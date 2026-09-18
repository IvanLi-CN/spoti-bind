#!/usr/bin/env python3
"""Validate the checked-in quality-gate declaration against local workflows."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
POLICY = ROOT / ".github/quality-gates.json"
WORKFLOWS = ROOT / ".github/workflows"


def main() -> int:
    policy = json.loads(POLICY.read_text(encoding="utf-8"))
    assert policy["schema_version"] == 1
    required = policy["required_checks"]
    assert required == ["PR / Swift tests", "PR / Build app", "Label Gate", "Release completion"]
    assert policy["policy"]["branch_protection"]["require_pull_request"] is True
    assert policy["policy"]["branch_protection"]["disallow_direct_pushes"] is True
    assert policy["release"]["tag_pattern"] == "vX.Y.Z"
    assert policy["release"]["draft"] is False
    assert policy["release"]["public"] is True
    assert policy["release"]["version_source"] == "VERSION"
    assert policy["release"]["draft_until_distribution_consistency"] is True
    assert policy["release"]["cask"] == {
        "path": "Casks/spotibind.rb",
        "sync_workflow": "Cask release sync",
        "finalize_workflow": "Finalize Cask release",
        "branch_prefix": "automation/cask-release-",
        "single_build_artifact": True,
        "public_release_gate": "version-url-sha256",
    }
    text = "\n".join(path.read_text(encoding="utf-8") for path in WORKFLOWS.glob("*.yml"))
    for check in required:
        assert re.search(rf"name:\s*{re.escape(check)}\s*$", text, re.MULTILINE), check
    assert "name: Cask release sync" in text
    assert "name: Finalize Cask release" in text
    release_workflow = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
    assert re.search(r"gh release create[^\n]*--draft(?:[ =]|$)", release_workflow)
    assert "Create or update Draft GitHub Release" in release_workflow
    assert "same-repository Homebrew Cask verification" in release_workflow
    assert "--draft=false" not in release_workflow
    print("quality gates declaration passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
