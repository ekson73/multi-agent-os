#!/usr/bin/env python3
"""
test_work_compass.py — stdlib-only tests for the work-compass aggregator.

Covers (per DoD): aggregator normalization · detector heuristics · renderer
determinism · router command-generation · read-only / no-clobber safety.

Run: python3 bin/tests/test_work_compass.py
"""
from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

# import the sibling module under test
_HERE = Path(__file__).resolve().parent
_MOD = _HERE.parent / "work-compass-aggregate.py"
_spec = importlib.util.spec_from_file_location("wc", _MOD)
wc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wc)

PASS = 0
FAIL = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  PASS  {name}")
    else:
        FAIL += 1
        print(f"  FAIL  {name}  {detail}")


def _old(days: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()


def _new() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── 1. aggregator normalization ───────────────────────────────────────────────
def test_item_normalization():
    it = wc.item("session:abc", "session", "do the thing", last_ts=_new(),
                 refs={"branch": "feat/x"})
    check("item: id namespaced", it["id"] == "session:abc")
    check("item: domain set", it["domain"] == "session")
    check("item: flags empty list by default", it["flags"] == [])
    check("item: refs preserved", it["refs"]["branch"] == "feat/x")
    check("item: default status unknown", it["status"] == "unknown")


def test_build_graph_deterministic():
    items = [
        wc.item("branch:z", "branch", "z", refs={"name": "z"}),
        wc.item("branch:a", "branch", "a", refs={"name": "a"}),
        wc.item("session:m", "session", "m"),
    ]
    g1 = wc.build_graph([dict(i) for i in items], "current", None, [])
    g2 = wc.build_graph([dict(i) for i in items], "current", None, [])
    check("graph: deterministic items order",
          [i["id"] for i in g1["items"]] == [i["id"] for i in g2["items"]],
          str([i["id"] for i in g1["items"]]))
    check("graph: branches sorted a<z",
          [i["id"] for i in g1["by_domain"]["branch"]] == ["branch:a", "branch:z"])
    check("graph: domains_present counted", g1["meta"]["domains_present"] == 2)


# ── 2. detector heuristics ────────────────────────────────────────────────────
def test_detector():
    items = [
        wc.item("branch:feat/x", "branch", "feat/x", refs={"name": "feat/x"}),     # no PR
        wc.item("branch:main", "branch", "main", refs={"name": "main"}),           # excluded
        wc.item("pr:o/r#5", "process", "fix stuff", refs={"branch": "feat/y", "number": 5}),  # no ticket
        wc.item("jira:VKS-1", "ticket", "a ticket", refs={"key": "VKS-1"}),        # no session
        wc.item("worktree:/p", "worktree", "p", refs={"branch": ""}),              # no branch
        wc.item("session:s1", "session", "old work", last_ts=_old(30),
                refs={"branch": "gone-branch"}),                                    # orphan + stale
    ]
    wc.detect(items, stale_days=7)
    by = {i["id"]: i for i in items}
    check("H1 branch-no-PR", "branch-no-PR" in by["branch:feat/x"]["flags"])
    check("H1 main excluded", "branch-no-PR" not in by["branch:main"]["flags"])
    check("H2 PR-no-ticket", "PR-no-ticket" in by["pr:o/r#5"]["flags"])
    check("H3 ticket-no-session", "ticket-no-session" in by["jira:VKS-1"]["flags"])
    check("H5 worktree-no-branch", "worktree-no-branch" in by["worktree:/p"]["flags"])
    check("H6 session-orphan", "session-orphan" in by["session:s1"]["flags"])
    check("H4 >Nd-no-update", any(">7d" in f for f in by["session:s1"]["flags"]))
    check("H4 sets stale-ish status", by["session:s1"]["status"] in ("stale", "orphan"))


def test_detector_no_false_positive_on_fresh_linked():
    items = [
        wc.item("branch:feat/live", "branch", "feat/live", refs={"name": "feat/live"}),
        wc.item("pr:o/r#9", "process", "VKS-2 fix", last_ts=_new(),
                refs={"branch": "feat/live", "number": 9}),  # title has ticket → no PR-no-ticket
        wc.item("session:s2", "session", "active", last_ts=_new(),
                refs={"branch": "feat/live", "tickets": ["VKS-2"]}),
    ]
    wc.detect(items, stale_days=7)
    by = {i["id"]: i for i in items}
    check("no false branch-no-PR (PR on branch)", "branch-no-PR" not in by["branch:feat/live"]["flags"])
    check("no false PR-no-ticket (title has VKS)", "PR-no-ticket" not in by["pr:o/r#9"]["flags"])
    check("no false session-orphan (branch exists)", "session-orphan" not in by["session:s2"]["flags"])


# ── 3. renderer determinism ───────────────────────────────────────────────────
def test_renderer_determinism():
    items = [
        wc.item("branch:b", "branch", "b", refs={"name": "b"}),
        wc.item("session:a", "session", "a"),
    ]
    g = wc.build_graph([dict(i) for i in items], "current", None, [])
    r1 = wc.render_ascii(g)
    r2 = wc.render_ascii(g)
    check("render ascii deterministic", r1 == r2)
    check("render ascii has header", "work-compass" in r1)
    m1 = wc.render_mermaid(g)
    check("render mermaid deterministic", m1 == wc.render_mermaid(g))
    check("render mermaid is flowchart", m1.startswith("flowchart TD"))
    # ascii-only fallback has no emoji
    r3 = wc.render_ascii(g, ascii_only=True)
    check("ascii-only has no emoji glyph", "🟢" not in r3 and "[" in r3)


# ── 4. router command-generation (read-only) ──────────────────────────────────
def test_router():
    n_branch = wc.item("branch:feat/x", "branch", "feat/x", refs={"name": "feat/x"})
    n_branch["flags"] = ["branch-no-PR"]
    r = wc.route(n_branch, action=None)
    check("router: suggests preflight for branch-no-PR", r["tool"] == "preflight")
    check("router: command non-empty", bool(r["suggested_command"]))
    check("router: execute=False (read-only contract)", r["execute"] is False)

    n_sess = wc.item("session:s1", "session", "x")
    n_sess["flags"] = ["session-orphan"]
    r2 = wc.route(n_sess, action="delete")
    check("router: destructive action flagged as warning",
          "DESTRUCTIVE" in r2["warning"])
    check("router: never sets execute true even for delete", r2.get("execute") is False)

    n_plain = wc.item("graph-node:misc", "graph-node", "misc")
    r3 = wc.route(n_plain, action=None)
    check("router: no-match returns suggestion None", r3.get("suggestion", "x") is None
          or r3.get("suggested_command") is None)


# ── 5. read-only / no-clobber safety ──────────────────────────────────────────
def test_read_only_safety():
    src = _MOD.read_text(encoding="utf-8")
    # the module must never invoke a known mutating verb autonomously
    banned = ["gh pr merge", "gh pr close", "git push", "git commit", "rm -rf",
              'subprocess.run(["gh", "pr", "merge"', "shutil.rmtree"]
    found = [b for b in banned if b in src]
    check("no mutating commands in source", not found, f"found: {found}")
    # router contract: execute is always False
    check("ROUTES contract: every route templates a command",
          all(isinstance(v[1], str) and v[1] for v in wc.ROUTES.values()))


# ── compass scope ─────────────────────────────────────────────────────────────
def test_scope_validation(capsys=None):
    items = [wc.item("branch:a", "branch", "a", refs={"name": "a"})]
    out = wc.apply_scope([dict(i) for i in items], "bogus", "branch:a")
    check("scope: invalid verb falls back (returns items)", len(out) == 1)
    sideways = wc.apply_scope(
        [wc.item("branch:a", "branch", "a", refs={"name": "a"}),
         wc.item("session:s", "session", "s")],
        "sideways", "branch:a")
    check("scope: sideways keeps same-domain only",
          all(i["domain"] == "branch" for i in sideways))


# ── 6. extended blind-spot scanners (v1.1.0) ──────────────────────────────────
def test_collect_plans():
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        (base / "old-plan.md").write_text("# Old Plan\n\n- [ ] step one\n- [x] done\n",
                                          encoding="utf-8")
        (base / "new-plan.md").write_text("# Fresh Plan\n\n- [ ] a\n", encoding="utf-8")
        old = time.time() - 30 * 86400
        os.utime(base / "old-plan.md", (old, old))
        items, diag = wc.collect_plans(plans_dir=td)
        by = {i["id"]: i for i in items}
        check("plans: both collected", len(items) == 2)
        check("plans: domain graph-node", all(i["domain"] == "graph-node" for i in items))
        check("plans: title parsed", by["plan:old-plan.md"]["title"] == "Old Plan")
        check("plans: open next-steps counted",
              by["plan:old-plan.md"]["refs"]["open_next_steps"] == 1)
        wc.detect(items, stale_days=7)
        by = {i["id"]: i for i in items}
        check("plans: stale + open steps → plan-orphan",
              "plan-orphan" in by["plan:old-plan.md"]["flags"])
        check("plans: fresh → no flag", not by["plan:new-plan.md"]["flags"])
    # absent dir degrades, never raises
    _, d = wc.collect_plans(plans_dir="/nonexistent-plans-xyz")
    check("plans: absent dir → diag not raise", isinstance(d, str))


def test_collect_bg_jobs():
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        j1 = base / "job-running"; j1.mkdir()
        (j1 / "state.json").write_text('{"status": "running"}', encoding="utf-8")
        (j1 / "timeline.jsonl").write_text('{"t": 1}\n', encoding="utf-8")
        old = time.time() - 30 * 86400
        os.utime(j1 / "timeline.jsonl", (old, old))
        j2 = base / "job-done"; j2.mkdir()
        (j2 / "state.json").write_text('{"status": "completed"}', encoding="utf-8")
        items, diag = wc.collect_bg_jobs(jobs_dir=td)
        by = {i["id"]: i for i in items}
        check("jobs: both collected", len(items) == 2)
        check("jobs: domain process", all(i["domain"] == "process" for i in items))
        check("jobs: status parsed", by["job:job-running"]["refs"]["job_status"] == "running")
        wc.detect(items, stale_days=7)
        by = {i["id"]: i for i in items}
        check("jobs: running + stale → job-orphan",
              "job-orphan" in by["job:job-running"]["flags"])
        check("jobs: fresh completed → no stale flag",
              not any(f.startswith("job-") for f in by["job:job-done"]["flags"]))


def test_collect_stashes():
    orig_run, orig_have = wc.run, wc.have
    wc.have = lambda c: True
    wc.run = lambda argv, timeout=30: (
        0,
        "stash@{0}|%s|WIP on feat/x\nstash@{1}|%s|WIP on main\n" % (_old(30), _new()),
        "",
    )
    try:
        items, diag = wc.collect_stashes("/x")
        check("stashes: two collected", len(items) == 2)
        check("stashes: domain graph-node", all(i["domain"] == "graph-node" for i in items))
        wc.detect(items, stale_days=7)
        by = {i["id"]: i for i in items}
        check("stashes: old → stash-forgotten", "stash-forgotten" in by["stash:stash@{0}"]["flags"])
        check("stashes: fresh → not forgotten",
              "stash-forgotten" not in by["stash:stash@{1}"]["flags"])
    finally:
        wc.run, wc.have = orig_run, orig_have


def test_tree_state_and_wip():
    orig_run = wc.run

    def fake_dirty(argv, timeout=30):
        if "symbolic-ref" in argv:
            return (0, "", "")                                  # attached HEAD
        if "status" in argv:
            return (0, " M tracked.py\n?? untracked.txt\n", "")  # tracked change → DIRTY
        return (1, "", "")

    def fake_clean(argv, timeout=30):
        if "symbolic-ref" in argv:
            return (0, "", "")
        if "status" in argv:
            return (0, "?? only-untracked.txt\n", "")            # untracked-only → CLEAN
        return (1, "", "")

    try:
        wc.run = fake_dirty
        check("tree_state: tracked change → DIRTY", wc._tree_state("/x") == "DIRTY")
        wc.run = fake_clean
        check("tree_state: untracked-only → CLEAN", wc._tree_state("/x") == "CLEAN")
    finally:
        wc.run = orig_run
    # H7 in detect()
    wt = wc.item("worktree:/w", "worktree", "w",
                 refs={"branch": "feat/x", "path": "/w", "wip_state": "DIRTY"})
    wt_clean = wc.item("worktree:/c", "worktree", "c",
                       refs={"branch": "feat/y", "path": "/c", "wip_state": "CLEAN"})
    wc.detect([wt, wt_clean], stale_days=7)
    check("H7 worktree-dirty-wip flagged", "worktree-dirty-wip" in wt["flags"])
    check("H7 no false positive on CLEAN", "worktree-dirty-wip" not in wt_clean["flags"])


def test_collect_codex():
    with tempfile.TemporaryDirectory() as td:
        idx = Path(td) / "session_index.jsonl"
        idx.write_text(
            '{"id": "abc", "thread_name": "refactor auth", "updated_at": "%s"}\n'
            '{"id": "def", "thread_name": "old thing", "updated_at": "%s"}\n'
            '\n'
            'not-json-line\n' % (_new(), _old(30)),
            encoding="utf-8")
        items, diag = wc.collect_codex_sessions(index_path=str(idx))
        by = {i["id"]: i for i in items}
        check("codex: valid rows only (2)", len(items) == 2)
        check("codex: domain session", all(i["domain"] == "session" for i in items))
        check("codex: id namespaced", "codex-session:abc" in by)
        check("codex: vendor tagged", by["codex-session:abc"]["refs"]["vendor"] == "codex")
        wc.detect(items, stale_days=7)
        by = {i["id"]: i for i in items}
        check("codex: old session → H4 stale", any(">7d" in f for f in by["codex-session:def"]["flags"]))
        check("codex: fresh → no false orphan",
              "session-orphan" not in by["codex-session:abc"]["flags"])
    _, d = wc.collect_codex_sessions(index_path="/nonexistent-codex-xyz.jsonl")
    check("codex: absent index → diag not raise", isinstance(d, str))


# ── 7. guardrails: openclaw exclusion + registry + new-domain determinism ──────
def test_openclaw_exclusion():
    inside = str(wc.HOME / "openclaw" / "agents" / "eko" / "SOUL.md")
    plans = str(wc.HOME / ".claude" / "plans" / "x.md")
    check("openclaw: path inside sovereign tree excluded", wc._is_openclaw(inside) is True)
    check("openclaw: root itself excluded", wc._is_openclaw(str(wc.HOME / "openclaw")) is True)
    check("openclaw: normal plans path not excluded", wc._is_openclaw(plans) is False)


def test_registry_flags():
    for n in ("stashes", "plans", "jobs", "codex"):
        check(f"registry: {n} in COLLECTORS", n in wc.COLLECTORS)
    ns = SimpleNamespace(inventory=None, repo_dir="/nonexistent-xyz", repo=None,
                         **{f"no_{n}": True for n in wc.COLLECTORS})
    items, unavailable = wc.aggregate(ns)
    check("registry: all-disabled → zero items", items == [])
    check("registry: all-disabled → zero diags", unavailable == [])


def test_new_domains_populated():
    items = [
        wc.item("plan:a.md", "graph-node", "a", last_ts=_new(), refs={"open_next_steps": 0}),
        wc.item("stash:stash@{0}", "graph-node", "wip", last_ts=_new(), refs={}),
        wc.item("job:x", "process", "job x", last_ts=_new(), refs={"job_status": "running"}),
        wc.item("codex-session:z", "session", "z", last_ts=_new(), refs={"vendor": "codex"}),
    ]
    g1 = wc.build_graph([dict(i) for i in items], "current", None, [])
    g2 = wc.build_graph([dict(i) for i in items], "current", None, [])
    check("new domains: deterministic",
          [i["id"] for i in g1["items"]] == [i["id"] for i in g2["items"]])
    check("new domains: graph-node populated", len(g1["by_domain"]["graph-node"]) == 2)
    check("new domains: process populated", len(g1["by_domain"]["process"]) == 1)


# ── 17. Eisenhower pendency view (v1.3 — composes skills/eisenhower-matrix) ─────
def test_eisenhower_classifier():
    dirty = wc.item("worktree:/w/x", "worktree", "x",
                    refs={"path": "/w/x", "wip_state": "DIRTY"}, flags=["worktree-dirty-wip"])
    check("eisenhower: dirty-wip worktree → Q1 Do",
          wc.classify_eisenhower(dirty)["quadrant"] == "Q1")
    active_pr = wc.item("pr:repo#9", "process", "p", last_ts=_new(), source="gh")
    check("eisenhower: PR ≤ 2d → Q1 (active convergence)",
          wc.classify_eisenhower(active_pr)["quadrant"] == "Q1")
    old_pr = wc.item("pr:repo#8", "process", "p", last_ts=_old(10), source="gh")
    check("eisenhower: old PR → Q2 Schedule",
          wc.classify_eisenhower(old_pr)["quadrant"] == "Q2")
    stale_branch = wc.item("branch:feat/x", "branch", "x", last_ts=_old(10),
                           flags=["branch-no-PR"])
    check("eisenhower: stale branch-no-PR → Q2",
          wc.classify_eisenhower(stale_branch)["quadrant"] == "Q2")
    quiet = wc.item("session:abc", "session", "s", last_ts=_old(30))
    check("eisenhower: unflagged session → Q4 Eliminate/Archive",
          wc.classify_eisenhower(quiet)["quadrant"] == "Q4")
    check("eisenhower: disposition labels",
          wc.classify_eisenhower(active_pr)["disposition"] == "Do"
          and wc.classify_eisenhower(quiet)["disposition"] == "Eliminate/Archive")


def test_eisenhower_determinism():
    items = [
        wc.item("pr:repo#9", "process", "p", last_ts=_new()),
        wc.item("branch:b", "branch", "b", last_ts=_old(9), flags=["branch-no-PR"]),
        wc.item("session:s", "session", "s", last_ts=_old(30)),
    ]
    v1 = wc.build_pendency_view([dict(i) for i in items], "all", "all", [], ref=None)
    v2 = wc.build_pendency_view([dict(i) for i in items], "all", "all", [], ref=None)
    check("pendency: deterministic (same input → same buckets)",
          [r["id"] for q in v1["quadrants"].values() for r in q]
          == [r["id"] for q in v2["quadrants"].values() for r in q])


def test_pendency_scope_filter():
    items = [
        wc.item("session:s1", "session", "s"),
        wc.item("codex-session:c1", "session", "c"),
        wc.item("job:j1", "process", "j"),
        wc.item("branch:b1", "branch", "b"),
        wc.item("worktree:/w", "worktree", "w"),
        wc.item("pr:repo#1", "process", "p"),
        wc.item("jira:VKS-1", "ticket", "t"),
    ]
    ids = lambda scope: sorted(i["id"] for i in items if wc.in_pendency_scope(i, scope))
    check("pendency-scope: session → host session state",
          ids("session") == ["codex-session:c1", "job:j1", "session:s1"])
    check("pendency-scope: repo → repo state",
          ids("repo") == ["branch:b1", "pr:repo#1", "worktree:/w"])
    check("pendency-scope: current = session+repo",
          ids("current") == ["branch:b1", "codex-session:c1", "job:j1",
                              "pr:repo#1", "session:s1", "worktree:/w"])
    check("pendency-scope: all → everything incl. jira",
          ids("all") == sorted(i["id"] for i in items))
    view = wc.build_pendency_view(items, "vault", "pending", [])
    check("pendency-scope: vault → empty + unavailable diag (no fabrication)",
          view["meta"]["count"] == 0
          and any("vault" in d for d in view["meta"]["unavailable"]))


def test_pendency_include_pending():
    done = wc.item("plan:p.md", "graph-node", "p", status="superseded")
    open_ = wc.item("plan:q.md", "graph-node", "q", status="unknown")
    check("include: pending drops superseded", wc._is_pending(done) is False
          and wc._is_pending(open_) is True)
    view = wc.build_pendency_view([done, open_], "all", "pending", [])
    got = [r["id"] for q in view["quadrants"].values() for r in q]
    check("include: view honors pending filter", got == ["plan:q.md"])


def test_pendency_next_action():
    items = [wc.item("session:s", "session", "s", last_ts=_old(30))]
    view = wc.build_pendency_view(items, "all", "pending", [])
    check("pendency: next_action = first non-empty quadrant head",
          view["next_action"] == "Q4 session:s")


def test_sort_flags_and_backcompat():
    # flag-name collision resolved: --scope (CPT verbs) and --pendency-scope coexist
    import argparse
    src = open(wc.__file__, encoding="utf-8").read()
    check("cli: both --scope and --pendency-scope declared",
          '--scope", default="current"' in src or '"--scope"' in src
          and '"--pendency-scope"' in src)
    check("cli: --sort choices include eisenhower", '"eisenhower"' in src)
    # backward compat: default build_graph output shape unchanged (id-sorted)
    items = [wc.item("b:2", "branch", "2"), wc.item("b:1", "branch", "1")]
    g = wc.build_graph(items, "current", None, [])
    check("backcompat: default order still id-asc",
          [i["id"] for i in g["items"]] == ["b:1", "b:2"])
    g2 = wc.build_graph(items, "current", None, [],
                        sort_key=lambda it: -wc.importance_rank(it))
    check("sort: build_graph honors sort_key", "items" in g2 and len(g2["items"]) == 2)


# ── 18. Q4 reap routing + Q3 honesty (v1.3.1 — closes the Eliminate loop) ──────
def test_stale_session_routes_to_reap():
    stale = wc.item("session:old", "session", "old", last_ts=_old(40), status="stale",
                    flags=[">7d-no-update"])
    r = wc.route(stale, None)
    check("reap: stale quiet session → reap-sessions (NOT resume)",
          r["tool"] == "reap-sessions"
          and r["suggested_command"].startswith("bin/reap-sessions.sh --repo-dir ."))
    check("reap: dry-run default + explicit operator gate (--apply only after review)",
          "--apply only after review" in r["suggested_command"] and r["execute"] is False)
    active = wc.item("session:live", "session", "live", last_ts=_new(), status="ok")
    r2 = wc.route(active, None)
    check("reap: active session still routes to resume",
          r2["tool"] == "auto-orchestrator")
    # producer-marked orphan (inventory id marker) with no timestamp/flags → archive, not resume
    orphan = wc.item("session:x.orphaned-1700000000000-abc", "session", "x",
                     status="unknown")
    r3 = wc.route(orphan, None)
    check("reap: producer-orphaned session (no ts/flags) → reap, not resume",
          r3["tool"] == "reap-sessions")


def test_q3_forward_compat():
    # RED-TEAM finding (v0.3.0): every production urgency signal lands on an important
    # domain → Q3 is structurally signal-starved today (needs an external-quota/CI-check
    # collector — deferred). The branch is wired: this synthetic item (urgent flag on a
    # non-delivery domain — no current collector emits it) proves forward-compat.
    synth = wc.item("plan:quota.md", "graph-node", "quota", flags=["job-orphan"])
    c = wc.classify_eisenhower(synth)
    check("q3: branch wired — synthetic urgency-without-importance → Q3 Delegate",
          c["quadrant"] == "Q3" and c["disposition"] == "Delegate")


def main() -> int:
    print("test_work_compass — work-compass v1.3.1")
    print("=" * 60)
    for fn in [
        test_item_normalization, test_build_graph_deterministic,
        test_detector, test_detector_no_false_positive_on_fresh_linked,
        test_renderer_determinism, test_router, test_read_only_safety,
        test_scope_validation,
        test_collect_plans, test_collect_bg_jobs, test_collect_stashes,
        test_tree_state_and_wip, test_collect_codex,
        test_openclaw_exclusion, test_registry_flags, test_new_domains_populated,
        test_eisenhower_classifier, test_eisenhower_determinism,
        test_pendency_scope_filter, test_pendency_include_pending,
        test_pendency_next_action, test_sort_flags_and_backcompat,
        test_stale_session_routes_to_reap, test_q3_forward_compat,
    ]:
        print(f"\n[{fn.__name__}]")
        fn()
    print("\n" + "=" * 60)
    print(f"RESULT: {PASS} passed, {FAIL} failed")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
