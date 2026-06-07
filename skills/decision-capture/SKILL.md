---
name: decision-capture
description: |
  Capture a non-trivial agent decision (with sources + rationale + spec-alignment) into the ASH
  decision-audit trail via `agentic-decide`, so it can later be audited with `agentic-decisions`.
  Use WHEN you make a decision that shapes the product/architecture/code AND that a reviewer might
  question later — especially any choice that touches a SPEC (BR/FR/NFR/ADR) or the manifesto, or
  that deviates from a prototype/spec. The operator's pain: AI agents drift from canonical SPECs and
  there is no way to ask "why did the agent decide that?". This skill closes the capture gap (agent
  reasoning is ephemeral — recorded only if written at decision-time). Cross-vendor AAIF (Bash + jq).
  Do NOT use for trivial actions (typos, formatting, read-only inspection) or for capturing OPERATOR
  directives (those are the ash Stop subagent's job — this is for the AGENT's own decisions).

prompt_version: "1.0.0"
evals:
  should_trigger:
    - "Chose column-based RLS over schema-per-tenant — record why + which spec"
    - "Deviated from the prototype's flow for a documented reason"
    - "Picked library X over Y based on ADR-006 + a benchmark link"
    - "Made an architecture call a reviewer will likely question"
    - "Decided to store a field as TEXT though NFR says UUID (divergent — must log)"
  should_not_trigger:
    - "Fixed a typo / reformatted code"
    - "Read a file to understand context (no decision)"
    - "Captured what the operator asked for (that is ash Stop-subagent territory)"
    - "Ran a test or a build"

id: MAOS-SKILL-decision-capture
version: 1.0.0
type: skill
status: active
owner: maos-community
last_updated: 2026-05-28
mentes: [Tomé, Crítica, Transparente]
rbad_categories: [IT-Architect, Modern-Context-Engineer, Traditional-Auditor]
related_adrs: []   # community Layer-1 — org-internal ADRs apply only to the corporate overlay
related_gaps: []
promotion_status: promoted to multi-agent-os 2026-06-02 (generic agent-observability)
dogfooding_validation:
  cycles_completed: 0
  cycles_required: 2
  evidence: []
  promotion_eligible: false

changelog:
  - 2026-05-28 — v1.0.0 — Bootstrap. Codifies when/how to call agentic-decide for the ASH v1.6.0
    decision-audit extension (ash-schema §17). Companion to agentic-decide / decide-merge.sh /
    agentic-decisions. AAIF cross-vendor. cycles_completed:0.
---

# decision-capture — record agent decisions for audit

> **Why this exists.** Agent reasoning is *ephemeral*: a decision's rationale + the sources it was
> based on vanish at session end unless written down at decision-time. A spec-driven / ai-driven project
> sees agents **drift from canonical SPECs** (e.g. BR/FR/NFR/ADR ids); the team needs to audit *why*. This skill
> is the in-session write-path of the ASH decision-audit extension (`docs/governance/ash-schema.md §17`).

## When to capture (trigger)

Call `agentic-decide` right after you make a **non-trivial decision** — one that:
- shapes product / architecture / data-model / code structure, AND
- a reviewer could reasonably question later, OR
- touches a SPEC (BR-/FR-/NFR-/ADR-) or the manifesto, OR
- **deviates** from a prototype / spec / manifesto (always capture these — `spec_alignment=divergent`).

Heuristic: if you'd write a sentence starting "I decided X because Y" — capture it.

## When NOT to capture (skip)

- Trivial: typos, formatting, mechanical edits, read-only inspection, running tests/builds.
- Operator directives (what the *human* asked) — those are reconstructed by the ASH Stop subagent, not this skill. This skill is for the **agent's own** decisions.

## How to capture

```bash
agentic-decide \
  --decision "Use column-based RLS, not schema-per-tenant" \
  --rationale "Lower migration cost; tenant_id filter sufficient for pilot scale" \
  --source spec:ADR-006:cited \
  --source file:docs/manifesto/PROJECT-MANIFESTO.md:attended \
  --source variable:tenant_id:cited \
  --spec-ref ADR-006 --spec-ref NFR-003 \
  --spec-alignment aligned \
  --confidence high
```

- **`--source TYPE:REF:INFL`** (repeatable) — what you based the decision on. `INFL` ∈ `attended` (read + shaped your choice) · `cited` (explicitly referenced) · `ignored` (saw but deliberately didn't use). `TYPE` ∈ `spec|file|link|field|variable|tool|transcript|mcp`. URLs with colons are fine.
- **`--spec-alignment`** ∈ `aligned|divergent|unverified` — **the drift signal.** Be honest: if you deviate from a spec, mark `divergent` and say why in `--rationale`. This is the field the operator audits.
- **`--confidence`** ∈ `high|medium|low`.
- One call per decision; ids auto-increment (`DEC-1`, `DEC-2`, …) per session.

Captured records stage to `.claude/audit/staging/<session>.decisions.jsonl`, then the `decide-merge.sh` Stop hook deterministically folds them into the session's journal `decisions[]`.

## How it gets audited (downstream)

The operator / a reviewer runs:
```bash
agentic-decisions                              # table of all decisions
agentic-decisions --filter spec_alignment=divergent   # the drift query
agentic-decisions --filter spec_ref=ADR-006 --sort alignment
agentic-decisions --output json | jq '…'       # [C06] machine output
```

## Discipline (anti-theater)

- **Never fabricate** a decision or a source. If you didn't base it on something, omit `--source`.
- **Honest alignment**: don't mark `aligned` to look good — a `divergent` capture with a clear rationale is exactly the signal the team wants.
- Role-types only in free-text (no PII real-names). No secrets in `--rationale`/`--source`.

## Refs

- Contract: `docs/governance/ash-schema.md §17` (v1.6.0 decision-audit extension)
- Tools: `agentic-decide` · `skills/agentic-session-harness/hooks/decide-merge.sh` · `agentic-decisions`
- Layer-1 schema: `docs/governance/agentic-session-harness-spec.md` (frozen-17; promotion candidate)
- External grounding: OpenTelemetry GenAI `agent.output.source.influence`; otel-agent-provenance Tier-1; Coverge "AI audit trail" (reasoning ephemerality).
