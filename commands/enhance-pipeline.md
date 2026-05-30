---
name: enhance-pipeline
description: Drive ONE feature through the full divergent→convergent→deliver lifecycle — EXPAND (analyze + internal/external research + find gaps/fails + ideate) → FILTER (select + debate + correct) → HARMONIZE (converge 5-act) → DELIVER (plan + execute + test + validate + deploy). Composes in-repo primitives; reimplements nothing. Override-friendly.
---

# /enhance-pipeline Command

Thin wrapper that invokes `skills/enhance-pipeline/SKILL.md`. The skill holds all logic
(four-stage pipeline, per-stage primitive composition, STOP-marker grammar, auto-merge
gates, bounds). This file is the command surface only.

## Usage

```text
/enhance-pipeline "<feature>" [--blocks=…] [--driver=…] [--dry-run] [--output=…] \
                  [--auto-merge=…] [--auto-merge-reason="…"] \
                  [--autonomy-threshold=…] [--max-pdca=…]
```

The positional `"<feature>"` is required; all flags are optional (defaults below).

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `"<feature>"` (positional) | *required* | the feature/enhancement to drive |
| `--blocks` | `1,2,3,deliver` | comma subset of `1`,`2`,`3`,`deliver` |
| `--driver` | `auto-pilot` | `auto-pilot`, `auto-orchestrator`, `quiesce`, `<custom>` |
| `--dry-run` | `false` | plan-only: run stages 1-3 + emit plan, STOP before execute |
| `--output` | `table` | `table`, `list`, `json` |
| `--auto-merge` | `hold` | `authorized`, `hold`, `off` |
| `--auto-merge-reason` | *(none)* | required-non-empty when `--auto-merge=authorized` |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` |
| `--max-pdca` | `6` | int — per-PR PDCA cap in DELIVER |

## Examples

```text
/enhance-pipeline "decision-audit report for ASH/walkthrough"
/enhance-pipeline "rate-limit middleware" --dry-run
/enhance-pipeline "dark-mode toggle" --blocks=1,2 --output=json
/enhance-pipeline "search index" --auto-merge=authorized --auto-merge-reason="nightly feature run"
```

## Related

- `skills/enhance-pipeline/SKILL.md` — full logic + composition table
- `skills/auto-pilot/SKILL.md`, `skills/quiesce/SKILL.md`, `skills/converge/SKILL.md` — siblings
