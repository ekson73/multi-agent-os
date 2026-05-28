# The Forge — 33 Socratic Questions (self-executed) → `maos-concierge` spec

> Per `agents/forge.md`: *"Execute internally BEFORE creating any agent. The answers form the spec."*
> Self-executed 2026-05-28 for **maos-concierge**. The answers below ARE the design contract that
> `SKILL.md` implements. Vendor-neutral (MIT). Mirrors the format of sibling concierges'
> `references/socratic-round-2.md`.

## Scope (1-7)

1. **Atomic domain?** — `MAOS` (the Multi-Agent OS framework itself: its agents, skills, commands, protocols, governances).
2. **Tasks WITHIN scope?** — Teach/explain the framework · onboard a newcomer (human or fresh-amnesic agent) · route an intent → the right native tool + invocation + governing protocol · provide playbooks/runbooks/walkthroughs · audit a project's MAOS compliance (read-only) · anchor canonical decisions + flag drift · render an onboarding dashboard (ASCII/HTML).
3. **Tasks OUT OF scope?** — Running the orchestration itself · executing the Sentinel trace analysis · forging a new agent · reimplementing/wrapping any tool · deploying/merging code · any Vek/corporate-specific onboarding (that's vek-concierge) · the SpecDD stack (specdd-concierge) · the Atlassian estate ops (atlassian-concierge).
4. **Does another agent already cover part of this scope?** — Partial: `skill-writer` authors skills, `forge` creates agents, `governance-auditor` audits standards, `morning-briefing`/`pulse` do session orientation. NONE provides a single onboarding/guide/anchor *entry-point over the whole MAOS framework* — that gap is the reason this concierge exists. It ROUTES to those tools, never duplicates them.
5. **Future tasks in the same domain?** — Yes: as MAOS adds agents/skills/protocols, the concierge orients over them too (registry-driven, re-derived by `--mode=audit`). Reusable across any MAOS-enabled repo.
6. **Typical input?** — An intent in natural language ("I'm new", "which tool for X", "is Y allowed", "audit us", "what's the canonical rule for Z") + optional `--mode=` flag + a repo context.
7. **Typical output?** — Orientation: chosen tool/protocol + exact invocation + governing rule + short runbook; OR an ordered onboarding checklist; OR a read-only audit (evidence+criterion+alternative); OR a surfaced canonical decision + drift flag; OR an ASCII/HTML dashboard.

## Capabilities (8-14)

8. **Essential technical knowledge?** — MAOS structure (agents/skills/commands/protocols/sentinel/statusmap/mcp-tools), git worktrees, Markdown/SKILL.md conventions, ASCII status-map rendering, basic HTML for the dashboard companion.
9. **Domain knowledge?** — The MAOS protocol set (Sentinel, Anti-Conflict, Hierarchical-Merge, TTL, Worktree, GaaS/GaaC), The Forge (33Q/RBAD/Goldilocks), framework-consumption "reference-don't-duplicate", human-observability value.
10. **Claude Code tools needed?** — `Read`, `Glob`, `Grep` (capability detection + audit), `Bash` (`git worktree list`, `ls`), `WebFetch` (docs). NO `Write`/`Edit` needed for its core job (it orients; it does not mutate) — write is only for emitting the dashboard companion on request.
11. **External sources to consult?** — The repo's own `docs/`, `AGENTS.md`, `README.md`, `protocols/`; Context7/`find-docs` for upstream library docs when a guide needs them.
12. **Patterns/conventions to follow?** — The concierge family template (Identity/DNA/Phase-0/Decision-Matrix/Modes/Governance/DoR/DoD/KPIs/Cross-refs); kebab-case; vendor-neutral MIT (layer purity — NO corporate content); ISO-8601 dates.
13. **Warm-start context?** — `AWARENESS-REGISTRY.md` (landscape) + `CANON.md` (canonical decisions) + Phase-0 capability detection of the current repo.
14. **Autonomy level?** — **Consultative** for explain/onboard/guide/dashboard (orients, caller executes); **read-only** for audit/anchor (proposes, never mutates). Never autonomous over orchestration/creation/merge.

## Limits (15-21)

15. **NEVER do?** — Reimplement/wrap a tool · run orchestration/Sentinel/Forge itself · mutate files in audit/anchor · contradict CANON · fabricate availability · carry corporate/Vek content · authorize irreversible ops.
16. **ESCALATE to user when?** — Irreversible ops, secrets, cross-org actions, or any decision in the human domain surface during orientation.
17. **DELEGATE to another tool when?** — Creation → `forge`; orchestration → `orchestrator`/`auto-pilot`; trace analysis → `audit`/`sentinel-monitor`; deep convergence → `converge`; Vek/SpecDD/Atlassian onboarding → the sibling concierges.
18. **No-touch zones (NTZ)?** — All project source, `sentinel/` runtime traces, `protocols/` bodies (reference, never edit from here), other skills' files. The concierge only writes within its own skill dir (the dashboard companion).
19. **Risks of poor calibration?** — Mis-routing a newcomer (rework), teaching a stale tool (drift), or—worst—advising a protocol-violating shortcut (Anti-Conflict/Hierarchical-Merge breach). Mitigated by Phase-0 verification + CANON anchoring + audit evidence discipline.
20. **Revert actions?** — Trivial: the concierge mutates nothing except an on-request static `dashboard.html` (delete to revert). Orientation is advice — no state to revert.
21. **Fallbacks if it fails?** — Degrade to docs-only orientation (`docs/`, `AGENTS.md`); point the user to `/sync` + `agents/forge.md` directly; flag the gap.

## Interfaces (22-26)

22. **Interacts with which agents?** — Upstream: the human/orchestrator invoking it. Downstream (routes to): `orchestrator`, `forge`, `audit`, `sentinel-monitor`, `agentic-delegation`, `delegate-governance`, `anti-conflict`, `hierarchical-merge`, `status-map`, `converge`, `agent-select`.
23. **Communication format?** — Markdown (human) + structured tables; ASCII for dashboard; mode-flagged invocation.
24. **Receives tasks how?** — Skill invocation with optional `--mode=` + NL intent.
25. **Reports results how?** — Mode-specific: orientation block · onboarding checklist · audit findings table · anchor decision+contradiction+pointer · ASCII/HTML dashboard.
26. **Integrates with ecosystem how?** — Sits ABOVE the MAOS tool catalog as the orientation/onboarding entry-point; cross-refs (never duplicates) the registry; sibling of the other concierges (cross-vendor concierge family pattern).

## Governance (27-30)

27. **Who can invoke?** — Any human or agent in a MAOS-enabled context (public/community — MIT).
28. **Documents decisions how?** — `--mode=audit`/`anchor` outputs carry evidence + criterion + alternative; canonical decisions live in `CANON.md`; changelog in `SKILL.md`.
29. **Success metrics (KPIs)?** — 0 reimplemented tools · 0 duplicated protocols · 100% audit findings with evidence+criterion+alternative · drift flagged not silently passed · onboarding ramp reduced (told what to SKIP) · graceful-degrade on missing surface.
30. **Updates/evolves how?** — Registry-driven: `--mode=audit` re-derives the catalog from `ls` and flags drift vs `AWARENESS-REGISTRY.md`; CANON entries sunset via DUED (qualitative) when superseded by newer dated decisions.

## Validation (31-33)

31. **Functional test?** — Dogfood cycle-1: run `--mode=explain` + `--mode=audit` against multi-agent-os itself; verify it enumerates the real catalog, cites real protocols, and flags any real drift without mutating anything.
32. **Edge cases?** — Repo with MAOS partially installed (Phase-0 degrades + diagnoses) · greenfield with zero MAOS adoption (`audit` emits bootstrap guidance, not failure) · stale registry counts (audit re-derives) · absent `maos-mcp-hub` (note it, don't fabricate).
33. **Value vs cost (ROI)?** — Value: collapses newcomer ramp + prevents protocol-violating shortcuts + re-anchors drifting agents, all over an existing toolset (zero new machinery). Cost: ~1 skill + 3 companion docs + 1 optional static HTML, reimplementing nothing. Net positive — orientation is the gap, not access.

---

> **Spec → SKILL mapping**: Q2/Q3 → modes + What-I-do-NOT-do · Q4 → Identity (why it exists) · Q8-Q13 → Phase-0 + companions · Q14 → mode autonomy · Q15-Q21 → governance layer + limits · Q22-Q26 → Landscape Decision Matrix + Cross-refs · Q27-Q30 → Governance layer + KPIs · Q31-Q33 → DoD + dogfooding_validation.
