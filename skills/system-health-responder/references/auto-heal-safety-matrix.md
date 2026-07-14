# Auto-Heal Safety Matrix — `system-health-responder`

> The binding disposition table for what the responder MAY do autonomously vs. what it
> MUST escalate to the operator (HITL). This is **normative documentation** — the source of
> truth for the policy that `bin/health-respond.sh` *implements in code*; the script does NOT
> parse this markdown at runtime (the dispositions are hard-coded in the engine, this doc and
> the engine are kept in sync by review). Authority level is **Moderate** (operator-chosen,
> EKO-90): *autonomous reversible `renice`/throttle for a clear runaway proc; everything
> destructive or security-touching → HITL.*
>
> **Autonomous-path gate (fail-safe).** The `renice` fires only when the engine is invoked with
> `--engage` **AND** `SHR_READY=1` (set by the calling reflex *after* it proves the standing-autonomy
> `READY` predicate + Moderate scope). `--engage` without `SHR_READY` degrades to dry-run — the engine
> never trusts the flag alone (DENY-until-proven). launchd must never set `SHR_READY`.

## Disposition per contract class

| Contract class (part-1 leaf) | Signal (from the contract) | Responder disposition | Autonomy |
|---|---|---|---|
| **cpu — runaway** | `branches.cpu.leaves.top_consumer.status != ok` AND `comm ∉ PROC_DENYLIST` AND `nice < RENICE_TO` | `renice RENICE_TO -p <pid>` (deprioritize) + record revert | ✅ **AUTONOMOUS (Moderate)** |
| cpu — protected runaway | runaway but `comm ∈ PROC_DENYLIST` | seed + notify (never touch) | 🟠 HITL |
| cpu — already-deprioritized | runaway but `nice ≥ RENICE_TO` (renice-down needs root) | seed + notify (kill/quit = operator) | 🟠 HITL |
| **cpu — load saturation** (round-6 F1) | `branches.cpu.status ∈ {warn, crit}` AND `root_fail ≠ top_consumer` (SUSTAINED system load `load1`/`load5`, no single runaway) | seed + notify — **not auto-healable** (there is no single proc to renice; reducing load = operator closes apps). Was silently dropped pre-round-6 (the responder read only the `top_consumer` leaf, never the branch). | 🟠 HITL |
| **disk** | `branches.disk.status != ok` | **DELEGATE to `disk-health-guardian`** — it owns disk (Tier-1/2 reclaim + its own escalate-seed). Zero duplication. | delegated |
| **burn_down — forecast** (top-level `burn_down`, round-3) | `burn_down.status ∈ {warn, crit}` AND `burn_down.trend == "draining"` (reclaim-aware: sloped over the post-reclaim-jump tail, so a guardian cache-deletion up-jump can't mask a genuine drain) | **seed + notify** — `health-respond.sh main()` reads the top-level `.burn_down` **independently of `.system.status`** (it is NOT a `.system.branches` leaf, so it does not feed the roll-up — the early-return is gated on it too) and surfaces `days_to_threshold` + `drain_gb_per_hr` so a session/operator acts *before* the crisis the 2026-07-14 drain reached. **Observe-only leading indicator — a forecast NEVER auto-deletes; the disk *branch* (above) owns actual reclaim.** `unknown` (thin/absent log) → no action, no seed (never a fabricated number). | 🟠 seed + notify (no new autonomous action) |
| **security** | firewall / SIP / gatekeeper off | seed + notify — re-enabling security = operator (System Settings) | 🟠 HITL |
| **malware** | XProtect stale / detection | seed + notify — OS security update / quarantine = operator | 🟠 HITL |
| **memory** | available% low **OR** kernel `pressure` warn/crit (round-6 F5: available% adds back inactive/purgeable → can read ok while the kernel signals pressure; blended via `worst()`) | seed + notify — freeing memory means killing a proc (destructive) | 🟠 HITL |
| **process** | zombie (env-thresholded) **or** optional thread high-water anomaly (round-6 F4: `counts.status` = zombies ⊕ threads, no longer zombies-only) | seed + notify — kill = operator judgment | 🟠 HITL |
| **network** | `informational` (round-6 F3: listeners collected but NOT thresholded → honest non-`ok` label, **no residue** — never a false `ok`, never a false HITL seed) | **none** (observe-only; never auto-close a socket) | ⚪ informational |
| **agentic-tools — cache-producer** | `branches.agentic_tools.leaves.cache_producer.status != ok` | `uv cache prune` (non-destructive; removes ONLY unreachable objects, keeps tool installs) | ✅ **AUTONOMOUS (Moderate)** |
| **agentic-tools — live `@latest` producer** | `cache_producer.uvx_latest_procs > 0` (+ `uvx_latest_producers` = the argv-free `<pkg>@latest` name(s), when the spawn was alive long enough to `ps` — secret-safe by grammar) | **ENGAGE (SHR_READY proven)** → responder invokes `offender-containment.sh --engage` = DISABLE registry-vetted, present offenders (reversible; uninstall NOT auto-armed). **DRY-RUN / launchd (no SHR_READY)** → seed only (naming the producer in the seed). Un-vetted → always seed. Producers are **transient** (spawn-do-exit) → the lever is the source (disable) / the cache (prune), never the proc. | ✅ **AUTONOMOUS DISABLE (armed 2026-07-14)** / 🟠 seed |
| **agentic-tools — claude runtime** | `claude_runtime.health != healthy` (from `claude doctor`) | seed + notify — fixing = operator `/doctor` in-session (the collector's probe is read-only) | 🟠 HITL |

**Eisenhower ordering (deterministic):** cpu-runaway (urgent+important → autonomous) → disk (delegated) →
agentic-tools cache-producer prune (Moderate autonomous) → security/malware (important, HITL) →
cpu-load-saturation / memory / process + agentic-tools containment/runtime (HITL). crit outranks warn within a
class. `network` is observe-only `informational` (round-6 F3) — not in the action ordering.

## Offender-containment tiers (`bin/offender-containment.sh`) — above Moderate, separately armed (EKO-90-ext)

The 2026-07-14 disk-drain proved a gap: the disk-guardian cleaned caches but could not beat a **live
producer** (`uvx …@latest` MCP churn; `uv` has no auto-GC). Neutralizing the producer is the root-fix,
but disabling/removing a plugin is **above Moderate** — so it gets its own escalating gates
(*elevate-autonomy → elevate-rigor*, DENY-until-proven):

| Tier | Action | Stakes | Reversibility | Arm gate |
|---|---|---|---|---|
| **prune** | `uv cache prune` | LOW · non-destructive | regeneration on next use | `--engage`+`SHR_READY` (Moderate — same as renice) |
| **disable** | `claude plugin disable <p>` | MEDIUM · reversible | `claude plugin enable <p>` | `--engage` + `OFC_ARM=1` + `OFC_READY=1` + **registry evidence** |
| **remove** | `claude plugin uninstall <p>` | HIGH · reinstall-able | `claude plugin install <p>` | above **+ `OFC_ALLOW_UNINSTALL=1`** |
| **default (no flags)** | detect + PROPOSE only | none | — | none — pure dry-run + seed |

> **ARMED status (operator ratification 2026-07-14):** the **disable** tier is now invoked autonomously by
> the responder's ENGAGE path (fires only when an active reflex proved `SHR_READY` — launchd never sets it,
> so the unattended cycle stays dry-run+seed). The **uninstall** tier remains a further explicit gate
> (`OFC_ALLOW_UNINSTALL`) — never auto-armed (reversible-first). Both stay evidence-gated + protected-denylisted.

**Evidence gate (the ADR's "no source fix" made real, not hand-waved):** a plugin is disabled/removed
ONLY if it appears in `references/no-source-fix-registry.md` with a confirmed upstream wontfix/closed/
not-planned + verified-date. Un-vetted producer → propose + seed to investigate (`/quiesce`'s "pesquise
do que se trata"), never auto-contain. **Protected tools (`1password openclaw omniroute claude`) are
refused** even if a registry entry names them (`claude` matches **whole-string** — it guards the *runtime*,
never claude-branded plugins/marketplaces like `claude-plugins-official`/`claude-code-concierge`; the others
match as conservative substrings, mirroring the renice-denylist `op` whole-word exception). Every
disable/remove appends its exact restore command to
`containment.log` (auditable reversibility — the renice-reverts.log pattern generalized).

> **Operator ADR 2026-07-14 (verbatim pt-BR):** *"Até que o agentic-tool/plugin nao tem fix resolvido na
> fonte, pode desativar e/ou remover o agentic-tool e/ou plugin."* This tier is the mechanization of that
> standing authorization — disarmed-by-default, evidence-gated, reversible, protected-denylist-honored.

## Why `renice` is the only autonomous lever (and how it stays reversible)

- **Non-destructive**: `renice` changes scheduling priority only — the proc keeps running, loses no data.
- **Reversible-by-record**: on macOS/BSD a *non-root* process can raise niceness (deprioritize) but cannot
  lower it back. So every autonomous renice appends the **exact restore command + original nice** to
  `reverts.log` (`renice <orig> -p <pid>`). Operator/root can restore; a proc-restart also resets it.
  This is *auditable* reversibility, not self-reversibility — stated honestly, not hand-waved.
- **Bounded**: `RENICE_TO` defaults to **+10** (moderate deprioritize, not extreme +20). Never `renice` below
  the current value (would need root and would *raise* priority — out of scope).
- **Pid-recycle guarded (round-5 #2, hardened v1.7.1 per CodeRabbit #131/#138)**: the contract can be up to
  `StartInterval` (600s) stale, so before acting `try_renice()` re-reads the **live** `comm` and requires an
  **exact normalized match** (`comm_match()` — basename + lowercase + strip-space, both non-empty, equal; **not**
  substring, so a recycled `foo-helper` can't match a contract `foo` and an empty comm matches nothing), then
  re-runs the denylist on the *live* comm, then **binds a start-identity** (`ps -o lstart=`) and re-verifies it
  immediately before the renice. A pid recycled to a different (or protected) process since the sample is skipped
  (fail-closed) — the autonomous action never trusts the ≤600s-old pid→comm binding alone, and the check→act
  TOCTOU is narrowed. Sound because `renice` is fully reversible (reverts.log), denylist-guarded, and re-sampled
  next 600s cycle.

## PROC_DENYLIST — never `renice` these (case-insensitive on `comm`)

`kernel_task launchd WindowServer loginwindow coreaudiod configd hidd powerd bluetoothd cfprefsd mds`
`mds_stores mdworker syslogd distnoted securityd trustd` — macOS-critical; deprioritizing them harms the UI/OS.

`1password op openclaw omniroute claude` — **sensitive-app guard** (mirrors the operator's absolute denylist:
never manipulate 1Password / OpenClaw / OmniRoute / the agent runtime itself).

**Matching rule (exact behavior, so the doc matches the code):** the `comm` is first **basename-normalized**
(lowercased basename — so a PATH comm like `/usr/local/bin/op` is compared as `op`; v1.7.1 per CodeRabbit @145,
consistent with `comm_match()`). Tokens then match as a **case-insensitive substring** of that basename, which
errs **conservative** — the worst case is over-protection (we skip a `renice` we *could* have done), never
under-protection. **Exception:** the ultra-short token **`op`** (1Password CLI) matches the **whole basename
only** (`basename(comm) == "op"`), so it protects `/usr/local/bin/op` AND bare `op` without over-matching
unrelated names like `Dropbox`, `top`, or `Finder` that merely contain the letters "op".

## Threshold ownership (DRY)

The responder does **not** re-derive any threshold. Part-1's collector already computes each leaf's
`status` (ok/warn/crit) from its own env-overridable thresholds (`PROC_CPU_WARN=70`, `DISK_FREE_WARN_GB`,
`XPROTECT_STALE_WARN_DAYS`, …). The responder gates purely on the **computed leaf status** — single owner,
zero drift.

> **Round-4 (collector v1.4.0→v1.4.1)** refined two of those thresholds to kill false-positives (transparent
> to the responder — it still just reads `status`): CPU **crit** now keys on `load5` (sustained) not `load1`
> (spiky) — a transient burst warns, never crits; XProtect freshness is gated on the auto-update channel
> (`XPROTECT_SELFHEAL_WARN_DAYS=60` when auto-update is ON ⇒ never crit / self-healing; full
> `XPROTECT_STALE_WARN_DAYS`/`_CRIT_DAYS` escalation only when auto-update is OFF — the real risk).
> The auto-update signal is a **proxy** (`softwareupdate --schedule`), NOT a direct XProtect read (modern
> macOS updates XProtect via `XProtectUpdateService`); **v1.4.1** threads a third `unknown` state so a
> *probe failure* degrades **fail-safe** (warn-capable, **never crit**) instead of collapsing to `off` and
> manufacturing a false-crit — the leaf `xprotect_freshness.auto_update` carries `on|off|unknown` for
> drill-down transparency regardless of the roll-up.
>
> **Round-5 (collector v1.5.0)** finished the ncpu-aware thesis + two honesty fixes (still transparent to the
> responder — leaf `status` only): (#1) **`top_consumer`/`runaway` is now ncpu-aware** — `PROC_CPU_WARN=70`
> stays a **per-core** WARN (the renice-actionable signal), but CRIT now requires `pct ≥ PROC_CPU_CRIT_RATIO
> (0.50) × ncpu × 100` (a real fraction of TOTAL capacity), so one core-bound proc on a many-core box is WARN,
> not a system crit — the load branch already owns true saturation. (#5) **XProtect freshness prefers the
> authoritative `xprotect version`** (real install date, no-sudo) over the bundle-mtime proxy that measures
> the wrong artifact; `xprotect_freshness.source` carries `xprotect-cli|bundle-mtime`. (#6) the
> `process.counts` leaf now reflects the real `zombies` status (was hardcoded `ok`) so root-fail drill-down
> lands on a non-`ok` leaf.
>
> **Round-6 (collector v1.5.0→v1.6.0)** — an anti-theater OODA that fixed what "ok" *means* rather than the
> labels. One responder-side change (**F1**, the only new disposition above): the responder now reads the
> `cpu` **branch** status, so a sustained-load crit (`root_fail=load1/load5`, no single runaway) is seeded to
> HITL instead of silently dropped. Four collector honesty fixes (still leaf-`status`-transparent to the
> responder): **F5** memory blends `kern.memorystatus_vm_pressure_level` (a false-`ok` caught live — available%
> can read ok while the kernel signals pressure); **F4** `counts.status` = zombies (now env-overridable) ⊕ an
> optional thread high-water (0 = disabled), and `thread_count` is threads-only (was procs+threads); **F3**
> `network` is honestly `informational` (collected-not-thresholded), never a false `ok` nor a false HITL seed;
> **F2** the `claude_runtime` probe resolves `claude` to an absolute path (launchd's minimal PATH had left it
> perpetually `absent`). **H1** the sensitive-app safelist core (`1password openclaw omniroute claude`) is now a
> single labelled SSOT in both `PROC_DENYLIST` (renice) and `PROTECTED` (containment), drift-guarded by a test.

## What the responder will NEVER do (⛔ absolute)

- Kill / `pkill` / force-quit any process.
- Quarantine, delete, or move any file.
- Re-enable / disable a security control (firewall, SIP, gatekeeper), or update the OS.
- Do disk-CRISIS reclaim (the disk-health-guardian owns space-crisis reclaim). The ONE cache action the
  responder may take is `uv cache prune` — strictly non-destructive **producer-cache hygiene** (removes
  only *unreachable* objects, never a tool install / user data / the disk-guardian's crisis nuke). Distinct
  axis: hygiene (proactive, targeted at a detected producer) ≠ crisis reclaim (reactive, disk-guardian).
- Disable / uninstall any plugin from within the *launchd responder* itself — containment is only ever
  performed by an ACTIVE agent invoking `offender-containment.sh` under the ADR arm + registry evidence
  (the responder only PROPOSES + seeds it).
- Echo / log / persist any secret value, or read a process's argv/`command` (tokens live there — reads
  `comm`/`pid`/`pct`/`nice` metadata only).
- Act on a denylisted (critical / sensitive) process.
