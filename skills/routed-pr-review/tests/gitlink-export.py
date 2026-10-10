#!/usr/bin/env python3
"""Offline regression: an export containing unmaterialized gitlinks is incomplete."""
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SUT = HERE.parent / "bin/routed-review.sh"


class GitlinkExportTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="rr-gitlink-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        tools = self.root / "tools"
        tools.mkdir()
        for command in ("jq", "timeout"):
            executable = shutil.which(command)
            if command == "timeout" and executable is None:
                executable = shutil.which("gtimeout")
            self.assertIsNotNone(executable, f"Required dependency: {command}")
            (tools / command).symlink_to(executable)
        home, tmp = self.root / "home", self.root / "tmp"
        home.mkdir()
        tmp.mkdir()
        self.env = {"HOME": str(home), "TMPDIR": str(tmp),
                    "PATH": f"{tools}:/usr/bin:/bin:/usr/sbin:/sbin",
                    "GIT_ALLOW_PROTOCOL": "file", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": "/dev/null", "LC_ALL": "C"}

    def replace_once(self, text, old, new):
        self.assertEqual(text.count(old), 1, f"fixture anchor missing or ambiguous: {old}")
        return text.replace(old, new, 1)

    def dispatch(self, kind, missing=False, post=False):
        fixture = (HERE / "contract.sh").read_text()
        delimiter = 'echo "routed-pr-review — gate contract"'
        self.assertEqual(fixture.count(delimiter), 1)
        fixture = fixture.split(delimiter, 1)[0]
        fixture = self.replace_once(fixture, 'SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', "SELF_DIR=" + shlex.quote(str(HERE)))
        fixture = self.replace_once(fixture, 'SUT="$SELF_DIR/../bin/routed-review.sh"', "SUT=" + shlex.quote(str(SUT)))
        marker = self.root / "reviewer-started"
        marker.unlink(missing_ok=True)
        post_marker = self.root / "posted"
        post_marker.unlink(missing_ok=True)
        path = "deps with spaces/nested lib" if missing else "deps/lib"
        fixture += '\nLINK_PATH=' + shlex.quote(path) + '\n'
        fixture += 'KIND=' + shlex.quote(kind) + '\n'
        fixture += 'LINK_OID=' + ('eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' if missing else '"$BASE_SHA"') + '\n'
        fixture += '''
# Synthetic gitlinks need no .gitmodules, remote or submodule checkout.
cd "$REPO_DIR" || exit 90
test -z "$(git remote)" && test ! -e .gitmodules || exit 91
if [ "$KIND" != control ]; then
  if [ "$KIND" != added ]; then
    OLD_OID="$HEAD_SHA"
    [ "$KIND" != unchanged ] || OLD_OID="$LINK_OID"
    git update-index --add --cacheinfo "160000,$OLD_OID,$LINK_PATH" || exit 92
    git commit -qm "base with gitlink" || exit 93
  fi
  BASE_SHA="$(git rev-parse HEAD)"
  git update-index --add --cacheinfo "160000,$LINK_OID,$LINK_PATH" || exit 94
  printf 'ordinary change\\n' >> file.txt
  git add file.txt && git commit -qm "reviewed head with gitlink" || exit 95
  HEAD_SHA="$(git rev-parse HEAD)"
  git ls-tree -r "$HEAD_SHA" -- "$LINK_PATH" >&2
  # Refresh the mocked approval to the newly constructed reviewed commit.
  AT_HEAD='[{"author":{"login":"coderabbitai"},"state":"%s","commit":{"oid":"'"$HEAD_SHA"'"}}]'
fi
'''
        if missing:
            fixture += 'if git cat-file -e "$LINK_OID" 2>/dev/null; then exit 96; fi\n'
        extra_args = "--primary coderabbitai" + (" --post" if post else "")
        fixture += f'''OUT="$(T_POST_MARK={shlex.quote(str(post_marker))} T_START_MARK={shlex.quote(str(marker))} T_REVIEWS="$(printf "$AT_HEAD" APPROVED)" T_REVIEW_BODY="$PASS_BODY" EXTRA_ARGS="{extra_args}" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
printf '%s' "$OUT"
cat "$SANDBOX/err" >&2
exit "$RC"
'''
        result = subprocess.run(["/bin/bash", "-c", fixture], text=True,
                                capture_output=True, timeout=60, env=self.env)
        return result, marker.exists(), post_marker.exists()

    def test_gitlinks_refuse_export_before_reviewer(self):
        for kind in ("added", "changed", "unchanged"):
            for missing in (False, True):
                with self.subTest(kind=kind, missing_object=missing):
                    result, started, posted = self.dispatch(kind, missing)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertFalse(started)
                    self.assertFalse(posted)
                    self.assertEqual(result.stdout, "")
                    self.assertIn("gitlink", result.stderr)
                    self.assertIn("refusing", result.stderr)

    def test_gitlink_post_mode_never_dispatches_or_publishes(self):
        result, started, posted = self.dispatch("added", missing=True, post=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("gitlink", result.stderr)
        self.assertIn("refusing", result.stderr)
        self.assertFalse(started)
        self.assertFalse(posted)

    def test_regular_tree_still_reaches_reviewer(self):
        result, started, _ = self.dispatch("control")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(started)
        self.assertIn('"may_complete_c3": true', result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
