# AWARENESS-REGISTRY — walkthrough-concierge

> The tool landscape the concierge is **aware of** + **routes to**. Tiered: **Tier-A** = active ASH surface (route here). **Tier-B** = sibling agentic-tools (cross-link / awareness only — never wrap). Awareness ≠ live integration (per maos/specdd-concierge discipline). Verify presence via SKILL Phase 0 — this registry may lag; flag staleness.

## Tier-A — ASH-lite surface (the harness this concierge orients over)

| Tool | Path | Role | Governing § |
|---|---|---|---|
| `agentic-walkthrough` | `agentic-walkthrough` | session timeline (markdown; `--raw` JSON; `--today`/`--violations`) | §2 journal |
| `agentic-decisions` | `agentic-decisions` | decision-audit report (table/list/json; `--filter`/`--sort`) | §17 |
| `agentic-decide` | `agentic-decide` | in-session explicit capture → staging (`DEC-` ids; high-fidelity "why") | §17.2 |
| `agentic-reindex` | `agentic-reindex` | backfill/migrate/enrich old journals (`reindex-rebuilt`) | §16 |
| `agentic-fix-dangling-symlinks` | `agentic-fix-dangling-symlinks.sh` | repair `.claude/transcripts/*` symlinks | SessionStart |
| `stop-fallback` | `skills/agentic-session-harness/hooks/stop-fallback.sh` | reliably-firing Stop entry writer + **structural `XDEC-` extraction** (v1.6.2) | §17.2b |
| `decide-merge` | `skills/agentic-session-harness/hooks/decide-merge.sh` | Stop merge: folds staged `DEC-` + `XDEC-` into `decisions[]`, deduped | §17.3 |
| `lib` | `skills/agentic-session-harness/hooks/lib.sh` | shared helpers (`ash_extract_goal`, `ash_extract_decisions`, tenant/transcript) | §15 |
| `link` / `resume` | `skills/agentic-session-harness/hooks/{link,resume}.sh` | SessionStart: symlink transcript + inject last-5 context | — |
| `decision-capture` | `skills/decision-capture/` | WHEN to call `agentic-decide` (≥MEDIUM autonomy; skip trivial) | §17.2 |
| schema L1 (generic) | `skills/agentic-session-harness/SPEC.md` | generic 17-field SSOT (FROZEN-17) — vendor-neutral | — |
| schema L2 (corporate overlay) | (org's private toolkit, NOT here) | optional org-specific extension: taxonomy/compliance/tenant deltas. Layer-2 lives in the consuming org's corporate repo, never in community | — |

## Tier-B — sibling agentic-tools (awareness / cross-link only — DO NOT wrap)

| Tool | Where | Why aware |
|---|---|---|
| `maos-concierge` | multi-agent-os | sibling concierge (the template); orients over the MAOS framework |
| domain concierges (e.g. SpecDD / work-tracker / org-umbrella) | org's corporate toolkit | sibling concierges in a consuming org's private toolkit; decisions audited here often trace to their domains' drift |
| `enhance-pipeline` | multi-agent-os | feature-lifecycle driver; its DELIVER stage produces commits/PRs that ASH structurally captures |
| `auto-orchestrator` / `quiesce` / `auto-pilot` | multi-agent-os | orchestration drivers; their sessions are what ASH journals |
| `morning-briefing` / `pulse` | multi-agent-os | session recap/re-orient; complementary to walkthrough (cross-session vs intra-session) |
| `TWG` (`twg` / `twg-workflows`) | user-scope | Atlassian work-data CLI; awareness for cross-tool routing |
| `converge` | multi-agent-os | 5-act proposal merge; decisions converged there may be `agentic-decide`-captured |

## Routing heuristics (reduce surface — what to SKIP)
- "Why did the agent diverge from the SPEC?" → `agentic-decisions --filter spec_alignment=divergent` (NOT `agentic-walkthrough` — that's the whole timeline).
- "Capture this decision's rationale" → `agentic-decide` (NOT edit the journal by hand).
- "Onboard onto SpecDD / MAOS" → route to `specdd-concierge` / `maos-concierge` (NOT this one).
- "Promote ASH to multi-agent-os" → ALREADY PROMOTED (Layer-1, 2026-06-02, via operator override of the ADR-017 R6 ≥2-cycle gate; recorded in the promotion ledger). Re-promotion/forking = governance PR (NOT a concierge action).
