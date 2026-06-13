#!/usr/bin/env python3
"""
test_work_compass.py — stdlib-only tests for the work-compass aggregator.

Covers (per DoD): aggregator normalization · detector heuristics · renderer
determinism · router command-generation · read-only / no-clobber safety.

Run: python3 bin/tests/test_work_compass.py
"""
from __future__ import annotations

import importlib.util
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

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


def main() -> int:
    print("test_work_compass — work-compass Phase-1")
    print("=" * 60)
    for fn in [
        test_item_normalization, test_build_graph_deterministic,
        test_detector, test_detector_no_false_positive_on_fresh_linked,
        test_renderer_determinism, test_router, test_read_only_safety,
        test_scope_validation,
    ]:
        print(f"\n[{fn.__name__}]")
        fn()
    print("\n" + "=" * 60)
    print(f"RESULT: {PASS} passed, {FAIL} failed")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
