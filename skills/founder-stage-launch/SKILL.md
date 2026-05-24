---
name: founder-stage-launch
version: "1.0.0"
description: |
  Launch-stage discipline for an AI-native startup: turn early traction into a
  repeatable, channel-driven growth engine and build the company around the product,
  so operations run WITHOUT the founder in every loop. Provides the 3-element exit
  gate (defensible CAC·LTV·payback; production-hardened; ops without founder
  bottleneck), the failure modes (technical debt comes due, founder-as-bottleneck,
  security/compliance no longer deferrable, expansion before ready), and exercises
  (architectural audit + remediation sequencing, attention/bottleneck audit, SOC 2 /
  GDPR / HIPAA compliance workstream, lightweight PM operating system). Use when a
  founder says "we launched", "scale our growth", "I'm the bottleneck", "tech debt",
  "SOC 2 / GDPR / HIPAA / compliance", or "set up sprints / processes".
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

# Founder Stage 3 — Launch (prove the *business* deserves to grow)

If MVP proved the *product* deserves to exist, Launch proves the *business* deserves
to grow. Finding PMF was the hard part; now the challenge is **keeping** it while the
organization around the product keeps up. All three capability classes are in full
use and compound — coding builds the product, automation builds the company, research
operationalizes the knowledge.

## Goals

Turn early traction into a **repeatable, sustainable growth engine**; harden the
infrastructure underneath; and build an actual company around the product. The aim
isn't to remove the founder — it's to build operational systems that **free founder
attention for the decisions only a founder can make.**

## Exit gate — three elements

Advance only when all three hold:

- [ ] **Growth is repeatable and channel-driven** — you acquire users predictably
      through specific channels with **CAC, LTV, and payback period** you know and can defend.
- [ ] **The product handles production workloads** — infra hardened; security &
      compliance in order; reliability holds under real conditions (not just tested ones).
- [ ] **Operations run without founder bottlenecks** — processes + automation exist;
      you're no longer personally handling support, triage, sprint planning, or reporting.

## Failure modes → mitigations

| Failure mode | What it looks like | Mitigation |
|---|---|---|
| **Technical debt comes due** | MVP shortcuts now accrue interest under production traffic + new features | Architectural audit → targeted refactor → expand test coverage (exercise A) |
| **The founder becomes the bottleneck** | Decisions that should take an hour now take a week; support piles up because only you know the answer; tasks happen only when you remember | Audit everything you touch; systematize / delegate / keep only founder-judgment work (exercise B) |
| **Security & compliance no longer deferrable** | Real users, real data, enterprise contracts; theoretical risk becomes real exposure | Systematic review *before* scale; treat findings as required remediation, not suggestions (exercise C) |
| **Expansion before you're ready** | New markets/funding look like growth but introduce variables your product wasn't built for | Resist premature expansion; protect the original user base; expand only with evidence |

## Exercises (reusable prompts)

### A. Architectural audit + remediation sequencing

> "Audit my MVP codebase and produce a prioritized list of structural weaknesses,
> test-coverage gaps, and refactoring candidates. Then sequence the remediation across
> sprints: what must be fixed before the next release, what can run in parallel with
> feature work, and what is acceptable ongoing debt at this stage. Also help me
> capture the MVP-era architectural decisions that only lived in my head into the
> `CLAUDE.md` so future sessions share one mental model."

### B. Founder-attention / bottleneck audit

> "Run a structured audit of my current operational load: every recurring task, every
> decision that lands on me, every workflow that only happens because I remember it.
> Categorize each into: (1) automate entirely, (2) needs a human but not me, (3)
> genuinely requires founder judgment. For the automation candidates, design the
> workflow logic — trigger, decision rules, output, and where it goes when done."

### C. Security & compliance workstream

> "Surface code-level issues that commonly come up in SOC 2 / GDPR / HIPAA audits for
> my target market. Produce two things: a prioritized remediation sequence, and a
> list of the documentation + controls (audit logging, access management) an
> enterprise buyer will ask for before signing. Build this as a continuous workstream
> in the dev cycle, not a one-time project."
> *(AI scans aid but don't replace a qualified compliance review.)*

### D. Lightweight PM operating system

> "Design a lightweight product-management operating system that runs without me
> triggering it: a sprint cadence, a minimum spec template (what a spec must include
> before code touches a feature), a bug-triage decision tree, and a weekly metrics
> brief that pulls from my actual data sources. Then specify what an automation layer
> should run on schedule — ceremony scheduling, bug routing, report compilation."

## When to leave

- All three exit elements hold → advance to **`founder-stage-scale`**.

## Guard-rails

- Compliance/security AI output is an aid, not a substitute for qualified human review
  (especially before signing regulated-industry or enterprise contracts).
- "Free your attention" ≠ "remove yourself" — keep the founder-only decisions
  (product narrative, key relationships, high-stakes calls).

## Attribution

Adapted (process & methodology, original prose) from Anthropic, *The Founder's
Playbook: Building an AI-Native Startup* (2026-05-14) —
https://claude.com/blog/the-founders-playbook. No text reproduced verbatim.
