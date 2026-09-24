---
name: instrument-self-heal-relay
version: 1.0.0
description: |
  Instrument, port, scaffold or recast ANY script or program — bash, python, node, and
  other languages (go, ruby, perl, PowerShell, …) — into the `self-heal-relay` model
  (soul-name Iatros): on an UNEXPECTED fault the program captures a redacted run log and an
  UNTRUSTED-labelled prompt, relays it to an AI-harness pool (most-qualified-first fallback),
  and an agent PROPOSES a repair that a human reviews as a diff. Intentional non-zero exits
  (gate verdicts, usage errors) never relay. Ships a single-source harness table, a
  stamp/verify renderer (bin/self-heal-relay-render), per-language templates (bash · python ·
  node), and a hermetic conformance suite. Use when a script should "throw to an AI agent on
  error" (try/catch-to-AI-harness), when auditing an existing self-heal block for drift, or
  when porting the pattern to a language without a template. Cross-vendor AAIF.
triggers:
  - self-heal
  - self heal relay
  - throw to ai agent on error
  - try-catch to ai harness
  - relay error to ai harness
  - instrument script with self-heal
  - port self-heal to another language
---

# instrument-self-heal-relay (soul-name *Iatros* — the physician)

> Anima decision (2026-09-23): system-name `self-heal-relay` · **type** = *supervised
> self-healing / out-of-process exception-escalation handler* (MAPE-K: the script is the
> Monitor, the harness pool the Analyze+Plan, the human the Execute gate). Not a retry loop,
> not autonomous repair. Spec: [`docs/self-heal-relay.md`](../../docs/self-heal-relay.md).

## §0 — BEING > Rules (with non-skippable safety gates)
Serve the operator's intent; skip ceremony (registry lines, README rows) if it obstructs
delivery — log `Skipped <step> — BEING > Rules`. **The safety gates are NOT skippable**:
contract-code enumeration (step 2), redaction, the UNTRUSTED fence, the propose tier / tier
lock for gates, and the re-entrancy guard. If a safe relay cannot be produced, **stop and
escalate — never ship a weaker one**. HUMAN_DOMAIN (secrets, production, irreversible) is never
relayed or auto-applied.

## When to use / not use
- **Use**: a script/hook/cron/CI job should escalate unexpected crashes to an AI harness;
  port the pattern to a new language; audit or refresh an adopter's stamped block.
- **Not use**: a *retry* on a flaky command (that is `retry`, not repair); autonomous
  production remediation (→ `system-health-responder`, a different autonomy tier); a script
  that handles secrets and cannot default the relay OFF (the redaction is best-effort).

## Parameters
| Param | Default | Meaning |
|---|---|---|
| `<target>` (positional) | — (required) | Script/program to instrument (path) or a language to port to. |
| `--lang` | auto | `bash` · `python` · `node` (template exists) · `other` (port from the contract, §Port). |
| `--mode` | `relay` | `relay` (synchronous dispatch) · `seed` (async `NEEDS-AGENT` hand-off — REQUIRED for hooks, cron, CI). |
| `--tier-lock` | off | `propose` for gate/governance scripts: the `apply` tier becomes unreachable. |
| `--contract-codes` | — | Exit codes that are intentional VERDICTS (never relayed), e.g. `2` for a BLOCK. |
| `--dry-run` | off | Show the diff that would be applied; write nothing. |

## Procedure

1. **Classify the target** — language; who runs it (interactive / hook / cron / CI → `seed`
   mode); does it handle secrets (→ default `MAOS_SELFHEAL=0`, relay opt-in); does it emit
   machine output on stdout (→ keep stdout pristine: capture stderr only).
2. **Enumerate the contract** — list every intentional non-zero exit (gate BLOCK, usage,
   `exit 1` verdict). These go in `SHR_CONTRACT_CODES` (bash) or are `SystemExit` /
   `process.exit` paths (python / node) that the block never intercepts. **If you cannot
   list them, stop and read the script — relaying a verdict is the one unforgivable bug.**
3. **Render the block** — `bin/self-heal-relay-render --lang <bash|python|node>`; insert it
   immediately after the script's own `set -e…` line (bash) or imports (python/node). Set
   the adopter knobs above the block. **Never hand-edit the stamped block**: fix
   `harnesses.json` or a template and re-render.
4. **Other languages (`--lang other`)** — no template? Port the *contract*, not the code: a
   conformant port satisfies all ten invariants below. Write the block, then add a fixture to
   `tests/test-self-heal-relay.sh` proving invariants 1-4 and 6 before shipping.
5. **Verify** — `bin/self-heal-relay-render --verify <file>` (rc 0 current · 1 drift · 2 no
   block) and `bash tests/test-self-heal-relay.sh` (runs the bash block on macOS `/bin/bash`
   3.2 *and* a modern bash: ERR-trap semantics differ between them).
6. **Record** — one line in the adopters table of `docs/self-heal-relay.md`; if a NEW artifact
   was created, `artifact-registry record --kind create …` (dedup memory).

## The ten invariants (the model — every port must hold all of them)

| # | Invariant | Why (the defect it closes) |
|---|---|---|
| 1 | Fire ONLY on an unexpected fault; intentional exits never relay | a relay on a verdict is theater |
| 2 | Original exit code preserved, always | the caller's contract is not the relay's to change |
| 3 | Re-entrancy guard (`MAOS_SELFHEAL_ACTIVE=1` exported to the harness) | a harness re-running the failing script must not relay again |
| 4 | Exactly ONE dispatch per harness; a failure moves to the NEXT harness | no unscoped double-dispatch fallback that swallows stderr |
| 5 | Error trap inherited into functions/subshells (`set -E` in bash) | without it a failure inside a function is silent |
| 6 | Log redacted BEFORE it leaves the process; prompt delivered by stdin (or file *path*), never log-in-argv | secrets to a third-party model / visible in `ps` |
| 7 | Log embedded inside a nonce-delimited UNTRUSTED fence + the contract to preserve | prompt-injection hygiene; repair must not weaken a guard |
| 8 | Bounded wait (watchdog) and non-blocking option (`seed` mode) | a hung harness must not hang a hook |
| 9 | Default tier is `propose` (read-only tools); `apply` is opt-in; tier-lock for gates | a gate must never self-edit |
| 10 | Unverified harnesses excluded from the default chain (explicit `MAOS_AI_HARNESS` opt-in) | never trust-all; verify flags against the CLI's own `--help` + a live round-trip |

## Known limits (state them, don't hide them)
- `set -u` unbound-variable aborts and a plain `exit N` never trip ERR → opt in with
  `SHR_TRAP_EXIT=1` (relays on any non-contract non-zero EXIT). Measured on bash 3.2 and 5.3.
- Redaction is pattern-based and **cannot** be exhaustive.
- A proposal is text: a human applies it. `apply` tier edits only what the harness's scoped
  tools allow; review the diff before merging.

## Definition of Done
Block stamped (or port conformant) · `--verify` rc 0 · conformance suite green on both bash
versions · contract codes enumerated and tested · adopters table updated · no secret in the diff.

## Anti-patterns
- ❌ Relaying a gate verdict / usage error. ❌ Retry-loop dressed as self-heal.
- ❌ Hand-editing a stamped block. ❌ Adding a harness to the default chain without a live
  verification. ❌ Log content in argv. ❌ `apply` tier on a governance script.

## Sunset (DUED, qualitative)
Deprecate when a host provides a native supervised-repair hook, when the harness table can no
longer be verified headlessly, or on operator retraction.

## Refs
`docs/self-heal-relay.md` (spec) · `harnesses.json` (single-source table) ·
`bin/self-heal-relay-render` · `tests/test-self-heal-relay.sh` · agent `self-heal-relay-engineer`
· Healer "LLM as Runtime Error Handler" (arXiv 2408.01055) · MAPE-K human-machine teaming
(arXiv 2203.13036).
