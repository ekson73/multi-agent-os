"""Tests for ref-claim-verify (fixtures build a throwaway git repo; no network)."""
import subprocess
import pytest
import ref_claim_verify as rcv


def git(repo, *a):
    subprocess.run(["git", "-C", str(repo), "-c", "user.email=t@example.org", "-c", "user.name=t",
                    "-c", "commit.gpgsign=false", *a], check=True, capture_output=True)


@pytest.fixture()
def repo(tmp_path):
    git(tmp_path, "init", "-q", "-b", "main")
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs/guide.md").write_text("# Guide\n\n## 4.1 — Intake\n\n### §4.2 Gate\n")
    (tmp_path / "docs/flat.md").write_text("just prose, no headings\n")
    (tmp_path / "PROTO.md").write_text("## [C04] Worktree Protocol\n\n> **Versão**: 3.0.0 (2026-01-21)\n")
    (tmp_path / "skill.md").write_text("---\nname: x\nversion: 1.2.0\n---\n")
    git(tmp_path, "add", "-A")
    git(tmp_path, "commit", "-q", "-m", "base")
    return tmp_path


def claims(text, repo, refs=("HEAD",), diff=False):
    return rcv.run(text, str(repo), list(refs), diff)["claims"]


def test_path_verified_and_missing(repo):
    c = claims("see `docs/guide.md` and `docs/nope.md`", repo)
    assert [(x["target"], x["verdict"]) for x in c] == [("docs/guide.md", "VERIFIED"), ("docs/nope.md", "MISMATCH")]


def test_path_added_only_at_head_needs_both_refs(repo):
    git(repo, "checkout", "-q", "-b", "feat")
    (repo / "new.md").write_text("x\n")
    git(repo, "add", "-A"); git(repo, "commit", "-q", "-m", "add")
    assert claims("`new.md`", repo, ("main",))[0]["verdict"] == "MISMATCH"
    assert claims("`new.md`", repo, ("main", "feat"))[0]["verdict"] == "VERIFIED"


def test_section_verified_mismatch_unresolved(repo):
    c = claims("`docs/guide.md` §4.1, `docs/guide.md` §9.9, `docs/flat.md` §1", repo)
    assert [x["verdict"] for x in c] == ["VERIFIED", "MISMATCH", "UNRESOLVED"]


def test_version_mismatch_is_the_original_defect(repo):
    c = claims("Bumped [C04] v3.1.0 in the rules", repo)[0]
    assert c["verdict"] == "MISMATCH" and c["declared"] == ["3.0.0"]


def test_version_verified_by_bracket_and_by_path(repo):
    c = claims("[C04] v3.0.0 and `skill.md` v1.2.0", repo)
    assert [x["verdict"] for x in c] == ["VERIFIED", "VERIFIED"]


def test_version_unresolved_when_no_declared_version(repo):
    assert claims("`docs/guide.md` v9.9.9", repo)[0]["verdict"] == "UNRESOLVED"


def test_markdown_links_and_urls_are_not_claims(repo):
    assert claims("[doc](https://x.io/a.md) and `https://x.io/b.md`", repo) == []


def test_unsafe_paths_are_unresolved_not_read(repo):
    c = claims("`../../etc/passwd.md`", repo)
    assert c and c[0]["verdict"] == "UNRESOLVED"


# Synthetic PII is assembled at runtime so no PII-shaped literal sits in the source tree.
EMAIL = "ana.silva" + "@" + "corp" + ".io"
CPF = "111.444" + ".777-35"          # standard public test checksum, not a real person
PHONE = "+55 11 99999" + "-8888"


def test_excerpt_masks_pii_and_long_tokens(repo):
    token = "A" * 40
    c = claims(f"`docs/guide.md` owner {EMAIL} cpf {CPF} key {token}", repo)[0]
    ex = c["excerpt"]
    assert EMAIL not in ex and CPF not in ex and token not in ex


def test_diff_mode_scans_only_added_lines(repo):
    diff = "+++ b/x.md\n-`docs/old.md`\n context `docs/ctx.md`\n+added `docs/guide.md`\n"
    c = claims(diff, repo, diff=True)
    assert [x["target"] for x in c] == ["docs/guide.md"]


def test_no_claims_is_flagged_not_a_pass(repo):
    r = rcv.run("plain text", str(repo), ["HEAD"])
    assert r["claims"] == [] and "NOT a pass" in r["note"] and r["exit"] == 0


def test_exit_codes(repo):
    run = lambda t: rcv.run(t, str(repo), ["HEAD"])["exit"]
    assert run("`docs/guide.md`") == 0
    assert run("`docs/flat.md` §1") == 2
    assert run("`docs/nope.md` `docs/flat.md` §1") == 3


def test_invalid_ref_errors_and_cli_exit_1(repo, tmp_path):
    with pytest.raises(ValueError):
        rcv.run("x", str(repo), ["--evil"])
    f = tmp_path / "in.txt"; f.write_text("x")
    assert rcv.main([str(f), "--repo", str(repo), "--ref", "does-not-exist"]) == 1


def test_fallback_masking_still_hides_cpf_phone_email(monkeypatch):
    monkeypatch.setattr(rcv, "_PII", None)
    out = rcv.mask(f"{EMAIL} {CPF} {PHONE}")
    assert EMAIL not in out and CPF not in out and "99999-8888" not in out


def test_report_declares_masking_mode(repo):
    assert rcv.run("x", str(repo), ["HEAD"])["masking"] in {"pii-masking", "fallback"}
    assert rcv.MASKING_MODE == "pii-masking"  # the shared linter really loaded


def test_backticked_bracket_anchor_is_parsed_like_the_real_pr(repo):
    c = claims("Full doctrine: `CLAUDE.md` `[C04]` v3.1.0 · more", repo)
    assert [(x["kind"], x["target"], x["verdict"]) for x in c if x["kind"] == "VERSION"] == [("VERSION", "[C04]", "MISMATCH")]


def test_anchor_in_prose_not_heading_stays_unresolved(repo):
    (repo / "notes.md").write_text("see [ZZ9] for details\n\nVersion: 7.7.7\n")
    git(repo, "add", "-A"); git(repo, "commit", "-q", "-m", "n")
    assert claims("[ZZ9] v7.7.7", repo)[0]["verdict"] == "UNRESOLVED"


def test_unparsed_version_mentions_are_counted_not_dropped(repo):
    r = rcv.run("upgrade to v2.5.1 soon", str(repo), ["HEAD"])
    assert r["unparsed_version_mentions"] == 1 and "review manually" in r["note"]


# ── regressions from the independent cross-vendor review (each was a real defect) ──
def _commit(repo, files):
    for name, body in files.items():
        (repo / name).write_text(body)
    git(repo, "add", "-A"); git(repo, "commit", "-q", "-m", "fixture")


def test_version_does_not_borrow_the_next_sections_declaration(repo):
    _commit(repo, {"two.md": "## [AA]\nVersion: 1.0.0\n## [BB]\nVersion: 9.9.9\n"})
    assert claims("[AA] v9.9.9", repo)[0]["verdict"] == "MISMATCH"
    assert claims("[AA] v1.0.0", repo)[0]["verdict"] == "VERIFIED"


def test_fenced_example_is_not_an_authoritative_declaration(repo):
    _commit(repo, {"x.md": "---\nversion: 1.0.0\n---\n\n```yaml\nversion: 9.9.9\n```\n"})
    assert claims("`x.md` v9.9.9", repo)[0]["verdict"] == "MISMATCH"
    assert claims("`x.md` v1.0.0", repo)[0]["verdict"] == "VERIFIED"


def test_conflicting_declarations_are_unresolved_not_verified(repo):
    _commit(repo, {"y.md": "Version: 1.0.0\n\nVersion: 2.0.0\n"})
    assert claims("`y.md` v2.0.0", repo)[0]["verdict"] == "UNRESOLVED"


def test_version_suffix_and_precision_are_compared_exactly(repo):
    _commit(repo, {"z.md": "Version: 1.2.3-rc.1\n", "w.md": "Version: 1.2.9\n"})
    assert claims("`z.md` v1.2.3", repo)[0]["verdict"] == "MISMATCH"
    assert claims("`z.md` v1.2.3-rc.1", repo)[0]["verdict"] == "VERIFIED"
    assert claims("`w.md` v1.2", repo)[0]["verdict"] == "MISMATCH"


def test_code_comment_is_not_a_markdown_heading(repo):
    _commit(repo, {"c.md": "```python\n# 4.1 example comment\n```\n"})
    assert claims("`c.md` §4.1", repo)[0]["verdict"] != "VERIFIED"


def test_every_displayed_string_is_masked_including_target_and_intl_phone(repo):
    intl = "+1 (415) 555" + "-2671"
    c = claims(f"`docs/{CPF}.md` owner {intl}", repo)[0]
    blob_out = " ".join(str(c[k]) for k in ("target", "excerpt", "evidence", "detail"))
    assert CPF not in blob_out and "555-2671" not in blob_out


def test_adversarial_whitespace_line_is_bounded(repo):
    import time
    for text in ("[X]" + " " * 200000 + "!", "`a.md`" + " " * 200000 + "§", "`a.md` " + "-" * 200000):
        t0 = time.time(); rcv.run(text, str(repo), ["HEAD"])
        assert time.time() - t0 < 1.5


# ── round-2 regressions (second independent review) ──
def test_shorter_fence_inside_longer_fence_does_not_close_it(repo):
    _commit(repo, {"f.md": "````\n```\nVersion: 8.6.4\n````\n"})
    assert claims("`f.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_setext_heading_is_a_section_boundary(repo):
    _commit(repo, {"s.md": "## [ZX]\nOther artifact\n--------------\nVersion: 8.6.4\n"})
    assert claims("[ZX] v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_over_long_lines_are_skipped_never_truncated_into_a_claim(repo):
    _commit(repo, {"l.md": "Version: 2.7.4\n"})
    pad = "`l.md` v2.7.4"
    line = pad + "x" * (rcv.MAX_LINE - len(pad)) + "-rc.2"
    r = rcv.run(line, str(repo), ["HEAD"])
    assert r["claims"] == [] and r["skipped_long_lines"] == 1 and "skipped" in r["note"]


def test_html_comment_is_not_a_heading_or_declaration(repo):
    _commit(repo, {"h.md": "<!--\n# 8.6 hidden comment\nVersion: 8.6.4\n-->\n"})
    assert claims("`h.md` §8.6", repo)[0]["verdict"] != "VERIFIED"
    assert claims("`h.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_declared_field_and_whole_report_are_masked(repo):
    import json
    secret = "S" * 40
    _commit(repo, {"d.md": f"Version: 2.7.4+{secret}\n"})
    r = rcv.run("`d.md` v2.7.4", str(repo), ["HEAD"])
    assert secret not in json.dumps(r)


def test_duplicate_anchor_headings_with_conflicting_versions_are_unresolved(repo):
    _commit(repo, {"dup.md": "## [ZX]\nVersion: 8.6.4\n## [ZX]\nVersion: 9.0.0\n"})
    assert claims("[ZX] v8.6.4", repo)[0]["verdict"] == "UNRESOLVED"


def test_files_that_only_mention_the_anchor_do_not_trip_the_overflow_cap(repo):
    files = {f"m{i}.md": "prose that cites [QQ1] in passing\n" for i in range(rcv.ANCHOR_FILE_CAP + 10)}
    files["real.md"] = "## [QQ1] Real\nVersion: 4.5.6\n"
    _commit(repo, files)
    assert claims("[QQ1] v4.5.6", repo)[0]["verdict"] == "VERIFIED"


# ── round-3 regressions ──
def test_indented_closer_does_not_close_a_fence(repo):
    _commit(repo, {"i.md": "```yaml\n    ```\nVersion: 8.6.4\n```\n"})
    assert claims("`i.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_fence_inside_blockquote_is_code(repo):
    _commit(repo, {"q.md": "> ```yaml\n> Version: 8.6.4\n> ```\n"})
    assert claims("`q.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_blockquote_declaration_outside_a_fence_still_counts(repo):
    _commit(repo, {"b.md": "## [BQ]\n\n> **Vers\u00e3o**: 1.0.0\n"})
    assert claims("[BQ] v1.0.0", repo)[0]["verdict"] == "VERIFIED"


def test_unterminated_frontmatter_is_not_authoritative(repo):
    _commit(repo, {"u.md": "---\nversion: 8.6.4\nname: unterminated\n"})
    assert claims("`u.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_version_with_extra_components_is_not_truncated(repo):
    _commit(repo, {"v.md": "Version: 8.6.4.2\n"})
    assert claims("`v.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_conflicting_declaration_beyond_old_14_line_window_is_seen(repo):
    _commit(repo, {"w2.md": "## [AA]\nVersion: 8.6.4\n" + "\n" * 14 + "Version: 9.0.0\n"})
    assert claims("[AA] v8.6.4", repo)[0]["verdict"] == "UNRESOLVED"


def test_nested_html_comment_is_ambiguous_not_verified(repo):
    _commit(repo, {"n.md": "<!-- outer\n<!-- inner -->\nVersion: 8.6.4\n-->\n"})
    assert claims("`n.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_cli_usage_errors_do_not_echo_pii(capsys):
    email = "alice" + "@" + "example" + ".test"
    with pytest.raises(SystemExit) as exc:
        rcv.main([f"--unknown={email}"])
    err = capsys.readouterr().err
    assert exc.value.code == 1 and email not in err and "unrecognized" in err


def test_comment_marker_quoted_in_inline_code_is_not_a_comment(repo):
    _commit(repo, {"ic.md": "## [IC] Title\n\nUse `<!--` and `-->` markers.\n\n> **Versão**: 2.0.0\n"})
    assert claims("[IC] v2.0.0", repo)[0]["verdict"] == "VERIFIED"


# ── round-4 regressions ──
@pytest.mark.parametrize("body", [
    "<!-- outer <!-- inner -->\nVersion: 8.6.4\n-->\n",
    "<!-- outer\n`<!--`\n-->\nVersion: 8.6.4\n",
    "Version: 8.6.4\n<!--\nVersion: 9.0.0\n",
    "Version: 8.6.4\n~~~yaml\nVersion: 9.0.0\n",
])
def test_unclosed_or_nested_structures_never_verify(repo, body):
    _commit(repo, {"amb.md": body})
    assert claims("`amb.md` v8.6.4", repo)[0]["verdict"] == "UNRESOLVED"


def test_multiline_inline_code_span_is_not_a_declaration(repo):
    _commit(repo, {"sp.md": "``example\nVersion: 8.6.4\n``\n"})
    assert claims("`sp.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_table_row_is_not_authoritative_metadata(repo):
    _commit(repo, {"t.md": "Version: 8.6.4 | example\n--- | ---\nold | new\n"})
    assert claims("`t.md` v8.6.4", repo)[0]["verdict"] != "VERIFIED"


def test_common_credential_shapes_are_masked_in_every_field(repo):
    import json
    aws = "AKIA" + "EXAMPLEKEY1234567"            # assembled at runtime: no secret-shaped literal in source
    pw = "hunter2" * 2
    kv = "pass" + "word" + ": " + pw
    r = rcv.run(f"`x.md` AWS_ACCESS_KEY_ID={aws} {kv}", str(repo), ["HEAD"])
    out = json.dumps(r)
    assert aws not in out and pw not in out
