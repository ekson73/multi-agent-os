# Changelog

All notable changes to the Multi-Agent OS plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Fixed — hub-registry bot-finding remediation (post-merge PDCA of #209)

- **F2 (High — Copilot + Qodo): conductor gate was inert** — `_load_conductors()` stored the raw
  `manager|signature-path` lines of `conductors.txt`, so `tid in conductors` never matched and the
  RULE-011 conductor cap only *appeared* to work (masked by license/conflict gates). Now parses the
  manager id (left of `|`); regression test asserts at least one conductor is capped BY the
  conductor gate itself.
- **F3 (Blocker — Qodo): tier upgrade via `request_activation()`** — non-always-on requests were
  granted unconditionally, letting a caller promote an `excluded` (supply-chain-veto) record to
  `opt-in`. Now: `excluded` is immutable via the API (re-derivation only) and any upgrade beyond
  the DERIVED tier is refused (downgrades allowed) — fail-closed restored.
- **F4 (High — Qodo): silent id collision** — `_add()` overwrote records; a third-party id could
  shadow a first-party tool in the SSOT. Now: first-derived wins (skills → agents → third-party
  precedence), every collision is recorded in `report().invariants.id_collisions`, and a
  cross-category collision FAILS the verdict.
- **F5 (Medium — Qodo): vacuous invariant** — `all_required_fields_present` checked dict KEYS of a
  dataclass (always true); now checks NON-EMPTY content of the critical fields (id · provenance ·
  derived_from · activation · license_spdx · rollback · security_status · category).
- **F6 (Medium — Qodo): falsy recipe ids** — `_load_recipes()` now skips empty/null recipe and
  tool ids.
- 7 regression tests appended to `tests/test_hub_registry.py` (38 total green).


### Added — profile-as-gating-input (T2 / WAVE 5) — the persisted enablement profile the hub honors

- **`mcp-tools/maos-mcp-hub/lib/gateway/profile.py`** — `HubProfile` + `load_profile()` (resolution:
  arg > `$MAOS_HUB_PROFILE` > `<hub>/profile.yaml` > None) + `resolver_from_profile()` — the
  persisted enablement-profile SSOT the WAVE-0 gating seam was waiting for (*"the active profile
  comes from OUTSIDE"*). Absent profile / `mode: advisory` / empty ⇒ `None` ⇒ passthrough
  (pre-WAVE-5 behaviour, 0-regression); a PRESENT-but-invalid profile raises `ProfileError`
  (fail-closed — never silently disables gating). `validate_profile(profile, registry)` refuses a
  profile enabling an `activation=excluded` id (supply-chain vetoes can't be re-enabled via YAML).
- **`hub.py` wiring** — ONE shared profile-derived `PolicyResolver` attached to every gateway
  router at mount (`router.policy = _hub_policy`); stderr banner when a profile is ENFORCED or
  loaded advisory-only.
- **`lib/gateway/policy.py`** — every DENY is now a **logged field**: recorded in
  `PolicyResolver.decisions` (bounded ring, `DECISION_LOG_MAXLEN=200`) + mirrored to
  `logging` (`maos_hub.policy` warning). Additive — decision semantics unchanged.
- **`profile.yaml.example`** — documented template (copy to `profile.yaml` to activate).
- **tasks.md T2 acceptance as logged fields (DoD-gate):** disabled tool → dispatch returns the
  structured `Blocked by policy` envelope AND `resolver.decisions[-1]` carries
  `{tool_id, allow: false, reason}`; conflicting tool → denied with `conflicting_with` populated
  (11 tests in `tests/test_gateway_profile.py`; ring-bound proof; registry fail-closed proof).
  Local suite delta vs pristine main = identical pre-existing env failures — zero regression.


### Added — hub-registry SSOT (T1 / WAVE 5) — plugin-level registry, derived not hand-maintained

- **`mcp-tools/maos-mcp-hub/lib/registry/hub_registry.py`** — `HubRegistry`: the plugin-level
  registry SSOT of `openspec/specs/maos-hub-registry/spec.md` (the SSOT the WAVE-5 console and the
  WAVE-6 integrator read). Records DERIVED from the repo's own sources — `skills/*/SKILL.md` +
  `agents/*.md` frontmatter (own tools), `evals/fixtures/intake_verdicts.yaml` (third-party:
  license/provenance/verdict→activation), `lib/gateway/conflicts.yaml` (WAVE-0 Phase-2
  incompatibilities, round-tripped), `plugin-scripts/governance/lib/conductors.txt` (RULE-011).
  Full spec field set per record (`activation` · `license_spdx` · `provenance` · `ttl` +
  `last_validated` · `rollback` · `conflicts_with` · `recipes` · `security_status` …) +
  `derived_from` (provenance of the derivation itself — the checkable "not hand-maintained" field).
- **`mcp-tools/maos-mcp-hub/lib/gateway/recipes.yaml`** — the Phase-2 §4 composition recipes
  promoted into structured data (one-time curated promotion, sibling of `conflicts.yaml`; source
  cited): 6 use-case stacks the registry projects into each record's `recipes[]`.
- **Spec scenarios as logged fields (DoD-gate honoured):** "a new skill ships" (synthetic-repo
  regeneration test) · "third-party proposed as always-on" (`request_activation` refuses on
  `license_spdx=NONE` / `conflicts_with` edge / non-vetted, reason recorded in `gate_decisions`) ·
  "two conductors selected" (`conflicts_roundtrip` invariant: registry graph == conflicts.yaml,
  every endpoint resolves to a record) · "upstream goes stale" (`eject_candidates(today)` flags
  past-TTL records — the GSD/MemPalace lesson). Deterministic verdict→activation map documented
  in the module docstring (EXCLUDED/ABANDON→excluded · SUB-AGENT/DEFER→opt-in ·
  INSTALL/ADAPT/ABSORB→default-on-for-context capped by license/conductor/conflict gates;
  `always-on` never granted to third-party at derivation).
- **`mcp-tools/maos-mcp-hub/tests/test_hub_registry.py`** — 20 tests incl. golden derivation over
  the REAL repo (62 skills · 32 intake entries) + CLI contract
  (`python -m lib.registry.hub_registry` → `verdict: pass`, exit 1 on any invariant violation).
  Additive; no plugin version bump (ADR-003). Local pre-existing env failures (py<3.10 unions,
  absent gateway deps) unchanged vs pristine main — zero regression.


### Removed — Layer-Purity: corp-overlay rules removed (KRDR #160 Phase-B item #1)

- **`rules/agent-delegation.md` [C14], `rules/exit-hygiene.md` [C13], `rules/forge-agent-design.md`
  [C14.1/RBAD] removed** — each was a corporate ("Organization") overlay of a generic community protocol that
  already lives in this repo (`protocols/agent-delegation.md`, `protocols/exit-hygiene.md`,
  `protocols/rbad.md` respectively), differing only by an `Organization` ↔ `Vek` label
  substitution across titles/headers/section-names — a genuine violation of Layer Purity
  (`layer-precedence-policy.md` Rule 2: community repos must never carry corp-specific content).
  Originally added as a batch in commit `eecf329` ("migrate 8 community protocols from user-scope");
  no prior CHANGELOG entry documented their creation, so there is nothing to mirror beyond this
  removal note.
- **Verified safe via recon before removal**: zero other files in the repo reference the 3 removed
  paths (only self-references, which vanish with the files); the 3 generic counterparts are
  confirmed vendor/org-neutral (0 Vek/Organization hits); no registry/manifest enumerates
  `rules/*.md` as a set; `rules/agent-scm.md` was investigated and **correctly excluded** — it is
  NOT a duplicate (no `vek-ai-toolkit` counterpart exists) and its content (generic SCM/git-provider
  engineer role) is genuinely community-appropriate.

### Docs — WT11 MAOS Hub reframe (WAVE 4) — series headers + published artifacts regenerated

- **`research/agentic-moe-2026/` series reframed** — a standardized, grep-able banner
  (`Reframe — MAOS Hub (ADR-006, Accepted 2026-06-29)`) inserted after the title of the 8 series
  files (`00-canonicalization` · `01a/b/c/d` · `02-ntree-moe` · `03-orchestrator-hub` ·
  `final-report`): the "ATH" hub of the series was ratified and realized as the **MAOS Hub**
  (ATH ⊂ agentic-moe-2026 ⊂ MAOS). History preserved — banners are additive, no rewriting of the
  dated 2026-06-27 record. *Acceptance (logged field, DoD-gate):*
  `grep -rl 'Reframe — MAOS Hub (ADR-006' research/agentic-moe-2026/*.md | wc -l` → `8`.
- **Published artifacts regenerated with the MAOS Hub framing** —
  `20260627-CONSOLIDATED.html` (retitled + cover reframe banner; `<title>` now
  "MAOS Hub (Agentic MoE 2026) — …"), `20260627-CONSOLIDATED.pdf` re-printed from the updated HTML
  (headless Chrome; PDF `/Title` metadata carries the new name — checkable field), and
  `20260627-exec-deck.pptx` title slide re-titled (3 runs patched via python-pptx).
- **MVV touch is NOT in this PR** — per ADR-006 §Consequences + ADR-007 §Status discipline the
  `CLAUDE.md` §Organizational Identity Vision edit is **HITL-escalated**: proposed in a dedicated
  ratification PR (operator merges; never a side-change in a lateral worktree).
- **WAVE 4 closes** (this was the WT11 docs slice): remaining backlog = WAVES 5–6 (console T1–T7,
  community T8–T10) per issue #204 + `openspec/changes/maos-hub-console/tasks.md`.

### Docs — ATH→MAOS Hub backlog living roadmap (status persisted)

- **`research/agentic-moe-2026/README.md`** — new §"Status do hands-on" living roadmap table (SSOT):
  WAVES 0–3 shipped (WT0 #187 · WT1 #188 · WT2 #189 · WT3 #197 · WT4 #198 · WT5 #199 · WT8 #200 ·
  WT10 #201), WT6 deferred / WT7 cut, WAVES 4–6 pending (WT11 docs+MVV-HITL, console/community per
  ADR-007 — tracking issue #204).
- **`docs/adrs/ADR-006-ath-moe-hub-adoption.md`** — §"Implementation status" appended as a pure
  pointer to the README SSOT table (no per-wave status duplicated in the ADR).

### Added — intake-batch verdicts (WT10 / P3, stories S10/S9) — the 26 experts dispositioned as data

- **`mcp-tools/maos-mcp-hub/evals/fixtures/intake_verdicts.yaml`** — machine-readable SSOT of the
  batch `agentic-tool-intake` dispositions for the agentic-moe-2026 landscape: 26 INCLUDED experts
  + graphiti BRIDGE + 5 EXCLUDED supply-chain reproductions (32 entries; verdict vocabulary
  INSTALL·ADAPT·ABSORB·SUB-AGENT·ABANDON·DEFER·EXCLUDED). Every verdict cites the existing
  research corpus as evidence (DRY — no re-research); star/license observations dated 2026-06-27;
  TTL `revisit: 2026-09-27`.
- **Supply-chain gate reproduced as data** (spec `maos-hub` → "Supply-chain gate"):
  `gsd-build/get-shit-done` ($GSD rug-pull → safe successor `open-gsd/gsd-core`) and `mempalace`
  (star-manip/unproven-claims class → `mem0ai/mem0`) are `blocked: true` records with evidence.
- **`mcp-tools/maos-mcp-hub/evals/intake_batch_eval.py`** — logged-field acceptance (DoD gate):
  checks A1..A7 incl. **A3 cross-SSOT** (the fixture's `conductor_class` must mirror the RULE-011
  enforcement registry `plugin-scripts/governance/lib/conductors.txt`, and no conductor may
  receive a plain INSTALL — the C1 single-conductor invariant asserted over the batch) and **A6**
  (every evidence ref resolves to a real repo file). `cd mcp-tools/maos-mcp-hub && python -m
  evals.intake_batch_eval` → `verdict: pass`; exit 1 on any violation.
- **`mcp-tools/maos-mcp-hub/tests/test_intake_batch.py`** — 16 tests: eval verdict + per-check
  parametrized asserts + the two named spec reproductions + cross-SSOT mirror + CLI contract.
- **`docs/adoption/intake-batch-2026-07-01.md`** — human mirror (fixture wins on disagreement):
  verdict summary (9 INSTALL · 4 ADAPT · 3 ABSORB · 3 SUB-AGENT · 4 ABANDON · 4 DEFER ·
  5 EXCLUDED) + notable dispositions (ECC/ruflo/bmad ABSORB are *empirically already done* —
  AgentShield→RULE-012, trust_score→CTS, phase-gating→intent classifier).
- WAVE 3 closes: this was the last WAVE-3 item (WT10); WAVE 4 (WT11 docs reframe) is next.

### Added — auto-generated tool-registry SSOT (WT8 / S1) — derived, never hand-maintained

- **`mcp-tools/maos-mcp-hub/lib/gateway/tool_registry.py`** — `ToolRegistry`: every `ToolRecord`
  is DERIVED from live `MetaToolRouter` instances (`SchemaRegistry` schemas + registered handlers +
  governance) — the WAVE-2 keystone that lifts the tool contract out of the gateways' divergent
  wiring (handoff: *"registry AUTO-GERADO … NÃO YAML hand-maintained que dá drift"*; spec anchor:
  `maos-hub-registry` → "Records are derived, not hand-maintained"). Provenance IS the acceptance:
  `derived_from` names the real handler (unwrapped past `@with_feedback`), checked by
  `report().invariants.all_records_derived` — a logged field, not prose.
- **WAVE-1 seams closed**: `to_iso_inventory()` = the exact `{id, summary, schema}` input of
  `IsoGate.from_inventory` (WT3); `to_cts_candidates()` = `CtsCandidate` rows with risk from a
  **deterministic, documented verb→`RiskSignals` map** (destructive→HIGH · write→MEDIUM · read→LOW,
  WT4). `to_yaml()` emits the generated YAML projection stamped `AUTO-GENERATED — DO NOT EDIT`.
- **DoD-gate honoured:** 8 tests (`tests/test_tool_registry.py`) incl. end-to-end seam proofs
  (registry→IsoGate selection · registry→CtsScorer rank with HIGH filtered traced) + a **golden
  derivation over the hub's REAL gateways** (confluence+compass+common, loss-free vs
  `router.action_count`; skip-graceful where gateway deps are absent). Additive; no plugin version
  bump (ADR-003).

### Added — L8 memory substrate (WT5 / S4) — mem0 default, file/seed degradation

- **`docs/adoption/mem0-2026-07-01.md`** — the `agentic-tool-intake` dossier for mem0 (verdict:
  **ADAPT — adapter-first, optional dependency**; research DRY-cited from
  `research/agentic-moe-2026/20260627-01a-substrates.md` §L8). Alternatives recorded: letta
  REJECTED (runtime lock-in), cognee = graph-first alternative, **graphiti DEFERRED** until a
  measured temporal workload (handoff WAVE-1: no gold-plating).
- **`mcp-tools/maos-mcp-hub/lib/memory/substrate.py`** — `MemorySubstrate`: resolves **mem0-first**
  (lazy import; any init/reach failure degrades) → `FileSeedBackend` (append-only JSONL — the
  file/seed mechanism postflight seeds already rely on). The spec scenario ("Substrate-first
  activation" → *memory backend unavailable*) implemented verbatim: degrade, **continue (never
  blocks, never fabricates — every response names the answering backend)**, and record
  **`l8_substrate{backend, degraded, reason}`** through the `on_trace` L9 hook. Mid-call outages
  degrade + retry on the fallback; a failing trace hook never blocks the substrate.
- **DoD-gate honoured:** acceptance = the logged field + golden behaviors asserted by **10 tests**
  (`tests/test_memory_substrate.py`), incl. torn-JSONL tolerance and no-false-degradation with a
  healthy client. 0-regression. Additive; no plugin version bump (ADR-003).

### Added — unified CTS scorer (WT4 / S2) — hard-filters-first multi-criteria ranking

- **`mcp-tools/maos-mcp-hub/lib/gateway/cts.py`** — `CtsScorer`: the WAVE-1 WT4 unification of the
  scattered prioritization logic (`protocols/action-priority.md` Eisenhower + `protocols/rbad.md`
  4-dim rubric + the WT3 ISO layer) into ONE weighted scorer (spec requirement "CTS multi-criteria
  scoring (hard-filters-first)", `openspec/specs/maos-hub/spec.md`).
- **The review-board-mandated `risk=HIGH` predicate is now CONCRETE** (not "irreversible-ish"):
  `RiskSignals` = enumerable boolean facts — HIGH iff ANY of {`irreversible`, `destructive`,
  `credential_scope`, `prod_facing`, `cross_org`}; MEDIUM iff {`bulk_write`, `remote_write`};
  LOW otherwise. Each signal is a verifiable property of the action, never a vibe.
- **Hard filters BEFORE any weighted score** (spec scenario): `policy` (PolicyResolver, PR #180 seam)
  → `open_source` → `auth` → `environment` → `data_class` → `risk_class` — the first hit eliminates
  with a traced reason; a perfect-score candidate lacking authorization is NEVER scored. Above-ceiling
  risk is `hitl_eligible` (HITL-routable), never a silent drop.
- **Six explicit criteria weights (sum = 1.0, test-asserted)**: scope 0.30 · eisenhower 0.20 ·
  risk 0.15 · reversibility 0.15 · iso 0.10 · methodology 0.10 — mapped to the RBAD 4-dim rubric
  (Expert-fit / Authorization / Task-frame / Risk-frame). Deterministic (tool_id tie-break).
- **The WT3↔WT4 seam composes**: `CtsRanking.ranked_ids()` is exactly `IsoGate.select`'s ranked
  input — `iso_promoted == cts_rank prefix` asserted end-to-end.
- **DoD-gate honoured:** acceptance = logged fields (`CtsRanking.to_report()` invariants:
  `weights_sum_to_1` · `eliminated_never_ranked` · `scores_descending` · `every_elimination_reasoned`)
  + golden fixture (`evals/fixtures/cts_cases.yaml`, real conflicts.yaml ids, 3 turns). Reproducible
  acceptance command: `python -m evals.cts_eval` (exit 0 ⇔ verdict green). **12 tests**
  (`tests/test_cts_scorer.py`), 0-regression. Additive; no plugin version bump (ADR-003).

### Added — ISO universal tool-gating (WT3 / S3) — summary pool + top-k promotion (MCP-tax control)

- **`mcp-tools/maos-mcp-hub/lib/gateway/iso.py`** — `IsoGate`: the WAVE-1 WT3 generalization of the
  Atlassian-only progressive-discovery into a gateway-agnostic ISO layer (spec requirement
  "ISO tool-gating (MCP-tax control)", `openspec/specs/maos-hub/spec.md`). Permanent summary pool
  (≤60 tokens/tool) + top-k full-schema promotion — conflict C4's fix: with dozens of connected MCP
  tools, full schemas cost 10k–60k tokens/turn; the pool keeps every tool discoverable at ≤60 tokens
  while only the top-k pay full price.
- **The two review-board-mandated definitions are now EXPLICIT** (else the threshold is incomputable):
  the NORMATIVE tokenizer `iso_tokens(text) = ceil(len(text)/4)` (deterministic, dependency-free,
  model-agnostic — the ≤60 threshold is *defined* in terms of this function) and
  `ISO_DEFAULT_TOP_K = 5` with a budget-derived cap
  (`k_effective = min(k_requested, budget_cap, allowed)`, greedy in rank order under an optional
  `schema_token_budget`).
- **Hard-filters-first composition:** an optional `PolicyResolver` (PR #180 seam, imported — never
  reimplemented) eliminates denied candidates BEFORE promotion; a denied tool is never surfaced as a
  top-k candidate (mirrors the CTS requirement). Denials carry `reason` + `conflicting_with`.
- **DoD-gate honoured:** every acceptance is a *logged field* (`IsoSelection.to_report()` invariants:
  `summaries_within_limit` · `promoted_lte_k` · `denied_never_promoted` · `budget_respected`) or a
  *golden-fixture invariant* (`evals/fixtures/iso_inventory.yaml` — 12 real conflicts.yaml tool-ids,
  4 turns: clean-topk / budget-bound / policy-gated / injection). Reproducible acceptance command:
  `python -m evals.iso_gate_eval` (exit 0 ⇔ verdict green). **14 tests** (`tests/test_iso_gate.py`),
  0-regression (error set identical to pristine main). Additive; no plugin version bump (ADR-003).

### Changed — bot-finding-arbiter v1.3.0 residual round (best-practices grounding · GitHub watch native · fire-point wiring)

- **`skills/bot-finding-arbiter/SKILL.md` v1.2.1 → v1.3.0** — directive-triage verified the operator's "OODA the bot-caused failure + 9 dispositions + teach-the-bot" directive was ~85-90% already satisfied by v1.2.x; this closes the 3 verified residual gaps (docs-only; `bin/classify.sh` + `tests/` untouched, 7/7 green): (a) teach-the-bot edicts now MANDATE **best-practices grounding** — consult the bot's official current config docs AND the governance anchor, and cite BOTH in the edict PR; (b) **GitHub watch parity resolved with the native primitive** — `gh pr checks <pr> --watch --fail-fast --json name,bucket,…` (+ `gh run view --log-failed`) documented as the sibling of `bin/bb-pipeline-watch.sh`; probe confirmed structured diagnosis → no custom wrapper built (Gordian native-over-custom); (c) fire-point effectivation below.
- **`skills/quiesce/SKILL.md` v0.1.0 → v0.2.0** — a PR red/blocked on a bot-reviewer finding now routes EACH finding to `bot-finding-arbiter` (*Praetor*) as the DEFAULT per-finding handler inside the PDCA loop (was: generic ad-hoc PDCA; the arbiter existed but nothing invoked it automatically).
- **`rules/pr-governance-unified.md` v1.2.0 → v1.2.1** — Step-8 now routes reviewer-BOT findings per-finding to the arbiter (elevates the 5-way disposition menu to 7-way + teach-the-bot); policy § Bot-Config Correction Discipline unchanged, now actively triggered from the lifecycle step.
- Additive; no plugin version bump (ADR-003 — bumps on release cut).

### Added — C6 content-security AgentShield (WT2 / RULE-012) — the PreToolUse BLOCKING half of the HYBRID

- **`plugin-scripts/governance/agentshield.sh`** (PreToolUse hook, `Bash|Task`) + **`lib/agentshield-scan.sh`** (pure, testable detector) — the runtime BLOCKING leg of the C6 content-security invariant (ADR-006 §4 · maos-hub spec §97–100), sibling of WT1's advisory SessionStart conductor-scan. Scans the channel payload — Bash `.tool_input.command` (channel=`tool_input`) and Task `.tool_input.prompt` (channel=`model_output` — model-generated text fed to a sub-agent) — and emits a **`RULE-012 c6_egress_check{channel, classification, secret_match, decision}`** logged field.
- **Blocks (exit 2 + JSON-RPC `-32004`)** on: a leaked secret (high-precision, gitleaks-grade signatures — `anthropic_key` · `github_token` · `aws_access_key` · `slack_token` · `private_key` · `jwt`); egress to a host outside `MAOS_AGENTSHIELD_ALLOWLIST` (opt-in); or `git --no-verify` bypassing the secret-at-rest floor (`hook_bypass`). Precedence: secret > egress > hook_bypass.
- **Leak-safe by construction:** the raw payload is NEVER serialized into the logged field — every JSON value is from a fixed vocabulary (`channel`/`classification`/`secret_match`-id/`decision`), so `secret_match` reports the KIND of secret (e.g. `anthropic_key`), never the value ⇒ no field can carry attacker-controlled bytes (leak-safe *and* JSON-injection-safe with zero escaping). **Availability-safe:** a malformed input defaults to allow (an unparseable call must not wedge the agent), HOME-safe under `set -u`, but a matched secret ALWAYS blocks. Opt-out `MAOS_NO_AGENTSHIELD=1`.
- **RULE-012** registered in `sentinel/detection_rules.md` + marked implemented in `openspec/specs/maos-hub/spec.md`. Wired into `hooks/hooks.json` PreToolUse under both `Bash` (after `worktree-gate`) and `Task` (after `token-budget-gate`) matchers.
- **DoD-gate honoured (the keystone, spec §106–109):** the acceptance is a *logged field / golden fixture*, never prose — a secret planted in a Task prompt yields `channel=model_output` & `decision=block` & `secret_match≠null`, asserted both on the pure detector AND end-to-end through the hook's audit jsonl. Secrets in fixtures are **assembled at runtime** so no literal credential lives in the test file (the scoped gitleaks scan stays clean). **43 bash tests** (`tests/governance/test-agentshield.sh`, auto-discovered by `run-all.sh`). Additive; no plugin version bump (ADR-003).

## [1.17.0] - 2026-06-30

### Added — hub routing-eval (S8) — *eval-first* measurement of the MoE gating-network

- **`mcp-tools/maos-mcp-hub/evals/routing_eval.py`** — the (k) "hub-ROUTING eval (6 task-families × risk)" from `protocols/moe-hub-architecture.md` + ADR-006's gap roadmap (WAVE-0 WT0). It runs *before* the gap-fill worktrees so the **"~70% coverage" claim is calibrated, not assumed** — the eval-first checkpoint the persona-pipeline mandated.
- **Exercises the REAL gating-seam** (`lib/gateway/policy.py::PolicyResolver`, PR #180) — never a reimplementation — over a golden corpus (`evals/fixtures/routing_cases.yaml`, 6 families × 3 risk, all real tool-ids) + calibrates the (a)–(m) coverage claim (`evals/fixtures/artifact_coverage.yaml`, from the doc's own status column).
- **Measured verdict:** `seam_teeth_real=true` (18/18 injected conflicts blocked, 18/18 naming the correct colliding tool; 18/18 would slip through `policy=None`) · `weighted_coverage=0.577` (strict 0.231 · lenient 0.923) → the "~70%" is **OPTIMISTIC** by the doc's own status column → `half_the_plan_falls=false` (the gap-fill waves WT1+ remain justified).
- **DoD-gate honoured:** every acceptance is a *logged JSON field* or a *golden-fixture invariant asserted in a test* — never prose. **14 tests** (`tests/test_routing_eval.py`, strengthened per bot review: `substrate_tools` source-of-truth, per-artifact weights, pinned calibration). Additive; no plugin version bump (ADR-003 — bumps on release cut).

### Added — C1 single-conductor runtime enforcement (WT1 / RULE-011) — the SessionStart half of the HYBRID

- **`plugin-scripts/governance/single-conductor-scan.sh`** (SessionStart hook) + **`lib/conductor-scan.sh`** (pure, testable detection) + **`lib/conductors.txt`** (curated footprint registry) — the runtime enforcement of the C1 single-conductor invariant (ADR-006 §4 · `moe-hub-architecture` Invariant 1). Scans the PROJECT scope (incl. the checkout's own `.claude/`) + USER scope (`~/.claude`) for a competing always-on manager (`bmad-method` · `superpowers` · `gstack` · `ECC` · `base` · `ruflo`) and emits a **`RULE-011 c1_conductor_scan{detected_conductors[], scope, decision}`** logged field; `decision ∈ {clean, taint, refuse}`.
- **Honest scoping (no false-blocks):** a competitor present only **user-globally** (the operator's own env) is `taint` (advisory); one **co-resident in THIS project** (a real second always-on manager) is `refuse`. The hook **never aborts the session** (always exit 0, HOME-safe under `set -u`) — the teeth are the logged decision + surfaced warning (warn→correct→block), routing the competitor via `/maos:agentic-tool-intake`.
- **Distinct from PR #180's gateway-layer seam:** #180 gates tool *dispatch* inside the MCP hub router; this is the *SessionStart* conductor-scan on the Claude-Code harness — the two are the cascade-resolved HYBRID's defense-in-depth (runtime hook + advisory cross-harness + blocking CI floor).
- **RULE-011** registered in `sentinel/detection_rules.md` + `openspec/specs/maos-hub/spec.md`. Wired into `hooks/hooks.json` SessionStart (after `preflight-session`). Opt-out `MAOS_NO_CONDUCTOR_SCAN=1`.
- **Security/robustness (bot review):** path-traversal guard on registry signatures (CWE-22), JSON-array escaping for data-driven ids. **DoD-gate honoured:** acceptance is the logged `decision` field over golden fixtures (planted project-conductor → `refuse`; user-only → `taint`; clean → `clean`; project-local `.claude/` → `refuse`; HOME-unset → still exit 0; `database`/maos-own do not false-trip). **23 bash tests** (`tests/governance/test-conductor-scan.sh`, auto-discovered by `run-all.sh`). Additive; no plugin version bump (ADR-003).

### Changed — `gap-loop` skill v0.1.0 → **v0.2.0** + `gap-loop-protocol` v1.0.0 → **v1.1.0** — fold the `--goal-n-loop v3 FINAL` deltas

- **`gap-loop` introduced** (#178) — harness-agnostic, self-driven, self-scored 5-phase convergence loop (DoR→RECAP→RESOLVE→VALIDATE→PERSIST) distilled from the operator's `--goal-n-loop` prompt; fills the seam left by `quiesce` (which needs the Claude Code `/goal` slash-command). *(This entry also backfills the missing v0.1.0 changelog line — boy-scout.)*
- **v0.2.0 enrichment** — the operator re-handed the prompt as `v3 FINAL (drift-audited)`; a line-by-line cross-read found genuine deltas v0.1.0 lacked, folded in (consolidate, **not** re-create — the skill already existed & was merged):
  - **`--auto-self-*` flag de-theatering** (protocol §3.5) — the operator's `--auto-self-{fix,heal,evolve,aware}` mapped onto EXISTING primitives (REFINE · preflight+Sentinel · boy-scout+capture · Sentinel-health+ASH); explicit anti-theater non-claims (self-evolve ≠ framework mutation → Forge under HITL; self-aware ≠ sentience).
  - **`agents/COWORK-AUTONOMY-POLICY.md` cited as the bands+carve-outs SSOT** (DRY — was re-listed inline) incl. the **≥0.90 "MAY substitute the human / NO-HITL"** band; "safety is a carve-out, not a score dimension".
  - **Three-regime RESOLVE routing** (REFINE/SELECT/DEFER by verifiability) surfaced via `convergence-engine` (protocol §4) + the **33Q × 13-target × 6-section** Socratic map.
  - **ASH loop meta-trace** (PERSIST §6) — per-round observability record (round · score+6-factor · binding factor · regime · roster-delta · n*/stop-reason); the operational form of `--auto-self-aware`.
  - Predicate/DoD nuance: **HARMONIC convergence + STABLE plateau (economic stop n*) + keep-best monotonicity + DEFER residue ~10–15% by design**; `directive-braindump-triage` as alt state-loader; objective tiers.
  - **KIS** (was KISS) — "Keep It Simple" (simple, not simplistic; "smart" is a quality caveat, never a redefinition).
  - **MAOS-specific *Project carries* (scope C)** — a clearly-fenced "drop-when-porting" section in the SKILL: ADR-006 (Proposed) → treat hub-absorption as **HUMAN_DOMAIN** until ratified; MAOS always-on single-conductor → **route** ECC/superpowers/gstack/BASE, never cohabit (cites `protocols/moe-hub-architecture.md` + ADR-006). The generic `gap-loop-protocol.md` stays portable (§7 pointer marks these droppable).
- **No new skill/command, plugin version unbumped** (DRY/Strata; consistent with the other `[Unreleased]` items at `1.16.0` per ADR-003 — plugin version bumps on the release cut). Additive `.md`-only; revertible.

### Added — North Star **proposed**: MAOS as the curated community-integration platform (ADR-007)

- **NEW `docs/adrs/ADR-007-curated-community-integration-platform.md`** — strategic identity: MAOS is the **curated, security-gated, agentically-maintained front-door** to the *vetted best* of the agentic commons — an *index + gate + adapter + guide*, not a re-host. Three faces of one MAOS Hub: **integrator** (inbound discover→vet→adapt→register), **registry** (SSOT), **console** (operator-facing, profile = first-class gating input). Operating model: agentic curation + **human HITL ratification** ("the integrator is built by the agents it integrates"). Fixes 7 non-negotiable guardrails (reject-by-default · no-agent-alone-on-security · real-SPDX-license · adapt-the-adapter-not-the-tool · honor-the-creator · rollback-as-DoD · TTL + hardened-distributor) + the `activation` taxonomy (always-on | default-on-for-context | opt-in | excluded).
- **NEW `docs/vision/maos-integration-platform.md`** — readable (pt-BR) narrative unifying console + integrator + gatekeeper; the discovery+education wedge; the honest "curation-trust-freshness product" reality.
- **NEW `openspec/changes/maos-hub-console/{proposal,tasks}.md`** + **`openspec/specs/maos-hub-registry/spec.md`** — spec-driven contract for the operator control-plane (views: preset · category · use-case · context-aware-v1 · prose-intent · safe-mode; `--help`/`--safe-mode`; 4 console guardrails) and the registry SSOT (`activation`, license/SPDX, provenance/SBOM, ttl, rollback, conflicts_with). Sequenced as WAVE 5–6, after the ADR-006 WAVE-0 safety foundation. Status: Proposed — HITL ratification via PR.

### Added — `agentic-moe-2026` research chapter + **MAOS Hub** architecture (ADR-006 — **ratified Accepted 2026-06-29**; WAVE-0 gating-seam shipped #180)

- **NEW research chapter `research/agentic-moe-2026/`** — a multi-phase deep-research study of the OSS agentic-tooling ecosystem (Claude Code & cross-harness): Phase 0 canonicalization + **mandatory supply-chain gate** (EXCLUDED `gsd-build/get-shit-done` for the `$GSD` rug-pull and `MemPalace` for star-manipulation/benchmark allegations), Phase 1 per-layer landscape (L0–L9, 26 INCLUDED experts, dated/`[sec]` star order-of-magnitude), Phase 2 N-Tree / MoE routing graph, Phase 3 the Agentic Tool Hub (ATH). Plus a consolidated PDF/HTML, an exec deck, NotebookLM/Jira prompts, and an **OODA-RECON** cross-walk of this repo.
- **NEW `docs/adrs/ADR-006-ath-moe-hub-adoption.md`** (Status: **Accepted** 2026-06-29) — **ratified decision**: absorb `agentic-moe-2026` as a MAOS **evolution chapter**, and realize the ATH hub as the **MAOS Hub** — the native MoE gating-network, declared **evolution of `maos-mcp-hub`** (not a new product). **Establishes** the **single-conductor invariant** (no co-resident ECC/superpowers/gstack/BASE/ruflo/BMAD — route via `agentic-tool-intake`, reuse patterns DRY, never stack runtimes).
- **NEW `protocols/moe-hub-architecture.md` + `openspec/specs/maos-hub/spec.md`** — native architecture protocol + as-designed OpenSpec contract (dogfooding MAOS's own L1). The OODA-RECON found MAOS already owns **~70%** of the ATH artifacts (a)–(m): `action-priority`=CTS-Eisenhower, `rbad`/`forge`=expert-profile, `maos-mcp-hub`=ISO/registry, `slm-routing`=model-router, `pii-masking`=proto-AgentShield, `sentinel`=observability, `agentic-tool-lifecycle`=DRY adoption.
- **Gap roadmap (MAOS evolution backlog)** — universal ISO tool-gating, a unified CTS scorer, an L8 memory substrate (mem0 default + graphiti temporal), an OTel exporter for Sentinel, a LiteLLM-backed model router, and AgentShield-grade content security. Hands-on implementation handed off to Claude Code via `research/agentic-moe-2026/20260627-HANDOFF-claude-code.md` (git-worktree GitHub Flow per ADR-004).

### Added — `bitbucket-pipeline-watch` skill — wake-on-completion pipeline watcher + auto failure-diagnosis (`skills/bitbucket-pipeline-watch` v1.0.0 + `bin/bb-pipeline-watch.sh`)

- **NEW skill `bitbucket-pipeline-watch`** (#169) — backgrounds a poll-until-done loop that exits the instant a Bitbucket Cloud build COMPLETES, so the harness re-invokes the agent on the **real** event (event-driven, no public webhook). On FAILURE it returns the **redacted** failure diagnosis (failed steps + error-relevant log tail) already baked in — the agent wakes holding what it needs to act, not just a green/red bit. Pairs with the `maos-mcp-hub` `atlassian_bitbucket` gateway.
- **Secret-safety** — token sourced inside a subshell, used only in an Authorization header, never echoed; all log output passes through `redact()` (AWS temp keys · long base64 · token/password · `bitbucket_api_token`).
- **PDCA-hardened during review** (bot convergence): `mktemp` for the log file (was predictable `/tmp/_bbw_log.$$` — CWE-377) · `--max-time` on every curl (was indefinite-hang risk that would defeat the `--max-polls` cap) · URL-encode the pipeline uuid + `curl -g` (was a globbing/encoding bug) · fail-fast env sourcing (dropped a masking `|| true`) · added the `bitbucket_api_token` redaction pattern (CWE-532).
- **Layer-Purity 0** — genericized example workspace/repo, made `--workspace` required (no hardcoded org default); gitleaks-clean; `version`+`triggers` frontmatter.
### Added — `voice` skill — official on-demand TTS narration for the content-lifecycle family (`skills/voice` v0.1.0 + `bin/speak.sh` + `commands/speak.md`)

- **NEW skill `voice`** (#172) — the **opt-in** audio producer for the eko-system family. Ratified by an operator-eared TTS bake-off (dogfood cycle 002 of `agentic-tool-pipeline`, the operator's ear = the independent verifier per the Convergence-Engine doctrine). Official fallback chain **Gemini 3.1 Flash TTS → ElevenLabs v3 → Kokoro** (local, free).
- **`bin/speak.sh`** — deterministic producer: `auto` fallback chain or forced `--engine`; style presets (narrador/executivo/caloroso/animado/free, encoding the bake-off winners); full overrides (voice/gender/stability/exaggeration/tags/speed/lang). The **HYBRID Voice-Director** rubric lives in the skill (deterministic templates × non-deterministic agent reading context/scope/session-mood), bounded by the faithfulness/tone gate.
- **⚠️ Audio is OPT-IN** — text is the default everywhere; `bin/speak.sh` is **render-only by default** (`--play` opts in) and audio NEVER auto-plays (the operator may be somewhere sound is unwelcome). Consumers pass `--play` on `--media audio-voice`.
- **⛔ Secrets** read from 1Password via the SA-token subshell — never echoed/logged/committed/placed in argv (the key goes in a chmod-600 `curl --config`). Per-operator `op://` item-refs live in a machine-local `~/.config/eko/speak.env` (allowlist-parsed per `script-safety §2`, never blind-sourced) — the committed file carries **zero** operator vault structure; with no config the API engines fall through to **Kokoro** (zero-setup, local). gitleaks-clean.
- **Family wiring (Strata — zero new renderer)** — `opera-debrief --media audio-voice`, `morning-briefing --media=audio-voice`, and `content-recast --format voice` all route to `bin/speak.sh` via the Composition map. Command is `/speak` (renamed from `/voice` to avoid the host's native `/voice` push-to-talk INPUT). **Named via `anima`**; converged through a 3-iteration PDCA (every real bot finding fixed; deterministic oracles — gitleaks/validate/Trivy/pip-audit/governance/snyk — govern over an oscillating probabilistic reviewer).

### Added — `proofread` skill — text-quality pass (grammar pt-BR+en · typos · mis-formatting) (`skills/proofread` v1.0.0 + `commands/proofread.md`)

- **NEW skill `proofread`** (soul-name *Aristarchus*) — the THOROUGH on-demand text-quality pass fired when finalizing any text artifact (doc/ADR/README/ticket-body/PR-description/commit-message). An **ECE composition** (`agentic-first §4.7` — deterministic linters × probabilistic rewrite), builds no new engine: **cspell** (catch-anything spell-check, pt-BR dict — flags novel typos like `Aurona` that grep+codespell miss) + **LanguageTool** (grammar/concordância/acentos, run **LOCAL** — never a public API) + **markdownlint-cli2** (structure) + an optional **Grammar-Genie** rewrite.
- **The cspell≠codespell split (empirically grounded)** — cspell = full-dictionary (catches novel typos, the workhorse); codespell = curated common-misspell pairs (low-noise CI/pre-commit backstop, does NOT catch novel typos). They complement, not compete. Verified: cspell flags `Aurona`, codespell doesn't, LanguageTool flags pt-BR concordância/acentos local.
- **⛔ Privacy guardrail** — LanguageTool's public API uploads text; sensitive content runs LOCAL only (`languagetool` CLI / `--http` / Docker). Secrets/PII/LGPD.
- **Self-describing WHEN** (the amnesic-agent trigger lives in the skill `description`) + thin `/proofread` command surface. **Named via `anima`**; forged via `agentic-tool-forge` discipline. Layer-Purity clean (generic, no Vek/org branding). Origin: akasha text-quality roadmap (`ekson73/akasha-claude` PR #182 + `plans/compressed-enchanting-shamir.md`).

### Added — `corpus-firing-audit` skill — audit a governance corpus FIRING vs THEATER (`skills/corpus-firing-audit` v1.0.0)

- **NEW skill `corpus-firing-audit`** (#163) — audits whether a governance corpus is **alive or theater**: does each rule/memory/instruction actually FIRE at a live decision point, or is it present-but-dormant? Idempotent, read-only P0–P6 pipeline: recon → kind-aware firing classification → recon-readiness sub-check → re-learning detection → Eisenhower-ranked **effectivation** proposals (*sharpen an existing fire-point > add a new passive rule*) → idempotent ledger → verify-and-brief.
- **Firing/vitality counterpart to `directive-braindump-triage`** — that skill triages a *braindump file* (directive → artifact); this one audits the *standing corpus* (artifact → application). Opposite traversal, paired skills (their cross-refs were reconciled in this PR).
- **Kind-aware classification (dogfood-earned)** — classify each artifact by *kind* before verdict: **behavioral-rule** · **decision-record** (ADR — fires by canonical-authority) · **reference/inventory** · **session-artifact**. A low/zero-ref count is THEATER **only** for a behavioral-rule with a should-apply mandate; the other three kinds ⇒ **DORMANT-OK, never THEATER**. Plus a **counting guard** (`grep -ril <slug> | wc -l`, never `grep -cl`).
- **Promoted after the ADR-005 dogfood gate** (≥2 ratified cycles): a user-scope rules corpus (36 rules) + a repo `docs/governance` corpus (80 artifacts). The 2 cycles produced the kind-aware + counting-guard refinements above; the promotion PR is the graduation record (no fabricated 3rd cycle).
- **Layer-Purity 0 violations** (no soul-names / private-repo names / org branding); gitleaks-clean. **Named via `anima`** (`corpus-firing-audit`).

### Added — `directive-braindump-triage` skill — triage a directive-braindump into a provenance ledger (`skills/directive-braindump-triage` v1.0.0)

- **NEW skill `directive-braindump-triage`** (#162; **changelog entry backfilled here** — #162 shipped skill-only) — triages an operator directive-braindump (a `*.braindump.md` / `prompt-aux-N` scratch of mixed directives) against the standing corpus so a future amnesic agent runs **only the verified residual** and never re-processes what is already done. Idempotent: recon-first → decompose into atomic directives → classify each DONE/OPEN/DROP-EXPLICIT/COVERED + the fulfilling artifact → inter-dependency DAG → Eisenhower residual roadmap, emitted as a **provenance ledger**.
- **Cures the re-learning anti-pattern** — a braindump without a provenance ledger gets re-learned; this is the directive-side cure (the corpus-side cure is `corpus-firing-audit`, above).
- **Promoted after the ADR-005 dogfood gate** (2 ratified cycles backfilled from real session analyses). Layer-Purity-clean; `/maos:directive-braindump-triage`.

### Added — `agentic-tool-intake` skill — the ADOPT stage of the agentic-tool lifecycle (`skills/agentic-tool-intake` v0.1.0)

- **NEW skill `agentic-tool-intake`** — fills the empty **ADOPT** slot in the lifecycle family: `forge` (create) → **`intake` (adopt-or-not)** → `evaluator` (score) → `trainer` (improve). Where forge answers *"I have an intent — what do I create?"*, intake answers the inverse: *"someone handed me a tool that already exists (an external repo/MCP/plugin/skill — e.g. a GitHub trend / YouTube review — or an internal proposal) — should I adopt it, and how?"*. Exploration confirmed the gap (~25-30% reuse < the 50% reuse-and-elevate threshold).
- **Thin composer (reimplements nothing)** — 7-phase pipeline (UNDERSTAND → RESEARCH → COMPARE/CROSS → VALIDATE → DECIDE → INSTALL(gated) → RECORD), each phase landing on an existing primitive: research → `agentic-tool-forge`; guarded install + scope/source + trust-tier → `claude-code-concierge`; multi-candidate conflict → `converge`; cycle tracking → `dogfood-ledger`; record/close → `postflight` + `ticket-as-prompt`. Adds **only** the adoption decision-matrix.
- **7-disposition decision-matrix** — `INSTALL · CREATE-INTERNALLY(→forge) · ABSORB · ADAPT · SUB-AGENT · ABANDON · DEFER-HITL`, scored across cost/benefit/features/requirements/install-complexity/blast-radius/conflicts/family-members/collaborations/incompatibilities/redundancy(Strata)/trust-tier([C12]). Governance baked in (concierge CANON C1-C8); install is ALWAYS confirm-gated + dry-run-default; HUMAN_DOMAIN ⇒ DEFER.
- **SSOT update** `protocols/agentic-tool-lifecycle.md` §3 — adds the **intake** stage to the lifecycle diagram + a one-paragraph definition (DRY pointer; payload lives in the skill).
- **Thin command wrapper** `commands/agentic-tool-intake.md` → `/maos:agentic-tool-intake`.
- **Named via `anima`** (`agentic-tool-intake`; rejected runner-up `vet` — under-claims the absorb/adapt/sub-agent/create outcomes).
- **Genesis**: operator `/enhance /deep-research` 2026-06-18 (VKS-2244). **First dogfood** = CodeGraph (`docs/adoption/codegraph-2026-06-18.md`) — a verdict-only run (no install).

### Added — `opendesign-concierge` skill — front-desk for the Open Design platform (`skills/opendesign-concierge` v1.0.0)

- **NEW skill `opendesign-concierge`** (5th member of the cross-vendor **concierge family**: `maos-concierge` · `claude-code-concierge` · `walkthrough-concierge` · `opendesign-concierge`). Teaches + routes the Open Design platform (`nexu-io/open-design` — open-source, agent-native, BYOK design tool). 4 modes: **explain** (teach: `od` CLI · 152 design-systems · BYOK/no-local-LLM · 2 integration tiers) · **onboard** (capability-detect → tier → first command) · **guide** (intent → exact tier + `od` invocation = the "helper" surface) · **audit** (read-only: installed? config drift vs CANON?).
- **Companions (DRY — payload lives here)**: `references/od-knowledge-pack.md` (verified-vs-source `od` CLI / MCP / 152 DS · 109 templates · 11 craft counts / DESIGN.md programmatic application — uncertain MCP snippet flagged honestly) · `references/apply-design-system-runbook.md` (Tier A assets-direct + Tier B `od-code-migration` + Airbnb→vek-list worked example, 34/34 tokens validated) · `AWARENESS-REGISTRY.md` (OD surface + external landscape: Figma Make · v0 · Anima · Banani · Stitch + when-to-use-which) · `CANON.md` (8 canonical decisions: BYOK · don't-reinstall · DESIGN.md-is-contract · Tier-A-default · Docker-not-source · etc).
- **Thin command wrapper** `commands/opendesign-concierge.md` → `/maos:opendesign-concierge` (Sandwich-Namespacing; function-specific filename).
- **DRY / Strata**: modeled on the existing concierge family; **no** duplicate `opendesign-helper` (the `guide` mode already delivers the helper function; a 2nd skill would duplicate ~70% of the knowledge-pack — deferred as a DUED future split only if the do-runbooks outgrow the concierge).
- **Genesis**: operator `/enhance /deep-research`; knowledge verified against the canonical clone + 2 Explore agents + external WebSearch; elevates the one-off vek-list AirBnB POC into a durable, recurring, cross-vendor tool.

### Removed — deferred v1.6.0 hard-removal of the `/status` deprecation alias (`commands/status.md`)

- **Executed the long-overdue v1.6.0 cleanup**: `commands/status.md` (the `/status` → `/agentic-status` deprecation alias shipped in v1.5.1 to dodge the Claude Code built-in `/status` collision) is **hard-removed**. The alias promised removal "in v1.6.0" but persisted through **v1.15.0** — ~10 minor releases past its 1-release window — while the successor `commands/agentic-status.md` was live the entire time. This completes a long-satisfied deprecation contract; bump `1.15.0 → 1.16.0`.
- **Doc surfaces de-referenced** so no live command-discovery surface points at the dead `/status`: `commands/README.md`, `agents/orchestrator.md`, `CLAUDE.md` (plugin tree), `skills/status-map/SKILL.md` (override table), `protocols/delegation/provider-matrix.md`, `skills/maos-concierge/{SKILL.md,AWARENESS-REGISTRY.md}` (collapsed `/status (/agentic-status)` → `/agentic-status`), and the legacy `statusmap/{inference.md,README.md,templates/*.md}` — including the `/s`·`/sf`·`/sd` shorthand **expansion targets** (shorthand names kept; targets re-pointed to `/agentic-status` to avoid a dangling expansion).
- **Preserved as history** (per `[C07b]`): CHANGELOG rename entries, `AGENTS.md` naming-rule that cites `/status` as the cautionary example, and `commands/agentic-status.md`'s "Renamed from `/status`" provenance. The `skills/status-map` *skill* keeps its name (no collision — `-map` qualifier). **Deferred** (noted in #160): dated `docs/*` analysis reports + the `statusmap_templates.md` scope-note (frozen historical artifacts, not live surfaces).
- **Genesis**: KRDR #160 hygiene backlog (operator `/quiesce` 2026-06-20). This was the prior session's mis-assessed "entangled migration" item — recon (verified against `origin/main` @ v1.15.0) corrected it to an overdue tombstone-execution.

## [1.13.0] - 2026-06-13

### Added — Postflight P2.5 TICKET-SYNC + continuation-seed contract v1.1.0 + DNA Geracional propagation (`skills/postflight` v0.6.2 → v0.7.0 · `references/ticket-sync-protocol.md` NEW v1.0.0 · `references/continuation-seed-contract.md` v1.0.0 → v1.1.0)

- **NEW phase P2.5 TICKET-SYNC** (between P2 DEBRIEF and P3 HANDOFF): reconciles the backlog with the session at exit so the "treasure map" (tickets) never diverges from reality. *(a)* bounded gap→ticket triage — anti-theater filter → dedup → Eisenhower Q1-Q4 → file under a **hard cap (≤3 individual tickets + 1 batch housekeeping ticket)**; *(b)* an **idempotent continuation ticket** (search-before-create; body mirrors the seed; provider-relative "relates-to"/child-of linkage); *(c)* enrich the anchored ticket. Bounded-autonomous (HITL only for HUMAN_DOMAIN / unknown-provider).
- **No reinvented ticketing** (anti-over-engineering): all ops are **delegated** to a capability-detected ticketing primitive (reference: the user-scope `ticket-as-prompt` skill, `--op create|update|link|enrich|close|auto`) — the tracker is the state, no custom schema/state-machine. **Capability ladder**: ticketing skill → `gh issue` (GitHub-hosted) → **DEFER(ticket)** (never blocks the exit).
- **Layer purity**: routing is by repo **CLASS** (corporate→Jira · personal→Linear · community→GitHub Issues) via governance discovery — **zero** hardcoded org/project/cloud-id in community code.
- **NEW SSOT** `skills/postflight/references/ticket-sync-protocol.md` v1.0.0 (triage caps · continuation-ticket field-map/linkage · capability ladder · audit trail · anti-patterns).
- **Continuation-seed contract v1.0.0 → v1.1.0** (MINOR — 4 OPTIONAL fields, no REQUIRED/envelope change): `session_type` (`<mode>/<work>`), `dna` upgraded to **string OR object** (`{principles[3], canonical_ref, session_learnings[≤5], learnings_ref}`) so the **DNA Geracional** travels into spawned sessions (not just sub-agents), `continuation_ticket`, `tickets_created`. Registers `skills/preflight` **R0 ANCHOR** as a consumer of `refs.ticket`+`session_type` — closing the `postflight → spawn → preflight` loop.
- **DNA propagation**: P3 populates the `dna` block; the template `resume_instructions` now mandate the resuming agent **internalize `params.dna` + transcribe the 3 principles into every sub-agent briefing**. P2 distils ≤5 session learnings into the seed's `dna.session_learnings`.
- `commands/postflight.md`: new `tickets` action (P2.5) + `TICKETS …` line in the sample output. `protocols/exit-hygiene.md`: new Tickets/Backlog exit-gate row. `skills/postflight/SKILL.md`: 4 new anti-patterns (>3 tickets/cycle · ticket-for-theater · API-in-PreCompact-hook · duplicate-continuation).

### Added — Preflight R0 ticket-anchor + session-type classification (closes #141 · `skills/preflight` + `bin/locus.sh` + `plugin-scripts/governance/preflight-session.sh`)

- **R0 ticket-anchor**: sessions start with deterministic local ticket context (seed `refs.ticket` › branch › last-commit via `locus --density anchor`), **zero-network** and non-blocking, producing a coarse `mode` hint. The full R0 N-Tree walk / classification / create-proposal stays **on-demand** via `/maos:preflight ticket` (the SessionStart hook runs only the deterministic anchor + coarse hint, NOT the full R0 flow).
- **Worktree-safe seed resolution**: linked-worktree `.git` is a gitlink FILE, not a dir — seed lookup now probes per-worktree git-dir (`rev-parse --absolute-git-dir`) → git common-dir (`--git-common-dir`) → `.git/maos` fallback, with `POSTFLIGHT_SEED_DIR` override parity (matches the producer).
- **Provider/org neutrality**: preflight docs/skill routing keeps ticket-provider names (corporate/personal/community) as **non-normative examples** + delegates creation to capability-detected `ticket-as-prompt` (layer-purity).
- Regression coverage: `tests/governance/test-preflight-session-r0.sh` (13 cases incl. real linked-worktree scenario, hi-res sub-second timing) + `bin/tests/locus.test.sh` (39 cases incl. zero-network side-effect-log contract). `skills/preflight/references/session-type-taxonomy.md` added.
- **Merge note (continuity for amnesic agents)**: merged 2026-06-13 (`cf75f7e`) after 2-round CodeRabbit PDCA (5→1→0 findings). The only non-green check was `security/snyk` in **error — "used your limit of private tests"** (quota exhausted, NOT a CVE); merged under HITL-authorized bypass (precedent #133), with security posture covered by gitleaks + Trivy + pip-audit (all SUCCESS). Recurring Snyk-quota blocker tracked in #142.

## [1.12.0] - 2026-06-11

### Added — scorecard dynamic context-based model selector + Model 8 "Briefing Card" (closes #132) (`scorecard.py` 7 → 8 models · NEW `scorecard-select-model.sh` · `scorecard-next-model.sh` 1→7 → 1→8 · `postflight` skill scorecard section)

- **Operator green-light + scope expansion (2026-06-11, issue #132)**: *"mantidos como templates oficiais … usados por decisões seletivas, dinâmicas, automáticas, autônomas e híbridas [deterministicas, não deterministicas] pelo script/agente que for usar"*. All models preserved as official templates; selection becomes dynamic per invocation.
- **NEW Model 8 "Briefing Card"** (`bin/scorecard.py`): the morning-briefing V2 Priority-Triage layout imported as an official scorecard model — above-the-fold 🎯 NEXT + 📍 PULSE callouts, decision-value ordering, empty-section silent omission. Numbered **8** (append-only/open-closed — renumbering 1-7 would break gallery/rubric/state/env refs; 0 is shell-falsy). Aliases: `briefing` · `briefing-card` · `morning-briefing` · `card` · `M8`.
- **NEW `bin/scorecard-select-model.sh`** — the selection-policy front-door. Hybrid deterministic/probabilistic split: the invoking agent distils session factors [contexto · escopo · propósito · objetivo · risco · segurança · impacto · urgência · importância · criticidade · human/agent] into flags (`--audience · --purpose · --items · --open · --risk · --urgency`); the script maps flags → model via a deterministic first-match decision table (R0 env-pin → R1 agent→M6 → R2 briefing→M8 → R3 handoff→M6 → R4 high-stakes→M1 → R5 trivial→M7 → R6 open-heavy→M5 → R7 backlog-heavy→M4 → R8 default→M2). `--explain` names the matched rule on stderr; "no information ≠ trivial" (bare call → M2, not M7); invalid values warn + default (never aborts a debrief; always exits 0).
- **Round-robin PRESERVED as fallback** (`--mode round-robin` delegates to `scorecard-next-model.sh`, now cycling **1→8**) — boy-scout/continuity, not deleted. `POSTFLIGHT_SCORECARD_MODEL` pin = highest precedence in ANY mode (the non-deterministic agent-judgment opt-in).
- Gallery (`skills/postflight/scorecards/gallery.md`): 8-model table + M8 rubric row (90 🥈, scored by analogy at import — recompute after dogfood) + new "Selection" section. `skills/postflight/SKILL.md`: P2 pipeline + "Model selection" section rewritten (dynamic default · round-robin fallback · pin override).
- Tests: NEW `bin/tests/scorecard-select-model.test.sh` (32 cases: decision table · precedence · pin · round-robin delegation+pointer continuity · graceful degradation · `--explain` · output contract); `scorecard-next-model.test.sh` updated for the 1→8 wrap (26 cases).

### Fixed — spawned continuation session never started working (`spawn-continuation` v0.3.0 → v0.4.0 · `postflight` skill v0.6.1 → v0.6.2)

- **Operator report (2026-06-11, attached tmux session)**: the spawned session "was not loaded with the injected prompt". Root cause: `--append-system-prompt` injects the seed as INVISIBLE system context, and the interactive `claude` REPL starts with NO initial prompt — the session sat idle until a human typed something (the opposite of "the work continues itself").
- **Fix — KICKOFF prompt**: the spawn now also passes a short positional prompt (`claude [options] [prompt]` submits it immediately) telling the session to read its continuation seed (persisted at `~/.claude/jobs/<short>/continuation-seed.json` — belt+suspenders if the system-prompt injection is ignored), run `/maos:preflight`, and resume the first non-blocked next-action. Opt-out: `--no-kickoff` flag OR `POSTFLIGHT_KICKOFF=0` (restores the idle spawn). `SEED_FILE` is now resolved before the command build (single definition).
- Tests: `spawn-continuation-name.test.sh` 6 → 9 (kickoff present by default · `--no-kickoff` · `POSTFLIGHT_KICKOFF=0`).

### Fixed — locus session-name quality: anchor never extracted the ticket + redundant slugs (`locus` v1.0.0 → v1.1.0 · `spawn-continuation` v0.2.0 → v0.3.0 · `postflight` skill v0.6.0 → v0.6.1)

- **Root cause (operator report 2026-06-11, real tmux names)**: `bin/locus.sh` set its default ticket regex via `${GEO_TICKET_RE:-[A-Z]{2,}-[0-9]+}` — inside `${var:-default}` the FIRST unescaped `}` closes the expansion, silently producing the broken regex `[A-Z]{2,-[0-9]+}` (never matches). The anchor therefore ALWAYS fell back to the full branch (`🟡 · feature/VKS-2159-poc-openspec · …`). Fixed with a two-step default assignment + a regression test on the DEFAULT regex.
- **Explicit `--ticket` anchor input** (`locus.sh`): new flag, highest anchor salience, accepted only when it matches `GEO_TICKET_RE` (shape-validated — anti-theater). `spawn-continuation.sh` now passes its `--ticket` through (it previously collected the flag and discarded it for the locus path).
- **Slug normalization (signal > noise)**: renderer drops slug tokens the anchor already carries (whole-token, case-insensitive) — `vks-2169-verify` with anchor `VKS-2169` renders `verify`; a branch-derived slug fully covered by a branch-fallback anchor is omitted. Spec section "slug quality + normalization" added (`references/locus-spec.md` v1.2.0 → v1.3.0); P3.5 + `--slug` usage gain slug-quality guidance (2-4 words, work essence, never embed ticket/repo/status).
- Tests: `bin/tests/locus.test.sh` 22 → 32 cases (controlled tmp-repo section: default-regex regression · explicit/malformed `--ticket` · dedupe · separator preservation `. _` · derived-slug omission); `spawn-continuation-name.test.sh` suite stays green.

### Fixed — `postflight-precompact.sh`: invalid PreCompact hook JSON output (D1, HIGH) (`postflight-precompact` v0.1.0 → v0.1.1)

- **Schema fix (2026-06-11)**: the hook's stdout emitted `{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"..."}}`, which is INVALID per the Claude Code PreCompact hook schema — reproduced failure: *"Hook JSON output validation failed — (root): Invalid input"*. PreCompact accepts only root-level output fields (`systemMessage`, `continue`, `suppressOutput`); `additionalContext` is a SessionStart/UserPromptSubmit affordance. Replaced with a root-level `{"systemMessage":"..."}` carrying the same seed-pointer nudge (same `json_escape` discipline; snapshot/stderr behavior unchanged; still never-blocks `exit 0`). Schema rationale documented inline at the emission site.

### Added — continuation-seed CONTRACT + TEMPLATE: the seed shape gets an SSOT (D2) (`postflight` skill v0.5.0 → v0.6.0)

- **NEW `skills/postflight/templates/continuation-seed.template.json`** — a valid-JSON, placeholder-populated template of the P3 `session.continuation` JSON-RPC envelope, EXTENDING the prior inline exemplar with the REQUIRED resume-spine fields: `who_you_are` · `bootstrap_order` (ordered reads) · `inherited_state` (verified facts: branches@sha/env) · `mission` (ordered steps) · `guardrails` · `dod` (binary checklist) · `dag` (what comes after) · `refs` `{git, ticket, memory, session}` · `resume_instructions`. All pre-existing P3 fields (goal, context, git, locus, objectives, done, in_flight, gaps, pendings, undecided, unasked_questions, next_actions, governance_refs, dna) are retained; `data.layer` stays `community`; the seed becomes self-describing via `data.contract`/`data.contract_version`.
- **NEW `skills/postflight/references/continuation-seed-contract.md` v1.0.0** — the field-by-field contract (REQUIRED/OPTIONAL semantics table), best-practices (amnesia premise: seed must be self-contained, zero conversational-memory dependence; sanitization: gitleaks-clean, metadata-only, no secrets/PII; idempotent re-read; verified-not-asserted state; dual-register JSON + optional human-markdown mirror), consumer registry (postflight P3 producer · `spawn-continuation.sh` consumer+minimal-fallback · `postflight-precompact.sh` deterministic-snapshot subset), and independent SemVer versioning.
- **DRY consumer updates**: `skills/postflight/SKILL.md` P3 section now points at template+contract (short inline excerpt kept, full shape no longer inline-only); `bin/spawn-continuation.sh` `read_seed()` fallback gained a contract-note comment pinning its synthesized subset to the template (script logic untouched).

### Added — `spawn-continuation`: D1 locus session-name wiring — the session name IS the geo-location (tool 8 closure) (`spawn-continuation` v0.1.0 → v0.2.0 · `postflight` v0.4.0 → v0.5.0 · `locus-spec` v1.1.0 → v1.2.0)

- **`bin/spawn-continuation.sh` v0.2.0** — the spawned continuation session is now **named with the D1 locus** rendered by `bin/locus.sh` (`<status> · <anchor> · <slug> · #<short>`, e.g. `🟡 · VKS-123 · payment-retry · #a1b2c3d4`), closing the last deferred wiring of tool 8 (locus-spec line-6 "D1 → session `--name` tracked"). New `--status <glyph>` flag (default `🟡`) feeds the Tier-B status; the **anchor stays Tier-A computed** by locus (ticket › PR › branch — anti-theater: never asserted). DRY: the name is rendered by the grammar SSOT renderer, never re-derived.
- **EMOJI-FIRST EXPERIMENT** (operator decision 2026-06-10, supersedes the previously-planned ascii-safe variant): status emoji + middle-dot `·` + spaces are kept **verbatim** in `tmux new-session -s` / `claude --name` — *"testarmos só com ícones primeiro; se eu ver algum problema eu relato"*. The potential problems (tmux unicode target-matching/truncation · terminal-font rendering · path-treating consumers) and the possible solution (ascii 3-letter color token `red|org|yel|grn` + `-` separator) are documented inside the tool (`@note`) per the operator's request. **Escape hatch**: `POSTFLIGHT_NAME_STYLE=legacy` restores the pre-0.2.0 ascii `<ticket>-<slug>-#<short>`; the same legacy shape is the **graceful auto-fallback** when `locus.sh` is absent (zero new hard dependency). Jobs-registry dirs keep using `SHORT` (hex) — filesystem untouched by the emoji name.
- **NEW test suite `bin/tests/spawn-continuation-name.test.sh`** (5/5 green, all via `--dry-run` + isolated `CLAUDE_JOBS_DIR`): D1 default-shape · `--status` propagation · legacy env-style · locus-absent fallback (via the `MAOS_LOCUS_BIN` test seam) · dry-run read-only guarantee. Regression: `locus.test.sh` (22/22) + `scorecard-next-model.test.sh` (full suite) stay green.
- Docs synced: `skills/postflight/SKILL.md` v0.5.0 (P3.5 row + invocation example + fixed a "locus locus" typo) · `skills/postflight/references/locus-spec.md` v1.2.0 (consumer line: wiring **WIRED**, deferred note replaced by the experiment + risk/fallback record).

## [1.11.0] - 2026-06-10

> Consolidated section — covers v1.6.0 through v1.11.0; changelog sections were not cut per-release during this period, so each entry below is annotated inline with the version it shipped in.

### Added — `reveng`: code → OpenSpec SPEC reverse-engineering skill (tool 7 — the genuine net-new) (v1.11.0)

- **NEW skill `skills/reveng/SKILL.md` + `/maos:reveng` command** (named by `anima` — `reveng`, chosen for **epistemology zero-drift** vs the rejected runner-up `code-to-spec`: the ecosystem already calls it "reveng" — a `feature/reveng` integration branch + a `reveng-poc-charter`; `reveng` is also a real established CS abbreviation, e.g. Greg Cook's CRC RevEng tool → not a coinage). Reverse-derives the **as-built behavioral contract** of a codebase as OpenSpec specs: code is a **read-only oracle** (specs never override it — ADR-026 precedence `src > spec > docs`); pipeline = discover capabilities → distill neutral brief (faithfulness anchor) → recast into OpenSpec (`## Purpose` / `### Requirement[SHALL]` / `#### Scenario[WHEN/THEN]`) → **faithfulness check** (every requirement traces to a code/test oracle — no invented behavior) → gap report (cloud-only truth: RLS/triggers/edge-fns) → `openspec validate --specs` → **end-of-reveng score-card** (decision-changing criteria only: coverage · confidence · drift · validate · gaps · idempotency — vanity metrics dropped per the observability discipline).
- **Reuse-and-elevate (Strata), not reinvent**: genuine net-new (maos had no reverse-engineering tool — deliberate sibling-ecosystem gap); the methodology existed **applied-only** in a downstream React+Supabase project (its OpenSpec-adoption + source-precedence ADRs + a 9-capability `openspec/specs/` corpus). `reveng` encodes that as a reusable tool + **inherits the `content-recast` pipeline** (distill→anchor→recast→faithfulness-check→render) adapted from the *audience* axis to the *abstraction* axis. Sibling of `content-recast` in the `spec-lifecycle` family; routes/audits via `openspec-concierge`.
- **Scope-disciplined v0.1.0**: priority pair `src → spec` built fully; other `--from`/`--target` pairs (docs/ADRs/tickets→spec; src→README/AGENTS) are documented roadmap behind a **target-reality (anti-theater) filter** — never re-derive non-drifted docs "because the list allows it".
- **Dogfood cycle 1** (read-only): dry-run on a downstream project's `src/features/kanban` capability → faithfulness-checked against the live oracles (`tickets-store.ts`, `types.ts`, `*.spec.tsx`) → drift ~0% (as-built fidelity) → `openspec validate --specs` **9/9 passed** → 1 cloud-only gap (RLS board-hydration) documented as a limitation. Score-card 🟢. Recorded via `bin/dogfood-mark` (cycle 1, in-progress — self-evaluated, awaiting independent ratification per the ≥2-cycle promotion gate).
- Forged via `agentic-tool-forge`; named by `anima`; 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. Layer-Purity clean (OpenSpec is open-source/universal). Lifecycle handoff `→ /agentic-tool-evaluator` → `/agentic-tool-trainer`.

### Added — `postflight` **P3.5 SPAWN**: autonomous continuation-session launch (tool 5.1) (`postflight` skill v0.1.0 → v0.2.0)

- **NEW `bin/spawn-continuation.sh`** — the P3.5 SPAWN primitive. Consumes `postflight`'s P3 continuation seed and launches a fresh, **named** (`<ticket>-<slug>-#<short>`) detached `claude` session (auto-detect `tmux` → `cmux` → register+print fallback) with the seed injected as durable system context (`--name --session-id --append-system-prompt`) — so the work *continues itself* across the `/compact`/`/clear` boundary instead of waiting on a manual clipboard paste. Registers intent in the `~/.claude/jobs/<short>/{state.json,continuation-seed.json}` convention. POSIX Bash 3.2; jq-free; AAIF cross-vendor. Closes the lifecycle loop `preflight → work → postflight → (spawn) → preflight …`.
- **`skills/postflight/SKILL.md` v0.1.0 → v0.2.0 (MINOR)** — adds P3.5 SPAWN as an **optional, default-ON** phase after P3 HANDOFF (`SWEEP → DEBRIEF → HANDOFF → [SPAWN]`), `DoR(SPAWN)=P3 seed`. **7 guardrails** (high-blast — a real session burns tokens): kill-switch `POSTFLIGHT_SPAWN=0` · once-per-source-session idempotency marker · anti-recursion `POSTFLIGHT_SPAWN_DEPTH` cap (default 1) · capability-detect graceful-noop · seed secret-sanitization (refuses to inject secrets) · audit-trail · `--dry-run`. Composes (does **not** reinvent) the P3 seed + `session-fission`'s reseed idea. `/maos:postflight` command surfaces `--spawn`/`--no-spawn`/`--dry-run` + the `POSTFLIGHT_SPAWN*`/`MAOS_SPAWN_LAUNCHER` env vars.
- **Architecture invariant**: the context>N% auto-fire is a **live-agent skill-level** condition; the deterministic PreCompact shell hook stays snapshot-only and **never spawns** a token-burning session (anti-pattern #5/#9). Operator-authorized default-ON spawn (this session's `/enhance` directive).
- Reuse-and-elevate (Strata): tools 1-5 of the operator's spec were already covered by `preflight` (1-3) + `postflight` P1/P2/P3 (4-5); P3.5 is the one genuine gap (tool 5.1) — built as the next layer, not a rebuild. Cross-vendor / Layer-Purity: `bin/check-layer-purity` clean; `bash -n` + guardrail dry-runs green.

### Added — `postflight`: end-of-session lifecycle skill (exit-hygiene sweep + amnesic continuation seed) (v1.11.0)

- **NEW skill `skills/postflight/SKILL.md`** (named by `anima` — `postflight`, the end-of-session counterpart to `preflight`; together they bound the session: `preflight → work → postflight`). Three responsibilities, **safe-or-DEFER**: **(P1 SWEEP)** operationalizes `protocols/exit-hygiene.md` — surveys git / docs / ADRs / changelogs / memories / rules / tickets / worktrees, classifies by Eisenhower, **acts or registers** a tracked follow-up (read-before-discard mandatory; never clobbers a dirty tree / divergence-with-conflict / held `.git/index.lock`); **(P2 DEBRIEF)** calculates the session map by composing `morning-briefing` (its 7-section state) + synthesizing on top the objectives N-Tree + Eisenhower next-actions + gaps/pendings/undecided; **(P3 HANDOFF)** emits an **ai-agnostic continuation seed** (JSON-RPC-style agent-register envelope + human mirror) a fresh amnesic agent can resume from, printed + best-effort clipboard, `DoR(HANDOFF)=SWEEP+DEBRIEF`. Composes (does **not** reinvent) `exit-hygiene`, `sync-to-git`, `quiesce`, `morning-briefing`, `session-fission`, `commands/worktree`, `bin/dogfood-mark`. `/maos:postflight` command wrapper added (`commands/postflight.md`; subcommands `sweep` | `debrief` | `seed` | full).
- **NEW hook `plugin-scripts/governance/postflight-precompact.sh`** (PreCompact) — a **deterministic safety-net snapshot**: fires before `/compact` / `/clear` (and auto-compaction at high context — the "context > N%" case), writing a factual git/session continuation-seed snapshot inside the repo's git dir (git-ignored — never dirties the working tree; + a durable audit copy) so continuity never fully fails even if the skill was not invoked. **Never blocks** (exit 0 always); **does NOT fake the agentic synthesis** (deterministic skeleton; the rich seed is the skill's job — probabilistic muscle). Registered under a new **`PreCompact`** event in `hooks/hooks.json`. Env: opt-out `POSTFLIGHT_NO_AUTOSNAPSHOT=1`; opt-in PR-fetch `POSTFLIGHT_SNAPSHOT_PRS=1`; dir override `POSTFLIGHT_SEED_DIR`.
- **`skills/preflight/AUDIT.md`** — reuse-verification documenting that `preflight` v1.1.1 already satisfies the start-of-session responsibilities (branch-detect-without-interfering · heal-from-origin · worktree-on-mutation), so `postflight` **composes** rather than duplicates them (DRY / reuse-first). Closes #118.
- Cross-vendor / Layer-Purity: `bin/check-layer-purity` clean (0 operator/vendor strings); `bash tests/validate-plugin.sh` green; PreCompact hook dogfood-tested (valid JSON-RPC snapshot, exit 0).

### Added — `anima`: sovereign precision-naming engine (the namer — forge Phase-4 delegate + standalone) (v1.11.0)

- **NEW skill `skills/anima/SKILL.md`** (+ `kb/{_index,agentic-tools,brand-product,databases}.md`) — the ecosystem's single naming engine: turns "name this X" into ONE sovereign, research-grounded name for anything (directory · file · variable · DB table/column · protocol · skill/command/agent/mcp/plugin · product · manifesto · …). Research-first (web before pronouncing; re-research on gap; HITL-with-ranked-options only on a genuine data gap), a **Register Gate** (machine · agent · human) that routes warmth, a **12 CORRECTNESS + 4 RESONANCE** scorecard, 33-Socratic interrogation, sub-adapters + a self-extending `kb/`, and **envelope-safety** (machine system-name vs optional human soul-name). Returns a decided name + scorecard + rejected runner-up + citations — **not a menu**. `/maos:anima` invocation; standalone or as the forge's naming step.
- **`agentic-tool-forge` Phase-4 now delegates naming to `anima`** (with the existing 5-axis as the inline fallback when anima is unavailable) — completing the documented **body↔soul** pairing (the forge shapes the body; `anima` breathes the name). DRY: ONE naming engine for the whole `forge → evaluate → train` lifecycle.
- Cross-vendor / Layer-Purity: `bin/check-layer-purity` clean (0 operator/vendor strings — corp-specific example namespaces genericized to neutral placeholders on promotion); AAIF (Claude/Cursor/Codex/Copilot/Gemini/Aider). Promoted from user-scope (`anima` v1.0.0); its predecessor `nomenclator` deliberately **not** promoted (redundant — `anima` supersedes it).

### Fixed — `preflight` cross-session layer robustness (v1.10.1)

- **`peer-session-detect.sh`** — `${HOME:-}` guard so an unset `HOME` under the hook's `set -u` can never trigger an unbound-variable exit (resolves to UNKNOWN instead, preserving the never-blocks contract). Coerce a non-numeric `MAOS_PEER_FRESH_SECS` (e.g. `"90s"`) to the default `90` so it can't break the `-le` arithmetic under `set -e`. (PR #116 review — Copilot + Qodo.)
- **`skills/preflight/SKILL.md` → v1.1.1** — section heading "The 3 Responsibilities" → "The Responsibilities (R1–R3, + optional R1.5)" to match the 4-row table (Copilot review).
- **`tests/governance/test-peer-session-detect.sh`** — added a non-numeric `MAOS_PEER_FRESH_SECS` regression assertion.

### Added — `preflight` cross-session layer: peer-agent awareness (v1.10.0)

- **NEW lib `plugin-scripts/governance/lib/peer-session-detect.sh`** (named by `anima` — `peer-session-detect`/`psd_`, deliberately NOT `git-*` because it is a host-concurrency signal, not a git primitive; `git-safe-sync.sh` explicitly excludes host-specific signals, so they live here, kept separate). The **R1.5** cross-session layer of `preflight`: detects OTHER live agent sessions (peers) writing the **SAME checkout** so the session-start hook can **DEFER R2 (heal/pull)** while a peer is active — closing the gap R1's worktree-locks don't cover (same-cwd/same-branch peers, which `.git/index.lock` only catches at the instant of a write). **Optional + capability-detected + gracefully-degrading**: one ships an agent-session-transcript-mtime backend keyed by the working-tree path (self-excluded, freshness-windowed); when no backend resolves (off-host / dir unresolved) it returns `UNKNOWN` and callers treat that as report-only (**never over-defer** → stays useful on Cursor/Codex/Copilot/Aider). READ-ONLY; **never blocks**. Env seams: `MAOS_PEER_SESSION_DIR` (explicit override / portability seam), `MAOS_PEER_PROJECTS_DIR`, `MAOS_PEER_FRESH_SECS` (default 90), `MAOS_SELF_SESSION_ID`. Functions: `psd_peer_sessions` · `psd_status` (`BUSY_PEERS <n>` | `QUIET` | `UNKNOWN`) · `psd_repo_busy_by_peers`.
- **`preflight-session.sh` → v1.1.0** — composes the new lib at the orchestration layer (graceful if absent): computes peer status after R1, **DEFERs R2 when peers are active** (`heal=DEFERRED peers-active(<n>)`), and surfaces `peers=<n>|unknown` in the human line + SessionStart `additionalContext`. The pure-git `git-safe-sync.sh` is **unchanged** (its "no host-specific session signals" invariant is preserved — peer-detection composes on top, it is not injected into the pure-git lib).
- **`skills/preflight/SKILL.md` → v1.1.0** — documents R1.5, the capability-detection + graceful-degradation contract, the env seams, and the honest subdir-cwd limitation; adds the new lib to the Components table.
- **NEW test `tests/governance/test-peer-session-detect.sh`** — capability-detection (missing dir → `UNKNOWN`), fresh-peer counting with self + stale exclusion, empty-dir → `QUIET`, exit-code predicate, path-encoder. Existing governance suite unchanged (regression-clean).
- Cross-vendor / Layer-Purity: the host name appears only inside an env-driven, capability-detected optional backend (the established `morning-briefing` "no hardcoded vendors" pattern); `bin/check-layer-purity` clean.

### Added — `preflight`: governance-aware session/action bootstrap bundle (v1.9.0)

- **NEW skill `skills/preflight/SKILL.md`** (named by `anima`) — the governance-aware orchestrator for the three pre-work readiness steps, run at the start of a session/action: **(R1)** detect the right branch *without interfering* with other agents/sessions/worktrees, **(R2)** safely *heal* the current branch from origin, **(R3)** *isolate* file mutations in a worktree (lazily — only when about to create/update files). Reads whatever governance is present at invocation (`CLAUDE/AGENTS/CONTRIBUTING/README/protocols/memories`) and adapts the branch/worktree conventions rather than hardcoding. Composes (does not reinvent) `worktree-policy`, `/maos:worktree create`, `worktree-utils.sh`. `/maos:preflight` command wrapper added (`commands/preflight.md`).
- **NEW libs (pure git primitives, Layer-Purity clean, no host-specific signals)**:
  - `plugin-scripts/governance/lib/git-branch-detect.sh` (R1, **read-only**) — current branch / `@{upstream}` / ahead-behind / branches **locked by other worktrees** (`git worktree list --porcelain`) / tree-state {CLEAN·DIRTY·DETACHED·MID_REBASE·MID_MERGE}.
  - `plugin-scripts/governance/lib/git-safe-sync.sh` (R2, **safe-or-DEFER**) — `fetch` → classify → act: `merge --ff-only` (clean-behind) · `rebase --autostash` (clean-diverged) · **DEFER** (dirty / detached / mid-op / diverged-conflict→`rebase --abort` / `.git/index.lock` held). Never `--force`, never clobbers uncommitted or concurrent work.
- **NEW hooks**:
  - `plugin-scripts/governance/preflight-session.sh` — **SessionStart** (R1+R2). Reports branch situation + safe-heals; injects a concise `additionalContext`; **never blocks** the session. Opt-out `PREFLIGHT_NO_AUTOHEAL=1` (report-only).
  - `plugin-scripts/governance/preflight-edit-gate.sh` — **PreToolUse:Edit\|Write\|MultiEdit** (R3 safety-net). When about to mutate a file in the MAIN checkout, recommends isolating in a worktree. **WARN by default** (surfaces guidance, never blocks); `PREFLIGHT_EDIT_GATE=block` enforces (exit 2, JSON-RPC `-32003`), `=off` disables. Exempt: `.worktrees/*` edits, append-only `tasks.md`/`sessions.json`, non-git / outside-repo.
  - `hooks/hooks.json` — registers both (SessionStart append; new `Edit|Write|MultiEdit` PreToolUse matcher).
- **Verified**: R1 correctly flags `main` as locked-by-another-worktree (non-interference); R2 dry-run across all 6 states (HEALED_FF · UP_TO_DATE · HEALED_REBASE · DEFER-conflict-with-HEAD-restored · DEFER-dirty · DEFER-detached); edit-gate WARN/block/off/exempt paths; Layer-Purity 0 violations; `validate-plugin.sh` PASS; all scripts `bash -n` clean.
- **Plugin bump** 1.8.1 → 1.9.0 (MINOR — additive feature bundle: 1 skill + 1 command + 2 hooks + 2 libs).

### Added — Agentic Session Harness (ASH) engine (Layer-1 community promotion)

- **Promoted the generic, vendor-neutral session-observability engine** from a host product (vek-im/vkl-rct-list-web) per the operator's documented Track A rename-map. Layer-Purity clean (verified by `bin/check-layer-purity`). New:
  - `skills/agentic-session-harness/` — self-contained engine bundle: `SPEC.md` (FROZEN-17 schema), `bin/agentic-{walkthrough,decisions,decide,reindex,fix-dangling-symlinks}` (renamed from `ash-*`), `hooks/{link,resume,stop-fallback,decide-merge,lib}.sh` (dropped `ash-` prefix). CLIs source `../hooks/lib.sh` relatively. Smoke-tested: lib loads + all CLIs run `--help`.
  - `skills/walkthrough-concierge/` — teach/route/anchor concierge over the engine (sibling of `maos-concierge`); de-coupled from org-specifics.
  - `skills/decision-capture/` — WHEN to call `agentic-decide`.
  - `bin/check-layer-purity` — Layer-Purity verification utility.
- **Opt-in activation**: hooks ship as files (NOT auto-wired) so ASH never forces journaling on consumers.
- **Sentinel coexistence**: ASH journals (`.claude/audit/<YYYY-MM>/<DD>.jsonl`) and Sentinel traces (`session_*.jsonl`) share the sink without collision — complementary (decision-audit vs anomaly-guard).
- **Promotion note**: accelerated past the dogfood gate via explicit operator override 2026-06-02 (audit-trailed); the Vek corporate Layer-2 overlay promotes separately to the private toolkit.

### Fixed — README install/config/usage drift (docs-only)

- **Installation commands were incorrect and would fail if followed**: README used `claude plugins marketplace add` / `claude plugins install multi-agent-os` (`claude plugin`/`claude plugins` are valid aliases — the real breakage was the wrong artifact name + invalid settings shape, both corrected below) and the wrong artifact name (`multi-agent-os` is the **repo**; the **plugin is `maos`** per `plugin.json`). Corrected to the official in-session `/plugin marketplace add ekson73/eko-claude-plugins` + `/plugin install maos@eko-claude-plugins` (verified against code.claude.com/docs), with the `/maos:<name>` namespace clarified, `claude --plugin-dir`/`claude plugin validate` for local dev, and a corrected **project/team** block using `extraKnownMarketplaces` + `enabledPlugins` in `.claude/settings.json` (the prior `{"plugins":["/path"]}` shape was invalid). Same fix applied to `install/DEPRECATED.md`.
- **Stale capability tables refreshed**: README listed 6 commands / 11 skills / 9 agents; the plugin now ships ~15 / 40+ / 20+. Tables relabeled as **representative** with a pointer to `/help`, `/agents`, and `/maos:maos-concierge` (drift-resistant — avoids re-enumerating a fast-moving catalog). `/status` → `/maos:agentic-status` (the rename that resolved the Claude Code built-in `/status` collision). Plugin-structure tree counts corrected.
- Docs-only; no code, manifest, or version change.

### Added — `dogfood-mark --backfill` manifest replay (v1.8.1)

- **`bin/dogfood-mark --backfill <manifest.jsonl>`** — implements the spec §6 Phase-2 backfill (manifest path): batch-replays an evidence-bearing JSONL manifest (one `{tool,cycle_id,status?,ratified?,evidence[]?,note?}` object per line), **re-invoking `dogfood-mark` per row** so all existing validation, the anti-theater `complete`-requires-`ratified`+`evidence` gate, idempotency, and the atomic lock are reused (DRY — no logic duplicated). **Anti-hallucination**: a `complete` row without evidence is REFUSED and tallied as failed — the ≥2 gate is met by **real history, never inflation**. `--dry-run` supported; blank/`#`-comment lines skipped.
- **NEW fixture** `docs/dogfood-backfill-example.jsonl` — honest manifest recording the `convergence-engine` tool's real cycles (001 complete = materialization PR #104; 002 in-progress = first executable dispatch PR #106). Tally is truthful (`1/2`, gate NOT-yet-met) — the fix makes counting *real*, it does not game the gate. Closes the operator-flagged "cycle counting was theater (nobody tallied)".
- **Honest scoping**: Phase 2.1 (auto-*deriving* a manifest by scanning ASH journals / changelogs / transcripts) is **deliberately deferred** — that heuristic prose-scanner is a separate, riskier effort and must not be faked. Spec §6 updated to reflect implemented-vs-deferred.
- **Plugin bump** → 1.8.1 (PATCH — additive flag on an existing primitive; stacks on the v1.8.0 `convergence-guard`).

### Added — `convergence-guard` deterministic master-condition gate (v1.8.0)

- **NEW executable** `bin/convergence-guard` — emits a deterministic `ALLOW` / `REFUSE` verdict (exit `0` / `3`, jq-parseable JSON) for a REFINE/SELECT convergence loop **before it runs**, enforcing the two CHECKABLE proxies of the `convergence-engine` master condition: (1) **verifier > generator** → prefer a deterministic oracle (`f=0`); a clean+passing oracle on a high-confidence output REFUSES the loop (selectivity gate — the self-critique paradox, Huang 2024); (2) **verifier independent** → a same-axis/same-brand verifier is REFUSED (correlated blind-spots). Fail-safe: missing/ambiguous inputs → REFUSE (enum validation + oracle/result dependency). **Independence by correlation-class** — same-brand peers (`claude-opus` vs `claude-sonnet`, `gpt-4` vs `gpt-4o`) REFUSE, not just identical tags; structured axis tags keep their discriminator. Built-in `--self-test` (12/12 assertions = its own deterministic oracle). POSIX Bash 3.2 + jq, Layer-Purity-clean.
- **Why** — closes the gap where the engine's master condition was *documented* but **model-judged**; the gate is now **deterministic-harness-enforced** (matching the existing "stopping is deterministic-harness-enforced, never model self-judgment" invariant). Honest scoping: it enforces the two structural proxies, it does NOT fabricate an accuracy measurement it cannot observe at runtime (anti-theater).
- `skills/convergence-engine/SKILL.md` Protocol Rules gain the mandated `convergence-guard` call (size kept < 12288B repo convention). First real executable dispatch of the engine (routing this very work-set) = the empirical R8 closure.
- **Plugin bump** 1.7.0 → 1.8.0 (MINOR — additive executable + enforcement).

### Added — `convergence-engine` skill + 3 dependent agents (v1.7.0)

- **NEW skill** `skills/convergence-engine/` (`SKILL.md` + `PRIOR-ART.md`) — an iterative multi-agent quality-convergence engine: a **deterministic harness × probabilistic cognition** kernel that routes one of three regimes by verifiability — **REFINE** (self-improve loop) · **SELECT** (best-of-N / debate→converge) · **DEFER** (HITL) — under a non-negotiable **master condition** (`verifier_accuracy > generator_accuracy` AND verifier independent) and a closed-form **economic stop** (`n* = 1 + ⌈ln((1−ρ)·g₀·V/C)/ln(1/ρ)⌉` → robustly ≤3–4 rounds). Floor = human-parity (~90%, NOT 100%); the 10–15% HITL residue is by design.
- **NEW agents** (the engine's probabilistic primitives, ported vendor-neutral): `agents/perspective-trio.md` (3 parallel orthogonal lenses — SELECT/breadth), `agents/cascade-resolver.md` (N sequential diverse score-uplift attempts + 8 termination conditions = economic-stop — REFINE), `agents/persona-pipeline.md` (6-stage risk-scaled review board → `certainty` — vertical-depth verify).
- **Anti-over-engineering / DRY**: the engine **composes existing primitives, builds NO new engine** — SELECT routes to the existing `skills/converge/`; deterministic layer reuses the `CONTRIBUTING.md` bot-convergence gate + hooks + git. Self-critique-paradox guard: never loop on a clean high-confidence output (Huang et al. 2024). `skills/converge/SKILL.md` gains a bidirectional cross-ref (converge = the SELECT-regime synthesizer under the engine).
- **Vendor-neutral (MIT, layer-pure)**: zero corporate/vendor-specific naming; portable across Claude Code / Cursor / Codex / Gemini CLI / Copilot. Research-grounded (Self-Refine Madaan 2023 · Huang 2024 self-correction limits · Reflexion · CRITIC · Multiagent-Debate Du et al. 2024) — see `PRIOR-ART.md`. Related auto-orchestration agents (`best-fit-router`, `agent-forger`) intentionally NOT bundled (YAGNI — not dispatched by the engine).
- **Plugin bump** 1.6.0 → 1.7.0 (MINOR — additive skill + agents).

- **docs(branching)**: documented GitHub Flow (Class B) model in `AGENTS.md` (SSOT) + `ADR-004`; added GEMINI.md / Copilot pointers; README badge. Companion to ADR-003 (source float).

### Added — `maos-concierge` skill (v1.6.0)

- **NEW skill** `skills/maos-concierge/` (SKILL.md + `AWARENESS-REGISTRY.md` + `CANON.md` + `references/socratic-33q.md` + `dashboard.html`) — a single onboarding/guide/anchor entry-point over the entire MAOS framework (agents · skills · commands · protocols · governances). **6 modes**: `explain` (teach), `onboard` (guided newcomer ramp), `guide` (intent → right tool + runbook), `audit` (read-only MAOS-compliance), `anchor` (surface canonical decisions + flag drift), `dashboard` (ASCII onboarding-map + optional self-contained HTML companion).
- **Anti-over-engineering / DRY**: ROUTES + TEACHES + ANCHORS over existing tools — reimplements NOTHING, wraps no skill/MCP, forges no agent (routes TO The Forge), mutates nothing in audit/anchor. Self-executed the Forge 33 Socratic Questions → `references/socratic-33q.md` (the spec).
- **Vendor-neutral (MIT, layer-pure)**: no corporate/vendor-specific content — portable across Claude Code / Cursor / Codex / Gemini CLI / Copilot. Sibling (cross-vendor concierge-family pattern) of `specdd-concierge` / `vek-concierge` (Vek layer) / `atlassian-concierge`.
- **Plugin bump** 1.5.2 → 1.6.0 (MINOR — additive skill). Origin: operator `/enhance` 2026-05-28.

### Added

#### `agentic-tool-evaluator` + `agentic-tool-trainer` — close the create→evaluate→train loop

- **NEW skills** (Agent Skills standard, AAIF cross-vendor): `skills/agentic-tool-evaluator` (behaviorally evaluate/score/QA any agentic-tool — skill/agent/command/prompt/MCP-tool — via with/without control + 0–5 rubric; read-only `EVAL-REPORT` + `--json`) and `skills/agentic-tool-trainer` (reflect-loop improvement `trace→reflect→distill` with Pareto guard + bounded iterations, **plus** distill-a-new-tool-from-an-observed-task mode → `WALKTHROUGH` + draft hand-off).
- **NEW shared reference** `protocols/agentic-tool-lifecycle.md` — taxonomy, AAIF frontmatter contract, behavioral-eval method (golden-set + with/without + rubric, NOT code unit-testing), reflect-loop training method, `--json`/`_agent_feedback` envelope, **Rovo bridge** (SKILL.md→Forge `rovo:agent` codegen — Rovo does not consume SKILL.md natively), DUED sunset.
- **DRY/SSOT**: NO redundant "creator" skill — authoring already lives in `skills/skill-writer` (skills) + `agents/forge.md` (agents, incl. 33 Socratic Q + Goldilocks + KPI). The creator-need "observe task → distill skill" is folded into trainer `distill` mode. Reuses `forge.md` KPI scale; composes with `rule-quality-tests` + `qa-validator` + `operator-quote-capture`.
- **Honest scoping**: "test" = behavioral eval (not code unit-test); "train" = reflective prompt-optimization (DSPy/GEPA/SIMBA lineage). Gamification + collaboration/share-results explicitly deferred to v2 (YAGNI). Design spec: `docs/specs/2026-05-28-agentic-tool-evaluator-trainer-design.md` (33 Socratic Q+A per skill).

#### `quiesce` — session-quiescence agentic-tool (compose /goal + pluggable driver)

- **NEW skill** `skills/quiesce/SKILL.md` + **NEW command** `/quiesce` — thin preset that drives the current session to QUIESCENCE (no open ticket/gap/fix/failure/PR, every PR green + answered, agentic convergence) by composing the native `/goal` condition-loop with a pluggable inner driver (default `auto-pilot`, in-repo; `--driver=auto-orchestrator` for the operator's user-scope stack). PDCA-converges open PRs and auto-files tracking tickets for out-of-radar gaps.
- **Override flags**: `--scope`, `--condition`, `--driver`, `--auto-merge`, `--auto-merge-reason`, `--auto-fix`, `--self-fix`, `--autonomy-threshold`, `--max-pdca`.
- **DRY/SSOT**: reimplements nothing — sibling to `auto-pilot` (single-goal delegation kernel); reuses STOP-marker grammar + Sentinel bounds + worktree-policy.

#### `session-fission` — on-demand, non-destructive tangled-session splitter (v1.6.0, MVP v0.1.0)

- **NEW skill** `skills/session-fission/SKILL.md` — splits one tangled Claude session (an N-Tree of atomic contexts collapsed into a single linear transcript) into clean, focused, atomic-context sessions via **non-destructive distill-and-reseed**. Relieves context bloat, cognitive overhead, and token exhaustion. The source session is **archived, never mutated or deleted** (recoverable via native `/resume`).
- **NEW command** `commands/session-fission.md` — `/maos:session-fission [transcript.jsonl] [--apply]` (dry-run by default).
- **NEW scripts** `plugin-scripts/session-fission/` — `inventory.sh` (READ-ONLY transcript → atomic-context N-Tree JSON), `snapshot.sh` (backup + manifest + gitleaks = rollback anchor, idempotent by SHA), `seed.sh` (Ticket-as-Prompt seed scaffold per cluster; agent fills the distilled context).
- **NEW spec** `docs/specs/session-fission-spec.md` — feasibility verdict, option analysis (A/B + C/D/E), algorithm, data shapes, safety contract.
- **Feasibility (validated vs `code.claude.com/docs/en/sessions` + on-disk transcript schema)**: native `/branch`/`--fork-session` *copy* the whole conversation (don't relieve bloat); surgical mid-message trimming is unsafe (append-only `parentUuid` DAG + paired `tool_use`/`tool_result` ⇒ unresumable). Fission fills the gap: distill each atomic context into a light seed and reseed, preserving the original.
- **Safety**: read-only on source; snapshot before any archive; idempotent; rollback via `/resume` + retained backup. Layer-pure (generic; backup/seed dirs env-configurable; no operator-specific content).
- **Deferred**: v2 automated spawn + CPT `topology.md` emission + rollback command; v3 sentinel anomaly rule + status-map template + morning-briefing/auto-orchestrator deep wiring.

#### `founder-*` family — Anthropic Founder's Playbook converted to agentic-tools

- **NEW skills** (Agent Skills standard, vendor-neutral): `founder-playbook` (lifecycle router + `references/product-matrix.md`), `founder-stage-idea`, `founder-stage-mvp`, `founder-stage-launch`, `founder-stage-scale`. Each stage skill carries its goal, exit-criteria gate, failure modes + mitigations, and ready-to-use exercise prompts / emittable templates.
- **NEW agent**: `founder-coach` — delegatable "founder as orchestrator-of-agents" coaching persona (stage diagnosis + exit-gate review).
- **NEW command**: `/founder-playbook` — thin wrapper over the router skill.
- **Origin**: framework adapted (process & methodology, original prose, attributed — no verbatim copy) from Anthropic, *The Founder's Playbook: Building an AI-Native Startup* (2026-05-14, https://claude.com/blog/the-founders-playbook). Capability classes are vendor-neutral (conversational-research / agentic-coding / workflow-automation) with Claude (Chat/Code/Cowork) as the reference implementation. Resolves #85.

#### Sandwich Namespacing — `command_namespace` + `vendor_reserved_audit` in plugin.json (v1.5.2)

- **NEW `.claude-plugin/plugin.json` `command_namespace` block** — declarative prefix `maos:` for commands (Layer 2 of Sandwich Namespacing 5-layer pattern). Forward-compat: when Claude Code runtime supports `command_namespace` declaration, commands surface as `/maos:<name>` preventing cross-plugin collision. Until runtime supports, Layer 3 (function-specific filename) handles disambiguation.
- **NEW `.claude-plugin/plugin.json` `vendor_reserved_audit` block** — Layer 4 reference pointing to canonical vendor-reserved-words list at [ekson73/vek-dot-claude:docs/vendor-reserved-words.md](https://github.com/ekson73/vek-dot-claude/blob/main/docs/vendor-reserved-words.md) (36+ Claude Code built-ins + Cursor/Copilot/Aider/Gemini/Goose).
- **Origin**: empirical observation 2026-05-21 — `commands/status.md` collided with Claude Code built-in `/status`. Layer 3 fix shipped v1.5.1 (rename to `agentic-status`); Layer 2 + Layer 4 reference shipped here v1.5.2.

### Changed

#### AGENTS.md §34 + §73 refinement — Sandwich Namespacing rationale split (v1.5.2)

- **REFINED §34 Naming rule**: split into 2 statements — skills+agents (no `maos-` prefix in filename — runtime auto-namespaces) vs commands (use function-specific filenames + manifest `command_namespace` block — runtime auto-namespace empirically unreliable). Cites empirical collision evidence + vendor-reserved-words list.
- **REFINED §73 Architecture decision**: same split + cross-reference to sister-PR `ekson73/vek-dot-claude#54` (vendor-words list, Sandwich Layer 4).

#### Command `status` → `agentic-status` (v1.5.1 — naming collision fix)

- **RENAME** `commands/status.md` → `commands/agentic-status.md` to resolve empirical collision with Claude Code built-in `/status` (observed 2026-05-21; built-in surfaces session/model/auth metadata, not agentic-system state)
- **DEPRECATION ALIAS**: `commands/status.md` retained for 1 release with deprecation warning + redirect to `/agentic-status`; hard-removed in **v1.6.0**
- **Sandwich Namespacing pattern** Layer 3 (function-specific filename) — paired with companion PRs:
  - PR-3 manifest extension (`.claude-plugin/plugin.json` `command_namespace` block — Layer 2)
  - Companion vendor-reserved-words list (sister-PR [ekson73/vek-dot-claude#54](https://github.com/ekson73/vek-dot-claude/pull/54), merged — Layer 4 audit reference)
  - AGENTS.md §34/§73 refinement (Layer 5 convention/docs)
- **Unchanged**: `skills/status-map/SKILL.md` already has `-map` qualifier; no collision risk; remains invocation target of `/agentic-status`
- **Refs**: Sister-PR (vendor-words audit list — Sandwich Namespacing Layer 4) at [ekson73/vek-dot-claude#54](https://github.com/ekson73/vek-dot-claude/pull/54) (merged 2026-05-21)

### Added

#### Skill `auto-pilot` v0.1.0 — Autonomous unattended orchestration entry point

- **NEW `skills/auto-pilot/SKILL.md`** — thin orchestration kernel that composes existing primitives (`delegate-governance`, `converge`, `agent-select`, `delegation-{init,dna,finalize}-prompt.md`, `sentinel/`) into a single goal-level entry point. No new agents, no new hooks, no new protocols beyond the DNA payload v1.1 block.
- **NEW `commands/auto-pilot.md`** — operator-facing command surface: `/auto-pilot "<goal>" [--mode=<mode>] [--band=L1|L2|L3] [--max-depth=2]`.
- **Delegation modes**: `sequential`, `parallel`, `recursive`, `debate-converge`, plus `dueto` / `swarm` naming sugar over `parallel`.
- **Autonomy bands** `L1-cautious` / `L2-bounded` (default) / `L3-extended` — keyed off the existing rejection-conditions list in `delegation-init-prompt.md`; no new tunables.
- **Anti-loop invariants** reused from `agents/orchestrator.md` with depth tightened to ≤ 2 for unattended runs.
- **Validation**: `tests/dogfood-auto-pilot.sh` (2 scripted cycles, no real Task spawns) + new assertions in `tests/validate-plugin.sh` (frontmatter, 12 KB size ceiling, reciprocity link).

#### Protocol `delegation-dna-prompt.md` v1.0 → v1.1 — additive DNA Payload block

- **NEW "DNA Payload v1.1 (auto-pilot, optional)" section** — emitted by `auto-pilot` when driving multi-spawn goals. Fields: `parent_agent_id`, `depth` (hard-cap 2), `mode`, `autonomy_band`, `goal_root`, `attempts_remaining`, `escalation_triggers` (pointer to existing §Escalation Rule, not re-authored).
- **Backward-compatible**: v1.0 callers do not emit the block; v1.1 readers tolerate its absence. Token budget still within 1500 (1280 estimated).
- **Reciprocity**: `skills/delegate-governance/SKILL.md` Related section now links `skills/auto-pilot/SKILL.md`.

### Changed

#### Skill `converge` v1.1.0 → v1.1.1 — Operational complement to Invariant 6 (cherry-picked from superseded PR #47)

- **NEW §11 "Downstream-agent handoff" template** — concrete neutral-framing markdown template for handing converge output to next agent/human. Operationalizes Invariant 6 by addressing the most common prompt-injection vector (the handoff message itself).
- **NEW `no-convergence-possible` output template example** — Failure modes section now includes full markdown example for when proposals contradict at axiom level (escalation path documented inline).
- **NEW worktree-compatibility bullet** in "When to use" — clarifies converge output lands in active worktree without coordination conflicts.
- **NEW bidirectional cross-references**:
  - `protocols/delegation/delegation-init-prompt.md` ↔ converge (handoff feeds delegation context)
  - `skills/delegate-governance/SKILL.md` ↔ converge (when sub-agents return competing proposals)
- **NEW PRIOR-ART.md "Dogfooding insights" section** — retrospective on v1.0.0 real-world usage (2-hour session, 7 parallel research agents) documenting what worked + the gap that drove v1.1.0.
- All changes are non-functional doc additions; no behavioral change to existing 5-act protocol or ACT 4 scan.
- Source: cherry-picked from PR #47 (closed as superseded) which was opened pre-#46 merge; this PR preserves PR #47's unique valuable additions atop main's current v1.1.0.

#### Skill `converge` v1.0.0 → v1.1.0
- **NEW Invariant 6: audit-not-persuasion / anti-prompt-injection** — output is a record for downstream evaluation, NOT a debate move. Forbids leading questions, asymmetric framing, victory tallies, "what do you think?" closers, first-person possessives, emotive adjectives applied unevenly, and embedded prompt-injection patterns
- **NEW end-of-ACT-4 mandatory impartiality scan** — before emitting §5 synthesis, scan output for persuasive framing and rewrite neutrally
- **NEW toggle `output_language`** ∈ {`auto`, `pt`, `en`, `es`, `<ISO-639-1>`} — explicit control over output language with reproducibility recorded in audit chain
- **EXTENDED §9 audit chain** — now includes `bias_techniques_applied` (e.g., runner-up-synthesizes attribution disclosure) and `output_language`
- Driven by real-world dogfooding feedback documented in issue #45 (caught a regression in a v1.0.0 production run where AI runner produced output with subtle persuasive framing toward downstream agent — skill needed to defend against this class of regression)

### Added

#### maos-mcp-hub v2.2.0 — VKS-1853: PR Interaction Ops + Params Standardization + Priority Support (Gaps 6, 7, 8)

- `servers/bitbucket/tools.py` — 3 new tools: `add_pr_comment` (top-level or threaded), `update_pr_description` (PUT-only body), `reply_to_pr_comment` (explicit threading wrapper). Standardizes params across ALL `pull_request.*` operations: every op now accepts both `pr_id` (canonical) and `pull_request_id` (alias), plus `account` for multi-persona auth. Helper `_normalize_pr_id(pr_id, pull_request_id)` handles disambiguation (raises on conflict, supports equal values).
- `lib/bitbucket/client.py` — 2 new HTTP methods: `add_pr_comment(pr_id, content, parent_id=None)` → `POST /pullrequests/{id}/comments` and `update_pr_description(pr_id, description)` → `PUT /pullrequests/{id}`. Both `max_retries=0` (non-idempotent; protects against race with concurrent edits for description, against duplicate comments for comments).
- `gateways/bitbucket/actions.py` — `RESOURCE_MAP["pull_request"]` now has 11 ops (was 8). Added governance hints and next-steps for the 3 new ops (e.g., "preferir reply_to_comment para manter threading", "idempotente mas NAO preserva mudancas concorrentes").
- `gateways/jira/actions.py:create_issue` — Now accepts optional `priority: str` (serialized as `{"name": value}`, Jira canonical form) and `assignee_account_id`. When a screen-scheme rejection occurs (e.g., issue type `Intervenção Técnica - I.A.` id 10407 in project VKS), surfaces a `screen_scheme_hint: True` result with a descriptive `hint` instead of a cryptic 400 — unblocks automated issue creation for IT-IA workflow.
- `docs/adrs/ADR-002-pull-request-ops-custom-wrapper.md` — Decision record: custom wrapper chosen over Rovo Dev API (Route B) because PR #40 already demoted atlassian-rovo to Tier-3 fallback. Delegating new functionality *back* to Rovo would reverse the architectural direction.
- `tests/test_bitbucket_client.py` — 5 new tests for PR methods (top-level, threaded reply, 404, update, non-idempotent-no-retry).
- `tests/test_gateway_bitbucket.py` — 9 new tests (11-ops assertion, governance for 3 new ops, `_normalize_pr_id` edge cases: canonical, alias, both equal, both missing, conflict).
- `tests/test_gateway_jira.py` — 4 new tests for priority handling (serialization, omission, screen-scheme rejection, non-priority error propagation).

### Changed

- `hub.py:HUB_VERSION` bumped from `1.0.0` → `2.2.0` (SemVer minor: 3 new ops are additive; existing `pr_id`-only callers still work).
- Gateway action count: Bitbucket 52 → 55 (cross-gateway total 96 → 99). Updated `tests/test_gateway_discover.py` and `tests/test_hub_registration.py` assertions accordingly.
- `servers/bitbucket/__init__.py:__version__` bumped `2.0.0` → `2.2.0`.
- README.md updated to reflect 55-action Bitbucket gateway and 99-action total; new v2.2 History entry.

### Validated

- `pytest` → 171/171 passing (18 new VKS-1853 tests + 153 existing).
- Non-breaking: all existing positional-or-keyword call sites (`pr_id=42`) continue to work. Agents using `pull_request_id=42` now work too.
- Safety: `_normalize_pr_id` raises `ValueError` on conflict or missing — bad calls fail fast with clear message.

#### GaaS/GaaC Agentic Delegation Framework (v1.0)
- `protocols/delegation/provider-matrix.md` — cross-provider lookup (Jira/Linear × Bitbucket/GitHub/GitLab × Secrets × Observability) citing source-of-truth files per cell
- `protocols/delegation/delegation-init-prompt.md` (~894 tok) — start-of-delegation prompt (4 cognitive lenses, Anti-Conflict Phase-1, provider detection, output contract)
- `protocols/delegation/delegation-dna-prompt.md` (~973 tok) — mid-flight guardrails (token watchdog, TTL, Sentinel, escalation, DNA heritage block for recursion)
- `protocols/delegation/delegation-finalize-prompt.md` (~1232 tok) — cleanup/handoff/learning (worktree lifecycle, ticket/PR closure via matrix, sanitize, learning entry template)
- `skills/delegate-governance/SKILL.md` — discoverable skill routing delegator/delegated to the right phase
- `plugin-scripts/gaac/delegate.sh` — CLI emitter auto-detecting ticket (key prefix) + VCS (git remote) providers, prepending dynamic context header
- `templates/memory-snippets/delegate-governance-memory.md` — paste-able blocks for user-scope memory
- `tests/validate-plugin.sh` — delegation-framework assertions (files exist, token budget ≤1500, CLI exec + 3 phases exit 0, skill frontmatter)

#### Converge Skill v1.0.0 — Cross-Agent Proposal Convergence

- `skills/converge/SKILL.md` — vendor-neutral 5-act protocol (steelman → critique → compare → synthesize → reject-log) for converging ≥2 AI-agent proposals into one validated synthesis. Single-session capable, general-purpose (not code-only). Optional toggles: `devil_advocate` (auto/on/off), `cognitive_activations` (inline list or catalog URI), `max_rounds`, `consensus_threshold`, `mcp_backend`.
- `skills/converge/PRIOR-ART.md` — survey of 20+ artifacts (sjarmak/converge, claude-octopus, peteski22/star-chamber, Solvely-Colin/Quorum, blueman82/ai-counsel, claudeblattman.com/council, AltimateAI/claude-consensus, dubs3c/council, onevcat/argue, et al.); cited primitives, universal gaps, quarterly maintenance protocol. Anti-NIH discipline with embedded prior-art table inside SKILL.md.
- Differentiators (validated as universal gaps in 20+ surveyed artifacts): (1) reject-log as first-class artifact, (2) devil's-advocate as TOGGLE (only Quorum had flag; others always-on/off), (3) cognitive-activations 1st-class with pluggable catalog URI (closest was /council with fixed `--type` rosters), (4) steelman-FIRST act ordering (sjarmak had as rule, not phase), (5) general-purpose scope (most prior art is code-review-scoped).

#### Pulse Skill v0.1.0 — Session Re-orientation + Eisenhower-DAG Planning

- `skills/pulse/SKILL.md` — vendor-neutral 5-phase protocol (memory refresh → status snapshot → dependency graph → Eisenhower 2x2 → route+persist) for session re-orientation. Single-session, output-budgeted, runtime-portable. Optional toggles: `persist`, `dry_run`, `consume_prior` (chain-link to prior pulse artifact), `persist_path`, `backlog_path`. Strict phase ordering with explicit skip-rules per phase; `defer-trigger` route as first-class taxon; cycle break-heuristic before escalation.
- `skills/pulse/PRIOR-ART.md` — survey of 20+ artifacts (hacktivist123/agent-session-resume, softaworks/agent-toolkit/session-handoff, MeisnerDan/mission-control, kenjudy/pdca-framework, realYushi/my-gtd-buddy, iamzifei/gtd-coach-plugin, mcpmarket OODA-loop skills, LangGraph plan-and-execute, et al.); cited primitives, universal gaps, decision matrix, quarterly maintenance protocol. Anti-NIH discipline with embedded prior-art digest table inside SKILL.md.
- Differentiators (validated as universal gaps in 20+ surveyed artifacts): (1) memory + status + DAG + Eisenhower + chain-linked persistence combined in one SKILL.md (no surveyed artifact combines >2), (2) `defer-trigger` route as first-class taxon (most tools collapse it into "backlog", losing the wake-up condition), (3) `consume_prior` chain-link semantics for compounding pulses across sessions, (4) cycle break-heuristic before escalation (deterministic recommendation > error), (5) vendor-neutral runtime-portable Skill format (most session-re-orientation tooling is SaaS or runtime-locked).
- Design process: meta-PDCA convergence loop using `/converge` skill (eat-our-own-dog-food). Three proposals (orchestrator A + best-practices-researcher B + code-simplicity-reviewer C) merged via 5-act protocol: steelman → critique → compare → synthesize → reject-log. Audit chain preserved.

### Fixed

#### maos-mcp-hub — VKO-88: Jira search endpoint migration (CHANGE-2046)
- `lib/jira/client.py:search_jql` — Migrated from deprecated `/rest/api/3/search` (HTTP 410) to new `/rest/api/3/search/jql`. Replaced `startAt` integer pagination with `nextPageToken` opaque string. Added optional `fields` and `expand` params for payload control.
- `gateways/jira/actions.py:search_jql` — Updated signature to match: `next_page_token: str = ""`, `fields: list[str] | None = None`, `expand: str | None = None`. Schema auto-regenerated via `SchemaRegistry` from the new signature.
- `tests/test_gateway_jira.py` — Updated existing mock to `/search/jql` + `nextPageToken`. Added 2 regression tests: `test_execution_search_jql_with_pagination_and_fields` (token + fields + expand) and `test_execution_search_jql_no_deprecated_startat_sent` (guard against re-introducing `startAt`).

#### Validated
- pytest tests/ → 153/153 passing (151 + 2 new)
- Real Jira API smoke test: page 1 returned 3 VKS issues + valid `nextPageToken`, page 2 paginated successfully.

### Removed

#### maos-mcp-hub — VKS-1694 Flat-Tools Residue Cleanup (Phase 2 / v1.7)
- `hub.py` — Removed the legacy flat-tool registration block in its entirety (the `if _expose_flat:` gate, the flat loop, and the per-server stderr dump in the summary)
- `MAOS_EXPOSE_FLAT_TOOLS` env var — No longer honored; variable removed from `.env.example`
- `mcp-tools/maos-mcp-hub/servers/bitbucket/server.py` — Deleted (metadata no longer needed; auto-discovery deprecated for Atlassian dirs)
- `mcp-tools/maos-mcp-hub/servers/jira/server.py` — Deleted
- README.md — Removed the "Available Tools (Bitbucket Server)" flat-tool reference section (~110 lines of deprecated docs)

### Changed

#### maos-mcp-hub — VKS-1694 Phase 2 follow-up
- `servers/{bitbucket,jira}/__init__.py` — Gateway-only modules now export just `TOOLS` (no longer `SERVER_INFO`); package version bumped to `2.0.0`
- `hub.py` — Simplified hub summary (no more "Flat servers" line), silenced auto-discovery skip warnings for directories without `server.py` (expected state)
- README.md — "Migration: Flat → Gateway" section updated to reflect v1.7 (removal complete, rollback path removed); "Why the change" + "Timeline" now reference v1.5 → v1.7 trajectory
- CLAUDE.md (root) — Simplified "MCP Tools" section to single-paragraph description of gateway-only architecture

#### Impact (v1.6 → v1.7)
- **No behavior change at runtime** — v1.6 already defaulted to flat-hidden via `MAOS_EXPOSE_FLAT_TOOLS=false`
- **Rollback via env flag removed** — consumers must use `atlassian_*` gateways (zero runtime consumers confirmed by VKS-1694 audit)
- **Handlers preserved** — `servers/{bitbucket,jira}/tools.py` unchanged; gateways still import `TOOLS` dict directly

### Phase 1 (previously under [Unreleased])

#### maos-mcp-hub — VKS-1694 Flat-Tools Residue Cleanup (Phase 1 / v1.6)
- `hub.py` — Flat-tool registration loop gated behind `MAOS_EXPOSE_FLAT_TOOLS` env var (default: `false`); introduced in this release, removed in v1.7
- `.env.example` — Documented `MAOS_EXPOSE_FLAT_TOOLS` rollback flag (removed in v1.7)
- `README.md` — Added "Migration: Flat → Gateway" section with full 30-tool mapping table; marked flat namespace as deprecated
- `CLAUDE.md` (root) — Updated "MCP Tools" section with deprecation notice
- `plugin-scripts/governance/lib/json-rpc.sh` — Updated PR workflow descriptive strings to reference `atlassian_bitbucket` meta-tool

## [1.5.0] - 2026-04-10

### Added

#### Skills (skills/)
- `response-compression/SKILL.md` — Output verbosity control (60-85% token reduction); profiles: none/lite/full/ultra; auto-mapped to agent role; derived from JuliusBrussee/caveman (MIT)

#### Governance (plugin-scripts/governance/)
- `token-budget-gate.sh` — PreToolUse[Bash] hook implementing RULE-009 (Token Bloat detection); blocks excessively verbose Task delegations; GaaS enforcement point

#### Documentation (docs/)
- `research-caveman-response-compression.md` — Research notes on response compression lineage and caveman protocol origins

#### Standards
- `AGENTS.md` — Agent coding standard following AAIF/Linux Foundation open standard (60k+ projects); covers build commands, code conventions, testing, commit guidelines, architecture decisions

#### maos-mcp-hub — Branch Management Tools (Sprint 8 — VKS-1647)
- `bitbucket_create_branch` — Create branch from commit hash (POST /refs/branches)
- `bitbucket_delete_branch` — Delete branch with default-branch protection (DELETE /refs/branches/{name})
- `bitbucket_set_default_branch` — Change repository default branch (PUT /repositories/{ws}/{repo})
- `bitbucket_get_branch_restrictions` — List branch protection rules (GET /branch-restrictions)
- `bitbucket_set_branch_restriction` — Create branch protection rule (POST /branch-restrictions)
- `bitbucket_delete_branch_restriction` — Remove branch protection rule by ID (DELETE /branch-restrictions/{id})
- 19 unit tests covering all new tools (success, error, edge cases)

### Changed
- `hooks/hooks.json` — Added `PreToolUse[Bash]` hook for `token-budget-gate.sh` (RULE-009)
- `sentinel/config.json` — Updated detection thresholds and rule weights
- `skills/context-prep/SKILL.md` — Refined trigger conditions and protocol rules
- `skills/skill-writer/SKILL.md` — Improved authoring guidelines and frontmatter spec
- `skills/README.md` — Updated skill catalog with response-compression entry
- `CLAUDE.md` — Updated plugin structure diagram; added token-budget-gate and response-compression references
- `README.md` — Updated component counts (Skills 15+, Agents 18+, Hooks 5); updated feature descriptions

## [1.4.0] - 2026-03-08

### Added

#### Rules (rules/)
- `action-now-protocol.md` (C15) — Eisenhower matrix for task prioritization with interdependency analysis
- `ai-native-errors.md` (C06) — MCP-JSON-RPC error protocol with recovery instructions
- `context-before-commit.md` (R01) — Context analysis before git commit (scope determination)

#### Documentation (docs/)
- `git-worktree-protocol.md` — Complete C04 git worktree protocol specification
- `git-workflow-standard.md` — Standard git workflow patterns
- `pr-review-protocol-spec.md` — PR review protocol full specification (C07)
- `mcp-jsonrpc-errors.md` — MCP-JSON-RPC error format reference
- `naming-conventions.md` — File and directory naming conventions
- `session-report-standard.md` — Session report format standard
- `session-audit-standard.md` — Session audit format standard
- `glossary-global-terms.md` — Global glossary of terms
- `ralph-loop-pattern.md` — Ralph Loop pattern documentation
- `error-codes-registry.md` — Error codes registry
- `ai-native-environment.md` — AI-native environment setup
- `auto-catchup-protocol.md` — Auto catch-up protocol for session continuity
- `session-identifiers-research.md` — Research on session identity patterns

#### Specs (docs/specs/)
- `auto-shard-agent-architecture.md` — Auto-shard agent architecture design
- `auto-shard-agent-brd.md` — Auto-shard agent business requirements
- `claude-md-sharding-spec.md` — CLAUDE.md sharding specification
- `sync-skill-interface.md` — Sync skill interface specification
- `sync-to-git-spec.md` — Sync-to-git specification

#### Agents (agents/)
- `code-reviewer.md` — Automated code review agent
- `data-analyst.md` — Data analysis and reporting agent
- `debugger.md` — Debugging specialist agent

#### Skills (skills/)
- `skill-writer/SKILL.md` — Skill creation and authoring tool
- `sync-to-git/SKILL.md` — Git synchronization skill

#### Commands (commands/)
- `auto-shard/` — CLAUDE.md sharding utility (8 files: SKILL.md, 6 operations, 1 script)
  - `operations/analyze.md` — Analyze CLAUDE.md for sharding opportunities
  - `operations/classify.md` — Classify content into shard categories
  - `operations/generate.md` — Generate shard files
  - `operations/recursive.md` — Recursive sharding for deep hierarchies
  - `operations/update-refs.md` — Update cross-references after sharding
  - `operations/validate.md` — Validate shard integrity
  - `scripts/detect-large-file.sh` — Detect files exceeding size thresholds
- `code/analyze/dependencies.md` — Dependency analysis command
- `analyze/research/quick-web-research.md` — Quick web research command

### Technical Details
- 36 new files consolidated from user-scope (`~/.claude/`) generic artifacts
- All files verified: no personal or proprietary data included
- Personal file paths sanitized in session-identifiers-research.md
- New `rules/` directory created at project root for reusable enforcement rules

## [1.3.0] - 2026-01-30

### Added

#### Governance Subsystem
- `plugin-scripts/governance/` - Git worktree enforcement hooks
  - `worktree-gate.sh` - Unified gatekeeper for C04 protocol enforcement
  - `auto-name-session.sh` - Automatic session naming based on project/branch/worktree
  - `lib/common.sh` - Shared constants and utilities
  - `lib/json-rpc.sh` - MCP-JSON-RPC error emission helpers
  - `lib/worktree-utils.sh` - Git worktree detection utilities

#### Enforcement Rules
- **RF01**: Block branch creation outside of git worktree
- **RF02**: Block checkout in main working directory
- **RF03**: Block commits to main/master branches
- **RF04**: MCP-JSON-RPC error format (stderr) for AI agent recovery
- **RF05**: Human-readable error messages for interactive sessions
- **RF06**: Bypass flag (`--force-no-worktree`, `--maos-bypass`)

#### Test Suite
- `tests/governance/` - Comprehensive unit tests for governance subsystem
  - `test-common.sh` - Tests for common.sh library
  - `test-json-rpc.sh` - Tests for JSON-RPC error emission
  - `test-worktree-utils.sh` - Tests for worktree detection
  - `test-worktree-gate.sh` - Integration tests for gate script
  - `run-all.sh` - Test suite runner

### Changed
- `hooks/hooks.json` - Added Bash matcher for worktree-gate.sh
- `hooks/hooks.json` - Added auto-name-session.sh to SessionStart

### Technical Details
- All scripts use `set -euo pipefail` for safety
- Errors emitted in MCP-JSON-RPC format to stderr (C06 compliant)
- Exit codes: 0=allow, 2=block (C06 standard)
- Error codes: -32000 (commit), -32001 (branch), -32002 (checkout)
- Audit logging to `~/.claude/audit/governance_*.jsonl`

### Migration Notes
After installing v1.3.0, you can remove duplicate hooks from user settings:
- `~/.claude/hooks/enforce-worktree.sh`
- `~/.claude/hooks/prevent-main-commit.sh`
- `~/.claude/hooks/auto-name-session.sh`

These are now consolidated in the MAOS plugin governance subsystem.

## [1.2.1] - 2026-01-10

### Fixed
- Version sync: plugin.json now matches CHANGELOG (was 1.2.1 vs 1.2.0)
- Note: No code changes, only version metadata alignment

## [1.2.0] - 2026-01-09

### Added
- Auto-install statusline feature in session-start.sh hook
- Statusline script template (`templates/statusline-command.sh`) with:
  - Model and version display
  - Project and branch info
  - Worktree detection
  - Session state from MAOS registry
  - Cost and context usage metrics
  - Visual semaphores for context consumption

### Fixed
- BUG-001: Arithmetic increment with `set -e` in validate-plugin.sh (Critical)
  - Changed `((VAR++))` to `((VAR++)) || true` to prevent exit on 0-to-1 increment
- BUG-002: grep failure in session-end.sh when session log does not exist (High)
  - Added existence check before grep -c
- BUG-003: Missing JSON validation in statusline-command.sh (High)
  - Added validation at start, graceful exit on invalid input
  - Changed shebang from `#!/bin/bash` to `#!/usr/bin/env bash`
- BUG-004: settings.json overwrite without backup in session-start.sh (High)
  - Added `.bak` file creation before modifying user settings

## [1.1.0] - 2026-01-08

> **Note**: Plugin manifest (`plugin.json`) version should be updated to 1.1.0 to match this release.

### Added

#### MVV Generator System
- `commands/mvv.md` - `/mvv` command for Mission, Vision, Values generation
- `skills/ontological-analysis/SKILL.md` - 8-dimension philosophical analysis (v1.0.0)
- `skills/mvv-synthesis/SKILL.md` - Mission/Vision/Values synthesis (v1.0.0)

#### Documentation & Tooling
- `CLAUDE.md` - AI agent development guidance
- `CHANGELOG.md` - Version tracking (Keep a Changelog format)
- `docs/ANALYSIS_REPORT_2026-01-08.md` - Plugin analysis report
- `.worktrees/` - Multi-agent coordination infrastructure
  - `tasks.md` - Task registry
  - `sessions.json` - Session tracking
  - `protected_files.json` - File protection manifest
  - `session_lock.template.json` - Lock file template

#### README Enhancements
- Added badges (MIT License, Claude Code Plugin, Version, Sentinel)
- MVV Generator documentation

### Changed
- Skills count increased from 8 to 10 (added ontological-analysis, mvv-synthesis)
- Commands count increased from 5 to 6 (added /mvv)

### Fixed
- Standardized YAML frontmatter in audit, agent-select, and context-prep skills
- Consistent skill format across all 10 skills

## [1.0.0] - 2026-01-07

### Added

#### Plugin Structure
- `.claude-plugin/plugin.json` - Plugin manifest for Claude Code integration
- `hooks/hooks.json` - Hook configuration for lifecycle events
- `plugin-scripts/` - 4 lifecycle hook scripts
  - `session-start.sh` - Session initialization
  - `pre-delegate.sh` - Pre-delegation checks
  - `post-delegate.sh` - Post-delegation processing
  - `session-end.sh` - Session cleanup

#### Skills (8 initial)
- `audit/SKILL.md` - Sentinel Protocol auditing (v1.1.0)
- `agent-select/SKILL.md` - Agent selection algorithm (v1.0.0)
- `context-prep/SKILL.md` - Pre-delegation context preparation (v1.0.0)
- `hierarchical-merge/SKILL.md` - Branch merge hierarchy rules (v1.0.0)
- `worktree-policy/SKILL.md` - Worktree enforcement policy (v1.1.0)
- `anti-conflict/SKILL.md` - Conflict prevention protocol (v3.2.0)
- `status-map/SKILL.md` - Status visualization system (v1.0.0)
- `ttl-policy/SKILL.md` - Content freshness management (v1.0.0)

#### Commands (5 initial)
- `/sync` - Framework synchronization to consumer projects
- `/audit` - On-demand session auditing
- `/status` - Status map visualization
- `/worktree` - Git worktree management
- `/delegate` - Task delegation to sub-agents

#### Agents (4 total)
- `orchestrator.md` - Master coordinator for multi-agent sessions
- `sentinel-monitor.md` - Anomaly detection and alerting
- `qa-validator.md` - Quality assurance validation
- `consolidator.md` - Output synthesis and consolidation

#### Sentinel Protocol v1.0.0
- `sentinel/config.json` - Detection thresholds configuration
- `sentinel/detection_rules.md` - 10 detection rules:
  1. Loop Detection (auto-block)
  2. Depth Violation (max 3 levels)
  3. Error Cascade (consecutive errors)
  4. Retry Storm (5+ retries/min)
  5. Task Drift (unrelated output)
  6. Chain Break (unexpected break)
  7. Escalation Abuse (>50% escalated)
  8. Stagnation (>5 min execution)
  9. Agent Mismatch (suboptimal selection)
  10. Token Bloat (excessive usage)
- `sentinel/schema/trace_schema.json` - OpenTelemetry aligned traces
- `sentinel/schema/alert_schema.json` - Alert format specification
- `sentinel/lib/trace_writer.md` - Trace persistence patterns
- `sentinel/lib/alert_handler.md` - Alert routing logic

#### Status Map System v1.0.0
- 9 individual template types + 1 consolidated reference file (10 total):
  - PULSE (1-line, every response)
  - COMPACT (6-line, every 5 responses)
  - SESSION_START (session begin)
  - SESSION_END (session end)
  - DELEGATION_PRE (before Task tool)
  - DELEGATION_POST (after Task tool)
  - ERROR_DEBUG (error diagnosis)
  - PRE_COMMIT (commit validation)
  - FULL_REPORT (complete audit)
  - `statusmap_templates.md` (consolidated reference)
- Automatic template inference engine
- Semaphore indicators (green/yellow/red)

#### Protocols
- `protocols/hierarchical-merge-protocol.md` - HMP v1.0
  - Parent-child branch convergence
  - Child Completion Constraint
  - Exception prefixes (hotfix/, emergency/)

#### Documentation
- `README.md` - Plugin overview and installation guide
- `docs/framework-consumption.md` - Consumer project integration
- `docs/worktrees-guide.md` - Multi-agent worktree coordination
- `LICENSE` - MIT License

### Technical Details
- Hook scripts use `set -euo pipefail` for safety
- JSON output from all hook scripts
- OpenTelemetry GenAI semantic conventions for traces
- W3C Trace Context compliant span IDs

### Deprecated
- `claude-md/` directory - Use README.md instead
- `install/` directory - Use Claude Code plugin system
- `scripts/` directory - Use plugin-scripts/

## [0.9.0] - 2026-01-07

### Added
- Initial framework structure
- Core protocol documentation drafts
- Agent definitions (conceptual)

### Technical
- Repository initialization
- MIT License

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.4.0 | 2026-03-08 | Consolidate 36 community artifacts: rules, docs, agents, skills, commands |
| 1.3.0 | 2026-01-30 | Governance subsystem, worktree enforcement hooks |
| 1.2.1 | 2026-01-10 | Version sync fix |
| 1.2.0 | 2026-01-09 | Statusline, bug fixes (BUG-001 to BUG-004) |
| 1.1.0 | 2026-01-08 | MVV Generator, CLAUDE.md, worktree infra |
| 1.0.0 | 2026-01-07 | Full plugin release, Sentinel, Status Map |
| 0.9.0 | 2026-01-07 | Initial framework structure |

---

*Multi-Agent OS - A Claude Code Plugin for Multi-Agent Orchestration*
*Maintained by Emilson Moraes | Powered by Claude Code*
