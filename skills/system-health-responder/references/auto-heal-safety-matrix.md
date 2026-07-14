# Auto-Heal Safety Matrix — `system-health-responder`

> The binding disposition table for what the responder MAY do autonomously vs. what it
> MUST escalate to the operator (HITL). Consumed by `bin/health-respond.sh`. Authority level
> is **Moderate** (operator-chosen, EKO-90): *autonomous reversible `renice`/throttle for a
> clear runaway proc; everything destructive or security-touching → HITL.*

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

**Eisenhower ordering (deterministic):** cpu-runaway (urgent+important → autonomous) → disk (delegated) →
security/malware (important, HITL) → memory/process/network (HITL). crit outranks warn within a class.

## Why `renice` is the only autonomous lever (and how it stays reversible)

- **Non-destructive**: `renice` changes scheduling priority only — the proc keeps running, loses no data.
- **Reversible-by-record**: on macOS/BSD a *non-root* process can raise niceness (deprioritize) but cannot
  lower it back. So every autonomous renice appends the **exact restore command + original nice** to
  `reverts.log` (`renice <orig> -p <pid>`). Operator/root can restore; a proc-restart also resets it.
  This is *auditable* reversibility, not self-reversibility — stated honestly, not hand-waved.
- **Bounded**: `RENICE_TO` defaults to **+10** (moderate deprioritize, not extreme +20). Never `renice` below
  the current value (would need root and would *raise* priority — out of scope).

## PROC_DENYLIST — never `renice` these (substring, case-insensitive on `comm`)

`kernel_task launchd WindowServer loginwindow coreaudiod configd hidd powerd bluetoothd cfprefsd mds`
`mds_stores mdworker syslogd distnoted securityd trustd` — macOS-critical; deprioritizing them harms the UI/OS.

`1password op openclaw omniroute claude` — **sensitive-app guard** (mirrors the operator's absolute denylist:
never manipulate 1Password / OpenClaw / OmniRoute / the agent runtime itself).

## Threshold ownership (DRY)

The responder does **not** re-derive any threshold. Part-1's collector already computes each leaf's
`status` (ok/warn/crit) from its own env-overridable thresholds (`PROC_CPU_WARN=70`, `DISK_FREE_WARN_GB`,
`XPROTECT_STALE_WARN_DAYS`, …). The responder gates purely on the **computed leaf status** — single owner,
zero drift.

## What the responder will NEVER do (⛔ absolute)

- Kill / `pkill` / force-quit any process.
- Quarantine, delete, or move any file.
- Re-enable / disable a security control (firewall, SIP, gatekeeper), or update the OS.
- Touch disk (the disk-health-guardian owns it).
- Echo / log / persist any secret value, or read a process's argv/`command` (tokens live there — reads
  `comm`/`pid`/`pct`/`nice` metadata only).
- Act on a denylisted (critical / sensitive) process.
