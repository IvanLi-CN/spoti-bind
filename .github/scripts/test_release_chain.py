#!/usr/bin/env python3
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("release_chain", Path(__file__).with_name("release_chain.py"))
release_chain = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(release_chain)


class ReleaseChainTests(unittest.TestCase):
    def setUp(self):
        self.policy = json.loads((ROOT / ".github/pr-label-release.json").read_text())

    def test_default_stable_patch_intent(self):
        labels = json.loads((Path(__file__).parent / "fixtures/labels-default.json").read_text())
        resolved = release_chain.resolve_labels(labels, self.policy)
        self.assertEqual(resolved["type"], "type:patch")
        self.assertEqual(resolved["channel"], "channel:stable")

    def test_unknown_and_duplicate_release_labels_fail(self):
        with self.assertRaises(release_chain.ReleaseError):
            labels = json.loads((Path(__file__).parent / "fixtures/labels-invalid-duplicate.json").read_text())
            release_chain.resolve_labels(labels, self.policy)
        with self.assertRaises(release_chain.ReleaseError):
            release_chain.resolve_labels(["type:wat", "channel:stable"], self.policy)

    def test_bump_rules_are_numeric_and_deterministic(self):
        self.assertEqual(release_chain.bump_version("0.1.0", "type:patch"), "0.1.1")
        self.assertEqual(release_chain.bump_version("0.1.9", "type:minor"), "0.2.0")
        self.assertEqual(release_chain.bump_version("0.1.9", "type:major"), "1.0.0")
        self.assertEqual(release_chain.bump_version("0.1.9", "type:none"), "0.1.9")

    def test_preparation_is_single_parent_and_version_only(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            import subprocess

            subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
            (repo / "VERSION").write_text("0.1.0\n")
            (repo / "README").write_text("stable\n")
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-qm", "source"], cwd=repo, check=True)
            source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
            (repo / "VERSION").write_text("0.1.1\n")
            subprocess.run(["git", "add", "VERSION"], cwd=repo, check=True)
            message = "prepare\n\nRelease-Source-SHA: %s\nRelease-Version: 0.1.1\nRelease-Type: type:patch\nRelease-Channel: channel:stable\nSigned-off-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>\n" % source
            subprocess.run(["git", "commit", "-qm", message], cwd=repo, check=True)
            preparation = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
            result = release_chain.validate_preparation(repo, preparation, source)
            self.assertEqual(result["version"], "0.1.1")


if __name__ == "__main__":
    unittest.main()
