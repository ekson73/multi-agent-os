"""
Tests for the intake-batch verdicts (WT10 / P3, stories S10/S9).

The acceptance IS the spec scenario (openspec/specs/maos-hub/spec.md →
"Supply-chain gate": reproduce the EXCLUDED verdicts for
gsd-build/get-shit-done and MemPalace) plus the batch invariants, asserted as
LOGGED FIELDS + golden-fixture invariants over the REAL eval — never prose:

    WHEN the 26 INCLUDED experts + BRIDGE + EXCLUDED reproductions are
    dispositioned in fixtures/intake_verdicts.yaml
    THEN evals/intake_batch_eval.py reports verdict=pass with every check
    (A1..A7) true — else the worktree does NOT close (DoD gate).
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

from evals.intake_batch_eval import (
    CONDUCTORS_TXT,
    VERDICTS_YAML,
    VERDICT_VOCABULARY,
    load_enforcement_conductors,
    load_fixture,
    run_eval,
)

HUB_DIR = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def report():
    return run_eval()


@pytest.fixture(scope="module")
def fixture():
    return load_fixture()


# --------------------------------------------------------------------------- #
# the DoD gate — the whole eval must pass, and each check individually
# --------------------------------------------------------------------------- #

def test_eval_verdict_pass(report):
    assert report["verdict"] == "pass", report["violations"]


@pytest.mark.parametrize("check", ["A1", "A2", "A3", "A4", "A5", "A6", "A7"])
def test_each_check_true(report, check):
    assert report["checks"][check] is True, [
        v for v in report["violations"] if v.startswith(check)
    ]


# --------------------------------------------------------------------------- #
# named spec scenario — supply-chain gate reproduction (logged fields)
# --------------------------------------------------------------------------- #

def test_gsd_rug_pull_reproduced(fixture):
    gsd = next(
        (e for e in fixture["entries"] if e["repo"] == "gsd-build/get-shit-done"),
        None,
    )
    assert gsd is not None, "fixture missing the gsd-build/get-shit-done EXCLUDED entry"
    assert gsd["set"] == "EXCLUDED"
    assert gsd["verdict"] == "EXCLUDED"
    assert gsd["blocked"] is True
    assert gsd["safe_successor"].startswith("open-gsd/")
    assert gsd["evidence"]


def test_mempalace_reproduced(fixture):
    mp = next((e for e in fixture["entries"] if e["id"] == "mempalace"), None)
    assert mp is not None, "fixture missing the mempalace EXCLUDED entry"
    assert mp["set"] == "EXCLUDED"
    assert mp["blocked"] is True
    assert mp["safe_successor"] == "mem0ai/mem0"
    assert mp["evidence"]


# --------------------------------------------------------------------------- #
# cross-SSOT consistency — fixture mirrors the RULE-011 enforcement registry
# --------------------------------------------------------------------------- #

def test_conductor_class_mirrors_enforcement_ssot(fixture):
    assert set(fixture["conductor_class"]) == load_enforcement_conductors()


def test_no_conductor_gets_plain_install(fixture):
    conductors = load_enforcement_conductors()
    for e in fixture["entries"]:
        if e["id"] in conductors:
            assert e["verdict"] != "INSTALL", e["id"]


# --------------------------------------------------------------------------- #
# corpus integrity
# --------------------------------------------------------------------------- #

def test_counts(fixture):
    sets = {}
    for e in fixture["entries"]:
        sets[e["set"]] = sets.get(e["set"], 0) + 1
    assert sets == {"INCLUDED": 26, "BRIDGE": 1, "EXCLUDED": 5}


def test_vocabulary_clean(fixture):
    for e in fixture["entries"]:
        assert e["verdict"] in VERDICT_VOCABULARY, e["id"]


def test_paths_exist():
    assert VERDICTS_YAML.is_file()
    assert CONDUCTORS_TXT.is_file()


# --------------------------------------------------------------------------- #
# CLI contract — module runs, prints valid JSON, exit 0 on pass
# --------------------------------------------------------------------------- #

def test_cli_emits_logged_fields():
    proc = subprocess.run(
        [sys.executable, "-m", "evals.intake_batch_eval"],
        cwd=HUB_DIR,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["verdict"] == "pass"
    assert payload["counts"]["included"] == 26
