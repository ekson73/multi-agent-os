---
name: founder-stage-mvp
version: "1.0.0"
description: |
  MVP-stage discipline for an AI-native startup: turn a validated problem into the
  smallest focused product that real users actually use, while moving fast WITHOUT
  accruing compounding technical debt. Provides the product-market-fit exit gate
  (Sean Ellis ≥40% "very disappointed"; the pull-vs-push effort test), the failure
  modes (agentic tech debt, false PMF, zero-friction scope creep, insecure-by-
  inexperience), and emittable templates (architecture-context / CLAUDE.md, scope
  definition, pre-launch measurement framework, security-review brief, pivot
  diagnostic). Use when a founder says "build the MVP", "define architecture/scope",
  "do I have product-market fit", "security review", "set up metrics", or "should I pivot".
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

# Founder Stage 2 — MVP (evidence, not completeness)

The MVP stage is still an **evidence-gathering exercise** — now about the *solution*:
does a specific, identifiable group find it valuable enough to return to, pay for, or
tell others about? Build the smallest, most focused iteration that puts a real
solution in front of real users.

## Goals

1. Translate a validated problem into a **working product real users actually use**
   (not the full roadmap — the focused core).
2. **Move fast without compounding technical debt.** Some debt is fine at MVP if
   managed before scaling; *agentic* debt compounds because, without written specs
   and constraints, each AI session re-derives foundations and drifts.
3. **Invest in persistent context from day one.** Your codebase is something you
   collaborate with AI on session after session — legibility is foundational.

## Exit gate — genuine product-market-fit evidence

PMF is a **pattern that holds across multiple iteration cycles**, not one data point.
Advance when you have real evidence that a specific group finds the product valuable
enough to return (retention), pay (revenue), or refer (referral). Useful litmus tests:

- [ ] **Sean Ellis test** — ask active users: *"How would you feel if you could no
      longer use this?"* **≥40% "very disappointed"** is a meaningful PMF signal.
- [ ] **Effort test (pull vs push)** — pre-PMF, retention needs constant founder
      intervention (outreach, incentives, follow-up). Post-PMF, the product starts
      doing that work itself. When things **pull instead of push**, something real changed.
- [ ] Retention, activation, and Day-7 / Day-30 targets (set *before* launch) are met.

## Failure modes → mitigations

| Failure mode | What it looks like | Mitigation |
|---|---|---|
| **Agentic technical debt** | Each session re-derives architecture; pieces never designed to fit; collapses late | Define + persist architecture (template A) before building; 5-min per-session log |
| **False product-market fit** | Launch-spike enthusiasm (friends, investor networks, a front-page post) read as PMF | Set the measurement framework *before* launch (template C); define what a false positive looks like |
| **Zero-friction scope creep** | Every extra feature is individually defensible and "only an afternoon" | Written scope doc with explicit non-goals + a feature-amendment bar (template B) |
| **Insecure by inexperience** | AI writes code that *works*, not code that's *secure*; vulns invisible until exploited | A security review before any real user touches it (template D); human review for auth/secrets/data |

## Emittable templates (ask the agent to produce these, then save them)

### A. Architecture-context (`CLAUDE.md`) — define BEFORE coding

> "I'm building <product> for <users>, expecting <realistic 6-month scale>. Help me
> define the architectural principles that should govern the MVP, the dependencies to
> avoid given my constraints, and the tradeoffs I'm consciously accepting now. Output
> a concise `CLAUDE.md` I can drop at the repo root as persistent project memory."

### B. Scope definition — define BEFORE building features

> "Draft a scope document for my MVP: what it **does**, what it **deliberately does
> not do**, and a feature-amendment bar — the specific real-user evidence that would
> justify adding something. Phrase the bar so the question shifts from 'should we
> build this?' to 'have a critical mass of users said they can't get value without it?'"

### C. Pre-launch measurement framework

> "Define the metrics that matter for <product>: retention benchmarks, activation
> criteria, and Day-7/Day-30 targets. Then define what a **false positive** looks
> like for this product (e.g., signups without activation, revenue without retention).
> When data arrives, make the adversarial case against my own traction."

### D. Security-review brief (before any real user)

> "Review my core application code for: authentication & session handling, data
> exposure in API responses, input validation & injection risks, and dependencies
> with known vulnerabilities. For each finding, say whether it needs a fix and flag
> anything touching auth, secrets, or data for mandatory human review."

### E. Session template (use every agentic-coding session)

> Start: revisit the scope doc + load the persistent context file (e.g., `CLAUDE.md`). End: append a brief log
> — what was built, what decisions were made, what assumptions were introduced.
> *Five minutes of documentation per session is cheap insurance against drift.*

### F. Pivot diagnostic (after 3+ iteration cycles with no PMF movement)

> "Here is my retention data, user feedback, and original problem hypothesis. Answer:
> (1) Is a segment responding differently than the rest? (2) Is the value gap a
> positioning problem or a product problem? (3) What would have to be true for the
> current product to find genuine PMF — and is that realistic given the data?"

## When to leave / when to loop

- PMF evidence holds across cycles → advance to **`founder-stage-launch`**.
- No movement after ≥3 cycles → run template F; let the answers decide whether to
  adjust onboarding/messaging, pivot the segment/value-prop, or return to **Idea**.

## Guard-rails

- AI security review is a useful first pass, **not** a substitute for security tooling
  or a human reviewer on high-stakes paths.
- Keep a human interpreting feedback ("great, but I wish it could also…" — core need
  or nice-to-have? one customer or a segment?).

## Attribution

Adapted (process & methodology, original prose) from Anthropic, *The Founder's
Playbook: Building an AI-Native Startup* (2026-05-14) —
https://claude.com/blog/the-founders-playbook. No text reproduced verbatim.
