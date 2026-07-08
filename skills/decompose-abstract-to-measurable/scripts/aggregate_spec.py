#!/usr/bin/env python3
"""aggregate_spec.py — deterministic aggregation engine for the
`decompose-abstract-to-measurable` (soul-name *Prisma*) skill.

Division of labour (the genuine deterministic × probabilistic seam):
  • The LLM (calling agent) AUTHORS the value-tree, TYPES each leaf D/T/J, writes
    measurement methods + anchors, and ESTIMATES judgment-leaf graded values +
    confidence  → probabilistic muscle (f > 0).
  • THIS script does the weighted roll-up, confidence propagation, sensitivity,
    residual + inconclusive detection  → deterministic skeleton (f = 0),
    amnesia-proof, repeatable, no arithmetic in the model's head.

Input  : a measurement-spec JSON (see ../templates/measurement-spec.schema.json).
Output : JSON (default) or a markdown table (--md).
Stdlib only. Single file. No framework. Analytic sensitivity (no monte-carlo).

Composes (cite-only, re-derives nothing):
  band boundaries      ← auto-self-harness §1.2 autonomy_score (HIGH .85 / MED .65)
  Goodhart / residual  ← agentic-observability-protocol (Metron) §5 (score = evidence, not target)
  DEFER-on-residue      ← convergence-engine (abstain + escalate HITL)
"""
import argparse
import json
import math
import sys

DEFAULT_THRESHOLDS = {
    "band_high": 0.85,          # ← autonomy_score §1.2 HIGH
    "band_med": 0.65,           # ← autonomy_score §1.2 MEDIUM
    "conf_inconclusive": 0.60,  # aggregate confidence below this → inconclusive
    "conflict_delta": 0.25,     # weighted child-value stdev at/above this in a material branch → conflict
    "residual_cap": 0.50,       # Σ J-leaf flow at/above this → judgment-dominated (score advisory)
    "materiality": 0.05,        # (advisory; pruning happens in the skill, not the script)
    "material_branch_flow": 0.20,  # a branch is "material" for conflict-detection when its flow ≥ this
    "depth_cap": 3,             # max root→leaf path depth (over-decomposition guard)
}


class SpecError(ValueError):
    """Raised when a measurement-spec is malformed, ungrounded, cyclic, or over-deep."""


def load_spec(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _thresholds(spec):
    t = dict(DEFAULT_THRESHOLDS)
    t.update(spec.get("thresholds", {}) or {})
    return t


def validate_spec(spec):
    """Reject malformed / context-free / ungrounded / cyclic / too-deep specs.

    Returns (by_id, root_id, children, thresholds). Hard refusals:
      - no meta.context_lock         → Step-0 CONTEXT-LOCK (the root bug: scoring a context-free construct)
      - leaf without positive+negative anchors → anchorless-leaf (disguised guessing)
      - a cycle                       → tree must be a DAG (no infinite recursion)
      - depth > depth_cap             → over-decomposition
    """
    if not isinstance(spec, dict) or "nodes" not in spec:
        raise SpecError("spec must be an object with a 'nodes' array")
    ctx = (spec.get("meta") or {}).get("context_lock")
    if not isinstance(ctx, dict):
        raise SpecError(
            "meta.context_lock required — Step-0 CONTEXT-LOCK: refuse to score a "
            "context-free construct (bind context+purpose+stakeholder+targets first)"
        )
    missing = [f for f in ("context", "purpose", "stakeholder", "targets")
               if not (isinstance(ctx.get(f), str) and ctx[f].strip())]
    if missing:
        raise SpecError(
            f"meta.context_lock incomplete — blank/absent sub-field(s) {missing}: a "
            "context-free score is the guess this refuses (bind real context+purpose+stakeholder+targets)"
        )
    nodes = spec["nodes"]
    if not nodes:
        raise SpecError("spec.nodes is empty")

    by_id = {}
    for n in nodes:
        nid = n.get("id")
        if not nid:
            raise SpecError("every node needs an 'id'")
        if nid in by_id:
            raise SpecError(f"duplicate node id: {nid}")
        by_id[nid] = n

    roots = [n for n in nodes if not n.get("parents")]
    if len(roots) != 1:
        raise SpecError(f"exactly one root (no-parent) node required; found {len(roots)}")
    root_id = roots[0]["id"]

    children = {nid: [] for nid in by_id}  # parent_id -> [(child_id, weight), ...]
    for n in nodes:
        for pe in n.get("parents", []):
            pid, w = pe.get("id"), pe.get("weight")
            if pid not in by_id:
                raise SpecError(f"node {n['id']} references unknown parent {pid}")
            if isinstance(w, bool) or not isinstance(w, (int, float)) or not math.isfinite(w) or w <= 0:
                raise SpecError(f"edge {pid}->{n['id']} needs a FINITE weight > 0 (got {w!r})")
            children[pid].append((n["id"], float(w)))

    for n in nodes:
        is_leaf = n.get("kind") == "leaf" or not children[n["id"]]
        if is_leaf:
            lt = n.get("leaf_type")
            if lt not in ("D", "T", "J"):
                raise SpecError(f"leaf {n['id']} needs leaf_type D/T/J (got {lt!r})")
            v = n.get("value")
            if not isinstance(v, (int, float)) or not (0.0 <= v <= 1.0):
                raise SpecError(f"leaf {n['id']} value must be a graded [0,1] membership")
            c = n.get("confidence")
            if not isinstance(c, (int, float)) or not (0.0 <= c <= 1.0):
                raise SpecError(f"leaf {n['id']} confidence must be in [0,1]")
            a = n.get("anchors") or {}
            pos, neg = a.get("positive"), a.get("negative")
            if not (isinstance(pos, str) and pos.strip()) or not (isinstance(neg, str) and neg.strip()):
                raise SpecError(
                    f"leaf {n['id']} REFUSED: missing/blank positive+negative anchors "
                    "(anchorless leaf = disguised guessing)"
                )

    t = _thresholds(spec)
    WHITE, GREY, BLACK = 0, 1, 2
    color = {nid: WHITE for nid in by_id}
    max_depth = [0]

    def dfs(nid, depth):
        color[nid] = GREY
        max_depth[0] = max(max_depth[0], depth)
        for cid, _w in children[nid]:
            if color[cid] == GREY:
                raise SpecError(f"cycle detected via edge {nid}->{cid} (tree must be a DAG)")
            if color[cid] == WHITE:
                dfs(cid, depth + 1)
        color[nid] = BLACK

    try:
        dfs(root_id, 0)
    except RecursionError:
        raise SpecError("spec too deep (recursion limit) — pathological chain exceeding depth_cap")
    if max_depth[0] > t["depth_cap"]:
        raise SpecError(f"depth {max_depth[0]} exceeds depth_cap {t['depth_cap']} (over-decomposition)")
    unreachable = [nid for nid in by_id if color[nid] == WHITE]
    if unreachable:
        raise SpecError(
            f"unreachable/orphan node(s) not connected to root: {unreachable} "
            "(silent-drop refused — connect them to the tree or remove them)"
        )
    return by_id, root_id, children, t


def normalize_weights(children):
    """Per-parent sibling weights → sum 1. Returns {parent_id: {child_id: norm_w}}."""
    norm = {}
    for pid, edges in children.items():
        total = sum(w for _c, w in edges)
        norm[pid] = {c: (w / total) for c, w in edges} if total > 0 else {}
    return norm


def _topo_order(root_id, children):
    """Parents-before-children ordering (DAG)."""
    order, seen = [], set()

    def visit(nid):
        if nid in seen:
            return
        seen.add(nid)
        for cid, _w in children[nid]:
            visit(cid)
        order.append(nid)

    visit(root_id)
    order.reverse()
    return order


def leaf_flows(root_id, children, norm):
    """Flow conservation: root=1, splits to children by normalized weight; DAG path-sum.

    Σ leaf_flows == 1. Returns (leaf_flow_map, full_flow_map).
    """
    order = _topo_order(root_id, children)
    flow = {nid: 0.0 for nid in children}
    flow[root_id] = 1.0
    for nid in order:
        for cid, _w in children[nid]:
            flow[cid] += flow[nid] * norm[nid][cid]
    leaves = [nid for nid in children if not children[nid]]
    return {lf: flow[lf] for lf in leaves}, flow


def node_values(root_id, children, norm, by_id):
    """Bottom-up node value: leaf → its graded value; branch → weighted avg of children."""
    order = _topo_order(root_id, children)
    val = {}
    for nid in reversed(order):  # children before parents
        if not children[nid]:
            val[nid] = float(by_id[nid]["value"])
        else:
            val[nid] = sum(norm[nid][cid] * val[cid] for cid, _w in children[nid])
    return val


def band_of(score, t):
    if score >= t["band_high"]:
        return "HIGH"
    if score >= t["band_med"]:
        return "MEDIUM"
    return "LOW"


def sensitivity(flows_leaf, by_id, score, t, top_k=3):
    """Analytic Δ-to-flip per leaf: how far this leaf's value must move to cross the
    nearest band boundary, and which band the score flips TO (the far side of that boundary)."""
    out = []
    boundaries = [t["band_med"], t["band_high"]]
    for lid, fl in flows_leaf.items():
        if fl <= 0:
            continue
        v = float(by_id[lid]["value"])
        best = None  # (boundary, need)
        for b in boundaries:
            need = (b - score) / fl
            newv = v + need
            if -1e-9 <= newv <= 1 + 1e-9 and abs(need) > 1e-9:
                if best is None or abs(need) < abs(best[1]):
                    best = (b, need)
        if best:
            b, need = best
            flips_to = band_of(b + math.copysign(1e-9, need), t)  # band on the destination side
            out.append({"pivot": lid, "delta_to_flip": round(need, 4), "flips_to": flips_to})
    out.sort(key=lambda d: abs(d["delta_to_flip"]))
    return out[:top_k]


def detect_inconclusive(flows_leaf, full_flow, by_id, children, norm, nvals, agg_conf, t):
    """First-class inconclusive verdict. Fires on ANY: low aggregate confidence,
    judgment-dominated (Σ J-flow ≥ residual_cap), or a material branch whose children conflict."""
    reasons = []
    if agg_conf < t["conf_inconclusive"]:
        reasons.append("low_confidence")
    j_weight = sum(fl for lid, fl in flows_leaf.items() if by_id[lid].get("leaf_type") == "J")
    if j_weight >= t["residual_cap"]:
        reasons.append("judgment_dominated")
    for bid, edges in children.items():
        if not edges or full_flow.get(bid, 0.0) < t["material_branch_flow"]:
            continue
        ws = norm[bid]
        mean = sum(ws[cid] * nvals[cid] for cid, _w in edges)
        var = sum(ws[cid] * (nvals[cid] - mean) ** 2 for cid, _w in edges)
        if math.sqrt(var) >= t["conflict_delta"]:
            reasons.append(f"conflict:{bid}")
    return reasons, round(j_weight, 4)


def compute(spec):
    by_id, root_id, children, t = validate_spec(spec)
    norm = normalize_weights(children)
    flows_leaf, full_flow = leaf_flows(root_id, children, norm)
    nvals = node_values(root_id, children, norm, by_id)
    score = round(sum(flows_leaf[lid] * float(by_id[lid]["value"]) for lid in flows_leaf), 4)
    agg_conf = round(sum(flows_leaf[lid] * float(by_id[lid]["confidence"]) for lid in flows_leaf), 4)
    contribs = sorted(
        [{"id": lid, "leaf_type": by_id[lid].get("leaf_type"), "flow": round(fl, 4),
          "value": float(by_id[lid]["value"]), "contrib": round(fl * float(by_id[lid]["value"]), 4)}
         for lid, fl in flows_leaf.items()],
        key=lambda d: d["contrib"], reverse=True)
    sens = sensitivity(flows_leaf, by_id, score, t)
    reasons, j_weight = detect_inconclusive(
        flows_leaf, full_flow, by_id, children, norm, nvals, agg_conf, t)
    return {
        "construct": (spec.get("meta") or {}).get("construct"),
        "score": score,
        "band": band_of(score, t),
        "aggregate_confidence": agg_conf,
        "leaf_flows": {lid: round(fl, 4) for lid, fl in flows_leaf.items()},
        "contributions": contribs,
        "sensitivity": sens,
        "residual": {"j_weight": j_weight, "judgment_dominated": j_weight >= t["residual_cap"]},
        "inconclusive": {"flag": bool(reasons), "reasons": reasons},
    }


def emit_md(r):
    lines = [
        f"### **{r['construct']}** → score `{r['score']}` · band **{r['band']}** · conf `{r['aggregate_confidence']}`",
        "",
        "| leaf | type | flow | value | contrib |",
        "|---|---|---|---|---|",
    ]
    for c in r["contributions"]:
        lines.append(f"| {c['id']} | {c['leaf_type']} | {c['flow']} | {c['value']} | {c['contrib']} |")
    lines.append("")
    lines.append(f"- residual (Σ J-flow): `{r['residual']['j_weight']}` · judgment_dominated: `{r['residual']['judgment_dominated']}`")
    if r["inconclusive"]["flag"]:
        lines.append(f"- ⚠️ **INCONCLUSIVE → abstain + escalate HITL** · reasons: {', '.join(r['inconclusive']['reasons'])}")
    else:
        lines.append("- conclusive — treat the score as **evidence, not a target** (Goodhart guard)")
    if r["sensitivity"]:
        s = r["sensitivity"][0]
        lines.append(f"- most-sensitive leaf: `{s['pivot']}` (Δ`{s['delta_to_flip']}` → {s['flips_to']})")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Deterministic value-tree aggregator for decompose-abstract-to-measurable (Prisma).")
    ap.add_argument("--spec", required=True, help="path to a measurement-spec JSON")
    ap.add_argument("--out", help="write result to this path (default: stdout)")
    ap.add_argument("--md", action="store_true", help="emit a markdown table instead of JSON")
    ap.add_argument("--high", type=float, help="override band_high threshold")
    ap.add_argument("--med", type=float, help="override band_med threshold")
    ap.add_argument("--conf-threshold", type=float, help="override conf_inconclusive threshold")
    args = ap.parse_args(argv)
    try:
        spec = load_spec(args.spec)
    except (OSError, json.JSONDecodeError) as e:
        print(f"[spec-error] cannot read {args.spec}: {e}", file=sys.stderr)
        return 2
    overrides = {}
    if args.high is not None:
        overrides["band_high"] = args.high
    if args.med is not None:
        overrides["band_med"] = args.med
    if args.conf_threshold is not None:
        overrides["conf_inconclusive"] = args.conf_threshold
    if overrides:
        spec.setdefault("thresholds", {}).update(overrides)
    try:
        result = compute(spec)
    except SpecError as e:
        print(f"[spec-refused] {e}", file=sys.stderr)
        return 3
    text = emit_md(result) if args.md else json.dumps(result, indent=2, ensure_ascii=False)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
