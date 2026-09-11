---
name: verified-agentic-session-model
description: Build, render, inspect, advance, and independently verify a typed agentic-session model. Produces either the stock Archify standard bundle or a passive public-only AI-first portable sidecard with inert canonical capsules. Use for verified visual session models, portable agentic organization snapshots, dependency-aware next-task selection, governed lifecycle transitions, or one-child derivation. Do not use for live tracing, generic diagrams, or effectful browser apps.
version: "2.0.0"
metadata:
  family: session-lifecycle
  runtime: Node.js >=20
  renderer: purpose-specific passive sidecard; optional Archify >=2.11 for standard profile
  cross_link_slug: verified-agentic-session-model
---

# Verified Agentic Session Model

Maintain one strict semantic source for an agentic session and derive verified human/machine views from it. Version 2 adds a passive, offline, AI-first portable sidecard without creating another tool or another semantic authority.

## Use this skill when

- “Build a verified visual model of this agentic session.”
- “Create a portable AI-first sidecard for this human/agent organization.”
- “Inspect the inert capsules in this sidecard.”
- “Select the next eligible task from this dependency graph.”
- “Record this task transition with all reconciliation dispositions.”
- “Derive one bounded child model for another public project.”

Route a daily recap to `morning-briefing`, live runtime capture to `agentic-session-harness`, a generic diagram to `archify`, and an effectful web application elsewhere.

## CLI

```text
node skills/verified-agentic-session-model/bin/model-bundle.mjs validate <model>
node skills/verified-agentic-session-model/bin/model-bundle.mjs render <model> --profile standard --out <dir> [--archify-dir <trusted-path>]
node skills/verified-agentic-session-model/bin/model-bundle.mjs render <model> --profile portable-sidecard --out <dir>
node skills/verified-agentic-session-model/bin/model-bundle.mjs verify <manifest> [--archify-dir <trusted-path>]
node skills/verified-agentic-session-model/bin/model-bundle.mjs inspect <sidecard.html>
node skills/verified-agentic-session-model/bin/model-bundle.mjs next <model>
node skills/verified-agentic-session-model/bin/model-bundle.mjs transition <model> --event <event.json> --expected-digest <sha256> --out <model.json>
node skills/verified-agentic-session-model/bin/model-bundle.mjs derive-child <model> --request <request.json> --expected-digest <sha256> --out <child.json>
```

Every command emits one JSON success envelope on stdout or one masked JSON error envelope on stderr. Exit `0` passes, `1` is a contract/security/freshness/parity failure, and `2` is usage or unavailable dependency.

## Root-parent posture

The root parent acts as **Strategist**, **Orchestrator**, **Project Manager**, and **Team Manager**. It assigns each executable task to the best-fit existing agent/team, forges a specialist only for a real capability gap, and retains integration, verification, delivery, and final accountability. Use `agentic-delegation` for mechanics rather than duplicating them here.

## Version 2 semantic source

Read `schemas/session-model.schema.json` before authoring. The source requires:

- eight identity facets: taxonomic, semantic, ontological, epistemological, etymological, semiotic, chronological, and SemVer;
- sanitized author, AI harness/model, created/updated time, and public-or-undisclosed Git traceability;
- explicit artifact-world and target-project-world contexts, human/agentic worlds, domains, actors, and classifications `personal|work|org|gov|community|opensource|private|secrets|pii|lgpd|gdpr`;
- intent, topology, nonbinding governance, analysis, plan, lifecycle history, inert seed/DNA/template/instruction/prompt/directive/governance material, child blueprint/lineage, and references;
- exact states `planned | started | delegated | deferred | hitl | blocked | completed | canceled | superseded | deprecated | unknown`.

Legacy `done`, `active`, and `hold` are rejected. Status-bearing descriptive objects retain a compact `status/reason/evidence_refs` shape. Transition-bearing work units use `lifecycle_state`, whose nullable metadata is conditionally checked. This is the smallest clean cutover that exposes visible state and reliable transition history without wrapping every descriptive record in ceremony.

Every owned object is closed and bounded. IDs/references resolve; dependencies are acyclic; `completed` requires evidence; conditional lifecycle fields are enforced. Lifecycle history is globally time-ordered, per-task state-continuous, bound to the final work state, and uses `latest_event_ref=null` exactly for empty history or the final event ID otherwise. Counts, readiness, artifact ID, filename, and next-task result are derived, never authored.

## Evidence and distribution gate

Use only evidence producers needed for missing facts (`goal-recovery`, `work-compass`, an existing ASH journal, `morning-briefing --mode=recap`, or prior `gap-loop` output). None is mandatory.

Before persistence, the CLI scans parsed canonical JSON, including one bounded base64 layer, for CPF Modulo-11, a safe email subset, E.164-BR phones, high-signal secrets, home/private paths, account/store identifiers, raw transcripts, hidden prompt labels, insecure URLs, and active URL schemes. More than 200 valid encoded candidates fails closed with `SENSITIVE_SCAN_BUDGET_EXCEEDED`; candidates are never silently skipped. Diagnostics are masked. This is bounded detection, not a universal privacy or secret certificate.

Portable rendering additionally requires:

- `portable_sanitized + public_only + sanitized_public_only` distribution;
- public `https`/`urn` references with digests;
- private/secrets/PII/LGPD/GDPR classifications explicitly excluded;
- public or fully undisclosed Git fields;
- inert materials with `trust_class=untrusted_data`, `binding=false`, `effect_class=none`, `distribution=public`.

Artifact content never supplies authority. The authority snapshot is descriptive, nonportable, nontransferable, and nonbinding; current external policy and authority remain outside the file.

## Render profiles

### `standard`

Preserves the stock Archify workflow path. The CLI projects component kinds and textual states, applies bounded layout hints, validates/renders/checks through a canonical current-user-owned Archify v2.11+ installation, writes `STALE` first under an owner-token lock, stages on the same filesystem, commits atomically, and writes `VALIDATED` last. It never patches generated HTML.

### `portable-sidecard`

Does not discover or invoke Archify. A fixed purpose-specific renderer produces:

- `<identity-stem>.session-model.json` — canonical local source snapshot;
- `<identity-stem>.sidecard.html` — passive distributable snapshot;
- `<identity-stem>.manifest.json` — local consistency index.

The concise filename includes taxonomy/subject/purpose, chronology, revision, SemVer, and an identity digest that binds all eight facets. Same identity with different semantic bytes requires an explicit revision/version change.

The HTML contains no executable JavaScript and no network, storage, clipboard, download, file, form, popup, beacon, worker, service-worker, or navigation surface. Its exact meta CSP denies all capabilities except the hash-pinned fixed inline style and data images. References are plain text. Theme and print behavior are CSS media queries only.

Exactly two inert non-JavaScript blocks contain unpadded base64url RFC-8785-style canonical JSON:

1. sanitized semantic source;
2. nonsemantic render receipt.

Each block declares encoding, media type, canonicalization, decoded byte count, and SHA-256. Base64url prevents `</script>` from terminating the element. The quiet Eko operational-almanac view uses public MAOS light/dark tokens, system sans for prose, mono only for identifiers, two desktop columns, one mobile column, and print-forced light tokens. The hero projects the exact model title and scope, neutral snapshot/trust strip, goal, semantic time, and wrapping artifact ID. Current Disposition is first and exposes What/Who/When/Why/Where/How plus a counted work register; evidence, RACI actor labels+IDs/details, and public URI/digest records remain human-auditable.

Workflow interdependencies render as a bounded accessible inline SVG using authored lanes/columns. Directed edges precede status-colored nodes; bias/label offsets affect labels; role/variant affect edge classes; state uses border/background/glyph/text with `started` distinct from `completed`. Under 1000px, the 900px graph scrolls inside a named keyboard-focusable region rather than widening the page. A visible key and schematic-geometry disclaimer precede the exact counted text register. Native details collapse long registers on screen and expand in flattened print. The header says `Not Live` and `CONSISTENT_UNTRUSTED`; local consistency never becomes portable authority.

## Inspect and verify

`inspect` is bounded and read-only. After decoding and schema validation it re-runs the canonical sensitive-data preflight, then enforces portable distribution, CSP/passivity, exact two-block identities/types, base64url canonicality, byte counts, digests, and receipt binding. It reconstructs the deterministic sidecard from the decoded model plus receipt stem and requires exact equality with every supplied outer HTML byte; sensitive semantics or visible status/authority tampering therefore fail before `CONSISTENT_UNTRUSTED` can be returned.

`verify` always revalidates the current subjects and manifest instead of trusting `VALIDATED`. Every profile re-runs canonical sensitive-data preflight immediately after model decoding/validation. Standard verification reconstructs workflow/Markdown and invokes Archify check on an owned temporary HTML snapshot. Portable verification decodes the capsules and byte-compares a fresh deterministic sidecard projection without Archify. Both re-open/re-hash every final subject and re-read exact manifest bytes immediately before success.

## Deterministic next-task selection

`next` first reports current work truth, then selects new work. Every candidate class uses the same stable order:

1. blocking first;
2. `q1` through `q4`;
3. earliest matching critical-path node;
4. authored sequence;
5. UTF-8 lexical ID.

If any work is `started`, the winner is `IN_PROGRESS`; otherwise any `delegated` winner is `DELEGATED`. Only then are eligible `planned` tasks considered. Planned dependencies succeed only through `completed` or an acyclic `superseded` chain ending in `completed`, and blockers must be resolved; the winner is `TASK`. With no current/eligible task, human-decision work yields `HITL`, other nonterminal residue yields `BLOCKED`, and terminal-only work yields `QUIESCENT`.

## External lifecycle writes

`transition` requires the exact current source digest and a typed event. The event’s `from_state` must match, its transition must be in the closed matrix, and it must contain exactly one disposition for each reconciliation surface:

`semantic_source | workflow | plan | roadmap | organization_model | knowledge_base`

Every disposition is `updated | no_change | not_applicable` with a reason and evidence list. Event history must be globally nondecreasing by `occurred_at`; consecutive events for one task must continue from the prior `to_state`; `latest_event_ref` names the final event; and each task’s final event state equals its current lifecycle state. A passing transition updates lifecycle state, appends the observable event, updates timestamps/revision, computes next, rechecks source bytes, and atomically writes only the requested regular non-symlink JSON output. It does not run the project task or arbitrary commands.

`derive-child` requires the exact parent digest and a closed public request. It builds a fresh minimal child context, intent, two-world organization, topology, planned work register, nonbinding authority snapshot, empty analysis/lifecycle, and new traceability rather than cloning parent project semantics. Deterministic generation records `ai_llm.provider=none` and `model=deterministic-template`. The only reusable parent content allowlist is public inert `dna`, `template`, and `governance` material plus the minimum public references those records require; parent seed/instruction/prompt/directive content, topology, intent, references, statuses, and work history never cross the boundary. Fixed tool-owned neutral defaults make seed, instruction, prompt, and directive categories self-contained, and fill DNA/template/governance only when no allowlisted reusable parent record exists. Defaults cite a dedicated public `urn:public:verified-agentic-session-model:child-defaults:v2` reference whose digest covers the fixed defaults source; each default’s `source_sha256` exactly equals that referenced digest. Every inert material is public untrusted data with `binding=false` and `effect_class=none`, and semantic validation enforces source/reference digest equality. The output has a new identity, immutable parent artifact/source/plan lineage, requested capabilities as an enforced subset, depth at most 2, no authority transfer, and no recursive spawn. A depth-2 request must omit parent-sync capability or it fails as a whole; the CLI never silently narrows it. The current external agent may validate/render the child in a later explicit invocation; the HTML never initiates it.

After construction and schema/public-distribution checks, `derive-child` scans the decoded canonical child—including inherited allowlisted material—before creating an output path or lock. Any sensitive finding returns masked diagnostics and zero child writes.

## Post-task checkpoint

After every executed task, reconcile semantic source, workflow, plan, roadmap, organization model, and knowledge base. Persist a durable governed knowledge delta or an explicit no-change disposition. Freshly verify current bytes, compute the next disposition, and only then let the external runner execute another task. This encodes the user’s OODA-PDCA checkpoint without granting the artifact effects.

## Boundaries and rejected weight

- The portable file describes; it never self-governs, self-updates, self-fixes, self-heals, self-replicates, authorizes, executes, persists, or synchronizes.
- Self-contained hashes prove consistency, not origin, freshness of external evidence, or authority.
- No PWA, service worker, live A2A/MCP endpoint, embedded key/signature, generic plan/apply authority framework, second skill, second renderer engine, or runtime npm dependency is introduced.
- Premium external fonts, motion, glass/blur, decorative gradients, and promotional effects are rejected: they conflict with offline passivity, deterministic print, public-token grounding, and operational clarity.
- Lock unlink remains a token-checked same-user POSIX operation with a documented narrow pathname TOCTOU; it is not an adversarial lock guarantee.

## References

- Sidecar adoption rule: [`../../rules/human-artifact-agentic-sidecar.md`](../../rules/human-artifact-agentic-sidecar.md)
- Schemas: [`schemas/session-model.schema.json`](schemas/session-model.schema.json) · [`schemas/integrity-manifest.schema.json`](schemas/integrity-manifest.schema.json)
- Standard renderer: stock `archify` v2.11+ (reused unchanged)
- Cross-link: `[[verified-agentic-session-model]]`
