#!/usr/bin/env python3
# structural_route.py — Prisma structural-form classifier + class-routing gate.
#
# A COMPOSABLE LAYER over aggregate_spec.py (subprocess, NOT a fork). It answers the
# question the additive engine cannot: "is this construct's STRUCTURE even representable
# by an additive value-tree?" — then routes the score accordingly.
#
# Routing (SAGE v10.7 engine-anchored class matrix):
#   additive / atomic                 → per_gates   (an additive tree is a valid model)
#   relational / gestalt              → BLOCKED     (additive tree structurally CANNOT represent it)
#   normative / dispositional / temporal → ASSISTIVE (band-capped + human review)
#   additive / atomic WITHOUT h35_diagnostics → ASSISTIVE (unverified; fail-closed)
#
# It also cross-checks the author-DECLARED structural_form against the form DERIVED from
# concrete H35 diagnostic answers (two channels must agree) — a declared/derived conflict
# → REVIEW. Emits a context_signature + a loss_vector (3 computable dims + 2 offline-null).
#
# ⚠️ HONEST LIMIT (do NOT hide): this catches evasion-by-omission (A2, fail-closed) and
# declared/derived conflict — but a CONSISTENT liar who declares "additive" AND lies on
# every diagnostic (A1) still passes. That boundary is IRREDUCIBLE without external
# verification (E2 — external non-author benchmark). See break_suite.py (A1 = confirmed FN).
#
# Seam: aggregate_spec.py = the pure additive aggregator (f=0); this = the router on top.
# stdlib-only. Usage:  python3 structural_route.py <spec.json>
import json, subprocess, sys, hashlib, os

HERE = os.path.dirname(os.path.abspath(__file__))
AGG = os.path.join(HERE, "aggregate_spec.py")

BLOCK_ON_ADDITIVE_TREE = {"relational", "gestalt"}          # additive tree CANNOT represent → mismatch/blocked
CAP_ASSISTIVE = {"normative", "dispositional", "temporal"}  # representable but band-capped + review
QORDER = [("relational", "q_value_lives_in_relations"), ("temporal", "q_requires_time_comparison"),
          ("dispositional", "q_predicts_future_behavior"), ("gestalt", "q_whole_differs_from_sum"),
          ("normative", "q_depends_on_whose_values")]


def route(spec_path):
    with open(spec_path, encoding="utf-8") as fh:
        spec = json.load(fh)
    meta = spec.get("meta", {})
    declared = meta.get("structural_form"); diags = meta.get("h35_diagnostics", {})
    try:
        base = json.loads(subprocess.check_output([sys.executable, AGG, "--spec", spec_path]))
    except subprocess.CalledProcessError as e:
        # aggregate_spec.py refused the spec (exit 2 unreadable / 3 SpecError). Surface it cleanly —
        # do NOT crash with a raw traceback; an un-scored spec simply cannot be routed.
        sys.stderr.write(f"structural_route: aggregate_spec.py rejected the spec (exit {e.returncode}) — "
                         f"cannot route an un-scored spec.\n")
        raise SystemExit(e.returncode or 3)
    out = {k: base.get(k) for k in ["score", "band", "aggregate_confidence", "residual", "inconclusive"]}
    # context_signature — binds the routing to the exact locked context
    cl = json.dumps(meta.get("context_lock", {}), sort_keys=True, ensure_ascii=False)
    out["context_signature"] = "sha256:" + hashlib.sha256(cl.encode()).hexdigest()[:16]
    # H35: derive structural forms from concrete diagnostic answers (decomposed judgment > holistic label)
    derived = [form for form, q in QORDER if diags.get(q) is True] or (["additive"] if diags else [])
    # Cross-check declared vs derived (two channels must agree)
    conflict = bool(diags) and declared is not None and (
        (declared in ("additive", "atomic") and any(f in BLOCK_ON_ADDITIVE_TREE | CAP_ASSISTIVE for f in derived))
        or (declared not in ("additive", "atomic") and declared not in derived))
    sl = None  # structural_loss (deterministic where derivable)
    if declared is None:
        route_v = {"status": "under_specified", "reason": "structural_form_not_declared"}
    elif conflict:
        sl = 0.7
        route_v = {"status": "classification_conflict", "allowed_use": "blocked_pending_review", "contestable": True,
                   "reason": f"declared '{declared}' but H35 diagnostics derive {derived}", "h35_derived": derived}
        out["band"] = "REVIEW"; out["inconclusive"] = {"flag": True, "reasons": ["classification_conflict"]}
    elif declared in BLOCK_ON_ADDITIVE_TREE:
        sl = 1.0
        route_v = {"status": "structural_mismatch", "allowed_use": "blocked", "h35_derived": derived,
                   "reason": f"'{declared}' cannot be represented by an additive value-tree"}
        out["score"] = None; out["band"] = "BLOCKED"; out["inconclusive"] = {"flag": True, "reasons": ["structural_mismatch"]}
    elif declared in CAP_ASSISTIVE:
        sl = 0.35
        route_v = {"status": "fit_with_cap", "allowed_use": "assistive_only", "human_review": True, "h35_derived": derived,
                   "reason": f"'{declared}' representable but band-capped per class policy"}
        out["band"] = f"ASSISTIVE (capped; engine said {out['band']})"
    elif declared in ("additive", "atomic") and not diags:
        # Fail-closed hardening (closes break-suite A2 evasion-by-omission):
        # an additive/atomic claim with NO h35_diagnostics is UNVERIFIABLE — it cannot earn a
        # clean pass, because omission would otherwise be *safer* for an evader than declaring.
        # Capped-assistive pending diagnostics (fail-closed > fail-open). Does NOT catch A1
        # (consistent lie WITH diagnostics) — that boundary is irreducible without external verification (E2).
        sl = 0.35
        route_v = {"status": "additive_unverified", "allowed_use": "assistive_only", "human_review": True,
                   "reason": "additive/atomic declared WITHOUT h35_diagnostics — structural fit unverifiable; "
                             "capped pending diagnostics (fail-closed)"}
        out["band"] = f"ASSISTIVE (capped; unverified; engine said {out['band']})"
        out["inconclusive"] = {"flag": True, "reasons": ["structural_form_unverified"]}
    else:
        sl = 0.1
        route_v = {"status": "structural_fit_ok", "form": declared, "h35_derived": derived, "allowed_use": "per_gates"}
    out["route"] = route_v
    rh = meta.get("R_human")
    out["loss_vector"] = {
        "structural_loss": sl, "semantic_loss": meta.get("semantic_loss_estimate"),
        "criterion_loss": (None if rh is None else round(1 - rh, 3)),
        "normative_loss": None, "validation_loss": None,
        "caveats": ["semantic_loss=LLM/author auto-report", "normative/validation=offline-only (null=honest)"]}
    return out


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("usage: structural_route.py <spec.json>\n"); sys.exit(2)
    print(json.dumps(route(sys.argv[1]), ensure_ascii=False))
