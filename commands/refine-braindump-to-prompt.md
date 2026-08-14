---
name: refine-braindump-to-prompt
description: Lapidate ONE raw operator braindump into ONE polished, ready-to-execute PROMPT — RECOVER (DoR · motivation · goal · DoD-as-measurable) → DRAFT (in an architecture profile) → REFINE (N rounds × N distinct lenses; stops only on min-revisions AND consecutive-clean-rounds) → RED-TEAM (independent refutation) → RENDER. Parameterized by profiles (`--architecture`, incl. `gauntlet-loop`). Composes in-repo primitives; reimplements nothing.
---

# /refine-braindump-to-prompt Command

Thin wrapper that invokes `skills/refine-braindump-to-prompt/SKILL.md` (soul-name *Lapidary*).
The skill holds all logic — five phases, per-phase primitive composition, the Verifiability Gate
stopping doctrine, architecture profiles, STOP-marker grammar, bounds. This file is the command
surface only.

## Usage

```text
/refine-braindump-to-prompt "<braindump>" [--architecture=…] [--dor=…] [--motivation=…] \
                            [--goal=…] [--condition=…] [--principles=…] \
                            [--min-revisions=N] [--clean-rounds=N] [--lenses=N] [--max-rounds=N] \
                            [--dry-run] [--output=…] [--persist=PATH] \
                            [--user-lang=…] [--agentic-lang=…]
```

The positional `"<braindump>"` (a file path or inline text) is required; all flags are optional.

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `"<braindump>"` (positional) | *required* | path to a braindump file, or inline text |
| `--architecture` | `default` | `default`, `gauntlet-loop`, or any file in `skills/refine-braindump-to-prompt/profiles/` |
| `--dor` / `--motivation` / `--goal` | `auto` | override what RECOVER inferred |
| `--condition` | `auto` | override the DoD / stop-condition (measurable spec) |
| `--principles` | `auto` | comma list, or `auto` = inherit the host's governance corpus by reference |
| `--min-revisions` | `3` | REFINE floor — minimum revisions regardless of apparent cleanliness |
| `--clean-rounds` | `3` | consecutive gap-free rounds required to exit REFINE |
| `--lenses` | `3` | distinct perspectives per round (a repeated lens does not count) |
| `--max-rounds` | `12` | hard cap; exceeded → `STOP-HITL` |
| `--dry-run` | `false` | run RECOVER→REFINE, emit the plan, STOP before RENDER writes |
| `--output` | `table` | `table`, `list`, `json` (json = machine contract; skill §Output contract, exit 0/1/2) |
| `--persist` | *(none)* | path to write the rendered prompt; omitted → return inline only |
| `--user-lang` | `auto` | operator-facing prose language |
| `--agentic-lang` | `en-us` | language of the RENDERED prompt (agent register) |

## Examples

```text
/refine-braindump-to-prompt "~/dumps/2026-08-14-gauntlet.braindump.md"
/refine-braindump-to-prompt "<dump>" --architecture=gauntlet-loop
/refine-braindump-to-prompt "<dump>" --dry-run --output=json
/refine-braindump-to-prompt "<dump>" --min-revisions=5 --clean-rounds=2 --lenses=4
/refine-braindump-to-prompt "<dump>" --persist=./prompts/migration.prompt.md
```

## Not this command

- "What in this dump is already done?" → `directive-braindump-triage` (user-scope).
- "Make this dump into a reusable tool" → `/agentic-tool-forge`.
- "Ship this feature end-to-end" → `/enhance-pipeline`.
- "Execute a prompt I already have" → `/auto-pilot`.

See `skills/refine-braindump-to-prompt/SKILL.md` for the full contract.
