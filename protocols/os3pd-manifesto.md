<!-- ═══════════════════════════════════════════════════════════════════════
     CANONICAL SOURCE
     ═══════════════════════════════════════════════════════════════════════
     Repository: https://github.com/ekson73/multi-agent-os
     Path: protocols/os3pd-manifesto.md
     Version: v4.13.0

     TTL POLICY:
     Type: Manifesto/Standard
     TTL: 180 days
     Next Review: 2026-11-17

     CONSUMPTION INSTRUCTIONS:
     When duplicating to consumer projects, add a CONSUMER HEADER with:
     - SOURCE OF TRUTH pointing back to this file (Canonical URL)
     - Last sync date (ISO 8601)
     - Calculated expiration date (sync_date + TTL)
     - Status indicator (FRESH/EXPIRING/EXPIRED)
     - Actions by state (what to do when FRESH/EXPIRING/EXPIRED)

     See: docs/framework-consumption.md for full template
     ═══════════════════════════════════════════════════════════════════════ -->

# OS3PD Manifesto — Ontology of Symbiotic Software Systems & Preservation of Digital Artifacts

**Version**: 4.13.0 | **Updated**: 2026-05-21 | **Status**: doc-only (Phase A of a 3-phase ingestion)

## Scope of this document

**This manifesto documents existing behavior** in `multi-agent-os@HEAD`. It does **not** introduce new runtime code or enforcement; each of the 7 principles below maps to one or more already-merged surfaces, cited with `file:line` references. The companion machine-readable artifacts (`ontology/os3pd-v4.13.0.ttl` + `ontology/os3pd-enforcement-matrix.jsonld`) restate the same mappings in OWL/RDF + JSON-LD for cross-vendor (AAIF) interoperability.

**Out of scope for v4.13.0** (tracked separately in the ingestion plan):

- Implementation of `linter_pii.py` (P6 gap G1 — captured by Phase B)
- SLM-routing decision matrix (P5 extension G3 — captured by Phase C)
- Runtime proxy gateway with PII masking + semantic cache + SLM routing (Phase D — deferred until ≥ 3 documented runtime-PII incidents post-Phase-B)

## Supreme Directive — The Boy Scout Rule

> "Regardless of whether the actor is a Human Actor or an AI Agent, every transaction in a repository, prompt, context window, or digital archive shall leave the artifact in a state that is **semantically cleaner, safer, more efficient, and more structured** than the one found."

## The 7 Pragmatic Principles

### P1 — Plan Ahead and Prepare (Preventive Input Engineering)

Security boundaries, context limits, and cognitive axes operate deterministically **before** model invocation.

**Existing surface**:

- `hooks/hooks.json:18-31` — `PreToolUse(Task)` matcher chains `plugin-scripts/pre-delegate.sh` + `plugin-scripts/governance/token-budget-gate.sh` on every subagent spawn. Hooks fire before tool execution, enforcing pre-invocation discipline.
- `plugin-scripts/pre-delegate.sh` — captures provider context (ticket / VCS / secrets / observability) before delegation.

### P2 — Travel and Camp on Durable Surfaces (Isolated, Ephemeral Execution)

Production infrastructure and original-binary archives are immutable zones; AI-generated code lives only in sandboxes until validated by a human.

**Existing surface**:

- `plugin-scripts/governance/worktree-gate.sh:115-137` — `RF03` blocks any commit when the current branch is `main` or `master` (unless `GOVERNANCE_OVERRIDE=1` is set with explicit rationale per the auto-loaded `pr-review-protocol.md` v1.1.0). Combined with `RF01` (branch creation) and `RF02` (checkout enforcement) at earlier lines of the same hook.
- `skills/worktree-policy/SKILL.md` — "WORKTREE IS MANDATORY" policy.
- `protocols/hierarchical-merge-protocol.md` — branches merge to a parent, not directly to `main`.

### P3 — Dispose of Waste Properly (Secret Scanning & Cleanup)

Automated secret scanning + dead-code purge + lockfile integrity + supply-chain scoring prevent leakage and silent regressions.

**Existing surface**:

- `.github/workflows/supply-chain-sentinel.yml:35-69` — Trivy `fs` scan (vuln + secret + misconfig).
- `.github/workflows/supply-chain-sentinel.yml:70-96` — `pip-audit` against the pinned MCP-hub `requirements.txt`.
- `.github/workflows/supply-chain-sentinel.yml:98-112` — gitleaks full-history secret scan.
- `.github/workflows/supply-chain-sentinel.yml:114-138` — lockfile integrity (empty file = fail).
- `.github/workflows/supply-chain-sentinel.yml:140-166` — OpenSSF Scorecard SARIF upload.

### P4 — Leave What You Find (Incremental Evolution with Architectural Alignment)

Generative AI must respect existing contracts and architectural signatures.

**Existing surface**:

- `sentinel/detection_rules.md` — 10 detection rules (`RULE-001` Loop Detection through `RULE-010` Retry Storm) catch drift introduced by sub-agents.
- `skills/anti-conflict/SKILL.md` — file-conflict prevention with worktrees + lock files.
- `skills/hierarchical-merge/SKILL.md` — parent-merge convergence rules.

### P5 — Minimize Campfire Impacts (FinOps & Green-IT Context Optimization)

Token consumption and GPU cycles are treated as scarce financial + environmental resources.

**Existing surface (verbosity axis — what is said)**:

- `skills/response-compression/SKILL.md:36-48` — role-based 4-profile matrix (`none` / `lite` / `full` / `ultra`).
- `plugin-scripts/governance/token-budget-gate.sh:46` — `RULE-009` token-bloat advisory at the ~ 1000-token threshold.
- `sentinel/config.json:152-158` — `RULE-009` registration in the detection-rule registry.

**Gap (routing axis — where it is sent)**: there is currently **no declarative primitive** mapping a task to "route to local SLM vs remote LLM". Captured by Phase C of this manifesto's ingestion plan as `skills/slm-routing/SKILL.md`.

### P6 — Respect Wildlife (Legal Shielding & Ecosystem Compliance)

User data, regulatory compliance (GDPR / LGPD / AI Act), and software-licensing rights are the protected fauna of the digital ecosystem.

**Existing surface**:

- `.github/workflows/ai-governance-linter.yml:46-52` — declares the step "Acionar Linter de Segurança (PII) Local" with the placeholder comment `# Aqui poderíamos acoplar o script linter_pii.py que está no repo`. **The slot exists; the implementation does not yet ship.**

**Gap (G1)**: a Python module performing **synchronous** PII detection (CPF Modulo-11 checksum, RFC 5322 email subset, E.164-BR phone) with a code-context allowlist (`localhost@127.0.0.1`, `noreply@github.com`, `test@example.com`, `*@example.{com,org,net}`) to prevent false-positives on developer artifacts. Captured by Phase B of this manifesto's ingestion plan as `skills/pii-masking/`.

### P7 — Be Considerate of Other Visitors (Explainability & Semantic Interoperability)

Systems built or assisted by AI must be auditable + intelligible by both humans and future software systems (FAIR: Findable, Accessible, Interoperable, Reusable).

**Existing surface**:

- `skills/ttl-policy/SKILL.md` — content-freshness vocabulary (`FRESH` / `EXPIRING` / `EXPIRED`) + PROV-tag pattern.
- `protocols/hierarchical-merge-protocol.md:1-22` — TTL header with canonical source URL + ISO-8601 dates (this manifesto follows the same convention; see the header above).
- **This document** + `ontology/os3pd-v4.13.0.ttl` + `ontology/os3pd-enforcement-matrix.jsonld` — the new FAIR-compliant ontology layer.

## Machine-readable mirrors

| File | Format | Purpose |
|---|---|---|
| `ontology/os3pd-v4.13.0.ttl` | OWL / Turtle, W3C-standard prefixes | Validated by `rdflib.Graph().parse()` in `tests/test_ontology_parse.py` |
| `ontology/os3pd-enforcement-matrix.jsonld` | JSON-LD, `$schema: https://json-schema.org/draft/2020-12/schema` | Validated by `jsonschema` in the same test |
| `.github/workflows/ontology-validation.yml` | GitHub Actions workflow | Runs the test on push/PR/manual dispatch |

## What this manifesto is NOT

- ❌ **Not a new rule engine.** The 7 policies in the enforcement matrix are **alias-views** over existing hooks/workflows/skills, not parallel measurement plumbing.
- ❌ **Not a runtime KPI calculator.** Terms like TRE / ECH / IEC / CSF (if used downstream) MUST be alias-derivations over the existing `sentinel/config.json:240-277` `health_score` model. No hardcoded numerators of the `bugs_fixed / (bugs_introduced + 1)` shape — that pattern is governance theater per the same family as `RULE-006` (Agent Mismatch) and `RULE-009` (Token Bloat).
- ❌ **Not a final framework.** Versions later than `v4.13.0` will refine prefixes, add policies, or deprecate them via the standard `[C07b]` SemVer + changelog protocol.

## Why version `4.13.0` (not `4.12.0`)

An upstream proposal self-labeled `v4.12.0-LTS`. This repository's first incorporation is `v4.13.0` — a `MINOR` bump per `[C07b]` — because the upstream submission was rejected for **5 structural defects**:

1. Hardcoded `bugs_fixed / bugs_introduced` numerator in CI (rubber-stamp gate).
2. Single-line Python source (newline-collapsed → `SyntaxError`).
3. Single-line Dockerfile (newline-collapsed → parse failure).
4. Single-line YAML (newline-collapsed → parse failure).
5. Turtle `@prefix owl: <http://w3.org> . @prefix rdf: <http://w3.org> ...` — four prefixes colliding on the same placeholder URI.
6. JSON-LD `"$schema": "http://json-schema.org"` — not a valid schema URL.

Re-using the `v4.12.0` label here would conflate the rejected submission with the rebuilt artifact. The full audit trail is preserved in the planning archive that accompanies this PR.

## Changelog

| Version | Date | Change |
|---|---|---|
| 4.13.0 | 2026-05-21 | Bootstrap — Phase A of the 3-phase ingestion plan. 7 principles mapped to existing `multi-agent-os` surfaces with `file:line` citations. OWL/Turtle + JSON-LD machine-readable mirrors. No runtime code introduced. |
