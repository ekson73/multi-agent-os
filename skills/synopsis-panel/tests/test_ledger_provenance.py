"""Tests for the HITL ledger PROVENANCE signal of synopsis-panel.

The defect these cover, measured on 2026-10-26: `find_hitl_md()` resolves the
WORKING-TREE copy of `hitl/punch-list.md`. A vault 21 commits behind its upstream,
with a dirty ledger, rendered 16 open items — the SAME count as the tracked copy,
with three already-closed items shown and three real ones hidden. The matching
count is what hid the error, and nothing in the output named the file that was read.

Contract under test (the minimum that stops an agent measuring the wrong file
WITHOUT KNOWING, while never breaking a human who is editing the ledger on purpose):

  1. a divergent working ledger (dirty, or repo behind upstream) PRODUCES a warning;
  2. a clean, up-to-date ledger produces NO warning at all;
  3. every render NAMES the file that was read, warning or not;
  4. the engine stays READ-ONLY and never substitutes a different file.

The git fixtures build real repositories in tmp_path — no mocks — because the
signal being tested IS the git state.
"""

import json
import subprocess
import sys

import pytest

LEDGER = """---
id: hitl-punch-list
next_id: 3
---

# HITL punch-list

<!-- hitl:open:start -->
| ID | Sev | Tipo | R | Decidir | Pediu | Aberto | Idade | Prazo | Status | Link |
|----|-----|------|---|---------|-------|--------|-------|-------|--------|------|
| H-0001 | 🔴 URGENTE | 🔑 credencial | R3 | Primeiro item | agente | 2026-10-20 | 6 d | - | pendente | (sem ticket) |
<!-- hitl:open:end -->
"""

LEDGER_EDITED = LEDGER.replace("Primeiro item", "Primeiro item, editado no working tree")


def _git(cwd, *args, check=True):
    return subprocess.run(["git", "-C", str(cwd), *args],
                          capture_output=True, text=True, check=check)


def _init_repo(path):
    path.mkdir(parents=True, exist_ok=True)
    _git(path, "init", "-q", "-b", "main")
    _git(path, "config", "user.email", "test@example.invalid")
    _git(path, "config", "user.name", "test")
    _git(path, "config", "commit.gpgsign", "false")
    return path


@pytest.fixture
def clean_repo(tmp_path):
    """An origin + a clone whose ledger is tracked, clean and up to date."""
    origin = _init_repo(tmp_path / "origin")
    hitl = origin / "hitl"
    hitl.mkdir()
    (hitl / "punch-list.md").write_text(LEDGER, encoding="utf-8")
    _git(origin, "add", "hitl/punch-list.md")
    _git(origin, "commit", "-qm", "ledger")
    clone = tmp_path / "clone"
    subprocess.run(["git", "clone", "-q", str(origin), str(clone)], check=True)
    return clone


@pytest.fixture
def dirty_repo(clean_repo):
    """Same clone, but the working-tree ledger is modified relative to HEAD."""
    (clean_repo / "hitl" / "punch-list.md").write_text(LEDGER_EDITED, encoding="utf-8")
    return clean_repo


@pytest.fixture
def behind_repo(clean_repo):
    """Same clone, left N commits behind its upstream (ledger itself untouched)."""
    origin = clean_repo.parent / "origin"
    (origin / "hitl" / "punch-list.md").write_text(
        LEDGER.replace("next_id: 3", "next_id: 4"), encoding="utf-8")
    _git(origin, "commit", "-qam", "ledger moves on")
    _git(clean_repo, "fetch", "-q", "origin")
    return clean_repo


# ── 1 + 2: the warning fires on divergence and is SILENT when clean ───────────────
def test_clean_ledger_produces_no_warning(synopsis_fuse, clean_repo):
    prov = synopsis_fuse.ledger_provenance(clean_repo / "hitl" / "punch-list.md")
    assert prov["in_git"] is True
    assert prov["dirty"] is False
    assert prov["behind"] == 0
    assert prov["warning"] is None, (
        "a clean, up-to-date ledger must not warn — warning on the legitimate case "
        "is worse than the defect, because the signal stops meaning anything")


def test_dirty_ledger_warns(synopsis_fuse, dirty_repo):
    prov = synopsis_fuse.ledger_provenance(dirty_repo / "hitl" / "punch-list.md")
    assert prov["dirty"] is True
    assert prov["warning"], "a working-tree ledger modified against HEAD must warn"
    assert "MODIFIED" in prov["warning"]


def test_repo_behind_upstream_warns(synopsis_fuse, behind_repo):
    prov = synopsis_fuse.ledger_provenance(behind_repo / "hitl" / "punch-list.md")
    assert prov["dirty"] is False, "the file itself is untouched in this fixture"
    assert prov["behind"] == 1
    assert prov["warning"], (
        "being behind upstream is the exact shape of the measured defect: a clean "
        "file that is nonetheless not the current ledger")
    assert "BEHIND" in prov["warning"]


def test_ledger_outside_git_reports_path_without_warning(synopsis_fuse, tmp_path):
    p = tmp_path / "loose-punch-list.md"
    p.write_text(LEDGER, encoding="utf-8")
    prov = synopsis_fuse.ledger_provenance(p)
    assert prov["path"] == str(p)
    assert prov["in_git"] is False
    assert prov["warning"] is None


def test_missing_ledger_is_named_as_missing(synopsis_fuse):
    prov = synopsis_fuse.ledger_provenance(None)
    assert prov["path"] is None
    assert "not found" in prov["warning"]


# ── 3: every render NAMES the file, warning or not ────────────────────────────────
def _run(script_path, ledger, fmt="tree"):
    proc = subprocess.run(
        [sys.executable, str(script_path), "--hitl-only", "--compass-json", "-",
         "--hitl-md", str(ledger), "--format", fmt],
        input="{}", capture_output=True, text=True, timeout=120)
    assert proc.returncode == 0, proc.stderr
    return proc.stdout


@pytest.mark.parametrize("fmt", ["tree", "mermaid", "html"])
def test_render_names_the_ledger_it_read(script_path, clean_repo, fmt):
    ledger = clean_repo / "hitl" / "punch-list.md"
    out = _run(script_path, ledger, fmt)
    assert str(ledger) in out, f"{fmt} render must say which ledger file it read"


def test_json_envelope_carries_provenance(script_path, dirty_repo):
    ledger = dirty_repo / "hitl" / "punch-list.md"
    env = json.loads(_run(script_path, ledger, "json"))
    meta = env["meta"]
    assert meta["hitl_source"] == str(ledger)
    assert meta["hitl_source_dirty"] is True
    assert meta["hitl_warning"] and "MODIFIED" in meta["hitl_warning"]


def test_tree_render_shows_the_warning(script_path, dirty_repo):
    out = _run(script_path, dirty_repo / "hitl" / "punch-list.md", "tree")
    assert "\u26a0" in out and "MODIFIED" in out


def test_clean_render_shows_no_warning_glyph(script_path, clean_repo):
    out = _run(script_path, clean_repo / "hitl" / "punch-list.md", "tree")
    assert "\u26a0" not in out
    assert "BEHIND" not in out and "MODIFIED" not in out


# ── 4: still READ-ONLY and still the file the caller asked for ────────────────────
def test_engine_does_not_mutate_the_repo_or_swap_the_file(script_path, dirty_repo):
    ledger = dirty_repo / "hitl" / "punch-list.md"
    before = ledger.read_text(encoding="utf-8")
    status_before = _git(dirty_repo, "status", "--porcelain").stdout
    env = json.loads(_run(script_path, ledger, "json"))
    assert ledger.read_text(encoding="utf-8") == before
    assert _git(dirty_repo, "status", "--porcelain").stdout == status_before
    # the working-tree edit is what was PARSED — the engine warned, it did not substitute
    decidir = env["tree"]["hitl_unattached"][0]["decidir"]
    assert "editado no working tree" in decidir, (
        "a human editing the ledger on purpose must still see their own edits")
