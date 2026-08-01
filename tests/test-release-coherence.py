#!/usr/bin/env python3
"""Contract tests for scripts/check-release-coherence.py."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "scripts" / "check-release-coherence.py"


class RepoFixture:
    def __init__(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.root / ".claude-plugin").mkdir()
        self.write_version("1.0.0")
        self.write("CHANGELOG.md", "# Changelog\n\n## [1.0.0] - 2026-01-01\n")
        self.write("README.md", "MAOS 1.0.0\n")
        self.write("CLAUDE.md", "MAOS 1.0.0\n")
        self.commit("chore(release): initial")

    def close(self) -> None:
        self.tempdir.cleanup()

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.strip()

    def write(self, path: str, content: str) -> None:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def write_version(self, version: str) -> None:
        self.write(
            ".claude-plugin/plugin.json",
            json.dumps({"name": "maos", "version": version}) + "\n",
        )

    def commit(self, subject: str) -> str:
        self.git("add", ".")
        self.git("commit", "-m", subject)
        return self.git("rev-parse", "HEAD")

    def branch(self, name: str) -> None:
        self.git("switch", "-c", name)

    def switch(self, name: str) -> None:
        self.git("switch", name)

    def release(
        self,
        version: str,
        *,
        extra_path: str | None = None,
        subject: str | None = None,
    ) -> str:
        self.write_version(version)
        with (self.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write(f"\n## [{version}] - 2026-08-01\n")
        if extra_path:
            self.write(extra_path, "functional change\n")
        return self.commit(subject or f"chore(release): {version}")

    def check(self, base: str, head: str, _title: str = "") -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "python3",
                str(CHECKER),
                "--repo",
                str(self.root),
                "--base-sha",
                base,
                "--head-sha",
                head,
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )


class ReleaseCoherenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = RepoFixture()
        self.initial = self.repo.git("rev-parse", "HEAD")

    def tearDown(self) -> None:
        self.repo.close()

    def test_valid_release_pr_passes(self) -> None:
        self.repo.branch("release")
        head = self.repo.release("1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_stale_untouched_branch_is_not_a_false_bump(self) -> None:
        self.repo.branch("stale")
        self.repo.write("notes.md", "branch documentation\n")
        stale_head = self.repo.commit("docs: branch work")
        self.repo.switch("main")
        base = self.repo.release("1.1.0")
        result = self.repo.check(base, stale_head, "docs: branch work")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("untouched", result.stdout)

    def test_feature_commit_subject_is_rejected(self) -> None:
        self.repo.branch("release")
        head = self.repo.release("1.1.0", subject="feat: hide a release")
        result = self.repo.check(self.initial, head)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("commit subject", result.stderr)

    def test_non_utf8_commit_subject_is_rejected_without_traceback(self) -> None:
        self.repo.branch("release")
        valid_commit = self.repo.release("1.1.0")
        raw_commit = subprocess.run(
            ["git", "-C", str(self.repo.root), "cat-file", "commit", valid_commit],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.replace(b"chore(release): 1.1.0", b"chore(release): \xff")
        commit = subprocess.run(
            ["git", "-C", str(self.repo.root), "hash-object", "-t", "commit", "-w", "--stdin"],
            check=True,
            input=raw_commit,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.decode("ascii").strip()
        self.repo.git("update-ref", "HEAD", commit)

        result = self.repo.check(self.initial, commit)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-UTF-8 output", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_release_delta_must_be_exactly_one_commit(self) -> None:
        self.repo.branch("release")
        self.repo.write("notes.md", "unrelated precursor\n")
        self.repo.commit("docs: precursor")
        head = self.repo.release("1.1.0")
        result = self.repo.check(self.initial, head)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)

    def test_release_pr_with_merge_commit_is_rejected(self) -> None:
        self.repo.branch("release")
        self.repo.switch("main")
        self.repo.write("README.md", "base documentation\n")
        self.repo.commit("docs: advance main")
        self.repo.switch("release")
        self.repo.git("merge", "--no-ff", "main", "-m", "merge main")
        head = self.repo.release("1.1.0")
        base = self.repo.git("rev-parse", "main")
        result = self.repo.check(base, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("linear", result.stderr)

    def test_release_pr_with_functional_path_is_rejected(self) -> None:
        self.repo.branch("release")
        head = self.repo.release("1.1.0", extra_path="src/feature.ts")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-release paths", result.stderr)

    def test_release_pr_cannot_modify_manifest_supply_chain_fields(self) -> None:
        self.repo.branch("release")
        self.repo.write(
            ".claude-plugin/plugin.json",
            json.dumps({"name": "maos", "version": "1.1.0", "hooks": {"unsafe": "head"}})
            + "\n",
        )
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0] - 2026-08-01\n")
        head = self.repo.commit("chore(release): 1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only the version field", result.stderr)

    def test_manifest_comparison_preserves_json_types(self) -> None:
        self.repo.write(
            ".claude-plugin/plugin.json",
            json.dumps({"name": "maos", "version": "1.0.0", "prefix_required": True}) + "\n",
        )
        base = self.repo.commit("test: typed manifest baseline")
        self.repo.branch("release")
        self.repo.write(
            ".claude-plugin/plugin.json",
            json.dumps({"name": "maos", "version": "1.1.0", "prefix_required": 1}) + "\n",
        )
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0] - 2026-08-01\n")
        head = self.repo.commit("chore(release): 1.1.0")
        result = self.repo.check(base, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only the version field", result.stderr)

    def test_release_pr_cannot_edit_derived_readme(self) -> None:
        self.repo.branch("release")
        self.repo.write_version("1.1.0")
        self.repo.write("README.md", "hidden instructions\n")
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0] - 2026-08-01\n")
        head = self.repo.commit("chore(release): 1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("README.md", result.stderr)

    def test_release_without_new_changelog_heading_is_rejected(self) -> None:
        self.repo.branch("release")
        self.repo.write_version("1.1.0")
        head = self.repo.commit("chore(release): 1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CHANGELOG", result.stderr)

    def test_historical_changelog_rewrite_is_rejected(self) -> None:
        self.repo.branch("release")
        changelog = self.repo.root / "CHANGELOG.md"
        prior = changelog.read_text(encoding="utf-8")
        changelog.write_text(prior.replace("2026-01-01", "2099-01-01"), encoding="utf-8")
        head = self.repo.release("1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("additive", result.stderr)

    def test_markdown_separator_removal_is_rejected(self) -> None:
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n---\n")
        base = self.repo.commit("docs: add separator")
        self.repo.branch("release")
        changelog = self.repo.root / "CHANGELOG.md"
        prior = changelog.read_text(encoding="utf-8")
        changelog.write_text(prior.replace("\n---\n", "\n"), encoding="utf-8")
        head = self.repo.release("1.1.0")
        result = self.repo.check(base, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("additive", result.stderr)

    def test_duplicate_new_changelog_heading_is_rejected(self) -> None:
        self.repo.branch("release")
        self.repo.write_version("1.1.0")
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0] - first\n\n## [1.1.0] - duplicate\n")
        head = self.repo.commit("chore(release): 1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)

    def test_version_already_in_base_changelog_is_rejected(self) -> None:
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0] - reserved\n")
        base = self.repo.commit("docs: reserve version")
        self.repo.branch("release")
        head = self.repo.release("1.1.0")
        result = self.repo.check(base, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists", result.stderr)

    def test_downgrade_is_rejected(self) -> None:
        self.repo.branch("release")
        head = self.repo.release("0.9.0")
        result = self.repo.check(self.initial, head, "chore(release): 0.9.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must advance", result.stderr)

    def test_reused_tag_is_rejected(self) -> None:
        self.repo.git("tag", "v1.1.0")
        self.repo.branch("release")
        head = self.repo.release("1.1.0")
        result = self.repo.check(self.initial, head, "chore(release): 1.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Git tag", result.stderr)

    def test_prerelease_precedence_advances(self) -> None:
        self.repo.write_version("1.1.0-alpha.1")
        with (self.repo.root / "CHANGELOG.md").open("a", encoding="utf-8") as changelog:
            changelog.write("\n## [1.1.0-alpha.1] - 2026-07-31\n")
        base = self.repo.commit("chore(release): 1.1.0-alpha.1")
        self.repo.branch("release")
        head = self.repo.release("1.1.0-alpha.2")
        result = self.repo.check(base, head, "chore(release): 1.1.0-alpha.2")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_stale_release_branch_must_rebase(self) -> None:
        self.repo.branch("release")
        head = self.repo.release("1.2.0")
        self.repo.switch("main")
        base = self.repo.release("1.1.0")
        result = self.repo.check(base, head, "chore(release): 1.2.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rebased", result.stderr)


class TrustedWorkflowTests(unittest.TestCase):
    def test_workflow_is_base_owned_and_never_executes_head(self) -> None:
        workflow = (ROOT / ".github/workflows/release-coherence.yml").read_text(encoding="utf-8")
        self.assertIn("pull_request_target:", workflow)
        self.assertNotIn("\n  pull_request:\n", workflow)
        self.assertIn("ref: main", workflow)
        self.assertNotIn("ref: ${{ github.event.pull_request.base.sha }}", workflow)
        self.assertNotIn("ref: ${{ github.event.pull_request.head.sha }}", workflow)
        self.assertIn("python3 scripts/check-release-coherence.py", workflow)
        self.assertNotIn("cp scripts/check-release-coherence.py", workflow)
        self.assertNotIn("statuses: write", workflow)
        self.assertNotIn("statuses/$HEAD_SHA", workflow)
        self.assertNotIn("pull_request.title", workflow)


if __name__ == "__main__":
    unittest.main()
