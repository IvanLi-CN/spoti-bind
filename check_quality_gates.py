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
    assert policy["release"] == {
        "tag_pattern": "vX.Y.Z", "draft": False, "public": True, "version_source": "VERSION"
    }
    text = "\n".join(path.read_text(encoding="utf-8") for path in WORKFLOWS.glob("*.yml"))
    for check in required:
        assert re.search(rf"name:\s*{re.escape(check)}\s*$", text, re.MULTILINE), check
    assert "name: Draft release" not in text
    release_workflow = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
    assert not re.search(r"gh release create[^\n]*--draft(?:[ =]|$)", release_workflow)
    print("quality gates declaration passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
