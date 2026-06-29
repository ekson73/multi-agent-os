---
title: "MAOS Agora — Executive One-Pager"
audience: human / executive (zero jargon)
date: "2026-06-29"
source: distilled faithfully from research/agentic-moe-2026/ (digest §B–§D + ADR-006/007 + goal-loop-closure). No claim here that isn't in those sources.
---

# MAOS Agora — what it is, why it matters (1 page)

## In one sentence
We studied the whole open-source landscape of AI-coding-agent tools, found it is **not one market but a stack of layers** best used together, and built the **first piece of a "smart switchboard" (a Hub)** inside our own MAOS framework that picks the right tool for each task — **without breaking the others**.

## What it is (plain words)
- A **Hub** = a coordinator that, before running any tool, checks *"is this tool allowed, and does it clash with something already running?"* — like a power strip that refuses a plug that would trip the breaker.
- It lives **inside MAOS** (the framework we already own), not as a new product. MAOS already did ~70% of the work; we added the missing **"teeth."**
- The name **`MAOS Agora`** (the Greek *agora* = meeting + vetted marketplace + forum) was chosen by our naming agent.

## Why it matters for Vek (productivity)
- **Less vendor lock-in** — we compose the best of many tools instead of betting the company on one.
- **Less "token tax"** — naively loading every tool's full description costs **10,000–60,000 tokens *per turn***; the Hub's design shows only short summaries until a tool is actually needed (real money + speed saved at scale).
- **Install-the-right-tool-without-breaking-the-rest** — the #1 concrete pain we can solve: many popular tools quietly **conflict** (two of them fight over the same config; one bans a browser tool another needs). The Hub knows the **16 known conflict pairs** and stops the collision before it happens.
- **Safety by default** — the study caught a real **crypto-token rug-pull** (`$GSD`) and a star-manipulation case (`MemPalace`) in popular tools; our Hub is built to **refuse those by default**.

## Why it matters for the community (honest)
- The bigger vision — MAOS becoming the **trusted, curated front-door** to the best of the agentic open-source commons — is a **destination we have to *earn*, not a fact today.** It's deliberately **frozen** until real demand shows up. We ship the useful core now; we don't over-claim.

## Where we actually are (verified)
- ✅ The Hub's core ("the seam") is **built, tested, and merged** — and proven to change **zero** existing behaviour (it's off-by-default).
- ✅ The decision to absorb this into MAOS is **ratified** (ADR-006 Accepted).
- ⏸️ The "trusted front-door platform" identity is **on hold** (ADR-007 Draft) pending real demand.
- ⏸️ We will **not** advertise it publicly until we've used the conflict-checker on our own stack first (dogfood-first).

## 3 next steps
1. **Dogfood** the conflict-checker on our own ~26-tool stack (prove it's useful to *us* first).
2. **Then** run a small, time-boxed demand test with the community — with a pre-agreed "kill switch" if interest is weak.
3. **Harden the safety floor** (make the security scan block bad merges) — in progress.

---
*Caveat: tool "popularity" numbers in the research are dated order-of-magnitude snapshots (2026-06-27), not precise metrics. "Platform" = aspiration to be earned. Distilled with no added claims; full evidence in `research/agentic-moe-2026/`.*
