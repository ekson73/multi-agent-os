---
name: founder-playbook
version: "1.0.0"
description: |
  Diagnose where an AI-native startup is in its lifecycle (Idea → MVP → Launch →
  Scale) and route to the right stage discipline. Provides the four-stage map,
  per-stage goals/exit-criteria/failure-modes, and a vendor-neutral product matrix
  (conversational-research / agentic-coding / workflow-automation, with Claude
  Chat/Code/Cowork as reference). Use when a founder asks "where am I", "what
  should I focus on now", "am I ready to move to the next stage", "how do AI-native
  startups work", or wants an overview of the whole journey. For deep work inside a
  single stage, this skill hands off to founder-stage-idea / -mvp / -launch / -scale.
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

# Founder Playbook — AI-Native Startup Lifecycle (router)

A stage-gated coach for building an AI-native startup. This skill **locates** a
founder on the lifecycle and routes to the matching stage discipline. It encodes
the *process and judgment* from Anthropic's *The Founder's Playbook: Building an
AI-Native Startup* (see Attribution), generalized to be vendor-neutral.

## The core reframe

In an AI-native startup the founder shifts from **individual contributor** to
**orchestrator of agents** — specialized AI assistants that research, write and
run code, and automate operations. AI has removed the three classic gates between
stages: **capital, headcount, and technical skill**. The scarce resource is no
longer building — it's **judgment about what to build and whether it's working.**

## When to use this skill

- "I have an idea — where do I start?" / "where am I in the journey?"
- "Am I ready to move from MVP to Launch?" (exit-gate check)
- "What should I focus on / what's the biggest risk right now?"
- You want the whole-lifecycle overview or the tool-per-stage matrix.

## When NOT to use it

- You already know your stage and want to do the work → go straight to the stage
  skill (`founder-stage-idea` | `-mvp` | `-launch` | `-scale`).
- You need legal/financial/medical/security sign-off → this is judgment **support**,
  not a substitute for a qualified human reviewer. Keep a human in the loop for
  nuanced calls (interpreting user feedback, security on auth/secrets/data, compliance).
- It's not a fundraising deck generator or a guarantee of product-market fit.

## The four-stage map

| Stage | Goal (one line) | Exit gate (one line) | Signature failure mode |
|---|---|---|---|
| **Idea** | Validate a real problem before building | Problem-solution fit: 3 honest "yes" | Mistaking *building* for *validating* |
| **MVP** | Turn a validated problem into a used product | Genuine product-market-fit evidence | Compounding agentic tech debt; false PMF |
| **Launch** | Make growth repeatable; build the company | Channel-driven growth + ops without founder | The founder becomes the bottleneck |
| **Scale** | Systematic growth + a defensible moat | Threshold: profitability / IPO-ready / acquire | Can't delegate the operating layer |

## Stage diagnosis flow

Ask the founder these, in order — stop at the first "no":

1. **Do you have qualitative evidence (from real conversations, not surveys) that a
   specific group has this problem and that your solution addresses it?**
   - No → **Idea stage** → load `founder-stage-idea`.
2. **Do real users return to / pay for / refer the product (evidence of PMF, e.g.
   Sean Ellis ≥40% "very disappointed"; effort starts to *pull* not *push*)?**
   - No → **MVP stage** → load `founder-stage-mvp`.
3. **Is growth repeatable through known channels (CAC·LTV·payback you can defend)
   AND do operations run without you personally in every loop?**
   - No → **Launch stage** → load `founder-stage-launch`.
4. **Are you building systematic growth + a defensible moat, with the company
   sustainable even when you step back from day-to-day?**
   - Otherwise → **Scale stage** → load `founder-stage-scale`.

> A founder can be mid-stage. If unsure between two, pick the **earlier** one — the
> earlier discipline is cheaper to revisit than the failure mode it prevents.

## Product matrix (vendor-neutral)

Three capability classes power the lean startup; see
[references/product-matrix.md](references/product-matrix.md) for the per-stage
mapping. Claude (Chat / Code / Cowork) is the canonical reference implementation;
the framework holds for any AAIF-compatible toolset.

| Capability class | What it is | Reference tool |
|---|---|---|
| Conversational research | On-call expert: research, drafting, strategy partner | Claude (Chat) |
| Agentic coding | The always-available engineer: generate/test/debug/refactor | Claude Code |
| Workflow automation | The on-demand ops team: recurring tasks + integrations | Claude Cowork |

## Cross-stage anti-patterns (watch at every stage)

- **Speed as the only variable** — AI removes natural bottlenecks, so velocity is
  guaranteed; *judgment* is the scarce input. Easy prototyping inflates the risk of
  building something nobody needs.
- **Skipping persistent context** — without written specs/architecture/decisions
  (e.g., a `CLAUDE.md`/context file), each session re-derives foundations and drifts.
- **Treating early energy as proof** — launch spikes from friends, investor networks,
  or a front-page post don't predict week-6/week-12 retention.
- **Vendor lock-in** — keep the capability classes provider-agnostic so a single
  vendor outage or pricing change can't paralyze the company.
- **Founder as permanent bottleneck** — the job is to design the systems that do the
  work, not to keep doing all the work.

## How to drive the family

1. Run the **diagnosis flow** → name the stage.
2. Load the matching **stage skill** for goal + exit-criteria checklist + failure
   modes + ready-to-use exercise prompts.
3. Re-check the **exit gate** before advancing; advancing early is its own failure mode.
4. For an interactive coach persona (delegatable via the Task tool), use the
   `founder-coach` agent. To invoke this router explicitly, run `/founder-playbook`.

## Attribution

Framework adapted (process & methodology, original prose) from Anthropic,
*The Founder's Playbook: Building an AI-Native Startup* (2026) —
https://claude.com/blog/the-founders-playbook. No text is reproduced verbatim;
this skill encodes the framework for agent use under the repository's MIT license.
