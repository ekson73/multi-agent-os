#!/usr/bin/env python3
"""Bash-compatible enforcement rendering; real dispatcher uses contract mocks only."""
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SUT = HERE.parent / "bin/routed-review.sh"


class EnforcementRendering(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="rr-enforcement-")
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        tools = root / "tools"
        tools.mkdir()
        for command in ("jq", "timeout"):
            executable = shutil.which(command)
            if command == "timeout" and executable is None:
                executable = shutil.which("gtimeout")
            self.assertIsNotNone(executable, f"Required test dependency: {command}")
            (tools / command).symlink_to(executable)
        home, tmp = root / "home", root / "tmp"
        home.mkdir()
        tmp.mkdir()
        # No host reviewer PATH, credentials, Bash startup hooks or harness overrides.
        self.env = {"HOME": str(home), "TMPDIR": str(tmp),
                    "PATH": f"{tools}:/usr/bin:/bin:/usr/sbin:/sbin",
                    "GIT_ALLOW_PROTOCOL": "file", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": "/dev/null", "LC_ALL": "C"}

    def test_bash32_case_patterns_are_parenthesized(self):
        # Newer /bin/bash versions accept the broken form: keep this portability
        # invariant observable even when the executing host is not Bash 3.2.
        source = SUT.read_text()
        start = source.index("  printf 'Read-only enforcement:")
        end = source.index("  printf 'Post-run tamper", start)
        rendering = source[start:end]
        self.assertRegex(rendering, r'case "\$ENFORCEMENT"\s+in\s+\(vendor\+os\*\)')
        self.assertRegex(rendering, r';;\s+\(\*\)\s+printf')

    def test_each_enforcement_arm(self):
        source = SUT.read_text()
        start = source.index("  printf 'Read-only enforcement:")
        end = source.index("  printf 'Post-run tamper", start)
        generic = "disposable export of every tracked path, chmod a-w, no .git"
        vendor = "CLI sandbox/tool restriction over a disposable export of every tracked path of the head"
        for mode, explanation in (("os-perms-only", generic), ("os-sandboxed", generic),
                                  ("vendor+os-perms-only", vendor), ("vendor+os-sandboxed", vendor)):
            with self.subTest(mode=mode):
                result = subprocess.run(
                    ["/bin/bash", "-c", "ENFORCEMENT=" + shlex.quote(mode) + "\n" + source[start:end]],
                    text=True, capture_output=True, timeout=10, env=self.env)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stderr, "")
                self.assertEqual(result.stdout, f"Read-only enforcement: `{mode}` ({explanation})\n")

    def test_mocked_dispatcher_markdown(self):
        # Reuse the maintained offline fixtures, not a copied reviewer implementation.
        fixture = (HERE / "contract.sh").read_text().split('echo "routed-pr-review — gate contract"')[0]
        fixture = fixture.replace('SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', "SELF_DIR=" + shlex.quote(str(HERE)))
        fixture = fixture.replace('SUT="$SELF_DIR/../bin/routed-review.sh"', "SUT=" + shlex.quote(str(SUT)))
        fixture = fixture.replace(' --json ${EXTRA_ARGS:-}', ' ${EXTRA_ARGS:-}')
        fixture += '''
OUT="$(T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
printf '%s\\n' "$OUT"
cat "$SANDBOX/err" >&2
exit "$RC"
'''
        result = subprocess.run(["/bin/bash", "-c", fixture], text=True,
                                capture_output=True, timeout=60, env=self.env)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertNotIn("syntax error", result.stderr)
        self.assertNotIn('case "$ENFORCEMENT"', result.stdout)
        self.assertRegex(result.stdout, r"Read-only enforcement: `os-(?:perms-only|sandboxed)` \(disposable export of every tracked path, chmod a-w, no \.git\)")
        self.assertIn('| May complete convergence on its own | `false` |', result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
