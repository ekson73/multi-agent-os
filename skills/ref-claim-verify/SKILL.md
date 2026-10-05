---
name: ref-claim-verify
description: |
  Use to check the cross-reference CLAIMS a doc, PR body or diff makes about other
  artifacts against the real source — before trusting them. Extracts three claim kinds
  (a cited PATH, a SECTION "path §4.1", a VERSION "[ID] v1.2.3" / "`file` v1.2.3") and
  verifies each against git objects (read-only, no checkout, no network): does the path
  exist at the base or head ref, does a heading carry that section token, does the
  artifact's own declared version match the claim. Verdicts are VERIFIED / MISMATCH /
  UNRESOLVED — UNRESOLVED is never a pass. Output excerpts are PII/secret-masked by
  reusing `pii-masking`. Exists because review bots routinely approve a doc line such as
  "bumped [X] v3.1.0" without opening X, while X actually declares v3.0.0. NOT a link
  checker for URLs, NOT a spell/style linter, NOT a substitute for a human or
  cross-vendor review of the CHANGE itself — it only checks that the cited facts exist.
  Triggers - "verify the references in this PR", "check the version/section/path claims",
  "do the cited files and versions exist", "bots approved but did anyone check the
  citation", "verify cross-references before merge".
version: 1.0.0
---

# ref-claim-verify

## Purpose

Documentation and PR descriptions *assert* facts about other artifacts. Automated reviewers
tend to judge whether a sentence reads as reasonable, not whether the thing it cites says
what it claims. `ref-claim-verify` closes that gap mechanically: it turns each citation into
a check against the repository's own git objects and reports exactly what the source says.

It is **read-only, stdlib-only, offline**. The input text is treated as DATA: it is never
executed and nothing in it is followed as an instruction.

## When to use

- A PR changes docs/rules/specs that cite other files, sections or versions.
- A bot or reviewer approved a documentation PR and you want evidence the citations hold.
- Before merging a PR whose body says "bumped X to vN".

## When NOT to use

- Checking URLs/hyperlinks (this checks repo-local citations only).
- Judging whether the change is *correct* — it only verifies the cited facts exist.
- A claim about an artifact in a repo you cannot read (it reports UNRESOLVED, not a pass).

## Usage

```bash
# a document
python3 skills/ref-claim-verify/ref_claim_verify.py README.md --repo . --ref HEAD

# a PR: pass BASE and HEAD — a path the PR adds exists only at head
gh pr diff 123 | python3 skills/ref-claim-verify/ref_claim_verify.py --diff \
    --repo . --ref origin/main --ref pr-head

# the artifact lives in ANOTHER repo: point --repo at it
python3 skills/ref-claim-verify/ref_claim_verify.py body.md --repo /path/to/other --ref origin/main --json
```

| Flag | Meaning |
|---|---|
| `file` / `-` | text to scan (default stdin) |
| `--repo DIR` | repository whose objects answer the claims (default `.`) |
| `--ref REF` | commit-ish to check against; repeatable; a claim holds if it holds at ANY ref |
| `--diff` | input is a unified diff; only added (`+`) lines are scanned |
| `--json` | machine-readable report |

## Claim kinds and what "verified" means

| Kind | Recognised form | VERIFIED when |
|---|---|---|
| PATH | `` `dir/file.ext` `` | the path exists at one of the refs |
| SECTION | `` `file.md` §4.1 `` | a heading in that file carries token `4.1` |
| VERSION | `` [ID] v1.2.3 `` or `` `file` v1.2.3 `` | the artifact's own declared version (frontmatter `version:` or a `Version:`/`Versão:` line) equals the claim |

For a `[ID]` anchor the declared version is read only from the lines right after a **heading
that carries the anchor, up to the next heading** — a declaration belongs to its own section and
is never borrowed from the following one. A bare mention of the anchor in prose is ignored on purpose.
Versions are compared **exactly** (`1.2.3` ≠ `1.2.3-rc.1`, `1.2` ≠ `1.2.9`). Fenced code blocks (CommonMark: same character, closer at least as long as the opener and indented at most 3 spaces, also inside blockquotes), HTML comments (inline-code mentions of `<!--` are not comments)
and Setext/thematic-break boundaries are respected when looking for declarations or headings; the section runs to its real boundary, with no fixed line window; YAML frontmatter, when present, is
the authoritative declaration (an unterminated frontmatter block is not authoritative). Version tokens must be complete (`8.6.4.2` never verifies `v8.6.4`). Nested HTML comments make a file's structure ambiguous -> `UNRESOLVED`. So do: a backtick run that never closes before its paragraph ends (it could hide a declaration), a heading or fence inside an open code span, an unterminated raw HTML block, a git-blob line over 1,000,000 characters (lines below that are parsed in linear time — real governance docs carry lines far above 4000), and a backslash-escaped backtick is literal text (not a span delimiter) outside code spans, and a frontmatter `version:` whose WHOLE value is not a clean version (`"8.6.4 other"`, a duplicate or empty key). Raw HTML is only partly emulated: `<pre>`/`<script>`/`<style>`/`<textarea>` (until an exact closer), processing instructions, declarations and CDATA are raw blocks and skipped; any other line that can start HTML (block tags, standalone or malformed tags, a tag left open at the line break, text after a block comment's closer) is *tainted* up to the next blank line or the end of its blockquote, and a tainted line that looks like metadata (a heading, a thematic/setext line, a `Version:` declaration) makes the answer `UNRESOLVED` — never a guessed pass. Autolinks (`<https://…>`) and code spans are not HTML; an empty `##` heading is a heading and closes its section. Two different declarations in one file, or the same anchor heading declaring different versions, are `UNRESOLVED`, never a pass.
When refs differ (base vs head of a PR) a claim is verified if ANY ref declares it unambiguously.

## Verdicts and exit codes

- `VERIFIED` — checked and true. `MISMATCH` — checked and false (the evidence column says what the source declares).
- `UNRESOLVED` — the instrument could not look (no numbered headings to test a section against, no declared version, unsafe/out-of-repo path). **Never treat as a pass.**
- Exit `0` all verified (or no claims) · `3` any MISMATCH · `2` only UNRESOLVED · `1` error.
- If nothing was extracted the report says so and says it is **not a pass of anything**; version-like mentions that are not tied to an anchor are counted in `unparsed_version_mentions` so silence cannot hide a recall gap.

## Guarantees

1. **Read-only**: only `git rev-parse`, `git show`, `git cat-file`, `git grep`; list-form subprocess, no shell.
2. **Input validation**: refs starting with `-` are rejected; paths with `..`, absolute or `~` prefixes are never read.
3. **PII/secret protection**: every displayed string (excerpt, target, detail, evidence) goes through `skills/pii-masking` (CPF, email, BR phone) **and** a second coarse pass (international phone shapes, CPF, email); any 32+ char token becomes `[TOKEN]`, and common credential shapes (AWS key ids, `gh*_` / `xox*` / `sk-` tokens, JWTs, `Authorization: Bearer …`, `*secret|token|pass(word)|pwd|passphrase|private_key|credentials|senha|api_key = value` incl. `=>`, `--password …`, URL-embedded `user:pass@`, `<password>…</password>`) become `[CREDENTIAL]`/`[REDACTED]` (best-effort, not exhaustive); masking only ever looks at the first 1,000 characters of a string, so its cost is bounded. If `pii-masking` cannot load, only the coarse pass runs and the report declares `masking: fallback` — it never degrades to raw text. Raw values stay internal to the lookups.
4. **No false comfort**: absence of evidence is UNRESOLVED or MISMATCH, never VERIFIED.
5. **Bounded work**: lines longer than 4000 characters are **skipped, not truncated** (a truncated line could mint a wrong claim) and are counted in `skipped_long_lines`; separators in the patterns are unambiguous (no quadratic backtracking).

## Limits (honest)

- Recognises backtick-quoted paths and the version/section forms above; free-prose references ("see the guide") are not extracted.
- A SECTION is matched against real Markdown (ATX `#`) headings outside code fences only.
- It checks one repo per run; cross-repo claims need a second run with the other `--repo`.
- Markdown is parsed heuristically (no full CommonMark engine). Seven rounds of independent cross-vendor adversarial review found 42 parser/masking edge cases (24 in rounds 1-4, 6 in round 5, 4 in round 6, 8 in round 7 and the late round-6 items); the HTML long tail was closed structurally (ambiguity ⇒ `UNRESOLVED`) instead of by emulating CommonMark; all were fixed and pinned by regression tests, but the residual risk is non-zero. The design rule is conservative: any structural ambiguity yields `UNRESOLVED`, never `VERIFIED` — but `VERIFIED` is strong evidence the cited fact exists, not a proof; keep a human or cross-vendor review of the change itself.

## Composes (does not duplicate)

`pii-masking` (masking), `bot-finding-arbiter` / `routed-pr-review` (review adjudication — this tool
supplies the missing "do the citations hold" evidence), `corpus-firing-audit` (liveness, a different question).

## Origin

Generalised from a real miss: a documentation PR cited an artifact's version that no ref declared; two
automated reviewers approved it and only an independent cross-vendor review plus a manual source check
caught it. This tool turns that manual check into a repeatable one.

## Related

- `skills/pii-masking/SKILL.md` · `skills/bot-finding-arbiter/SKILL.md` · `skills/atomize-and-route/SKILL.md`
