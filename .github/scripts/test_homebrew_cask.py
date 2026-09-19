#!/usr/bin/env python3
import importlib.util
import os
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "homebrew_cask", Path(__file__).with_name("homebrew_cask.py")
)
homebrew_cask = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(homebrew_cask)


class HomebrewCaskTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / "Casks/spotibind.rb").read_text(encoding="utf-8")
        self.version = homebrew_cask._field(self.text, "version")
        self.sha256 = homebrew_cask._field(self.text, "sha256")

    def test_current_cask_uses_canonical_identity(self):
        head_ref = os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME", "")
        if head_ref.startswith("automation/cask-release-"):
            expected_version = head_ref.removeprefix("automation/cask-release-")
            self.assertEqual(self.version, expected_version)
            homebrew_cask.validate_text(
                self.text,
                version=self.version,
                sha256=self.sha256,
            )
            return

        homebrew_cask.validate_text(
            self.text,
            version="0.2.6",
            sha256="84bbca994079472528d4088a2b456deec6dd7b33d470993ff381c408385b360c",
        )

    def test_render_updates_only_identity_fields(self):
        rendered = homebrew_cask.render_text(
            self.text,
            version="0.2.7",
            sha256="a" * 64,
        )
        self.assertIn('version "0.2.7"', rendered)
        self.assertIn(f'sha256 "{"a" * 64}"', rendered)
        self.assertIn(homebrew_cask.URL_TEMPLATE, rendered)
        self.assertIn("Ad Hoc signed", rendered)

    def test_noncanonical_url_fails_closed(self):
        bad = self.text.replace(homebrew_cask.URL_TEMPLATE, "https://example.invalid/app.dmg")
        with self.assertRaises(homebrew_cask.CaskError):
            homebrew_cask.validate_text(
                bad,
                version=self.version,
                sha256=self.sha256,
            )

    def test_duplicate_identity_field_fails_closed(self):
        bad = self.text.replace(
            f'version "{self.version}"',
            f'version "{self.version}"\n  version "{self.version}"',
            1,
        )
        with self.assertRaises(homebrew_cask.CaskError):
            homebrew_cask.validate_text(
                bad,
                version=self.version,
                sha256=self.sha256,
            )


if __name__ == "__main__":
    unittest.main()
