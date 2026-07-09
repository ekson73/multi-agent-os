#!/usr/bin/env python3
# e3_kappa.py — Prisma E3 inter-rater reliability scorer (the maturity-mover harness).
#
# WHAT: given N independent raters × M items, each labelled with a categorical leaf-type
# (D/T/J — the skill's typing rubric), compute inter-rater agreement:
#   - Fleiss' κ (multi-rater, the headline E3 metric)
#   - pairwise Cohen's κ (per rater-pair, for granularity)
#   - per-item agreement + the disagreement set (WHICH leaves split the raters — the honest signal)
#   - Landis-Koch band + the E3 gate (κ ≥ 0.60 — the moderate→substantial boundary; per
#     canonical Landis-Koch "substantial" = 0.61–0.80, "moderate" = 0.41–0.60, so κ==0.60 is "moderate")
#
# WHY (honest scope): this measures the RELIABILITY of the D/T/J typing — do independent
# agents, following the same rubric, classify the same leaf the same way? High κ ⇒ the rubric
# is reproducible (a real validity property, Cronbach-Meehl). Low κ ⇒ the typing is subjective
# ⇒ an honest weakness to surface, NOT hide. This is rater-vs-rater agreement, so it needs NO
# author-supplied "gold" answer — the skill author's bias does not enter (unlike E2, whose
# CASES must be non-author). It does NOT prove the constructs are "correctly" decomposed; it
# proves the typing step is (un)reliable. A passing κ is NECESSARY-not-sufficient for E3, and a
# lean pilot (small M/N) is a SIGNAL, not the full study. Capability ≠ validation (SAGE v10.7).
#
# stdlib-only. Usage:
#   python3 e3_kappa.py --labels labels.json
#   labels.json = {"categories":["D","T","J"],
#                  "raters":["r1","r2","r3"],
#                  "items":[{"id":"c1.l1","construct":"...","leaf":"...",
#                            "labels":{"r1":"D","r2":"T","r3":"D"}}, ...]}
import json, sys, argparse, itertools

E3_GATE = 0.60  # memorialized E3 bar = the moderate→substantial boundary
                # (Landis-Koch: "substantial" = 0.61–0.80, "moderate" = 0.41–0.60; κ==0.60 lands in "moderate")


def landis_koch(k):
    if k < 0:      return "poor (worse than chance)"
    if k <= 0.20:  return "slight"
    if k <= 0.40:  return "fair"
    if k <= 0.60:  return "moderate"
    if k <= 0.80:  return "substantial"
    return "almost-perfect"


def fleiss_kappa(items, cats):
    """Fleiss' κ over M items × fixed rater count N × k categories.
    Requires every item rated by the SAME number of raters N (complete design)."""
    if not items:
        raise ValueError("no items")
    # n_ij = count of raters assigning category j to item i
    counts = []
    N_set = set()
    for it in items:
        row = {c: 0 for c in cats}
        for lab in it["labels"].values():
            if lab not in row:
                raise ValueError(f"item {it.get('id')}: label '{lab}' not in categories {cats}")
            row[lab] += 1
        counts.append(row)
        N_set.add(sum(row.values()))
    if len(N_set) != 1:
        raise ValueError(f"unbalanced design — raters-per-item varies: {sorted(N_set)} "
                         f"(Fleiss' κ requires a constant N; drop partial items or use Cohen pairwise)")
    N = N_set.pop()
    if N < 2:
        raise ValueError("need ≥2 raters per item")
    M = len(items)
    # P_i (agreement within item i)
    P = []
    for row in counts:
        s = sum(v * v for v in row.values())
        P.append((s - N) / (N * (N - 1)))
    P_bar = sum(P) / M
    # p_j (marginal proportion per category)
    pj = {c: sum(row[c] for row in counts) / (M * N) for c in cats}
    P_e = sum(v * v for v in pj.values())
    kappa = 1.0 if P_e == 1.0 else (P_bar - P_e) / (1 - P_e)
    return kappa, N, M, pj, P


def cohen_kappa(labels_a, labels_b, cats):
    """Cohen's κ for two raters over the shared items (both must have a label)."""
    ids = [i for i in labels_a if i in labels_b]
    n = len(ids)
    if n == 0:
        return None, 0
    agree = sum(1 for i in ids if labels_a[i] == labels_b[i]) / n
    pa = {c: sum(1 for i in ids if labels_a[i] == c) / n for c in cats}
    pb = {c: sum(1 for i in ids if labels_b[i] == c) / n for c in cats}
    pe = sum(pa[c] * pb[c] for c in cats)
    k = 1.0 if pe == 1.0 else (agree - pe) / (1 - pe)
    return k, n


def score(spec):
    cats = spec["categories"]
    raters = spec["raters"]
    items = spec["items"]
    # Validate the declared design BEFORE scoring — else a malformed payload (missing/extra/
    # duplicate raters, duplicate item ids) silently produces numbers over the WRONG set and
    # could pass the E3 gate. Fail-closed (an E3 instrument must not be fool-able).
    if not raters:
        raise ValueError("raters must be non-empty")
    if len(set(raters)) != len(raters):
        raise ValueError(f"raters must be unique: {raters}")
    ids = [it.get("id") for it in items]
    if len(set(ids)) != len(ids):
        raise ValueError("item ids must be unique (duplicate ids collapse the pairwise-Cohen label maps)")
    expected = set(raters)
    for it in items:
        if set(it.get("labels", {})) != expected:
            raise ValueError(f"item {it.get('id')}: labels {sorted(it.get('labels', {}))} "
                             f"must match the declared raters {sorted(expected)} exactly")
    kappa, N, M, pj, P = fleiss_kappa(items, cats)
    kappa_r = round(kappa, 4)  # report + gate-decide + band from the SAME rounded value (no boundary mismatch)
    # per-item agreement + disagreement set
    per_item = []
    disagreement = []
    for it, p in zip(items, P):
        labs = list(it["labels"].values())
        unanimous = len(set(labs)) == 1
        rec = {"id": it.get("id"), "leaf": it.get("leaf"), "construct": it.get("construct"),
               "labels": it["labels"], "agreement": round(p, 4), "unanimous": unanimous}
        per_item.append(rec)
        if not unanimous:
            disagreement.append({"id": it.get("id"), "leaf": it.get("leaf"),
                                 "construct": it.get("construct"), "labels": it["labels"]})
    # pairwise Cohen
    pairwise = []
    for a, b in itertools.combinations(raters, 2):
        la = {it["id"]: it["labels"][a] for it in items if a in it["labels"]}
        lb = {it["id"]: it["labels"][b] for it in items if b in it["labels"]}
        ck, cn = cohen_kappa(la, lb, cats)
        pairwise.append({"pair": f"{a}×{b}", "cohen_kappa": (None if ck is None else round(ck, 4)),
                         "n": cn, "band": (None if ck is None else landis_koch(ck))})
    return {
        "metric": "fleiss_kappa",
        "fleiss_kappa": kappa_r,
        "band": landis_koch(kappa_r),
        "e3_gate": E3_GATE,
        "e3_pilot_meets_gate": kappa_r >= E3_GATE,
        "raters": N, "items": M, "categories": cats,
        "category_marginals": {c: round(v, 4) for c, v in pj.items()},
        "unanimous_items": sum(1 for r in per_item if r["unanimous"]),
        "disagreement_items": disagreement,
        "pairwise_cohen": pairwise,
        # HONESTY caveat travels WITH the result (anti-theater — never a bare pass/fail)
        "honest_caveat": ("Inter-rater RELIABILITY of the D/T/J typing only. A lean pilot is a "
                          "SIGNAL, not full E3 (needs larger M/N + ideally non-author constructs). "
                          "Reliability ≠ validity: agreement does not prove the typing is correct, "
                          "only reproducible. capability ≠ validation (SAGE v10.7); Tier-Professional "
                          "remains BLOCKED regardless of this κ."),
    }


def main():
    ap = argparse.ArgumentParser(description="Prisma E3 inter-rater κ scorer")
    ap.add_argument("--labels", required=True, help="path to labels JSON")
    args = ap.parse_args()
    try:
        with open(args.labels, encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"e3_kappa: cannot read labels '{args.labels}': {e}\n")
        raise SystemExit(2)
    try:
        out = score(spec)
    except (ValueError, KeyError) as e:
        sys.stderr.write(f"e3_kappa: SpecError: {e}\n")
        raise SystemExit(3)
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
