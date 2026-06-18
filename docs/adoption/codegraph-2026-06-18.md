# Adoption verdict — CodeGraph (code-knowledge-graph MCP)

> **Produced by**: `agentic-tool-intake` v0.1.0 (first dogfood) · `--mode=decide --dry-run` · 2026-06-18 · VKS-2244.
> **Candidate**: `github.com/colbymchenry/codegraph` · npm `@colbymchenry/codegraph` · trigger: Bitwise AI video (2026-05-27).
> **This is a verdict-only run — nothing was installed; `~/.claude.json` is unchanged.**

## VERDICT: **ADAPT** (scoped per-large-repo trial, pinned) — global/user-scope INSTALL = **DEFER-HITL** pending a measured tool-call delta on this operator's real workflow.

*Not a blanket user-scope install (the hype default), not ABANDON (the capability is real + non-redundant). The deciding factor — does this operator's heavy sub-agent fan-out trigger the author's own "pure overhead" caveat? — cannot be settled by reading; it must be measured. So: adopt in a scoped, pinned, measurable way on the repos where it can actually pay off, and let evidence decide global rollout.*

## 1. UNDERSTAND
CodeGraph pre-indexes a repo (tree-sitter → graph of 23 node-kinds / 12 edge-types → local SQLite + FTS) and serves it to the agent over MCP (10 tools), so the agent queries a *map* instead of grep+re-reading files. 100% local, no embeddings/API keys. Purpose: cut tokens + tool-calls on large repos.

## 2. CLAIM AUDIT (primary sources, not the video title — Mente Tomé)
| Claim (video, 2026-05-27) | Verified (2026-06-18) | Note |
|---|---|---|
| "~30k stars" | **51,594 stars** · 3,140 forks | grew — headline is *stale-low*, not inflated |
| "pre-1.0" | **v1.0.1** (released 2026-06-13) | that caveat is now resolved |
| single-author | owner `colbymchenry` (User) · **36 contributors** | one owner, real community |
| license | **MIT** · 100% local | permissive + privacy-safe ✓ |
| maturity | created 2026-01-18 · pushed **today** · **266 open issues** | very active = churn + maintenance load |
| benchmark "35% cheaper / 70% fewer tool calls" | author-own, single-model, **gains scale with repo size** | unverified on *our* workflow — the crux |

## 3. COMPARE / CROSS (decision-matrix)
| Axis | Reading |
|---|---|
| **Benefit** | Real + **non-redundant** capability: live, agent-queried code-graph retrieval — token/tool-call savings **on large repos**. |
| **Redundancy (Strata)** | LOW. Internal similars `graphify` + `understand-anything` v2.8.0 are **one-shot, human-facing** graph builders; `Context7` = docs-graph. None serve a live query-time graph to the agent → CodeGraph is complementary, not a duplicate. |
| **Conflicts** | Tool-surface bloat: +10 MCP tools onto an already very large MCP surface (overload risk). |
| **Collaborations** | Could **complement** `understand-anything` (deep one-time human audit) on the biggest repos. |
| **Cost** | Install low (npm + MCP register). Maintenance **medium-high** (T4 single-owner · 266 open issues · fast churn → upgrade treadmill). Token: small per-query, offset by the savings *if* the savings materialize. |
| **Trust-tier ([C12])** | **T4** (individual, unverified) — mitigated by MIT + 100% local + 51k stars + 36 contributors. Requires **version/SHA-pin + operator gate** before any enable. |
| **Expansion** | Gains scale with repo size → only the big repos (`k8s-eks-prd-002`, `vks-*` monorepos). Context-window-fit repos = no benefit (author agrees). |

## 4. VALIDATE — the decisive fit-risk (CASC)
The author's own docs warn: **"if your agent hands work off to file-reading sub-agents, CodeGraph becomes pure overhead."** This operator's workflow is **heavily sub-agent fan-out** (Explore / Task / maos orchestration). A sub-agent that re-reads files does **not** benefit from the parent's CodeGraph MCP context → the headline 70%-fewer-tool-calls could erode toward zero (or net-negative from index overhead). **This is workflow-specific and unknowable without measurement** — it is the single fact that flips the verdict. Security/CASC otherwise green (local-only, MIT, no secrets, reversible).

## 5. DECIDE — why ADAPT + DEFER, not INSTALL or ABANDON
- **Not blanket INSTALL** — the benefit is conditional (large-repo + low sub-agent-delegation) and unmeasured on our stack; T4 trust + churn argue against an unpinned global enable.
- **Not ABANDON** — the capability is real, non-redundant, MIT, 100% local, and demonstrably popular.
- **ADAPT** — adopt in a **scoped, pinned, measurable** form first.

### Recommended scoped trial (the actionable next step — separate operator GO)
1. Pick ONE large repo (`k8s-eks-prd-002` or a `vks-*` monorepo).
2. Register CodeGraph **project-scope** (that repo's `.mcp.json` / `--add-dir`), **version-pinned to `@1.0.1`** (T4 → pin), via `claude-code-concierge --mode=install` (confirm-gated, [C12]/[C14]/[C13]).
3. Run a representative task **with vs without** CodeGraph; measure the **actual tool-call / token delta** — including a sub-agent-fan-out task (the caveat test).
4. Decision gate: meaningful delta on *our* workflow → promote to user-scope; negligible/negative → ABANDON + record. This becomes the **child Agentic Step** under VKS-2244.

## 6. Simpler-alternative + revisit
- **Simpler alternative**: lean harder on the already-installed `understand-anything`/`graphify` for human-facing comprehension; rely on native search for context-window-fit repos (no new MCP).
- **Revisit trigger**: CodeGraph adds sub-agent-aware indexing (kills the caveat), OR the operator's workflow shifts away from fan-out, OR a large-repo task is observably tool-call-bound.

---
*Verdict produced by `agentic-tool-intake` — composes forge(research)+concierge(trust/install)+CASC; adds the decision-matrix. No install performed.*
