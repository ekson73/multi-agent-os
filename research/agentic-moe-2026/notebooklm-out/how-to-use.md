---
title: "MAOS Agora — How To Use It (today)"
audience: operator / engineer
date: "2026-06-29"
source: faithful to the seam as merged (#180) + ADR-006 (Accepted) + the dogfood plan (issues #182/#183). Describes only what exists today + the one near-term step; no speculative features.
---

# MAOS Agora — how to use it today

## What exists right now (usable)
The **gating-seam** is merged into `mcp-tools/maos-mcp-hub/lib/gateway/`. It is **off by default** — so today it changes nothing unless you opt in by giving it a *profile* (the set of enabled tool ids).

### Conceptually, the contract is one call
```
resolver.check(tool_id) -> PolicyDecision(allow | deny + reason)
```
- **No profile set** (`policy=None`) → everything is allowed (passthrough). This is the current production behaviour across all 96 gateway actions.
- **A profile set** → a tool is **denied** if it's *not in the profile* (explicitly disabled) **or** it *conflicts* with something already active (one of the 16 edges in `conflicts.yaml`). The deny comes back in the normal `_agent_feedback` envelope, with a human-readable reason.

### Where the knowledge lives
- The conflict graph: `mcp-tools/maos-mcp-hub/lib/gateway/conflicts.yaml` (edit/extend it to add a known incompatibility — `[a, b]` pairs or `{a, b, reason}` mappings).
- The resolver: `lib/gateway/policy.py` (`PolicyResolver.from_yaml(...)` loads the edges; the *profile* is injected by the caller, never auto-discovered).

## The one near-term step (the actual next feature)
The **conflict-checker** — a single-input tool that, given your active stack, reports the collisions — is the next thing to build, and it must be **dogfooded on our own ~26-tool stack first** before any public demand probe.
- Tracking: **issue #182** ([dogfood] conflict-checker — implement + self-use proven) blocks **issue #183** (the R2 demand-probe; the post is written but **must not be published** until #182 is done).
- Definition of done for #182: runs end-to-end on our stack, reproduces the **6 known collisions** modelled in `conflicts.yaml`, generates the report, and we use it for ≥1 real cycle.

## What you should NOT expect yet
- ❌ A public "curated front-door" / registry / console — that's **ADR-007, Draft (frozen)**, deliberately not built until demand is proven.
- ❌ Automatic model-routing (LiteLLM) / OTel export — deferred (anti-over-engineering until ≥3 incidents).
- ❌ Any external announcement — dogfood-first.

## The one rule to remember (now active guidance)
**Single-conductor invariant:** MAOS is the always-on conductor — do **not** co-install competing instruction-layer managers (ECC / superpowers / gstack / BASE) as resident layers. Route them in isolation via `agentic-tool-intake`, reuse their *patterns* (DRY), never stack their runtimes.

---
*This describes only shipped behaviour (#180) + the single tracked next step. When the conflict-checker lands, this file gets a "how to run it" section.*
