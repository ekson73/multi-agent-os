#!/usr/bin/env python3
"""Synthetic environment policy tests; never read host credentials or run a CLI."""
import os
from pathlib import Path
import subprocess
import tempfile
import shlex
import unittest

SUT = Path(__file__).resolve().parents[1] / 'bin/routed-review.sh'

class CandidateEnvironment(unittest.TestCase):
    def test_candidate_and_fallback_isolation(self):
        source = SUT.read_text()
        family = source[source.index('family_of() {'):source.index('CALLER_FAMILY=')]
        policy = source[source.index('REVIEWER_ENV=(env -i)'):source.index('STATE_DIR="$(dirname "$STATE_FILE")"; mkdir')]
        keys = {'claude': 'ANTHROPIC_API_KEY', 'codex': 'OPENAI_API_KEY',
                'gemini': 'GEMINI_API_KEY', 'kimi': 'MOONSHOT_API_KEY',
                'qwen': 'DASHSCOPE_API_KEY', 'grok': 'XAI_API_KEY'}
        env = {'PATH': '/usr/bin:/bin', 'HOME': '/nonexistent',
               'ROUTED_REVIEW_ENV_ALLOW': 'GH_TOKEN AWS_SECRET_ACCESS_KEY OPENAI_API_KEY PRIVATE_TOKEN T_FIXTURE INNOCENT_LABEL',
               'GH_TOKEN': 'synthetic-gh', 'AWS_SECRET_ACCESS_KEY': 'synthetic-cloud',
               'PRIVATE_TOKEN': 'synthetic-private', 'INNOCENT_LABEL': 'synthetic-hidden-secret', 'T_FIXTURE': 'synthetic-fixture'}
        env.update({key: 'synthetic-' + key for key in keys.values()})
        env['OPENROUTER_API_KEY'] = 'synthetic-multi'
        # Same process, A -> B -> unknown -> multi: catches reuse of candidate A's array.
        for candidate in (*keys, 'unknown', 'pi', 'opencode'):
            with self.subTest(candidate=candidate):
                command = family + '\n' + policy + '\n'
                if 'build_reviewer_env()' in policy:
                    command += 'build_reviewer_env claude\nbuild_reviewer_env ' + candidate + '\n'
                command += '"${REVIEWER_ENV[@]}" /usr/bin/env\n'
                result = subprocess.run(['/bin/bash', '-c', command], env=env, text=True, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                actual = dict(line.split('=', 1) for line in result.stdout.splitlines())
                expected = {keys[candidate]} if candidate in keys else set()
                present = set(actual) & (set(keys.values()) | {'OPENROUTER_API_KEY', 'GH_TOKEN', 'AWS_SECRET_ACCESS_KEY', 'PRIVATE_TOKEN', 'INNOCENT_LABEL'})
                self.assertEqual(expected, present)
                self.assertNotIn('ROUTED_REVIEW_ENV_ALLOW', actual)
                self.assertNotIn('T_FIXTURE', actual)

    def test_real_dispatch_rebuilds_environment_on_fallback(self):
        source = SUT.read_text()
        policy = source[source.index('REVIEWER_ENV=(env -i)'):source.index('STATE_DIR="$(dirname "$STATE_FILE")"; mkdir')]
        dispatch = source[source.index('run_reviewer() {'):source.index('reset_isolation() {')]
        with tempfile.TemporaryDirectory(prefix='rr-candidate-') as directory:
            root = Path(directory)
            for name in ('claude', 'codex'):
                path = root / name
                path.write_text('#!/bin/sh\ncat >/dev/null\nprintf "INVOKED\\n"\n/usr/bin/env\n')
                path.chmod(0o700)
            timeout = root / 'timeout'
            timeout.write_text('#!/bin/sh\nshift 3\nexec "$@"\n')
            timeout.chmod(0o700)
            (root / 'prompt').write_text('synthetic prompt')
            env = {'PATH': str(root) + ':/usr/bin:/bin', 'HOME': str(root),
                   'ANTHROPIC_API_KEY': 'synthetic-a', 'OPENAI_API_KEY': 'synthetic-b',
                   'INNOCENT_LABEL': 'synthetic-hidden-secret',
                   'ROUTED_REVIEW_ENV_ALLOW': 'INNOCENT_LABEL'}
            command = policy + '\n' + dispatch + '\n'
            command += 'WORK=' + shlex.quote(str(root)) + '\n'
            command += 'PROMPT_F="$WORK/prompt"; OUT_F="$WORK/out"; TIMEOUT_CMD="$WORK/timeout"; TIMEOUT=5; MAX_TURNS=1; SBX=()\n'
            command += 'run_reviewer claude "$WORK"; cat "$OUT_F"; printf "NEXT\\n"; run_reviewer codex "$WORK"; cat "$OUT_F"\n'
            result = subprocess.run(['/bin/bash', '-c', command], env=env, text=True, capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)
            first, second = result.stdout.split('NEXT\n')
            self.assertIn('INVOKED', first)
            self.assertIn('INVOKED', second)
            self.assertIn('ANTHROPIC_API_KEY=synthetic-a', first)
            self.assertNotIn('OPENAI_API_KEY', first)
            self.assertIn('OPENAI_API_KEY=synthetic-b', second)
            self.assertNotIn('ANTHROPIC_API_KEY', second)
            self.assertNotIn('synthetic-hidden-secret', result.stdout)

if __name__ == '__main__':
    unittest.main(verbosity=2)
