---
name: ichnos
description: |
  Use to apply Google-Analytics-style usage analytics to our OWN agentic-tools corpus —
  attribution (how was a skill actually reached: a direct /command, an explicit Skill-tool
  call, or a referral/citation from another skill's own body), recency+frequency+retention
  (RFM-lite: is usage a one-shot burst or sticky repeat-usage over distinct days), trend
  (this window vs the prior window), and funnel drop-off across known multi-step lifecycle
  chains (e.g. forge -> evaluate -> train). Composes corpus-firing-audit's log sources and
  NEVER re-implements its binary FIRING/DORMANT classification — Ichnos answers a different
  question ("how is it found and used, over time?") that a snapshot count cannot. Triggers -
  "apply GA principles to our tools", "usage analytics for our skills", "which tools are
  sticky vs one-shot", "why is X dormant: attribution/awareness/discoverability?", "funnel
  for the forge/quiesce lifecycle", "traffic/attention across our agentic-tools".
metadata:
  version: "1.0.0"
  scope: AAIF cross-vendor (log sources are Claude/Codex/pi-specific; the method generalizes)
---

# Ichnos (ἴχνος, "footprint/track") — Agentic Usage Analytics

## Overview

Web/app analytics tools (Google Analytics and peers) do not just count hits — they attribute
*how* a visitor arrived (channel), measure *recency+frequency+retention* (is this visitor
sticky or a one-time bounce), track *funnels* (where a multi-step journey drops off), and
compare *trend* (this period vs the last). Ichnos applies that same discipline to our own
agentic-tools corpus, because the raw firing count alone conflates very different situations:
a skill invoked 10 times in one afternoon and never again looks identical, on a bare counter,
to one invoked once a week for ten weeks — yet one is a novelty and the other is a habit.

**Distinct-from `corpus-firing-audit`** (DRY — composes, never duplicates): that skill answers
a binary question (does this artifact fire at all, kind-aware, THEATER-vs-DORMANT-OK) from a
point-in-time snapshot count. Ichnos consumes the **same 3 log sources** but keeps the
**timestamp + session-id per hit**, which corpus-firing-audit intentionally discards after
summing — that richer event stream is what makes attribution/RFM/trend/funnel possible.
Ichnos is a strict *addition* on top; it never re-scores FIRING/DORMANT/THEATER/STALE itself.

## GA-principle -> Ichnos mapping

| GA / analytics concept | Ichnos equivalent | How it's computed |
|---|---|---|
| Acquisition channel (direct / organic / referral / campaign) | **Attribution**: `direct` (matched a `<command-name>/x`), `explicit` (an agent called `Skill x` by name), `referral` (another skill/agent/command/protocol's own body cites `skills/x` or `maos:x`) | 2 regex anchors over Claude/Codex/pi JSONL + a corpus-wide `rg` for cross-references |
| Impressions -> Clicks (CTR) | Every skill is "shown" every session (listed in the tool catalog); direct+explicit hits are the "clicks" | not a true impression count (no denominator of sessions-that-saw-the-listing) — treat as a **directional** proxy only, not a literal rate |
| Recency + Frequency (RFM) | `recency_d` (days since last hit), `days_active` (distinct calendar days with >=1 hit) | derived from each event's ISO timestamp |
| Retention / Cohort | `NEVER` (0 distinct days) / `ONE-SHOT` (exactly 1 distinct day, any volume) / `STICKY` (>=2 distinct days) | `days_active` bucketed — this is the metric raw totals cannot give you |
| Trend | `trend_recent` vs `trend_prior`: hits in the last window vs the window before it | window = `min(30d, half the observed log span)`, adaptive so a short log history doesn't produce a meaningless 30d/30d split |
| Funnel | hit-count per step of a **named, hardcoded** multi-step lifecycle chain, so drop-off is visible at a glance | v1 ships 2 chains (`genesis`, `quiesce-compose`) — see §Funnels |
| Bounce rate | **NOT built in v1** | needs full intra-session tool-call sequencing (was this the last tool-call before the session ended with no other agent skill touched?) — tracked as roadmap |
| Goal / Conversion | **NOT built in v1** | needs a join against a DIFFERENT data source (PR-merged / ticket-closed) per invocation — tracked as roadmap |
| A/B testing of variants | **NOT rebuilt** | that discipline already exists — the Gauntlet pairwise-critique method / `agentic-tool-evaluator`. Ichnos only *prioritizes* candidates for it (low-CTR + short/terse description = the exact profile the Gauntlet pilot's own dormant-skill-selection mistake should have screened for) |

## When to use

- "Apply Google-Analytics-style measurement to our agentic-tools."
- "Is skill X actually being used, or just called once and abandoned?"
- "Show the drop-off across the forge -> evaluate -> train (or any) lifecycle chain."
- "Which dormant skills are dormant because of description/attribution vs genuinely rare preconditions?" (this is the bridge back to the manual dormant-skill root-cause analysis this tool operationalizes and makes repeatable)

**When NOT to use**: scoring whether a rule/skill FIRES AT ALL (binary) -> `corpus-firing-audit`;
scoring the BEHAVIORAL QUALITY a tool induces -> `agentic-tool-evaluator`; improving a
tool's prompt -> `agentic-tool-trainer`; counting DOGFOOD promotion-gate cycles ->
`dogfood-ledger`; per-session re-orientation -> `pulse`.

## How it works

```bash
python3 scripts/ichnos-analytics.py
```

1. **Collect events** (read-only): for each of the 3 vendors, list JSONL files containing a
   relevant anchor (`rg -l`, cheap), then fully parse only THOSE files' matching lines to
   extract `(skill, vendor, channel, timestamp, session_id)`. Self-session excluded via the
   same environment-derived guard `corpus-firing-audit.py` uses (never a hardcoded path).
2. **Referral count**: for every skill, `rg -l` across `agents/ commands/ skills/ protocols/`
   for `skills/<name>` or `maos:<name>`, excluding the skill's own directory — a real,
   systematic version of the ad-hoc cross-reference check this tool was born from.
3. **Aggregate + bucket**: per skill, sum direct/explicit hits, compute `sessions` (distinct
   vendor+session-id pairs), `days_active`, `recency_d`, the adaptive-window trend pair, and
   the retention bucket (NEVER/ONE-SHOT/STICKY).
4. **Funnels**: for each named chain, print the hit-count of every step in order — the
   drop-off between steps is the finding (a step invoked 0 times while an earlier step fires
   heavily is very likely composed-into the earlier step, not literally unused).
5. **Write** `docs/audits/ichnos-<date>.md` (idempotent — regenerate, never versioned
   duplicates) + a one-line stdout pulse.

## Funnels (v1 — named chains, extend by editing the `FUNNELS` dict in the script)

- **genesis**: `agentic-tool-forge -> agentic-tool-evaluator -> agentic-tool-trainer` — the
  documented tool-genesis lifecycle. A live finding at authoring time: forge fires, evaluator/
  trainer do not — the formal eval/train steps are being bypassed by an ad-hoc manual process
  (a pairwise-critique pilot run directly, rather than invoking the two dedicated skills).
- **quiesce-compose**: `quiesce -> auto-pilot -> bot-finding-arbiter -> converge` — quiesce's
  own SKILL.md documents composing all three as its inner driver / per-finding handler / PDCA
  merge tool. A live finding at authoring time: quiesce fires heavily, the three composed
  primitives show 0 *direct* hits — exactly the "cited but never top-level-invoked" bucket a
  raw firing count cannot distinguish from genuine non-use.

## Roadmap (v2, honestly out of scope — not silently dropped)

1. **Bounce rate** — requires ordering ALL tool-calls within a session and checking whether
   an agentic-tool invocation was immediately followed by session end / no further agent
   action, vs. leading into further work.
2. **Goal/Conversion** — requires joining an invocation to a downstream outcome (a PR that
   later merged, a ticket that later closed) — a genuinely different data source (`gh`/Jira),
   not derivable from these 3 log vendors alone.
3. **True impression rate (CTR)** — requires a denominator of "sessions where this skill was
   listed in the available-tools context", which is not currently logged anywhere; today's
   `direct+explicit` counts are numerators without a true denominator.

## Guard-rails

Read-only corpus + read-only logs · fail-loud `rg` (an `rg` error must never silently read as
zero-hits — the exact anti-pattern `corpus-firing-audit.py`'s own Qodo-#346 finding fixed, and
this script inherits the same guard verbatim) · self-session excluded via environment, never a
hardcoded personal path · idempotent output (regenerate the same dated file, no duplicates
across reruns on the same day) · never mutates the audited skills — only ever writes its own
dashboard file.

## Provenance

Distilled during a live root-cause session on why 66/83 corpus skills showed as DORMANT in
`corpus-firing-audit-2026-08-15.md` — the manual, ad-hoc cross-reference check performed that
session (grep for citations, spot-check a handful of skills) is what this tool operationalizes
and makes systematic + repeatable for all 83, plus adds the RFM/trend/funnel dimensions a
one-off manual check could not produce. Building it surfaced (and fixed, in the same PR) a
real blind spot in `corpus-firing-audit.py` itself: its Claude-vendor anchor only matched
`<command-name>` tags and never detected an explicit `Skill`-tool call — a live measurement
(before/after) showed 8 skills (the `*-concierge` family + `chief-of-staff` + `voice-director`)
flip from DORMANT to FIRING once that second anchor was added. Named via the corpus's Greek-
soul convention: *Ichnos* (ἴχνος, footprint/track — the study of tracks, ichnology, is
literally the discipline of inferring behavior from where something walked) — chosen to be
distinct from, and pair cleanly with, `agentic-observability-protocol` (soul *Metron*, "measure"
— which scores RUN OUTCOME quality/SLIs; Ichnos scores TOOL USAGE/traffic. Metron asks "did the
action succeed?"; Ichnos asks "where did agents/humans walk, and did they come back?"). Cross-
link slug: `[[ichnos]]`.
