---
name: refine-braindump-to-prompt
description: Lapidate ONE raw operator braindump into ONE polished, ready-to-execute PROMPT — RECOVER (DoR · motivation · goal · DoD-as-measurable) → DRAFT (in an architecture profile) → REFINE (N rounds × N distinct lenses; economic stop by default, floor only where the profile licenses the long loop) → RED-TEAM (independent refutation) → RENDER. Parameterized by profiles (`--architecture`, incl. `gauntlet-loop`). Composes in-repo primitives; reimplements nothing.
---

# /maos:refine-braindump-to-prompt Command

Thin wrapper that invokes `skills/refine-braindump-to-prompt/SKILL.md` (soul-name *Lapidary*).
The skill holds all logic — five phases, per-phase primitive composition, the Verifiability Gate
stopping doctrine, architecture profiles, STOP-marker grammar, bounds. This file is the command
surface only.

## Usage

```text
/maos:refine-braindump-to-prompt "<braindump>" [--architecture=…] [--dor=…] [--motivation=…] \
                            [--goal=…] [--condition=…] [--principles=…] \
                            [--min-revisions=N] [--clean-rounds=N] [--lenses=N] [--max-rounds=N] \
                            [--dry-run] [--output=…] [--output-target=…] \
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
| `--min-revisions` | `3` | REFINE floor — **licensed profiles only**; ignored (with a warning) when the Verifiability Gate is false |
| `--clean-rounds` | `3` | consecutive gap-free rounds — **licensed profiles only**; same gate as above |
| `--max-redteam-cycles` | `2` | cap on `RED-TEAM REFUTED → REFINE` returns; exhausted while still REFUTED → `STOP-HITL` |
| `--lenses` | `3` | distinct perspectives per round (a repeated lens does not count) |
| `--max-rounds` | `12` | hard cap; exceeded → `STOP-HITL` |
| `--dry-run` | `false` | run RECOVER→REFINE, emit the plan, STOP before RENDER writes |
| `--output` | `table` | `table`, `list`, `json` (json = machine contract; skill §Output contract, exit 0/1/2) |
| `--persist` | *(none)* | **DEPRECATED alias** — `--persist=P` ≡ `--output-target=git-repo:P` |
| `--output-target` | *(none)* | comma-separated sinks `<kind>[:<param>]`: `stdout` · `clipboard` · `vault:<path>` · `git-repo:<path>` · `agentic-tool:<sub-kind>:<path>`. A sink is valid iff **reachable** (probed) ∧ **render defined** ∧ **can refuse by name**. See skill §Output targets. |
| `--user-lang` | `auto` | operator-facing prose language |
| `--agentic-lang` | `en-us` | language of the RENDERED prompt (agent register) |

## Examples

```text
/maos:refine-braindump-to-prompt "~/dumps/2026-08-14-gauntlet.braindump.md"
/maos:refine-braindump-to-prompt "<dump>" --architecture=gauntlet-loop
/maos:refine-braindump-to-prompt "<dump>" --dry-run --output=json
/maos:refine-braindump-to-prompt "<dump>" --min-revisions=5 --clean-rounds=2 --lenses=4
/maos:refine-braindump-to-prompt "<dump>" --output-target=clipboard
/maos:refine-braindump-to-prompt "<dump>" --output-target=vault:~/eko-engram/pages/x.md,clipboard
/maos:refine-braindump-to-prompt "<dump>" --output-target=agentic-tool:skill:./skills/x/SKILL.md
```

## Not this command

- "What in this dump is already done?" → `directive-braindump-triage` (user-scope).
- "Make this dump into a reusable tool" → `/agentic-tool-forge`.
- "Ship this feature end-to-end" → `/enhance-pipeline`.
- "Execute a prompt I already have" → `/auto-pilot`.

See `skills/refine-braindump-to-prompt/SKILL.md` for the full contract.
