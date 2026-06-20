---
name: status-map
description: Generate human-readable ASCII status visualizations for agent sessions
version: 1.0.0
---

# Status Map Skill

## Purpose

Generate ASCII-based visualizations for human observability of AI agent sessions. Complements Sentinel Protocol (JSON-based) by providing quick, scannable status information.

## When to Use

- Every response (PULSE template)
- Every 5 responses (COMPACT template)
- Session start/end
- Before/after delegations
- On errors
- Before commits

## Template Catalog

| Template | Purpose | Time |
|----------|---------|------|
| PULSE | 1-line minimal status | 1-2s |
| COMPACT | Quick 6-line check | 3-5s |
| SESSION_START | Initial state | 8-10s |
| SESSION_END | Handoff summary | 20-30s |
| DELEGATION_PRE | Pre-delegation context | 5-8s |
| DELEGATION_POST | Post-delegation result | 8-12s |
| ERROR_DEBUG | Error diagnosis | 15-20s |
| PRE_COMMIT | Commit validation | 8-10s |
| FULL_REPORT | Complete audit | 60-120s |

## Template Examples

### PULSE (1-line)
```
[PULSE] ████████░░ 80% | ✓3 ↻1 ⚠0 | 25m | → Continue editing
```

### COMPACT (6-line)
```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS MAP | 2026-01-06T12:30 | Session: c614                  │
├────────────┬────────────────────────────────────────────────────┤
│ 🟢 GIT     │ main | clean | last: a31b933                       │
│ 🟢 AGENTS  │ 23 completed | 0 active | 0 blocked                │
│ 🟢 SENTINEL│ v1.0 | 10 rules | health: 100                      │
│ 🟢 LOCKS   │ 0 active | 0 stale                                 │
├────────────┴────────────────────────────────────────────────────┤
│ NEXT: aguardando instrucao do humano                            │
└─────────────────────────────────────────────────────────────────┘
```

## Semaphore Indicators

| Indicator | Meaning | Fallback |
|-----------|---------|----------|
| 🟢 | OK / Healthy | [OK] |
| 🟡 | Warning | [WARN] |
| 🔴 | Error / Critical | [FAIL] |

## Override Commands

| Command | Template |
|---------|----------|
| `/agentic-status` | COMPACT |
| `/agentic-status full` | FULL_REPORT |
| `/agentic-status debug` | ERROR_DEBUG |
| `/agentic-status pre` | PRE_COMMIT |
| `/agentic-status end` | SESSION_END |
| `/agentic-status pulse` | PULSE |

## Template Inference

The AI automatically selects template based on context:
- Session start? → SESSION_START
- Error detected? → ERROR_DEBUG
- About to delegate? → DELEGATION_PRE
- Delegation returned? → DELEGATION_POST
- About to commit? → PRE_COMMIT
- Session ending? → SESSION_END
- Every 5th response? → COMPACT
- Default → PULSE

---

*Skill based on Status Map System v1.0 | multi-agent-os*
