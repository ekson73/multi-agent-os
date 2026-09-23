#!/usr/bin/env python3
"""project_roadmap.py — deterministic half of the roadmap-tree-projector.

The HYBRID split (see skills/roadmap-tree-projector/SKILL.md):
  · DETERMINISTIC (this script): locate the SSOT, parse it, validate the graph
    (nodes, edges, parents, cycles), topo-sort, fold in measured statuses,
    render the N-Tree and the requested lens. Pure, testable, no LLM.
  · COGNITIVE (the skill body): classify ambiguous status, suggest MISSING
    edges, resolve which ticket-manager/probe to call per world. Deferred to the
    agent because it is judgement, not computation.

eko-executable-scripts compliance (~/.kiro/steering/eko-executable-scripts.md):
  1. Self-locating — finds roadmap.yaml via a glob+fallback, never a hardcoded
     absolute path.
  2. Live-pinned — reads the SSOT at runtime; carries no copied constant.
  3. One idempotent run — verify -> parse -> validate -> render -> PASS/FAIL,
     non-zero exit on ANY FAIL (invalid schema, cycle, unknown parent, unknown
     lens) so CI/cron can gate a broken projection.
  4. Native prereq — PyYAML is REQUIRED. There is no built-in YAML fallback: the
     seed uses nested maps and flow scalars a hand-rolled parser would misread,
     and a silent misparse is worse than a loud stop (anti-theater — we do not
     claim a fallback we do not have). Absent PyYAML => fail loud with the exact
     `pip install` remedy.
  5. Flags — --check / --help / --lens / --json / --roadmap / --status-file.
  6. Self-heal — the SKILL body dispatches the AI harness on failure; this
     script stays a pure computation (a trap ERR belongs in the bash wrapper the
     skill emits, not in a library the tests import).
  7. Human-run, agent-authored.

Status probing (gh/acli/linear) is intentionally NOT run here: it is a network
side-effect that belongs to the cognitive layer, which passes measured statuses
in via --status-file (id=status pairs). This keeps the script pure + testable.
The MEASURED status is folded into BOTH the tree render and the --json envelope.
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
# ticket-manager a world declares -> the probe the cognitive layer should call.
WORLD_MANAGER = {"personal": "linear", "client-alpha": "jira", "integrator-beta": "github"}


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


# ── property 4: parse (PyYAML required, duplicate-key-safe, no silent misparse)
class _DupKeyError(ValueError):
    """Raised when a YAML mapping has a duplicate key (PyYAML would overwrite)."""


def load_yaml(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    try:
        import yaml  # type: ignore
    except ImportError:
        # No built-in fallback by design (see module docstring). Fail LOUD with
        # the exact remedy rather than silently misparse.
        raise SystemExit(
            "PyYAML is required to parse the roadmap and is not installed. "
            "Install it: pip install pyyaml"
        )

    class _NoDupLoader(yaml.SafeLoader):
        pass

    def _no_dup_mapping(loader: yaml.SafeLoader, node, deep=False):  # type: ignore
        mapping: dict = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in mapping:
                raise _DupKeyError(f"duplicate YAML key {key!r} (PyYAML would overwrite it silently)")
            mapping[key] = loader.construct_object(value_node, deep=deep)
        return mapping

    _NoDupLoader.add_constructor(  # reject dup keys instead of last-wins
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _no_dup_mapping
    )
    try:
        return yaml.load(text, Loader=_NoDupLoader) or {}
    except _DupKeyError as e:
        raise SystemExit(f"roadmap invalid: {e}")


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
        # required title — a titleless node renders as a blank branch (silent-wrong)
        if not n.get("title"):
            errs.append(f"node {nid}: missing required 'title'")
    # parents must reference existing nodes — a typo'd parent silently drops the
    # node out of render_tree (it becomes an orphan under a non-existent root).
    for n in nodes:
        nid = n.get("id")
        if not nid:
            continue
        for p in n.get("parents") or []:
            if p not in ids:
                errs.append(f"node {nid}: parent references unknown node {p!r}")
    for e in doc.get("edges") or []:
        if e.get("type") not in EDGE_TYPES:
            errs.append(f"edge {e!r}: unknown type {e.get('type')!r}")
        for endpoint in ("from", "to"):
            if e.get(endpoint) not in ids:
                errs.append(f"edge {e!r}: {endpoint} references unknown node {e.get(endpoint)!r}")
    return errs


def resolve_probe_manager(node: dict) -> str | None:
    """Which ticket-manager to probe this node's status against.

    ROUTING CONTRACT (coderabbit/copilot/codex converged): the node's own
    `ref.manager` is authoritative — a node can live in a Jira world yet point
    at a GitHub PR (e.g. a client item delivered by a PR on GitHub). The world's
    declared ticket-manager is only the DEFAULT when the ref carries no manager.
    """
    ref = node.get("ref")
    if isinstance(ref, dict) and ref.get("manager"):
        return str(ref["manager"])
    world = node.get("world")
    return WORLD_MANAGER.get(world) if world else None


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


def effective_status(node: dict, statuses: dict[str, str]) -> str:
    """MEASURED status wins; else the node's declared status; else '?'."""
    return statuses.get(node.get("id"), node.get("status", "?"))


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
        st = effective_status(n, statuses)
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

    # An unknown --lens is a broken projection: fail loud + non-zero so CI does
    # not read exit 0 on a lens that renders nothing meaningful.
    if args.lens:
        lenses = doc.get("lenses") or {}
        if args.lens not in lenses:
            avail = ", ".join(sorted(lenses)) or "none"
            msg = f"unknown lens {args.lens!r}; available: {avail}"
            if args.json:
                print(json.dumps({"ok": False, "errors": [msg]}, ensure_ascii=False))
            else:
                print(f"FAIL — {msg}", file=sys.stderr)
            return 1

    if args.check:
        msg = f"PASS — {len(doc.get('nodes') or [])} nodes, {len(doc.get('edges') or [])} edges, acyclic"
        print(json.dumps({"ok": True, "summary": msg}) if args.json else msg)
        return 0

    statuses = load_status_file(args.status_file)
    order = topo_order(doc)

    if args.json:
        # Fold the MEASURED status into each node so the JSON branch is not a raw
        # dump that drops what --status-file measured (silent-wrong for consumers).
        enriched = []
        for n in doc.get("nodes") or []:
            m = dict(n)
            if n.get("id"):
                m["effective_status"] = effective_status(n, statuses)
                m["probe_manager"] = resolve_probe_manager(n)
            enriched.append(m)
        env = {
            "ok": True,
            "topo_order": order,
            "nodes": enriched,
            "edges": doc.get("edges"),
            "lenses": list((doc.get("lenses") or {})),
        }
        if args.lens:
            env["lens"] = {args.lens: (doc.get("lenses") or {})[args.lens]}
        print(json.dumps(env, ensure_ascii=False, indent=2))
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
