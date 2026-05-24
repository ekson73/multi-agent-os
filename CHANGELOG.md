# Changelog

All notable changes to the Multi-Agent OS plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Added

#### `founder-*` family — Anthropic Founder's Playbook converted to agentic-tools

- **NEW skills** (Agent Skills standard, vendor-neutral): `founder-playbook` (lifecycle router + `references/product-matrix.md`), `founder-stage-idea`, `founder-stage-mvp`, `founder-stage-launch`, `founder-stage-scale`. Each stage skill carries its goal, exit-criteria gate, failure modes + mitigations, and ready-to-use exercise prompts / emittable templates.
- **NEW agent**: `founder-coach` — delegatable "founder as orchestrator-of-agents" coaching persona (stage diagnosis + exit-gate review).
- **NEW command**: `/founder-playbook` — thin wrapper over the router skill.
- **Origin**: framework adapted (process & methodology, original prose, attributed — no verbatim copy) from Anthropic, *The Founder's Playbook: Building an AI-Native Startup* (2026, https://claude.com/blog/the-founders-playbook). Capability classes are vendor-neutral (conversational-research / agentic-coding / workflow-automation) with Claude (Chat/Code/Cowork) as the reference implementation. Resolves #85.

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
