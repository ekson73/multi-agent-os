"""Independent Draft 2020-12 validation for OODA-loop intake fixtures.

This test uses the repository's pinned ``jsonschema`` dependency.  It complements, rather
than replaces, the dependency-free adapter validator: the latter intentionally supports only
the assertion-keyword subset that these contracts use and fails closed on schema drift.
"""

from __future__ import annotations

import copy
import datetime as dt
import json
import re
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker, ValidationError


ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates"
RFC3339 = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)
FORMAT_CHECKER = FormatChecker()


@FORMAT_CHECKER.checks("date-time")
def valid_rfc3339_datetime(value: object) -> bool:
    """Validate both RFC3339 shape/offset and real calendar/time values."""
    if not isinstance(value, str) or RFC3339.fullmatch(value) is None:
        return False
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None and parsed.utcoffset() is not None


def load(name: str) -> dict:
    return json.loads((TEMPLATES / name).read_text(encoding="utf-8"))


def validator(kind: str) -> Draft202012Validator:
    schema = load(f"{kind}.schema.json")
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=FORMAT_CHECKER)


@pytest.mark.parametrize(
    ("kind", "example"),
    [
        ("operator-profile", "operator-profile.example.json"),
        ("trigger-envelope", "trigger-envelope.example.json"),
        ("run-envelope", "run-envelope.example.json"),
    ],
)
def test_examples_are_valid_draft_2020_12(kind: str, example: str) -> None:
    validator(kind).validate(load(example))


@pytest.mark.parametrize(
    "mutate",
    [
        lambda value: value["operator"].pop("role"),
        lambda value: value["authority"]["baseline_acknowledgements"].pop(),
        lambda value: value["authority"]["human_decision_domains"].append("business-rule"),
        lambda value: value["delivery"].update({"candidate_stages": ["not-a-stage"]}),
        lambda value: value["authority"].update({"invented_grant": "deploy"}),
    ],
)
def test_operator_profile_negative_fixtures_are_rejected(mutate) -> None:
    instance = copy.deepcopy(load("operator-profile.example.json"))
    mutate(instance)
    with pytest.raises(ValidationError):
        validator("operator-profile").validate(instance)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda value: value["security"].update({"raw_payload_retained": True}),
        lambda value: value["security"].update({"authority_claim": "authorized"}),
        lambda value: value["request"].update({"auto_merge": "authorized"}),
        lambda value: value["idempotency"].update({"replay_key": "not-a-digest"}),
        lambda value: value["event"].update({"observed_at": "2026-08-01T12:00:00"}),
        lambda value: value["event"].update({"observed_at": "2026-99-99T99:99:99Z"}),
    ],
)
def test_trigger_envelope_negative_fixtures_are_rejected(mutate) -> None:
    instance = copy.deepcopy(load("trigger-envelope.example.json"))
    mutate(instance)
    with pytest.raises(ValidationError):
        validator("trigger-envelope").validate(instance)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda value: value["result"].update({"outcome": "PARTIAL"}),
        lambda value: value["result"].update({"stop_marker": "STOP-HITL-TECHNICAL"}),
        lambda value: value["intake"].update({"lifecycle_stage": "reveng"}),
        lambda value: value["intake"].update({"execution_authority": "proven"}),
        lambda value: value.update({"result": {"outcome": "DELIVERY_DONE", "status": "error", "stop_marker": "STOP-HITL", "route": "act"}}),
        lambda value: value.update({"result": {"outcome": "PARKED_PARTIAL", "status": "ok", "stop_marker": "STOP-DONE", "route": "park"}}),
        lambda value: value.update({"result": {"outcome": "BLOCKED_HITL", "status": "hitl", "stop_marker": "STOP-ERROR", "route": "act"}}),
        lambda value: value.update({"result": {"outcome": "ERROR", "status": "partial", "stop_marker": "CONTINUE", "route": "consult"}}),
        lambda value: (
            value.update({"result": {"outcome": "CONTINUE", "status": "partial", "stop_marker": "CONTINUE", "route": "act"}}),
            value["intake"]["execution_authority"].update({"state": "denied"}),
            value["intake"].update({"access": "ACCESS_FORBIDDEN"}),
        ),
        lambda value: (
            value.update({"result": {"outcome": "CONTINUE", "status": "partial", "stop_marker": "CONTINUE", "route": "act"}}),
            value["intake"]["execution_authority"].update({"state": "proven"}),
            value["intake"].update({"access": "ACCESS_READY"}),
            value["budget"].update({"lease": "expired", "continuation_authorized": True}),
        ),
        lambda value: (
            value.update({"result": {"outcome": "CONTINUE", "status": "partial", "stop_marker": "CONTINUE", "route": "act"}}),
            value["intake"]["execution_authority"].update({"state": "proven"}),
            value["intake"].update({"access": "ACCESS_READY"}),
            value["budget"].update({"cancelled": True, "continuation_authorized": True}),
        ),
        lambda value: (
            value.update({"result": {"outcome": "CONTINUE", "status": "partial", "stop_marker": "CONTINUE", "route": "act"}}),
            value["intake"]["execution_authority"].update({"state": "proven"}),
            value["intake"].update({"access": "ACCESS_READY"}),
            value["budget"].update({"continuation_authorized": False}),
        ),
        lambda value: (
            value.update({"result": {"outcome": "CONTINUE", "status": "partial", "stop_marker": "CONTINUE", "route": "act"}}),
            value["intake"]["execution_authority"].update({"state": "proven", "evidence_refs": []}),
            value["intake"].update({"access": "ACCESS_READY"}),
            value["budget"].update({"continuation_authorized": True}),
        ),
    ],
)
def test_run_envelope_negative_fixtures_are_rejected(mutate) -> None:
    instance = copy.deepcopy(load("run-envelope.example.json"))
    mutate(instance)
    with pytest.raises(ValidationError):
        validator("run-envelope").validate(instance)


def test_run_envelope_allows_act_with_proven_authority_and_ready_access() -> None:
    instance = copy.deepcopy(load("run-envelope.example.json"))
    instance["result"] = {
        "outcome": "DELIVERY_DONE",
        "status": "ok",
        "stop_marker": "STOP-DONE",
        "route": "act",
    }
    instance["intake"]["execution_authority"] = {
        "state": "proven",
        "evidence_refs": ["repository-policy:accepted-decision-42"],
    }
    instance["intake"]["access"] = "ACCESS_READY"
    validator("run-envelope").validate(instance)


def test_run_envelope_allows_continue_act_with_live_authorized_budget() -> None:
    instance = copy.deepcopy(load("run-envelope.example.json"))
    instance["result"] = {
        "outcome": "CONTINUE",
        "status": "partial",
        "stop_marker": "CONTINUE",
        "route": "act",
    }
    instance["intake"]["execution_authority"] = {
        "state": "proven",
        "evidence_refs": ["repository-policy:accepted-decision-42"],
    }
    instance["intake"]["access"] = "ACCESS_READY"
    instance["budget"].update(
        {"lease": "valid", "cancelled": False, "continuation_authorized": True}
    )
    validator("run-envelope").validate(instance)
