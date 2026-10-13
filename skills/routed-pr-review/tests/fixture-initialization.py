#!/usr/bin/env python3
"""Fail closed before fixture Git writes; simulate failures, never exhaust disk."""
from pathlib import Path
import os
import shlex
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class FixtureInitialization(unittest.TestCase):
    def check_fixture(self, failure):
        with tempfile.TemporaryDirectory(prefix='rr-fixture-guard-') as temp:
            root = Path(temp)
            outer, home, tmp, tools = (root / name for name in ('outer', 'home', 'tmp', 'bin'))
            for path in (outer, home, tmp, tools):
                path.mkdir()
            env = {'PATH': str(tools) + ':/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': str(home),
                   'TMPDIR': str(tmp), 'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'}
            def git(*args):
                return subprocess.check_output(['/usr/bin/git', *args], cwd=outer, env=env)
            git('init', '-q')
            git('config', 'user.name', 'outer-fixture')
            git('config', 'user.email', 'outer@example.invalid')
            git('config', 'commit.gpgsign', 'false')
            git('commit', '--allow-empty', '-qm', 'outer')
            before = (git('rev-parse', 'HEAD'), git('status', '--porcelain'), (outer / '.git/config').read_bytes())
            if failure == 'mktemp':
                script = '#!/bin/sh\nprintf %s ' + shlex.quote(str(tmp / 'failed-fixture')) + '\nexit 1\n'
                (tools / 'mktemp').write_text(script)
                (tools / 'mktemp').chmod(0o700)
            elif failure in ('mkdir', 'cd'):
                # Failure or false success: in either case no fixture directory exists.
                (tools / 'mkdir').write_text('#!/bin/sh\nexit ' + ('1' if failure == 'mkdir' else '0') + '\n')
                (tools / 'mkdir').chmod(0o700)
            if failure == 'git-context':
                env['GIT_DIR'] = str(outer / '.git')
                env['GIT_WORK_TREE'] = str(outer)
            fixture = (HERE / 'contract.sh').read_text().split('echo "routed-pr-review — gate contract"', 1)[0]
            fixture = fixture.replace('SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
                                      'SELF_DIR=' + shlex.quote(str(HERE)), 1)
            result = subprocess.run(['/bin/bash', '-c', fixture + '\nprintf FIXTURE_READY\\n'],
                                    cwd=outer, env=env, capture_output=True, text=True, timeout=20)
            # Never let poisoned Git context affect our independent observer.
            env.pop('GIT_DIR', None)
            env.pop('GIT_WORK_TREE', None)
            after = (git('rev-parse', 'HEAD'), git('status', '--porcelain'), (outer / '.git/config').read_bytes())
            self.assertEqual(before, after, result.stderr)
            if failure:
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertNotIn('FIXTURE_READY', result.stdout)
            else:
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn('FIXTURE_READY', result.stdout)

    def test_failures_cannot_mutate_callers_repository(self):
        for failure in ('mktemp', 'mkdir', 'cd', 'git-context'):
            with self.subTest(failure=failure):
                self.check_fixture(failure)

    def test_successful_fixture_is_isolated(self):
        self.check_fixture(None)

if __name__ == '__main__':
    unittest.main(verbosity=2)
