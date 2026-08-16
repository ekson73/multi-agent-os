#!/usr/bin/env python3
"""ichnos — Agentic Usage Analytics (GA-style: attribution, RFM/retention, trend, funnel).

Answers the question corpus-firing-audit (Camada 0) does NOT: not just "did it fire",
but "HOW is it being found and used, over time, and is that usage sticky or one-shot?"
Composes corpus-firing-audit's log sources (same 3 vendors, same repo-local skills list)
and NEVER re-implements its FIRING/DORMANT classification — Ichnos consumes richer
(timestamped, per-hit) events from the same logs to add dimensions that classification
alone cannot answer.

GA-principle -> Ichnos mapping (see skills/ichnos/SKILL.md for the full table + rationale):
  Acquisition/channel  -> ATTRIBUTION: direct (/command) · explicit (Skill-tool-call) ·
                          referral (cited by another skill/agent/command/protocol's body)
  Impressions -> Clicks -> every skill is "shown" every session (listed in context);
                          CTR = hits / sessions-scanned (a proxy, not a true impression count)
  Recency / Frequency  -> RFM-LITE: days-since-last-hit, hits-in-window, distinct-active-days
  Trend                -> this-window vs prior-window (window = min(30, half the observed span))
  Funnel                -> named multi-step lifecycle chains, per-step hit presence (drop-off)
  Retention / Cohort   -> ONE-SHOT (active on exactly 1 distinct day) vs STICKY (>=2 distinct
                          days) -- corpus-firing-audit's raw total conflates a 1-day burst
                          of 10 hits with 10 hits spread over 10 weeks; this does not.

Explicitly OUT OF SCOPE for v1 (documented, not silently dropped -- Gordian/anti-over-eng):
  - Bounce rate (needs full intra-session tool-call sequencing to detect "invoked then
    abandoned with zero follow-through" -- a v2 item, tracked in the SKILL.md roadmap)
  - Goal/Conversion (needs cross-referencing PR-merged/ticket-closed outcomes to a given
    invocation -- a v2 item requiring a join against a DIFFERENT data source (gh/jira),
    not just these logs)
  - A/B testing of descriptions -- NOT rebuilt; that discipline already exists (the
    Gauntlet pairwise-critique method, `agentic-tool-evaluator`). Ichnos only PRIORITIZES
    which skills most need that treatment (Bucket-D-style: short description + low CTR).

Reuses corpus-firing-audit.py's safety patterns verbatim (fail-loud rg, self-session
exclusion, glob-dots-kills-everything guard) rather than re-deriving them.
Saída: docs/audits/ichnos-YYYY-MM-DD.md (dashboard) + stdout summary.
"""
import re, subprocess, sys, os, json
from datetime import date, datetime, timedelta
from collections import defaultdict

REPO = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                      capture_output=True, text=True).stdout.strip()
os.chdir(REPO)
TODAY = date.today()

# Self-session exclusion, identical rationale to corpus-firing-audit.py (Qodo #346 finding 3):
# derived from the environment, never hardcoded (a personal path does not belong in the repo).
_sess = os.environ.get('PI_SESSION_FILE', '')
_sess_dir = os.path.basename(os.path.dirname(_sess)) if _sess else ''
EXCLUDE_GLOB = f'!{_sess_dir}/**' if _sess_dir else '!__none__'

SKILLS = sorted(d for d in os.listdir('skills') if os.path.exists(f'skills/{d}/SKILL.md'))
SKILL_SET = set(SKILLS)


def rg_files(pattern, path):
    """List files containing `pattern` under `path`. Fail-loud on real rg errors
    (corpus-firing-audit's own guard: rc not in {0,1} is an error, never silence-to-zero)."""
    r = subprocess.run(['rg', '-l', pattern, path, '-g', '*.jsonl', '--glob', EXCLUDE_GLOB],
                       capture_output=True, text=True)
    if r.returncode not in (0, 1):
        raise RuntimeError(f'rg falhou rc={r.returncode}: {r.stderr[:200]}')
    return [l for l in r.stdout.splitlines() if l]


def parse_claude_events(files):
    events = []
    cmd_re = re.compile(r'<command-name>/(?:maos:)?([a-z0-9._-]+)</command-name>')
    skill_re = re.compile(r'"name":"Skill","input":\{"skill":"(?:maos:)?([a-z0-9._-]+)"')
    for path in files:
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    if '<command-name>' not in line and '"name":"Skill"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    ts = d.get('timestamp')
                    sid = d.get('sessionId') or os.path.basename(path)
                    for name in cmd_re.findall(line):
                        events.append((name, 'claude', 'direct', ts, sid))
                    for name in skill_re.findall(line):
                        events.append((name, 'claude', 'explicit', ts, sid))
        except OSError:
            continue
    return events


def parse_codex_events(files):
    events = []
    cmd_re = re.compile(r'"/([a-z][a-z0-9._-]{2,})"')
    for path in files:
        sid = os.path.basename(path)
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    if '"/' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    ts = d.get('timestamp')
                    for name in cmd_re.findall(line):
                        events.append((name, 'codex', 'direct', ts, sid))
        except OSError:
            continue
    return events


def parse_pi_events(files):
    events = []
    read_re = re.compile(r'skills/([a-z0-9._-]+)/SKILL\.md')
    for path in files:
        sid = os.path.basename(path)
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    if '"name":"read"' not in line or 'SKILL.md' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    ts = d.get('timestamp')
                    for name in read_re.findall(line):
                        events.append((name, 'pi', 'explicit', ts, sid))
        except OSError:
            continue
    return events


# --- 1. Collect timestamped events (attribution + RFM raw material) ---
claude_files = rg_files(r'<command-name>|"name":"Skill"', os.path.expanduser('~/.claude/projects'))
codex_files = rg_files(r'"/[a-z][a-z0-9._-]{2,}"', os.path.expanduser('~/.codex/sessions'))
pi_files = rg_files(r'"name":"read".*SKILL\.md', os.path.expanduser('~/.pi/agent/sessions'))

events = (parse_claude_events(claude_files)
          + parse_codex_events(codex_files)
          + parse_pi_events(pi_files))
events = [e for e in events if e[0] in SKILL_SET]  # only known skills

# --- 2. Referral / composed-reference attribution (grep other bodies for this skill's name) ---
def referral_count(skill):
    r = subprocess.run(
        ['rg', '-l', '--no-messages', rf'skills/{re.escape(skill)}\b|maos:{re.escape(skill)}\b',
         'agents', 'commands', 'skills', 'protocols'],
        capture_output=True, text=True, cwd=REPO)
    if r.returncode not in (0, 1):
        raise RuntimeError(f'rg (referral) falhou rc={r.returncode}: {r.stderr[:200]}')
    files = [f for f in r.stdout.splitlines() if f and f != f'skills/{skill}/SKILL.md'
             and not f.startswith(f'skills/{skill}/')]
    return len(files)


# --- 3. Aggregate per skill ---
per_skill = defaultdict(lambda: {'direct': 0, 'explicit': 0, 'sessions': set(), 'dates': set(),
                                  'last_ts': None, 'first_ts': None})
for name, vendor, channel, ts, sid in events:
    row = per_skill[name]
    row[channel] += 1
    row['sessions'].add((vendor, sid))
    if ts:
        try:
            dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
            row['dates'].add(dt.date().isoformat())
            if row['last_ts'] is None or ts > row['last_ts']:
                row['last_ts'] = ts
            if row['first_ts'] is None or ts < row['first_ts']:
                row['first_ts'] = ts
        except ValueError:
            pass

# --- 4. Trend window (adaptive: min(30d, half the observed span)) ---
all_dates = sorted({d for row in per_skill.values() for d in row['dates']})
if len(all_dates) >= 2:
    span_days = (date.fromisoformat(all_dates[-1]) - date.fromisoformat(all_dates[0])).days
    window = max(1, min(30, span_days // 2 or 1))
else:
    window = 30
cutoff_recent = TODAY - timedelta(days=window)
cutoff_prior = TODAY - timedelta(days=2 * window)


def in_window(dates, lo, hi):
    return sum(1 for d in dates if lo <= date.fromisoformat(d) <= hi)


# --- 5. Build per-skill row ---
rows = []
for s in SKILLS:
    row = per_skill.get(s)
    if row is None:
        rows.append({'skill': s, 'direct': 0, 'explicit': 0, 'referral': referral_count(s),
                      'sessions': 0, 'days_active': 0, 'recency_days': None,
                      'trend_recent': 0, 'trend_prior': 0, 'retention': 'NEVER'})
        continue
    total = row['direct'] + row['explicit']
    recency_days = None
    if row['last_ts']:
        try:
            last_date = datetime.fromisoformat(row['last_ts'].replace('Z', '+00:00')).date()
            recency_days = (TODAY - last_date).days
        except ValueError:
            pass
    trend_recent = in_window(row['dates'], cutoff_recent, TODAY)
    trend_prior = in_window(row['dates'], cutoff_prior, cutoff_recent - timedelta(days=1))
    retention = 'STICKY' if len(row['dates']) >= 2 else ('ONE-SHOT' if len(row['dates']) == 1 else 'NEVER')
    rows.append({'skill': s, 'direct': row['direct'], 'explicit': row['explicit'],
                 'referral': referral_count(s), 'sessions': len(row['sessions']),
                 'days_active': len(row['dates']), 'recency_days': recency_days,
                 'trend_recent': trend_recent, 'trend_prior': trend_prior, 'retention': retention})

# --- 6. Funnels (known lifecycle chains -- hardcoded by design; see SKILL.md §Funnels) ---
FUNNELS = {
    'genesis (forge -> evaluate -> train)': ['agentic-tool-forge', 'agentic-tool-evaluator', 'agentic-tool-trainer'],
    'quiesce-compose (quiesce -> auto-pilot -> bot-finding-arbiter -> converge)':
        ['quiesce', 'auto-pilot', 'bot-finding-arbiter', 'converge'],
}
by_skill = {r['skill']: r for r in rows}


def funnel_hits(name):
    r = by_skill.get(name)
    return (r['direct'] + r['explicit']) if r else 0


# --- 7. Write dashboard ---
os.makedirs('docs/audits', exist_ok=True)
out_path = f'docs/audits/ichnos-{TODAY.isoformat()}.md'
with open(out_path, 'w') as f:
    f.write(f'# Ichnos — Agentic Usage Analytics ({TODAY.isoformat()})\n\n')
    f.write(f'> Trend window: {window}d (adaptive to observed log span). '
            f'Composes corpus-firing-audit\'s log sources; adds attribution/RFM/trend/funnel '
            f'dimensions that a binary FIRING/DORMANT classification cannot answer.\n\n')
    f.write('## Attribution + RFM (per skill)\n\n')
    f.write('| skill | direct | explicit | referral | sessions | days_active | recency_d | '
            'trend(recent/prior) | retention |\n')
    f.write('|---|---|---|---|---|---|---|---|---|\n')
    for r in rows:
        f.write(f"| {r['skill']} | {r['direct']} | {r['explicit']} | {r['referral']} | "
                f"{r['sessions']} | {r['days_active']} | "
                f"{r['recency_days'] if r['recency_days'] is not None else '—'} | "
                f"{r['trend_recent']}/{r['trend_prior']} | {r['retention']} |\n")
    f.write('\n## Funnels (known lifecycle chains — hit-count per step, drop-off visible)\n\n')
    for fname, steps in FUNNELS.items():
        f.write(f'**{fname}**\n\n')
        f.write('| step | skill | hits |\n|---|---|---|\n')
        for i, st in enumerate(steps, 1):
            f.write(f'| {i} | {st} | {funnel_hits(st)} |\n')
        f.write('\n')
    f.write('## Roadmap (v2, explicitly out of scope for this version)\n\n')
    f.write('- **Bounce rate** — needs intra-session tool-call sequencing (invoked-then-abandoned).\n')
    f.write('- **Goal/Conversion** — needs a join against PR-merged/ticket-closed outcomes.\n')
    f.write('- **A/B testing** — not rebuilt; delegates to the existing Gauntlet/'
            '`agentic-tool-evaluator` method. Ichnos only prioritizes candidates for it.\n')

# --- 8. stdout summary ---
never = sum(1 for r in rows if r['retention'] == 'NEVER')
one_shot = sum(1 for r in rows if r['retention'] == 'ONE-SHOT')
sticky = sum(1 for r in rows if r['retention'] == 'STICKY')
referral_only = sum(1 for r in rows if r['retention'] == 'NEVER' and r['referral'] > 0)
isolated = sum(1 for r in rows if r['retention'] == 'NEVER' and r['referral'] == 0)
print(f'skills={len(rows)} STICKY={sticky} ONE-SHOT={one_shot} NEVER={never} '
      f'(of which referral-only={referral_only} truly-isolated={isolated})')
print(f'events_parsed={len(events)} (claude_files={len(claude_files)} '
      f'codex_files={len(codex_files)} pi_files={len(pi_files)})')
print(f'wrote {out_path}')
