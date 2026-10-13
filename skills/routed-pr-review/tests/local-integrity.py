#!/usr/bin/env python3
"""Physical temporary roots and ignored-file integrity, synthetic/offline only."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

SUT = Path(__file__).resolve().parents[1] / 'bin/routed-review.sh'

class LocalIntegrity(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='rr-integrity-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.env = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': str(self.root),
                    'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'}
        for cmd in (['git', 'init', '-q'], ['git', 'config', 'user.email', 'fixture@example.invalid'],
                    ['git', 'config', 'user.name', 'fixture'], ['git', 'config', 'commit.gpgsign', 'false']):
            subprocess.run(cmd, cwd=self.repo, env=self.env, check=True)
        (self.repo / '.gitignore').write_text('ignored/\n')
        subprocess.run(['git', 'add', '.gitignore'], cwd=self.repo, env=self.env, check=True)
        subprocess.run(['git', 'commit', '-qm', 'fixture'], cwd=self.repo, env=self.env, check=True)

    def test_tmpdir_inside_checkout_refused_before_any_temp_creation(self):
        source = SUT.read_text()
        prelude = source.split('STATE_FILE=', 1)[0]
        inside = self.repo / 'ignored'
        inside.mkdir()
        link = self.root / 'link'
        link.symlink_to(inside, target_is_directory=True)
        for path in (self.repo, inside, link):
            with self.subTest(path=path):
                env = dict(self.env, TMPDIR=str(path))
                result = subprocess.run(['/bin/bash', '-c', prelude + '\nprintf REACHED'], cwd=self.repo,
                                        env=env, text=True, capture_output=True)
                self.assertEqual(1, result.returncode, result.stdout + result.stderr)
                self.assertIn('outside', result.stderr)
                self.assertNotIn('REACHED', result.stdout)
                self.assertEqual([], list(inside.iterdir()))
        result = subprocess.run(['/bin/bash', '-c', prelude + '\nprintf REACHED'], cwd=self.repo,
                                env=dict(self.env, TMPDIR=str(self.root)), text=True, capture_output=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('REACHED', result.stdout)

    def test_preexisting_ignored_bytes_and_symlink_target_are_observed(self):
        source = SUT.read_text()
        function = source[source.index('live_repo_state() {'):source.index('snapshot_live_repo() {')]
        ignored = self.repo / 'ignored'
        ignored.mkdir()
        file = ignored / 'canary'
        file.write_text('before')
        link = ignored / 'link'
        link.symlink_to('canary')
        def snapshot():
            result = subprocess.run(['/bin/bash', '-c', 'set -o pipefail\nHASH_CMD=(shasum -a 256)\n' + function + '\nlive_repo_state'],
                                    cwd=self.repo, env=self.env, capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)
            return result.stdout
        first = snapshot()
        file.write_text('after')
        second = snapshot()
        self.assertNotEqual(first, second, 'Ignored-file mutation was invisible')
        link.unlink()
        link.symlink_to('missing')
        self.assertNotEqual(second, snapshot(), 'Ignored symlink mutation was invisible')

    def test_ignored_fifo_refuses_instead_of_hanging(self):
        source = SUT.read_text()
        function = source[source.index('live_repo_state() {'):source.index('snapshot_live_repo() {')]
        ignored = self.repo / 'ignored'
        ignored.mkdir()
        os.mkfifo(ignored / 'fifo')
        result = subprocess.run(['/bin/bash', '-c', 'set -o pipefail\nHASH_CMD=(shasum -a 256)\n' + function + '\nlive_repo_state'],
                                cwd=self.repo, env=self.env, capture_output=True, timeout=5)
        self.assertNotEqual(0, result.returncode)

if __name__ == '__main__':
    unittest.main(verbosity=2)
