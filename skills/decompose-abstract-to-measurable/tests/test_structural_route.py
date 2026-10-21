#!/usr/bin/env python3
"""Deterministic regression tests for structural_route.py (the class-routing layer).
Assertive (pass/fail) companion to the illustrative break_suite.py. stdlib-only.
Run: python3 tests/test_structural_route.py"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROUTER = os.path.join(HERE, "..", "scripts", "structural_route.py")
CTX = {"context": "c", "purpose": "p", "stakeholder": "s", "targets": "t"}


def _leaf(i, v=0.9, c=0.95):
    return {"id": i, "parents": [{"id": "root", "weight": 1.0}], "kind": "leaf",
            "leaf_type": "D", "value": v, "confidence": c,
            "anchors": {"positive": "hi", "negative": "lo"}}


def _run(form=None, diags=None, legacy=False):
    spec = {"meta": {"construct": "x", "context_lock": CTX},
            "nodes": [{"id": "root", "parents": [], "kind": "branch"}, _leaf("l1"), _leaf("l2")]}
    if form is not None:
        spec["meta"]["structural_form"] = form
    if diags is not None:
        spec["meta"]["h35_diagnostics"] = diags
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)  # system tempdir (read-only-install safe)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(spec, fh)
    try:
        argv = [sys.executable, ROUTER] + (["--legacy-unrouted"] if legacy else []) + [path]
        return json.loads(subprocess.check_output(argv, text=True))
    finally:
        os.remove(path)


TESTS = []


def test(fn):
    TESTS.append(fn); return fn


@test
def test_relational_blocked():
    d = _run(form="relational", diags={"q_value_lives_in_relations": True})
    assert d["band"] == "BLOCKED", d["band"]
    assert d["route"]["status"] == "structural_mismatch", d["route"]
    assert d["score"] is None, d["score"]


@test
def test_gestalt_blocked():
    d = _run(form="gestalt", diags={"q_whole_differs_from_sum": True})
    assert d["route"]["allowed_use"] == "blocked", d["route"]


@test
def test_additive_with_diagnostics_fit_ok():
    d = _run(form="additive", diags={"q_value_lives_in_relations": False, "q_requires_time_comparison": False,
                                     "q_predicts_future_behavior": False, "q_whole_differs_from_sum": False,
                                     "q_depends_on_whose_values": False})
    assert d["route"]["status"] == "structural_fit_ok", d["route"]
    assert d["route"]["allowed_use"] == "per_gates", d["route"]


@test
def test_additive_without_diagnostics_failclosed():
    # A2 defense: additive declared but NO diagnostics -> unverifiable -> capped-assistive
    d = _run(form="additive", diags=None)
    assert d["route"]["status"] == "additive_unverified", d["route"]
    assert d["route"]["allowed_use"] == "assistive_only", d["route"]
    assert d["inconclusive"]["flag"] is True, d["inconclusive"]


@test
def test_declared_vs_derived_conflict_review():
    # declared additive, but a diagnostic derives relational -> two channels disagree -> REVIEW
    d = _run(form="additive", diags={"q_value_lives_in_relations": True})
    assert d["band"] == "REVIEW", d["band"]
    assert d["route"]["status"] == "classification_conflict", d["route"]


@test
def test_normative_assistive_capped():
    d = _run(form="normative", diags={"q_depends_on_whose_values": True})
    assert d["route"]["status"] == "fit_with_cap", d["route"]
    assert "ASSISTIVE" in d["band"], d["band"]


@test
def test_context_signature_present():
    d = _run(form="additive", diags={"q_value_lives_in_relations": False})
    assert d["context_signature"].startswith("sha256:"), d.get("context_signature")


@test
def test_under_specified_failclosed_default():
    # A2b defense: NO structural_form declared and no diagnostics -> fail-closed by DEFAULT.
    # Unrouted omission must NOT earn a clean band; it is held for review (was fail-OPEN passthrough).
    d = _run(form=None, diags=None)
    assert d["route"]["status"] == "under_specified", d["route"]
    assert d["route"]["allowed_use"] == "blocked_pending_review", d["route"]
    assert d["route"]["human_review"] is True, d["route"]
    assert d["inconclusive"]["flag"] is True, d["inconclusive"]
    assert d["band"].startswith("REVIEW (unrouted"), d["band"]


@test
def test_under_specified_legacy_optin_passthrough():
    # v1.0.0 compatibility preserved, but OPT-IN only via --legacy-unrouted (not the default).
    d = _run(form=None, diags=None, legacy=True)
    assert d["route"]["status"] == "under_specified", d["route"]
    assert d["route"].get("legacy_unrouted") is True, d["route"]
    assert d["band"] is not None and not str(d["band"]).startswith("REVIEW"), d["band"]  # passthrough


@test
def test_a2b_omission_with_relational_diagnostics_blocked():
    # The core A2b hole: remove structural_form from a relational spec. Diagnostics still derive
    # relational -> must BLOCK (an additive tree cannot represent it), not pass as HIGH.
    d = _run(form=None, diags={"q_value_lives_in_relations": True})
    assert d["band"] == "BLOCKED", d["band"]
    assert d["route"]["status"] == "structural_mismatch", d["route"]
    assert d["score"] is None, d["score"]


@test
def test_loss_vector_shape():
    # loss_vector carries 3 computable dims + 2 offline-null (honest null, not 0)
    d = _run(form="additive", diags={"q_value_lives_in_relations": False})
    lv = d["loss_vector"]
    for k in ("structural_loss", "semantic_loss", "criterion_loss", "normative_loss", "validation_loss"):
        assert k in lv, (k, lv)
    assert lv["normative_loss"] is None and lv["validation_loss"] is None, lv  # offline-only = honest null


def main():
    passed = 0
    for fn in TESTS:
        try:
            fn(); print(f"PASS  {fn.__name__}"); passed += 1
        except AssertionError as e:
            print(f"FAIL  {fn.__name__}: {e}")
        except Exception as e:
            print(f"ERROR {fn.__name__}: {e!r}")
    print(f"\n{passed}/{len(TESTS)} passed")
    return 0 if passed == len(TESTS) else 1


if __name__ == "__main__":
    sys.exit(main())
