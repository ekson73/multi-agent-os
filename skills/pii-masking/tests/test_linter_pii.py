"""Tests for the PII masking linter.

Covers three categories: CPF, Email, Phone-BR; plus mask invariants
(raw PII never echoed), allowlist behavior, CLI exit codes, and the
catastrophic-backtracking-safe regex on adversarial inputs.

Test CPFs used:
    - 111.444.777-35 — standard Brazilian test fixture (valid checksum)
    - 529.982.247-25 — computed via the same Modulo-11 algorithm
    - 111.111.111-11 — all-same-digit; checksum algebraically valid but
      rejected by Receita Federal anti-fraud rule
"""

import json
import pathlib
import subprocess
import sys
import textwrap

import pytest

import linter_pii


REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
LINTER_PATH = pathlib.Path(__file__).resolve().parents[1] / "linter_pii.py"

VALID_CPF_FORMATTED = "111.444.777-35"
VALID_CPF_RAW = "11144477735"
VALID_CPF_SECONDARY = "529.982.247-25"
ALL_SAME_DIGIT_CPF = "111.111.111-11"
INVALID_CHECKSUM_CPF = "111.444.777-99"


# ── CPF detection ──────────────────────────────────────────────────────────


def test_cpf_valid_formatted_is_detected():
    findings = linter_pii.scan_text("sample.md", f"Customer CPF: {VALID_CPF_FORMATTED} on file.")
    cpfs = [f for f in findings if f.pii_type == "cpf"]
    assert len(cpfs) == 1
    assert VALID_CPF_FORMATTED not in cpfs[0].masked_excerpt
    assert "111.***.***-35" in cpfs[0].masked_excerpt


def test_cpf_valid_raw_11_digits_is_detected():
    findings = linter_pii.scan_text("dump.txt", f"id={VALID_CPF_RAW};")
    cpfs = [f for f in findings if f.pii_type == "cpf"]
    assert len(cpfs) == 1
    assert VALID_CPF_RAW not in cpfs[0].masked_excerpt
    assert "111.***.***-35" in cpfs[0].masked_excerpt


def test_cpf_secondary_valid_is_detected():
    findings = linter_pii.scan_text("file.md", f"Outro CPF: {VALID_CPF_SECONDARY}")
    cpfs = [f for f in findings if f.pii_type == "cpf"]
    assert len(cpfs) == 1
    assert VALID_CPF_SECONDARY not in cpfs[0].masked_excerpt


def test_cpf_invalid_checksum_is_skipped():
    findings = linter_pii.scan_text("data.csv", f"User listed {INVALID_CHECKSUM_CPF} (placeholder).")
    assert [f for f in findings if f.pii_type == "cpf"] == []


def test_cpf_all_same_digit_is_rejected_anti_fraud():
    assert linter_pii.is_valid_cpf(ALL_SAME_DIGIT_CPF) is False
    findings = linter_pii.scan_text("doc.md", f"Sentinela: {ALL_SAME_DIGIT_CPF}")
    assert [f for f in findings if f.pii_type == "cpf"] == []


def test_cpf_embedded_in_longer_digit_run_is_not_matched():
    findings = linter_pii.scan_text(
        "log.txt",
        f"transaction_id=99{VALID_CPF_RAW}99 was approved",
    )
    assert [f for f in findings if f.pii_type == "cpf"] == []


# ── Email detection ────────────────────────────────────────────────────────


def test_email_valid_is_detected():
    findings = linter_pii.scan_text("notes.md", "Contact: alice@gmail.com for details.")
    emails = [f for f in findings if f.pii_type == "email"]
    assert len(emails) == 1
    assert "alice@gmail.com" not in emails[0].masked_excerpt
    assert "a***@gmail.com" in emails[0].masked_excerpt


def test_email_allowlist_noreply_github_is_skipped():
    findings = linter_pii.scan_text("cfg.yml", "author = 'noreply@github.com'")
    assert [f for f in findings if f.pii_type == "email"] == []


def test_email_allowlist_test_example_com_is_skipped():
    findings = linter_pii.scan_text("fix.py", "fixture_email = 'test@example.com'")
    assert [f for f in findings if f.pii_type == "email"] == []


def test_email_allowlist_wildcard_example_domains_are_skipped():
    text = textwrap.dedent(
        """
        users: jane.doe@example.com
        users: bob@example.org
        users: carol@example.net
        """
    )
    assert [f for f in linter_pii.scan_text("u.yml", text) if f.pii_type == "email"] == []


def test_email_invalid_no_at_is_not_matched():
    findings = linter_pii.scan_text("readme.md", "Just text not.an.email here.")
    assert [f for f in findings if f.pii_type == "email"] == []


def test_email_code_identifier_without_tld_is_not_matched():
    # `email@interface` (Java/TS-style annotation reference) lacks a valid TLD
    # and must not be matched by the safe-subset regex.
    findings = linter_pii.scan_text("Decorator.java", "@email @interface Email { }")
    assert [f for f in findings if f.pii_type == "email"] == []


# ── Phone E.164-BR detection ───────────────────────────────────────────────


def test_phone_br_valid_e164_is_detected():
    findings = linter_pii.scan_text("crm.csv", "Phone: +55 11 98765-4321")
    phones = [f for f in findings if f.pii_type == "phone_br"]
    assert len(phones) == 1
    assert "98765-4321" not in phones[0].masked_excerpt
    assert "+55 11 ****-****" in phones[0].masked_excerpt


def test_phone_br_valid_compact_form_is_detected():
    findings = linter_pii.scan_text("crm.csv", "Mobile=+5511987654321")
    assert len([f for f in findings if f.pii_type == "phone_br"]) == 1


def test_phone_non_br_is_not_matched():
    findings = linter_pii.scan_text("intl.csv", "US line: +1 555-1234")
    assert [f for f in findings if f.pii_type == "phone_br"] == []


# ── Output safety invariants ───────────────────────────────────────────────


def test_raw_pii_never_appears_in_json_output(tmp_path):
    sample = tmp_path / "user.md"
    sample.write_text(
        f"CPF {VALID_CPF_FORMATTED}, email leak.actor@gmail.com, fone +55 11 98765-4321\n",
        encoding="utf-8",
    )
    findings = linter_pii.scan_file(sample)
    payload = json.dumps([f.as_dict() for f in findings])
    for forbidden in (
        VALID_CPF_FORMATTED,
        VALID_CPF_RAW,
        "leak.actor@gmail.com",
        "98765-4321",
    ):
        assert forbidden not in payload, f"raw value {forbidden!r} leaked into output"


def test_scan_text_handles_long_lines_by_trimming():
    long_line = " " * 300 + f"hidden {VALID_CPF_FORMATTED} pii" + " " * 300
    findings = linter_pii.scan_text("wide.txt", long_line)
    assert findings
    excerpt = findings[0].masked_excerpt
    assert VALID_CPF_FORMATTED not in excerpt
    assert len(excerpt) <= 200


# ── CLI integration ────────────────────────────────────────────────────────


def _run_cli(args: list[str], cwd: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(LINTER_PATH), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=False,
    )


def test_cli_fail_on_match_returns_exit_1(tmp_path):
    sample = tmp_path / "leaky.md"
    sample.write_text(f"Bad: {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    result = _run_cli(
        ["--paths", "*.md", "--root", str(tmp_path), "--fail-on-match"],
        cwd=tmp_path,
    )
    assert result.returncode == 1
    # stdout shows the masked line; raw PII must not appear anywhere.
    assert VALID_CPF_FORMATTED not in (result.stdout + result.stderr)
    assert "111.***.***-35" in result.stdout


def test_cli_zero_exit_when_no_findings(tmp_path):
    sample = tmp_path / "clean.md"
    sample.write_text("no pii here\n", encoding="utf-8")
    result = _run_cli(
        ["--paths", "*.md", "--root", str(tmp_path), "--fail-on-match"],
        cwd=tmp_path,
    )
    assert result.returncode == 0


def test_cli_without_fail_flag_returns_zero_even_with_findings(tmp_path):
    sample = tmp_path / "leaky.md"
    sample.write_text(f"Bad: {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    result = _run_cli(
        ["--paths", "*.md", "--root", str(tmp_path)],
        cwd=tmp_path,
    )
    assert result.returncode == 0
    # Findings are still reported (just informationally).
    assert "111.***.***-35" in result.stdout


def test_cli_rejects_bad_root(tmp_path):
    bogus = tmp_path / "does-not-exist"
    result = _run_cli(["--paths", "*.md", "--root", str(bogus)], cwd=tmp_path)
    assert result.returncode == 2


def test_cli_json_format_emits_records(tmp_path):
    sample = tmp_path / "leaky.md"
    sample.write_text(f"Bad: {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    result = _run_cli(
        ["--paths", "*.md", "--root", str(tmp_path), "--format", "json"],
        cwd=tmp_path,
    )
    assert result.returncode == 0
    records = json.loads(result.stdout)
    assert isinstance(records, list) and records
    assert records[0]["pii_type"] == "cpf"
    assert VALID_CPF_FORMATTED not in result.stdout


# ── Backtracking safety on adversarial input ───────────────────────────────


def test_email_regex_does_not_hang_on_adversarial_input():
    # A common catastrophic-backtracking trigger: long run of dots.
    # The safe-subset regex must complete near-instantly even on 5kB input.
    import time
    adversarial = "a." * 2500 + "@example.com.com.com.com.com"
    start = time.perf_counter()
    findings = linter_pii.scan_text("evil.txt", adversarial)
    elapsed = time.perf_counter() - start
    # Whatever the linter decides about this line, it must not hang.
    assert elapsed < 0.5, f"regex took {elapsed:.3f}s on adversarial input"
    # And if it does match, the match itself must be allowlisted via *@example.com
    assert [f for f in findings if f.pii_type == "email"] == []


# ── Glob skipping ──────────────────────────────────────────────────────────


def test_globs_skip_dot_git_dir(tmp_path):
    git_dir = tmp_path / ".git" / "objects"
    git_dir.mkdir(parents=True)
    (git_dir / "leak.txt").write_text(f"CPF {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    real = tmp_path / "real.md"
    real.write_text("clean\n", encoding="utf-8")
    result = _run_cli(["--paths", "**/*"], cwd=tmp_path)
    assert result.returncode == 0
    assert "111.***.***-35" not in result.stdout


# ── Exclude flag ───────────────────────────────────────────────────────────


def test_exclude_skips_matching_paths(tmp_path):
    (tmp_path / "fixtures").mkdir()
    (tmp_path / "fixtures" / "users.md").write_text(
        f"Fixture CPF: {VALID_CPF_FORMATTED}\n", encoding="utf-8"
    )
    (tmp_path / "real.md").write_text("clean content\n", encoding="utf-8")

    result = _run_cli(
        ["--paths", "**/*.md", "--exclude", "fixtures/**", "--fail-on-match"],
        cwd=tmp_path,
    )
    assert result.returncode == 0
    assert "111.***.***-35" not in result.stdout


def test_exclude_glob_pattern_matches_nested_dirs(tmp_path):
    (tmp_path / "skills" / "pii-masking" / "tests").mkdir(parents=True)
    (tmp_path / "skills" / "pii-masking" / "tests" / "fixture.md").write_text(
        f"Test CPF: {VALID_CPF_FORMATTED}\n", encoding="utf-8"
    )
    result = _run_cli(
        ["--paths", "**/*.md", "--exclude", "**/tests/**", "--fail-on-match"],
        cwd=tmp_path,
    )
    assert result.returncode == 0


def test_multiple_excludes_compose(tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "guide.md").write_text(f"Doc: {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests" / "fixture.md").write_text(f"Test: {VALID_CPF_FORMATTED}\n", encoding="utf-8")
    (tmp_path / "real.md").write_text("clean\n", encoding="utf-8")

    result = _run_cli(
        [
            "--paths", "**/*.md",
            "--exclude", "docs/**",
            "--exclude", "tests/**",
            "--fail-on-match",
        ],
        cwd=tmp_path,
    )
    assert result.returncode == 0


# ── SSH git host allowlist ─────────────────────────────────────────────────


@pytest.mark.parametrize(
    "ssh_url",
    [
        "git@github.com:ekson73/multi-agent-os.git",
        "git@gitlab.com:group/repo.git",
        "git@bitbucket.org:workspace/repo.git",
        "git@codeberg.org:user/project.git",
    ],
)
def test_ssh_git_urls_are_not_flagged_as_email(ssh_url):
    findings = linter_pii.scan_text("README.md", f"Clone: {ssh_url}")
    assert [f for f in findings if f.pii_type == "email"] == []


# ── Domain-suffix allowlist ────────────────────────────────────────────────


@pytest.mark.parametrize(
    "allowlisted_email",
    [
        # RFC 2606 reserved test domains (incl. subdomains)
        "user@example.com",
        "alice@acme-corp.example.com",
        "ops@team.example.org",
        # AI provider noreply convention used in Co-Authored-By footers
        "noreply@anthropic.com",
        "noreply@openai.com",
        "noreply@google.com",
        "noreply@amazon.com",
        "noreply@block.xyz",
        "noreply@alibaba.com",
        "noreply@qodo.ai",
        # GitHub per-user noreply
        "12345+ekson73@users.noreply.github.com",
    ],
)
def test_allowlist_covers_well_known_noreply_and_subdomains(allowlisted_email):
    findings = linter_pii.scan_text("docs.md", f"Contact: {allowlisted_email}")
    assert [f for f in findings if f.pii_type == "email"] == []


def test_allowlist_subdomain_does_not_match_lookalike_suffix():
    # A domain that ENDS in literal `anthropic.com` substring but is NOT a
    # subdomain (e.g. `mailanthropic.com`) MUST NOT inherit the allowlist.
    findings = linter_pii.scan_text(
        "leak.md", "Contact: actor@mailanthropic.com"
    )
    assert len([f for f in findings if f.pii_type == "email"]) == 1


@pytest.mark.parametrize(
    "co_author_line",
    [
        # Anthropic uses both the bare noreply and the per-tool suffix form.
        "Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>",
        "Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>",
    ],
)
def test_anthropic_co_author_line_is_not_flagged(co_author_line):
    """Sanity check for the common commit-footer shape: the email regex
    matches the bracketed address (including the `+tag` form) and the
    allowlist covers it via the `anthropic.com` domain-suffix entry.
    """
    findings = linter_pii.scan_text("COMMIT_MSG", co_author_line)
    assert [f for f in findings if f.pii_type == "email"] == []


# ── Skip-segment scope (regression for worktree-path false-pass) ───────────


def test_skip_segments_apply_to_relative_path_not_absolute(tmp_path):
    """When the repo lives inside a path whose name contains a skip
    segment (e.g., a git worktree under `<repo>/.worktrees/...`), the
    linter must still scan files in that repo. The skip filter is meant
    to ignore segments *inside* the scan tree, not segments in the path
    leading up to the scan root.
    """
    fake_worktree = tmp_path / ".worktrees" / "task-slug"
    fake_worktree.mkdir(parents=True)
    leaky = fake_worktree / "leak.md"
    leaky.write_text(f"CPF {VALID_CPF_FORMATTED}\n", encoding="utf-8")

    result = _run_cli(
        ["--paths", "**/*.md", "--root", str(fake_worktree), "--fail-on-match"],
        cwd=fake_worktree,
    )
    assert result.returncode == 1, (
        "Linter should detect PII inside a path that happens to include "
        f"`.worktrees/`. stdout={result.stdout!r}"
    )
    assert "111.***.***-35" in result.stdout
