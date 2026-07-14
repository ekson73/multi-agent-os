---
name: system-health-responder
description: End-of-action reflex that reads the system-health contract, engage-locks, Eisenhower-ranks the warnings, does MODERATE non-destructive auto-heal (autonomous reversible renice of a clear cpu runaway + `uv cache prune` producer-hygiene), responds to the new `agentic_tools` branch (`claude doctor` runtime health + cache-producer pressure), reads the reclaim-aware `burn_down` disk forecast (observe-only leading indicator → seed+notify before crisis), and escalate-seeds the HITL residue (security · malware · kill · disk→disk-guardian · no-source-fix offender containment). EKO-90 part-2 — the responder half of the health suite.
version: 1.7.1
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

### Burn-down forecast (v1.5.0, round-3, 2026-07-14) — the proactive half, completed

The original EKO-90 DoD listed *"previsão de burn-down"* but rounds 1-2 left it a `BURN_DOWN="null"` stub.
Round-3 implements it — the **leading indicator** whose absence let the 2026-07-14 drain reach 2.5 GB
before anyone noticed. The collector (v1.2.0 → **v1.3.0**) now emits a structured top-level `burn_down`:

```json
"burn_down": {"status":"warn","trend":"draining","drain_gb_per_hr":2.10,"days_to_threshold":3.4,"threshold_gb":15,"samples":18,"free_gb":186}
```

- **Reclaim-aware** (`compute_burndown()`, collector **v1.3.2**): reads the disk-guardian's own timestamped
  `free=<N>G` samples (no new state file) and slopes **only the tail after the last reclaim up-jump** —
  because free space *jumps up* on the guardian's cache deletions, a naïve slope would misread a
  reclaim-masked drain as "recovering". When that post-reclaim tail is too short to slope honestly
  (<3 samples), it returns `unknown reason:post-reclaim-tail-short` rather than re-including the jump.
  Flat/rising tail → `{status:ok, trend:"stable-or-recovering", days_to_threshold:null}`; genuine drain →
  `days_to_threshold` + `status` (crit <1d · warn <7d · ok else). Timestamp parse accepts `+0000`, RFC3339
  `+00:00`, and Zulu `…Z` (no silent sample loss on a producer format drift).
- **Observe-only, but WIRED** — a forecast never auto-deletes anything; a `warn`/`crit` burn-down →
  **the responder reads `.burn_down` and seeds + notifies** (`main()`, gated independently of
  `.system.status` since `burn_down` is a top-level leading indicator, not a `.system.branches` leaf) so a
  session/operator acts *before* crisis. No new autonomous action — the disk *branch* still owns reclaim.
- **Secret-safe** (only free-space integers + timestamps; never argv) · **cold-start honest** (thin/absent
  log → `status:"unknown"`, never a fabricated number — Tomé).
- **Tested**: `bin/burndown-test.sh` — 7 synthetic series / 16 assertions (declining → correct
  days-to-threshold; **reclaim-jump → NOT misread as recovering** [the critical assertion]; flat/rising →
  not-draining; insufficient → unknown; `+00:00` & Zulu `Z` → parse; **short post-reclaim tail → honest
  `unknown`, not a jump-contaminated slope**). Plus `bin/responder-burndown-test.sh` — 4 cases / 5
  assertions proving the responder ACTS on `.burn_down` (warn/crit → seed; ok/unknown → quiet; the
  wired-not-inert proof).

```bash
DISK_GUARDIAN_LOG=<log> "$COLLECTOR" --burndown   # forecast-only (no probing, no contract write) — testable
```

### Threshold false-positive fixes (v1.6.1, round-4, 2026-07-14) — honest classification, not more theater

An OODA review after the round-3 merge surfaced **two false-positive classes** the collector's thresholds
mis-classified — both empirically observed this session. A false `crit`/`warn` isn't cosmetic: it makes the
responder engage spuriously, which erodes the trust the operator needs to let the auto-heal run unattended.
So this is squarely an **enhance-autonomy** fix (collector **v1.3.2 → v1.4.1**):

- **CPU transient false-crit** — `cpu_load_status()`. `vm.loadavg` carries three averages `{1min 5min 15min}`;
  the collector keyed **both** warn and crit off `load1` (the *spikiest* metric), so a transient burst
  (IDE compile / Spotlight indexer) tripped `crit`. Fix: **WARN keyed on `load1`** (early signal),
  **CRIT keyed on `load5`** (sustained) — a 1-min burst warns but never crits; crit now requires ~5 min of
  real overload. Empirical: `load1=27.33/12cores` (2.28×) crit that settled to `warn` in ~4 min. The `load1`
  leaf now also exposes `load5` + `load5_ratio` for honest drill-down.
- **XProtect chronic false-warn** — `xprotect_status()`. Age-alone conflates "genuinely stale" with "Apple
  hasn't shipped a newer signature" (XProtect ships on Apple's cadence, routinely >30d). Fix: gate on the
  **auto-update channel** (cheap ~20ms `softwareupdate --schedule` read, no-sudo — a **proxy**, not a direct
  XProtect read; modern macOS updates XProtect via `XProtectUpdateService`): auto-update **ON** ⇒
  self-healing ⇒ caps at `warn` past a generous 60d window, **never crit** (the next signature lands
  automatically); auto-update **OFF** ⇒ the real risk ⇒ full 30/60 age escalation. Empirical: 5347 (47d) **is**
  Apple's latest for macOS 26.5.2 with auto-update on → honestly `ok`, not `warn`. The leaf now exposes
  `auto_update` (`on|off|unknown`). **v1.4.1 (CodeRabbit finding)**: the probe is capture-then-classified into
  a third `unknown` state, so a *probe failure* degrades **fail-safe** (warn-capable, **never crit**) instead
  of collapsing to `off` and manufacturing a false-crit — the residual false-positive hiding in this fix's own
  error path.
- Both extracted as **pure functions** (mirroring `compute_burndown`) with **test entrypoints**
  (`--cpu-load-status` / `--xprotect-status`) so they're exercised, not eyeballed. **Anti-theater**: this did
  not mark anything healthy — it fixed *what "healthy" means*; the contract went `crit → ok` by correct
  classification, and `auto-OFF 65d → crit` still fires (real risk preserved).
- **Tested**: `bin/threshold-test.sh` — 16 assertions (burst→warn-not-crit · sustained-load5→crit ·
  auto-ON-47d→ok · auto-OFF-65d→crit · never-crit-while-self-healing · **unknown-9999d→warn-never-crit**).
  Round-3 suites regress clean (16+5).

### Multi-core & measurement-honesty fixes (v1.7.0, round-5, 2026-07-14) — finishing the ncpu-aware thesis

Round-4 made the **load-aggregate** ncpu-aware but left the **per-process** leaf raw — an OODA sweep caught
the unfinished half plus three adjacent honesty/safety gaps (collector **v1.4.1 → v1.5.0**, skill **v1.6.1 → v1.7.0**):

- **#1 `top_consumer`/`runaway` NOT ncpu-aware (the live false-crit)** — `top_consumer_status()`. macOS `ps
  %cpu` is **per-core** (100% = one full core, can exceed 100%). Warn+crit were applied raw, so one process
  at 130.7% (1.3 of 12 cores ≈ 11% of capacity) rolled up to `system=crit` **while the sustained-saturation
  branch said the box was fine** — the two CPU branches actively contradicted each other. Fix (twin of the
  round-4 load1/load5 split): **WARN keyed per-core** (the responder's renice-actionable signal survives —
  renice fires on any non-`ok`), **CRIT requires a fraction of TOTAL capacity** (`PROC_CPU_CRIT_RATIO=0.50` ⇒
  crit only when a proc eats ≥50% of `ncpu`; the load branch already owns true saturation). Fail-safe on
  `ncpu=1` (crit never below warn). Auto-resolves the old double-count (a reniced proc no longer *also* seeds
  a "process=crit → operator kill"). Empirical: live `global crit → warn` (a busy core, not a system emergency).
- **#5 XProtect measured the wrong artifact (upgrade)** — freshness now prefers the **authoritative
  `/usr/bin/xprotect version`** (no-sudo, real version + install date) over the legacy `XProtect.bundle`
  mtime, which modern macOS never touches on a signature update (`XProtectUpdateService` writes elsewhere).
  Empirical: bundle-mtime said **47d**, the CLI says the real install was Jun-3 = **41d** — a 6-day honesty
  gap. `source` (`xprotect-cli|bundle-mtime`) is exposed in the leaf; bundle-mtime remains the fallback for
  older macOS. This is `medição real`, not a proxy.
- **#2 responder pid-recycle guard (safer autonomy)** — `try_renice()` re-reads the **live** `comm` for the
  pid and requires an **exact normalized match** (`comm_match()`: basename + lowercase + strip-space, both
  non-empty, equal) to the (≤600s-old) contract comm **before** renicing, then re-runs the denylist on the
  *live* comm, then **binds a process start-identity** (`ps -o lstart=`) and re-verifies it immediately before
  the action. A recycled pid can no longer be reniced by mistake, a recycled-into-protected proc is refused,
  and the check→act TOCTOU window is narrowed (fail-closed on identity drift). Directly hardens the one
  autonomous action the responder takes. *(v1.7.1 PDCA per CodeRabbit PR#259 #131/#138 — the initial
  either-contains-substring match was too loose: a recycled `foo-helper` would match a contract `foo`, and an
  empty contract comm would match anything, either authorizing a wrong-proc renice; replaced with exact
  equality + start-identity re-check. A follow-up review added two more: **@145** — `denied()` now
  basename-normalizes so the whole-word `op` (1Password CLI) rule protects a PATH comm (`/usr/local/bin/op`),
  not just a bare `op`; **@157** — the original niceness `cur` is now sampled AFTER the start-identity is bound
  (a recycle can no longer pair a stale nice value with a live identity). `renice` is fully reversible +
  denylist-guarded + re-sampled every 600s, so fail-closed is sound.)*
- **#6 drill-down leaf-status consistency** — the `process.counts` leaf carried a hardcoded `status:"ok"`
  while its own `zombies` value could drive the branch to `crit`, so a `root_fail → leaf` walker landed on an
  `ok`-labeled leaf. Now the leaf reflects the (DRY, computed-once) `zombie` status — honoring the contract's
  "cada nível aponta o filho com falha → root-fail" promise.
- **Deferred (documented, not dropped)**: memory could use the native `kern.memorystatus_vm_pressure_level`
  signal (low payoff — memory is HITL-only + the current available% already adds back reclaimable classes).
- **Tested**: `bin/threshold-test.sh` — **+7 `top_consumer_status`** (130.7@12c→warn · 700@12c→crit ·
  ncpu=1 fail-safe · …) **+8 `comm_match` recycle-guard** (foo-helper≠foo · empty≠anything ·
  case/basename-normalize · …) **+6 `denied` basename-normalize** (/path/op→denied · top→allowed ·
  1Password-path→denied · …) assertions = **37**; round-3 suites regress clean (16+5) = **58/58**.

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
- `bin/offender-containment.sh` — the containment executor · `collectors/system-health-guardian.sh` — the extended Phase-1 collector (v1.3.x = burn-down · **v1.4.1 = round-4 threshold fixes + probe fail-safe**).
- `bin/burndown-test.sh` — round-3 collector unit tests (drives `--burndown`; 16 assertions: reclaim-jump-not-misread · short-tail-honest-unknown · `+0000`/`+00:00`/`Z` tz variants).
- `bin/responder-burndown-test.sh` — round-3 responder wiring tests (5 assertions: `warn`/`crit`→seed · `ok`/`unknown`→quiet — proves `.burn_down` is read, not just documented).
- `bin/threshold-test.sh` — round-4 threshold unit tests (drives `--cpu-load-status`/`--xprotect-status`; 13 assertions: CPU burst→warn-not-crit · sustained-load5→crit · XProtect auto-ON-47d→ok · auto-OFF-65d→crit · never-crit-while-self-healing).
- EKO-90 (Linear, team EKO) — the parent ticket; part-1 = the collector, part-2 = this responder + this v1.2.0 ext.
- `~/.claude/rules/loose-end-triage-queue.md` (Taxis) · `~/.claude/rules/agentic-observability-protocol.md`
  (Metron measure→respond) · `~/.claude/rules/standing-autonomous-operation-authorization.md` (READY gate).
