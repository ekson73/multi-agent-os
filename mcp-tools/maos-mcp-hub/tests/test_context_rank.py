"""Tests — ContextRank (T4 / WAVE 5): context-aware ranking v1.

tasks.md T4 acceptance, as logged fields / golden fixtures (the DoD-gate):
  "same input → same ranking (byte-stable); the 'why' is emitted."
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from lib.registry import HubConsole, HubRecord, HubRegistry
from lib.registry.context_rank import (
    extract_signals,
    load_signals_file,
    rank,
    render_ranking,
)

_HERE = Path(__file__).resolve()
_HUB_DIR = _HERE.parents[1]
_REPO_ROOT = _HERE.parents[3]


# ------------------------------------------------------------------ fixtures


def _mk_record(rid: str, **kw) -> HubRecord:
    base = dict(
        id=rid, owner_repo="acme/tools", layer="L2", role="r", category="skill",
        harness_coverage=(), requires=(), conflicts_with=(), guardrails="g",
        impact="i", recipes=(), activation="opt-in", license_spdx="MIT",
        provenance="p", ttl=None, last_validated="2026-07-02",
        rollback="rb", security_status="vetted", derived_from="d",
    )
    base.update(kw)
    return HubRecord(**base)


@pytest.fixture()
def registry() -> HubRegistry:
    reg = HubRegistry()
    reg._add(_mk_record("guard", activation="always-on", category="substrate"))
    reg._add(_mk_record("cognee", activation="opt-in",
                        recipes=("legacy-refactor", "codebase-onboarding")))
    reg._add(_mk_record("spec-kit", activation="opt-in", recipes=("new-idea-to-mvp",)))
    reg._add(_mk_record("mallory", activation="excluded", security_status="rejected"))
    return reg


def _compass_graph(generated_utc: str = "2026-07-02T12:00:00+00:00") -> dict:
    """A synthetic work-compass --json snapshot: a legacy-refactor project."""
    return {
        "meta": {"count": 2, "scope": "current", "generated_utc": generated_utc},
        "by_domain": {},
        "items": [
            {"id": "git:refactor/legacy-billing", "domain": "branch",
             "title": "Refactor legacy billing module", "status": "open",
             "last_ts": generated_utc, "refs": {"pr": "acme/app#7"}, "flags": []},
            {"id": "jira:APP-12", "domain": "ticket",
             "title": "Characterize legacy behavior with cognee",
             "status": "in-progress", "last_ts": generated_utc, "refs": {}, "flags": []},
        ],
    }


# ------------------------------------------------------ signal extraction


def test_signals_are_sorted_and_stable() -> None:
    sig = extract_signals(_compass_graph())
    assert sig == tuple(sorted(set(sig)))
    assert "legacy" in sig and "cognee" in sig and "billing" in sig


def test_volatile_fields_do_not_change_signals() -> None:
    """DoD byte-stability: only stable content contributes — two snapshots of
    the same project state (different generated_utc) yield identical tokens."""
    assert extract_signals(_compass_graph("2026-07-02T12:00:00+00:00")) == \
        extract_signals(_compass_graph("2027-01-01T00:00:00+00:00"))


def test_malformed_graph_degrades_to_empty(tmp_path: Path) -> None:
    assert extract_signals(["not", "a", "dict"]) == ()
    assert extract_signals({"items": "notalist"}) == ()
    bad = tmp_path / "bad.json"
    bad.write_text("{ truncated", encoding="utf-8")
    assert load_signals_file(bad) == ()
    assert load_signals_file(tmp_path / "absent.json") == ()


def test_stopwords_filtered_but_refactor_is_a_signal() -> None:
    sig = extract_signals(_compass_graph())
    assert "refactor" in sig            # intent signal, deliberately NOT a stopword
    assert "open" not in sig            # status noise
    assert "branch" not in sig          # domain-plumbing noise


# ---------------------------------------------------------------- ranking


def test_ranking_is_byte_stable_same_input_same_output(registry: HubRegistry) -> None:
    """T4 acceptance: same input → same ranking (byte-stable)."""
    sig = extract_signals(_compass_graph())
    r1 = json.dumps(rank(registry, sig), sort_keys=True)
    r2 = json.dumps(rank(registry, extract_signals(_compass_graph())), sort_keys=True)
    assert r1 == r2


def test_golden_ranking_order_and_scores(registry: HubRegistry) -> None:
    """Golden fixture: the legacy-refactor snapshot must surface cognee first
    (tool-id match +2 AND recipe matches), guard next (tier prior)."""
    ranking = rank(registry, extract_signals(_compass_graph()))
    assert [e["id"] for e in ranking] == ["cognee", "guard", "spec-kit"]
    by_id = {e["id"]: e for e in ranking}
    # cognee: 'cognee' id match (+2) + 'legacy'/'refactor' → recipe legacy-refactor (+1+1)
    assert by_id["cognee"]["score"] >= 4
    assert by_id["guard"]["score"] == 2          # tier prior only
    assert by_id["spec-kit"]["score"] == 0       # nothing matches


def test_why_is_emitted_for_every_entry(registry: HubRegistry) -> None:
    """T4 acceptance: the 'why' is emitted — every entry, even zero-score."""
    ranking = rank(registry, extract_signals(_compass_graph()))
    for entry in ranking:
        assert entry["why"], f"empty why for {entry['id']}"
    by_id = {e["id"]: e for e in ranking}
    assert any("matches tool id 'cognee'" in w for w in by_id["cognee"]["why"])
    assert any("recipe 'legacy-refactor'" in w for w in by_id["cognee"]["why"])
    assert by_id["spec-kit"]["why"] == ["no signal match; activation-tier baseline"]


def test_excluded_records_are_never_ranked(registry: HubRegistry) -> None:
    ranking = rank(registry, ("mallory",))
    assert "mallory" not in [e["id"] for e in ranking]


def test_empty_signals_rank_is_tier_ordered_baseline(registry: HubRegistry) -> None:
    ranking = rank(registry, ())
    assert [e["id"] for e in ranking] == ["guard", "cognee", "spec-kit"]
    assert ranking[0]["why"] == ["activation-tier prior: always-on (+2)"]


def test_top_parameter_truncates(registry: HubRegistry) -> None:
    assert len(rank(registry, (), top=2)) == 2


# ------------------------------------------------------- console integration


def test_console_context_aware_view_uses_engine_when_signals_present(
    registry: HubRegistry,
) -> None:
    sig = extract_signals(_compass_graph())
    console = HubConsole(registry, [], signals=sig)
    out = console.render("context-aware")
    assert "why:" in out
    assert out.index("cognee") < out.index("spec-kit")
    assert console.render("context-aware") == out  # byte-stable through the view


def test_console_context_aware_baseline_without_signals(registry: HubRegistry) -> None:
    out = HubConsole(registry, []).render("context-aware")
    assert "no work-compass snapshot provided" in out
    assert "why:" not in out


def test_rendered_ranking_lines_carry_positions_and_reasons() -> None:
    lines = render_ranking(
        [{"id": "x", "score": 3, "activation": "opt-in", "category": "skill",
          "why": ["signal 'x' matches tool id 'x' (+2)"]}],
        ("x",),
    )
    assert any(ln.startswith("  1. x") for ln in lines)
    assert any("why: signal 'x'" in ln for ln in lines)


# ------------------------------------------------------------------- CLI


def test_cli_signals_flag_ranks_with_reasons(tmp_path: Path) -> None:
    """CLI smoke over the LIVE repo: a snapshot naming a real recipe token
    produces a ranked view with reasons; run twice → byte-identical."""
    snap = tmp_path / "compass.json"
    snap.write_text(json.dumps(_compass_graph()), encoding="utf-8")
    script = _HUB_DIR / "lib" / "registry" / "console.py"
    argv = [sys.executable, str(script), "view", "context-aware",
            "--signals", str(snap), "--repo-root", str(_REPO_ROOT)]
    run1 = subprocess.run(argv, capture_output=True, text=True, check=True)
    run2 = subprocess.run(argv, capture_output=True, text=True, check=True)
    assert "why:" in run1.stdout
    assert run1.stdout == run2.stdout  # T4 acceptance at the CLI surface


def test_cli_malformed_signals_degrades_to_baseline(tmp_path: Path) -> None:
    snap = tmp_path / "broken.json"
    snap.write_text("{ nope", encoding="utf-8")
    script = _HUB_DIR / "lib" / "registry" / "console.py"
    out = subprocess.run(
        [sys.executable, str(script), "view", "context-aware",
         "--signals", str(snap), "--repo-root", str(_REPO_ROOT)],
        capture_output=True, text=True, check=True,
    )
    assert "no usable tokens" in out.stderr
    assert "no work-compass snapshot provided" in out.stdout
