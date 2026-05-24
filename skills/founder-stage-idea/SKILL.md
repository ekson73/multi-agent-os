---
name: founder-stage-idea
version: "1.0.0"
description: |
  Idea-stage discipline for an AI-native startup: validate that a real, specific,
  frequent problem exists — and that your solution addresses it — BEFORE writing any
  production code. Provides the problem-solution-fit exit gate, the signature failure
  modes (mistaking building for validating; "no competition" as advantage; surveys
  instead of interviews), and ready-to-use prompts for problem-hypothesis sharpening,
  competitive-landscape synthesis, and customer-discovery interviews. Use when a
  founder says "I have an idea", "should I build this", "validate my idea", "customer
  discovery", "is there a market", or "who are my competitors".
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

# Founder Stage 1 — Idea (validate before you build)

The Idea stage is where the most consequential mistakes are made. With AI removing
technical blockers, the temptation is to build immediately. The discipline of this
stage is the opposite: **don't build until the evidence justifies it.** The work is
research, customer discovery, competitive analysis, and honest evaluation of
disconfirming evidence — all *before* the first line of production code.

## Goal

Research-oriented validation: assemble solid, mostly **qualitative** evidence (from
real human conversations) that a real problem exists and that your proposed solution
addresses it, before committing resources to building.

Get specific before you get moving. *"People struggle with expense reporting"* is an
observation. *"Finance managers at mid-market companies spend 4+ hours/week
reconciling submissions because their tools don't integrate with their accounting
software"* is a **testable hypothesis.**

## Exit gate — problem-solution fit

Advance only when you can answer **yes to all three**:

- [ ] **Is the problem real and specific?** You can name exactly *who* has it, *how
      often* they hit it, *how severely* it affects them, and *what they do about it today.*
- [ ] **Does your solution address the actual problem** the validation revealed (not
      the one you originally assumed)?
- [ ] **Do you have enough signal to justify building?** You'll never have certainty
      — waiting for it is itself a failure mode — but committing to an MVP must be a
      reasoned decision, not an act of faith.

## Failure modes → mitigations

| Failure mode | What it looks like | Mitigation |
|---|---|---|
| **Mistaking building for validating** | Spinning up a prototype *feels* like progress; ~42% of startups historically fail building something nobody wanted, and easy prototyping raises that risk | Keep the coding tool closed until the 3 exit questions are "yes" |
| **"No competition" as an advantage** | "Nobody else does this" treated as a moat | Usually means no market, or you haven't looked hard enough — map substitutes and the status quo |
| **Surveys instead of interviews** | Aggregated survey data stands in for real conversations | Run deep 1:1 interviews; aim for first-hand transcripts, not Likert averages |
| **Solution obsession** | Falling in love with the build, ignoring the problem | Re-anchor on the problem's specificity and frequency every iteration |

## Exercises (reusable prompts)

### A. Sharpen the problem hypothesis
> "Here is my rough idea: <idea>. Rewrite it as a single testable problem hypothesis
> naming the exact user, the frequency, the severity, and what they currently do
> instead. Then list the 5 riskiest assumptions in it and, for each, the cheapest way
> to disconfirm it through conversation — not a survey."

### B. Map the competitive landscape
> "For the problem '<problem>', map how it is solved today: direct competitors,
> indirect substitutes, and the do-nothing/status-quo option. For each, summarize how
> well it solves the problem and where it fails. Then state the 3 sharpest, defensible
> differences a new solution would need — and flag if 'no competition' actually means
> 'no market'."

### C. Customer-discovery interview kit
> "Draft a customer-discovery interview guide for '<user segment>' about '<problem>'.
> Use open, non-leading questions focused on past behavior ('tell me about the last
> time…') not hypotheticals. Include a screening question to confirm they actually
> have the problem. Then give me a 1-page synthesis template to fill after each
> interview that captures evidence for/against the hypothesis."

### D. Build the interview target list
> "From these public signals (<communities, job titles, forums, reviews>), produce a
> prioritized outreach list of people likely to have '<problem>', with a one-line
> reason each and a short, non-salesy outreach message."

## When to leave / when to loop

- All 3 exit questions "yes" → advance to **`founder-stage-mvp`**.
- Evidence contradicts the hypothesis → that's the system working. Explore an
  adjacent segment, adjust the value proposition, or sharpen the problem — *before*
  over-investing in the wrong answer.

## Guard-rails

- This is judgment **support**, not a verdict. The interview *interpretation* — is a
  request a core need or a nice-to-have? — requires a human.
- Don't outsource the conversations themselves; founder-led discovery is the signal.

## Attribution

Adapted (process & methodology, original prose) from Anthropic, *The Founder's
Playbook: Building an AI-Native Startup* (2026-05-14) —
https://claude.com/blog/the-founders-playbook. No text reproduced verbatim.
