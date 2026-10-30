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
