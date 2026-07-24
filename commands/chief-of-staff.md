---
name: chief-of-staff
description: Operator work-focus conductor (Oikonomos) — "what should I focus on now, who asked me for what by when, any loose ends?" Aggregates all your backlogs, prioritizes (Eisenhower), surfaces the people-ask view, and presents one briefing. Composes work-compass + pulse + morning-briefing; reimplements nothing; read-only by default.
argument-hint: "[--mode catch-up|drift|who-owes-me|full] [--depth quick|full] [--scope all|jira|github|linear|sessions] [--who <person>] [--lang pt|en|auto] [--json]"
allowed-tools: Read, Grep, Glob, Task, AskUserQuestion
---

# /maos:chief-of-staff — Oikonomos

Thin wrapper that invokes `skills/chief-of-staff/SKILL.md`. The skill holds all logic
(the 5-phase GATHER → PRIORITIZE → SURFACE → BRIEF → PRESENT pipeline, the invariants,
the anti-patterns). **This file is the command surface only.**

> **Invocation**: canonical form is `/maos:chief-of-staff` (`plugin.json` sets
> `command_namespace.prefix_required=true`). The bare `/chief-of-staff` also resolves via the
> manifest's `permit_unprefixed_if_no_collision` fallback, but prefer the prefixed form in docs/scripts.

## Usage

```
/maos:chief-of-staff                          # quick catch-up: landscape + next-action + who-asked + loose-ends
/maos:chief-of-staff --mode drift             # what am I slipping? loose-ends first
/maos:chief-of-staff --mode who-owes-me       # the people-ask view first (who asked · by-when)
/maos:chief-of-staff --depth full             # + ops-strategist 4-lens (if present) + full SitRep
/maos:chief-of-staff --who "the boss"         # filter the people-ask view to one person
/maos:chief-of-staff --scope jira             # restrict the gather to one backlog
```

## What it does

Your operator-facing chief-of-staff — the human twin of the agent-facing `reactivate`/Entelecheia
(which orients a fresh **agent**; incoming in PR #280). It answers *"what should I focus on now?"* by:

1. **GATHER** — delegates `work-compass` to aggregate ALL scattered work into ONE N-Tree.
2. **PRIORITIZE** — delegates `pulse` (Eisenhower 2×2; the maos-resident core). `--depth full`
   optionally adds the richer user-scope `ops-strategist` 4-lens **if you have it**.
3. **SURFACE** — the people-ask view (who asked · when · by-when) projected over the native tracker
   fields `work-compass` already surfaces (Jira `reporter`/`duedate`, GitHub author/milestone…). Newly authored.
4. **BRIEF** — the `morning-briefing` 7-section SitRep contract.
5. **PRESENT** — ONE briefing: ▶ next-action · Eisenhower quadrants · ⏰ who-asked/by-when ·
   🧹 loose-ends. Read-only — any write/notify/schedule is PRINTED for your approval.

## Sibling routing (don't reach for this if…)

- Learn / route the MAOS **framework** itself → `/maos:maos-concierge`.
- Just the raw aggregated N-Tree, no prioritization → `/maos:work-compass`.
- Re-orient inside ONE session → `/maos:pulse`.
- A fresh **agent** woke with no context → `/maos:reactivate` (the agent-facing twin — incoming in PR #280).
- Sort a raw brain-dump into tickets → `/maos:directive-braindump-triage`.

## Guarantees

- **Route-never-reimplement** — composes the existing family; adds only the people-ask
  projection + tag/categorize + the unified front-door.
- **Read-only by default** — never executes a write/notify/schedule; prints for approval. No `Bash`
  in `allowed-tools` (least-privilege — all tracker access is delegated to `work-compass`).
- **On-demand only** — no hooks, no always-on runtime (MAOS stays the sole conductor).
- **Layer-pure** — runs fully on the maos-resident core; `ops-strategist` is optional, never required.
- **Explicit operator instruction wins** over every computed condition. ⛔ Never echoes secrets/PII.
