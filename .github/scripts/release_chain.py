#!/usr/bin/env python3
"""Pure release identity checks used by the GitHub Actions workflows."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

VERSION_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
TRAILER_RE = re.compile(r"^([A-Za-z][A-Za-z0-9-]*):[ \t]*(.+)$")
RELEASE_LABEL_RE = re.compile(r"^(type|channel):")
BOT_SIGNOFF = "Signed-off-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>"


class ReleaseError(ValueError):
    pass


def load_policy(path: Path) -> dict[str, Any]:
    policy = json.loads(path.read_text(encoding="utf-8"))
    if policy.get("schema_version") != 1:
        raise ReleaseError("unsupported release policy schema")
    return policy


def parse_version(value: str) -> tuple[int, int, int]:
    match = VERSION_RE.fullmatch(value.strip())
    if not match:
        raise ReleaseError(f"invalid numeric VERSION: {value!r}")
    return tuple(int(part) for part in match.groups())


def format_version(parts: tuple[int, int, int]) -> str:
    return ".".join(str(part) for part in parts)


def bump_version(version: str, release_type: str) -> str:
    major, minor, patch = parse_version(version)
    if release_type == "type:patch":
        patch += 1
    elif release_type == "type:minor":
        minor += 1
        patch = 0
    elif release_type == "type:major":
        major += 1
        minor = patch = 0
    elif release_type == "type:none":
        return version
    else:
        raise ReleaseError(f"unsupported release type: {release_type}")
    return format_version((major, minor, patch))


def _group_labels(labels: list[str], policy: dict[str, Any]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {group["name"]: [] for group in policy["label_groups"]}
    allowed = {
        label
        for group in policy["label_groups"]
        for label in group["allowed"]
    }
    for label in labels:
        if label in allowed:
            for group in policy["label_groups"]:
                if label.startswith(group["prefix"]):
                    groups[group["name"]].append(label)
            continue
        if RELEASE_LABEL_RE.match(label):
            raise ReleaseError(f"unknown release label: {label}")
    return groups


def resolve_labels(labels: list[str], policy: dict[str, Any]) -> dict[str, Any]:
    if len(labels) != len(set(labels)):
        raise ReleaseError("duplicate pull request labels")
    groups = _group_labels(labels, policy)
    resolved: dict[str, Any] = {"labels": sorted(labels)}
    for group in policy["label_groups"]:
        values = groups[group["name"]]
        if group["required"] and len(values) != 1:
            raise ReleaseError(
                f"label group {group['name']} requires exactly one label, got {values}"
            )
        if group["cardinality"] == "exactly-one" and len(values) != 1:
            raise ReleaseError(f"label group {group['name']} is not exactly one")
        resolved[group["name"]] = values[0] if values else None
    return resolved


def parse_trailers(message: str) -> dict[str, str]:
    trailers: dict[str, str] = {}
    for line in message.splitlines():
        match = TRAILER_RE.fullmatch(line.strip())
        if match:
            trailers[match.group(1)] = match.group(2).strip()
    return trailers


def validate_identity(
    *,
    source_sha: str,
    version: str,
    release_type: str,
    channel: str,
    prep_sha: str | None = None,
) -> dict[str, str]:
    if not SHA_RE.fullmatch(source_sha):
        raise ReleaseError("source SHA must be a full lowercase git SHA")
    if prep_sha is not None and not SHA_RE.fullmatch(prep_sha):
        raise ReleaseError("preparation SHA must be a full lowercase git SHA")
    parse_version(version)
    if release_type not in {"type:major", "type:minor", "type:patch", "type:none"}:
        raise ReleaseError("invalid release type")
    if channel != "channel:stable":
        raise ReleaseError("unsupported release channel")
    return {
        "source_sha": source_sha,
        "version": version,
        "type": release_type,
        "channel": channel,
    }


def git(*args: str, cwd: Path) -> str:
    result = subprocess.run(
        ["git", *args], cwd=cwd, text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise ReleaseError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout.strip()


def validate_preparation(repo: Path, preparation_sha: str, source_sha: str) -> dict[str, str]:
    if not SHA_RE.fullmatch(preparation_sha) or not SHA_RE.fullmatch(source_sha):
        raise ReleaseError("preparation and source must be full git SHAs")
    parents = git("show", "-s", "--format=%P", preparation_sha, cwd=repo).split()
    if parents != [source_sha]:
        raise ReleaseError("preparation must have exactly the source commit as its parent")
    changed = git("diff-tree", "--no-commit-id", "--name-only", "-r", preparation_sha, cwd=repo)
    if changed.splitlines() != ["VERSION"]:
        raise ReleaseError("preparation must modify VERSION only")
    message = git("show", "-s", "--format=%B", preparation_sha, cwd=repo)
    trailers = parse_trailers(message)
    if BOT_SIGNOFF not in message:
        raise ReleaseError("preparation must include the GitHub Actions DCO signoff")
    if trailers.get("Release-Source-SHA") != source_sha:
        raise ReleaseError("preparation provenance source SHA is missing or incorrect")
    version = trailers.get("Release-Version")
    release_type = trailers.get("Release-Type")
    channel = trailers.get("Release-Channel")
    if not version or not release_type or not channel:
        raise ReleaseError("preparation provenance trailers are incomplete")
    validate_identity(
        source_sha=source_sha,
        version=version,
        release_type=release_type,
        channel=channel,
        prep_sha=preparation_sha,
    )
    committed_version = git("show", f"{preparation_sha}:VERSION", cwd=repo).strip()
    if committed_version != version:
        raise ReleaseError("VERSION does not match preparation provenance")
    return {"preparation_sha": preparation_sha, "source_sha": source_sha, "version": version, "type": release_type, "channel": channel}


def check_checks(payload: list[dict[str, Any]], required: list[str]) -> None:
    by_name = {item.get("name"): item for item in payload}
    missing = [name for name in required if name not in by_name]
    failed = [
        name for name in required
        if name in by_name and by_name[name].get("conclusion") != "success"
    ]
    if missing or failed:
        parts = []
        if missing:
            parts.append(f"missing checks: {', '.join(missing)}")
        if failed:
            parts.append(f"failed checks: {', '.join(failed)}")
        raise ReleaseError("; ".join(parts))


def validate_main_merge(repo: Path, merge_sha: str) -> dict[str, str]:
    """Validate the immutable merge -> preparation -> source identity chain."""
    if not SHA_RE.fullmatch(merge_sha):
        raise ReleaseError("merge SHA must be a full lowercase git SHA")
    parents = git("show", "-s", "--format=%P", merge_sha, cwd=repo).split()
    if len(parents) != 2:
        raise ReleaseError("release target must be a normal two-parent merge commit")
    previous_main, preparation = parents
    prep_parents = git("show", "-s", "--format=%P", preparation, cwd=repo).split()
    if len(prep_parents) != 1:
        raise ReleaseError("merge second parent must be a single-parent preparation commit")
    source = prep_parents[0]
    identity = validate_preparation(repo, preparation, source)
    merge_version = git("show", f"{merge_sha}:VERSION", cwd=repo).strip()
    if merge_version != identity["version"]:
        raise ReleaseError("merge VERSION does not match preparation provenance")
    identity.update({"merge_sha": merge_sha, "previous_main_sha": previous_main})
    return identity


def command_validate_labels(args: argparse.Namespace) -> None:
    labels = json.loads(args.labels)
    if not isinstance(labels, list) or not all(isinstance(label, str) for label in labels):
        raise ReleaseError("labels must be a JSON string array")
    result = resolve_labels(labels, load_policy(Path(args.policy)))
    print(json.dumps(result, sort_keys=True))


def command_bump(args: argparse.Namespace) -> None:
    print(bump_version(args.version, args.type))


def command_validate_preparation(args: argparse.Namespace) -> None:
    print(json.dumps(validate_preparation(Path(args.repo), args.preparation, args.source), sort_keys=True))


def command_check_checks(args: argparse.Namespace) -> None:
    payload = json.loads(Path(args.checks).read_text(encoding="utf-8"))
    check_checks(payload, args.required)
    print("required checks passed")


def command_validate_main(args: argparse.Namespace) -> None:
    print(json.dumps(validate_main_merge(Path(args.repo), args.merge), sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    labels = sub.add_parser("validate-labels")
    labels.add_argument("--labels", required=True)
    labels.add_argument("--policy", required=True)
    labels.set_defaults(function=command_validate_labels)
    bump = sub.add_parser("bump-version")
    bump.add_argument("--version", required=True)
    bump.add_argument("--type", required=True)
    bump.set_defaults(function=command_bump)
    prep = sub.add_parser("validate-preparation")
    prep.add_argument("--repo", required=True)
    prep.add_argument("--preparation", required=True)
    prep.add_argument("--source", required=True)
    prep.set_defaults(function=command_validate_preparation)
    checks = sub.add_parser("check-checks")
    checks.add_argument("--checks", required=True)
    checks.add_argument("--required", action="append", required=True)
    checks.set_defaults(function=command_check_checks)
    main = sub.add_parser("validate-main")
    main.add_argument("--repo", required=True)
    main.add_argument("--merge", required=True)
    main.set_defaults(function=command_validate_main)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        args.function(args)
    except (OSError, json.JSONDecodeError, ReleaseError) as error:
        print(f"release-chain: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
