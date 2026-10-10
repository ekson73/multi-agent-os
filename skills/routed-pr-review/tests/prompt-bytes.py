#!/usr/bin/env python3
"""Reject unrepresentable prompts before dispatch; synthetic offline fixtures only."""
from pathlib import Path
import importlib.util
import json
import shlex
import shutil
import subprocess
import unittest

HERE = Path(__file__).resolve().parent
SUT = HERE.parent / 'bin/routed-review.sh'
spec = importlib.util.spec_from_file_location('enforcement_fixture', HERE / 'enforcement-render.py')
fixture_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture_module)


class PromptBytes(unittest.TestCase):
    # Reuse the minimal credential-free environment and maintained contract mocks.
    setUp = fixture_module.EnforcementRendering.setUp

    def replace_once(self, fixture, anchor, replacement):
        self.assertEqual(1, fixture.count(anchor), f'Fixture anchor drift: {anchor!r}')
        return fixture.replace(anchor, replacement, 1)

    def dispatch(self, location, reviewer='kimi', validator_error=None):
        fixture = (HERE / 'contract.sh').read_text()
        boundary = 'echo "routed-pr-review — gate contract"'
        self.assertEqual(1, fixture.count(boundary), 'Fixture boundary drift')
        fixture = fixture.split(boundary, 1)[0]
        fixture = self.replace_once(fixture, 'SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
                                  'SELF_DIR=' + shlex.quote(str(HERE)))
        fixture = self.replace_once(fixture, 'SUT="$SELF_DIR/../bin/routed-review.sh"',
                                  'SUT=' + shlex.quote(str(SUT)))
        if location == 'diff':
            fixture = self.replace_once(fixture, 'echo hello > file.txt', "printf 'LEFT\\000RIGHT\\n' > file.txt")
        elif location == 'title':
            fixture = self.replace_once(fixture, '"title": "contract fixture"', r'"title": "LEFT\u0000RIGHT"')
        fixture = self.replace_once(fixture, 'cat >/dev/null', ': > "$T_START_MARK"\ncat >/dev/null')
        # Unarmed fallback lets the offline mock write an invocation marker.
        fixture += '\nprintf "#!/bin/sh\\nexit 1\\n" > "$STUB_BIN/sandbox-exec"; chmod +x "$STUB_BIN/sandbox-exec"\n'
        fixture += '\ncp "$CODEX_BIN/codex" "$STUB_BIN/codex"\n'
        if validator_error:
            target = shutil.which(validator_error)
            self.assertIsNotNone(target)
            match = ('case "$*" in *prompt.nul-check*) exit 2 ;; esac' if validator_error == 'cmp'
                     else '[ "$1" != -d ] || [ "$2" != "\\000" ] || exit 2')
            if validator_error == 'jq':
                match = 'case "$*" in *\'index("\\u0000")\'*) exit 5 ;; esac'
            wrapper = '#!/bin/sh\n' + match + '\nexec ' + shlex.quote(target) + ' "$@"\n'
            fixture += '\nprintf %s ' + shlex.quote(wrapper) + ' > "$STUB_BIN/' + validator_error + '"; chmod +x "$STUB_BIN/' + validator_error + '"\n'
        fixture += '''
OUT="$(T_REVIEWS="$(printf "$AT_HEAD" APPROVED)" T_REVIEW_BODY="$PASS_BODY" T_START_MARK="$SANDBOX/invoked" T_PROMPT_MARK=LEFTRIGHT EXTRA_ARGS="--primary coderabbitai" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
printf '%s\\n' "$OUT"
cat "$SANDBOX/err" >&2
[ ! -e "$SANDBOX/invoked" ] || echo REVIEWER_INVOKED >&2
exit "$RC"
'''
        fixture = self.replace_once(fixture, 'T_PROMPT_MARK=LEFTRIGHT', 'RV=' + shlex.quote(reviewer) + ' T_PROMPT_MARK=LEFTRIGHT')
        if location == 'body':
            fixture = self.replace_once(fixture, 'T_PROMPT_MARK=LEFTRIGHT', r"T_PROMPT_MARK=LEFTRIGHT T_PR_BODY='LEFT\u0000RIGHT'")
        result = subprocess.run(['/bin/bash', '-c', fixture], text=True, capture_output=True,
                                timeout=60, env=self.env)
        return result

    def test_nul_inputs_refused(self):
        for location in ('diff', 'title', 'body'):
            for reviewer in ('kimi', 'codex'):
                with self.subTest(location=location, reviewer=reviewer):
                    result = self.dispatch(location, reviewer=reviewer)
                    self.assertEqual(1, result.returncode, result.stdout + result.stderr)
                    self.assertIn('NUL', result.stderr)
                    self.assertNotIn('REVIEWER_INVOKED', result.stderr)
                    self.assertEqual('', result.stdout.strip())

    def test_text_input_preserves_full_review(self):
        for reviewer in ('kimi', 'codex'):
            with self.subTest(reviewer=reviewer):
                result = self.dispatch('text', reviewer=reviewer)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn('REVIEWER_INVOKED', result.stderr)
                self.assertTrue(json.loads(result.stdout)['may_complete_c3'])

    def test_validator_errors_refuse_dispatch(self):
        for command in ('tr', 'cmp', 'jq'):
            with self.subTest(command=command):
                result = self.dispatch('text', validator_error=command)
                self.assertEqual(1, result.returncode, result.stdout + result.stderr)
                expected = 'PR title' if command == 'jq' else 'prompt'
                self.assertIn(f'cannot validate {expected} bytes', result.stderr)
                self.assertNotIn('REVIEWER_INVOKED', result.stderr)
                self.assertEqual('', result.stdout.strip())


if __name__ == '__main__':
    unittest.main(verbosity=2)
