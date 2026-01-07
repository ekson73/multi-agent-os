---
name: status
description: Display human-readable status of current session using Status Map templates
---

# /status Command

Displays human-readable ASCII status visualizations for the current session.

## Usage

```
/status [template]
```

## Templates

| Template | Description | Absorption Time |
|----------|-------------|-----------------|
| (default) | COMPACT - Quick 6-line check | 3-5s |
| `pulse` | 1-line minimal status | 1-2s |
| `full` | Complete audit report | 60-120s |
| `debug` | Error diagnosis view | 15-20s |
| `pre` | Pre-commit validation | 8-10s |
| `end` | Session handoff summary | 20-30s |

## Examples

```
/status              # COMPACT template (default)
/status pulse        # 1-line status
/status full         # Full report
/status debug        # Debug view for errors
```

## Output Examples

### PULSE
```
[PULSE] ████████░░ 80% | ✓3 ↻1 ⚠0 | 25m | → Continue editing
```

### COMPACT (default)
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

| Indicator | Meaning |
|-----------|---------|
| 🟢 | OK / Healthy |
| 🟡 | Warning / Attention |
| 🔴 | Error / Critical |
