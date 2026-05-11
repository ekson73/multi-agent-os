# tests/converge — converge skill test rig

Closes the **tooling** portion of issue [#50](https://github.com/ekson73/multi-agent-os/issues/50) (follow-up to #45).

## What's here

| Path | Purpose |
|---|---|
| `case-01-balanced/output.md` | Well-formed converge output (§1-§9 present, Invariant 6 honored) — expected to PASS lint |
| `case-02-missing-sections/output.md` | Output missing §1 Steelman, §5 Reject log, §8 Open questions — expected to fail with CL001+CL005+CL006 |
| `case-03-leading-question/output.md` | Output with persuasive framing ("Você concorda em…", "Don't you think A would also work?") — expected to fail with CL002 |
| `case-NN/expected.txt` | `exit_code=<N>` + optional `expected_rules=<list>` declaring the assertion |
| `run.sh` | POSIX-sh test runner; invokes `../../scripts/converge-lint.sh` on each case + asserts |

## Usage

```bash
# Run the full rig locally
./tests/converge/run.sh

# Or run lint on a single output you produced
./scripts/converge-lint.sh /path/to/your-converge-output.md
```

## CI

`.github/workflows/converge-tests.yml` runs the rig on every PR touching `skills/converge/**`, `scripts/converge-*.sh`, `tests/converge/**`, or the workflow itself.

## Adding a new case

1. Create `tests/converge/case-NN-<name>/output.md` with the markdown content
2. Create `tests/converge/case-NN-<name>/expected.txt`:
   ```
   exit_code=0      # or 1
   expected_rules=CL00X CL00Y   # optional, space-separated
   ```
3. Re-run `./tests/converge/run.sh` to verify

## Format-only validation

The rig asserts **structure** (sections present, fields populated, framing-anti-bias guards). It does NOT score subjective content quality — that remains a human responsibility.

## Refs

- Skill spec: [`skills/converge/SKILL.md`](../../skills/converge/SKILL.md) v1.1.1+
- Issues: [#45](https://github.com/ekson73/multi-agent-os/issues/45) (original dogfooding) · [#50](https://github.com/ekson73/multi-agent-os/issues/50) (this tooling)
- Lint rules documented in `scripts/converge-lint.sh --help`
