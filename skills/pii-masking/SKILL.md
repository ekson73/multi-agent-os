---
name: pii-masking
version: 1.0.0
description: >
  Synchronous CI-time PII detection — CPF Modulo-11 (algorithmic checksum,
  not just regex), RFC 5322 email subset (catastrophic-backtracking-safe),
  E.164-BR phone — with allowlist for developer-artifact false-positives.
  Wires the `ai-governance-linter.yml` step that v1.0 declared with a
  placeholder comment but never implemented. Closes Gap G1 of the OS3PD
  manifesto v4.13.0 (Principle 6 — Respect Wildlife). Output: structured
  records with masked excerpts; raw PII never appears in any log line.
protocols:
  - OS3PD-P6
  - OWASP-A03
agnostic: [os, project]
---

# PII Masking Linter

Synchronous, dependency-free Python module + CLI that scans repository files for three categories of personally identifiable information and emits structured findings whose excerpts are masked at the source.

Closes the empirical gap documented in `protocols/os3pd-manifesto.md` §P6:

> `.github/workflows/ai-governance-linter.yml:46-52` declares the step "Acionar Linter de Segurança (PII) Local" with the placeholder comment `# Aqui poderíamos acoplar o script linter_pii.py que está no repo`. **The slot exists; the implementation does not yet ship.**

## When to Use

- A pull-request workflow needs to fail (or warn) before merge when PII reaches text files.
- A local developer wants a quick sanity scan: `python -m skills.pii_masking.linter_pii --paths "**/*.{py,md,yml,yaml,json,sh}" --fail-on-match`.
- A consumer plugin needs a vendored, zero-dependency detector with deterministic, masked output it can feed into its own audit pipeline.

## What it Detects

| Category | Rule | Anti-false-positive defense |
|---|---|---|
| **CPF** | 11-digit Brazilian taxpayer ID — `DDD.DDD.DDD-DD` or bare. Validated via **Modulo-11 algorithmic checksum**, not just regex shape. | All-same-digit sentinels (`111.111.111-11` etc.) are rejected per Receita Federal anti-fraud rules. Random 11-digit runs that fail the checksum are not reported. |
| **Email** | RFC 5322 SAFE subset — local part with bounded dot-separated segments, domain with at least one dot, TLD between 2-24 chars. | Allowlist: `localhost@127.0.0.1`, `noreply@github.com`, `test@example.com`, `*@example.{com,org,net}`, plus the well-known SSH git remote URL hosts (`git@github.com`, `git@gitlab.com`, `git@bitbucket.org`, `git@codeberg.org`) which match the email shape but are not personal data. The regex is **catastrophic-backtracking-safe** (no nested unbounded quantifiers) — `email@interface` is **not** matched (no valid TLD). |
| **Phone (E.164-BR)** | `+55` country code + 2-digit area code (`11-99`) + 8 or 9 digit number, with optional `.`/`-`/space/parens separators. | Negative lookarounds on both sides reject runs embedded in longer digit sequences (which usually disguise CPFs). |

## Output Contract

Findings are emitted as one record per detection:

```json
{
  "file": "path/to/scanned/file.py",
  "line": 42,
  "pii_type": "cpf|email|phone_br",
  "masked_excerpt": "user code mentions 529.***.***-99 in this line"
}
```

**Mandatory invariants** (enforced by tests):

1. The raw PII value **never** appears in `stdout`, `stderr`, or any record field.
2. Excerpts longer than ~200 chars are trimmed around the match with ellipses.
3. Masks preserve enough structure for a human to confirm a true positive without re-exposing the value:
   - CPF → `529.***.***-99`
   - Email → `j***@gmail.com`
   - Phone → `+55 11 ****-****`

## CLI

```bash
python -m skills.pii_masking.linter_pii \
    --paths "**/*.py" \
    --paths "**/*.md" \
    --paths "**/*.{yml,yaml,json,sh}" \
    --root . \
    --format text \
    --fail-on-match
```

| Flag | Effect |
|---|---|
| `--paths GLOB` | Glob pattern relative to `--root`. Repeat for multiple patterns. Required. |
| `--exclude GLOB` | Glob pattern (relative to `--root`) to skip during scanning. Repeatable. Typical workflow excludes: `**/tests/**`, `**/fixtures/**`, `docs/**`. |
| `--root DIR` | Repository root (default: cwd). Absolute glob patterns are rejected — scope is the repo. |
| `--format text\|json` | Default text. JSON for machine consumption. |
| `--fail-on-match` | Exit code 1 when any PII is detected. Without this flag, the linter is informational. |

**Exit codes**: `0` clean (or matches without `--fail-on-match`), `1` matches with `--fail-on-match`, `2` invocation/argument error.

**Skipped paths**: `.git/`, `.worktrees/`, `node_modules/`, `__pycache__/` are always excluded regardless of glob.

## CI Wiring

`.github/workflows/ai-governance-linter.yml` invokes the linter as a job step on every pull-request `synchronize`. The wiring step is SHA-pinned per the convention established by `supply-chain-sentinel.yml` and `ontology-validation.yml`. See that file for the canonical invocation.

The job runs `--fail-on-match` so PII detection blocks merges. The allowlist absorbs developer-artifact noise; if a legitimate detection is a false positive that the allowlist does not cover, prefer extending the allowlist over silencing the linter.

## Sister Skills and Cross-References

| Concern | Where to look |
|---|---|
| Why this skill exists at all | `protocols/os3pd-manifesto.md` §P6 (Gap G1) |
| Companion ontology (formal model) | `ontology/os3pd-v4.13.0.ttl` `:containsCleartextPII` property |
| Enforcement matrix entry | `ontology/os3pd-enforcement-matrix.jsonld` policy `os3pd:Principio_6_RespectWildlife` |
| Verbosity axis (complementary) | `skills/response-compression/SKILL.md` |
| FinOps routing axis (planned) | `skills/slm-routing/SKILL.md` (Phase C, Gap G3) |
| Worktree governance | `skills/worktree-policy/SKILL.md`, hierarchical-merge-protocol |

## Local Verification

```bash
cd skills/pii-masking
python -m pytest tests/ -v
python -m pytest tests/ --cov=linter_pii --cov-report=term
```

Coverage target: ≥ 85% on `linter_pii.py` (anti-theater check — the module is small enough that high coverage is achievable, and false positives there matter for governance credibility).

## What this Skill is NOT

- ❌ A runtime proxy. It is **synchronous, CI-time, file-based**. The runtime proxy (Phase D of the OS3PD ingestion plan) is **deferred** until ≥ 3 documented runtime-PII incidents prove this CI-time linter insufficient.
- ❌ A full RFC 5322 parser. The email regex is a **safe subset** — it intentionally rejects exotic-but-legal addresses (quoted local parts, IP-literal domains) to keep the implementation tight and catastrophic-backtracking-safe.
- ❌ A GDPR / LGPD compliance certifier. Detection of these three formats reduces exposure risk, but a compliance program needs scoping, retention, and Data Protection Impact Assessment work this linter does not perform.
