#!/usr/bin/env python3
"""decision-engine — route each HITL item to DIY, COMPUTE or HITL by fixed rules.

Input: the JSON envelope of `synopsis-fuse.py --hitl-only --format json`, a list of
HITL items, or a single HITL item (one dict with `id` + `tipo`).
Output: one verdict per item:

    {"id", "route": "DIY"|"COMPUTE"|"HITL", "rule", "reason",
     "recommendation", "recommendation_basis", "alternatives": [...], "denied"}

Deterministic, read-only, stdlib-only. It never mutates the ledger and never
authorizes anything: a HITL verdict still goes to the human, with a recommendation
and alternatives attached. The option texts come from the synopsis-panel engine
(`_card_options`, loaded from the sibling skill), so the dispositions per type
live in ONE place.

Rules, evaluated in this order (first match wins):

  R0 leaked-secret  `credencial` item about an already leaked/exposed secret or PII
                    -> DIY, denied=True: the operator's policy is "ignore existing
                    leaks, no rotation". Overridable with --policy.
  R1 human-type     tipo in {credencial, gasto, irreversivel, envio, negocio}
                    -> HITL with recommendation + alternatives.
  R2 guard          technical item whose text names an irreversible-in-production,
                    spend or external-send act -> HITL (a mislabelled type never
                    downgrades a human gate).
  R3 technical      tipo in the technical aliases -> DIY (the agent decides and
                    records; technical decisions are not HITL).
  R4 unknown        anything else (missing/unrecognised tipo) -> COMPUTE: the agent
                    must classify and compute the decision itself, then re-route.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import re
import sys
import unicodedata

SCHEMA = "decision-engine/verdict/v1"
HUMAN_TYPES = ("credencial", "gasto", "irreversivel", "envio", "negocio")
TECH_TYPES = ("tecnico", "technical", "tatico", "tactical", "operacional", "operational")

DEFAULT_POLICY = {
    # "deny-rotation": an already-leaked secret/PII is ignored, never rotated.
    # "escalate": treat it like any other credencial item (R1).
    "leaked_secret": "deny-rotation",
}

_LEAK_RE = re.compile(
    r"\b(vazad[oa]s?|vazamento|expost[oa]s?|exposi[cç][aã]o|leak(ed|s)?|exposed|"
    r"rota[cç][aã]o|rotacionar|rotate|rotation)\b", re.IGNORECASE)
_GUARD_RE = re.compile(
    r"\b(produ[cç][aã]o|production|prod|irrevers[ií]vel|irreversible|apagar|delete|"
    r"drop|force[- ]push|pagar|pagamento|contratar|assinar|payment|spend|"
    r"enviar e-?mail|send email|publicar externamente)\b", re.IGNORECASE)

_FUSE_PATH = (pathlib.Path(__file__).resolve().parents[2]
              / "synopsis-panel" / "bin" / "synopsis-fuse.py")


def _fold(text: str) -> str:
    """Lower-case and strip accents, so 'irreversível' == 'irreversivel'."""
    norm = unicodedata.normalize("NFKD", text or "")
    return "".join(c for c in norm if not unicodedata.combining(c)).strip().lower()


def _load_card_options(fuse_path: pathlib.Path = _FUSE_PATH):
    """Reuse the synopsis-panel option builder; fall back to a minimal one.

    The fallback is explicit: its verdicts carry
    options_source='fallback:synopsis-panel-absent', never a silent substitute."""
    if fuse_path.is_file():
        try:
            spec = importlib.util.spec_from_file_location("synopsis_fuse", fuse_path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)  # module body only; main() is __main__-guarded
            return mod._card_options
        except Exception:  # noqa: BLE001 — never let the sibling break the verdict
            pass

    def _fallback(h: dict, raw: dict):
        return ([{"label": "Aprovar", "description": "Segue com o que o item descreve."},
                 {"label": "Recusar", "description": "Não segue; fecha como recusado."},
                 {"label": "Manter pendente", "description": "Nada muda agora."}],
                False, "fallback:synopsis-panel-absent")
    return _fallback


_CARD_OPTIONS = _load_card_options()


def _is_item(obj) -> bool:
    return (isinstance(obj, dict) and isinstance(obj.get("id"), str)
            and obj["id"].startswith("H-") and "tipo" in obj)


def collect_items(doc) -> list[dict]:
    """Every HITL item in an envelope / list / single item, in document order."""
    if _is_item(doc):
        return [doc]
    found: list[dict] = []
    seen: set[str] = set()

    def walk(node):
        if _is_item(node):
            if node["id"] not in seen:
                seen.add(node["id"])
                found.append(node)
            return
        if isinstance(node, dict):
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
    walk(doc)
    return found


def _hitl_verdict(item: dict, rule: str, reason: str) -> dict:
    opts, has_rec, source = _CARD_OPTIONS(item, item)
    labels = [o["label"] for o in opts]
    if has_rec:
        rec, basis = labels[0], "evidence"
    else:
        # No evidenced option: recommend the type's first disposition, flagged as a
        # type default so nobody reads it as an evidence-backed recommendation.
        rec, basis = labels[0], f"type-default:{source}"
    return {"route": "HITL", "rule": rule, "reason": reason,
            "recommendation": rec, "recommendation_basis": basis,
            "alternatives": labels[1:], "denied": False, "options_source": source}


POLICY_VALUES = {"leaked_secret": ("deny-rotation", "escalate")}


def validate_policy(policy) -> dict:
    """Reject an invalid policy instead of guessing: unknown keys or values fail."""
    if policy is None:
        return dict(DEFAULT_POLICY)
    if not isinstance(policy, dict):
        raise ValueError("policy must be a JSON object")
    for k, v in policy.items():
        if k not in POLICY_VALUES:
            raise ValueError(f"unknown policy key: {k}")
        if v not in POLICY_VALUES[k]:
            raise ValueError(f"invalid value for {k}: {v!r} (allowed: {POLICY_VALUES[k]})")
    return dict(DEFAULT_POLICY, **policy)


def decide(item: dict, policy: dict | None = None) -> dict:
    pol = validate_policy(policy)
    tipo = _fold(str(item.get("tipo", "")))
    text = " ".join(str(item.get(k, "")) for k in ("decidir", "titulo", "title"))
    out = {"id": item.get("id"), "tipo": item.get("tipo", "")}

    if tipo == "credencial" and pol.get("leaked_secret") == "deny-rotation" \
            and _LEAK_RE.search(text):
        out.update(route="DIY", rule="R0-leaked-secret", denied=True,
                   reason="segredo/PII já vazado: política do operador é ignorar, sem rotação",
                   recommendation="Negado: não rotacionar; não reabrir no digest",
                   recommendation_basis="policy:leaked_secret=deny-rotation",
                   alternatives=[])
        return out
    if tipo in HUMAN_TYPES:
        out.update(_hitl_verdict(item, "R1-human-type",
                                 f"tipo '{tipo}' é um dos 5 tipos HITL do SSOT"))
        return out
    if tipo in TECH_TYPES and _GUARD_RE.search(text):
        out.update(_hitl_verdict(item, "R2-guard",
                                 "item técnico cita ato irreversível/produção, gasto ou envio"))
        return out
    if tipo in TECH_TYPES:
        out.update(route="DIY", rule="R3-technical", denied=False,
                   reason="decisão técnica: o agente decide e registra, não é HITL",
                   recommendation="Decidir e registrar (decision-capture)",
                   recommendation_basis="rule", alternatives=[])
        return out
    out.update(route="COMPUTE", rule="R4-unknown", denied=False,
               reason=f"tipo '{item.get('tipo', '')}' não reconhecido: classificar e calcular antes de rotear",
               recommendation="Classificar o tipo e recalcular a rota",
               recommendation_basis="rule", alternatives=[])
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("input", nargs="?", default="-",
                    help="JSON file (synopsis-fuse envelope, item list, or one item); '-' = stdin")
    ap.add_argument("--policy", help="JSON file overriding the default policy")
    ap.add_argument("--format", choices=("json", "tree"), default="json")
    args = ap.parse_args(argv)

    try:
        raw = sys.stdin.read() if args.input == "-" else pathlib.Path(args.input).read_text("utf-8")
        doc = json.loads(raw)
        policy = json.loads(pathlib.Path(args.policy).read_text("utf-8")) if args.policy else None
        validate_policy(policy)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"decision-engine: invalid input: {exc}", file=sys.stderr)
        return 2

    verdicts = [decide(i, policy) for i in collect_items(doc)]
    if args.format == "tree":
        if not verdicts:
            print("decision-engine: 0 itens HITL na entrada")
        for v in verdicts:
            print(f"{v['id']} [{v['tipo']}] -> {v['route']} ({v['rule']}): {v['recommendation']}")
            for alt in v["alternatives"]:
                print(f"    alt: {alt}")
        return 0
    counts = {r: sum(v["route"] == r for v in verdicts) for r in ("DIY", "COMPUTE", "HITL")}
    print(json.dumps({"schema": SCHEMA, "counts": counts, "verdicts": verdicts},
                     ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
