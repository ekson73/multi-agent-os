---
description: Require a machine-readable sidecar or machine-first source when durable human artifacts carry meaning that agents consume; uses hard triggers or a transparent weighted threshold and fresh-byte verification.
---

# Human Artifact Agentic Sidecar

<!-- Auto-loaded rule | Version: 1.0.0 | Ratified: 2026-09-11 -->

## Rule

When an agent creates or materially changes a durable human-facing artifact, it MUST decide whether agents will parse, interpret, validate, route from, or reuse that artifact. If a hard trigger fires or the transparent weighted score is at least 70, the same delivery includes an agent-facing sidecar form. The sidecar is part of Done, not follow-up work.

## Decision gate

### Hard triggers

A sidecar form is required regardless of score when any condition holds:

- The artifact is input to an agent, MCP, CLI, API, CI gate, workflow, delegation, policy, roadmap, status model, responsibility assignment, decision record, or release gate.
- Two or more agents or harnesses must derive the same meaning from it.
- Human/machine interpretation drift can change authority, scope, status, execution, safety, or acceptance.
- Structured data generates the human artifact. That structured source is the sidecar and semantic SSOT; creating a duplicate sidecar is forbidden.

### Weighted adoption matrix

Score each criterion as binary: met = 1; not met = 0. Report every criterion value and arithmetic term whenever a score is reported; an unexplained aggregate never authorizes adoption.

| Criterion | Weight | Met when |
|---|---:|---|
| Size/complexity | 30 | More than 200 lines or at least three concerns are mixed |
| Reusability | 25 | At least three consumers or imports are expected |
| Multi-agent use | 20 | At least two distinct agents or tools consume it |
| Schema criticality | 15 | Machine validation or interface correctness matters |
| Longevity | 10 | Expected lifetime exceeds six months |

`score = Σ(met × weight)`

- `score >= 70`: sidecar REQUIRED.
- `score 50–69`: owner judgment; default to no sidecar unless a hard trigger fires.
- `score < 50`: no sidecar; keep the human artifact self-contained.

## Permitted forms

1. **Machine-first rendered artifact:** structured data generates the human artifact, so the structured source is both semantic SSOT and sidecar. It remains valid under its domain schema; never add fields forbidden by that schema and never create a second sidecar.
2. **Human-first artifact:** create one co-located `<artifact-stem>.sidecar.json`, validated by a versioned artifact-appropriate JSON Schema.
3. **Dual-native artifact:** concise normative text written directly for humans and agents may serve both audiences when no deterministic field extraction is required. Record that decision in its validation evidence.
4. **Integrity manifest:** a separate `<artifact-stem>.manifest.json` may index pointers, provenance, current-byte hashes, validators, and generation identity. It is an index, not another sidecar, and contains no duplicated semantic content.
5. **Protocol separation:** static artifacts use plain JSON. JSON-RPC 2.0/AIMS envelopes are reserved for runtime status, error, progress, and return messages; they do not decorate static files.

A companion sidecar contains at least `schema_version`, `artifact_id`, `artifact_kind`, `human_artifact`, `sections`, `provenance`, and `status`. A machine-first source follows its own domain schema. Every form excludes raw secrets, credentials, personal data, private identifiers, unbounded transcripts, and machine-local account/store values.

## Coupled update and current-byte verification

A material semantic change is complete only when:

1. the machine SSOT or sidecar is updated first;
2. the human artifact is regenerated or reconciled;
3. schema and semantic-reference validation pass;
4. referenced sections and IDs resolve;
5. an integrity manifest, when used, records hashes from the final current bytes after rendering;
6. the human and agent views expose the same statuses, dependencies, authority, risks, and acceptance criteria; and
7. a fresh read-only verification recomputes live hashes, pointers, derived facts, and cross-view parity rather than trusting the manifest’s recorded status or file modification times.

A producer that claims manifest validity uses an exclusive writer lock, writes `STALE` atomically before changing generated targets, and writes `VALIDATED` atomically only after final bytes and checks succeed. A crash, failed check, hash mismatch, unresolved pointer, or parity mismatch leaves the effective status `STALE`. Consumers never infer current authority or completion from stale bytes or from a self-declared `VALIDATED` value without fresh verification.

## Explicit exceptions

No sidecar is needed for throwaway or single-use artifacts, short single-concern prose, or human-only narrative that no agent consumes, unless a hard trigger fires. Existing legacy artifacts migrate only when materially changed or when observed interpretation drift has caused a real failure. This rule does not require signing: ordinary hashes detect accidental staleness; adversarial attestation belongs to a separately justified threat model.

## Scope boundary

This rule decides **whether** a durable artifact needs a machine form and how coupled freshness behaves. It does not define a domain schema, collect evidence, render a view, verify a particular bundle, or choose a producer. Domain tools own those operations. The session-model application is [`../skills/verified-agentic-session-model/SKILL.md`](../skills/verified-agentic-session-model/SKILL.md).

## Independent review record — rule quality 6/6

These six semantic judgments were reviewed independently; they are not unit-tested by prose regex, which can prove only that declarations are present.

- **Self-application — PASS:** this concise normative rule is dual-native; humans and agents consume the same clauses and no deterministic extraction is required.
- **Non-contradiction — PASS:** hard-trigger, threshold, machine-first, human-first, dual-native, and optional-manifest branches are mutually explicit; a machine-first source forbids a duplicate sidecar.
- **Survival — PASS:** applying the rule keeps this rule readable and keeps governed artifacts synchronized.
- **Bounded responsibility — PASS:** only materially changed durable artifacts with identified machine consumers or explicit gate results are in scope; there is no periodic global migration.
- **Explicit exception — PASS:** throwaway, single-use, short human-only, and non-consumed narrative artifacts remain excluded absent a hard trigger.
- **Utility sunset — PASS:** deprecation becomes a candidate when a host-native schema-enforced dual-audience contract supersedes this rule, the operator retracts it, repeated evidenced false positives show harm, or a better composable standard emerges.

## Lineage

Promoted from the operator-ratified sidecar decision contract. The weighted matrix preserves its transparent 30/25/20/15/10 adoption aid; the current-byte and fail-closed clauses close the stale self-certification gap. Cross-link: `[[human-artifact-agentic-sidecar]]`.

*Signed: Claude-Dev-793b-421 · 2026-09-12T01:35:00Z*
