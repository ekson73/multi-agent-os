#!/usr/bin/env python3
"""
postflight scorecard renderer — deterministic end-of-action status cards.

ONE renderer · ONE param schema · 7 layout MODELS. Design contract:
  - DETERMINISTIC: same params -> same output (no clock unless passed in).
  - SELF-CALCULATING: auto-derives git/PR facts + the autonomy pulse + bars
    from numbers, so an AI agent only supplies what cannot be computed.
  - AI-PARAMETERIZED: the qualitative items (verdict, checklist, notes,
    confidence, what's-left) arrive as a JSON params blob (file/stdin).
  - HUMAN-GLANCEABLE: 5-state colour legend (🔴🟡🟠🟢🔵) + bars + tally.
  - PORTABLE: stdlib only; NO_COLOR / --no-color honoured; emoji carry colour
    so it renders in any terminal AND in GitHub/markdown.

Usage:
  scorecard.py --model N [--params FILE|-] [--demo] [--auto-git] [--repo DIR]
               [--no-color] [--all]
  echo '<json>' | scorecard.py --model 2
  scorecard.py --all --demo            # render every model with demo data

Param schema (all keys optional; sane fallbacks):
  {
    "session":  {"title","id","date","time","duration"},
    "verdict":  {"state":"done|warn|blocked|wip", "label":"DONE · green · merged"},
    "autonomy": {"green":N,"blue":N,"orange":N,"red":N},      # pulse tally
    "vitals":   [{"label","icon","pct":0-100,"note"}],
    "checklist":[{"state":"green|blue|orange|yellow|red","label","note","confidence":0-100|null}],
    "whats_left":[{"state":"done|orange|red|yellow","text"}]
  }
"""
import argparse, json, os, sys, subprocess, datetime, re

# ── 5-state legend (icon · human-word · machine-token · ansi-256) ─────────────
STATE = {
    "red":    ("🔴", "not-started", "not_started",  196),
    "yellow": ("🟡", "in-progress", "in_progress",  226),
    "orange": ("🟠", "need-HITL",   "need_hitl",    208),
    "green":  ("🟢", "done-IA",     "done_agentic",  46),
    "blue":   ("🔵", "done-human",  "done_human",    39),
}
ALIAS = {"done": "green", "agentic": "green", "human": "blue", "hitl": "orange",
         "doing": "yellow", "wip": "yellow", "todo": "red", "blocked": "red",
         "warn": "orange", "closed": "green", "open": "yellow", "review": "orange",
         "in-progress": "yellow", "in_progress": "yellow", "merged": "green"}
VERDICT_ICON = {"done": "✅", "warn": "⚠️", "blocked": "🛑", "wip": "🟡"}


def st(key):
    return STATE.get(ALIAS.get(key, key), STATE["green"])


# ── colour + width helpers ────────────────────────────────────────────────────
COLOR = True


def c(text, code=None, bold=False, dim=False):
    if not COLOR:
        return text
    pre = ""
    if bold:
        pre += "\033[1m"
    if dim:
        pre += "\033[2m"
    if code is not None:
        pre += f"\033[38;5;{code}m"
    return f"{pre}{text}\033[0m" if pre else text


_WIDE = re.compile(
    "[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U00002B00-\U00002BFF✅❌✔✖⚠]"
)


def vlen(s):
    """visual width: emoji/symbols ~2, variation-selectors 0, else 1."""
    s = re.sub("\033\\[[0-9;]*m", "", s)  # strip ansi
    w = 0
    for ch in s:
        if ch == "️":
            continue
        w += 2 if _WIDE.match(ch) else 1
    return w


def pad(s, width):
    return s + " " * max(0, width - vlen(s))


def bar(pct, width=10, code=46):
    pct = max(0, min(100, int(round(pct))))
    fill = int(round(pct / 100 * width))
    return c("█" * fill, code) + c("▒" * (width - fill), 240)


def dot(state):
    return st(state)[0]


def pulse_pct(a):
    tot = sum(a.get(k, 0) for k in ("green", "blue", "orange", "red"))
    return (100 * (a.get("green", 0) + a.get("blue", 0)) / tot) if tot else 0


def green_pct(a):
    tot = sum(a.get(k, 0) for k in ("green", "blue", "orange", "red"))
    return (100 * a.get("green", 0) / tot) if tot else 0


# ── deterministic git/PR self-calculation (graceful) ─────────────────────────
def _run(args, cwd, timeout=6):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                              timeout=timeout).stdout.strip()
    except Exception:
        return ""


def git_facts(repo):
    g = ["git", "-C", repo]
    out = {}
    top = _run(g + ["rev-parse", "--show-toplevel"], repo)
    if not top:
        return out
    out["repo"] = os.path.basename(top)
    out["branch"] = _run(g + ["rev-parse", "--abbrev-ref", "HEAD"], repo)
    lr = _run(g + ["rev-list", "--left-right", "--count", "@{u}...HEAD"], repo)
    if lr and "\t" in lr:
        b, a = lr.split("\t")[:2]
        out["behind"], out["ahead"] = int(b or 0), int(a or 0)
    dirty = _run(g + ["status", "--porcelain"], repo)
    out["dirty"] = len([x for x in dirty.splitlines() if x.strip()])
    wl = _run(g + ["worktree", "list"], repo)
    out["worktrees"] = len(wl.splitlines())
    out["head"] = _run(g + ["log", "--oneline", "-1"], repo)
    prs = _run(["gh", "pr", "list", "--state", "open", "--json", "number"], repo)
    try:
        out["open_prs"] = len(json.loads(prs)) if prs else 0
    except Exception:
        out["open_prs"] = None
    return out


# ── demo params (this session) ───────────────────────────────────────────────
DEMO = {
    "session": {"title": "cross-ref end-of-action-* policy ⇄ postflight executable",
                "id": "49702159", "date": "2026-06-09", "time": "22:07", "duration": "~25min"},
    "verdict": {"state": "done", "label": "DONE · green · merged"},
    "autonomy": {"green": 5, "blue": 1, "orange": 0, "red": 0},
    "vitals": [
        {"icon": "📦", "label": "Escopo",   "pct": 100, "note": "já existia (PRs #114-#121)"},
        {"icon": "🎯", "label": "Entregue", "pct": 100, "note": "1/1 remnant (§B-row-3)"},
        {"icon": "🔀", "label": "PR #138",  "pct": 100, "note": "MERGED · squash · c568d40"},
        {"icon": "✅", "label": "Checks",   "pct": 100, "note": "gitleaks ✓ · amazon-q ✓"},
        {"icon": "⚠️", "label": "Risco",    "pct": 10,  "note": "baixo · docs-only · sem deploy"},
    ],
    "checklist": [
        {"state": "green",  "label": "Reuse-verify", "note": "escopo já merged · nada reinventado", "confidence": 97},
        {"state": "blue",   "label": "Decisão escopo", "note": "build-novo vs confirmar → você (HITL)", "confidence": None},
        {"state": "green",  "label": "Remnant §B", "note": "cross-ref PATCH (1.1.1 + 1.3.1)", "confidence": 95},
        {"state": "green",  "label": "PR/merge", "note": "auto-merge sob standing-auth", "confidence": 93},
        {"state": "green",  "label": "persisted?", "note": "origin/main + ledger + plan", "confidence": 99},
        {"state": "green",  "label": "boy-scout?", "note": "worktree+branch removidos · MAOS 0/0", "confidence": 99},
    ],
    "whats_left": [
        {"state": "done",   "text": "Nada nesta tarefa — fechada."},
        {"state": "orange", "text": "(opcional) housekeeping ~/.claude: index.lock stale · 5 worktrees órfãos"},
    ],
    "tickets": [
        {"id": "PROJ-204", "status": "closed",      "title": "spec round-2 — as-built fidelity"},
        {"id": "PROJ-211", "status": "in-progress", "title": "POC: dev branch + protections"},
        {"id": "PROJ-218", "status": "review",      "title": "add module test oracles"},
        {"id": "PROJ-220", "status": "open",        "title": "capture infra config in VC"},
    ],
}


def load_params(args):
    if args.demo:
        return DEMO
    raw = ""
    if args.params == "-":
        raw = sys.stdin.read()
    elif args.params:
        raw = open(args.params, encoding="utf-8").read()
    if not raw.strip():
        return DEMO
    return json.loads(raw)


def enrich(d, args):
    d.setdefault("session", {})
    if args.auto_git:
        g = git_facts(args.repo or ".")
        d["_git"] = g
    else:
        d["_git"] = {}
    d.setdefault("verdict", {"state": "done", "label": "DONE"})
    d.setdefault("autonomy", {"green": 0, "blue": 0, "orange": 0, "red": 0})
    d.setdefault("vitals", [])
    d.setdefault("checklist", [])
    d.setdefault("whats_left", [])
    d.setdefault("tickets", [])
    return d


# ── shared fragments ─────────────────────────────────────────────────────────
def legend_line():
    return "  ".join(f"{i} {w}" for i, w, *_ in (st(k) for k in
                     ("red", "yellow", "orange", "green", "blue")))


def pulse_line(a):
    seq = (dot("green") * a["green"] + " " + dot("blue") * a["blue"] + " "
           + dot("orange") * a["orange"] + " " + dot("red") * a["red"]).strip()
    tot = a["green"] + a["blue"] + a["orange"] + a["red"]
    tally = f"{a['green']}🟢 · {a['blue']}🔵 · {a['orange']}🟠 · {a['red']}🔴"
    return seq, tally, tot, green_pct(a)


def sess_head(s):
    t = s.get("title", "session")
    meta = " · ".join(x for x in (s.get("date"), s.get("time"), s.get("duration")) if x)
    return t, meta


def conf(item):
    cf = item.get("confidence")
    return f"{cf}%" if isinstance(cf, (int, float)) else "──"


def tk_list(d):
    return d.get("tickets", []) or []


def tk_counts(d):
    tk = tk_list(d)
    done = sum(1 for t in tk if ALIAS.get(t.get("status"), t.get("status")) in ("green", "blue"))
    return done, len(tk)


def tk_summary(d):
    tk = tk_list(d)
    return "  ".join(f"{dot(t.get('status','green'))} {t.get('id','?')}" for t in tk) if tk else None


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 1 — "Cockpit" : rich left-framed card (verdict band · vitals · checklist
#                       · pulse · what's-left). Best for substantive sessions.
# ══════════════════════════════════════════════════════════════════════════════
def model_1(d):
    s = d["session"]; t, meta = sess_head(s)
    a = d["autonomy"]; _, _, _, gp = pulse_line(a)
    vi = VERDICT_ICON.get(d["verdict"].get("state"), "•")
    L = []
    L.append(c("┏━━ 🛬 END-OF-ACTION SCORECARD " + "━" * 8, 244))
    L.append(c("┃ ", 244) + c(t, bold=True))
    L.append(c("┃ ", 244) + c(meta, dim=True))
    L.append(c("┣" + "━" * 38, 244))
    L.append(c("┃ ", 244) + c("VERDICT ", dim=True) + f"{vi} " + c(d["verdict"].get("label", ""), 46, bold=True)
              + "   " + c("autonomy ", dim=True) + bar(gp, 10) + f" {gp:.0f}%")
    L.append(c("┃", 244))
    L.append(c("┃ ", 244) + c("VITALS", 244, bold=True))
    for v in d["vitals"]:
        L.append(c("┃  ", 244) + f"{v.get('icon','•')} " + pad(v.get("label", ""), 9)
                 + bar(v.get("pct", 0), 10) + "  " + c(v.get("note", ""), dim=True))
    L.append(c("┃", 244))
    L.append(c("┃ ", 244) + c("CHECKLIST", 244, bold=True))
    for it in d["checklist"]:
        L.append(c("┃  ", 244) + f"{dot(it['state'])} " + pad(it.get("label", ""), 16)
                 + c(pad(it.get("note", ""), 40), dim=True) + c(conf(it), 46))
    if tk_list(d):
        L.append(c("┃", 244))
        dn, tt = tk_counts(d)
        L.append(c("┃ ", 244) + c(f"TICKETS  ({dn}/{tt} done)", 244, bold=True))
        for t in tk_list(d):
            L.append(c("┃  ", 244) + f"{dot(t.get('status','green'))} " + pad(t.get("id", "?"), 12)
                     + c(t.get("title", ""), dim=True))
    L.append(c("┃", 244))
    seq, tally, tot, _ = pulse_line(a)
    L.append(c("┃ ", 244) + c("PULSE ", 244, bold=True) + seq + "   " + c(tally, dim=True))
    L.append(c("┃", 244))
    L.append(c("┃ ", 244) + c("WHAT'S LEFT", 244, bold=True))
    for w in d["whats_left"]:
        mark = "✔" if w["state"] == "done" else dot(w["state"])
        L.append(c("┃  ", 244) + f"{mark} " + w.get("text", ""))
    L.append(c("┗" + "━" * 38, 244))
    L.append(c("  " + legend_line(), dim=True))
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 2 — "Traffic-Light Strip" : ultra-compact, no boxes, one line per item.
#                       Best for quick sessions / inline / chat.
# ══════════════════════════════════════════════════════════════════════════════
def model_2(d):
    s = d["session"]; t, meta = sess_head(s)
    a = d["autonomy"]; seq, tally, tot, gp = pulse_line(a)
    vi = VERDICT_ICON.get(d["verdict"].get("state"), "•")
    L = [f"{vi} {c(d['verdict'].get('label',''),46,bold=True)}  ·  {c(t,dim=True)}  ·  {c(meta,dim=True)}"]
    L.append("")
    for it in d["checklist"]:
        line = f"{dot(it['state'])} {pad(it.get('label',''),16)} {c('·',240)} {pad(it.get('note',''),42,)}"
        L.append(line + c(conf(it).rjust(4), 46))
    ts = tk_summary(d)
    if ts:
        dn, tt = tk_counts(d)
        L.append(f"{c('tickets',244)} {ts}   {c(f'({dn}/{tt} done)',dim=True)}")
    L.append("")
    L.append(f"{c('pulse',244)} {seq}  {bar(gp,10)} {gp:.0f}%  {c(tally,dim=True)}")
    nxt = next((w["text"] for w in d["whats_left"] if w["state"] != "done"), None)
    L.append(f"{c('next ',244)}{('✔ nada pendente' if not nxt else dot('orange')+' '+nxt)}")
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 3 — "Dashboard / KPI Tiles" : status-page tile grid + compact checklist.
#                       Best for metric-heavy sessions.
# ══════════════════════════════════════════════════════════════════════════════
def _tile(label, value, code, w=17):
    top = "┌" + "─" * w + "┐"
    lab = "│ " + pad(c(label, dim=True), w - 1) + "│"
    val = "│ " + pad(c(value, code, bold=True), w - 1) + "│"
    bot = "└" + "─" * w + "┘"
    return [top, lab, val, bot]


def model_3(d):
    s = d["session"]; t, meta = sess_head(s)
    a = d["autonomy"]; gp = green_pct(a)
    done = sum(1 for it in d["checklist"] if it["state"] in ("green", "blue"))
    tiles = [
        ("VERDICT", d["verdict"].get("label", "").split("·")[0].strip(), 46),
        ("AUTONOMY", f"{gp:.0f}% green", 46 if gp >= 80 else 208),
        ("CHECKLIST", f"{done}/{len(d['checklist'])} done", 46),
        ("OPEN", f"{sum(1 for w in d['whats_left'] if w['state']!='done')} left",
         46 if all(w["state"] == "done" for w in d["whats_left"]) else 208),
    ]
    L = [c(f"🛬 {t}", bold=True), c(meta, dim=True), ""]
    rows = [tiles[i:i + 2] for i in range(0, len(tiles), 2)]
    for row in rows:
        cells = [_tile(lbl, val, cd) for lbl, val, cd in row]
        for ln in range(4):
            L.append("  ".join(cell[ln] for cell in cells))
    L.append("")
    for it in d["checklist"]:
        L.append(f"  {dot(it['state'])} {pad(it.get('label',''),14)} {c(it.get('note',''),dim=True)}")
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 4 — "Burndown Ledger" : done-vs-remaining bar + numbered item ledger.
#                       Best for multi-task sessions with a backlog.
# ══════════════════════════════════════════════════════════════════════════════
def model_4(d):
    s = d["session"]; t, meta = sess_head(s)
    items = d["checklist"]
    done = sum(1 for it in items if it["state"] in ("green", "blue"))
    n = len(items) or 1
    L = [c(f"🛬 {t}", bold=True), c(meta, dim=True), ""]
    L.append(f"  {c('burndown',244)}  {bar(100*done/n,20)}  {c(f'{done}/{n} done · {n-done} left',bold=True)}")
    L.append("")
    for i, it in enumerate(items, 1):
        L.append(f"  {c(f'[{i:>2}]',240)} {dot(it['state'])} {pad(it.get('label',''),16)}"
                 f" {c(pad(it.get('note',''),40),dim=True)} {c(conf(it),46)}")
    rem = [w for w in d["whats_left"] if w["state"] != "done"]
    L.append("")
    if rem:
        L.append(f"  {c('remaining',208,bold=True)}")
        for w in rem:
            L.append(f"    {dot(w['state'])} {w['text']}")
    else:
        L.append(f"  {c('✔ remaining: none — burned down',46)}")
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 5 — "Kanban Lanes" : items bucketed by state (Done/Doing/Need-you/Todo).
#                       Best when 'what's left' is the headline.
# ══════════════════════════════════════════════════════════════════════════════
def model_5(d):
    s = d["session"]; t, meta = sess_head(s)
    lanes = [("green", "✅ DONE"), ("yellow", "🟡 DOING"),
             ("orange", "🟠 NEED-YOU"), ("red", "🔴 TODO")]
    buckets = {k: [] for k, _ in lanes}
    for it in d["checklist"]:
        key = ALIAS.get(it["state"], it["state"])
        buckets.setdefault("blue" if key == "blue" else key, [])
        buckets.setdefault(key, []).append(it.get("label", ""))
    # fold blue(done-human) into DONE lane
    buckets["green"] = buckets.get("green", []) + buckets.get("blue", [])
    for w in d["whats_left"]:
        if w["state"] != "done":
            buckets.setdefault(ALIAS.get(w["state"], w["state"]), []).append(w["text"])
    for tk in tk_list(d):
        key = ALIAS.get(tk.get("status"), tk.get("status", "green"))
        buckets.setdefault(key, []).append(f"🎫 {tk.get('id','?')} {tk.get('title','')}")
    L = [c(f"🛬 {t}", bold=True), c(meta, dim=True), ""]
    for key, title in lanes:
        rows = buckets.get(key, [])
        code = STATE[key][3]
        L.append(c(f"  {title}  ({len(rows)})", code, bold=True))
        for r in rows:
            L.append(f"    {c('•',code)} {r}")
        if not rows:
            L.append(c("    —", dim=True))
    a = d["autonomy"]; _, tally, _, gp = pulse_line(a)
    L.append("")
    L.append(f"  {c('pulse',244)} {bar(gp,10)} {gp:.0f}% green  ·  {c(tally,dim=True)}")
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 6 — "Telemetry / Machine-First" : key:value + sparkline + JSON-RPC sidecar.
#                       Best for agent-to-agent consumption (economical register).
# ══════════════════════════════════════════════════════════════════════════════
SPARK = "▁▂▃▄▅▆▇█"


def model_6(d):
    s = d["session"]; a = d["autonomy"]; gp = green_pct(a)
    tot = sum(a.values()) or 1
    spark = "".join(SPARK[min(7, int(a[k] / tot * 7))] for k in ("red", "orange", "yellow" if "yellow" in a else "blue", "green") if k in a) if a else ""
    L = [c("# scorecard.telemetry", 244, bold=True)]
    L.append(f"session.id        = {s.get('id','-')}")
    L.append(f"session.title     = {s.get('title','-')}")
    L.append(f"verdict.state     = {d['verdict'].get('state','-')}  {VERDICT_ICON.get(d['verdict'].get('state'),'')}")
    L.append(f"autonomy.green    = {a['green']}")
    L.append(f"autonomy.human    = {a['blue']}")
    L.append(f"autonomy.need_hitl= {a['orange']}")
    L.append(f"autonomy.pct_green= {gp:.1f}%   {bar(gp,12)}")
    L.append(f"checklist.done    = {sum(1 for it in d['checklist'] if it['state'] in ('green','blue'))}/{len(d['checklist'])}")
    L.append(f"open.items        = {sum(1 for w in d['whats_left'] if w['state']!='done')}")
    g = d.get("_git") or {}
    if g:  # script-self-calculated facts (zero agent input) — surfaced here
        L.append(f"git.repo          = {g.get('repo','-')}")
        L.append(f"git.branch        = {g.get('branch','-')}  (+{g.get('ahead',0)}/-{g.get('behind',0)})")
        L.append(f"git.dirty         = {g.get('dirty','-')} file(s)")
        L.append(f"git.open_prs      = {g.get('open_prs','-')}")
    if tk_list(d):
        dn, tt = tk_counts(d)
        L.append(f"tickets.done      = {dn}/{tt}")
        for t in tk_list(d):
            L.append(f"  ticket {t.get('id','?'):<10}= {t.get('status',''):<12} {t.get('title','')}")
    L.append("")
    L.append(c("  json-rpc sidecar:", dim=True))
    payload = {"jsonrpc": "2.0", "method": "session.scorecard", "params": {
        "verdict": d["verdict"].get("state"),
        "autonomy": {k: a[k] for k in ("green", "blue", "orange", "red")},
        "pct_green": round(gp, 1),
        "checklist": [{"label": it.get("label"), "token": st(it["state"])[2],
                       "confidence": it.get("confidence")} for it in d["checklist"]],
        "open": [w["text"] for w in d["whats_left"] if w["state"] != "done"],
        "tickets": [{"id": t.get("id"), "status": t.get("status"),
                     "token": st(t.get("status", "green"))[2]} for t in tk_list(d)],
        "git": {k: g.get(k) for k in ("repo", "branch", "ahead", "behind", "dirty", "open_prs")} if g else None,
    }, "data": {"layer": "community"}}
    L.append("  " + json.dumps(payload, ensure_ascii=False))
    return "\n".join(L)


# ══════════════════════════════════════════════════════════════════════════════
# MODEL 7 — "Executive One-Liner + drilldown" : Minto TL;DR in one line.
#                       Best for 1-second 'bater o olho'.
# ══════════════════════════════════════════════════════════════════════════════
def model_7(d):
    a = d["autonomy"]; gp = green_pct(a)
    vi = VERDICT_ICON.get(d["verdict"].get("state"), "•")
    done = sum(1 for it in d["checklist"] if it["state"] in ("green", "blue"))
    openn = sum(1 for w in d["whats_left"] if w["state"] != "done")
    def clip(t, n):
        return t if len(t) <= n else t[:n - 1] + "…"
    nxt = next((w["text"] for w in d["whats_left"] if w["state"] != "done"), "—")
    tkseg = (f" · 🎫 {tk_counts(d)[0]}/{tk_counts(d)[1]}" if tk_list(d) else "")
    head = (f"{vi} {c(d['verdict'].get('label','').split('·')[0].strip().upper(),46,bold=True)}"
            f" · {bar(gp,8)} {gp:.0f}% green"
            f" · {done}/{len(d['checklist'])} done{tkseg}"
            f" · {openn} blocker{'s' if openn!=1 else ''}"
            f" · next: {('—' if openn==0 else clip(nxt,34))}")
    L = [head]
    L.append(c(f"  ↳ {d['session'].get('title','')}  ({d['session'].get('duration','')})", dim=True))
    if openn:
        L.append(c("  ↳ open: " + " · ".join(clip(w["text"], 42) for w in d["whats_left"] if w["state"] != "done"), 208))
    return "\n".join(L)


MODELS = {1: model_1, 2: model_2, 3: model_3, 4: model_4, 5: model_5, 6: model_6, 7: model_7}
NAMES = {1: "Cockpit", 2: "Traffic-Light Strip", 3: "Dashboard / KPI Tiles",
         4: "Burndown Ledger", 5: "Kanban Lanes", 6: "Telemetry / Machine-First",
         7: "Executive One-Liner"}


def main():
    global COLOR
    ap = argparse.ArgumentParser(description="postflight scorecard renderer (7 models)")
    ap.add_argument("--model", type=int, default=1, choices=range(1, 8))
    ap.add_argument("--params", help="JSON params file, or '-' for stdin")
    ap.add_argument("--demo", action="store_true", help="use built-in demo params")
    ap.add_argument("--auto-git", action="store_true", help="self-calculate git/PR facts")
    ap.add_argument("--repo", help="repo dir for --auto-git (default cwd)")
    ap.add_argument("--no-color", action="store_true")
    ap.add_argument("--all", action="store_true", help="render every model")
    a = ap.parse_args()
    COLOR = not (a.no_color or os.environ.get("NO_COLOR"))
    d = enrich(load_params(a), a)
    if a.all:
        for m in range(1, 8):
            print(c(f"\n══════ MODEL {m} — {NAMES[m]} " + "═" * 30, 39, bold=True))
            print(MODELS[m](d))
        return
    print(MODELS[a.model](d))


if __name__ == "__main__":
    main()
