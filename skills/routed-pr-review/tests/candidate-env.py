#!/usr/bin/env python3
"""Synthetic environment policy tests; never read host credentials or run a CLI."""
import os
from pathlib import Path
import subprocess
import tempfile
import shlex
import unittest

SUT = Path(__file__).resolve().parents[1] / 'bin/routed-review.sh'
FAMILY_START, FAMILY_END = 'family_of() {', 'CALLER_FAMILY='
POLICY_START = 'REVIEWER_ENV=(env -i)'
POLICY_END = 'STATE_DIR="$(dirname "$STATE_FILE")"; mkdir'
DISPATCH_START, DISPATCH_END = 'run_reviewer() {', 'reset_isolation() {'

class CandidateEnvironment(unittest.TestCase):
    def section(self, source, start, end):
        self.assertIn(start, source, f'missing source anchor: {start}')
        begin=source.index(start)
        self.assertIn(end, source[begin+len(start):], f'missing source anchor: {end}')
        return source[begin:source.index(end, begin+len(start))]

    def policy(self, source):
        policy=self.section(source, POLICY_START, POLICY_END)
        self.assertIn('build_reviewer_env() {', policy, 'required per-candidate builder missing')
        return policy

    def test_missing_anchors_fail_descriptively(self):
        with self.assertRaisesRegex(AssertionError, 'missing source anchor: START'):
            self.section('unrelated', 'START', 'END')
        with self.assertRaisesRegex(AssertionError, 'missing source anchor: END'):
            self.section('START body', 'START', 'END')

    def test_removed_builder_fails_before_execution(self):
        source=SUT.read_text()
        self.policy(source)  # Assert anchors before constructing the deletion mutant.
        start=source.index('build_reviewer_env() {')
        end=source.index('\n}\n', start)+3
        source=source[:start]+source[end:]
        with self.assertRaisesRegex(AssertionError, 'required per-candidate builder missing'):
            self.policy(source)

    def test_candidate_and_fallback_isolation(self):
        source = SUT.read_text()
        family = self.section(source, FAMILY_START, FAMILY_END)
        policy = self.policy(source)
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
        policy = self.policy(source)
        dispatch = self.section(source, DISPATCH_START, DISPATCH_END)
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
