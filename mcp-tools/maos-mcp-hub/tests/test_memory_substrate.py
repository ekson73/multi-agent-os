"""
Tests for the L8 memory substrate (WT5 / S4).

The acceptance IS the spec scenario (openspec/specs/maos-hub/spec.md →
"Substrate-first activation" / "memory backend unavailable"), asserted as
LOGGED FIELDS — never prose:

    WHEN the L8 backend (default mem0) is unreachable
    THEN the Hub degrades to file/seed memory, continues (never blocks,
    never fabricates), and records the degradation in the L9 trace.
"""

from pathlib import Path
from typing import Any, Dict, List

import pytest

from lib.memory import FileSeedBackend, MemoryRecord, MemorySubstrate


def _unreachable_factory():
    raise RuntimeError("mem0 unavailable: simulated outage")


def _substrate(tmp_path: Path, **kwargs) -> MemorySubstrate:
    return MemorySubstrate(
        seed_path=tmp_path / "seed.jsonl",
        clock=lambda: 1000.0,
        **kwargs,
    )


# --------------------------------------------------------------------------- #
# the spec scenario: backend unavailable -> degrade, continue, trace
# --------------------------------------------------------------------------- #

def test_unreachable_mem0_degrades_to_file_seed_with_logged_reason(tmp_path):
    sub = _substrate(tmp_path, mem0_factory=_unreachable_factory)
    status = sub.status()["l8_substrate"]
    assert status["backend"] == "file-seed"
    assert status["degraded"] is True
    assert "simulated outage" in status["reason"]


def test_degraded_substrate_continues_add_and_search(tmp_path):
    """Never blocks: add + recall keep working on the file/seed tier."""
    sub = _substrate(tmp_path, mem0_factory=_unreachable_factory)
    result = sub.add("operator prefers squash merges", user_id="op")
    assert result["stored"] is True
    assert result["l8_substrate"]["backend"] == "file-seed"

    found = sub.search("squash", user_id="op")
    assert [h["text"] for h in found["hits"]] == ["operator prefers squash merges"]
    # never fabricates: the answering backend is named in every response
    assert found["l8_substrate"]["backend"] == "file-seed"


def test_degradation_is_recorded_in_the_trace(tmp_path):
    """The L9 hook receives l8_substrate{backend, degraded, reason}."""
    events: List[Dict[str, Any]] = []
    sub = _substrate(
        tmp_path, mem0_factory=_unreachable_factory, on_trace=events.append
    )
    assert events, "resolution must emit a trace event"
    resolved = events[0]
    assert resolved["event"] == "l8_substrate_resolved"
    assert resolved["l8_substrate"]["degraded"] is True
    assert resolved["l8_substrate"]["reason"]
    assert sub.status()["schema_version"] == "l8-substrate/1.0.0"


def test_mid_call_outage_degrades_without_raising(tmp_path):
    """A backend that dies AFTER resolution still never blocks the caller."""

    class DiesOnFirstUse:
        name = "mem0"

        def add(self, record: MemoryRecord):
            raise RuntimeError("mem0 add failed: connection reset")

        def search(self, query, user_id="default", limit=5):
            raise RuntimeError("mem0 search failed: connection reset")

    events: List[Dict[str, Any]] = []
    sub = _substrate(
        tmp_path, mem0_factory=DiesOnFirstUse, on_trace=events.append
    )
    assert sub.status()["l8_substrate"]["degraded"] is False  # resolved fine

    result = sub.add("fact survives the outage")
    assert result["stored"] is True
    assert result["l8_substrate"]["backend"] == "file-seed"
    assert result["l8_substrate"]["degraded"] is True
    assert any(e["event"] == "l8_substrate_degraded" for e in events)

    # the retried write actually landed in the fallback store
    hits = sub.search("survives")["hits"]
    assert len(hits) == 1


def test_healthy_injected_client_is_used_not_degraded(tmp_path):
    """With a working backend the substrate does NOT degrade."""

    class HealthyStub:
        name = "mem0"

        def __init__(self):
            self.items: List[MemoryRecord] = []

        def add(self, record: MemoryRecord):
            self.items.append(record)
            return {"backend": self.name, "stored": True}

        def search(self, query, user_id="default", limit=5):
            return [
                r.to_dict()
                for r in self.items
                if query in r.text and r.user_id == user_id
            ][:limit]

    sub = _substrate(tmp_path, mem0_factory=HealthyStub)
    status = sub.add("remember the tokenizer is ceil(len/4)")["l8_substrate"]
    assert status == {"backend": "mem0", "degraded": False, "reason": None}
    assert sub.search("tokenizer")["hits"]


def test_default_factory_degrades_cleanly_when_mem0ai_not_installed(tmp_path):
    """On a machine without the optional dependency, resolution degrades
    (never raises) — the exact CI environment this suite runs in."""
    sub = MemorySubstrate(seed_path=tmp_path / "seed.jsonl")
    status = sub.status()["l8_substrate"]
    assert status["backend"] in ("mem0", "file-seed")
    if status["backend"] == "file-seed":
        assert status["degraded"] is True
        assert status["reason"]


# --------------------------------------------------------------------------- #
# file/seed backend honesty + robustness
# --------------------------------------------------------------------------- #

def test_file_seed_search_is_user_scoped_and_recency_ordered(tmp_path):
    backend = FileSeedBackend(tmp_path / "seed.jsonl")
    backend.add(MemoryRecord(text="older squash note", user_id="op", ts=1.0))
    backend.add(MemoryRecord(text="newer squash note", user_id="op", ts=2.0))
    backend.add(MemoryRecord(text="squash but other user", user_id="x", ts=3.0))
    hits = backend.search("squash", user_id="op")
    assert [h["text"] for h in hits] == ["newer squash note", "older squash note"]


def test_file_seed_tolerates_torn_lines(tmp_path):
    path = tmp_path / "seed.jsonl"
    backend = FileSeedBackend(path)
    backend.add(MemoryRecord(text="good record", user_id="op", ts=1.0))
    with path.open("a", encoding="utf-8") as fh:
        fh.write('{"torn": \n')  # a crashed writer's partial line
    assert [h["text"] for h in backend.search("good", user_id="op")] == [
        "good record"
    ]


def test_trace_hook_failure_never_blocks_the_substrate(tmp_path):
    def broken_hook(_event):
        raise ValueError("observability sink down")

    sub = _substrate(
        tmp_path, mem0_factory=_unreachable_factory, on_trace=broken_hook
    )
    assert sub.add("still works")["stored"] is True


def test_non_runtime_error_from_injected_backend_still_degrades(tmp_path):
    """PR #199 review (amazon-q + Copilot): the never-blocks contract must
    hold for ANY exception type, not just Mem0Backend's RuntimeError wrapper."""

    class RaisesConnectionError:
        name = "mem0"

        def add(self, record: MemoryRecord):
            raise ConnectionError("socket closed")

        def search(self, query, user_id="default", limit=5):
            raise TimeoutError("backend hung")

    sub = _substrate(tmp_path, mem0_factory=RaisesConnectionError)
    result = sub.add("survives non-RuntimeError outage", user_id="op")
    assert result["stored"] is True
    assert result["l8_substrate"]["degraded"] is True
    assert sub.search("survives", user_id="op")["hits"]


def test_mem0_backend_normalizes_dict_envelope_and_memory_field():
    """PR #199 review (Copilot): the mem0 SDK v1.1+ returns
    {"results": [...]} with the text under "memory" — both shapes normalize."""
    from lib.memory import Mem0Backend

    class DictEnvelopeClient:
        def search(self, query, user_id="default", limit=5):
            return {
                "results": [
                    {"id": "m1", "memory": "squash merges preferred"},
                    "not-a-dict-is-skipped",
                ]
            }

    hits = Mem0Backend(client=DictEnvelopeClient()).search("squash")
    assert hits == [
        {"id": "m1", "memory": "squash merges preferred",
         "text": "squash merges preferred"}
    ]

    class BareListClient:
        def search(self, query, user_id="default", limit=5):
            return [{"text": "already normalized"}]

    hits = Mem0Backend(client=BareListClient()).search("already")
    assert hits == [{"text": "already normalized"}]


def test_substrate_is_deterministic_given_fixed_clock(tmp_path):
    sub = _substrate(tmp_path, mem0_factory=_unreachable_factory)
    sub.add("alpha", user_id="op")
    a = sub.search("alpha", user_id="op")
    b = sub.search("alpha", user_id="op")
    assert a == b
