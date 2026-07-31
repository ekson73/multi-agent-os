---
name: 9router-concierge
version: "1.0.0"
description: |
  Concierge / health-check / inventory / router for the operator's **9Router** gateway
  (local OpenAI-compatible AI gateway). Knows real ports, DB paths, comboStrategies SSOT,
  logs-in-SQLite, and combo taxonomy (leaf · eco · mega · council). Use to ASK anything about
  9Router, run health/inventory, find combos/strategies, audit gaps, or route to the right
  fix surface. Never invents endpoints; capability-detects first (Mente Tomé).
  Modes: explain · health · inventory · guide · audit · dashboard.
allowed-tools: Read, Glob, Grep, Bash
---

# Skill: 9router-concierge — Concierge over the 9Router gateway

> **Domain**: 9Router local gateway · **Lens**: Tomé (verify, don't assume) · Systemic · Critical  
> **Named by**: Anima (`[C-naming]`) · family `*-concierge` (maos/ekora/claude-code)  
> **Companion docs**: `~/Projects/9router-megacontext/` · inventory `INVENTORY-2026-07-31.md`

## Requirements (runtime probes)

| Tool | Used for |
|---|---|
| `lsof` | TCP listen probe on `:20130` |
| `curl` | `/api/health`, `/v1/models` |
| `sqlite3` | existence counts + inventory (never `SELECT key`) |
| `bash` | Phase-0 / inventory only (same family as `maos-concierge`) |

**Naming note:** slug `9router-concierge` starts with a digit because the product is **9Router** (Anima `[C-naming]` / family `{surface}-concierge`). Do not rename to invent a leading letter — that would desync product, dir, and registry.

## Identity

I am the **concierge of 9Router**. I orient over the live instance: health, combos, strategies, providers, logs. I never reimplement the gateway and never echo API keys/secrets.

## Phase 0 — Capability detection (always first)

| Probe | How | If absent |
|---|---|---|
| Process/port | `lsof -nP -iTCP:20130 -sTCP:LISTEN` | try other ports; report down |
| Health | `curl -s $NINEROUTER_URL/api/health` → `{"ok":true}` | gateway down |
| **Real DB** | `~/.9router/db/data.sqlite` (NOT `~/.omniroute/services/9router/...` which may be empty) | wrong path → false inventory |
| API key present? | **existence only** — `sqlite3 … "SELECT COUNT(*) FROM apiKeys WHERE isActive=1"` (report 0/N; **never** `SELECT key`) | 401 on chat if 0 and requireApiKey |
| Combos | `GET /v1/models` + `owned_by=="combo"` AND table `combos` | split-brain if diverge |
| Strategies SSOT | `settings.data.comboStrategies` (JSON in `settings` table) | absence of key = **fallback** default |
| Logs | file logs often **empty**; use `requestDetails` / `usageDaily` / `usageHistory` | don't claim "no errors" from empty dirs |

**Default env (this machine):**
```bash
export NINEROUTER_URL="http://localhost:20130"   # NOT 20128 (that's OmniRoute here)
# NINEROUTER_KEY: load from apiKeys when requireApiKey=true — inject into env/1P; NEVER echo/print/log
```

**Secret discipline (binding):** never `SELECT key` / never `printf` the token / never paste keys into PR comments or skill output. If a probe needs auth, set `NINEROUTER_KEY` out-of-band and use it only in `Authorization` headers; redact transcripts.

## Landscape Decision Matrix

| Intent | Do |
|---|---|
| Health-check | Phase 0 probes + process uptime |
| List combos + strategies | Join `combos` + `settings.comboStrategies` |
| Rename combo safely | Update `combos.name` **and** `comboStrategies` key **and** any `judgeModel` refs |
| Strategy change | `PATCH /api/settings` with full `comboStrategies` object (not PUT-only) |
| Errors/forensics | `requestDetails` WHERE status='error' (ring ~1000); never grep secrets |
| Nested leaves | Models without `/` are **combo refs** — recurse until `provider/model` |
| Compare to OmniRoute | Use `omniroute-concierge` / dual inventory; 9r is SSOT for this operator's strategies |

## Combo taxonomy (canonical)

| Family | Examples | Meaning |
|---|---|---|
| Leaf | `claude-opus`, `gpt-sol`, `kimi` | model family name |
| Eco mode | `eco-fallback`, **`eco-rotate`**, `eco-council` | cheap pool + strategy |
| Mega ladder | `mega-mid/high/xhigh/swift/review` | cognition ordinal |
| Council/fusion | `*-council`, `mega-brain` | fusion panel; judge = non-fusion combo |

**Anima naming rules:** mode combos must encode strategy (`fallback` / `rotate`); never opaque metaphors (`hold` rejected).

### Strategy enum (UI)

| value | Label | Persistence |
|---|---|---|
| `fallback` | Fallback — try in order | **default** — entry deleted from `comboStrategies` when set |
| `round-robin` | Round Robin — rotate | explicit entry |
| `fusion` | Fusion — panel + judge | explicit + `judgeModel` |

## Modes

- `--mode=explain` (default) — teach architecture + paths + taxonomy  
- `--mode=health` — Phase 0 only, compact status  
- `--mode=inventory` — full combo×strategy×judge table  
- `--mode=guide` — intent → exact curl/SQL  
- `--mode=audit` — gaps vs OmniRoute, orphan strategies, dead leaves  
- `--mode=dashboard` — point to `~/Projects/9router-megacontext/*.html` + inventory md  

## Anti-patterns

1. ❌ Reading `~/.omniroute/services/9router/data/db/data.sqlite` as live SSOT (often empty)  
2. ❌ Assuming empty log dirs ⇒ no traffic (use SQLite)  
3. ❌ **Printing / selecting API keys** (`SELECT key`, `echo $NINEROUTER_KEY`, paste into chat/PR)  
4. ❌ Renaming combo without updating `judgeModel` / `comboStrategies` keys  
5. ❌ Treating `/v1/models` alone as full config (strategies live in settings)  
6. ❌ Using Bash for anything beyond Phase-0 probes / read-only inventory (no destructive `rm`/`pkill` without operator)

## Refs

- Skill entry: `9router` (thin OpenAI client index)  
- Sibling: `omniroute-concierge`  
- Docs: `~/Projects/9router-megacontext/`  
- Cross-link: `[[9router-concierge]]`
