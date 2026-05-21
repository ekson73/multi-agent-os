"""Validate OS3PD v4.13.0 ontology + enforcement matrix.

Tests:
1. Turtle file parses cleanly via rdflib.
2. Turtle file contains all expected OWL classes.
3. Turtle file declares 7 principle named individuals.
4. JSON-LD file is valid JSON with 7 policy entries.
5. JSON-LD declares a real json-schema.org draft URL as $schema.
6. JSON-LD policies cross-reference NamedIndividuals declared in the .ttl.
7. JSON-LD contains no hardcoded TRE-style numerator (governance-theater check).

Run: pytest tests/test_ontology_parse.py -v
"""

import json
import pathlib
import re

import pytest
import rdflib
from jsonschema import Draft202012Validator  # noqa: F401  (import-time sanity)

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
TTL_PATH = REPO_ROOT / "ontology" / "os3pd-v4.13.0.ttl"
JSONLD_PATH = REPO_ROOT / "ontology" / "os3pd-enforcement-matrix.jsonld"

OS3PD_NS = "https://github.com/ekson73/multi-agent-os/ontology/os3pd/4.13.0#"
OWL = rdflib.Namespace("http://www.w3.org/2002/07/owl#")
RDF = rdflib.Namespace("http://www.w3.org/1999/02/22-rdf-syntax-ns#")


@pytest.fixture(scope="module")
def graph():
    g = rdflib.Graph()
    g.parse(str(TTL_PATH), format="turtle")
    return g


@pytest.fixture(scope="module")
def matrix():
    return json.loads(JSONLD_PATH.read_text(encoding="utf-8"))


def test_turtle_parses_clean(graph):
    """At least 40 triples after parse; zero parse errors."""
    assert len(graph) > 40, f"Expected >40 triples in ontology, got {len(graph)}"


def test_turtle_has_expected_classes(graph):
    expected = {
        "DigitalActor", "HumanActor", "AIAgent",
        "ExecutionHarness", "PromptHarness", "ValidationHarness",
        "DigitalArtifact", "SourceCode", "ArchivedAsset",
        "GuardrailPolicy",
    }
    found = {
        str(s).replace(OS3PD_NS, "")
        for s in graph.subjects(RDF["type"], OWL["Class"])
        if str(s).startswith(OS3PD_NS)
    }
    missing = expected - found
    assert not missing, f"Missing expected OWL classes: {missing}"


def test_turtle_has_7_principle_individuals(graph):
    principles = {
        str(s).replace(OS3PD_NS, "")
        for s in graph.subjects(RDF["type"], OWL["NamedIndividual"])
        if str(s).startswith(OS3PD_NS) and "Principle_" in str(s)
    }
    assert len(principles) == 7, (
        f"Expected 7 principle individuals, got {len(principles)}: {principles}"
    )


def test_jsonld_is_valid_json(matrix):
    assert "enforcement_matrix" in matrix
    assert len(matrix["enforcement_matrix"]) == 7, (
        f"Expected 7 policy entries, got {len(matrix['enforcement_matrix'])}"
    )


def test_jsonld_declares_real_schema(matrix):
    schema_uri = matrix.get("$schema", "")
    assert schema_uri.startswith("https://json-schema.org/draft/"), (
        f"$schema must be a real json-schema.org draft URL, got: {schema_uri!r}"
    )


def test_jsonld_policies_reference_ontology_individuals(graph, matrix):
    """Every policy_id in the JSON-LD must resolve to a NamedIndividual in the .ttl."""
    ttl_individuals = {
        str(s) for s in graph.subjects(RDF["type"], OWL["NamedIndividual"])
    }
    missing = []
    for policy in matrix["enforcement_matrix"]:
        pid = policy["policy_id"].replace("os3pd:", OS3PD_NS)
        if pid not in ttl_individuals:
            missing.append(policy["policy_id"])
    assert not missing, (
        f"policy_id(s) not declared as owl:NamedIndividual in the .ttl: {missing}"
    )


def test_jsonld_has_no_hardcoded_tre_numerator(matrix):
    """Anti-theater check: reject the bugs_corrigidos/bugs_introduzidos hardcoded gate."""
    text = json.dumps(matrix)
    forbidden = re.compile(
        r"bugs[_-]?(?:corrigidos|introduzidos|fixed|introduced)\s*=",
        re.IGNORECASE,
    )
    assert not forbidden.search(text), (
        "Hardcoded TRE-style numerator detected (governance theater)"
    )
