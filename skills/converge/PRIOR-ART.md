# Prior Art Survey — Cross-Agent Proposal Convergence

**Survey date:** 2026-04-30
**Scope:** OSS frameworks, MCP servers, AI provider marketplaces (Anthropic, OpenAI, Google, Cursor, Continue, Cline, GitHub Copilot, MS), academic releases.
**Total artifacts surveyed:** 20+
**Methodology:** Two parallel research agents (commercial-providers + open-source/academic), primary-source verification.

## Top-10 closest matches (by similarity to this skill)

| Rank | Artifact | Type | URL | Similarity | Maturity | License |
|---|---|---|---|---|---|---|
| 1 | sjarmak/agent-workflows `/converge` | Claude Code SKILL.md | https://github.com/sjarmak/agent-workflows | 9.5/10 | 4★ active 2026-04 | MIT |
| 2 | nyldn/claude-octopus `/octo:debate` | Claude Code plugin | https://github.com/nyldn/claude-octopus | 8/10 | 3.2k★ v9.30.0 | (repo) |
| 3 | peteski22/star-chamber | Skill + CLI | https://github.com/peteski22/star-chamber | 8/10 | mozilla.ai endorsed | (repo) |
| 4 | Solvely-Colin/Quorum | CLI/MCP | https://github.com/Solvely-Colin/Quorum | 8/10 | 7-phase deliberation | (repo) |
| 5 | onevcat/argue | TypeScript engine | https://github.com/onevcat/argue | 8/10 | 109★ MIT | MIT |
| 6 | blueman82/ai-counsel | MCP server | https://github.com/blueman82/ai-counsel | 7.5/10 | 208★ v1.10.0 | MIT |
| 7 | rachittshah/llmcouncil | MCP + Claude skill | https://github.com/rachittshah/llmcouncil | 7.5/10 | active 2026-03 | (repo) |
| 8 | claudeblattman.com `/council` | Personal slash command | https://claudeblattman.com/workflows/council/ | 7/10 | personal site | n/a |
| 9 | AltimateAI/claude-consensus | CC plugin | https://github.com/AltimateAI/claude-consensus | 7/10 | 24★ MIT active | MIT |
| 10 | dubs3c/council | Standalone OSS | https://github.com/dubs3c/council | 6/10 | OSS Python | (repo) |

## Honorable mentions

- slior/dialectic-agentic — Pure-prompt skills (similarity 7)
- synaptiai/prompt-decorators `Steelman` decorator — Sub-feature primitive (similarity 6)
- composable-models/llm_multiagent_debate — Research code (Du et al. ICML 2024) (similarity 6)
- Lightless-Labs/refinery `synthesize` — Rust CLI (similarity 7)
- github/awesome-copilot/devils-advocate.agent.md — Sub-feature
- OpenBMB/AgentVerse — Multi-agent framework
- AltimateAI subset, quantsquirrel/claude-synod-debate, capitansuat/swarm-debate, gumbel-ai/agent-debate, jonathansantilli/freemad, Argus-Framework/argus-ai-debate, Coetus.AI (closed beta), Perplexity Model Council (GA)

## Negative results (verified absent)

- No `/converge` equivalent in OpenAI Cookbook (verified: github.com/openai/openai-cookbook)
- No featured GPT-Store agent for general-purpose convergence
- No Vertex AI Agent Garden sample for debate/consensus
- No Continue Hub assistant for synthesis (hub.continue.dev)
- No cursor.directory rules for steelman/devil's-advocate orchestration
- LangChain Hub returned only single-shot prompts, no convergence chain
- "RAD-AC" string returned no matches (the closest hits — RADAR, MADRA — are unrelated)

## Universal gaps (none of the 20+ artifacts cover)

1. **Reject log as separate artifact** — most "preserve dissent" textually, none emit a structured `rejected[]`
2. **Steelman as explicit FIRST act** — sjarmak has it as a rule, not as the protocol's first phase
3. **Devil's advocate as TOGGLE** — only Quorum's `--devils-advocate` flag; others bake it always-on or always-off
4. **Cognitive activations 1st-class with pluggable catalog URI** — /council closest with `--type` rosters but not pluggable
5. **General-purpose (proposals, not code review)** — only /council, sjarmak, dubs3c/council

This `converge` skill consolidates the 5 universal gaps into one cohesive protocol while citing all primitives borrowed from prior art (anti-NIH discipline).

## Decision matrix used to design this skill

| Approach | Effort | Risk | Verdict |
|---|---|---|---|
| Adopt sjarmak as-is | Low | Medium (Agent Teams flag dependency) | Rejected — dependency unacceptable |
| Adopt octopus as-is | Low | Medium (CC-only, code-task-oriented) | Rejected — narrow scope |
| Fork sjarmak + 4 patches | Medium | Low | Considered — but anti-NIH equally served by citing |
| Build new with prior-art citations | Medium | Low | **Adopted** — full gap coverage + prior art credit |
| Hybrid lean wrapper + ai-counsel MCP | High | Medium | Optional via `mcp_backend` parameter |

## Maintenance protocol

This `PRIOR-ART.md` should be re-validated **quarterly** against:
- New releases of cited artifacts (semver bumps)
- New entrants in the convergence-pattern space
- Any artifact reaching feature-parity with this skill (in which case, consider deprecating in favor of consolidation upstream)

If a cited artifact reaches >95% feature parity with this skill, consider:
1. Contributing our `reject-log` and `cognitive-activations` patches upstream
2. Deprecating this skill and pointing to the upstream artifact
3. Documenting the deprecation in `CHANGELOG.md` of multi-agent-os

## Dogfooding insights (v1.0.0 retrospective — 2026-05-07)

Real-world usage of v1.0.0 on substantial use case (7 parallel research agent outputs on multi-account AI identity management) revealed:

**What worked exceptionally well:**
1. **5-act ordering eliminates bias** — Steelman-first prevents premature judgment formation
2. **Reject log (§7) is the killer differentiator** — preserves considered-and-rejected alternatives with rationale
3. **Parity check** catches real bias in critique distribution (4+ negatives per "soft" proposal vs 2-3 per "concrete" proposal)
4. **Anti-NIH discipline §10** changed behavior — forces citation of prior art that would otherwise be implicitly absorbed
5. **Cross-checking in §3 critique** surfaces hidden patterns not visible in flat collation (e.g., `includeIf hasconfig:remote.*.url:` discovery)

**Critical gap identified (driving v1.1.0):**
- **Subtle prompt injection risk**: v1.0.0 was format-prescriptive but not tone-prescriptive. Real output contained leading questions ("Do you agree that...?") and asymmetric framing ("9 wins vs 5") — violations of the spirit (not letter) of impartiality. This was caught by the human user, not by the skill itself.
- **Solution shipped**: Invariant 6 (audit-not-persuasion) + mandatory ACT 4 impartiality scan in v1.1.0 (PR #46).

**Operational complement (v1.1.1):**
- Added §11 "Downstream-agent handoff" template (this PR) to operationalize Invariant 6 — provides concrete neutral-framing template for the most common prompt-injection vector (the handoff message).

**Other improvements considered:**
- DA skip rationale should require qualitative breakdown, not just mechanical thresholds (open)
- Output language auto-detection improved (shipped v1.1.0)
- No-convergence-possible output template (shipped v1.1.1 inline in Failure modes)

Session: 2-hour multi-proposal session including cross-agent debate (Claude vs Gemini-Antigravity).

## Sources cited (primary URLs checked as of 2026-04-30)

> Verification method: HTTP GET via WebFetch with expected 2xx status; cross-checked across at least one secondary search engine. Re-verification due quarterly per the maintenance protocol above. Treat any future 404/403 as a signal to update — not as a defect of this document at write time.

- https://github.com/sjarmak/agent-workflows/blob/main/skills/converge/SKILL.md
- https://github.com/nyldn/claude-octopus
- https://github.com/peteski22/star-chamber
- https://blog.mozilla.ai/the-star-chamber-multi-llm-consensus-for-code-quality/
- https://github.com/Solvely-Colin/Quorum
- https://github.com/onevcat/argue
- https://github.com/blueman82/ai-counsel
- https://github.com/rachittshah/llmcouncil
- https://claudeblattman.com/workflows/council/
- https://github.com/AltimateAI/claude-consensus
- https://github.com/dubs3c/council
- https://github.com/slior/dialectic-agentic
- https://synaptiai.github.io/prompt-decorators/api/decorators/Steelman/
- https://github.com/composable-models/llm_multiagent_debate
- https://arxiv.org/abs/2305.14325 (Du et al. Multiagent Debate, ICML 2024)
- https://github.com/Lightless-Labs/refinery/pull/26
- https://github.com/github/awesome-copilot/blob/main/agents/devils-advocate.agent.md
- https://github.com/openai/swarm
- https://cookbook.openai.com/examples/agents_sdk/multi-agent-portfolio-collaboration/multi_agent_portfolio_collaboration
