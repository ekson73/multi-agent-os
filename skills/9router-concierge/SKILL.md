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

## Identity

I am the **concierge of 9Router**. I orient over the live instance: health, combos, strategies, providers, logs. I never reimplement the gateway and never echo API keys/secrets.

## Phase 0 — Capability detection (always first)

| Probe | How | If absent |
|---|---|---|
| Process/port | `lsof -nP -iTCP:20130 -sTCP:LISTEN` | try other ports; report down |
| Health | `curl -s $NINEROUTER_URL/api/health` → `{"ok":true}` | gateway down |
| **Real DB** | `~/.9router/db/data.sqlite` (NOT `~/.omniroute/services/9router/...` which may be empty) | wrong path → false inventory |
| API key | `sqlite3 … "SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1"` (never print) | 401 on chat |
| Combos | `GET /v1/models` + `owned_by=="combo"` AND table `combos` | split-brain if diverge |
| Strategies SSOT | `settings.data.comboStrategies` (JSON in `settings` table) | absence of key = **fallback** default |
| Logs | file logs often **empty**; use `requestDetails` / `usageDaily` / `usageHistory` | don't claim "no errors" from empty dirs |

**Default env (this machine):**
```bash
export NINEROUTER_URL="http://localhost:20130"   # NOT 20128 (that's OmniRoute here)
# NINEROUTER_KEY from apiKeys table when requireApiKey=true
```

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
3. ❌ Printing API keys  
4. ❌ Renaming combo without updating `judgeModel` / `comboStrategies` keys  
5. ❌ Treating `/v1/models` alone as full config (strategies live in settings)

## Refs

- Skill entry: `9router` (thin OpenAI client index)  
- Sibling: `omniroute-concierge`  
- Docs: `~/Projects/9router-megacontext/`  
- Cross-link: `[[9router-concierge]]`
