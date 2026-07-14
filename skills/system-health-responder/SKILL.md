---
name: system-health-responder
description: End-of-action reflex that reads the system-health contract, engage-locks, Eisenhower-ranks the warnings, does MODERATE non-destructive auto-heal (autonomous reversible renice of a clear cpu runaway + `uv cache prune` producer-hygiene), responds to the new `agentic_tools` branch (`claude doctor` runtime health + cache-producer pressure), and escalate-seeds the HITL residue (security · malware · kill · disk→disk-guardian · no-source-fix offender containment). EKO-90 part-2 — the responder half of the health suite.
version: 1.4.0
allowed-tools: Read, Bash
---

# System-Health Responder

**EKO-90 part-2** — the *responder* half of the system-health suite. Part-1 (the machine-local
`system-health-guardian.sh` launchd collector) *measures* every 10 min and writes a secret-free,
jq/yq-searchable **health-contract** with root-fail drill-down. This skill is the *end-of-action
reflex* that **reads that contract and responds**: it heals what is safely autonomous (Moderate)
and escalate-seeds the rest to the operator — never destructively.

> Not to be confused with `agents/sentinel-monitor` — that watches **agent-orchestration**
> anomalies (loops, depth, token-bloat). This watches **system-resource** health (cpu·mem·security·
> malware·process·network). Orthogonal domains; this composes existing primitives, it does not extend Sentinel.

## Purpose

Close the *measure → respond* loop (Metron-style) for host health: convert the passive part-1
contract into bounded, reversible, auditable action + a durable HITL queue — so a runaway process
gets deprioritized on its own, while security/malware/kill decisions reach the operator as a
NEEDS-AGENT seed instead of rotting silently (Taxis / no-silent-drop).

## When to Use

Fire this reflex at an **end-of-action boundary** (reusing the existing `end-of-action-self-audit` /
`postflight` trigger — SELECTIVE, not every turn) when **all** hold:

1. The health-contract exists and `.system.status != ok` (there is a real warning to respond to).
2. No other responder is already engaged (the engage-lock is free).
3. (For the autonomous `--engage` path) the standing-autonomy predicate `READY = R1∧R2∧R3∧R4` holds
   and the action is within Moderate scope (see Guardrails).

Also usable on-demand: an active session (preflight / morning-briefing) that finds a
`NEEDS-AGENT-*.md` seed picks it up and delegates a specialist or surfaces to the operator.

## Trigger Phrases

`system health responder`, `respond to health contract`, `auto-heal system`, `health self-heal`,
`drain NEEDS-AGENT seed`, `renice runaway`.

## Protocol Rules

The deterministic engine is `bin/health-respond.sh` (see it for the exact logic). The reflex:

1. **Engage-lock** — atomic mkdir-mutex `responder.lock` (stale-steal > 30 min) so two concurrent
   end-of-action reflexes never double-act. Stand down (exit 1) if held.
2. **Read + Eisenhower-rank** — parse the contract's branch statuses; rank crit > warn, with the
   disposition fixed by `references/auto-heal-safety-matrix.md`.
3. **Moderate auto-heal** — the ONLY autonomous action is `renice`-ing a **clear cpu runaway**
   (`top_consumer.status != ok`, `comm ∉ PROC_DENYLIST`, `nice < RENICE_TO`). Every renice records the
   exact restore command + original nice to `reverts.log` (auditable reversibility).
4. **Delegate disk** — disk warnings go untouched: the `disk-health-guardian` owns disk (no duplication).
5. **Escalate-seed the HITL residue** — security · malware · memory · process · network · protected/
   maxed cpu → a `NEEDS-AGENT-<ts>.md` seed (`kind: system-health-agent-delegation-seed`) + macOS
   notification + 6 h throttle (the disk-guardian's escalate shape). **The seed IS the Taxis queue
   entry** an active session drains (no-silent-drop).
6. **Log** a heartbeat to `responder.log`.

### Invocation

```bash
BIN="$CLAUDE_PLUGIN_ROOT/skills/system-health-responder/bin/health-respond.sh"
"$BIN"                       # DEFAULT: dry-run — reads, ranks, PROPOSES, seeds HITL residue. Acts on NOTHING.
SHR_READY=1 "$BIN" --engage  # Moderate autonomous path: performs the renice. Requires SHR_READY=1 (see gate below).
"$BIN" --engage              # --engage WITHOUT SHR_READY → fail-safe DEGRADES to dry-run (never auto-acts).
"$BIN" --help
```

**The `--engage` gate (fail-safe DENY-until-proven).** `--engage` alone only *requests* the autonomous
path; the renice fires **only when `SHR_READY=1` is also set**. The calling agentic reflex sets `SHR_READY=1`
**after** it has proven the standing-autonomy `READY = R1∧R2∧R3∧R4` predicate + Moderate scope. A stray
`--engage` (launchd misconfig, a curious operator running the script by hand) therefore degrades to dry-run
and a stderr diagnostic instead of auto-acting — the script never trusts the flag alone. launchd must **never**
pass `SHR_READY=1`; only an active reflex under proven authorization does.

Env overrides: `SHR_CONTRACT`, `SHR_STATE_DIR`, `SHR_RENICE_TO`, `SHR_LOCK_STALE_SEC`,
`SHR_ESCALATE_THROTTLE_SEC`, `SHR_READY=1` (arm the autonomous `--engage` path — set only by an authorized
reflex), `SHR_NO_NOTIFY=1` (suppress the macOS notification, for tests/headless).

## Guardrails (⛔ non-negotiable)

- **Safe-by-default**: the bin is `--dry-run` unless `--engage` is passed. `--engage` is used only by an
  active agentic reflex under standing-autonomy `READY` + Moderate scope — never blindly by launchd.
- **Non-destructive only**: NEVER kill/quit a process, quarantine/delete/move a file, re-enable or disable
  a security control, update the OS, or touch disk. `renice` is the sole lever (reversible-by-record).
- **Secret-safe (absolute)**: reads `comm`/`pid`/`pct`/`nice` metadata only — never a process's argv/
  `command` (tokens live there). Writes no secret value; the contract + seeds are the operator's own state.
- **PROC_DENYLIST**: never `renice` a macOS-critical proc (WindowServer, kernel_task, launchd, …) nor a
  sensitive app (`1password`, `openclaw`, `omniroute`, `claude`). See the safety-matrix reference.
- **HITL residue** (security · malware · kill · quarantine · OS-update) is *always* the operator's
  decision — the responder only queues it (seed + notify), never acts.

## Agentic-tools response + offender-containment (EKO-90-ext v1.2.0)

The 2026-07-14 disk-drain exposed a gap: the disk-guardian cleaned caches but could not beat a **live
producer** — N Claude sessions re-spawning `uvx …@latest` MCP servers re-inflated `~/.cache/uv/archive-v0`
(`uv` has no auto-GC) faster than Tier-1 pruned the symptom. Two additions close it:

1. **Collector Phase-1** (`collectors/system-health-guardian.sh`, machine-local at `~/.local/bin/`) gains an
   `agentic_tools` branch: `claude_runtime` (a read-only `claude doctor` — the "unattended show-only" probe;
   the *fixing* `/doctor` stays in-session) + `cache_producer` (`uv_archive_objects` argv-free footprint +
   `uvx_latest_procs` producer signature). Secret-safe: counts/names/booleans only, never argv.

2. **Responder** consumes that branch: **Tier-A** autonomous `uv cache prune` (LOW · non-destructive · same
   `--engage`+`SHR_READY` Moderate gate as renice); **Tier-B** — **DISABLE tier ARMED 2026-07-14 (operator
   ratification)** — in ENGAGE mode (only when an active reflex proved `SHR_READY`; launchd never sets it) the
   responder now invokes the containment executor to **DISABLE** (reversible) registry-vetted, present
   offenders. Uninstall stays a further explicit gate (NOT auto-armed — reversible-first). Un-vetted/
   un-present producers still fall through to the HITL seed (the launchd path, with no `SHR_READY`, always
   dry-run-seeds — it never auto-contains).

An **active, armed agent** (or the armed responder above) performs the containment via
`bin/offender-containment.sh`, mechanizing the operator ADR (2026-07-14): *"até que o plugin nao tem fix na
fonte, pode desativar e/ou remover"* — with
escalating gates (prune → disable `+OFC_ARM+OFC_READY+evidence` → remove `+OFC_ALLOW_UNINSTALL`), an
**evidence gate** (`references/no-source-fix-registry.md` — a vetted upstream wontfix, not a hunch), a
protected-denylist (`1password/openclaw/omniroute/claude`), reversibility (`containment.log` restore
commands), and **disarmed-by-default dry-run**. Design rationale + edge cases:
`references/offender-containment-33-socratic.md`.

```bash
OFC="$CLAUDE_PLUGIN_ROOT/skills/system-health-responder/bin/offender-containment.sh"
"$OFC"                                          # DEFAULT dry-run: detect + PROPOSE. Acts on nothing.
"$OFC" --prune                                  # LOW: uv cache prune (non-destructive maintenance)
OFC_ARM=1 OFC_READY=1 "$OFC" --engage           # MEDIUM: disable registry-vetted, present offenders
OFC_ARM=1 OFC_READY=1 OFC_ALLOW_UNINSTALL=1 "$OFC" --engage --allow-uninstall  # HIGH: uninstall (reinstall-able)
```

### Round-2 (v1.4.0, 2026-07-14) — producer attribution + sibling-falsification

Running the recon surfaced material the design pass could not:

1. **Producer attribution** (collector v1.2.0): the `cache_producer` leaf now emits `uvx_latest_producers` —
   the argv-free `<pkg>@latest` token(s) of any *live* producer, so a re-emergent offender is **named**, not
   just counted. **Secret-safe by grammar** (not vigilance): only `^[alnum][alnum._-]*@latest$` is accepted, so
   a `--api-key=…` (starts `-`) or a `key=value` (contains `=`) is structurally rejected — unit-proven. Motivated
   by a live transient producer (pid 28935) that vanished before it could be named (the `uvx …@latest`
   spawn-do-exit model — the lever is the source/cache, never the transient proc).
2. **Sibling-falsification recorded** (`references/no-source-fix-registry.md`): the ~20 sibling AWS/deploy
   plugins from `deploy-on-aws`'s marketplaces were tested and are **NOT** the offender class — `deploy-on-aws`
   was the unique `awslabs uvx@latest` carrier. Recorded as a durable anti-false-positive so a future amnesic
   agent neither re-investigates nor wrongly mass-contains the operator's AWS plugins. Its uninstall cache-orphan
   is expected (native 7-day GC), not a re-drain.
3. **Warn residue is HITL, by design**: the collector's `system.status=warn` (firewall=disabled · XProtect stale ·
   a transient `fseventsd` cpu blip) is on branches *orthogonal* to EKO-90's disk scope. The responder seeds them
   (operator's System Settings / OS update) — it does not auto-flip a security control. Round-2 drained the stale
   NEEDS-AGENT seed (persisted the still-valid firewall/xprotect items; the cpu/process items were transient).

Design-reasoning (33 non-duplicate Socratic Q&A): `references/offender-containment-round2-33-socratic.md`.

## Composition (reuse, not reinvent — Strata)

- **Part-1 contract** (`~/.local/state/system-health/health-contract.json`) — the input it responds to.
- **disk-health-guardian** — owns disk; its `escalate()` → `write_agent_seed()` shape is the pattern this
  skill generalizes cross-resource (and it delegates disk *back* to the guardian).
- **engage-lock** — the `shared-git-lock` engaged-check idea (mkdir-mutex + stale-steal), local-state form.
- **Taxis** (`loose-end-triage-queue`) — the NEEDS-AGENT seed is the durable queue entry (no-silent-drop).
- **CASC / standing-autonomy** — the `--engage` gate (Moderate scope, `READY` predicate, HITL residue).

## Refs

- `references/auto-heal-safety-matrix.md` — the binding disposition table + PROC_DENYLIST + threshold ownership + the offender-containment tiers.
- `references/no-source-fix-registry.md` — the ADR evidence gate (vetted no-source-fix offenders + dossiers).
- `references/offender-containment-33-socratic.md` — round-1 design-reasoning (33 Socratic Q&A; the *why* behind the tiers).
- `references/offender-containment-round2-33-socratic.md` — round-2 operational-reasoning (33 non-duplicate Q&A; sibling-falsification · transient-vs-persistent producers · attribution · warn/HITL boundary · unknown-offender handling).
- `bin/offender-containment.sh` — the containment executor · `collectors/system-health-guardian.sh` — the extended Phase-1 collector.
- EKO-90 (Linear, team EKO) — the parent ticket; part-1 = the collector, part-2 = this responder + this v1.2.0 ext.
- `~/.claude/rules/loose-end-triage-queue.md` (Taxis) · `~/.claude/rules/agentic-observability-protocol.md`
  (Metron measure→respond) · `~/.claude/rules/standing-autonomous-operation-authorization.md` (READY gate).
