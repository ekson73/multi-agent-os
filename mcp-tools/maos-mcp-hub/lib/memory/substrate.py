"""
MemorySubstrate — the L8 memory substrate (WT5 / S4): mem0 default,
file/seed degradation, never blocks.

Spec contract (openspec/specs/maos-hub/spec.md → "Substrate-first
activation")::

    Scenario: memory backend unavailable
    - WHEN the L8 backend (default mem0) is unreachable
    - THEN the Hub degrades to file/seed memory, continues (never blocks,
      never fabricates), and records the degradation in the L9 trace.

Adoption verdict (``docs/adoption/mem0-2026-07-01.md``, via the
``agentic-tool-intake`` discipline): **ADAPT (adapter-first, optional
dependency)** — mem0 is the DEFAULT backend but NEVER a hard dependency:

  - ``mem0ai`` is imported lazily; when the package is absent OR the client
    cannot be constructed/reached, the substrate DEGRADES to the file/seed
    backend (the mechanism postflight seeds + memory journals already rely
    on) instead of failing.
  - graphiti (temporal graph memory) is DEFERRED until a measured temporal
    workload exists (no gold-plating — handoff WAVE 1 / os3pd).
  - letta was REJECTED at intake (runtime lock-in: "must use Letta");
    cognee remains the graph-first alternative (see the dossier).

Every resolution and degradation is a LOGGED FIELD (the DoD-gate)::

    l8_substrate{backend, degraded, reason}

emitted through an optional ``on_trace`` callback so the caller can append
it to the L9 trace (Sentinel JSONL) — the substrate does not invent its own
observability channel.

HONESTY NOTE (never fabricates): the file/seed backend is an AVAILABILITY
fallback, not a parity implementation — search is naive substring/recency
over an append-only JSONL, and every search response carries the backend
name so downstream consumers can see which quality tier answered.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

SCHEMA_VERSION = "l8-substrate/1.0.0"

TraceHook = Optional[Callable[[Dict[str, Any]], None]]


@dataclass(frozen=True)
class MemoryRecord:
    """One memory item (the substrate's common currency across backends)."""

    text: str
    user_id: str = "default"
    metadata: Dict[str, Any] = field(default_factory=dict)
    ts: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class FileSeedBackend:
    """Append-only JSONL file/seed memory — the degradation target.

    Always available (stdlib only). Search is honest-but-naive: case-folded
    substring match, most-recent-first.
    """

    name = "file-seed"

    def __init__(self, path: Path) -> None:
        self._path = Path(path)
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def add(self, record: MemoryRecord) -> Dict[str, Any]:
        line = json.dumps(record.to_dict(), ensure_ascii=False, sort_keys=True)
        with self._path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
        return {"backend": self.name, "stored": True}

    def search(
        self, query: str, user_id: str = "default", limit: int = 5
    ) -> List[Dict[str, Any]]:
        if not self._path.exists():
            return []
        needle = (query or "").casefold()
        hits: List[Dict[str, Any]] = []
        # stream line-by-line: the append-only file grows unboundedly and must
        # never be loaded whole into memory (crash-risk on large seeds)
        with self._path.open("r", encoding="utf-8") as fh:
            for raw in fh:
                if not raw.strip():
                    continue
                try:
                    item = json.loads(raw)
                except json.JSONDecodeError:
                    continue  # a torn line never blocks recall
                if not isinstance(item, dict):
                    continue  # valid-JSON-but-not-an-object fragment (torn line)
                if item.get("user_id") != user_id:
                    continue
                if needle and needle not in str(item.get("text", "")).casefold():
                    continue
                hits.append(item)
        hits.sort(key=lambda i: i.get("ts", 0.0), reverse=True)
        return hits[: max(0, limit)]


class Mem0Backend:
    """The DEFAULT L8 backend — a thin adapter over the ``mem0ai`` client.

    The import is LAZY and every failure mode raises ``RuntimeError`` so the
    substrate (not the caller) decides to degrade. This class is deliberately
    minimal: it adapts, it does not re-model mem0's API.
    """

    name = "mem0"

    def __init__(self, client: Optional[Any] = None) -> None:
        if client is None:
            try:
                from mem0 import Memory  # type: ignore[import-not-found]
            except Exception as exc:  # ImportError or transitive init errors
                raise RuntimeError(f"mem0 unavailable: {exc!r}") from exc
            try:
                client = Memory()
            except Exception as exc:
                raise RuntimeError(f"mem0 client init failed: {exc!r}") from exc
        self._client = client

    def add(self, record: MemoryRecord) -> Dict[str, Any]:
        try:
            self._client.add(
                record.text, user_id=record.user_id, metadata=record.metadata
            )
        except Exception as exc:
            raise RuntimeError(f"mem0 add failed: {exc!r}") from exc
        return {"backend": self.name, "stored": True}

    def search(
        self, query: str, user_id: str = "default", limit: int = 5
    ) -> List[Dict[str, Any]]:
        try:
            results = self._client.search(query, user_id=user_id, limit=limit)
        except Exception as exc:
            raise RuntimeError(f"mem0 search failed: {exc!r}") from exc
        # normalize to the substrate's record-dict shape — the mem0 SDK returns
        # a dict envelope ({"results": [...]}) on v1.1+, a bare list on older
        # versions; each hit carries the memory text under "memory"
        if isinstance(results, dict):
            results = results.get("results", [])
        out: List[Dict[str, Any]] = []
        for item in results or []:
            if not isinstance(item, dict):
                continue
            if "text" not in item and "memory" in item:
                item = {**item, "text": item["memory"]}
            out.append(item)
        return out


class MemorySubstrate:
    """Resolve mem0-first, degrade to file/seed, never block, always trace.

    Usage::

        substrate = MemorySubstrate(seed_path=Path(".claude/memory/seed.jsonl"),
                                    on_trace=sentinel_append)
        substrate.add("operator prefers squash merges")
        hits = substrate.search("squash")
        substrate.status()   # -> l8_substrate{backend, degraded, reason}
    """

    def __init__(
        self,
        seed_path: Path,
        mem0_factory: Optional[Callable[[], Any]] = None,
        on_trace: TraceHook = None,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._fallback = FileSeedBackend(seed_path)
        self._on_trace = on_trace
        self._clock = clock
        self._degraded = False
        self._reason: Optional[str] = None
        self._backend: Any = self._fallback
        factory = mem0_factory if mem0_factory is not None else Mem0Backend
        try:
            self._backend = factory()
        except Exception as exc:
            self._degrade(f"resolve: {exc}")
        self._trace("l8_substrate_resolved")

    # -- degradation (the spec scenario) --------------------------------------

    def _degrade(self, reason: str) -> None:
        self._degraded = True
        self._reason = reason
        self._backend = self._fallback

    def _trace(self, event: str) -> None:
        if self._on_trace is not None:
            try:
                self._on_trace({"event": event, **self.status()})
            except Exception:
                # observability must never block the substrate — but a broken
                # hook should still be visible to whoever reads debug logs
                logging.getLogger(__name__).debug(
                    "on_trace hook failed for event %r", event, exc_info=True
                )

    def status(self) -> Dict[str, Any]:
        """The logged field: ``l8_substrate{backend, degraded, reason}``."""
        return {
            "schema_version": SCHEMA_VERSION,
            "l8_substrate": {
                "backend": getattr(self._backend, "name", "unknown"),
                "degraded": self._degraded,
                "reason": self._reason,
            },
        }

    # -- the substrate API (never blocks) -------------------------------------

    def add(
        self,
        text: str,
        user_id: str = "default",
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        record = MemoryRecord(
            text=text,
            user_id=user_id,
            metadata=dict(metadata or {}),
            ts=self._clock(),
        )
        try:
            result = self._backend.add(record)
        except Exception as exc:
            # ANY backend failure (not just Mem0Backend's RuntimeError wrapper —
            # injected backends may raise anything) degrades instead of blocking
            self._degrade(f"add: {exc}")
            self._trace("l8_substrate_degraded")
            result = self._fallback.add(record)
        return {**result, **self.status()}

    def search(
        self, query: str, user_id: str = "default", limit: int = 5
    ) -> Dict[str, Any]:
        try:
            hits = self._backend.search(query, user_id=user_id, limit=limit)
        except Exception as exc:
            self._degrade(f"search: {exc}")
            self._trace("l8_substrate_degraded")
            hits = self._fallback.search(query, user_id=user_id, limit=limit)
        return {"hits": hits, **self.status()}
