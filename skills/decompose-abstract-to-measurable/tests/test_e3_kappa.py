#!/usr/bin/env python3
"""Deterministic tests for e3_kappa.py (the E3 inter-rater κ scorer).
Hand-verified expected values. stdlib-only. Run: python3 tests/test_e3_kappa.py"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import e3_kappa as K  # noqa: E402

TESTS = []
def test(fn): TESTS.append(fn); return fn


def _items(rows, cats=("D", "T", "J")):
    # rows: list of label-lists (one per item), raters r1..rN
    assert rows and rows[0], "test helper needs non-empty rows"
    n = len(rows[0])
    raters = [f"r{i+1}" for i in range(n)]
    items = [{"id": f"i{k}", "leaf": f"l{k}", "construct": "c",
              "labels": {raters[j]: row[j] for j in range(n)}} for k, row in enumerate(rows)]
    return {"categories": list(cats), "raters": raters, "items": items}


@test
def test_perfect_agreement_mixed_cats():
    # all raters agree, ≥2 categories used → κ = 1.0 (P_e < 1)
    spec = _items([["D", "D", "D"], ["T", "T", "T"]])
    out = K.score(spec)
    assert out["fleiss_kappa"] == 1.0, out["fleiss_kappa"]
    assert out["band"] == "almost-perfect", out["band"]
    assert out["e3_pilot_meets_gate"] is True


@test
def test_known_fleiss_value_0_55():
    # 3 raters, 3 items, 2 cats: [DDD],[TTT],[DDT] → hand-computed κ ≈ 0.55 (moderate)
    spec = _items([["D", "D", "D"], ["T", "T", "T"], ["D", "D", "T"]], cats=("D", "T"))
    out = K.score(spec)
    assert abs(out["fleiss_kappa"] - 0.55) < 0.01, out["fleiss_kappa"]
    assert out["band"] == "moderate", out["band"]
    assert out["e3_pilot_meets_gate"] is False  # 0.55 < 0.60 gate


@test
def test_max_disagreement_negative_kappa():
    # 3 raters, 1 item, 3 distinct labels → κ = -0.5 (poor, worse-than-chance)
    spec = _items([["D", "T", "J"]])
    out = K.score(spec)
    assert out["fleiss_kappa"] < 0, out["fleiss_kappa"]
    assert out["band"] == "poor (worse than chance)", out["band"]


@test
def test_disagreement_set_populated():
    spec = _items([["D", "D", "D"], ["D", "T", "J"]])
    out = K.score(spec)
    assert out["unanimous_items"] == 1, out["unanimous_items"]
    assert len(out["disagreement_items"]) == 1, out["disagreement_items"]
    assert out["disagreement_items"][0]["id"] == "i1", out["disagreement_items"]


@test
def test_pairwise_cohen_present():
    spec = _items([["D", "D", "T"], ["T", "T", "T"], ["J", "J", "J"]])
    out = K.score(spec)
    assert len(out["pairwise_cohen"]) == 3, out["pairwise_cohen"]  # 3 pairs from 3 raters
    for p in out["pairwise_cohen"]:
        assert p["n"] == 3, p


@test
def test_unbalanced_design_rejected_internal_guard():
    # fleiss_kappa's OWN guard (called directly, bypassing score() pre-validation):
    # varying raters-per-item → ValueError. Defense-in-depth even if score()'s check is skipped.
    items = [{"id": "i0", "labels": {"r1": "D", "r2": "D", "r3": "T"}},
             {"id": "i1", "labels": {"r1": "T", "r2": "T"}}]
    try:
        K.fleiss_kappa(items, ["D", "T", "J"]); assert False, "should reject unbalanced"
    except ValueError as e:
        assert "unbalanced" in str(e).lower(), str(e)


@test
def test_missing_rater_rejected():
    # score() pre-check: declared 3 raters but an item labelled by only 2 → labels-must-match-declared
    # (qodo #5: raters declared=3, labels/item=2 must fail).
    spec = {"categories": ["D", "T", "J"], "raters": ["r1", "r2", "r3"],
            "items": [{"id": "i0", "leaf": "l", "construct": "c", "labels": {"r1": "D", "r2": "D", "r3": "D"}},
                      {"id": "i1", "leaf": "l", "construct": "c", "labels": {"r1": "T", "r2": "T"}}]}
    try:
        K.score(spec); assert False, "should reject missing rater"
    except ValueError as e:
        assert "match" in str(e).lower(), str(e)


@test
def test_duplicate_raters_rejected():
    spec = {"categories": ["D", "T", "J"], "raters": ["r1", "r1", "r2"],
            "items": [{"id": "i0", "leaf": "l", "construct": "c", "labels": {"r1": "D", "r2": "T"}}]}
    try:
        K.score(spec); assert False, "should reject duplicate raters"
    except ValueError as e:
        assert "unique" in str(e).lower(), str(e)


@test
def test_duplicate_ids_rejected():
    # duplicate item ids would collapse the pairwise-Cohen label maps → must reject
    spec = {"categories": ["D", "T", "J"], "raters": ["r1", "r2"],
            "items": [{"id": "dup", "leaf": "l", "construct": "c", "labels": {"r1": "D", "r2": "D"}},
                      {"id": "dup", "leaf": "l", "construct": "c", "labels": {"r1": "T", "r2": "T"}}]}
    try:
        K.score(spec); assert False, "should reject duplicate ids"
    except ValueError as e:
        m = str(e).lower(); assert "id" in m and "unique" in m, str(e)


@test
def test_unknown_label_rejected():
    spec = _items([["D", "X", "D"]])  # 'X' not in D/T/J
    try:
        K.score(spec); assert False, "should have raised ValueError"
    except ValueError as e:
        assert "not in categories" in str(e).lower(), str(e)


@test
def test_honest_caveat_travels_with_result():
    # anti-theater: the reliability≠validity + capability≠validation caveat is ALWAYS present
    spec = _items([["D", "D", "D"], ["T", "T", "T"]])
    out = K.score(spec)
    assert "capability ≠ validation" in out["honest_caveat"], out["honest_caveat"]
    assert "reliability" in out["honest_caveat"].lower()


@test
def test_cli_specerror_exit3():
    # malformed labels file → clean SystemExit(3), not a traceback
    bad = {"categories": ["D", "T", "J"], "raters": ["r1"], "items": [{"id": "i", "labels": {"r1": "Z"}}]}
    fd, path = tempfile.mkstemp(suffix=".json"); os.close(fd)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(bad, fh)
    try:
        r = subprocess.run([sys.executable, os.path.join(HERE, "..", "scripts", "e3_kappa.py"),
                            "--labels", path], capture_output=True, text=True)
        assert r.returncode == 3, (r.returncode, r.stderr)
        assert "SpecError" in r.stderr, r.stderr
    finally:
        os.remove(path)


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
