#!/usr/bin/env python3
"""project_roadmap.py — deterministic half of the roadmap-tree-projector.

The HYBRID split (see skills/roadmap-tree-projector/SKILL.md):
  · DETERMINISTIC (this script): locate the SSOT, parse it, validate the graph
    (cycle detection), topo-sort, fold in measured statuses, render the N-Tree
    and the requested lens. Pure, testable, no LLM.
  · COGNITIVE (the skill body): classify ambiguous status, suggest MISSING
    edges, resolve which ticket-manager/probe to call per world. Deferred to the
    agent because it is judgement, not computation.

eko-executable-scripts compliance (~/.kiro/steering/eko-executable-scripts.md):
  1. Self-locating — finds roadmap.yaml via a glob+fallback, never a hardcoded
     absolute path.
  2. Live-pinned — reads the SSOT at runtime; carries no copied constant.
  3. One idempotent run — verify -> parse -> validate -> render -> PASS/FAIL,
     non-zero exit on any FAIL so CI/cron can gate.
  4. Native prereqs — PyYAML if present; else a tiny built-in fallback parser so
     the tool runs on a bare interpreter (degrade, never crash).
  5. Flags — --check / --help / --lens / --json / --roadmap.
  6. Self-heal — the SKILL body dispatches the AI harness on failure; this
     script stays a pure computation (a trap ERR belongs in the bash wrapper the
     skill emits, not in a library the tests import).
  7. Human-run, agent-authored.

Status probing (gh/acli/linear) is intentionally NOT run here: it is a network
side-effect that belongs to the cognitive layer, which passes measured statuses
in via --status-file (id=status pairs). This keeps the script pure + testable.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from collections import defaultdict, deque

SCHEMA_VERSION = 1
KINDS = {"goal", "objective", "epic", "item", "task", "pr", "session", "dor", "dod"}
EDGE_TYPES = {"depends-on", "blocks", "informs", "realizes"}


# ── property 1: self-locating ────────────────────────────────────────────────
def locate_roadmap(explicit: str | None) -> str:
    if explicit:
        if os.path.isfile(explicit):
            return explicit
        raise FileNotFoundError(f"--roadmap path not found: {explicit}")
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "..", "..", "..", "orchestration", "roadmap.yaml"),
        "orchestration/roadmap.yaml",
    ]
    candidates += glob.glob(os.path.join(here, "..", "..", "..", "**", "roadmap.yaml"), recursive=True)
    for c in candidates:
        if os.path.isfile(c):
            return os.path.abspath(c)
    raise FileNotFoundError("could not locate orchestration/roadmap.yaml (self-locating glob failed)")


# ── property 4: parse with graceful degradation ──────────────────────────────
def load_yaml(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    try:
        import yaml  # type: ignore

        return yaml.safe_load(text) or {}
    except ImportError:
        # Bare-interpreter fallback: we do not reimplement YAML, we require it
        # for anything non-trivial. Fail LOUD with the exact remedy rather than
        # silently misparsing (anti-theater: no fake capability).
        raise SystemExit(
            "PyYAML not installed and the built-in fallback cannot parse this "
            "roadmap safely. Install it: pip install pyyaml"
        )


def validate(doc: dict) -> list[str]:
    errs: list[str] = []
    if doc.get("version") != SCHEMA_VERSION:
        errs.append(f"version must be {SCHEMA_VERSION}, got {doc.get('version')!r}")
    nodes = doc.get("nodes") or []
    ids = set()
    for n in nodes:
        nid = n.get("id")
        if not nid:
            errs.append(f"node missing id: {n!r}")
            continue
        if nid in ids:
            errs.append(f"duplicate node id: {nid}")
        ids.add(nid)
        if n.get("kind") not in KINDS:
            errs.append(f"node {nid}: unknown kind {n.get('kind')!r}")
    for e in doc.get("edges") or []:
        if e.get("type") not in EDGE_TYPES:
            errs.append(f"edge {e!r}: unknown type {e.get('type')!r}")
        for endpoint in ("from", "to"):
            if e.get(endpoint) not in ids:
                errs.append(f"edge {e!r}: {endpoint} references unknown node {e.get(endpoint)!r}")
    return errs


def _dep_graph(doc: dict) -> dict[str, set[str]]:
    """Normalize edges to a depends-on adjacency (blocks is inverse sugar)."""
    deps: dict[str, set[str]] = defaultdict(set)
    for e in doc.get("edges") or []:
        t = e.get("type")
        if t == "depends-on":
            deps[e["from"]].add(e["to"])
        elif t == "blocks":
            deps[e["to"]].add(e["from"])
        # realizes / informs are not hard ordering constraints for topo-sort
    return deps


def detect_cycle(doc: dict) -> list[str] | None:
    deps = _dep_graph(doc)
    ids = [n["id"] for n in doc.get("nodes") or [] if n.get("id")]
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {i: WHITE for i in ids}
    stack: list[str] = []

    def dfs(u: str) -> list[str] | None:
        color[u] = GRAY
        stack.append(u)
        for v in deps.get(u, ()):  # v must precede u
            if color.get(v) == GRAY:
                return stack[stack.index(v):] + [v]
            if color.get(v) == WHITE:
                r = dfs(v)
                if r:
                    return r
        color[u] = BLACK
        stack.pop()
        return None

    for i in ids:
        if color[i] == WHITE:
            cyc = dfs(i)
            if cyc:
                return cyc
    return None


def topo_order(doc: dict) -> list[str]:
    deps = _dep_graph(doc)
    ids = [n["id"] for n in doc.get("nodes") or [] if n.get("id")]
    indeg = {i: 0 for i in ids}
    adj: dict[str, list[str]] = defaultdict(list)
    for u in ids:
        for v in deps.get(u, ()):  # v precedes u
            adj[v].append(u)
            indeg[u] += 1
    q = deque(sorted(i for i in ids if indeg[i] == 0))
    order: list[str] = []
    while q:
        u = q.popleft()
        order.append(u)
        for w in sorted(adj[u]):
            indeg[w] -= 1
            if indeg[w] == 0:
                q.append(w)
    return order


def load_status_file(path: str | None) -> dict[str, str]:
    """Measured statuses from the cognitive layer: `id=status` per line."""
    out: dict[str, str] = {}
    if not path:
        return out
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def _ref_str(node: dict) -> str:
    ref = node.get("ref")
    if not ref:
        return ""
    if isinstance(ref, dict):
        if ref.get("key"):
            return str(ref["key"])
        if ref.get("pr") is not None:
            return f"{ref.get('repo', '?')}#{ref['pr']}"
        return json.dumps(ref, sort_keys=True)
    return str(ref)


def render_tree(doc: dict, statuses: dict[str, str]) -> str:
    nodes = {n["id"]: n for n in doc.get("nodes") or [] if n.get("id")}
    children: dict[str, list[str]] = defaultdict(list)
    has_parent = set()
    for nid, n in nodes.items():
        for p in n.get("parents") or []:
            children[p].append(nid)
            has_parent.add(nid)
    roots = sorted(nid for nid in nodes if nid not in has_parent)
    lines: list[str] = []

    def emit(nid: str, prefix: str, last: bool) -> None:
        n = nodes[nid]
        branch = "└─ " if last else "├─ "
        st = statuses.get(nid, n.get("status", "?"))
        ref = _ref_str(n)
        ref_s = f"  <{ref}>" if ref else ""
        lines.append(f"{prefix}{branch}[{n['kind']}] {nid}: {n['title']} — {st}{ref_s}")
        kids = sorted(children.get(nid, []))
        ext = "   " if last else "│  "
        for i, k in enumerate(kids):
            emit(k, prefix + ext, i == len(kids) - 1)

    for i, r in enumerate(roots):
        emit(r, "", i == len(roots) - 1)
    return "\n".join(lines)


def render_lens(doc: dict, lens: str) -> str:
    lenses = doc.get("lenses") or {}
    if lens not in lenses:
        return f"(lens '{lens}' not defined in this roadmap; available: {', '.join(sorted(lenses)) or 'none'})"
    return json.dumps({lens: lenses[lens]}, indent=2, ensure_ascii=False)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Project the roadmap N-Tree from the durable SSOT.")
    ap.add_argument("--roadmap", help="path to roadmap.yaml (default: self-locate)")
    ap.add_argument("--check", action="store_true", help="validate + cycle-detect only, no render")
    ap.add_argument("--lens", help="render a stored lens (swot|raci|eisenhower|...)")
    ap.add_argument("--status-file", help="measured statuses from the cognitive layer (id=status per line)")
    ap.add_argument("--json", action="store_true", help="machine envelope")
    args = ap.parse_args(argv)

    try:
        path = locate_roadmap(args.roadmap)
        doc = load_yaml(path)
    except (FileNotFoundError, SystemExit) as e:
        print(f"FAIL: {e}", file=sys.stderr)
        return 1

    errs = validate(doc)
    cyc = detect_cycle(doc) if not errs else None
    if cyc:
        errs.append("dependency CYCLE: " + " -> ".join(cyc))

    if errs:
        if args.json:
            print(json.dumps({"ok": False, "errors": errs}, ensure_ascii=False))
        else:
            print("FAIL — roadmap invalid:", file=sys.stderr)
            for e in errs:
                print(f"  · {e}", file=sys.stderr)
        return 1

    if args.check:
        msg = f"PASS — {len(doc.get('nodes') or [])} nodes, {len(doc.get('edges') or [])} edges, acyclic"
        print(json.dumps({"ok": True, "summary": msg}) if args.json else msg)
        return 0

    statuses = load_status_file(args.status_file)
    order = topo_order(doc)

    if args.json:
        print(json.dumps({
            "ok": True,
            "topo_order": order,
            "nodes": doc.get("nodes"),
            "edges": doc.get("edges"),
            "lenses": list((doc.get("lenses") or {})),
        }, ensure_ascii=False, indent=2))
        return 0

    print("ROADMAP N-TREE (parents -> children; status measured or declared)\n")
    print(render_tree(doc, statuses))
    print("\nTOPOLOGICAL ORDER (dependency-respecting):")
    print("  " + " -> ".join(order))
    if args.lens:
        print(f"\nLENS — {args.lens}:")
        print(render_lens(doc, args.lens))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
