---
name: instrument-self-heal-relay
description: Instrument, port or audit a script so an UNEXPECTED fault is relayed to an AI-harness pool (redacted log + UNTRUSTED prompt; agent proposes, human reviews). bash/python/node templates + a port contract for other languages; intentional exits never relay.
---

# /instrument-self-heal-relay Command

Invokes the `instrument-self-heal-relay` skill (soul-name *Iatros*) — turns a script into a
**try-catch-to-AI-harness** program: the script escalates only what it did not expect, an
agent proposes the repair, a human reviews the diff.

## Usage

```text
/instrument-self-heal-relay <path-or-language> [--lang bash|python|node|other] [--mode relay|seed]
                                               [--tier-lock propose] [--contract-codes 2,3] [--dry-run]
```

## What it does

1. Classifies the target (language, who runs it, secrets, stdout contract).
2. Enumerates the **intentional** non-zero exits — these are never relayed.
3. Stamps the canonical block with `skills/instrument-self-heal-relay/bin/self-heal-relay-render` (single-source harness table)
   or ports the ten-invariant contract to a language without a template.
4. Verifies: bash/python/node → `skills/instrument-self-heal-relay/bin/self-heal-relay-render --verify <file>` (+ `bash tests/test-self-heal-relay.sh` when inside a checkout of this repo; a portable install relies on `--verify` plus its own fixture); other-language port → its own fixture (invariants 1-4 and 6) instead of `--verify`.

Use `--mode seed` for hooks, cron and CI (non-blocking `NEEDS-AGENT` hand-off).

## Spec

`skills/instrument-self-heal-relay/SKILL.md` (procedure + invariants) ·
`docs/self-heal-relay.md` (pattern spec) · agent `self-heal-relay-engineer`.
