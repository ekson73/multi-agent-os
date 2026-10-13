#!/usr/bin/env python3
"""Regression #494: successful matching and complete piped diagnostic output."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class OutputCompleteness(unittest.TestCase):
    def test_delegate_header_checks_do_not_sigpipe(self):
        source = (ROOT / 'tests/validate-plugin.sh').read_text()
        checks = source.split('    # Simulated cross-provider contexts', 1)[1].split('\n', 1)[1].split('    # Invalid --provider', 1)[0]
        with tempfile.TemporaryDirectory() as temporary:
            delegate = Path(temporary) / 'delegate.sh'
            delegate.write_text('''#!/bin/bash
case "$*" in
 *VKS-*) printf 'TICKET_PROVIDER=jira\\nVCS_PROVIDER=bitbucket\\n';;
 *VKO-*) printf 'TICKET_PROVIDER=linear\\nVCS_PROVIDER=github\\n';;
 *) printf 'TICKET_PROVIDER=none\\nVCS_PROVIDER=none\\n';;
esac
printf '%1000000s\\n' ''
''')
            script = '''set -uo pipefail
failed=0
pass() { :; }
fail() { echo "$*" >&2; failed=1; }
''' + checks + '\nexit "$failed"\n'
            result = subprocess.run(['bash', '-c', script], env={'PATH':os.environ['PATH'], 'DELEGATE_CLI':str(delegate)}, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_renderer_drains_delayed_pipe_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            preload = Path(temporary) / 'delay-output.cjs'
            preload.write_text('''const write = process.stdout.write.bind(process.stdout);
process.stdout.write = function (...args) {
  setTimeout(() => write(...args), 25);
  return true;
};
''')
            result = subprocess.run(['node', '--require', str(preload), str(ROOT/'bin/research-dossier-render.mjs'),
                '--ir', str(ROOT/'skills/research-dossier/examples/ir-dangling-refs.json'), '--gates-only'],
                env={'PATH':os.environ['PATH'], 'HOME':temporary}, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('EMPTY_NOT_CHECKED', result.stdout)
            self.assertIn('BUILD FAILED', result.stdout)

if __name__ == '__main__': unittest.main()
