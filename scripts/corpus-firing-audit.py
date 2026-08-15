#!/usr/bin/env python3
"""corpus-firing-audit — Camada 0 determinística (régua híbrido-ancorada, council 2026-08-15).

Conta FIRING estrutural de cada skill em logs reais de 3 vendors:
  Claude: <command-name>/x</command-name>  em ~/.claude/projects/**/*.jsonl
  Codex : "/x" em input_text              em ~/.codex/sessions/**/*.jsonl
  pi    : read tool-call do SKILL.md       em ~/.pi/agent/sessions/**/*.jsonl
          (sessão da própria auditoria EXCLUÍDA — auto-referência)

Word-boundary livre NUNCA promove a FIRING. Buckets: FIRING / DORMANT-NO-EVIDENCE.
Boundedness = regex-proxy rotulado. Frontmatter = YAML parse + name==dir + description.
Saída: docs/audits/audit-matrix-YYYY-MM-DD.md (tabela 83-row) + stdout summary.
"""
import re, subprocess, sys, yaml, os
from datetime import date

REPO = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                      capture_output=True, text=True).stdout.strip()
os.chdir(REPO)
TODAY = date.today().isoformat()
EXCLUDE = '!--Users-emilson-moraes-Projects--/**'  # sessão da auditoria (dashes! dots no glob mata tudo)

skills = sorted(d for d in os.listdir('skills') if os.path.exists(f'skills/{d}/SKILL.md'))

def hits(pattern, path):
    r = subprocess.run(['rg', '-o', '--no-filename', pattern, path,
                        '-g', '*.jsonl', '--glob', EXCLUDE],
                       capture_output=True, text=True)
    return r.stdout

def per_skill(vendor):
    out = {}
    if vendor == 'claude':
        raw = hits(r'<command-name>/[a-z0-9:._-]+</command-name>',
                   os.path.expanduser('~/.claude/projects'))
        names = re.findall(r'<command-name>/(?:maos:)?([a-z0-9._-]+)</command-name>', raw)
    elif vendor == 'codex':
        raw = hits(r'"/[a-z][a-z0-9._-]{2,}"', os.path.expanduser('~/.codex/sessions'))
        names = re.findall(r'"/([a-z][a-z0-9._-]{2,})"', raw)
    else:  # pi — invocação genuína = read tool-call do SKILL.md (preload nunca é tool-call)
        raw = hits(r'"name":"read","arguments":\{"path":"[^"]*skills/[a-z0-9._-]+/SKILL\.md',
                   os.path.expanduser('~/.pi/agent/sessions'))
        names = re.findall(r'skills/([a-z0-9._-]+)/SKILL\.md', raw)
    for n in names:
        out[n] = out.get(n, 0) + 1
    return out

C, X, P = per_skill('claude'), per_skill('codex'), per_skill('pi')

rows = []
for s in skills:
    txt = open(f'skills/{s}/SKILL.md').read()
    b = bool(re.search(r'DUED|sunset|max_iterations|exit.?condition|time.?box|stop.?condition|bail',
                       txt, re.I))
    try:
        d = yaml.safe_load(txt.split('---')[1])
        ok = d.get('name') == s and bool(d.get('description'))
    except Exception:
        ok = False
    c, x, p = C.get(s, 0), X.get(s, 0), P.get(s, 0)
    rows.append((s, c, x, p, c + x + p,
                 'bounded' if b else 'UNBOUNDED',
                 'valid' if ok else 'INVALID',
                 'FIRING' if c + x + p > 0 else 'DORMANT/NO-EVIDENCE'))

os.makedirs('docs/audits', exist_ok=True)
with open(f'docs/audits/audit-matrix-{TODAY}.md', 'w') as f:
    f.write('| skill | claude | codex | pi | firing_total | boundedness | frontmatter | bucket |\n')
    f.write('|---|---|---|---|---|---|---|---|\n')
    for r in rows:
        f.write('| ' + ' | '.join(map(str, r)) + ' |\n')

firing = [r for r in rows if r[7] == 'FIRING']
unb = sum(1 for r in rows if r[5] == 'UNBOUNDED')
inv = sum(1 for r in rows if r[6] != 'valid')
print(f"skills={len(rows)} FIRING={len(firing)} DORMANT={len(rows)-len(firing)} "
      f"UNBOUNDED={unb} INVALID={inv}")
print(f"claude_hits={sum(C.values())} codex_hits={sum(X.values())} pi_hits={sum(P.values())}")
