#!/usr/bin/env python3
"""Offline regression tests for the real dispatcher state/TTL functions."""
from pathlib import Path
import os
import json
import hashlib
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

SOURCE = (Path(__file__).resolve().parents[1] / 'bin/routed-review.sh').read_text()


def function(name):
    return re.search(r'^' + name + r'\(\).*?^}', SOURCE, re.M | re.S).group(0)


class StateSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rr-state-safety-')
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'state.json'
        self.path.write_text('{"bots":{}}')
        safe_bin = Path(self.temp.name) / 'tools'
        safe_bin.mkdir()
        for command in ('jq', 'timeout'):
            source = shutil.which(command) or (shutil.which('gtimeout') if command == 'timeout' else None)
            self.assertIsNotNone(source, command)
            (safe_bin / command).symlink_to(source)
        hash_tool = 'shasum' if shutil.which('shasum') else 'sha256sum'
        hash_source = shutil.which(hash_tool)
        self.assertIsNotNone(hash_source, 'shasum or sha256sum is required')
        (safe_bin / hash_tool).symlink_to(hash_source)
        self.hash_cmd = [hash_tool, '-a', '256'] if hash_tool == 'shasum' else [hash_tool]
        home = Path(self.temp.name) / 'home'
        home.mkdir()
        # Never inherit reviewer, shell-startup, git or harness overrides.
        self.env = {'PATH': str(safe_bin) + ':/usr/bin:/bin:/usr/sbin:/sbin',
                    'HOME': str(home), 'TMPDIR': self.temp.name, 'LC_ALL': 'C'}

    def run_bash(self, body, extra=''):
        script = '\n'.join((
            'set -uo pipefail', 'STATE_FILE="$1"',
            'TIMEOUT_CMD=$(command -v timeout || command -v gtimeout)',
            'HASH_CMD=(' + ' '.join(shlex.quote(arg) for arg in self.hash_cmd) + ')',
            function('sha256_stdin'), function('read_state'), function('state_digest'),
            function('verify_state_untouched'), 'log() { :; }', extra, body))
        return subprocess.run(['bash', '-c', script, 'state-test', str(self.path)],
                              text=True, capture_output=True, timeout=5, env=self.env)

    def test_setup_and_digest_support_sha256sum_without_shasum(self):
        which = shutil.which
        fallback = which('sha256sum')
        if fallback is None:
            # A shasum-only host can still exercise the fallback command shape.
            fallback = str(Path(self.temp.name) / 'sha256sum')
            Path(fallback).write_text('#!/bin/sh\nexec ' + shlex.quote(which('shasum')) + ' -a 256 "$@"\n')
            Path(fallback).chmod(0o700)
        with patch('shutil.which', side_effect=lambda name: None if name == 'shasum' else
                   fallback if name == 'sha256sum' else which(name)):
            probe = StateSafetyTests('test_regular_and_absent_are_distinct_valid_digests')
            self.addCleanup(probe.doCleanups)
            probe.setUp()
            self.assertEqual(['sha256sum'], probe.hash_cmd)
            result = probe.run_bash('state_digest')
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(hashlib.sha256(probe.path.read_bytes()).hexdigest(), result.stdout)

    def test_record_failure_initializes_empty_or_absent_regular_state(self):
        for kind in ('absent', 'empty', 'whitespace'):
            with self.subTest(kind=kind):
                if kind == 'absent':
                    self.path.unlink()
                else:
                    self.path.write_text(' \t\r\n  \n' if kind == 'whitespace' else '')
                result = self.run_bash('record_failure kimi broken auth', function('record_failure'))
                self.assertEqual(0, result.returncode, result.stderr)
                state = json.loads(self.path.read_text())
                self.assertEqual('auth', state['bots']['kimi']['broken_reason'])
                self.assertRegex(state['bots']['kimi']['broken_at'], r'^\d{4}-\d{2}-\d{2}T')
                self.assertFalse(Path(str(self.path) + '.lock').exists())

    def test_record_failure_preserves_invalid_json(self):
        for invalid in ('{not valid JSON\n', '\v', '\f'):
            with self.subTest(invalid=repr(invalid)):
                self.path.write_text(invalid)
                result = self.run_bash('record_failure kimi broken auth', function('record_failure'))
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(invalid, self.path.read_text())
                self.assertFalse(Path(str(self.path) + '.lock').exists())

    def test_regular_and_absent_are_distinct_valid_digests(self):
        result = self.run_bash('state_digest')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertRegex(result.stdout, r'^[0-9a-f]{64}$')
        self.path.unlink()
        self.assertEqual('absent', self.run_bash('state_digest').stdout)

    def test_nonregular_state_is_rejected_without_hanging(self):
        for kind in ('fifo', 'directory', 'symlink'):
            with self.subTest(kind=kind):
                if self.path.is_dir():
                    self.path.rmdir()
                else:
                    self.path.unlink(missing_ok=True)
                if kind == 'fifo':
                    os.mkfifo(self.path)
                elif kind == 'directory':
                    self.path.mkdir()
                else:
                    self.path.symlink_to('/dev/zero')
                self.assertNotEqual(0, self.run_bash('state_digest').returncode)

    def test_substitution_after_regular_check_is_bounded(self):
        # A synthetic race at the pathname type check: the open itself must be
        # inside the timeout, not just the command reading an already-open fd.
        extra = '''function [() {
  if [[ "$#" == 3 && "$1" == -f && "$2" == "$RACE_PATH" ]]; then
    rm "$RACE_PATH"; mkfifo "$RACE_PATH"
    return 0
  fi
  builtin [ "$@"
}
export -f '['
export RACE_PATH="$STATE_FILE"
'''
        result = self.run_bash('state_digest', extra)
        self.assertNotEqual(0, result.returncode, result.stdout)

    def test_hash_failure_cannot_compare_equal(self):
        result = self.run_bash('STATE_BEFORE="$(state_digest)"; verify_state_untouched',
                               'HASH_CMD=(false)')
        self.assertNotEqual(0, result.returncode)

    def test_hash_descendants_cannot_outlive_read_deadline(self):
        result = self.run_bash('state_digest', "HASH_CMD=(bash -c 'trap \"\" TERM; sleep 20')")
        self.assertNotEqual(0, result.returncode)

    def test_mocked_dispatch_rejects_initial_fifo_and_reviewer_substitution(self):
        # Reuse only the inspected contract harness scaffold, never its cases.
        tests = Path(__file__).resolve().parent
        scaffold = (tests / 'contract.sh').read_text().split('# ── 1 ──', 1)[0]
        sut = tests.parent / 'bin/routed-review.sh'
        scaffold = re.sub(r'SUT="[^"\n]+"', 'SUT=' + shlex.quote(str(sut)), scaffold, count=1)
        old = '''[ -n "${T_TAMPER_PATH:-}" ] && printf '%s' "${T_TAMPER_JSON:-}" > "$T_TAMPER_PATH" 2>/dev/null'''
        self.assertIn(old, scaffold)
        scaffold = scaffold.replace(old, '[ -n "${T_TAMPER_PATH:-}" ] && { rm -f "$T_TAMPER_PATH"; mkfifo "$T_TAMPER_PATH"; }')
        body = r'''
BROKEN_SBX="$SANDBOX/no-sandbox"; mkdir -p "$BROKEN_SBX"
printf '#!/bin/sh\nexit 1\n' > "$BROKEN_SBX/sandbox-exec"; chmod +x "$BROKEN_SBX/sandbox-exec"
STATE="$SANDBOX/state/fifo.json"; mkfifo "$STATE"
OUT="$(EXTRA_BIN="$BROKEN_SBX" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "initial FIFO fails before dispatch" 1
[ -p "$STATE" ] || exit 1
rm "$STATE"; printf '{"bots":{"kimi":{"broken_at":"2020-01-01T00:00:00Z"}}}' > "$STATE"
OUT="$(EXTRA_BIN="$BROKEN_SBX" RV=auto ROUTED_REVIEW_BROKEN_TTL_SEC=09 T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "decimal TTL allows an expired broken reviewer" 3 '.status' 'reviewed'
OUT="$(EXTRA_BIN="$BROKEN_SBX" RV=auto ROUTED_REVIEW_BROKEN_TTL_SEC=$'1\n+PR[$(printf AUDIT_MARKER >&2)0]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "TTL arithmetic payload is rejected without execution" 3 '.status' 'reviewed'
! grep -q AUDIT_MARKER "$SANDBOX/err" || exit 1
jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg retry $'1\n+since[$(printf AUDIT_MARKER >&2)0]' '{bots:{kimi:{last_limited_at:$at,retry_after_sec:$retry}}}' > "$STATE"
OUT="$(EXTRA_BIN="$BROKEN_SBX" RV=auto T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "retry arithmetic payload is rejected without execution" 3 '.status' 'reviewed'
! grep -q AUDIT_MARKER "$SANDBOX/err" || exit 1
printf '{"bots":{}}' > "$STATE"
OUT="$(EXTRA_BIN="$BROKEN_SBX" T_TAMPER_PATH="$STATE" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "reviewer FIFO substitution is isolation violation" 1 '.detail' 'violated:state-file'
[ -p "$STATE" ] || exit 1
[ "$FAIL" -eq 0 ]
'''
        result = subprocess.run(['/bin/bash', '-c', scaffold + body], env=self.env,
                                text=True, capture_output=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_record_failure_does_not_open_special_state_for_writing(self):
        target = Path(self.temp.name) / 'target.json'
        target.write_text('{"untouched":true}')
        for kind in ('fifo', 'directory', 'symlink'):
            with self.subTest(kind=kind):
                if self.path.is_dir():
                    self.path.rmdir()
                else:
                    self.path.unlink(missing_ok=True)
                if kind == 'fifo':
                    os.mkfifo(self.path)
                elif kind == 'directory':
                    self.path.mkdir()
                else:
                    self.path.symlink_to(target)
                result = self.run_bash('record_failure kimi broken auth', function('record_failure'))
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual('{"untouched":true}', target.read_text())
                self.assertFalse(Path(str(self.path) + '.lock').exists())
                if kind == 'directory':
                    self.assertEqual([], list(self.path.iterdir()))

    def test_retry_rejects_multiline_arithmetic_and_preserves_decimal(self):
        for raw, expected in [('09', 0), ('86400', 0), ('86401', 1),
                              ('100000', 1), ('9\n+1', 1), ('9\n', 1),
                              ('\n9', 1), ('9\r', 1), ('-1', 1),
                              ('1\n+since[$(printf AUDIT_MARKER >&2)0]', 1)]:
            with self.subTest(raw=raw):
                self.path.write_text(json.dumps({'bots': {'kimi': {
                    'last_limited_at': 'fixture', 'retry_after_sec': raw}}}))
                extra = function('expired') + '\nts_epoch() { date +%s; }'
                result = self.run_bash('expired kimi', extra)
                self.assertEqual(expected, result.returncode, result.stderr)
                self.assertNotIn('AUDIT_MARKER', result.stderr)

    def test_retry_does_not_concatenate_multiple_json_documents(self):
        at = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        documents = [{'bots': {'kimi': {'retry_after_sec': 9}}},
                     {'bots': {'kimi': {'last_limited_at': at, 'retry_after_sec': 9}}}]
        self.path.write_text('\n'.join(json.dumps(document) for document in documents))
        extra = function('expired') + '\n' + function('ts_epoch')
        result = self.run_bash('expired kimi', extra)
        self.assertEqual(1, result.returncode, result.stderr)

    def test_ttl_uses_decimal_and_preserves_validation_bounds(self):
        block = SOURCE.split('BROKEN_TTL="', 1)[1].split('EXCLUDED=', 1)[0]
        for raw, expected in [('09', 9), ('000009', 9), ('010', 10), ('0', 0),
                              ('999999', 999999), ('1000000', 86400),
                              ('-1', 86400), ('bad', 86400), ('', 86400),
                              ('1\n+1000000', 86400), ('9\n+1', 86400),
                              ('9\n', 86400), ('\n9', 86400), ('9\r', 86400),
                              ('1\n+PR[$(printf AUDIT_MARKER >&2)0]', 86400)]:
            with self.subTest(raw=raw):
                script = 'set -u\nPR=1\nBROKEN_TTL="' + block + '\nprintf "%s" "$((100 + BROKEN_TTL))"'
                result = subprocess.run(['bash', '-c', script], capture_output=True, text=True,
                                        env={**self.env, 'ROUTED_REVIEW_BROKEN_TTL_SEC': raw})
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(str(100 + expected), result.stdout)
                self.assertNotIn('AUDIT_MARKER', result.stderr)


if __name__ == '__main__':
    unittest.main()
