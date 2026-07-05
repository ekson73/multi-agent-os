#!/usr/bin/env python3
"""
conflict-checker.py — MAOS Agora conflict-checker (issue #182).

Single input (a STACK of tool ids) → collision report over the curated
incompatibility edge-list (``mcp-tools/maos-mcp-hub/lib/gateway/
conflicts.yaml``), powered by the #180 gating-seam engine
(``lib.gateway.policy``). Detection composes the #188 RULE-011
single-conductor scan instead of re-implementing it.

Input modes (exactly ONE):
  --stack "ECC,base,mem0"    comma/space-separated tool ids
  --stack-file PATH          one id per line ('#' comments + blanks ignored)
  --rule011 PATH|-           a RULE-011 JSON line (from plugin-scripts/
                             governance/single-conductor-scan.sh); reads
                             .detected_conductors as the stack

Output: human-readable report (default) · ``--json`` = logged fields
(the DoD-GATE surface — acceptance is a checkable field, never prose).

Exit codes: 0 = clean · 2 = collisions found · 1 = usage/load error.

Every reported collision is cross-confirmed by the live PolicyResolver
(``engine_confirmed``): the same edge must also DENY under
``resolver.check()`` with the stack as active profile — two independent
derivations must agree (the #202 discipline).

Version: 1.0.0 · Protocol: ADR-006 §4 single-conductor · conflicts.yaml SSOT
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Sequence

_REPO_ROOT = Path(__file__).resolve().parent.parent
_HUB_ROOT = _REPO_ROOT / "mcp-tools" / "maos-mcp-hub"
_DEFAULT_CONFLICTS = _HUB_ROOT / "lib" / "gateway" / "conflicts.yaml"

SCHEMA = "maos-conflict-checker/1"


def _import_policy():
    """Import the #180 engine (lib/gateway/policy.py) from the hub tree.

    Loaded by FILE PATH (not ``import lib.gateway``) so the gateway
    package ``__init__`` — which drags httpx-dependent siblings — never
    runs: the engine itself needs only PyYAML.
    """
    import importlib.util

    mod_path = _HUB_ROOT / "lib" / "gateway" / "policy.py"
    try:
        spec = importlib.util.spec_from_file_location("maos_hub_policy", mod_path)
        policy = importlib.util.module_from_spec(spec)
        # dataclasses resolve their owning module through sys.modules —
        # register BEFORE exec or @dataclass blows up under Python 3.12+.
        sys.modules["maos_hub_policy"] = policy
        spec.loader.exec_module(policy)  # type: ignore[union-attr]
    except (ImportError, FileNotFoundError) as exc:
        raise SystemExit(
            f"conflict-checker: cannot load the gating engine ({exc}). "
            "Install PyYAML (see mcp-tools/maos-mcp-hub/requirements.txt) "
            "and run from the multi-agent-os checkout."
        )
    return policy


def _parse_stack_arg(raw: str) -> List[str]:
    parts = [p.strip() for chunk in raw.split(",") for p in chunk.split()]
    return [p for p in parts if p]


def _parse_stack_file(path: Path) -> List[str]:
    ids: List[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        ids.append(line)
    return ids


def _parse_rule011(source: str) -> List[str]:
    """Extract .detected_conductors from a RULE-011 JSON line ('-' = stdin)."""
    text = sys.stdin.read() if source == "-" else Path(source).read_text(
        encoding="utf-8"
    )
    # tolerate surrounding log noise: pick the first line that parses as JSON
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("rule") == "RULE-011":
            conductors = obj.get("detected_conductors", [])
            return [str(c) for c in conductors if c]
    raise SystemExit(
        "conflict-checker: no RULE-011 JSON line found in the given input."
    )


def analyze(
    stack: Sequence[str], conflicts_path: Path
) -> Dict[str, object]:
    """Cross a stack against the curated edges → logged-field report dict."""
    policy = _import_policy()
    records = policy.load_conflict_records(conflicts_path)

    # de-dup, keep deterministic order (sorted — same input, same output)
    ids = sorted({t for t in (s.strip() for s in stack) if t})
    idset = set(ids)

    collisions: List[Dict[str, object]] = []
    resolver = policy.PolicyResolver(
        profile=ids, conflicts=[(r["a"], r["b"]) for r in records]
    )
    for rec in sorted(records, key=lambda r: (r["layer"], r["a"], r["b"])):
        if rec["a"] in idset and rec["b"] in idset:
            # independent confirmation by the live engine (#202 discipline):
            # under profile=stack, activating either endpoint must DENY.
            decision = resolver.check(rec["a"])
            confirmed = (not decision.allow) and rec["b"] in (
                decision.conflicting_with or []
            )
            collisions.append(
                {
                    "a": rec["a"],
                    "b": rec["b"],
                    "layer": rec["layer"],
                    "reason": rec["reason"],
                    "engine_confirmed": confirmed,
                }
            )

    known = {r["a"] for r in records} | {r["b"] for r in records}
    return {
        "schema": SCHEMA,
        "conflicts_file": str(conflicts_path),
        "edges_loaded": len(records),
        "stack": ids,
        "collisions": collisions,
        "unknown_ids": sorted(idset - known),
        "verdict": "conflicted" if collisions else "clean",
    }


def render_human(report: Dict[str, object]) -> str:
    stack: List[str] = list(report["stack"])  # type: ignore[arg-type]
    collisions: List[Dict[str, object]] = list(report["collisions"])  # type: ignore[arg-type]
    unknown: List[str] = list(report["unknown_ids"])  # type: ignore[arg-type]
    lines: List[str] = []
    lines.append(
        f"MAOS Agora — conflict-checker · {report['edges_loaded']} curated "
        f"edges ({Path(str(report['conflicts_file'])).name})"
    )
    lines.append(f"Stack ({len(stack)}): " + (" · ".join(stack) or "(empty)"))
    lines.append("")
    if collisions:
        lines.append(f"COLLISIONS ({len(collisions)}):")
        for c in collisions:
            layer = f"[{c['layer']}] " if c["layer"] else ""
            mark = "✖" if c["engine_confirmed"] else "✖(unconfirmed)"
            lines.append(f"  {mark} {layer}{c['a']} × {c['b']}")
            if c["reason"]:
                lines.append(f"      {c['reason']}")
        layers = sorted({str(c["layer"]) for c in collisions if c["layer"]})
        lines.append("")
        lines.append(
            f"Verdict: CONFLICTED — {len(collisions)} collision(s)"
            + (f" across layer(s) {', '.join(layers)}" if layers else "")
        )
        lines.append(
            "Hint: keep ONE tool per collided slot (single-conductor, "
            "ADR-006 §4) — route the choice via /agentic-tool-intake."
        )
    else:
        lines.append(
            f"Verdict: CLEAN — no curated incompatibility among the "
            f"{len(stack)} tool(s)."
        )
    if unknown:
        lines.append("")
        lines.append(
            "Note: not in any curated edge (unknown to conflicts.yaml, "
            "NOT proof of safety): " + " · ".join(unknown)
        )
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="conflict-checker",
        description="Cross a tool stack against the curated MAOS "
        "incompatibility edge-list (issue #182).",
    )
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--stack", help="comma/space-separated tool ids")
    src.add_argument("--stack-file", type=Path, help="one tool id per line")
    src.add_argument(
        "--rule011",
        help="RULE-011 JSON line file ('-' = stdin) from single-conductor-scan.sh",
    )
    ap.add_argument(
        "--conflicts",
        type=Path,
        default=_DEFAULT_CONFLICTS,
        help=f"edge-list YAML (default: {_DEFAULT_CONFLICTS})",
    )
    ap.add_argument("--json", action="store_true", help="emit logged-field JSON")
    args = ap.parse_args(argv)

    if args.stack is not None:
        stack = _parse_stack_arg(args.stack)
    elif args.stack_file is not None:
        stack = _parse_stack_file(args.stack_file)
    else:
        stack = _parse_rule011(args.rule011)

    if not args.conflicts.is_file():
        raise SystemExit(
            f"conflict-checker: conflicts file not found: {args.conflicts}"
        )

    report = analyze(stack, args.conflicts)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    else:
        print(render_human(report))
    return 2 if report["verdict"] == "conflicted" else 0


if __name__ == "__main__":
    sys.exit(main())
