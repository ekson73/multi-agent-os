# The Forge — 33 Socratic Questions (self-executed) → `claude-code-concierge` spec

> Per the Forge discipline: *"Execute internally BEFORE creating any agentic-tool. The answers form the spec."*
> Self-executed 2026-06-13 for **claude-code-concierge** (soul-name *Cicerone*). The answers below ARE the
> design contract that `SKILL.md` implements. Vendor-neutral (MIT). Mirrors sibling concierges' format.

## Scope (1-7)

1. **Atomic domain?** — The **Claude-Code platform itself**: interacting with Claude Code (install · configure · use the CLI · manipulate agentic-tools [MCP·skill·command·agent/subagent·plugin·marketplace·hook·rule] · choose scope · choose source · research official docs).
2. **Tasks WITHIN scope?** — Teach the platform · onboard a newcomer · route an intent → best scope + best source + exact command + governing rule + official-doc · **research the OFFICIAL+CURRENT docs (Claude-Code's AND the tool's)** before acting (core) · render a control-panel dashboard (sessions·context·memory·MCPs·plugins·marketplaces·worktrees·tasks·next-actions) · health-check the config (read-only) · self-test · guarded install (MCP/plugin/marketplace) · anchor canonical platform decisions.
3. **Tasks OUT OF scope?** — Deep "how does feature X work internally" Q&A (→ `claude-code-guide` agent) · CREATING a new tool (→ `agentic-tool-forge`) · NAMING (→ `anima`) · running orchestration/session-lifecycle (→ `auto-pilot`/`preflight`/`postflight`/`morning-briefing`/`pulse`) · MAOS/ASH/OpenClaw onboarding (→ sibling concierges) · Atlassian ops (→ `maos-mcp-hub`) · writing application code.
4. **Does another tool already cover part of this scope?** — Partial: `claude-code-guide` answers feature Q&A; `find-docs`/Context7/ref-tools fetch docs; `agentic-tool-forge` creates tools; `morning-briefing`/`pulse` do session orientation; sibling concierges scope OTHER frameworks. **NONE** is a single onboarding/router/**docs-researcher**/guarded-operator entry-point over the *Claude-Code platform itself* (scope+source decisioning + official-docs research + install lifecycle). That gap is why this exists. It ROUTES to those tools, never duplicates them.
5. **Future tasks in the same domain?** — Yes: as Claude Code adds tool types / CLI verbs / scope or marketplace primitives, the concierge orients over them (registry-driven; `--mode=doctor`/`research` re-derive against current docs). Reusable across any Claude-Code (or AAIF) host.
6. **Typical input?** — An intent in natural language ("install this MCP", "where should this skill live", "research the marketplace docs", "show me a dashboard", "health-check my config") + optional flag (`--research-tools`, `--dashboard`, `--install-mcp`, `--health-check`, …) + host/repo context.
7. **Typical output?** — Orientation: best scope + source + exact capability-detected command + governing rule + cited official-doc; OR an ordered onboarding checklist; OR a research reconciliation (Claude-Code docs + tool docs → recommendation, cited); OR an ASCII/HTML control-panel; OR a read-only health-check (evidence+criterion+fix); OR a confirm-gated install + verify + audit line; OR a surfaced canonical decision + drift flag.

## Capabilities (8-14)

8. **Essential technical knowledge?** — Claude-Code config model (scopes user/project/local/enterprise + precedence), agentic-tool types, the `claude`/`claude mcp`/`claude plugin` CLIs, `.mcp.json`/settings structure, Markdown/SKILL.md conventions, ASCII dashboard rendering, basic HTML for the companion.
9. **Domain knowledge?** — Scope precedence, source trust-tier (provenance), secrets-never-inline, official-docs-first, the lifecycle family, the genesis pair, the sibling-concierge boundaries.
10. **Claude Code tools needed?** — `Read`, `Glob`, `Grep` (capability detection + health-check), `Bash` (`command -v claude`, `claude mcp list`, `claude plugin …`, `git worktree list`), `WebFetch`/`WebSearch` (official docs — the core research muscle). `Write` only for the on-request `dashboard.html` companion (it orients/researches; it does not mutate config except in confirm-gated `--mode=install`, which uses the `claude` CLI via Bash, not file edits).
11. **External sources to consult?** — `code.claude.com/docs` (authoritative), `docs.claude.com`/`docs.anthropic.com`, `github.com/anthropics/*`, each tool's own docs (via `find-docs`/Context7/ref-tools), and the `claude-code-guide` agent for feature Q&A.
12. **Patterns/conventions to follow?** — The concierge family template (Identity/DNA/Phase-0/Decision-Matrix/Modes/Governance/DoR/DoD/KPIs/Cross-refs); kebab-case; vendor-neutral MIT (layer purity — NO corporate content); ISO-8601 dates; soul-name display-only (envelope-safety).
13. **Warm-start context?** — `AWARENESS-REGISTRY.md` (landscape) + `CANON.md` (canonical decisions) + Phase-0 capability detection of the current host/repo.
14. **Autonomy level?** — **Consultative** for explain/onboard/guide/research/dashboard (orients/researches, caller executes); **read-only** for doctor/anchor (proposes, never mutates); **guarded-autonomous** for install (confirm-gated, capability-detected, verified). Never autonomous over irreversible/secret/cross-org/enterprise changes.

## Limits (15-21)

15. **NEVER do?** — Fabricate a command/availability · answer install/config "how" from memory (must cite current docs) · inline a secret · enable an unverified source without provenance+gate · mutate outside confirm-gated install · reimplement/wrap `claude-code-guide`/`find-docs`/`forge`/lifecycle/sibling-concierges · carry corporate content · authorize irreversible ops.
16. **ESCALATE to user when?** — Secrets, paid installs/subscriptions, irreversible/destructive config, cross-org/enterprise-managed changes, or any human-domain decision surfaced during orientation.
17. **DELEGATE to another tool when?** — Feature Q&A → `claude-code-guide`; docs fetch → `find-docs`/Context7/ref-tools; creation → `agentic-tool-forge`; naming → `anima`; eval/tune → `agentic-tool-evaluator`/`-trainer`; session lifecycle → `preflight`/`postflight`/`auto-pilot`/`morning-briefing`/`pulse`/`quiesce`; MAOS/ASH/OpenClaw → sibling concierges; Atlassian → `maos-mcp-hub`.
18. **No-touch zones (NTZ)?** — All project source · other skills' files · `~/.claude` runtime/transcripts/secrets · enterprise/managed settings (read-only) · `protocols/` bodies. The concierge writes only within its own skill dir (the dashboard companion) and runs `claude` CLI installs only confirm-gated.
19. **Risks of poor calibration?** — Recommending the wrong scope (a user-scope tool a teammate can't see), teaching a stale "how" (docs changed), enabling an untrusted source, or—worst—leaking a secret. Mitigated by Phase-0 verification + official-docs-first (C1) + trust-tier (C3) + secrets-never-inline (C4) + confirm-gate (C6).
20. **Revert actions?** — Trivial: only the on-request static `dashboard.html` is written (delete to revert); orientation/research is advice (no state). A confirm-gated install is reversible via the inverse `claude` CLI command (e.g. `claude mcp remove`, `claude plugin uninstall`), surfaced in the audit line.
21. **Fallbacks if it fails?** — Degrade to docs-only orientation (`code.claude.com/docs`); point to `claude-code-guide` + `find-docs` directly; flag the absent surface; never fabricate availability.

## Interfaces (22-26)

22. **Interacts with which agents?** — Upstream: the human/agent invoking it. Downstream (routes to): `claude-code-guide`, `find-docs`, `agentic-tool-forge`, `anima`, `agentic-tool-evaluator`/`-trainer`, `preflight`/`postflight`/`auto-pilot`/`morning-briefing`/`pulse`/`quiesce`/`recap`, `maos-concierge`/`walkthrough-concierge`/`openclaw-concierge`, `maos-mcp-hub`, `agentic-status`/`status-map`.
23. **Communication format?** — Markdown (human) + structured tables; ASCII for dashboard; `--format=json` for agent-to-agent; mode-flagged invocation.
24. **Receives tasks how?** — Skill invocation (or `/claude-code-concierge` command wrapper) with optional `--mode=`/flag-alias + NL intent.
25. **Reports results how?** — Mode-specific: orientation block · onboarding checklist · research reconciliation (cited) · dashboard · health-check findings table · install audit line · anchor decision+contradiction+pointer.
26. **Integrates with ecosystem how?** — Sits ABOVE the Claude-Code tool catalog as the platform onboarding/research/install entry-point; cross-refs (never duplicates) the registry; 4th member of the cross-vendor concierge family (maos/walkthrough/openclaw + this).

## Governance (27-30)

27. **Who can invoke?** — Any human or agent in a Claude-Code (or AAIF) context (public/community — MIT).
28. **Documents decisions how?** — `--mode=doctor`/`anchor` outputs carry evidence + criterion + fix; install emits an audit line (command + scope/source + revert); canonical decisions live in `CANON.md`; changelog in `SKILL.md`.
29. **Success metrics (KPIs)?** — 0 reimplemented tools · 0 fabricated commands · 100% research recommendations cite a CURRENT official source · 100% installs confirm-gated + verified · 100% health-check findings with evidence+criterion+fix · graceful-degrade on missing surface.
30. **Updates/evolves how?** — Docs-driven: `--mode=research`/`doctor` re-derive against current official docs and flag drift vs `AWARENESS-REGISTRY.md`; CANON entries sunset via DUED (qualitative) when the official mechanism changes.

## Validation (31-33)

31. **Functional test?** — Dogfood cycle-1: run `--mode=explain` + `--mode=doctor --self-test` against this host; verify it enumerates real scopes/sources, Phase-0 probes run, companions exist + cross-refs resolve, and it routes (not duplicates) `claude-code-guide`/`find-docs`/`forge` — mutating nothing. `--mode=research` on a real example (e.g. "add an MCP at project scope") cites `code.claude.com/docs`.
32. **Edge cases?** — `claude` CLI not on PATH (Phase-0 degrades to docs-only) · greenfield host with no `~/.claude` (onboard bootstrap, not failure) · absent plugin/MCP subsystem (install degrades to manual guidance) · stale registry paths (doctor re-derives) · cross-vendor host (Cursor/Codex/Gemini — degrade, don't fabricate `claude` CLI) · a secret about to be inlined (block + escalate, C4).
33. **Value vs cost (ROI)?** — Value: collapses the recurring research loop (Claude-Code docs + tool docs + scope/source decision) the operator does on EVERY platform interaction, prevents wrong-scope/untrusted-source/stale-how/secret-leak mistakes, and front-desks the whole platform — over an existing toolset (zero new machinery). Cost: ~1 skill + 3 companion docs + 1 optional static HTML + 1 command wrapper, reimplementing nothing. Net positive — the research loop is the gap, not access.

---

> **Spec → SKILL mapping**: Q2/Q3 → 8 modes + What-I-do-NOT-do · Q4 → Identity (why it exists, the gap) · Q8-Q13 → Phase-0 + companions + AWARENESS-REGISTRY · Q14 → mode autonomy (consultative/read-only/guarded) · Q15-Q21 → governance layer + limits + C1-C8 · Q22-Q26 → Landscape Decision Matrix + Cross-refs · Q27-Q30 → governance + KPIs · Q31-Q33 → DoD + dogfooding.
