#!/usr/bin/env python3
"""Behavioral tests for aggregate_spec.py. Stdlib only. Run: python tests/test_aggregate.py
Exit 0 = all pass; nonzero = failure. No pytest dependency."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(SKILL, "scripts"))
import aggregate_spec as A  # noqa: E402

EX = os.path.join(SKILL, "examples")


def _load(name):
    with open(os.path.join(EX, name), "r", encoding="utf-8") as fh:
        return json.load(fh)


CTX = {"context": "t", "purpose": "t", "stakeholder": "t", "targets": "t"}
CASES = []


def case(fn):
    CASES.append(fn)
    return fn


@case
def test_pr_healthy_high_conclusive():
    r = A.compute(_load("pr-healthy.json"))
    assert r["band"] == "HIGH", r["band"]                       # (i) all-D-ish high → HIGH
    assert r["score"] >= 0.85, r["score"]
    assert r["aggregate_confidence"] >= 0.85, r["aggregate_confidence"]
    assert r["inconclusive"]["flag"] is False, r["inconclusive"]
    assert r["residual"]["judgment_dominated"] is False
    assert abs(sum(r["leaf_flows"].values()) - 1.0) < 1e-6      # flow conservation Σ=1


@case
def test_doc_professional_judgment_dominated():
    r = A.compute(_load("doc-professional.json"))
    assert r["residual"]["judgment_dominated"] is True, r["residual"]   # (ii) Σ J-flow ≥ 0.5
    assert r["inconclusive"]["flag"] is True
    assert "judgment_dominated" in r["inconclusive"]["reasons"], r["inconclusive"]


@case
def test_quality_conflict_flag():
    r = A.compute(_load("quality-conflict.json"))
    assert r["inconclusive"]["flag"] is True                          # (iii) conflicting material branch
    assert any(x.startswith("conflict:") for x in r["inconclusive"]["reasons"]), r["inconclusive"]
    assert r["band"] == "MEDIUM", r["band"]


@case
def test_cycle_rejected():                                            # (iv) cycle → refuse
    spec = {"meta": {"construct": "c", "context_lock": CTX}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "a", "parents": [{"id": "root", "weight": 1}, {"id": "b", "weight": 1}], "kind": "branch"},
        {"id": "b", "parents": [{"id": "a", "weight": 1}], "kind": "branch"},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "cycle" in str(e).lower(), e
        return
    raise AssertionError("cycle spec was NOT rejected")


@case
def test_anchorless_leaf_rejected():                                  # (v) anchorless leaf → refuse
    spec = {"meta": {"construct": "c", "context_lock": CTX}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "anchor" in str(e).lower(), e
        return
    raise AssertionError("anchorless leaf was NOT rejected")


@case
def test_context_free_rejected():                                     # (vi) Step-0 gate → refuse
    spec = {"meta": {"construct": "c"}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9,
         "anchors": {"positive": "p", "negative": "n"}},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "context_lock" in str(e).lower(), e
        return
    raise AssertionError("context-free spec was NOT rejected")


@case
def test_nonfinite_weight_rejected():                                 # (vii) NaN/inf weight → refuse, not NaN-score
    spec = {"meta": {"construct": "c", "context_lock": CTX}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": float("inf")}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9,
         "anchors": {"positive": "p", "negative": "n"}},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "finite" in str(e).lower(), e
        return
    raise AssertionError("non-finite weight was NOT rejected (would ship a NaN score)")


@case
def test_orphan_node_rejected():                                      # (viii) unreachable/orphan → refuse silent-drop
    spec = {"meta": {"construct": "c", "context_lock": CTX}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9,
         "anchors": {"positive": "p", "negative": "n"}},
        {"id": "a", "parents": [{"id": "b", "weight": 1}], "kind": "branch"},   # a,b: unreachable cycle
        {"id": "b", "parents": [{"id": "a", "weight": 1}], "kind": "branch"},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "unreachable" in str(e).lower() or "orphan" in str(e).lower(), e
        return
    raise AssertionError("unreachable/orphan node was silently dropped, NOT rejected")


@case
def test_blank_context_subfield_rejected():                           # (ix) junk Step-0 gate → refuse
    spec = {"meta": {"construct": "c", "context_lock": {"context": " ", "purpose": "p",
                                                        "stakeholder": "s", "targets": "t"}},
            "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9,
         "anchors": {"positive": "p", "negative": "n"}},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "context_lock" in str(e).lower(), e
        return
    raise AssertionError("blank context_lock sub-field was NOT rejected")


@case
def test_blank_anchor_rejected():                                     # (x) whitespace-junk anchor → refuse
    spec = {"meta": {"construct": "c", "context_lock": CTX}, "nodes": [
        {"id": "root", "parents": [], "kind": "branch"},
        {"id": "l1", "parents": [{"id": "root", "weight": 1}], "kind": "leaf",
         "leaf_type": "D", "value": 0.8, "confidence": 0.9,
         "anchors": {"positive": " ", "negative": "   "}},
    ]}
    try:
        A.compute(spec)
    except A.SpecError as e:
        assert "anchor" in str(e).lower(), e
        return
    raise AssertionError("blank whitespace anchors were NOT rejected")


def run():
    failures = 0
    for fn in CASES:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
        except Exception as e:  # noqa: BLE001
            failures += 1
            print(f"FAIL  {fn.__name__}: {e}")
    print(f"\n{len(CASES) - failures}/{len(CASES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(run())
