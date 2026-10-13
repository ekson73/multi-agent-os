#!/usr/bin/env python3
"""Offline tests of the actual review-evidence functions (no provider dispatch)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SUT = Path(__file__).resolve().parents[1] / 'bin/routed-review.sh'
HEAD = 'a' * 40

def review(state='APPROVED', login='coderabbitai', sha=HEAD, timestamp='2026-10-13T12:00:00Z'):
    return dict(state=state, user={'login': login}, commit_id=sha, submitted_at=timestamp, id=1)

class Evidence(unittest.TestCase):
    def run_probe(self, history, latest=None, failed=False, repo=False, pulls=None):
        source = SUT.read_text()
        primary = source.split('compute_primaries() {', 1)[1].split('\ncompute_primaries\n', 1)[0]
        corroboration = source.split('repo_reviewer_seen() {', 1)[1].split('\n}\n', 1)[0] + '\n}'
        with tempfile.TemporaryDirectory() as directory:
            env = {'PATH': os.environ['PATH'], 'HOME': directory, 'LC_ALL': 'C'}
            env.update(HISTORY=history, LATEST=json.dumps(latest or []), FAIL=str(int(failed)),
                       PULLS=json.dumps(pulls if pulls is not None else [{'number': 2}]))
            script = '''gh() {
case "$*" in
 */reviews*) printf '%s' "$HISTORY"; return "$FAIL";;
 *'/pulls?'*) printf '%s' "$PULLS";;
 *) printf '[]';;
esac
}
HEAD_SHA=''' + HEAD + '''
REPO=o/r; PR=1; PRIMARIES=coderabbitai
KNOWN_BOTS_RE='^(coderabbitai)(\\[bot\\])?$'; PRIMARY_RE="$KNOWN_BOTS_RE"
PR_JSON="$(jq -n --argjson rv "$LATEST" '{latestReviews:$rv,comments:[],reviewDecision:""}')"
compute_primaries() {''' + primary + '\nrepo_reviewer_seen() {' + corroboration
            script += '\nrepo_reviewer_seen; echo "$?"' if repo else '''
compute_primaries
jq -n --arg cleared "$CLEARED" --arg changes "$CHANGES_REQ" '{cleared:$cleared,changes:$changes}'
'''
            result = subprocess.run(['bash', '-c', script], env=env, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            return int(result.stdout) if repo else json.loads(result.stdout)

    def test_fresh_history_overrides_stale_projection(self):
        result = self.run_probe(json.dumps([review()]))
        self.assertEqual(result['cleared'], 'coderabbitai')

    def test_stale_projection_cannot_clear_withdrawn_approval(self):
        latest = [{'author': {'login': 'coderabbitai'}, 'commit': {'oid': HEAD}, 'state': 'APPROVED'}]
        result = self.run_probe(json.dumps([review('DISMISSED')]), latest)
        self.assertEqual(result['cleared'], '')

    def test_pagination_retains_blocking_review(self):
        result = self.run_probe('[]\n' + json.dumps([review('CHANGES_REQUESTED')]))
        self.assertEqual(result['changes'], 'yes')

    def test_partial_failure_and_malformed_fail_closed(self):
        for payload, failed in [('[]', True), ('{}', False), ('[{}]', False), ('', False),
                                (json.dumps([review(timestamp='bad')]), False)]:
            with self.subTest(payload=payload, failed=failed):
                self.assertEqual(self.run_probe(payload, failed=failed)['changes'], 'unknown')

    def test_prior_head_never_clears(self):
        self.assertEqual(self.run_probe(json.dumps([review(sha='b'*40)]))['cleared'], '')

    def test_empty_repository_is_not_error(self):
        self.assertEqual(self.run_probe("[]", repo=True, pulls=[]), 1)

    def test_submitted_review_contradicts_absence(self):
        self.assertEqual(self.run_probe(json.dumps([review()]), repo=True), 0)

    def test_repository_empty_endpoint_is_unknown(self):
        for payload in ("", " ", "{}", "[{}]"):
            with self.subTest(payload=payload):
                self.assertEqual(self.run_probe(payload, repo=True), 2)

    def test_repository_partial_failure_is_unknown(self):
        self.assertEqual(self.run_probe('[]', failed=True, repo=True), 2)

if __name__ == '__main__':
    unittest.main()
