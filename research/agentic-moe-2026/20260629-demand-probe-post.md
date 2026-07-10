---
title: "R2 demand-probe — ready-to-fire munition (agent-drafted, operator-posts)"
date: "2026-06-29"
purpose: "Close the SOFT half of R2. The agent drafts the probe + the falsifier; the operator posts it (HARD: needs the operator's own accounts). Reduces the irreducible HARD residual to one click."
classification: "SOFT-done (this artifact) + HARD-escalated (the operator posting)"
source_of_truth: "conflicts.yaml (16 edges) · 20260627-02-ntree-moe.md · 20260628-solutions-debate.md §3 (wedge)"
lang: "EN (target = Claude Code Discord / r/ClaudeAI — an EN community)"
---

# The R2 demand-probe — the cheapest experiment that can kill or confirm the wedge

> **⚠️ REFRAMED 2026-07-10 (ADR-007 Amendment — publish-by-default doctrine).** This post is now an
> **optional dissemination/contribution artifact** (operator-sovereign, no deadline, no ADR/roadmap
> consequence). Making the work available IS the contribution; adoption is each community member's
> sovereign choice — not our validation gate. The §D kill-criterion below is retained verbatim as
> **historical pre-registration / calibration telemetry only** — its decision authority over ADR-007
> was revoked. The "Why this exists" block below reflects the original (superseded) framing.

> **Why this exists.** Round 3 (Gates / Zuckerberg / Musk) converged: the *pain* is real
> (evidence-backed prior ~0.68), but *willingness-to-adopt* is **HARD** — only the world's
> pull-signal resolves it, and no further deliberation moves it. Per the loop's own rule, the
> agent does the SOFT part (draft the probe + the matrix + the kill-criterion) and escalates only
> the HARD act (the operator posting from their own accounts). **One click closes the loop.**

---

## A) The post — Reddit / r/ClaudeAI (long form)

**Title:** We ran 26 agentic tools in one workspace. 6 pairs silently collided. Here's the map — paste your stack and I'll tell you what breaks.

**Body:**

Spent a week mapping the agentic-tooling landscape (plugins, MCPs, skills, harness add-ons) to
build a stack. The surprise wasn't "which tool is best" — it was how many *silently fight each
other* when installed together. Not crashes. Quiet breakage: duplicate hooks, two configs
overwriting each other, one tool banning the exact MCP another one ships, two "memory backends"
both claiming the same slot.

We found **16 concrete incompatibility edges** in a 26-tool set. The pattern is always one of five
shapes:

| Collision shape | What actually breaks | Real example from our set |
|---|---|---|
| **Two `CLAUDE.md` managers** | duplicate hooks, config sprawl, nondeterministic precedence | `ECC × base`, `ECC × gstack`, `gstack × carl` |
| **Two always-on instruction layers** | stacked context erosion, unpredictable which "rules" win | `superpowers × gstack`, `superpowers × ECC` |
| **Banned-vs-expected tooling** | one tool bans the MCP another bundles → silent tool-not-found | `gstack` bans the browser-MCP `ECC` ships |
| **Two spec systems** | two spec dirs + two conventions = drift, nobody's SSOT | `spec-kit × openspec`, `openspec × gsd-core` |
| **Two memory/runtime backends** | lock-in + embedding/namespace contention on the same slot | `mem0 × letta`, `letta × cognee`, `mem0 × cognee` |
| **Two hook engines / heavy orchestrators** | double execution per prompt; over-kill stacking | `carl × ECC`, `ruflo × bmad-as-runtime` |

None of these throw an error at install. You find out when something gets weird three days later.

**The ask:** paste the agentic tools you run together (plugins / MCPs / skills / harness mods) and
I'll reply with what collides in *your* set — the L0 config clashes, the token-tax hogs, and any
copyleft (AGPL/NONE) license traps. No signup, no tool to install. Just the report.

The checker is already a small open-source CLI (`bin/conflict-checker.py` in the
[multi-agent-os](https://github.com/ekson73/multi-agent-os) repo) — paste a stack file into it
locally if you'd rather not share your stack publicly. And if the collisions turn out rarer than
they looked in our set, I'll happily learn that too.

---

## B) The post — Claude Code Discord (short form)

> Mapped 26 agentic tools for our stack — **6 pairs silently collide** (duplicate `CLAUDE.md`
> hooks, one tool banning the MCP another ships, two spec dirs fighting, two memory backends on the
> same slot). Built a 16-edge conflict map.
>
> **Paste your plugin/MCP/skill stack and I'll tell you what breaks** (config clashes · token-tax ·
> AGPL/NONE license traps). No signup — or run the open-source checker yourself
> (`bin/conflict-checker.py` in the multi-agent-os repo). 👇

---

## C) Instrumentation — measure PULL, not views (Gates + Zuckerberg)

The probe is only worth running if it's falsifiable. Measure:

| Signal | Pull (counts) | Vanity (ignore) |
|---|---|---|
| **Primary** | unsolicited "this would save me / I need this" replies | upvotes / views |
| **Primary** | people who actually **paste their stack** | "cool, nice" comments |
| Secondary | DMs asking for the checker / "is X compatible with Y?" | reactions |
| Secondary | stars/forks if a gist of the matrix is linked | impressions |

The thesis is "people paste *their own* stack" — a real `conflicts.yaml` submission is one new edge
you didn't have (the **data-network-effect** Zuckerberg named). Pastes are the moat seed; views are
noise.

## D) Kill-criterion — the falsifier (Musk red-team, pre-registered)

> **⚠️ HISTORICAL PRE-REGISTRATION — decision authority REVOKED (ADR-007 Amendment 2026-07-10).**
> Under the publish-by-default doctrine this section no longer decides ADR-007's fate. Kept verbatim
> as calibration telemetry: if the post is ever published, score against it for LEARNING (how well
> did we predict pull?), never for roadmap authority. WAVE-6 entry is governed by per-tile internal
> usefulness + the 7 guardrails + operator HITL (see the ADR amendment).

- **KILL ADR-007** if, within **2 weeks**: fewer than **~10 unsolicited "this would save me"**
  signals AND fewer than **~5 real stack-pastes**. That = the wedge has no organic pull; freeze the
  platform identity for good.
- **CONFIRM the wedge** (re-open ADR-007 toward ratifiable) if pastes clear the bar AND ≥1 paste
  reveals a collision *we didn't have* (proves the inbound-curation flywheel, not just our N=1).
- **Either way, ADR-006 stands.** Musk's irreducible floor (~0.30–0.35) is own-infra: the
  gating-seam is test-proven (Loop 2, 16/16, 0-regression) and MAOS consumes it itself. The Hub is
  valuable independent of this probe's outcome. The probe only decides the *platform* ambition.

## E) Operator checklist (the HARD step — only you can do this)

- [ ] Pick the channel (r/ClaudeAI long-form **or** Discord short — or both, staggered a day apart).
- [ ] (optional) Publish `conflicts.yaml` as a public gist titled "Agentic-Tool Conflict Matrix" and link it (passive stars = extra pull-signal).
- [ ] Post from your account — whenever (or if) you want; this is dissemination, not an experiment with a clock.
- [ ] When stacks come in: reply with the per-stack report (the checker `bin/conflict-checker.py` does it now). Each real paste → append an edge to `conflicts.yaml`.
- [ ] (optional) Score against (D) as calibration telemetry — learning only; no ADR/roadmap consequence.

---
*Agent-drafted munition · the post itself is the product's first advertisement (the output IS the ad). EKO-66: nothing here is auto-posted — the operator fires it.*
