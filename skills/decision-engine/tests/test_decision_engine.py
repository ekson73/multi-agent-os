"""decision-engine contract: every rule, through the real CLI (no mocks)."""
from __future__ import annotations

import importlib.util
import json
import pathlib
import subprocess
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "decision_engine.py"
FUSE = ROOT.parent / "synopsis-panel" / "bin" / "synopsis-fuse.py"


def _load():
    spec = importlib.util.spec_from_file_location("decision_engine", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


de = _load()


def _item(hid, tipo, decidir="Decidir algo", **kw):
    return {"id": hid, "tipo": tipo, "sev": "ALTA", "decidir": decidir,
            "link": "-", "status": "pendente", **kw}


def _cli(payload, *extra):
    proc = subprocess.run([sys.executable, str(SCRIPT), "-", *extra],
                          input=json.dumps(payload), capture_output=True,
                          text=True, timeout=60)
    assert proc.returncode == 0, proc.stderr
    return proc.stdout


@pytest.mark.parametrize("tipo", ["credencial", "gasto", "irreversivel", "envio", "negocio"])
def test_the_five_human_types_go_to_hitl_with_a_recommendation(tipo):
    v = de.decide(_item("H-0001", tipo))
    assert v["route"] == "HITL" and v["rule"] == "R1-human-type"
    assert v["recommendation"], "a HITL verdict always carries a recommendation"
    assert v["alternatives"], "and at least one alternative"
    assert v["recommendation"] not in v["alternatives"]


def test_accented_type_is_the_same_type():
    assert de.decide(_item("H-0002", "irreversível"))["route"] == "HITL"


def test_technical_goes_to_diy():
    v = de.decide(_item("H-0003", "tecnico", "Escolher a lib de parsing"))
    assert v["route"] == "DIY" and v["rule"] == "R3-technical"


def test_technical_naming_a_production_act_is_guarded_to_hitl():
    v = de.decide(_item("H-0004", "tecnico", "Apagar a tabela em produção"))
    assert v["route"] == "HITL" and v["rule"] == "R2-guard"


def test_unknown_type_goes_to_compute_never_silently_diy():
    for tipo in ("", "outro"):
        v = de.decide(_item("H-0005", tipo))
        assert v["route"] == "COMPUTE" and v["rule"] == "R4-unknown"


def test_leaked_secret_is_denied_without_rotation():
    v = de.decide(_item("H-0006", "credencial", "Token exposto em transcript: rotação pendente"))
    assert v["route"] == "DIY" and v["denied"] is True
    assert v["rule"] == "R0-leaked-secret" and v["alternatives"] == []


def test_leaked_secret_policy_can_be_switched_back_to_escalate():
    v = de.decide(_item("H-0007", "credencial", "Token vazado"), {"leaked_secret": "escalate"})
    assert v["route"] == "HITL"


def test_a_credential_request_that_is_not_a_leak_still_escalates():
    v = de.decide(_item("H-0008", "credencial", "Fornecer a API key do provedor X"))
    assert v["route"] == "HITL" and v["denied"] is False


def test_evidenced_structured_option_is_the_recommendation():
    item = _item("H-0009", "gasto", options=[
        {"label": "Plano B", "description": "x"},
        {"label": "Plano A", "description": "y", "recommended": True,
         "evidence": "pricing page 2026-10-30", "confidence": "0.9"}])
    v = de.decide(item)
    assert v["recommendation_basis"] == "evidence"
    assert v["recommendation"].startswith("Plano A")


def test_without_evidence_the_basis_says_type_default():
    v = de.decide(_item("H-0010", "envio"))
    assert v["recommendation_basis"].startswith("type-default")


def test_collects_items_from_a_synopsis_fuse_envelope():
    env = {"schema": "synopsis-panel/v1", "tree": {
        "domains": {"d": [{"hitl": [_item("H-0011", "gasto")]}]},
        "hitl_unattached": [_item("H-0012", "tecnico"), _item("H-0011", "gasto")]}}
    out = json.loads(_cli(env))
    assert out["schema"] == "decision-engine/verdict/v1"
    assert [v["id"] for v in out["verdicts"]] == ["H-0011", "H-0012"], "dedup by id, doc order"
    assert out["counts"] == {"DIY": 1, "COMPUTE": 0, "HITL": 1}


def test_deterministic_same_input_same_output():
    payload = [_item("H-0013", "negocio"), _item("H-0014", "tecnico")]
    assert _cli(payload) == _cli(payload)


def test_invalid_json_exits_2():
    proc = subprocess.run([sys.executable, str(SCRIPT), "-"], input="{nope",
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2


@pytest.mark.skipif(not FUSE.is_file(), reason="synopsis-panel not installed")
def test_end_to_end_with_the_real_synopsis_fuse(tmp_path):
    """Pipe the real engine's JSON into the decision-engine."""
    ledger = tmp_path / "punch-list.md"
    ledger.write_text(
        "---\nid: hitl-punch-list\nnext_id: 3\n---\n\n# HITL punch-list\n\n"
        "<!-- hitl:open:start -->\n"
        "| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link | Sessão |\n"
        "|----|-----|------|---|---------|-------|--------|-------|-------|--------|------|--------|\n"
        "| H-0001 | 🟠 ALTA | 💸 gasto | R2 | Assinar plano X | agente | 2026-10-20 | 1 d | - | pendente | (sem ticket) | - |\n"
        "| H-0002 | 🟡 NORMAL | 🔑 credencial | R1 | Token exposto: rotação | agente | 2026-10-20 | 1 d | - | pendente | (sem ticket) | - |\n"
        "<!-- hitl:open:end -->\n",
        encoding="utf-8")
    fuse = subprocess.run(
        [sys.executable, str(FUSE), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--scope", "all", "--format", "json"],
        input="{}", capture_output=True, text=True, timeout=120)
    assert fuse.returncode == 0, fuse.stderr
    out = json.loads(_cli(json.loads(fuse.stdout)))
    routes = {v["id"]: (v["route"], v["denied"]) for v in out["verdicts"]}
    assert routes == {"H-0001": ("HITL", False), "H-0002": ("DIY", True)}


def test_mutation_check_the_guard_is_load_bearing(monkeypatch):
    """Inject the defect (remove the human types) and prove a gate stops escalating;
    a test that passes with and without the defect would prove nothing."""
    monkeypatch.setattr(de, "HUMAN_TYPES", ())
    assert de.decide(_item("H-0015", "irreversivel"))["route"] != "HITL"
    monkeypatch.undo()
    assert de.decide(_item("H-0015", "irreversivel"))["route"] == "HITL"


def test_absent_backend_falls_back_explicitly(monkeypatch, tmp_path):
    """synopsis-panel missing: still a verdict, and it says it used the fallback."""
    monkeypatch.setattr(de, "_CARD_OPTIONS", de._load_card_options(tmp_path / "nope.py"))
    v = de.decide(_item("H-0016", "gasto"))
    assert v["route"] == "HITL"
    assert v["options_source"] == "fallback:synopsis-panel-absent"
    assert v["recommendation_basis"].startswith("type-default")


def test_present_backend_is_not_reported_as_fallback():
    assert not de.decide(_item("H-0017", "gasto"))["options_source"].startswith("fallback")


@pytest.mark.parametrize("policy", ['{"leaked_secret": "rotate-now"}',
                                    '{"autonomy": "max"}', '[1]', '{nope'])
def test_invalid_policy_is_refused_with_exit_2(tmp_path, policy):
    pf = tmp_path / "policy.json"
    pf.write_text(policy, encoding="utf-8")
    proc = subprocess.run([sys.executable, str(SCRIPT), "-", "--policy", str(pf)],
                          input=json.dumps([_item("H-0018", "gasto")]),
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2 and "invalid input" in proc.stderr


def test_a_hitl_verdict_never_grants_permission():
    """The engine recommends; it never marks a human gate as resolved."""
    for tipo in ("credencial", "gasto", "irreversivel", "envio", "negocio"):
        v = de.decide(_item("H-0019", tipo))
        assert v["route"] == "HITL" and "resolved" not in v and "approved" not in v


@pytest.mark.parametrize("text", ["Realizar rotação trimestral da chave",
                                  "Autorizar rotação preventiva da credencial",
                                  "Rotate the deploy key"])
def test_a_planned_rotation_is_not_a_leak_and_escalates(text):
    v = de.decide(_item("H-0020", "credencial", text))
    assert v["route"] == "HITL" and v["denied"] is False


def test_an_item_without_tipo_is_collected_and_goes_to_compute():
    out = json.loads(_cli({"id": "H-1001", "decidir": "Escolher parser"}))
    assert [(v["id"], v["route"]) for v in out["verdicts"]] == [("H-1001", "COMPUTE")]


def test_accented_type_gets_its_own_type_options():
    plain = de.decide(_item("H-0021", "irreversivel"))
    accented = de.decide(_item("H-0021", "irreversível"))
    assert accented["recommendation"] == plain["recommendation"]
    assert accented["alternatives"] == plain["alternatives"]


def test_unresolved_scope_is_carried_and_not_read_as_empty():
    env = {"meta": {"hitl_scope": "session", "hitl_ledger_total": 19,
                    "hitl_scope_unresolved": "no session identity"},
           "tree": {"domains": {}, "hitl_unattached": []}}
    out = json.loads(_cli(env))
    assert out["source"]["hitl_scope_unresolved"] == "no session identity"
    tree = _cli(env, "--format", "tree")
    assert "NÃO é fila vazia" in tree


@pytest.mark.parametrize("text", ["Enviar mensagem ao cliente pelo WhatsApp",
                                  "Postar o anúncio no Discord", "Send the release note"])
def test_a_technical_item_that_sends_externally_is_guarded(text):
    assert de.decide(_item("H-1000", "tecnico", text))["route"] == "HITL"


@pytest.mark.parametrize("text", ["Comprar licença anual por R$ 500",
                                  "Autorizar gasto de R$ 500",
                                  "Compartilhar dados do cliente com parceiro"])
def test_a_technical_item_that_spends_or_shares_is_guarded(text):
    assert de.decide(_item("H-2000", "tecnico", text))["route"] == "HITL"


@pytest.mark.parametrize("text", ["Token não exposto; rotação preventiva",
                                  "Key was not exposed, rotate on schedule"])
def test_a_negated_exposure_is_not_a_leak(text):
    v = de.decide(_item("H-2001", "credencial", text))
    assert v["route"] == "HITL" and v["denied"] is False


def test_a_broken_backend_is_not_reported_as_absent(tmp_path):
    broken = tmp_path / "synopsis-fuse.py"
    broken.write_text("raise RuntimeError('boom')\n", encoding="utf-8")
    opts = de._load_card_options(broken)
    assert opts({}, {})[2] == "fallback:synopsis-panel-error"


def test_tree_output_shows_the_recommendation_basis():
    assert "[base: type-default" in _cli([_item("H-2002", "gasto")], "--format", "tree")


# ── R9: recommendation from the item's own evidence + GUT priority ─────────────────
import datetime as _dt

TODAY = _dt.date(2026, 10, 30)


def test_deferred_item_recommends_keeping_it_deferred():
    v = de.decide(_item("H-0101", "irreversivel",
                        "Fechar o SG. ADIADO pelo operador; revisar em 2026-11-30. Plano pronto",
                        prazo="2026-11-30"), today=TODAY)
    assert v["rule"] == "R1-human-type" and v["route"] == "HITL"
    assert v["recommendation"] == "Manter adiado até 2026-11-30"
    assert v["recommendation_basis"] == "evidence:adiado" and v["confidence"] == "alta"
    assert v["alternatives"] and v["recommendation"] not in v["alternatives"]
    assert v["priority"]["u"] == 1 and v["priority"]["t"] == 1


def test_a_past_deferral_date_is_not_a_deferral():
    v = de.decide(_item("H-0102", "irreversivel", "ADIADO; revisar em 2026-10-01"), today=TODAY)
    assert v["recommendation_basis"].startswith("type-default")


def test_open_precondition_recommends_waiting_with_the_step():
    v = de.decide(_item("H-0103", "irreversivel",
                        "Remover hoje quebra os 30 worktrees: antes do gate, migrar ou podar esses worktrees"),
                  today=TODAY)
    assert v["recommendation"] == "Manter pendente: antes, migrar ou podar esses worktrees"
    assert v["recommendation_basis"] == "evidence:pre-condicao"


def test_unblock_step_wins_over_the_bare_blocking_cause():
    v = de.decide(_item("H-0104", "credencial",
                        "Criar o bot. BLOQUEADO (causa X): a extensão está no Dia. "
                        "Desbloqueio (qualquer um): (A) instalar no Chrome. Fim"), today=TODAY)
    assert v["evidence"][0] == {"kind": "pre-condicao", "text": "(A) instalar no Chrome"}


def test_command_and_undo_recommend_executing_with_the_undo_named():
    v = de.decide(_item("H-0105", "irreversivel",
                        "Criar o banco; destrava o dev. Comando: `CREATE DATABASE x` "
                        "Undo: `DROP DATABASE x` (vazio)"), today=TODAY)
    assert v["recommendation_basis"] == "evidence:comando+undo" and v["confidence"] == "media"
    assert v["recommendation"].startswith("Executar com o comando registrado")
    assert "DROP DATABASE x" in v["recommendation"]
    assert v["priority"]["t"] == 4, "a row that unblocks something trends up"


def test_a_command_without_undo_is_not_evidence_to_execute():
    v = de.decide(_item("H-0106", "irreversivel", "Comando: `rm -rf x`"), today=TODAY)
    assert v["recommendation_basis"].startswith("type-default")


def test_undetermined_item_recommends_what_closing_requires():
    v = de.decide(_item("H-0107", "envio",
                        "Conferir a mensagem · NÃO DETERMINÁVEL pelo arquivo local; "
                        "fechar exige backfill ou o operador olhar o celular"), today=TODAY)
    assert v["recommendation_basis"] == "evidence:nao-determinavel"
    assert "backfill" in v["recommendation"]


def test_a_recommendation_written_in_the_row_is_used():
    v = de.decide(_item("H-0108", "negocio", "Piloto no cliente? Recomendação: sim, sem isolamento. Fim"),
                  today=TODAY)
    assert v["recommendation"] == "sim, sem isolamento"
    assert v["recommendation_basis"] == "evidence:recomendacao-registrada"


def test_without_evidence_the_verdict_says_so_explicitly():
    v = de.decide(_item("H-0109", "negocio", "Nomes da família do operador"), today=TODAY)
    assert v["confidence"] == "nenhuma" and v["evidence"] == []
    assert "sem evidência" in v["evidence_note"]
    assert v["recommendation_basis"].startswith("type-default")


@pytest.mark.parametrize("risk,prazo,status,expected", [
    ("R3", "2026-10-29", "pendente", (5, 5)),
    ("R2", "2026-11-01", "pendente", (4, 4)),
    ("R1", "2026-11-10", "pendente", (3, 3)),
    ("R1", "2026-12-30", "pendente", (3, 2)),
    ("", "-", "expirado", (4, 5)),
])
def test_gut_reads_risk_and_deadline(risk, prazo, status, expected):
    p = de.decide(_item("H-0110", "negocio", risk=risk, prazo=prazo, status=status),
                  today=TODAY)["priority"]
    assert (p["g"], p["u"]) == expected and p["score"] == p["g"] * p["u"] * p["t"]


def test_sort_gut_orders_by_score_and_input_keeps_document_order():
    items = [_item("H-0201", "negocio", risk="R1"),
             _item("H-0202", "irreversivel", "trava o dev", risk="R3", prazo="2026-10-01")]
    by_input = json.loads(_cli(items, "--today", "2026-10-30"))["verdicts"]
    by_gut = json.loads(_cli(items, "--sort", "gut", "--today", "2026-10-30"))["verdicts"]
    assert [v["id"] for v in by_input] == ["H-0201", "H-0202"]
    assert [v["id"] for v in by_gut] == ["H-0202", "H-0201"]


def test_tree_shows_confidence_gut_and_evidence():
    out = _cli([_item("H-0203", "irreversivel", "ADIADO; revisar em 2099-01-01")],
               "--format", "tree", "--today", "2026-10-30")
    assert "confiança: alta" in out and "[GUT " in out and "evidência: adiado: 2099-01-01" in out


def test_invalid_today_exits_2():
    proc = subprocess.run([sys.executable, str(SCRIPT), "-", "--today", "30/10"],
                          input="[]", capture_output=True, text=True, timeout=60)
    assert proc.returncode == 2


def test_technical_and_leak_rules_are_unchanged_by_evidence():
    assert de.decide(_item("H-0204", "tecnico", "ADIADO; revisar em 2099-01-01"),
                     today=TODAY)["rule"] == "R3-technical"
    v = de.decide(_item("H-0205", "credencial", "token vazado; Comando: `x` Undo: y"), today=TODAY)
    assert v["rule"] == "R0-leaked-secret" and v["denied"] is True


@pytest.mark.parametrize("text", ["Não adiado; revisar em 2099-01-01",
                                  "Sem plano pronto ainda",
                                  "Comando: `x` mas sem undo: nada"])
def test_negated_evidence_is_not_evidence(text):
    v = de.decide(_item("H-0206", "irreversivel", text), today=TODAY)
    assert v["recommendation_basis"].startswith("type-default"), v["evidence"]


def test_negated_blocking_word_does_not_raise_the_trend():
    assert de.decide(_item("H-0207", "negocio", "não trava nada"), today=TODAY)["priority"]["t"] == 3
