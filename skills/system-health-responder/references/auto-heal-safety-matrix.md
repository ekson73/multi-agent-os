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
| **disk** | `branches.disk.status != ok` | **DELEGATE to `disk-health-guardian`** — it owns disk (Tier-1/2 reclaim + its own escalate-seed). Zero duplication. | delegated |
| **security** | firewall / SIP / gatekeeper off | seed + notify — re-enabling security = operator (System Settings) | 🟠 HITL |
| **malware** | XProtect stale / detection | seed + notify — OS security update / quarantine = operator | 🟠 HITL |
| **memory** | available < threshold | seed + notify — freeing memory means killing a proc (destructive) | 🟠 HITL |
| **process** | zombie / runaway-count anomaly | seed + notify — kill = operator judgment | 🟠 HITL |
| **network** | unexpected listener | seed + notify — never auto-close a socket | 🟠 HITL |
| **agentic-tools — cache-producer** | `branches.agentic_tools.leaves.cache_producer.status != ok` | `uv cache prune` (non-destructive; removes ONLY unreachable objects, keeps tool installs) | ✅ **AUTONOMOUS (Moderate)** |
| **agentic-tools — live `@latest` producer** | `cache_producer.uvx_latest_procs > 0` | **ENGAGE (SHR_READY proven)** → responder invokes `offender-containment.sh --engage` = DISABLE registry-vetted, present offenders (reversible; uninstall NOT auto-armed). **DRY-RUN / launchd (no SHR_READY)** → seed only. Un-vetted → always seed. | ✅ **AUTONOMOUS DISABLE (armed 2026-07-14)** / 🟠 seed |
| **agentic-tools — claude runtime** | `claude_runtime.health != healthy` (from `claude doctor`) | seed + notify — fixing = operator `/doctor` in-session (the collector's probe is read-only) | 🟠 HITL |

**Eisenhower ordering (deterministic):** cpu-runaway (urgent+important → autonomous) → disk (delegated) →
agentic-tools cache-producer prune (Moderate autonomous) → security/malware (important, HITL) →
memory/process/network + agentic-tools containment/runtime (HITL). crit outranks warn within a class.

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

## PROC_DENYLIST — never `renice` these (case-insensitive on `comm`)

`kernel_task launchd WindowServer loginwindow coreaudiod configd hidd powerd bluetoothd cfprefsd mds`
`mds_stores mdworker syslogd distnoted securityd trustd` — macOS-critical; deprioritizing them harms the UI/OS.

`1password op openclaw omniroute claude` — **sensitive-app guard** (mirrors the operator's absolute denylist:
never manipulate 1Password / OpenClaw / OmniRoute / the agent runtime itself).

**Matching rule (exact behavior, so the doc matches the code):** tokens match as a **case-insensitive
substring** of `comm`, which errs **conservative** — the worst case is over-protection (we skip a `renice`
we *could* have done), never under-protection. **Exception:** the ultra-short token **`op`** (1Password CLI)
matches the **whole `comm` only** (`comm == "op"`), so it doesn't accidentally over-match unrelated names
like `Dropbox`, `top`, or `Finder` that happen to contain the letters "op".

## Threshold ownership (DRY)

The responder does **not** re-derive any threshold. Part-1's collector already computes each leaf's
`status` (ok/warn/crit) from its own env-overridable thresholds (`PROC_CPU_WARN=70`, `DISK_FREE_WARN_GB`,
`XPROTECT_STALE_WARN_DAYS`, …). The responder gates purely on the **computed leaf status** — single owner,
zero drift.

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
