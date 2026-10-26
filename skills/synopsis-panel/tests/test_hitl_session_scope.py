"""Tests for the HITL SESSION SCOPE of synopsis-panel.

The defect these cover, measured on 2026-10-26: the HITL ledger is ONE global
queue — every conversation's gates in the same file — and the digest rendered all
of it. A `/hitl-digest` answering "what needs ME now" therefore answered with
19 gates, most of them owned by other conversations.

Contract under test:

  1. the DEFAULT in --hitl-only mode is THIS conversation's items, and the
     filter runs BEFORE the counts, so every number describes the shown slice;
  2. only an explicit `--scope all` widens to the whole ledger, legacy items
     included — any other scope narrows;
  3. ownership is PROVEN by the ledger's own "Sessão" column: an item with no
     provenance (or "-") is legacy and never enters the session scope, and a
     mention in chat is not provenance;
  4. an UNRESOLVED identity fails closed: nothing is shown and the reason is
     stated — never "everything", never "there is nothing";
  5. outside --hitl-only the general panel keeps its historical behaviour (the
     whole ledger), and the work-compass pendency scope is untouched.

The fixtures are REAL ledgers in the writer's own format: the same table shape,
the same column names, the same "-" for a missing provenance. The row content
is invented for the test, but the FORMAT is the writer's contract, not a
parallel invention — a divergence between the two would show up here as a
parse failure, which is the point.

The CLI is invoked as a real subprocess — no mocks, because the behaviour being
tested IS the CLI's.
"""

import json
import os
import subprocess
import sys

import pytest

SESSION_A = "01a13c82-0525-75a0-b620-c81e79c32830"
SESSION_B = "01a16b0d-cd00-74c2-8c50-164ec90b27f6"

# The writer's table shape: the 11 base columns plus the "Sessão" provenance
# column. "-" is the writer's marker for "no provenance" (a legacy row).
LEDGER = """---
id: hitl-punch-list
next_id: 4
---

# HITL punch-list

<!-- hitl:open:start -->
| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link | Sessão |
|----|-----|------|---|---------|-------|--------|-------|-------|--------|------|--------|
| H-0001 | 🔴 URGENTE | 🔑 credencial | R3 | Gate da sessao A | agente | 2026-10-20 | 6 d | - | pendente | (sem ticket) | {a} |
| H-0002 | 🟠 ALTA | ⚖️ negocio | R2 | Gate da sessao B | agente | 2026-10-21 | 5 d | - | pendente | (sem ticket) | {b} |
| H-0003 | 🟡 NORMAL | 📤 envio | R1 | Gate legado sem proveniencia | agente | 2026-10-22 | 4 d | - | pendente | (sem ticket) | - |
<!-- hitl:open:end -->
""".format(a=SESSION_A, b=SESSION_B)

# A ledger written BEFORE the writer gained the column: 11 columns, no
# provenance anywhere. Every item in it is legacy.
LEDGER_LEGACY = """---
id: hitl-punch-list
next_id: 3
---

# HITL punch-list

<!-- hitl:open:start -->
| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link |
|----|-----|------|---|---------|-------|--------|-------|-------|--------|------|
| H-0001 | 🔴 URGENTE | 🔑 credencial | R3 | Gate legado um | agente | 2026-10-20 | 6 d | - | pendente | (sem ticket) |
| H-0002 | 🟠 ALTA | ⚖️ negocio | R2 | Gate legado dois | agente | 2026-10-21 | 5 d | - | pendente | (sem ticket) |
<!-- hitl:open:end -->
"""


def _ledger(tmp_path, body=LEDGER):
    p = tmp_path / "punch-list.md"
    p.write_text(body, encoding="utf-8")
    return p


def _run(script_path, ledger, *extra, env=None, compass="{}"):
    """Invoke the real CLI. The compass payload is stdin, so NO collector runs."""
    cmd = [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
           "--hitl-md", str(ledger), "--format", "json", *extra]
    proc = subprocess.run(cmd, input=compass, capture_output=True, text=True,
                          timeout=120, env=env)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def _clean_env(**overrides):
    """An environment with NO session identity at all."""
    env = dict(os.environ)
    for var in ("MAOS_SELF_SESSION_ID", "PI_SESSION_ID", "PI_SESSION_FILE",
                "CLAUDE_CODE_SESSION_ID", "CLAUDE_SESSION_ID"):
        env.pop(var, None)
    env.update(overrides)
    return env


def _ids(envelope):
    return [h["id"] for h in envelope["tree"]["hitl_unattached"]]


# ── 1: the default is THIS conversation's items, and the counts follow ────────────
def test_default_scope_shows_only_the_calling_session(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == ["H-0001"], (
        "the default must be the calling conversation's items, not the whole queue")
    assert env["meta"]["hitl_scope"] == "session"
    assert env["meta"]["hitl_session_ids"] == [SESSION_A]
    # the counts describe the SHOWN slice, not the ledger: the filter runs first
    assert env["meta"]["hitl_count"] == 1
    assert env["meta"]["hitl_orphan"] == 1


def test_explicit_session_id_selects_that_session(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--session-id", SESSION_B,
               env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == ["H-0002"]


def test_session_id_may_be_a_set(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--session-id", f"{SESSION_A},{SESSION_B}",
               env=_clean_env())
    assert sorted(_ids(env)) == ["H-0001", "H-0002"]


def test_scope_session_is_the_same_as_the_default(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--scope", "session",
               env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == ["H-0001"]


# ── 2: only an explicit `all` widens ────────────────────────────────────────────
def test_explicit_scope_all_shows_the_whole_ledger_including_legacy(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--scope", "all", env=_clean_env())
    assert sorted(_ids(env)) == ["H-0001", "H-0002", "H-0003"]
    assert env["meta"]["hitl_scope"] == "all"
    assert env["meta"]["hitl_count"] == 3


def test_a_pendency_scope_does_not_widen_the_ledger(script_path, tmp_path):
    """`--scope repo` is a PENDENCY scope; it must not become a widening."""
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--scope", "repo",
               env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == ["H-0001"]
    assert env["meta"]["hitl_scope"] == "session"


# ── 3: legacy items (no provenance) never enter the session scope ───────────────
def test_legacy_item_without_provenance_is_excluded_from_the_session_scope(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert "H-0003" not in _ids(env), (
        "an item with no provenance is legacy: it belongs to no known conversation "
        "and must not be attributed to the caller")


def test_legacy_item_shows_only_in_the_global_scope(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--scope", "all", env=_clean_env())
    assert "H-0003" in _ids(env)


def test_a_ledger_without_the_session_column_is_all_legacy(script_path, tmp_path):
    """A ledger written before the column existed parses and stays legacy."""
    ledger = _ledger(tmp_path, LEDGER_LEGACY)
    env = _run(script_path, ledger, "--scope", "all", env=_clean_env())
    assert sorted(_ids(env)) == ["H-0001", "H-0002"]
    env = _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == [], "a ledger with no provenance column owns nothing"


def test_mentioning_an_item_does_not_make_it_mine(script_path, tmp_path):
    """A chat mention is not provenance: the ledger decides, and only the ledger."""
    body = LEDGER.replace("Gate legado sem proveniencia", "H-0001 Gate legado sem proveniencia")
    ledger = _ledger(tmp_path, body)
    env = _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == ["H-0001"], (
        "the only item of session A is H-0001; a legacy item that merely mentions "
        "H-0001 stays out of the session scope")


# ── 4: an unresolved identity fails closed ──────────────────────────────────────
def test_unresolved_identity_shows_nothing_and_says_why(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env())
    assert _ids(env) == [], "an unresolved identity must not fall back to the whole ledger"
    meta = env["meta"]
    assert meta["hitl_scope"] == "session"
    assert meta["hitl_session_resolved"] is False
    assert meta["hitl_scope_unresolved"], "the reason must be stated, not implied"
    assert meta["hitl_count"] == 0
    # the ledger's own size is still reported, so "0 shown" is never read as "0 exist"
    assert meta["hitl_ledger_total"] == 3


def test_a_narrowed_scope_still_reports_the_ledger_size(script_path, tmp_path):
    """0 of 19 shown must not read as 'there is nothing'."""
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert env["meta"]["hitl_count"] == 1
    assert env["meta"]["hitl_ledger_total"] == 3


def test_unresolved_identity_does_not_claim_the_queue_is_empty(script_path, tmp_path):
    """The render must distinguish 'unknown scope' from 'no gates'."""
    ledger = _ledger(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "tree"],
        input="{}", capture_output=True, text=True, timeout=120, env=_clean_env())
    assert proc.returncode == 0, proc.stderr
    out = proc.stdout
    assert "H-0001" not in out and "H-0003" not in out
    assert "unresolved" in out.lower()
    assert "NOT an empty queue" in out


def test_unresolved_identity_never_leaks_other_sessions_items(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    out = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "tree"],
        input="{}", capture_output=True, text=True, timeout=120, env=_clean_env()).stdout
    assert "Gate da sessao A" not in out and "Gate da sessao B" not in out


def test_a_narrowed_scope_says_how_many_the_ledger_holds(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    out = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "tree"],
        input="{}", capture_output=True, text=True, timeout=120,
        env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A)).stdout
    assert "1 of 3 ledger items" in out, (
        "a session scope that shows fewer items must say how many the ledger holds — "
        "'0 shown' would read as 'nothing exists'")


def test_an_unresolved_identity_claims_no_ownership_split(script_path, tmp_path):
    """With an unresolved identity the engine cannot say which ledger items are
    the caller's — so it must not present a per-conversation split. The metadata
    is the contract: the scope is unresolved and no item is attributed."""
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env())
    meta = env["meta"]
    assert meta["hitl_session_resolved"] is False
    assert meta["hitl_session_ids"] == []
    assert meta["hitl_count"] == 0
    # the ledger's size is still reported — the DATA is not lost, only the claim
    assert meta["hitl_ledger_total"] == 3
    assert meta["hitl_scope_unresolved"]
    out = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "tree"],
        input="{}", capture_output=True, text=True, timeout=120, env=_clean_env()).stdout
    assert "are this conversation's" not in out, (
        "with an unresolved identity the render must not assert how the ledger splits "
        "between conversations — it does not know which one is the caller's")
    assert "NOT an empty queue" in out


# ── 5: identity resolution and the untouched general panel ──────────────────────
def test_identity_comes_from_the_harness_environment(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, env=_clean_env(CLAUDE_SESSION_ID=SESSION_B))
    assert _ids(env) == ["H-0002"]
    assert env["meta"]["hitl_session_source"] == "env:CLAUDE_SESSION_ID"


# ── 4b: the identity comes from the harness's OWN session layout (P2) ───────────
def test_the_identity_resolves_from_the_session_file_name(synopsis_fuse):
    """The OMP layout: <timestamp>_<uuid>.jsonl — the uuid is in the file name."""
    ident = synopsis_fuse.resolve_session_identity(
        None, {"PI_SESSION_FILE": f"/x/2026-10-14T22-21-56-389Z_{SESSION_A}.jsonl"})
    assert ident["resolved"] is True
    assert ident["ids"] == [SESSION_A]


def test_the_identity_resolves_from_the_forked_session_directory(synopsis_fuse):
    """The OMP layout for a delegated run: <timestamp>_<uuid>/<worker>.jsonl — the
    uuid is in the PARENT DIRECTORY name, the same convention the repo already
    reads in scripts/corpus-firing-audit.py and scripts/ichnos-analytics.py."""
    ident = synopsis_fuse.resolve_session_identity(
        None, {"PI_SESSION_FILE": f"/x/2026-10-14T22-21-56-389Z_{SESSION_A}/Worker.jsonl"})
    assert ident["resolved"] is True
    assert ident["ids"] == [SESSION_A]


def test_an_arbitrary_parent_directory_does_not_resolve_an_identity(synopsis_fuse):
    """A directory whose name is not a session layout must not resolve anything."""
    ident = synopsis_fuse.resolve_session_identity(
        None, {"PI_SESSION_FILE": "/tmp/not-a-session-dir/Worker.jsonl"})
    assert ident["resolved"] is False
    assert ident["ids"] == []


def test_the_process_scoped_session_id_is_not_the_conversation(synopsis_fuse):
    """PI_SESSION_ID is per PROCESS: in a delegated run it is the fork's id, not the
    conversation's. The engine must not read it."""
    ident = synopsis_fuse.resolve_session_identity(
        None, {"PI_SESSION_ID": "01a17992-43e8-772d-a304-7eb015417730"})
    assert ident["resolved"] is False


def test_an_empty_session_id_does_not_shadow_the_environment(synopsis_fuse):
    """An empty --session-id carries no claim; the environment still answers."""
    ident = synopsis_fuse.resolve_session_identity(
        "", {"MAOS_SELF_SESSION_ID": SESSION_A})
    assert ident["resolved"] is True
    assert ident["ids"] == [SESSION_A]


def test_an_identity_of_only_separators_is_not_an_identity(synopsis_fuse):
    """A value like " , " is not an id: reporting it as RESOLVED would show an
    empty queue with no warning — the "unknown is not nothing" case."""
    for value in (" , ", ",", " ", "-"):
        ident = synopsis_fuse.resolve_session_identity(
            None, {"MAOS_SELF_SESSION_ID": value})
        assert ident["resolved"] is False, f"{value!r} must not resolve an identity"
        assert ident["ids"] == []


def test_the_unknown_sentinel_is_not_an_identity(synopsis_fuse):
    """"unknown" is the repo-wide spelling of "absent" (plugin-scripts/
    pre-delegate.sh, post-delegate.sh, session-end.sh, governance/lib/common.sh)."""
    ident = synopsis_fuse.resolve_session_identity(
        "unknown", {"MAOS_SELF_SESSION_ID": SESSION_A})
    assert ident["ids"] == [SESSION_A], "an explicit 'unknown' must not shadow the env"
    ident = synopsis_fuse.resolve_session_identity(None, {"MAOS_SELF_SESSION_ID": "unknown"})
    assert ident["resolved"] is False


# ── 3b: the base columns are located by the header, not by position (P2) ────────
def test_a_moved_session_column_does_not_shift_the_base_columns(synopsis_fuse, tmp_path):
    """If the writer put "Sessão" anywhere but last, the base values must not move."""
    body = LEDGER.replace(
        "| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link | Sessão |",
        "| ID | Sessão | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link |")
    body = body.replace(f"| {SESSION_A} |", f"| {SESSION_A} |", 1)
    lines = []
    for line in body.splitlines():
        if line.startswith("| H-0001"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            # move the session cell from the end to the second position
            sess = cells.pop()
            cells.insert(1, sess)
            line = "| " + " | ".join(cells) + " |"
        lines.append(line)
    ledger = tmp_path / "punch-list.md"
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
    items = synopsis_fuse.parse_hitl_md(ledger)
    item = next(i for i in items if i["id"] == "H-0001")
    assert item["sev"].endswith("URGENTE"), "the severity must not be the session id"
    assert item["tipo"] == "credencial"
    assert item["risk"] == "R3"
    assert item["decidir"] == "Gate da sessao A"
    assert item["session"] == [SESSION_A]



def test_explicit_session_id_beats_the_environment(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--session-id", SESSION_A,
               env=_clean_env(CLAUDE_SESSION_ID=SESSION_B))
    assert _ids(env) == ["H-0001"]


def test_the_general_panel_keeps_the_whole_ledger(script_path, tmp_path):
    """Outside --hitl-only the panel is unchanged: it is a landscape, not a digest."""
    ledger = _ledger(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(script_path), "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "json"],
        input="{}", capture_output=True, text=True, timeout=120, env=_clean_env())
    assert proc.returncode == 0, proc.stderr
    env = json.loads(proc.stdout)
    assert env["meta"]["hitl_scope"] == "all"
    assert env["meta"]["hitl_count"] == 3


def test_the_pure_path_never_calls_the_collector(script_path, tmp_path):
    """The pure path takes the compass from stdin, so no collector may run."""
    ledger = _ledger(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", "json"],
        input="{}", capture_output=True, text=True, timeout=120, env=_clean_env())
    assert proc.returncode == 0, proc.stderr
    env = json.loads(proc.stdout)
    assert env["meta"]["compass_count"] == 0, (
        "an empty compass payload must stay empty — the collector did not run")


def test_the_engine_does_not_write_to_the_ledger(script_path, tmp_path):
    ledger = _ledger(tmp_path)
    before = ledger.read_text(encoding="utf-8")
    _run(script_path, ledger, env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert ledger.read_text(encoding="utf-8") == before


@pytest.mark.parametrize("fmt", ["tree", "mermaid", "html"])
def test_every_render_names_the_scope_it_applied(script_path, tmp_path, fmt):
    ledger = _ledger(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", fmt],
        input="{}", capture_output=True, text=True, timeout=120,
        env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert proc.returncode == 0, proc.stderr
    assert "H-0001" in proc.stdout
    assert "H-0002" not in proc.stdout
    assert "session" in proc.stdout.lower()


# ── 6: the JSON path carries the same provenance, under the writer's field ──────
def test_the_json_path_reads_the_session_id_field(script_path, tmp_path):
    payload = tmp_path / "hitl.json"
    payload.write_text(json.dumps([
        {"id": "H-0001", "decidir": "Gate A", "session_id": SESSION_A},
        {"id": "H-0002", "decidir": "Gate B", "session_id": SESSION_B},
        {"id": "H-0003", "decidir": "Gate legado", "session_id": "-"},
    ]), encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-json", str(payload), "--format", "json"],
        input="{}", capture_output=True, text=True, timeout=120,
        env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert proc.returncode == 0, proc.stderr
    env = json.loads(proc.stdout)
    assert [h["id"] for h in env["tree"]["hitl_unattached"]] == ["H-0001"]


def test_a_json_item_without_session_id_is_legacy(script_path, tmp_path):
    payload = tmp_path / "hitl.json"
    payload.write_text(json.dumps([
        {"id": "H-0001", "decidir": "Gate A", "session_id": SESSION_A},
        {"id": "H-0002", "decidir": "Gate sem campo"},
    ]), encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-json", str(payload), "--format", "json"],
        input="{}", capture_output=True, text=True, timeout=120,
        env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert proc.returncode == 0, proc.stderr
    env = json.loads(proc.stdout)
    assert [h["id"] for h in env["tree"]["hitl_unattached"]] == ["H-0001"]


# ── 7: the id is compared EXACTLY, not case-folded ──────────────────────────────
def test_the_session_id_is_compared_exactly(script_path, tmp_path):
    """A session id is opaque: a different case is a DIFFERENT id."""
    upper = SESSION_A.upper()
    ledger = _ledger(tmp_path)
    env = _run(script_path, ledger, "--session-id", upper,
               env=_clean_env(MAOS_SELF_SESSION_ID=SESSION_A))
    assert _ids(env) == [], (
        "the ledger's id and the requested id must match exactly; a casefold would "
        "silently match a different conversation")
