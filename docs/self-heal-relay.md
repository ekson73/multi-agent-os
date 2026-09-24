# self-heal-relay (v2)

> **Anima decision** — system-name `self-heal-relay` · soul-name **Iatros** (ἰατρός, "the
> physician"; prose only, never in a slug/trigger) · **type: supervised self-healing /
> out-of-process exception-escalation handler** — in MAPE-K terms the program is the
> *Monitor*, the harness pool the *Analyze + Plan*, the human the *Execute* gate. It is not a
> retry loop and not autonomous repair: an agent **proposes**, a human **reviews**.
> Executable form: skill [`instrument-self-heal-relay`](../skills/instrument-self-heal-relay/SKILL.md),
> agent [`self-heal-relay-engineer`](../agents/self-heal-relay-engineer.md).
> Prior art: Healer, "LLM as a Runtime Error Handler" (arXiv 2408.01055); MAPE-K human-machine
> teaming (arXiv 2203.13036). The soul-name in v1 was *Phoenix*; three adopters still carry that
> word in comments (see [Adopters](#adopting-scripts)).

## Intent

When an executable hits an **unexpected** fault it captures a run log and an UNTRUSTED-labelled
prompt, then **relays** the error to an AI harness through a harness-agnostic fallback chain so
the failure can be diagnosed and a repair *proposed* — while a human reviews the diff. The
script does the minimum itself (log → redact → prompt → dispatch); the repair is the harness's.

## The rule that is the whole point — fire ONLY on an UNEXPECTED failure

Every adopter has **intentional non-zero exits that are not errors**: a gate that denies a
command, a provenance gate that fails a build, a usage error. A relay that fired on those would
be theater — it would "repair" a verdict working exactly as designed. So it fires only on an
unexpected fault (an uncaught crash, a failed `source`, an IO/environment fault) and never on a
verdict. Each language enforces this structurally:

| Language | Intentional exit that must NOT relay | Mechanism |
|---|---|---|
| **bash** | `exit N` for verdict codes | `SHR_CONTRACT_CODES=" 2 "` — the ERR handler re-exits a contract code verbatim; a plain `exit N` never trips ERR |
| **python** | `sys.exit(n)` / `SystemExit` | relay lives in `sys.excepthook`; `SystemExit` never reaches it |
| **node** | `process.exit(n)` | relay lives in `uncaughtException` / `unhandledRejection`; `process.exit` bypasses both |

## v2 — what changed and why (defects found in v1, measured)

v1 was reviewed by running its real prelude against a stub harness. Six defects, each with the
v2 fix and a test in [`tests/test-self-heal-relay.sh`](../tests/test-self-heal-relay.sh):

| # | v1 defect (evidence) | v2 fix |
|---|---|---|
| D1 | **No `set -E`** — the ERR trap does not fire for a failure *inside a function* (reproduced) | `set -E` (errtrace) is part of the block |
| D2 | **No re-entrancy guard** — a harness that re-runs the failing script re-triggers the relay (unbounded) | `MAOS_SELFHEAL_ACTIVE=1` exported to the harness; the block is inert when it is set |
| D3 | **Double dispatch** — the "fallback" re-ran the whole repair with different flags, unscoped, swallowing stderr | exactly one invocation per harness; a failure moves to the *next* harness |
| D4 | **Unredacted log** sent to a third-party model, and passed through argv (visible in `ps`) | best-effort redaction before the prompt exists; prompt via **stdin** (or a file *path* for argv-only CLIs) |
| D5 | **Synchronous dispatch blocks** hooks and cron | `seed` mode: write a `NEEDS-AGENT-*.md` and return; plus a watchdog timeout in `relay` mode |
| D6 | **`set -u` aborts never trip ERR** — v1's claim that an unbound variable relays was false (measured on bash 3.2 and 5.3) | opt-in `SHR_TRAP_EXIT=1` relays on any non-contract non-zero EXIT; documented as a limit otherwise |

Refuted while reviewing: a suspected race between the log `tee` and reading the log (0/40 lost).

## The two modes and the two tiers

| | `relay` (default) | `seed` |
|---|---|---|
| What happens | dispatch synchronously, write `proposal.md` | write `NEEDS-AGENT-<utc>-<script>.md`, dispatch nothing |
| Use for | interactive CLI tools | hooks, cron, CI (must not block) |
| Env | `MAOS_SELFHEAL_MODE=relay` | `MAOS_SELFHEAL_MODE=seed`, `MAOS_SELFHEAL_SEED_DIR=<dir>` |

| Tier | Harness tools | Use for |
|---|---|---|
| `propose` (default) | read-only (`fs_read`, `Read,Grep,Glob`, `--sandbox read-only`) | everything |
| `apply` | scoped edit (`fs_write`, `Edit,Write`, `--sandbox workspace-write`) | opt-in only |

`SHR_TIER_LOCK=propose` makes `apply` unreachable — mandatory for gate/governance scripts (a gate
must never self-edit). Consume a seed by moving it to `consumed/`.

## Harness-agnostic chain — verified vs opt-in

The single source of truth is [`harnesses.json`](../skills/instrument-self-heal-relay/harnesses.json);
`skills/instrument-self-heal-relay/bin/self-heal-relay-render` stamps it into every language block (`--list` prints it,
`--verify <file>` detects drift). A harness is `verified` only if its flags exist in the CLI's own
`--help` **and** a live headless round-trip through that exact argv + prompt delivery was
observed. **Only verified harnesses are in the default chain**; the rest run only when named in
`MAOS_AI_HARNESS`.

| Harness | Verified | Prompt via | Notes |
|---|---|---|---|
| `kiro-cli` | ✅ default #1 | stdin | `chat --no-interactive --trust-tools=fs_read` |
| `claude` | ✅ default #2 | stdin | `-p --allowedTools=Read,Grep,Glob` — use the `=` form: the flag is variadic and swallows a following positional |
| `codex` | ✅ default #3 | stdin | `exec --skip-git-repo-check --sandbox read-only -` |
| `gemini` | opt-in | stdin | in an untrusted folder it overrides `--approval-mode`, so read-only is not guaranteed |
| `opencode` · `amp` | opt-in | file **path** in argv | no scoped-tool flag verified |
| `crush` | opt-in | stdin | no scoped-tool flag verified |

## Safety boundary

- **Redaction (best-effort).** Private-key blocks, cloud/API/GitHub/Slack tokens, JWTs,
  `user:pass@` URLs, `Bearer`/`Basic` credentials and `key=value` pairs whose key names a
  secret are scrubbed before the prompt exists. It **cannot** be exhaustive — a script that
  handles secrets should default `MAOS_SELFHEAL=0` and treat the relay as opt-in.
- **UNTRUSTED fence with a nonce.** The log sits between `<<<UNTRUSTED-LOG-{nonce}` and
  `UNTRUSTED-LOG-{nonce}>>>` (exactly three `>`); the nonce is generated at fault time, so a log line cannot forge
  the closing delimiter. The harness is told the block is data, not instructions.
- **Contract to preserve.** The prompt states the invariant the repair must keep (e.g. "do not
  weaken the gate's block semantics") via `SHR_CONTRACT_NOTE`.
- **Private temp.** The run directory is `mktemp -d` (mode 0700), prompts and seeds are written mode 0600,
  and it is removed on a clean or intentional exit (bash, python and node alike); it is kept only
  when a relay happened, so a human can read the prompt and proposal.

## Env reference

| Variable | Effect |
|---|---|
| `MAOS_SELFHEAL=0` | disable entirely (default `1`) |
| `MAOS_SELFHEAL_MODE` | `relay` (default) · `seed` |
| `MAOS_SELFHEAL_TIER` | `propose` (default) · `apply` (ignored under `SHR_TIER_LOCK`) |
| `MAOS_AI_HARNESS="claude codex"` | explicit chain — the only way to use an unverified harness |
| `MAOS_SELFHEAL_TIMEOUT` | per-harness wall-clock cap in seconds (default 300) |
| `MAOS_SELFHEAL_SEED_DIR` | seed directory (default `$XDG_STATE_HOME/maos/self-heal-seeds`) |
| `MAOS_SELFHEAL_ACTIVE=1` | set by the relay itself; inert-guard for re-entrancy |
| `SHR_CONTRACT_CODES` · `SHR_TIER_LOCK` · `SHR_TRAP_EXIT` · `SHR_CAPTURE_STDOUT` · `SHR_CONTRACT_NOTE` | adopter knobs, set *before* the block |

## Honest limitations

- `set -u` aborts and a bare `exit N` do not trip ERR; use `SHR_TRAP_EXIT=1` to relay on EXIT.
- On macOS `/bin/bash` 3.2 a `set -u` abort reports status **0** to the EXIT trap, so it is undetectable there even with
  `SHR_TRAP_EXIT=1` (bash >= 4 reports the real status). A bare `exit N` is detected on both.
- On timeout the harness' whole process tree is killed (POSIX: process group / depth-first tree; Windows: `taskkill /T` —
  best-effort, not covered by the suite).
- ERR-trap behaviour differs between bash 3.2 (macOS `/bin/bash`) and 5.x — the conformance
  suite runs the block under both; e.g. `( exit 2 )` trips ERR only on 5.x, so tests use
  `sh -c 'exit 2'`.
- Redaction is pattern-based. A novel secret shape passes through.
- The captured run log (`run.log`) grows for as long as the instrumented program runs and writes to stderr; only the *read-back* is capped
  (256 KiB). For a long-lived or very noisy process, rotate its output externally or set `MAOS_SELFHEAL=0`; the relay is meant for
  short-lived scripts and jobs.
- Node: `spawnSync` blocks the event loop, so a `SIGTERM`/`SIGINT` delivered to the script *while* it waits on the harness is only
  handled after the call returns (bounded by `MAOS_SELFHEAL_TIMEOUT`); the harness is already in the watchdog's process tree.
  A hard `SIGKILL` of the script cannot be trapped in any language and can leave the harness running until its timeout.
- The Bash block tees stderr through a process substitution. Bash does not `wait` for it, so under a container PID 1 that never
  reaps orphans (no `--init`/`tini`), a very frequently invoked script leaves one defunct `tee` per run. That is an environment
  fault, not a script one: run such containers with an init. The Windows `.cmd`/`.bat` harness launcher (node) is untested.
- A proposal is text; nothing is applied without a human (or an explicit `apply` opt-in).

## Adopting scripts

| Script | Language | Block | Never relays |
|---|---|---|---|
| [`bin/kirocrew-extras`](../bin/kirocrew-extras) | bash | v1 (reference impl) | — |
| [`plugin-scripts/governance/worktree-gate.sh`](../plugin-scripts/governance/worktree-gate.sh) | bash | v1 | `exit 2` (BLOCK), `exit 0` |
| [`bin/work-compass-aggregate.py`](../bin/work-compass-aggregate.py) | python | v1 | any `SystemExit` |
| [`bin/research-dossier-render.mjs`](../bin/research-dossier-render.mjs) | node | v1 | `exit 1` (GATE FAILURE) |

The four adopters above still run the **v1** block (and the word "Phoenix"). Migrating each to
the stamped v2 block is a **gated follow-up**: `worktree-gate.sh` is a guardrail hook (mandatory
independent red-team, `SHR_TIER_LOCK=propose`), so it is not batch-edited here.

## Instrumenting a new script

Run `/instrument-self-heal-relay <path>` (or `skills/instrument-self-heal-relay/bin/self-heal-relay-render --lang <bash|python|node>`
and insert the block). For a language with no template, port the ten invariants listed in the
skill and add a fixture to `tests/test-self-heal-relay.sh` before shipping.
