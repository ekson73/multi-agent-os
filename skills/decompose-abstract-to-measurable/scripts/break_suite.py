#!/usr/bin/env python3
"""Adversarial break-suite for structural_route.py + aggregate_spec.py (Prisma).

INTENT: try to BREAK the router (surface false-negatives), NOT illustrate it. The cases
are author-authored but ADVERSARIAL-intent. Each declares a PREDICTION; the runner reports
predicted-vs-actual so the robustness boundary is EMPIRICAL, not asserted.

This suite ships the tool's own honesty: it CONFIRMS that A1 (a consistent liar who
declares "additive" AND lies on every diagnostic) still slips through — the boundary that
is irreducible without external verification (E2). A tool that hides its failure modes is
theater; this one prints them. Run: `python3 break_suite.py` (any cwd)."""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROUTER = os.path.join(HERE, "structural_route.py")
CTX = {"context": "code review of a multi-tenant PR", "purpose": "gate merge",
       "stakeholder": "eng team", "targets": "the diff"}


def leaf(i, t, v, c, pos="p", neg="n", w=1.0):
    return {"id": i, "parents": [{"id": "root", "weight": w}], "kind": "leaf",
            "leaf_type": t, "value": v, "confidence": c,
            "anchors": {"positive": pos, "negative": neg}}


def spec(construct, nodes, form=None, diags=None, extra_meta=None):
    m = {"construct": construct, "context_lock": CTX}
    if form is not None: m["structural_form"] = form
    if diags is not None: m["h35_diagnostics"] = diags
    if extra_meta: m.update(extra_meta)
    return {"meta": m, "nodes": [{"id": "root", "parents": [], "kind": "branch"}] + nodes}


# --- The adversarial cases -------------------------------------------------
CASES = [
    # A1 — CONSISTENT DOUBLE-LIE: a relational concept (fairness) declared "additive"
    # AND the diagnostics ALL lied to False. Nothing for the cross-check to conflict against.
    ("A1 consistent-double-lie (relational→additive, diagnostics lied False)",
     spec("fairness", [leaf("l1", "D", 0.9, 0.95), leaf("l2", "D", 0.9, 0.95), leaf("l3", "D", 0.9, 0.95)],
          form="additive",
          diags={"q_value_lives_in_relations": False, "q_requires_time_comparison": False,
                 "q_predicts_future_behavior": False, "q_whole_differs_from_sum": False,
                 "q_depends_on_whose_values": False}),
     "BREAK expected: passes as structural_fit_ok / HIGH (false-negative) — the honesty-dependency boundary (only E2 closes it)"),

    # A2 — EVASION BY OMISSION: same relational concept, declared additive, NO diagnostics block at all.
    ("A2 evasion-by-omission (relational→additive, h35_diagnostics ABSENT)",
     spec("fairness", [leaf("l1", "D", 0.9, 0.95), leaf("l2", "D", 0.9, 0.95), leaf("l3", "D", 0.9, 0.95)],
          form="additive", diags=None),
     "HOLD expected: fail-closed → additive_unverified / assistive (no diagnostics ⇒ unverifiable, capped)"),

    # A3 — CONFIDENT-BS: every leaf is J (pure judgment) but each asserted at high confidence 0.95.
    ("A3 confident-BS (all-J leaves, each confidence 0.95)",
     spec("professionalism",
          [{"id": f"l{i}", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
            "leaf_type": "J", "value": 0.9, "confidence": 0.95,
            "anchors": {"positive": "p", "negative": "n"}} for i in range(1, 5)],
          form="normative",
          diags={"q_depends_on_whose_values": True}),
     "HOLD expected: judgment_dominated fires on J-flow regardless of confidence (aggregate defends)"),

    # A4 — GAMED-PERMISSIVE: relational concept but diagnostics crafted to derive ONLY 'normative'
    # (CAP_ASSISTIVE, softer) instead of 'relational' (BLOCK). Attacker steers to the permissive class.
    ("A4 gamed-permissive (relational concept steered to normative-only diagnostics)",
     spec("fairness", [leaf("l1", "D", 0.9, 0.95), leaf("l2", "D", 0.9, 0.95)],
          form="normative",
          diags={"q_value_lives_in_relations": False, "q_depends_on_whose_values": True}),
     "PARTIAL expected: capped-assistive (softer than BLOCK) — steering to the lenient class works"),
]


def run():
    print("=== ADVERSARIAL BREAK-SUITE (Prisma) — predicted vs actual ===\n")
    broke = 0
    for name, sp, prediction in CASES:
        fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)  # system tempdir (read-only-install safe)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(sp, fh)
        try:
            try:
                raw = subprocess.check_output([sys.executable, ROUTER, path], text=True, stderr=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                # router/aggregate refused this spec (exit≠0) — report as an outcome, don't crash the suite.
                print(f"● {name}\n    PRED : {prediction}\n    REAL : ROUTER REFUSED "
                      f"(exit {e.returncode}): {(e.stderr or '').strip()[:160]}\n"
                      f"    → engine held (refused to route an un-scored spec)\n")
                continue
            d = json.loads(raw)
            band = d.get("band"); status = d.get("route", {}).get("status")
            use = d.get("route", {}).get("allowed_use", "—")
            jd = d.get("residual", {}).get("judgment_dominated")
            inc = d.get("inconclusive", {}).get("flag")
            passed_clean = status == "structural_fit_ok" and not inc
            slipped = passed_clean and name.startswith(("A1", "A2"))
            if slipped:
                broke += 1
            print(f"● {name}")
            print(f"    PRED : {prediction}")
            print(f"    REAL : band={band} · route.status={status} · allowed_use={use} · "
                  f"judgment_dominated={jd} · inconclusive={inc}")
            print(f"    → {'⚠️  BROKE (false-negative slipped through)' if slipped else 'engine held / behaved as class policy'}\n")
        finally:
            os.remove(path)
    print(f"=== {broke} adversarial false-negative(s) confirmed (the honesty-dependency boundary; only E2 closes A1) ===")
    return 0


if __name__ == "__main__":
    sys.exit(run())
