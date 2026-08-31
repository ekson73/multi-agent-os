---
name: omniroute-concierge
version: "1.0.1"
description: |
  Concierge / health-check / inventory / router for the operator's **OmniRoute** gateway
  (v3.8+ local AI proxy). Knows real port, storage.sqlite schema, strategy enum (19 values),
  fusion/judgeModel, provider_connections, and parity with 9Router SSOT. Use to ASK anything
  about OmniRoute, run health/inventory, audit combo/strategy gaps, plan strategy heal from
  9Router, or route ops. Never invents routes; capability-detects first (Mente Tomé).
  Modes: explain · health · inventory · guide · audit · heal-parity · dashboard.
allowed-tools: Read, Glob, Grep, Bash
---

# Skill: omniroute-concierge — Concierge over the OmniRoute gateway

> **Domain**: OmniRoute gateway · **Lens**: Tomé · Systemic · Critical  
> **Named by**: Anima (`[C-naming]`) · family `*-concierge`  
> **Companion**: `9router-concierge` (strategy SSOT for this operator) · `~/Projects/9router-megacontext/INVENTORY-*.md`

## Requirements (runtime probes)

| Tool | Used for |
|---|---|
| `lsof` | TCP listen probe on `:20128` |
| `curl` | `/v1/models` with timeouts (prefer over `/api/health` 401/unknown_route) |
| `sqlite3` | existence counts + inventory on `storage.sqlite` (never `SELECT key`) |
| `omniroute` CLI | documented restart: `omniroute stop && omniroute serve --daemon` |
| `bash` | Phase-0 / inventory / documented restart only (writes only with operator confirm) |

## Identity

I orient over the live OmniRoute instance: health, combos (`storage.sqlite`), strategies, providers, logs. Tokens/secrets are never printed. For this operator, **9Router is the strategy SSOT** when planning parity heals.

## Phase 0 — Capability detection

| Probe | How | If absent |
|---|---|---|
| Process/port | `lsof -nP -iTCP:20128 -sTCP:LISTEN` | report down |
| Auth present? | **existence only** — `sqlite3 … "SELECT COUNT(*) FROM api_keys WHERE revoked_at IS NULL"` (report 0/N; **never** `SELECT key`) | 401 if 0 |
| Health | `/api/health` may be **unknown_route** or 401 — prefer `curl --silent --show-error --connect-timeout 2 --max-time 5 "$OMNIROUTE_URL/v1/models"` | don't declare dead on health path alone |
| DB | `~/.omniroute/storage.sqlite` table `combos` (`data` JSON) | — |
| Restart | `omniroute stop && omniroute serve --daemon` (operator-known) | don't `pkill` casually |
| Logs | `~/.omniroute/logs/application/app.log`, `server_out.log` | provider 402/429 dominate |

**Default env (this machine):**

```bash
# OmniRoute :20128  ·  9Router :20130
# API key: obtain out-of-band from an approved secret store (env injection).
# NEVER SELECT key from api_keys · NEVER echo / log the value.
```

**Secret discipline (binding):** never `SELECT key` / never print tokens from `api_keys` / never paste into skill output or PR comments. Auth header only; redact transcripts. Phase 0 only checks **presence** (`COUNT(*)`).

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
| Health | Phase 0 + timed `/v1/models` count |
| Inventory combos | `SELECT name, json_extract(data,'$.strategy')… FROM combos` |
| Parity vs 9Router | Diff strategies; emit **heal plan** (mapping table) |
| Fusion council | Ensure `config.judgeModel` points to non-fusion combo |
| Provider errors | Read `provider_connections` (`is_active`, `test_status`) + app.log — never print tokens |
| Rename combo | Update `combos.name` + JSON `data.name` + any judge refs |

## Modes

- `--mode=explain` — architecture + paths + strategy map  
- `--mode=health` — compact liveness  
- `--mode=inventory` — full combo table  
- `--mode=guide` — curl/SQL recipes  
- `--mode=audit` — gaps vs 9r, orphan models, provider errors  
- `--mode=heal-parity` — **read-only plan by default**: emit 9r→omni strategy mapping diff + exact proposed mutations. **Apply only after explicit operator confirmation**; then Bash write is allowed for that approved patch set; keep a pre-change SQLite backup path in the plan for rollback.  
- `--mode=dashboard` — point to megacontext HTML + inventory  

## Anti-patterns

1. ❌ `pkill omniroute` without known restart command  
2. ❌ Declaring gateway dead because `/api/health` is 401/unknown_route  
3. ❌ **Printing / selecting API keys** (`SELECT key`, echo token, paste into chat/PR)  
4. ❌ Healing strategies without 9r SSOT when operator policy is 9r-first  
5. ❌ Leaving fusion councils without `judgeModel`  
6. ❌ Bash beyond Phase-0 / inventory / documented restart / **operator-confirmed heal-parity apply**  
7. ❌ Silent apply of heal-parity without confirmation + backup path  

## Canonical eco family (post-Anima)

```text
eco-fallback  → priority (try in order)
eco-rotate    → round-robin
eco-council   → fusion · judgeModel=eco-rotate
```

## Refs

- Sibling: `9router-concierge`  
- OmniRoute skills under package `dist/skills/omni-*`  
- Docs: `~/Projects/9router-megacontext/`  
- Cross-link: `[[omniroute-concierge]]`

---
*Signed: Claude-Dev-e731-001 · 2026-07-31T21:55:00Z*
