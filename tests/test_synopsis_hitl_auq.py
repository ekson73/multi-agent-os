"""synopsis-fuse.py — hitl-digest `--format ask-user-question` mode.

(a) existing tree/mermaid/html/json outputs stay byte-identical to the pre-change
    goldens (after normalizing the tmp path and the generation timestamp);
(b) the new mode yields a valid AskUserQuestion payload (1-4 questions, header <=12,
    2-4 options, recommended option first) and is deterministic;
(c) a machine consumer never gets a text digest.

Run: pytest tests/test_synopsis_hitl_auq.py -v
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import unicodedata

import pytest

REPO = pathlib.Path(__file__).resolve().parent.parent
FUSE = REPO / "skills" / "synopsis-panel" / "bin" / "synopsis-fuse.py"
FIX = REPO / "tests" / "fixtures" / "synopsis-panel"
ARGS = ["--session-id", "0000000011111111aaaabbbb", "--now", "1793030400"]
SESSION_A = ARGS[1]
SESSION_B = "0000000022222222ccccdddd"


def run(*args, stdin="{}"):
    env = dict(os.environ)
    for key in ("MAOS_SELF_SESSION_ID", "PI_SESSION_ID", "PI_SESSION_FILE",
                "CLAUDE_CODE_SESSION_ID", "CLAUDE_SESSION_ID", "CODEX_THREAD_ID"):
        env.pop(key, None)
    p = subprocess.run([sys.executable, str(FUSE), "--hitl-only", "--compass-json", "-", *args],
                       input=stdin, capture_output=True, text=True, timeout=60, env=env)
    assert p.returncode == 0, p.stderr
    return p.stdout


def normalize(text, tmp):
    text = text.replace(str(tmp), "<TMP>")
    text = re.sub(r'"generated_utc": "[^"]+"', '"generated_utc": "<TS>"', text)
    return re.sub(r"gerado \S+Z", "gerado <TS>Z", text)


@pytest.fixture
def ledger(tmp_path):
    dst = tmp_path / "punch-list.md"
    shutil.copy(FIX / "punch-list.md", dst)
    return dst


@pytest.mark.parametrize("fmt", ["tree", "mermaid", "html", "json"])
def test_existing_formats_byte_identical(ledger, fmt):
    out = normalize(run("--hitl-md", str(ledger), "--scope", "all", "--format", fmt), ledger.parent)
    assert out == (FIX / f"golden.{fmt}.txt").read_text(encoding="utf-8")


def payload(ledger, *extra):
    return json.loads(run("--hitl-md", str(ledger), "--scope", "all",
                          "--format", "ask-user-question", *ARGS, *extra))


def test_auq_payload_valid_and_deterministic(ledger):
    a = run("--hitl-md", str(ledger), "--scope", "all", "--format", "ask-user-question", *ARGS)
    b = run("--hitl-md", str(ledger), "--scope", "all", "--format", "ask-user-question", *ARGS)
    assert a == b
    d = json.loads(a)
    qs = d["ask_user_question"]["questions"]
    assert 1 <= len(qs) <= 4
    for q in qs:
        assert len(q["header"]) <= 12
        assert 2 <= len(q["options"]) <= 4
        assert q["multiSelect"] is False
        labels = [o["label"] for o in q["options"]]
        assert len(set(labels)) == len(labels)
        for o in q["options"]:
            assert o["description"] and o["description"] != o["label"]
    assert d["code"] == "K261026-1600-aaaabbbb"
    assert d["preamble"][0].startswith("══ 🟠 HITL DIGEST · K261026-1600-aaaabbbb")
    # severity order: URGENTE first, overflow is not answerable
    assert [c["sev"] for c in d["cards"]][:2] == ["URGENTE", "URGENTE"]
    assert set(d["overflow"]).isdisjoint({c["id"] for c in d["cards"]})
    assert not any("Responda:" in line for line in d["preamble"])
    assert all("aberta no AskUserQuestion" in l for l in d["preamble"] if l.startswith("· "))


def test_auq_record_lines_fit_80_columns(ledger):
    import unicodedata
    def width(s):
        return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
    d = payload(ledger)
    assert all(width(l) <= 80 for l in d["preamble"])


def test_auq_structured_recommendation_first(tmp_path):
    items = [{"id": "H-0999", "session_id": SESSION_A, "sev": "🟠 ALTA", "tipo": "envio", "risk": "R2",
              "decidir": "Aprovar o rascunho X", "aberto": "2026-10-01", "idade": "25 d",
              "link": "-", "options": [
                  {"label": "Pedir ajustes", "description": "nada é enviado"},
                  {"label": "Aprovar", "description": "a mensagem sai", "recommended": True,
                   "evidence": "#1 abcdef12", "confidence": "alta"}]}]
    hj = tmp_path / "h.json"
    hj.write_text(json.dumps(items), encoding="utf-8")
    d = json.loads(run("--hitl-json", str(hj), "--format", "ask-user-question", *ARGS))
    opts = d["ask_user_question"]["questions"][0]["options"]
    assert opts[0]["label"].endswith("(recomendado)")
    assert "#1 abcdef12" in opts[0]["description"]
    assert d["cards"][0]["has_recommendation"] is True


@pytest.mark.parametrize("evidence", [None, "", "   ", "\t\n", 123, {}])
def test_auq_recommendation_needs_evidence(tmp_path, evidence):
    items = [{"id": "H-0998", "session_id": SESSION_A, "sev": "🟡 NORMAL", "tipo": "negocio", "decidir": "Y",
              "options": [{"label": "A1", "description": "x", "recommended": True, "evidence": evidence},
                          {"label": "B1", "description": "y"}]}]
    hj = tmp_path / "h.json"
    hj.write_text(json.dumps(items), encoding="utf-8")
    d = json.loads(run("--hitl-json", str(hj), "--format", "ask-user-question", *ARGS))
    assert not any("(recomendado)" in o["label"] for o in d["ask_user_question"]["questions"][0]["options"])


def test_machine_consumer_gets_no_text_digest(ledger):
    out = run("--hitl-md", str(ledger), "--scope", "all",
              "--format", "ask-user-question", "--consumer", "machine", *ARGS)
    d = json.loads(out)
    assert d["artifact"] == "synopsis-panel" and "ask_user_question" not in d
    assert "HITL DIGEST" not in out
    baseline = run("--hitl-md", str(ledger), "--scope", "all", "--format", "json", *ARGS)
    assert normalize(out, ledger.parent) == normalize(baseline, ledger.parent)
    assert not out.endswith("\n") and not baseline.endswith("\n")


def test_human_deferred_gets_existing_text(ledger):
    out = run("--hitl-md", str(ledger), "--scope", "all", "--format", "ask-user-question", "--consumer", "human-deferred", *ARGS)
    assert out == run("--hitl-md", str(ledger), "--scope", "all", "--format", "tree")


def test_no_session_id_no_code(ledger, monkeypatch):
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    monkeypatch.delenv("CODEX_THREAD_ID", raising=False)
    d = json.loads(run("--hitl-md", str(ledger), "--scope", "all",
                       "--format", "ask-user-question", "--now", "1793030400"))
    assert d["code"] is None and d["preamble"][0] == "══ 🟠 HITL DIGEST ══"


def _hj(tmp_path, items, *extra, compass="{}"):
    hj = tmp_path / "h.json"
    hj.write_text(json.dumps([{"session_id": SESSION_A, **it} for it in items]), encoding="utf-8")
    return json.loads(run("--hitl-json", str(hj), "--format", "ask-user-question",
                          *ARGS, *extra, stdin=compass))


def test_single_structured_option_padded(tmp_path):
    d = _hj(tmp_path, [{"id": "H-0997", "sev": "🟡 NORMAL", "tipo": "negocio", "decidir": "Z",
                        "idade": "3 d", "options": [{"label": "Só esta", "description": "x"}]}])
    opts = d["ask_user_question"]["questions"][0]["options"]
    assert len(opts) == 2 and opts[1]["label"] == "Manter pendente" and "3 d" in opts[1]["description"]


def test_duplicate_labels_after_clip_are_unique(tmp_path):
    long = "Aprovar a proposta com todos os ajustes pedidos pelo cliente " * 2
    d = _hj(tmp_path, [{"id": "H-0996", "sev": "🟡 NORMAL", "tipo": "negocio", "decidir": "W",
                        "options": [{"label": long + "A", "description": "a"},
                                    {"label": long + "B", "description": "b"}]}])
    labels = [o["label"] for o in d["ask_user_question"]["questions"][0]["options"]]
    assert len(set(labels)) == len(labels)


def test_empty_queue_no_decisions(tmp_path):
    d = _hj(tmp_path, [])
    assert d["ask_user_question"] is None and d["no_decisions"] is True
    assert any("não abra AskUserQuestion" in l for l in d["preamble"])


def test_unknown_sev_overflow_does_not_crash(tmp_path):
    items = [{"id": f"H-09{i:02d}", "sev": "🟠 ALTA", "tipo": "negocio", "decidir": "q"} for i in range(4)]
    items.append({"id": "H-0950", "sev": "???", "tipo": "negocio", "decidir": "q"})
    d = _hj(tmp_path, items)
    assert "H-0950" in d["overflow"]


def test_provenance_fields_present(ledger):
    d = payload(ledger)
    for k in ("hitl_source", "hitl_source_kind", "hitl_source_dirty", "hitl_source_behind", "hitl_warning"):
        assert k in d


@pytest.mark.parametrize("labels", [
    ["A", "A", "A (2)"],
    ["A", "A (2)", "A", "A (3)"],
    ["x" * 65, "x" * 65, "x" * 65, "x" * 65],
])
def test_emitted_labels_are_unique(tmp_path, labels):
    d = _hj(tmp_path, [{"id": "H-0801", "decidir": "Selecionar", "options": [
        {"label": label, "description": str(i)} for i, label in enumerate(labels)]}])
    opts = d["ask_user_question"]["questions"][0]["options"]
    assert len(opts) == len(labels)
    assert len({o["label"] for o in opts}) == len(opts)
    assert all(len(o["label"]) <= 60 for o in opts)
    assert [o["description"] for o in opts] == [str(i) for i in range(len(labels))]


@pytest.mark.parametrize("choices, expected", [
    ("autorizar R$ 10,50, ou adiar", ["autorizar R$ 10,50", "adiar"]),
    ("usar 1,5 unidades, limitar 2,75, ou adiar",
     ["usar 1,5 unidades", "limitar 2,75", "adiar"]),
])
def test_decimal_commas_preserve_choices(tmp_path, choices, expected):
    d = _hj(tmp_path, [{"id": "H-0802", "decidir": f"opções: {choices}"}])
    assert [o["label"] for o in d["ask_user_question"]["questions"][0]["options"]] == expected
    assert d["cards"][0]["options_source"] == "ledger-text"


def test_attached_cards_remain_session_scoped(tmp_path):
    items = [{"id": "H-0803", "decidir": "SYNTHETIC_OWN", "session_id": SESSION_A},
             {"id": "H-0804", "decidir": "SYNTHETIC_FOREIGN", "session_id": SESSION_B},
             {"id": "H-0805", "decidir": "SYNTHETIC_LEGACY", "session_id": "-"}]
    compass = json.dumps({"by_domain": {"test": [
        {"id": it["id"], "title": "attached"} for it in items]}})
    d = _hj(tmp_path, items, compass=compass)
    assert [c["id"] for c in d["cards"]] == ["H-0803"]
    assert d["ask_user_question"]["questions"][0]["header"] == "H-0803"
    assert d["hitl_scope"] == "session" and d["hitl_ledger_total"] == 3
    assert d["hitl_session_ids"] == [SESSION_A]
    out = json.dumps(d)
    for value in ("H-0804", "H-0805", "SYNTHETIC_FOREIGN", "SYNTHETIC_LEGACY"):
        assert value not in out


def test_markdown_session_column_filters_live_payload(tmp_path):
    ledger = tmp_path / "two-sessions.md"
    ledger.write_text(
        "<!-- hitl:open:start -->\n"
        "| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link | Sessão |\n"
        "|----|-----|------|---|---------|-------|--------|-------|-------|--------|------|--------|\n"
        f"| H-0806 | ALTA | negocio | R1 | SYNTHETIC_OWN | agente | 2026-10-01 | 1 d | - | pendente | - | {SESSION_A} |\n"
        f"| H-0807 | URGENTE | negocio | R1 | SYNTHETIC_FOREIGN | agente | 2026-10-01 | 1 d | - | pendente | - | {SESSION_B} |\n"
        "<!-- hitl:open:end -->\n", encoding="utf-8")
    out = run("--hitl-md", str(ledger), "--format", "ask-user-question", *ARGS)
    d = json.loads(out)
    assert [c["id"] for c in d["cards"]] == ["H-0806"]
    assert "H-0807" not in out and "SYNTHETIC_FOREIGN" not in out
    assert d["hitl_session_resolved"] is True
    assert not any(c["has_recommendation"] for c in d["cards"])


def test_unresolved_live_scope_is_not_an_empty_queue(tmp_path):
    hj = tmp_path / "h.json"
    hj.write_text(json.dumps([{"id": "H-0808", "session_id": SESSION_B,
                              "decidir": "SYNTHETIC_FOREIGN"}]))
    out = run("--hitl-json", str(hj), "--format", "ask-user-question")
    d = json.loads(out)
    assert d["ask_user_question"] is None
    assert d["no_decisions"] is False
    assert d["hitl_session_resolved"] is False and d["hitl_scope_unresolved"]
    assert d["hitl_ledger_total"] == 1
    assert "H-0808" not in out and "SYNTHETIC_FOREIGN" not in out
    visible = "".join("".join(d["preamble"]).split())
    assert "".join(d["hitl_scope_unresolved"].split()) in visible


def _width(text):
    return sum(0 if unicodedata.combining(c) else
               2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


@pytest.mark.parametrize("title", ["界" * 30, "界e\u0301" * 20])
def test_wide_unicode_titles_fit_record_columns(tmp_path, title):
    d = _hj(tmp_path, [{"id": "H-0809", "sev": "URGENTE", "decidir": title}])
    assert all(_width(line) <= 80 for line in d["preamble"])
    assert d["cards"][0]["id"] == "H-0809"
    assert title in d["ask_user_question"]["questions"][0]["question"]


def test_long_metadata_survives_wrapping(tmp_path):
    harness, repo = "HARNESS_" + "界" * 90, "REPO_" + "x" * 120
    d = _hj(tmp_path, [{"id": "H-0810", "decidir": "Escolher"}],
            "--harness", harness, "--repo", repo)
    assert all(_width(line) <= 80 for line in d["preamble"])
    visible = "".join(d["preamble"])
    assert harness in visible and repo in visible and SESSION_A[-8:] in visible


def test_untracked_warning_is_complete_at_long_path(tmp_path):
    subprocess.run(["git", "-C", str(tmp_path), "init", "-q"], check=True)
    parent = tmp_path / ("a" * 70) / ("b" * 70) / ("界" * 30)
    parent.mkdir(parents=True)
    hj = parent / "untracked.json"
    hj.write_text(json.dumps([{"id": "H-0811", "session_id": SESSION_A,
                              "decidir": "Escolher"}]))
    d = json.loads(run("--hitl-json", str(hj), "--format", "ask-user-question", *ARGS))
    assert d["hitl_warning"]
    assert all(_width(line) <= 80 for line in d["preamble"])
    visible = "".join("".join(d["preamble"]).split())
    assert "".join(d["hitl_warning"].split()) in visible
    assert str(hj) in "".join(d["preamble"])


def test_malformed_json_preserves_self_heal_error(tmp_path):
    hj = tmp_path / "broken.json"
    hj.write_text("{", encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(FUSE), "--hitl-only", "--compass-json", "-",
         "--hitl-json", str(hj), "--format", "ask-user-question", "--self-heal", *ARGS],
        input="{}", capture_output=True, text=True, timeout=60)
    assert proc.returncode == 1 and proc.stdout == ""
    error = json.loads(proc.stderr)
    assert error["synopsis_panel_error"] is True
    assert error["error_type"] == "JSONDecodeError"
