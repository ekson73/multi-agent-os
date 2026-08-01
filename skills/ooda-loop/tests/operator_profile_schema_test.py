"""Independent Draft 2020-12 validation for OODA-loop intake fixtures.

This test uses the repository's pinned ``jsonschema`` dependency.  It complements, rather
than replaces, the dependency-free adapter validator: the latter intentionally supports only
the assertion-keyword subset that these contracts use and fails closed on schema drift.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker, ValidationError


ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates"


def load(name: str) -> dict:
    return json.loads((TEMPLATES / name).read_text(encoding="utf-8"))


def validator(kind: str) -> Draft202012Validator:
    schema = load(f"{kind}.schema.json")
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=FormatChecker())


@pytest.mark.parametrize(
    ("kind", "example"),
    [
        ("operator-profile", "operator-profile.example.json"),
        ("trigger-envelope", "trigger-envelope.example.json"),
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
    ],
)
def test_trigger_envelope_negative_fixtures_are_rejected(mutate) -> None:
    instance = copy.deepcopy(load("trigger-envelope.example.json"))
    mutate(instance)
    with pytest.raises(ValidationError):
        validator("trigger-envelope").validate(instance)
