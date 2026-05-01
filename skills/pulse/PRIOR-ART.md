# Prior Art Survey — Session Re-orientation + Eisenhower-DAG Planning

**Survey date:** 2026-05-01
**Scope:** OSS frameworks, MCP servers, AI provider marketplaces (Anthropic Skills, Claude Code, Cursor rules, Codex, Gemini, GitHub Copilot, ChatGPT GPTs), task-management SaaS with agentic features, academic releases.
**Total artifacts surveyed:** 20+
**Methodology:** Two parallel research agents (best-practices-researcher + code-simplicity-reviewer) + primary-source verification via WebFetch on each cited GitHub repo.

## Top-10 closest matches (by similarity to this skill)

| Rank | Artifact | Type | URL | Similarity | Maturity | License |
|---|---|---|---|---|---|---|
| 1 | hacktivist123/agent-session-resume | Claude Code SKILL.md | https://github.com/hacktivist123/agent-session-resume | 8/10 | 156★ MIT | MIT |
| 2 | softaworks/agent-toolkit/session-handoff | Skill | https://github.com/softaworks/agent-toolkit | 7/10 | active 2026 | unspec. |
| 3 | MeisnerDan/mission-control | Standalone Next.js app | https://github.com/MeisnerDan/mission-control | 7/10 | 391★ AGPL-3.0 | AGPL-3.0 |
| 4 | kenjudy/pdca-framework | Skill | https://github.com/kenjudy/pdca-framework | 6/10 | CC0-1.0 | CC0-1.0 |
| 5 | realYushi/my-gtd-buddy | GTD plugin | https://github.com/realYushi/my-gtd-buddy | 6/10 | 22★ unspec. | unspec. |
| 6 | iamzifei/gtd-coach-plugin | Plugin | https://github.com/iamzifei/gtd-coach-plugin | 6/10 | 31★ MIT | MIT |
| 7 | mcpmarket OODA-loop skills | MCP skills | https://mcpmarket.com/tools/skills/ooda-loop-thinking-framework | 5/10 | active | varies |
| 8 | muratcankoylan/Agent-Skills-for-Context-Engineering | Skill toolbox | https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering | 5/10 | unspec. | unspec. |
| 9 | LangGraph plan-and-execute pattern | Reference example | https://github.com/langchain-ai/langgraph | 5/10 | MIT | MIT |
| 10 | michael-ga/obsidian-task-priority-eisenhower-matrix | Obsidian plugin | https://github.com/michael-ga/obsidian-task-priority-eisenhower-matrix- | 4/10 | MIT | MIT |

## Honorable mentions (similarity ≤ 4)

- joshmedeski/todoist-eisenhower-matrix — Todoist UI for Eisenhower (no agentic protocol)
- Standuply / Geekbot / Spinach.io / Dailybot — async stand-up SaaS (closed-source, narrow scope)
- ChatGPT Pulse — OpenAI proprietary "next-week bets" feature (closed)
- Cursor Automations — trigger-based scheduling (closes the `defer-trigger` gap from a different angle)
- addyosmani/agent-skills — index repo, no pulse-equivalent skill
- VoltAgent/awesome-agent-skills — curated index, no pulse-equivalent
- anthropics/skills — official Anthropic skills repo, no session-re-orientation skill at survey time

## Negative results (verified absent)

- No `/pulse` equivalent in OpenAI Cookbook (verified: github.com/openai/openai-cookbook)
- No featured GPT-Store agent for general-purpose session re-orientation
- No Vertex AI Agent Garden sample combining memory refresh + Eisenhower + DAG
- No Continue Hub assistant for re-orientation (hub.continue.dev)
- No cursor.directory rules combining memory + Eisenhower + DAG triage
- LangChain Hub returned only single-shot prompts, no multi-phase re-orientation
- "Eisenhower DAG" / "session pulse" / "PDCA skill" returned no exact matches in any AI provider marketplace at survey time

## Universal gaps (none of the 20+ artifacts cover all of these)

1. **Memory refresh + Eisenhower + DAG + routing + chain-linked persistence in one artifact** — no surveyed skill combines >2 of these primitives
2. **`defer-trigger` route as first-class taxon** — most tools collapse "wake up when X happens" into "backlog", losing the trigger condition
3. **`consume_prior` chain-link semantics** — compounding pulses across sessions; absent from all surveyed skills
4. **Cycle break-heuristic before escalation** — most DAG planners just error on cycles; no deterministic recommendation
5. **Vendor-neutral, runtime-portable Skill format** — most session-re-orientation tooling is SaaS (Standuply, Geekbot, ChatGPT Pulse) or runtime-locked (Obsidian plugin, Next.js app)

This `pulse` skill consolidates the 5 universal gaps into one cohesive protocol while citing all primitives borrowed from prior art (anti-NIH discipline).

## Decision matrix used to design this skill

| Approach | Effort | Risk | Verdict |
|---|---|---|---|
| Adopt agent-session-resume as-is | Low | High (in-session only; no triage) | Rejected — narrow scope |
| Adopt softaworks/agent-toolkit/session-handoff as-is | Low | Medium (CREATE/RESUME only; no Eisenhower) | Rejected — feature-gap |
| Wrap mission-control (Next.js) as a skill | High | High (AGPL viral license; runtime-coupled) | Rejected — license + portability |
| Fork agent-session-resume + 4 patches | Medium | Medium | Considered — but anti-NIH equally served by citing |
| Build new with prior-art citations | Medium | Low | **Adopted** — full gap coverage + prior-art credit |

## Maintenance protocol

This `PRIOR-ART.md` should be re-validated **quarterly** against:

- New releases of cited artifacts (semver bumps)
- New entrants in the session-re-orientation pattern space
- Any artifact reaching feature parity with this skill (in which case, consider deprecating in favor of consolidation upstream)

If a cited artifact reaches >95% feature parity with this skill, consider:

1. Contributing our `defer-trigger`, `consume_prior`, and `cycle-break-heuristic` patches upstream
2. Deprecating this skill and pointing to the upstream artifact
3. Documenting the deprecation in `CHANGELOG.md` of multi-agent-os

## Sources cited (primary URLs checked as of 2026-05-01)

> Verification method: HTTP GET via WebFetch with expected 2xx status; cross-checked across at least one secondary search engine. Re-verification due quarterly per the maintenance protocol above. Treat any future 404/403 as a signal to update — not as a defect of this document at write time.

- https://github.com/hacktivist123/agent-session-resume
- https://github.com/softaworks/agent-toolkit
- https://github.com/MeisnerDan/mission-control
- https://github.com/kenjudy/pdca-framework
- https://github.com/realYushi/my-gtd-buddy
- https://github.com/iamzifei/gtd-coach-plugin
- https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering
- https://github.com/addyosmani/agent-skills
- https://github.com/michael-ga/obsidian-task-priority-eisenhower-matrix-
- https://github.com/joshmedeski/todoist-eisenhower-matrix
- https://mcpmarket.com/tools/skills/ooda-loop-thinking-framework
- https://mcpmarket.com/tools/skills/ooda-loop-decision-framework
- https://github.com/langchain-ai/langgraph
- https://blog.langchain.com/planning-agents/
- https://standuply.com/
- https://standuply.com/retrospective-for-jira-tasks
- https://help.openai.com/en/articles/12293630-chatgpt-pulse
- https://cursor.com/blog/automations
- https://github.com/VoltAgent/awesome-agent-skills
- https://github.com/anthropics/skills
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- https://arxiv.org/pdf/2406.09953 (DAG-Plan)
- https://dl.acm.org/doi/10.1145/3746058.3758449 (MermaidLLM)
