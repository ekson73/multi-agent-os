---
name: omniroute-concierge
version: "1.0.0"
description: |
  Concierge / health-check / inventory / router for the operator's **OmniRoute** gateway
  (v3.8+ local AI proxy). Knows real port, storage.sqlite schema, strategy enum (19 values),
  fusion/judgeModel, provider_connections, and parity with 9Router SSOT. Use to ASK anything
  about OmniRoute, run health/inventory, audit combo/strategy gaps, heal strategy drift from
  9Router, or route ops. Never invents routes; capability-detects first (Mente Tomé).
  Modes: explain · health · inventory · guide · audit · heal-parity · dashboard.
allowed-tools: Read, Glob, Grep, Bash
---

# Skill: omniroute-concierge — Concierge over the OmniRoute gateway

> **Domain**: OmniRoute gateway · **Lens**: Tomé · Systemic · Critical  
> **Named by**: Anima (`[C-naming]`) · family `*-concierge`  
> **Companion**: `9router-concierge` (strategy SSOT for this operator) · `~/Projects/9router-megacontext/INVENTORY-*.md`

## Identity

I orient over the live OmniRoute instance: health, combos (`storage.sqlite`), strategies, providers, logs. I never print tokens/secrets. For this operator, **9Router is the strategy SSOT** when healing parity.

## Phase 0 — Capability detection

| Probe | How | If absent |
|---|---|---|
| Process/port | `lsof -nP -iTCP:20128 -sTCP:LISTEN` | report down |
| Auth | API key from `api_keys` table (never print); `Authorization: Bearer …` | 401 |
| Health | `/api/health` may be **unknown_route** or 401 — prefer `/v1/models` reachability | don't declare dead on health path alone |
| DB | `~/.omniroute/storage.sqlite` table `combos` (`data` JSON) | — |
| Restart | `omniroute stop && omniroute serve --daemon` (operator-known) | don't `pkill` casually |
| Logs | `~/.omniroute/logs/application/app.log`, `server_out.log` | provider 402/429 dominate |

**Default env (this machine):**
```bash
# OmniRoute :20128  ·  9Router :20130
# Key: sqlite3 ~/.omniroute/storage.sqlite "SELECT key FROM api_keys WHERE revoked_at IS NULL LIMIT 1;"
```

## Combo `data` JSON (canonical shape)

```json
{
  "name": "eco-rotate",
  "strategy": "round-robin",
  "models": [{"id":"…","kind":"model","model":"kimi/k3","providerId":"kimi","weight":1}],
  "config": {"maxRetries":2, "judgeModel":"…", "fusionTuning":{}},
  "context_length": 1000000,
  "version": 2
}
```

## Strategy enum (product)

`priority · weighted · round-robin · context-relay · fill-first · p2c · random · least-used · cost-optimized · reset-aware · reset-window · headroom · strict-random · auto · lkgp · context-optimized · cache-optimized · fusion · pipeline` (+ internal `quota-share`)

### Mapping from 9Router → OmniRoute (operator SSOT)

| 9r `fallbackStrategy` | Omni `strategy` |
|---|---|
| `fallback` (default / absent entry) | **`priority`** |
| `round-robin` | **`round-robin`** |
| `fusion` | **`fusion`** (+ copy `judgeModel` / `fusionTuning`) |

## Landscape Decision Matrix

| Intent | Do |
|---|---|
| Health | Phase 0 + `/v1/models` count |
| Inventory combos | `SELECT name, json_extract(data,'$.strategy')… FROM combos` |
| Parity vs 9Router | Diff strategies; heal with mapping table above |
| Fusion council | Ensure `config.judgeModel` points to non-fusion combo |
| Provider errors | Read `provider_connections` (`is_active`, `test_status`) + app.log — never print tokens |
| Rename combo | Update `combos.name` + JSON `data.name` + any judge refs |

## Modes

- `--mode=explain` — architecture + paths + strategy map  
- `--mode=health` — compact liveness  
- `--mode=inventory` — full combo table  
- `--mode=guide` — curl/SQL recipes  
- `--mode=audit` — gaps vs 9r, orphan models, provider errors  
- `--mode=heal-parity` — apply 9r→omni strategy mapping (confirm if destructive/large)  
- `--mode=dashboard` — point to megacontext HTML + inventory  

## Anti-patterns

1. ❌ `pkill omniroute` without known restart command  
2. ❌ Declaring gateway dead because `/api/health` is 401/unknown_route  
3. ❌ Printing API keys from `api_keys`  
4. ❌ Healing strategies without 9r SSOT when operator policy is 9r-first  
5. ❌ Leaving fusion councils without `judgeModel`

## Canonical eco family (post-Anima)

```
eco-fallback  → priority (try in order)
eco-rotate    → round-robin
eco-council   → fusion · judgeModel=eco-rotate
```

## Refs

- Sibling: `9router-concierge`  
- OmniRoute skills under package `dist/skills/omni-*`  
- Docs: `~/Projects/9router-megacontext/`  
- Cross-link: `[[omniroute-concierge]]`
