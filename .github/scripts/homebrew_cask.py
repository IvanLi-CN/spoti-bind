#!/usr/bin/env python3
"""Render and validate SpotiBind's same-repository Homebrew Cask."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CASK_NAME = "spotibind"
URL_TEMPLATE = (
    "https://github.com/IvanLi-CN/spoti-bind/releases/download/"
    "v#{version}/SpotiBind-#{version}-universal.dmg"
)
VERSION_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class CaskError(ValueError):
    pass


def _field(text: str, name: str) -> str:
    matches = re.findall(
        rf"^\s*{re.escape(name)}\s+\"([^\"]+)\"\s*$",
        text,
        re.MULTILINE,
    )
    if len(matches) != 1:
        raise CaskError(f"cask field must occur exactly once: {name}")
    return matches[0]


def validate_values(version: str, sha256: str) -> None:
    if not VERSION_RE.fullmatch(version):
        raise CaskError(f"invalid numeric version: {version!r}")
    if not SHA256_RE.fullmatch(sha256):
        raise CaskError("sha256 must be a lowercase 64-character hexadecimal digest")


def validate_text(text: str, *, version: str, sha256: str) -> None:
    validate_values(version, sha256)
    cask_matches = re.findall(
        rf'^\s*cask\s+"{re.escape(CASK_NAME)}"\s+do\s*$',
        text,
        re.MULTILINE,
    )
    if len(cask_matches) != 1:
        raise CaskError(f"cask name must be {CASK_NAME!r}")
    if _field(text, "version") != version:
        raise CaskError("cask version does not match the release identity")
    if _field(text, "sha256") != sha256:
        raise CaskError("cask sha256 does not match the release asset")
    if _field(text, "url") != URL_TEMPLATE:
        raise CaskError("cask URL must use the canonical same-repository release template")


def render_text(text: str, *, version: str, sha256: str) -> str:
    validate_values(version, sha256)
    version_pattern = r'^(\s*version\s+")[^"]+("\s*)$'
    sha_pattern = r'^(\s*sha256\s+")[^"]+("\s*)$'
    rendered, version_count = re.subn(
        version_pattern,
        rf'\g<1>{version}\g<2>',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    rendered, sha_count = re.subn(
        sha_pattern,
        rf'\g<1>{sha256}\g<2>',
        rendered,
        count=1,
        flags=re.MULTILINE,
    )
    if version_count != 1 or sha_count != 1:
        raise CaskError("cannot render a Cask without exactly one version and sha256 field")
    validate_text(rendered, version=version, sha256=sha256)
    return rendered


def read_path(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def command_render(args: argparse.Namespace) -> None:
    print(render_text(read_path(Path(args.path)), version=args.version, sha256=args.sha256), end="")


def command_check(args: argparse.Namespace) -> None:
    validate_text(read_path(Path(args.path)), version=args.version, sha256=args.sha256)
    print("Homebrew Cask identity passed")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name, function in (("render", command_render), ("check", command_check)):
        subparser = subparsers.add_parser(name)
        subparser.add_argument("--path", required=True)
        subparser.add_argument("--version", required=True)
        subparser.add_argument("--sha256", required=True)
        subparser.set_defaults(function=function)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        args.function(args)
    except (OSError, CaskError) as error:
        print(f"homebrew-cask: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
