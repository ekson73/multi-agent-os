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
  R2 guard          technical item naming production/spend/send or an explicit
                    account/security/real-personal-data act -> HITL. This lexical
                    guard is advisory, not a general authorization check.
  R3 technical      tipo in the technical aliases -> DIY (the agent decides and
                    records; technical decisions are not HITL).
  R4 unknown        anything else (missing/unrecognised tipo) -> COMPUTE: the agent
                    must classify and compute the decision itself, then re-route.
"""
from __future__ import annotations

import argparse
import datetime as dt
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

# Only words that say the secret is ALREADY exposed. Rotation words are not
# evidence of a leak: a planned rotation is a normal credencial gate (R1).
_LEAK_RE = re.compile(
    r"\b(vazad[oa]s?|vazamento|expost[oa]s?|exposi[cç][aã]o|leak(ed|s)?|exposed|"
    r"compromised|comprometid[oa]s?)\b", re.IGNORECASE)
_GUARD_RE = re.compile(
    r"\b(produ[cç][aã]o|production|prod|irrevers[ií]vel|irreversible|apagar|delete|"
    r"drop|force[- ]push|pagar|pagamento|contratar|assinar|payment|spend|"
    r"comprar|compra|gasto|gastar|despesa|fatura|billing|purchase|buy|"
    r"compartilhar|share|divulgar|encaminhar|forward|"
    # External send: any send/publish verb or messaging channel. A false positive
    # only escalates (safe); a false negative would let a send run unasked.
    r"enviar|envio|mandar|send|publicar|postar|post|e-?mail|whatsapp|telegram|"
    r"slack|discord|sms)\b", re.IGNORECASE)

# Action + sensitive object, not words such as "conta" or "dados" alone.
# Fold accents at the call site; local implementation and synthetic parsing
# remain technical unless the text actually requests one of these acts.
_HUMAN_ACT_RE = re.compile(
    r"\b(?:(?:alter(?:ar|ando)|mud(?:ar|ando)|modific(?:ar|ando)|conced(?:er|endo)|"
    r"revog(?:ar|ando)|chang(?:e|ing)|modify(?:ing)?|grant(?:ing)?|revok(?:e|ing))\s+"
    r"(?:(?:a|as|o|os|the)\s+)?(?:(?:permiss(?:ao|oes)|privilegios?|acesso|configurac(?:ao|oes)|"
    r"permissions?|privileges?|access|settings?)(?:\s+(?:real|reais))?\s+"
    r"(?:d[ao]s?|de|n[ao]s?|em|aos?|as?|para|pra|of|on|to|for)\s+"
    r"(?:(?:a|as|o|os|um|uma|uns|umas|the|an)\s+)?"
    r"(?:contas?|accounts?|usuarios?|users?)|(?:(?:real|live)\s+)?(?:provider\s+)?"
    r"account\s+(?:permissions?|settings?))|"
    r"(?:ativ(?:ar|ando)|desativ(?:ar|ando)|habilit(?:ar|ando)|desabilit(?:ar|ando)|"
    r"redefin(?:ir|indo)|enabl(?:e|ing)|disabl(?:e|ing)|reset(?:ting)?)\s+"
    r"(?:(?:a|o|the)\s+)?(?:mfa|2fa|autenticacao\s+(?:multifator|de dois fatores)|"
    r"multi[- ]factor authentication|two[- ]factor authentication)|"
    r"(?:aceit(?:ar|ando)|aprov(?:ar|ando)|confirm(?:ar|ando)|autoriz(?:ar|ando)|"
    r"accept(?:ing)?|approv(?:e|ing)|confirm(?:ing)?|authoriz(?:e|ing))\s+"
    r"(?:(?:a|o|the)\s+)?(?:(?:verificacao|checagem) de seguranca d[oa] "
    r"(?:provedor|plataforma)|provider[- ](?:safety|security) (?:check|verification))|"
    r"(?:us(?:ar|ando)|utiliz(?:ar|ando)|process(?:ar|ando)|colet(?:ar|ando)|"
    r"analis(?:ar|ando)|us(?:e|ing)|process(?:ing)?|collect(?:ing)?|analyz(?:e|ing))\s+"
    r"(?:(?:os|the)\s+)?(?:dados pessoais reais|dados reais d[oa]s? clientes?|pii real|"
    r"real (?:pii|personal data|customer data)))\b")

# Only a directly attributed local implementation, not a stray "mock" label.
# An unknown target or another request after the feature description stays HITL.
_LOCAL_IMPL_PREFIX_RE = re.compile(
    r"^(?:implementar|criar|escrever|implement|create|write)\s+"
    r"(?:(?:um|uma|a|an|the)\s+)?"
    r"(?:(?:testes?|mocks?|fixtures?)\s+(?:local|locais|sintetic[oa]s?)|"
    r"(?:local|synthetic)\s+(?:tests?|mocks?|fixtures?))\s+(?:para|to)\s+$")
_SYNTHETIC_TARGET_RE = re.compile(
    r"\s*(?:(?:em|in|on)\s+(?:(?:uma?|a|an|the)\s+)?"
    r"(?:contas?\s+sintetic[oa]s?|synthetic\s+accounts?|"
    r"fixtures?\s+(?:sintetic[oa]s?|local|locais)|"
    r"(?:synthetic|local)\s+fixtures?))?\s*[.!]?\s*")
_REAL_OBJECT_RE = re.compile(r"\b(?:real|reais|live)\b")
# Explicit real/unknown target metadata also constrains a local action field.
_TARGET_CONTEXT_RE = re.compile(
    r"\b(?:(?:em|na|no|in|on|for)\s+(?:(?:uma?|a|an|the)\s+)?"
    r"(?:contas?|accounts?)(?!\s+sintetic[oa]s?\b)|"
    r"contas?\s+(?:alvo|d[aoe]\s+(?:cliente|provedor))|"
    r"(?:target|customer|provider)\s+accounts?)\b")

_NEG_RE = re.compile(r"\b(n[aã]o|nunca|sem|not|never|no|without)\s+(\w+\s+)?$", re.IGNORECASE)
# The new human-act guard only accepts a negator adjacent to the action.
# Legacy exposure negation above keeps its existing policy semantics.
_ACT_NEG_RE = re.compile(r"\b(?:nao|nunca|sem|not|never|no|without)\s*$")
# A structured rhetorical proposal is not an operational prohibition.
_PROPOSAL_RE = re.compile(r"\b(?:why\s+not|por\s+que\s+nao)\s*$")


def reports_leak(text: str) -> bool:
    """True when the text states an exposure; a negated one ('não exposto') is not."""
    for m in _LEAK_RE.finditer(text or ""):
        if not _NEG_RE.search(text[:m.start()]):
            return True
    return False


_MONEY_RE = re.compile(r"(R\$|US\$|USD|EUR|€)\s*\d", re.IGNORECASE)

_FUSE_PATH = (pathlib.Path(__file__).resolve().parents[2]
              / "synopsis-panel" / "bin" / "synopsis-fuse.py")


def _fold(text: str) -> str:
    """Lower-case and strip accents, so 'irreversível' == 'irreversivel'."""
    norm = unicodedata.normalize("NFKD", text or "")
    return "".join(c for c in norm if not unicodedata.combining(c)).strip().lower()


def _human_authority_act(text: str, context: str = "") -> bool:
    folded = _fold(text)
    global_text = _fold(context) if context else folded
    for m in _HUMAN_ACT_RE.finditer(folded):
        prefix = folded[:m.start()]
        if _ACT_NEG_RE.search(prefix) and not _PROPOSAL_RE.search(prefix):
            continue
        if (_LOCAL_IMPL_PREFIX_RE.fullmatch(prefix)
                and _SYNTHETIC_TARGET_RE.fullmatch(folded[m.end():])
                and not _REAL_OBJECT_RE.search(global_text)
                and not _TARGET_CONTEXT_RE.search(global_text)):
            continue
        return True
    return False


def _load_card_options(fuse_path: pathlib.Path = _FUSE_PATH):
    """Reuse the synopsis-panel option builder; fall back to a minimal one.

    The fallback is explicit: its verdicts carry
    options_source='fallback:synopsis-panel-absent' (not installed) or
    'fallback:synopsis-panel-error' (installed but failed to load)."""
    reason = "fallback:synopsis-panel-absent"
    if fuse_path.is_file():
        try:
            spec = importlib.util.spec_from_file_location("synopsis_fuse", fuse_path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)  # module body only; main() is __main__-guarded
            return mod._card_options
        except Exception:  # noqa: BLE001 — never let the sibling break the verdict
            # Installed but broken is not the same as absent: say which.
            reason = "fallback:synopsis-panel-error"

    def _fallback(h: dict, raw: dict):
        return ([{"label": "Aprovar", "description": "Segue com o que o item descreve."},
                 {"label": "Recusar", "description": "Não segue; fecha como recusado."},
                 {"label": "Manter pendente", "description": "Nada muda agora."}],
                False, reason)
    return _fallback


_CARD_OPTIONS = _load_card_options()


def _is_item(obj) -> bool:
    # `tipo` may be missing: such an item must still reach R4 (COMPUTE).
    return (isinstance(obj, dict) and isinstance(obj.get("id"), str)
            and obj["id"].startswith("H-") and ("tipo" in obj or "decidir" in obj))


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


# ── item evidence: what the ledger row itself says, never invented ────────────────
# Each matcher reads the item's own `decidir` text. The first kind that matches, in
# this order, sets the recommendation. No match = the verdict says "sem evidência".
_DATE_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
_ADIADO_RE = re.compile(r"\badiad[oa]s?\b", re.IGNORECASE)
_REVISAR_RE = re.compile(r"\b(?:revisar|rever|retomar|revisit)\s+(?:em|on|at[eé])\s+"
                         r"(\d{4}-\d{2}-\d{2})", re.IGNORECASE)
# Open preconditions, most specific first: what unblocks it, then what must come
# before the gate, then the bare blocking cause.
_PRECOND_RES = tuple(re.compile(p + r"(.+?)(?:\.\s|$)", re.IGNORECASE) for p in (
    r"\bdesbloqueio[^:]{0,30}:\s*",
    r"\bantes\s+do\s+gate\s*[,:]?\s*",
    r"\bbloquead[oa]\b[^:]{0,80}:\s*"))
_UNDETERMINED_RE = re.compile(
    r"n[aã]o\s+determin[aá]vel.*?(?:fechar|para\s+fechar)\s+exige\s+(.+?)(?:\.\s|$)",
    re.IGNORECASE | re.DOTALL)
_COMMAND_RE = re.compile(r"\bcomando\s*:\s*(`[^`]+`)", re.IGNORECASE)
_UNDO_RE = re.compile(r"\bundo\s*:\s*(.+?)(?:\s+\||\.\s|;\s|$)", re.IGNORECASE)
# "Recomendação: x" or the short "Rec. A: x" (option letter optional). Ends at the
# first ". " or "; " so a trailing "alt. B: ..." is not read as part of it.
_TEXT_REC_RE = re.compile(r"\b(?:recomenda[cç][aã]o|rec\.)(?:\s+[A-Z])?\s*:\s*(.+?)(?:;\s|\.\s|$)",
                          re.IGNORECASE)
_PLAN_RE = re.compile(r"\bplano\s+pronto\b", re.IGNORECASE)
_TREND_RE = re.compile(r"\b(destrava|trava|bloqueia|blocks|unblocks|crash|quebra)\w*",
                       re.IGNORECASE)
SNIPPET_MAX = 160


def _affirmed(rx: re.Pattern, text: str):
    """First match of rx not directly negated ('não adiado', 'sem plano pronto')."""
    for m in rx.finditer(text or ""):
        if not _NEG_RE.search(text[:m.start()]):
            return m
    return None


def _snip(text: str, n: int = SNIPPET_MAX) -> str:
    text = " ".join((text or "").split()).strip(" .;,")
    return text if len(text) <= n else text[: n - 1].rsplit(" ", 1)[0] + "…"


def _as_date(text: str):
    m = _DATE_RE.search(text or "")
    if not m:
        return None
    try:
        return dt.date.fromisoformat(m.group(1))
    except ValueError:
        return None


def _deferred_until(item: dict, today: dt.date):
    """The future date the item is deferred to, or None. Needs the word 'adiado'."""
    text = str(item.get("decidir", ""))
    if not _affirmed(_ADIADO_RE, text):
        return None
    m = _REVISAR_RE.search(text)
    when = _as_date(m.group(1)) if m else _as_date(str(item.get("prazo", "")))
    return when if when and when > today else None


def item_evidence(item: dict, today: dt.date) -> list[dict]:
    """Every evidence kind the row carries, in precedence order."""
    text = str(item.get("decidir", ""))
    found: list[dict] = []
    until = _deferred_until(item, today)
    if until:
        found.append({"kind": "adiado", "text": until.isoformat()})
    for rx in _PRECOND_RES:
        m = _affirmed(rx, text)
        if m:
            found.append({"kind": "pre-condicao", "text": _snip(m.group(1))})
            break
    m = _UNDETERMINED_RE.search(text)
    if m:
        found.append({"kind": "nao-determinavel", "text": _snip(m.group(1))})
    cmd, undo = _affirmed(_COMMAND_RE, text), _affirmed(_UNDO_RE, text)
    if cmd and undo:
        found.append({"kind": "comando+undo", "text": _snip(undo.group(1), 80)})
    m = _TEXT_REC_RE.search(text)
    if m:
        found.append({"kind": "recomendacao-registrada", "text": _snip(m.group(1))})
    if _affirmed(_PLAN_RE, text):
        found.append({"kind": "plano", "text": "plano pronto registrado"})
    return found


def _evidence_recommendation(ev: dict, yes: str, no: str) -> tuple[str, list[str], str]:
    """(recommendation, alternatives, confidence) for the top evidence kind."""
    keep = "Manter pendente"
    kind, text = ev["kind"], ev["text"]
    if kind == "adiado":
        return f"Manter adiado até {text}", [yes, no], "alta"
    if kind == "pre-condicao":
        return f"Manter pendente: antes, {text}", [yes, no], "alta"
    if kind == "nao-determinavel":
        return f"Manter pendente: fechar exige {text}", [yes, no], "media"
    if kind == "comando+undo":
        return f"{yes} com o comando registrado (undo: {text})", [no, keep], "media"
    if kind == "recomendacao-registrada":
        return text, [yes, no, keep], "media"
    return f"{yes} seguindo o plano registrado", [no, keep], "baixa"


def priority(item: dict, today: dt.date) -> dict:
    """GUT (Gravidade x Urgência x Tendência, 1-5 each, score = product).

    G from the row's risk letter (R3/R2/R1), else its severity. U from the deadline
    (past or 'expirado' = 5) or a deferral (1). T is 4 when the row says it blocks
    something, 1 when deferred, else 3. Every input is a ledger field."""
    risk = str(item.get("risk", "")).strip().upper()
    sev = str(item.get("sev", "")).strip().upper()
    g = {"R3": 5, "R2": 4, "R1": 3}.get(risk) or \
        {"URGENTE": 5, "ALTA": 4, "NORMAL": 3}.get(sev, 3)
    deferred = _deferred_until(item, today)
    due = _as_date(str(item.get("prazo", "")))
    if deferred:
        u = 1
    elif "expirado" in _fold(str(item.get("status", ""))):
        u = 5
    elif due:
        days = (due - today).days
        u = 5 if days < 0 else 4 if days <= 3 else 3 if days <= 14 else 2
    else:
        u = 2
    t = 1 if deferred else 4 if _affirmed(_TREND_RE, str(item.get("decidir", ""))) else 3
    return {"g": g, "u": u, "t": t, "score": g * u * t, "method": "GUT"}


def _hitl_verdict(item: dict, rule: str, reason: str, today: dt.date | None = None) -> dict:
    today = today or dt.date.today()
    # The option builder keys on the unaccented SSOT spelling ('irreversivel').
    folded = dict(item, tipo=_fold(str(item.get("tipo", ""))))
    opts, has_rec, source = _CARD_OPTIONS(folded, folded)
    labels = [o["label"] for o in opts]
    evidence = item_evidence(item, today)
    if has_rec:
        rec, basis, alts, conf = labels[0], "evidence", labels[1:], "media"
    elif evidence:
        # The row's own facts pick the answer; the type's dispositions stay as
        # alternatives so the human can still say yes/no to the act itself.
        yes = labels[0]
        no = labels[1] if len(labels) > 1 else "Recusar"
        rec, alts, conf = _evidence_recommendation(evidence[0], yes, no)
        basis = f"evidence:{evidence[0]['kind']}"
        alts = [a for a in alts if a != rec]
    else:
        # No evidenced option: recommend the type's first disposition, flagged as a
        # type default so nobody reads it as an evidence-backed recommendation.
        rec, basis, alts, conf = labels[0], f"type-default:{source}", labels[1:], "nenhuma"
    out = {"route": "HITL", "rule": rule, "reason": reason,
           "recommendation": rec, "recommendation_basis": basis,
           "alternatives": alts, "denied": False, "options_source": source,
           "confidence": conf, "evidence": evidence}
    if conf == "nenhuma":
        out["evidence_note"] = "sem evidência no item: recomendação é só o padrão do tipo"
    return out


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


def decide(item: dict, policy: dict | None = None, today: dt.date | None = None) -> dict:
    out = _route(item, policy, today or dt.date.today())
    out["priority"] = priority(item, today or dt.date.today())
    return out


def _route(item: dict, policy: dict | None, today: dt.date) -> dict:
    pol = validate_policy(policy)
    tipo = _fold(str(item.get("tipo", "")))
    text = " ".join(str(item.get(k, "")) for k in ("decidir", "titulo", "title"))
    out = {"id": item.get("id"), "tipo": item.get("tipo", "")}

    if tipo == "credencial" and pol.get("leaked_secret") == "deny-rotation" \
            and reports_leak(text):
        out.update(route="DIY", rule="R0-leaked-secret", denied=True,
                   reason="segredo/PII já vazado: política do operador é ignorar, sem rotação",
                   recommendation="Negado: não rotacionar; não reabrir no digest",
                   recommendation_basis="policy:leaked_secret=deny-rotation",
                   alternatives=[])
        return out
    if tipo in HUMAN_TYPES:
        out.update(_hitl_verdict(item, "R1-human-type",
                                 f"tipo '{tipo}' é um dos 5 tipos HITL do SSOT", today))
        return out
    if tipo in TECH_TYPES and (_GUARD_RE.search(text) or _MONEY_RE.search(text)
                               or any(_human_authority_act(str(item.get(k, "")), text)
                                      for k in ("decidir", "titulo", "title"))):
        out.update(_hitl_verdict(item, "R2-guard",
                                 "item técnico cita ato irreversível/produção, gasto, envio "
                                 "ou ato de conta/segurança/dados pessoais reais", today))
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


SCOPE_KEYS = ("hitl_scope", "hitl_scope_reason", "hitl_scope_unresolved",
              "hitl_session_resolved", "hitl_ledger_total", "hitl_source", "hitl_warning")


def scope_info(doc) -> dict:
    """Carry the digest's scope metadata through, so an unresolved scope is never
    read as an empty queue."""
    meta = doc.get("meta") if isinstance(doc, dict) else None
    if not isinstance(meta, dict):
        return {}
    return {k: meta[k] for k in SCOPE_KEYS if k in meta}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("input", nargs="?", default="-",
                    help="JSON file (synopsis-fuse envelope, item list, or one item); '-' = stdin")
    ap.add_argument("--policy", help="JSON file overriding the default policy")
    ap.add_argument("--format", choices=("json", "tree"), default="json")
    ap.add_argument("--sort", choices=("input", "gut"), default="input",
                    help="verdict order: input (document order, default) or gut (GUT score, highest first)")
    ap.add_argument("--today", help="reference date YYYY-MM-DD for deadlines/deferrals (default: today)")
    args = ap.parse_args(argv)

    try:
        raw = sys.stdin.read() if args.input == "-" else pathlib.Path(args.input).read_text("utf-8")
        doc = json.loads(raw)
        policy = json.loads(pathlib.Path(args.policy).read_text("utf-8")) if args.policy else None
        validate_policy(policy)
        today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"decision-engine: invalid input: {exc}", file=sys.stderr)
        return 2

    verdicts = [decide(i, policy, today) for i in collect_items(doc)]
    if args.sort == "gut":
        verdicts.sort(key=lambda v: -v["priority"]["score"])  # stable on ties
    source = scope_info(doc)
    if args.format == "tree":
        if source.get("hitl_scope_unresolved"):
            print(f"decision-engine: escopo não resolvido no digest: {source['hitl_scope_unresolved']}"
                  " (isto NÃO é fila vazia)")
        elif not verdicts:
            total = source.get("hitl_ledger_total")
            extra = f" (ledger tem {total}; escopo {source.get('hitl_scope')})" if total else ""
            print(f"decision-engine: 0 itens HITL na entrada{extra}")
        for v in verdicts:
            p = v["priority"]
            conf = f"; confiança: {v['confidence']}" if "confidence" in v else ""
            print(f"{v['id']} [{v['tipo']}] -> {v['route']} ({v['rule']}): {v['recommendation']}"
                  f" [base: {v['recommendation_basis']}{conf}]"
                  f" [GUT {p['g']}x{p['u']}x{p['t']}={p['score']}]")
            for ev in v.get("evidence", []):
                print(f"    evidência: {ev['kind']}: {ev['text']}")
            if v.get("evidence_note"):
                print(f"    {v['evidence_note']}")
            for alt in v["alternatives"]:
                print(f"    alt: {alt}")
        return 0
    counts = {r: sum(v["route"] == r for v in verdicts) for r in ("DIY", "COMPUTE", "HITL")}
    print(json.dumps({"schema": SCHEMA, "counts": counts, "source": source,
                      "verdicts": verdicts},
                     ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
