#!/usr/bin/env python3
import importlib.util
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

    def test_current_cask_uses_canonical_identity(self):
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
                version="0.2.6",
                sha256="84bbca994079472528d4088a2b456deec6dd7b33d470993ff381c408385b360c",
            )

    def test_duplicate_identity_field_fails_closed(self):
        bad = self.text.replace('version "0.2.6"', 'version "0.2.6"\n  version "0.2.6"')
        with self.assertRaises(homebrew_cask.CaskError):
            homebrew_cask.validate_text(
                bad,
                version="0.2.6",
                sha256="84bbca994079472528d4088a2b456deec6dd7b33d470993ff381c408385b360c",
            )


if __name__ == "__main__":
    unittest.main()
