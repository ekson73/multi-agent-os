#!/usr/bin/env python3
"""Offline end-to-end final head/base pin checks in every output mode."""
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SUT = HERE.parent / "bin/routed-review.sh"


class FinalPinTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="rr-final-pin-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        tools = self.root / "tools"
        tools.mkdir()
        for command in ("jq", "timeout"):
            executable = shutil.which(command)
            if command == "timeout" and executable is None:
                executable = shutil.which("gtimeout")
            self.assertIsNotNone(executable, f"Required test dependency: {command}")
            (tools / command).symlink_to(executable)
        home, tmp = self.root / "home", self.root / "tmp"
        home.mkdir()
        tmp.mkdir()
        self.env = {"HOME": str(home), "TMPDIR": str(tmp),
                    "PATH": f"{tools}:/usr/bin:/bin:/usr/sbin:/sbin",
                    "GIT_ALLOW_PROTOCOL": "file", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": "/dev/null", "LC_ALL": "C"}

    def dispatch(self, mode, drift="", scanner_rc=0):
        fixture = (HERE / "contract.sh").read_text().split('echo "routed-pr-review — gate contract"')[0]
        fixture = fixture.replace('SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', "SELF_DIR=" + shlex.quote(str(HERE)))
        fixture = fixture.replace('SUT="$SELF_DIR/../bin/routed-review.sh"', "SUT=" + shlex.quote(str(SUT)))
        fixture = fixture.replace(' --json ${EXTRA_ARGS:-}', ' ${EXTRA_ARGS:-}')
        fixture = fixture.replace('    H="$T_HEAD";', '    if [ -n "${T_FINAL_UNREADABLE:-}" ] && [ -f "$T_COUNT" ] && [ "$(cat "$T_COUNT")" -ge 3 ]; then exit 1; fi\n    H="$T_HEAD";')
        marker = self.root / "posted"
        marker.unlink(missing_ok=True)
        scan_marker = self.root / "scanned"
        scan_marker.unlink(missing_ok=True)
        fixture = fixture.replace('exit "${T_GITLEAKS_RC:-0}"', ': > "$T_SCAN_MARK"\nexit "${T_GITLEAKS_RC:-0}"')
        fixture += '\nexport T_SCAN_MARK=' + shlex.quote(str(scan_marker)) + '\n'
        changed = f'T_{drift}_AFTER=1111111111111111111111111111111111111111 ' if drift else ""
        if drift == "UNREADABLE":
            changed = "T_FINAL_UNREADABLE=1 "
        args = {"text": "", "json": "--json", "post": "--post"}[mode]
        fixture += f'''OUT="$(T_COUNT="$SANDBOX/count" T_SWITCH_AT=3 {changed}T_GITLEAKS_RC={scanner_rc} T_POST_MARK={shlex.quote(str(marker))} T_REVIEWS="$(printf "$AT_HEAD" APPROVED)" T_REVIEW_BODY="$PASS_BODY" EXTRA_ARGS="--primary coderabbitai {args}" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
printf '%s' "$OUT"
cat "$SANDBOX/err" >&2
exit "$RC"
'''
        result = subprocess.run(["/bin/bash", "-c", fixture], text=True,
                                capture_output=True, timeout=60, env=self.env)
        return result, marker.exists(), scan_marker.exists()

    def test_late_head_and_base_drift_never_emit_or_post(self):
        for mode in ("text", "json", "post"):
            for drift in ("HEAD", "BASE"):
                with self.subTest(mode=mode, drift=drift):
                    result, posted, scanned = self.dispatch(mode, drift)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertEqual(result.stdout, "")
                    self.assertNotIn("may_complete_c3=true", result.stderr)
                    self.assertIn("moved after the verdict", result.stderr)
                    self.assertFalse(posted)
                    self.assertEqual(scanned, mode == "post")

    def test_unreadable_final_pin_never_emits_or_posts(self):
        for mode in ("text", "json", "post"):
            with self.subTest(mode=mode):
                result, posted, _ = self.dispatch(mode, "UNREADABLE")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertNotIn("may_complete_c3=true", result.stderr)
                self.assertIn("pr_unreadable", result.stderr)
                self.assertFalse(posted)

    def test_unchanged_pin_preserves_success_in_all_modes(self):
        for mode in ("text", "json", "post"):
            with self.subTest(mode=mode):
                result, posted, scanned = self.dispatch(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(posted, mode == "post")
                self.assertEqual(scanned, mode == "post")
                expected = '"may_complete_c3": true' if mode == "json" else '| May complete convergence on its own | `true` |'
                self.assertIn(expected, result.stdout)

    def test_scanner_refusal_still_prevents_posting(self):
        result, posted, scanned = self.dispatch("post", scanner_rc=1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("gitleaks flagged", result.stderr)
        self.assertTrue(scanned)
        self.assertFalse(posted)


if __name__ == "__main__":
    unittest.main(verbosity=2)
