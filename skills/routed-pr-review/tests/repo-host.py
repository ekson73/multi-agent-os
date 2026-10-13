#!/usr/bin/env python3
"""Hermetic repository-host parsing and API/fetch binding checks."""
import json
import os
from pathlib import Path
import subprocess
import unittest
SUT = Path(__file__).resolve().parents[1] / 'bin/routed-review.sh'

class RepoHost(unittest.TestCase):
    def parse(self, value, host=''):
        source = SUT.read_text()
        self.assertIn('normalize_repo() {', source)
        function = source.split('normalize_repo() {', 1)[1].split('\n}\n', 1)[0]
        env = {'PATH': os.environ['PATH'], 'REPO': value, 'GH_HOST': host}
        return subprocess.run(['bash', '-c', 'normalize_repo() {' + function + '''
}
normalize_repo || exit 1
jq -n --arg host "$REPO_HOST" --arg path "$REPO_PATH" --arg repo "$REPO" --arg fetch "$REPO_FETCH_URL" '{host:$host,path:$path,repo:$repo,fetch:$fetch}'
'''], env=env, text=True, capture_output=True, timeout=10)

    def test_explicit_enterprise(self):
        r=self.parse('git.example.com/team/project')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout), {'host':'git.example.com','path':'team/project','repo':'git.example.com/team/project','fetch':'https://git.example.com/team/project.git'})

    def test_default_host_and_explicit_override(self):
        self.assertEqual(json.loads(self.parse('o/r').stdout)['host'], 'github.com')
        self.assertEqual(json.loads(self.parse('o/r','git.example.com').stdout)['host'], 'git.example.com')
        self.assertEqual(json.loads(self.parse('github.com/o/r','git.example.com').stdout)['host'], 'github.com')

    def test_unsafe_inputs_refuse(self):
        for value in ['x/y/z/w','evil@host/o/r','host/../r','o/r?x','https://host/o/r','-x/r','o/','host:44/o/r', 'github.com/o/r\nBAD?x', 'host\nBAD?/o/r', 'host/o\nBAD?/r', 'o/r\r', 'o/r\t', 'o/r\x01', '', 'o//r']:
            with self.subTest(value=value): self.assertNotEqual(self.parse(value).returncode,0)

    def test_actual_api_and_fetch_argv_share_host(self):
        source = SUT.read_text()
        functions = []
        for name in ('normalize_repo', 'ensure_commit', 'repo_reviewer_seen'):
            body = source.split(name + '() {', 1)[1].split('\n}\n', 1)[0]
            functions.append(name + '() {' + body + '\n}')
        script = '\n'.join(functions) + '''
exec 3>&1
git() { printf 'git %s\\n' "$*" >&3; return 1; }
gh() { printf 'gh %s\\n' "$*" >&3; printf '[]'; }
REPO=git.example.com/o/r; PR=1; KNOWN_BOTS_RE='^bot$'
normalize_repo || exit 1
ensure_commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/main
repo_reviewer_seen
'''
        result = subprocess.run(['bash', '-c', script], env={'PATH': os.environ['PATH']},
                                text=True, capture_output=True, timeout=10)
        self.assertIn('gh api --hostname git.example.com --paginate repos/o/r/pulls?', result.stdout)
        self.assertIn('git fetch --quiet --no-tags https://git.example.com/o/r.git refs/heads/main', result.stdout)
        self.assertNotIn('repos/git.example.com/', result.stdout)

    def test_api_and_fetch_share_validated_host(self):
        source=SUT.read_text()
        self.assertNotIn('https://github.com/$REPO.git', source)
        self.assertNotIn('"repos/$REPO/', source)
        self.assertIn('gh api --hostname "$REPO_HOST" --paginate "repos/$REPO_PATH/', source)
        self.assertIn('git fetch --quiet --no-tags "$REPO_FETCH_URL"', source)

if __name__ == '__main__': unittest.main()
