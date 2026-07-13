#!/usr/bin/env python3
"""validate_envelope.py — deterministic validator + idempotency digest for the goal-loop
typed envelopes (handoff-as-prompt / dod-as-prompt).

Single responsibility: gate the SHAPE of the envelope (the deterministic half of the hybrid).
The CONTENT (what goal was recovered, what leaves the DoD has) is the LLM's probabilistic job and
is NOT judged here. Stdlib only — no jsonschema dependency (portable, AAIF cross-vendor).

Exit codes:
  0  valid
  2  unreadable   (bad path / bad JSON)
  3  SpecError    (a required key is absent, a range is violated, or a gate is broken -> refused)

Usage:
  validate_envelope.py <file.json> [--type handoff|dod|auto] [--conf-inconclusive 0.60]
  validate_envelope.py <file.json> --digest [--type handoff|dod|auto]

The --digest mode prints a canonical sha256 over the DETERMINISTIC envelope: every `confidence`
float (at any depth), the optional `evaluation` block, and the volatile leaf VALUES of a DoD's
measurement_spec are stripped first. So two runs over the same session-state that differ ONLY in the
probabilistic `confidence` produce the SAME digest — that is the precise idempotency claim
("same state -> same validated envelope, modulo the confidence float"). Deterministic content in;
deterministic digest out.
"""
import argparse
import copy
import hashlib
import json
import sys

DEFAULT_CONF_INCONCLUSIVE = 0.60


def die(code, msg):
    sys.stderr.write(msg.rstrip("\n") + "\n")
    sys.exit(code)


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        die(2, f"[unreadable] no such file: {path}")
    except json.JSONDecodeError as exc:
        die(2, f"[unreadable] invalid JSON in {path}: {exc}")


def detect_type(obj):
    if not isinstance(obj, dict):
        return None
    data = obj.get("data")
    t = data.get("type") if isinstance(data, dict) else None
    if t in ("handoff-as-prompt", "dod-as-prompt"):
        return "handoff" if t == "handoff-as-prompt" else "dod"
    m = obj.get("method")
    if m == "session.goal_recovery":
        return "handoff"
    if m == "session.dod_derivation":
        return "dod"
    return None


def require(obj, keys, where, errs):
    """every key in `keys` must be present in dict obj (present, even if empty array)."""
    if not isinstance(obj, dict):
        errs.append(f"{where}: expected object, got {type(obj).__name__}")
        return
    for k in keys:
        if k not in obj:
            errs.append(f"{where}: missing required key '{k}'")


def in_unit(obj, key, where, errs):
    """key, if present, must be a number in [0,1]."""
    if key in obj:
        v = obj[key]
        if not isinstance(v, (int, float)) or isinstance(v, bool) or not (0.0 <= v <= 1.0):
            errs.append(f"{where}.{key}: must be a number in [0,1], got {v!r}")


def validate_handoff(obj, conf_thresh):
    errs = []
    require(obj, ["jsonrpc", "method", "params", "data"], "handoff", errs)
    p = obj.get("params")
    if not isinstance(p, dict):
        errs.append("handoff.params: expected object")
        return errs
    require(p, ["goal", "motivations", "DoR", "context", "scope", "objectives",
               "confidence", "hypotheses", "inconclusive", "recovered_from", "guardrails", "refs"],
            "handoff.params", errs)
    in_unit(p, "confidence", "handoff.params", errs)

    inconc = p.get("inconclusive") or {}
    require(inconc, ["flag", "reasons"], "handoff.params.inconclusive", errs)
    flag = bool(inconc.get("flag", False))

    scope = p.get("scope") or {}
    require(scope, ["in", "out"], "handoff.params.scope", errs)

    objectives = p.get("objectives") or {}
    require(objectives, ["originating", "primary", "secondary", "auxiliary"], "handoff.params.objectives", errs)

    # --- the gate rules (SpecError conditions) ---
    goal = p.get("goal", "")
    if isinstance(goal, str) and goal.strip() == "" and not flag:
        errs.append("handoff.params: empty goal requires inconclusive.flag=true (a no-goal recovery must DEFER)")

    conf = p.get("confidence")
    rec = p.get("recovered_from")
    if isinstance(conf, (int, float)) and not isinstance(conf, bool) and conf > 0:
        if isinstance(rec, list) and len(rec) == 0:
            errs.append("handoff.params: recovered_from is empty while confidence>0 (a confident recovery must cite its sources — anti-theater grounding)")

    if isinstance(conf, (int, float)) and not isinstance(conf, bool) and conf < conf_thresh and not flag:
        errs.append(f"handoff.params: confidence {conf} < conf_inconclusive {conf_thresh} requires inconclusive.flag=true (never drive a loop on a low-confidence goal)")

    # the chosen goal IS the top-ranked hypothesis (enforces the schema/SKILL invariant, not just prose)
    hyps = p.get("hypotheses") or []
    if isinstance(goal, str) and goal.strip() != "" and not flag and isinstance(hyps, list) and len(hyps) > 0 and isinstance(hyps[0], dict):
        top_goal = hyps[0].get("goal")
        if isinstance(top_goal, str) and top_goal.strip() != "" and top_goal.strip() != goal.strip():
            errs.append("handoff.params: goal must equal hypotheses[0].goal (the chosen goal IS the top-ranked hypothesis) unless inconclusive.flag=true")

    # ranked hypotheses' confidences
    for i, h in enumerate(p.get("hypotheses") or []):
        if isinstance(h, dict):
            require(h, ["goal", "confidence"], f"handoff.params.hypotheses[{i}]", errs)
            in_unit(h, "confidence", f"handoff.params.hypotheses[{i}]", errs)
    return errs


def validate_dod(obj):
    errs = []
    require(obj, ["jsonrpc", "method", "params", "data"], "dod", errs)
    p = obj.get("params")
    if not isinstance(p, dict):
        errs.append("dod.params: expected object")
        return errs
    require(p, ["for_goal", "context_lock", "measurement_spec", "acceptance", "kpis", "termination_predicate"],
            "dod.params", errs)

    for_goal = p.get("for_goal", "")
    if isinstance(for_goal, str) and for_goal.strip() == "":
        errs.append("dod.params.for_goal: must be non-empty (a DoD divorced from its goal is a SpecError)")

    tp = p.get("termination_predicate", "")
    if isinstance(tp, str) and tp.strip() == "":
        errs.append("dod.params.termination_predicate: must be non-empty (it is the driver's --condition)")

    cl = p.get("context_lock") or {}
    require(cl, ["context", "purpose", "stakeholder", "targets"], "dod.params.context_lock", errs)

    spec = p.get("measurement_spec") or {}
    require(spec, ["meta", "nodes"], "dod.params.measurement_spec", errs)
    meta = spec.get("meta") or {}
    if "context_lock" not in meta:
        errs.append("dod.params.measurement_spec.meta: missing context_lock (Prisma Step-0 hard gate — deeper validation is delegated to aggregate_spec.py)")
    if "construct" not in meta:
        errs.append("dod.params.measurement_spec.meta: missing construct")
    nodes = spec.get("nodes")
    if isinstance(nodes, list) and len(nodes) == 0:
        errs.append("dod.params.measurement_spec.nodes: must have >=1 node")

    ev = p.get("evaluation")
    if isinstance(ev, dict):
        require(ev, ["score", "band", "inconclusive"], "dod.params.evaluation", errs)  # match schema: evaluation, when present, is complete
        in_unit(ev, "score", "dod.params.evaluation", errs)
        in_unit(ev, "aggregate_confidence", "dod.params.evaluation", errs)
        if ev.get("band") not in (None, "HIGH", "MEDIUM", "LOW"):
            errs.append(f"dod.params.evaluation.band: must be HIGH|MEDIUM|LOW, got {ev.get('band')!r}")
    return errs


def _strip_volatile(node, kind):
    """recursively remove the probabilistic degrees of freedom so the digest is over the
    DETERMINISTIC envelope only."""
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            if k == "confidence":            # the one probabilistic float, at any depth
                continue
            if kind == "dod" and k == "evaluation":  # progress score — not part of the DoD DEFINITION
                continue
            if kind == "dod" and k in ("value", "raw", "aggregate_confidence"):  # DoD leaf VALUES change as work progresses
                continue
            out[k] = _strip_volatile(v, kind)
        # order-invariance: hypotheses are RANKED by (now-stripped) confidence — a cross-run confidence
        # shift that re-orders them must NOT change the digest. Canonicalize their order for the digest only.
        if isinstance(out.get("hypotheses"), list):
            out["hypotheses"] = sorted(out["hypotheses"], key=lambda x: json.dumps(x, sort_keys=True))
        return out
    if isinstance(node, list):
        return [_strip_volatile(x, kind) for x in node]
    return node


def canonical_digest(obj, kind):
    stripped = _strip_volatile(copy.deepcopy(obj), kind)
    canon = json.dumps(stripped, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def main():
    ap = argparse.ArgumentParser(description="validate a handoff-as-prompt / dod-as-prompt envelope")
    ap.add_argument("file")
    ap.add_argument("--type", choices=["handoff", "dod", "auto"], default="auto")
    ap.add_argument("--conf-inconclusive", type=float, default=DEFAULT_CONF_INCONCLUSIVE)
    ap.add_argument("--digest", action="store_true", help="print the canonical idempotency digest and exit")
    args = ap.parse_args()

    obj = load(args.file)
    kind = args.type if args.type != "auto" else detect_type(obj)
    if kind is None:
        die(3, "[SpecError] cannot detect envelope type (data.type must be handoff-as-prompt|dod-as-prompt, "
               "or method must be session.goal_recovery|session.dod_derivation)")

    if args.digest:
        print(canonical_digest(obj, kind))
        sys.exit(0)

    errs = validate_handoff(obj, args.conf_inconclusive) if kind == "handoff" else validate_dod(obj)
    if errs:
        die(3, "[SpecError] " + f"{kind} envelope refused ({len(errs)}):\n  - " + "\n  - ".join(errs))
    print(f"[ok] {kind} envelope valid: {args.file}")
    sys.exit(0)


if __name__ == "__main__":
    main()
