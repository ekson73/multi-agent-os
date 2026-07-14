#!/usr/bin/env bash
# /** health-respond.sh — EKO-90 part-2: system-health responder (deterministic engine)
#  *
#  *  @what   End-of-action reflex executor. Reads the part-1 health-contract, engage-locks
#  *          (so two reflexes never double-act), Eisenhower-ranks the warn/crit leaves, and:
#  *            - MODERATE auto-heal: autonomously `renice`s a CLEAR cpu runaway that is NOT
#  *              on the proc-denylist (reversible-by-record; never a critical/sensitive proc);
#  *            - DELEGATES disk to disk-health-guardian (it owns disk — zero duplication);
#  *            - ESCALATE-SEEDS the HITL residue (security · malware · memory · kill · net)
#  *              via a NEEDS-AGENT seed + osascript notify + 6h throttle (disk-guardian shape).
#  *
#  *  @safe   `--dry-run` is the DEFAULT (proposes, acts on NOTHING). `--engage` performs the
#  *          Moderate autonomous renice. NEVER kills, quarantines, re-enables security, updates
#  *          the OS, or touches disk. Non-destructive only.
#  *  @secret Reads comm/pid/pct/status METADATA only — never argv/command (which carries tokens).
#  *          Writes nothing secret. Contract + seeds are the operator's own machine-local state.
#  *  @revert Every autonomous renice appends the exact restore command + original nice to
#  *          reverts.log (auditable reversibility — operator/root can restore; proc-restart resets).
#  *  @deny   Protected procs are NEVER reniced: kernel_task launchd WindowServer loginwindow
#  *          coreaudiod configd hidd powerd bluetoothd cfprefsd mds mds_stores mdworker syslogd
#  *          + sensitive apps 1password op openclaw omniroute claude (substring, case-insensitive).
#  *  @exit   0 ok · 1 no-contract/lock-held · 2 internal error. (script-safety §6: real exit.)
#  */
set -euo pipefail

STATE_DIR="${SHR_STATE_DIR:-$HOME/.local/state/system-health}"
CONTRACT="${SHR_CONTRACT:-$STATE_DIR/health-contract.json}"
LOG="${SHR_LOG:-$STATE_DIR/responder.log}"
LOCK="$STATE_DIR/responder.lock"
LOCK_STALE_SEC="${SHR_LOCK_STALE_SEC:-1800}"      # 30min stale-steal
ESCALATE_THROTTLE_SEC="${SHR_ESCALATE_THROTTLE_SEC:-21600}"  # 6h, disk-guardian parity
RENICE_TO="${SHR_RENICE_TO:-10}"                  # moderate deprioritize (not extreme +20)
DRY_RUN=1
NOTIFY=1; [ "${SHR_NO_NOTIFY:-0}" = "1" ] && NOTIFY=0

# SENSITIVE-APP SAFELIST — SSOT CORE (round-6 H1): the 4 tokens `1password openclaw omniroute claude` MUST
# stay identical in BOTH this PROC_DENYLIST and offender-containment.sh PROTECTED — the runtime + the
# secrets/sovereignty managers that NEITHER effector may ever touch (renice OR contain). Kept INLINE in each
# script (NOT a sourced lib) ON PURPOSE: a safety-critical safelist must be fail-safe/self-contained — a
# missing/empty sourced lib would be the UNSAFE direction (an empty safelist). Drift is caught deterministically
# by threshold-test.sh (`SSOT sensitive-app core` assertion), not by faith.
PROC_DENYLIST=(
  # OS daemons — renice-protected (responder-scope; not relevant to containment)
  kernel_task launchd windowserver loginwindow coreaudiod configd hidd powerd
  bluetoothd cfprefsd mds mds_stores mdworker syslogd distnoted securityd trustd
  1password openclaw omniroute claude   # ← SSOT sensitive-app core (sync ↔ offender-containment.sh PROTECTED)
  op                                    # responder-scope extra: 1Password CLI (whole-word match in denied())
)

usage() {
  cat <<'EOF'
health-respond.sh — system-health responder (EKO-90 part-2)
  (default)     DRY-RUN: read contract, rank, PROPOSE actions, seed HITL residue. Acts on nothing.
  --engage      Perform the Moderate autonomous renice of a clear cpu runaway (reversible-by-record).
                REQUIRES SHR_READY=1 (the calling reflex sets it AFTER proving standing-autonomy
                READY); without it --engage fail-safe DEGRADES to dry-run (DENY-until-proven).
  --help        This help.
Env: SHR_CONTRACT SHR_STATE_DIR SHR_LOG SHR_RENICE_TO SHR_LOCK_STALE_SEC SHR_ESCALATE_THROTTLE_SEC
     SHR_READY=1 (gate the autonomous --engage path) · SHR_NO_NOTIFY=1 (suppress macOS notification)
EOF
}

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG" 2>/dev/null || true; }
# INJECTION-SAFE: title/subtitle are passed as AppleScript string VALUES via argv (`on run argv`),
# NEVER spliced into the script source. A process named with an embedded `"` (attacker-influenceable
# `comm`) is thus an inert string literal — it can never break out into `do shell script`. (CWE-78.)
notify() {
  [ "$NOTIFY" -eq 1 ] || return 0
  command -v osascript >/dev/null 2>&1 || return 0
  osascript - "$1" "$2" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  display notification (item 1 of argv) with title "System-Health Responder" subtitle (item 2 of argv)
end run
APPLESCRIPT
}

# portable mtime (BSD `stat -f` → GNU `stat -c` → 0) — os-agnostic per EKO-90 spec
mtime_of() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

acquire_lock() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  if mkdir "$LOCK" 2>/dev/null; then printf '%s' "$$" >"$LOCK/pid" 2>/dev/null || true; return 0; fi
  # lock exists — steal ONLY if VERIFIABLY stale: age>threshold AND the recorded holder pid is dead.
  local age holder; age=$(( $(date +%s) - $(mtime_of "$LOCK") ))
  holder="$(cat "$LOCK/pid" 2>/dev/null || echo '')"
  if [ "$age" -gt "$LOCK_STALE_SEC" ] && { [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; }; then
    # ATOMIC steal via rename-aside: `mv` of a dir is atomic on one fs, so among N concurrent
    # stealers EXACTLY ONE succeeds the mv; the losers' `mv` fails (source already moved) and they
    # stand down — no double-`mkdir`, no duplicate hold from the concurrent-steal path (CWE-362).
    # Defense-in-depth: even a residual race is HARMLESS here because the only autonomous action
    # (renice) is idempotent + guarded (already-deprioritized→HITL) and seeds are 6h-throttled.
    local aside="${LOCK}.stale.$$"
    if mv "$LOCK" "$aside" 2>/dev/null; then
      rm -rf "$aside" 2>/dev/null || true
      if mkdir "$LOCK" 2>/dev/null; then printf '%s' "$$" >"$LOCK/pid" 2>/dev/null || true
        log "engage-lock: stole verified-stale lock (age ${age}s, holder=${holder:-none} dead)"; return 0; fi
    fi
  fi
  return 1
}
release_lock() { rm -rf "$LOCK" 2>/dev/null || true; }

denied() {  # $1=comm → 0 if protected. Substring match, which ERRS CONSERVATIVE (over-protect: worst
            # case we skip a renice we could have done — never the reverse). EXCEPTION: the ultra-short
            # `op` token (1Password CLI) matches WHOLE-comm only, so it doesn't over-match Dropbox/top/etc.
  # basename-normalize (per CodeRabbit PR#259 @145): `ps -o comm=` may return a PATH (`/usr/local/bin/op`).
  # Without basename the whole-comm `op` rule below (`c == "op"`) would MISS a path → the sensitive 1Password
  # CLI could be reniced on recycle. Basename also makes this consistent with comm_match() + tightens the
  # substring rules against false path-component matches. Denylist entries are all comm basenames.
  local c; c="$(basename "${1:-}" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  local d; for d in "${PROC_DENYLIST[@]}"; do
    if [ "$d" = "op" ]; then [ "$c" = "op" ] && return 0; continue; fi
    case "$c" in *"$d"*) return 0;; esac
  done
  return 1
}

# normalized comm-identity match: basename + lowercase + strip-whitespace, then EXACT equality with BOTH
# sides non-empty. NOT substring — a recycled `foo-helper` must NOT match a contract `foo`, and an empty
# side must match nothing (either would authorize renicing the WRONG unprotected proc). CodeRabbit PR#259 #131.
comm_match() {  # $1=live_raw $2=want_raw → 0 iff same normalized non-empty command
  local a b
  a="$(basename "${1:-}" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  b="$(basename "${2:-}" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" = "$b" ]
}

# Moderate autonomous heal of a clear cpu runaway. Returns 0 acted/proposed, 1 skipped, 2 denied.
try_renice() {
  local pid="$1" comm="$2" pct="$3"
  if denied "$comm"; then
    echo "  🟠 cpu-runaway ${comm} (pid ${pid}, ${pct}%) — PROTECTED proc → seed+notify (never renice)"
    return 2
  fi
  # pid-recycle guard (round-5 #2, HARDENED per CodeRabbit PR#259 #131/#138): the contract can be up to
  # StartInterval (600s) stale, so this pid may have been recycled to a DIFFERENT process since the sample →
  # renicing it would hit the wrong proc, and the denied() check above ran against the STALE contract comm.
  # (#131) Require an EXACT normalized command match — NOT substring: a recycled `foo-helper` must NOT match
  # a contract `foo`, and an empty comm must match nothing. comm_match() enforces both-non-empty + equal;
  # anything else fails closed (skip). Then re-run denied() on the LIVE comm (a recycled pid could BE protected).
  local live_raw
  live_raw="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
  if ! comm_match "$live_raw" "$comm"; then
    echo "  ⏭  cpu-runaway pid ${pid}: live comm '${live_raw:-gone}' ≠ contract '${comm}' (recycled/gone/ambiguous since sample) → skip (no renice)"
    return 1
  fi
  if denied "$live_raw"; then
    echo "  🟠 cpu-runaway pid ${pid}: live comm '${live_raw}' is PROTECTED (recycle re-check) → seed+notify (never renice)"
    return 2
  fi
  # (#138) TOCTOU narrowing: bind a stable start-identity (kernel process start time) NOW; re-verify it
  # immediately before renice (below). Shell check-then-act can't be atomic, but this catches the pid
  # exiting/recycling between here and the action. Combined with the exact-comm match, the denylist re-check,
  # renice being fully REVERSIBLE (reverts.log), and the collector re-sampling every 600s (a real runaway
  # re-surfaces next cycle), fail-closed here is sound. Cannot bind an identity ⇒ skip (DENY-until-proven).
  local live_start
  live_start="$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ' || true)"
  if [ -z "$live_start" ]; then
    echo "  ⏭  cpu-runaway pid ${pid}: cannot bind start-identity (proc gone) → fail-closed skip (no renice)"
    return 1
  fi
  # sample the ORIGINAL niceness AFTER the identity is bound (per CodeRabbit PR#259 @157): reading `cur`
  # before binding live_start could pair a nice value from a since-recycled process with a different identity
  # → a wrong revert record / wrong -ge decision. The recheck_start below then validates identity stability
  # across this read up to the renice. `|| true`: under pipefail a dead pid fails the pipe → would abort under
  # set -e before the numeric guard; force success (empty) so the guard handles proc-gone gracefully.
  local cur; cur="$(ps -o nice= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
  if ! [[ "$cur" =~ ^-?[0-9]+$ ]]; then
    echo "  ⏭  cpu-runaway pid ${pid} gone / invalid nice ('${cur}') before action"; return 1
  fi
  # already at/below target priority → renicing DOWN needs root (BSD: non-root can only raise niceness);
  # renice to the same value is a no-op. Either way skip → the runaway becomes HITL residue (kill/quit=operator).
  if [ "$cur" -ge "$RENICE_TO" ]; then
    echo "  ⏭  cpu-runaway ${comm} (pid ${pid}) already deprioritized (nice=${cur} ≥ ${RENICE_TO}) — renice maxed → HITL"
    return 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  ✅ PROPOSE renice ${RENICE_TO} pid=${pid} comm=${comm} pct=${pct} (cur nice=${cur}) [dry-run]"
    return 0
  fi
  # re-verify the bound start-identity immediately before acting (TOCTOU close-out #138) — a pid recycled or
  # exited since the bind now shows a different / empty start time ⇒ fail-closed skip (never renice the wrong proc).
  local recheck_start
  recheck_start="$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ' || true)"
  if [ -z "$recheck_start" ] || [ "$recheck_start" != "$live_start" ]; then
    echo "  ⏭  cpu-runaway pid ${pid}: start-identity drift ('${live_start}' → '${recheck_start:-gone}') = pid recycled/exited before renice → fail-closed skip"
    return 1
  fi
  if renice "$RENICE_TO" -p "$pid" >/dev/null 2>&1; then
    printf '%s reverted-by: renice %s -p %s   # was comm=%s pct=%s\n' \
      "$(date -u +%FT%TZ)" "$cur" "$pid" "$comm" "$pct" >>"$STATE_DIR/reverts.log" 2>/dev/null || true
    echo "  ✅ AUTONOMOUS renice ${RENICE_TO} pid=${pid} comm=${comm} (was ${cur}; revert recorded)"
    log "AUTONOMOUS-RENICE pid=${pid} comm=${comm} nice ${cur}->${RENICE_TO} pct=${pct}"
    notify "Deprioritized runaway ${comm} (pid ${pid}, ${pct}% cpu). Reversible via reverts.log — nothing killed." "Moderate auto-heal"
    return 0
  fi
  echo "  ⏭  renice failed pid=${pid} (gone / needs privilege) → seeding instead"
  return 1
}

seed_and_notify() {  # $1 = multiline HITL residue
  local residue="$1" now last stamp="$STATE_DIR/last-responder-escalate"
  # `|| true`: a MISSING stamp (first-ever escalation) makes `cat` fail → under `set -o pipefail`
  # the pipe fails → the $() assignment aborts the script under `set -e`, silently skipping the seed
  # (a no-silent-drop bug in the no-silent-drop path). Force success, then the numeric guard runs.
  now="$(date +%s)"; last="$(cat "$stamp" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ "$last" =~ ^[0-9]+$ ]] || last=0   # guard against absent/corrupt/edited stamp crashing $(( )) under set -e
  if [ $((now - last)) -lt "$ESCALATE_THROTTLE_SEC" ]; then
    echo "  ⏳ HITL residue present but escalate throttled (<6h since last seed)"; log "escalate throttled"; return 0
  fi
  local seed; seed="$STATE_DIR/NEEDS-AGENT-$(date +%Y%m%dT%H%M%S).md"
  { echo "---"; echo "kind: system-health-agent-delegation-seed"; echo "created: $(date -u +%FT%TZ)";
    echo "source: system-health-responder"; echo "---"; echo
    echo "# System-health HITL residue — Moderate auto-heal cannot self-resolve these"; echo
    echo "An active session (preflight / morning-briefing / postflight) picks this up and either"
    echo "delegates a specialist OR surfaces to the operator. NONE of these are autonomous:"; echo
    printf '%b\n' "$residue"
    echo "Contract: \`$CONTRACT\` · drill-down: \`jq '.system' \"$CONTRACT\"\`"
  } >"$seed" 2>/dev/null || true
  printf '%s' "$now" >"$stamp" 2>/dev/null || true
  echo "  📨 SEED written → $seed (HITL residue queued for an active session = Taxis entry)"
  log "SEED $seed"
  notify "System-health HITL residue queued (security/malware/etc). Nothing auto-changed — review NEEDS-AGENT seed." "HITL residue"
}

main() {
  [ -f "$CONTRACT" ] || { echo "[responder] no contract at $CONTRACT — part-1 collector not run yet"; log "no-contract"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "[responder] jq required"; return 2; }
  acquire_lock || { echo "[responder] another responder is engaged (lock held) — standing down"; log "lock-held stand-down"; return 1; }
  trap release_lock EXIT

  local overall; overall="$(jq -r '.system.status // "unknown"' "$CONTRACT" 2>/dev/null)"
  # burn_down is a TOP-LEVEL leading indicator (NOT a .system.branches leaf → it does NOT feed .system.status),
  # so it must be read + gated independently, else a burn_down warn/crit while branches are ok is silently ignored.
  local bd bd_trend bd_days bd_drain
  bd="$(jq -r '.burn_down.status // "unknown"' "$CONTRACT" 2>/dev/null)"
  bd_trend="$(jq -r '.burn_down.trend // "?"' "$CONTRACT" 2>/dev/null)"
  bd_days="$(jq -r '.burn_down.days_to_threshold // "?"' "$CONTRACT" 2>/dev/null)"
  bd_drain="$(jq -r '.burn_down.drain_gb_per_hr // "?"' "$CONTRACT" 2>/dev/null)"
  echo "System-health responder  [$([ "$DRY_RUN" -eq 1 ] && echo DRY-RUN || echo ENGAGE)]  contract.status=${overall}  burn_down=${bd}"
  if [ "$overall" = "ok" ] && [ "$bd" != "warn" ] && [ "$bd" != "crit" ]; then
    echo "  ✅ all classes ok — nothing to do"; log "no-op overall=ok burn_down=${bd}"; return 0
  fi

  # ── Eisenhower-ranked disposition (deterministic) ─────────────────────────
  local residue="" acted=0
  # cpu runaway → MODERATE autonomous (Q1 urgent+important)
  local cs; cs="$(jq -r '.system.branches.cpu.leaves.top_consumer.status // "ok"' "$CONTRACT" 2>/dev/null)"
  if [ "$cs" != "ok" ]; then
    local pid comm pct
    pid="$(jq -r '.system.branches.cpu.leaves.top_consumer.pid // empty' "$CONTRACT" 2>/dev/null)"
    comm="$(jq -r '.system.branches.cpu.leaves.top_consumer.comm // "?"' "$CONTRACT" 2>/dev/null)"
    pct="$(jq -r '.system.branches.cpu.leaves.top_consumer.pct // "?"' "$CONTRACT" 2>/dev/null)"
    if [ -n "$pid" ]; then
      if try_renice "$pid" "$comm" "$pct"; then acted=1
      else residue="${residue}- 🟠 cpu-runaway ${comm} (pid ${pid}, ${pct}%): protected/failed → operator judgment (kill/quit = HITL).\n"; fi
    else
      # runaway flagged but no pid in contract → still MUST surface (no-silent-drop / Taxis)
      residue="${residue}- 🟠 cpu=${cs}: runaway flagged but no pid in contract (comm=${comm}, ${pct}%) → operator review (no-silent-drop).\n"
    fi
  fi
  # cpu BRANCH-level load saturation (round-6 F1): the block above acts on the single top_consumer, but a crit
  # driven by SUSTAINED SYSTEM LOAD (root_fail=load1/load5 — no single runaway to renice) was previously read
  # by NOTHING → silently dropped (guardian.log showed `system=crit cpu=crit` surfacing zero residue). Surface
  # it as HITL residue: load saturation is NOT auto-healable (no single proc to renice; reducing load = operator
  # closing apps). Skip when root_fail IS the top_consumer (already handled above → no double-report).
  local cpu_br cpu_rf; cpu_br="$(jq -r '.system.branches.cpu.status // "ok"' "$CONTRACT" 2>/dev/null)"
  cpu_rf="$(jq -r '.system.branches.cpu.root_fail // ""' "$CONTRACT" 2>/dev/null)"
  if [ "$cpu_br" != "ok" ] && [ "$cpu_rf" != "top_consumer" ]; then
    local l1 l5 nc
    l1="$(jq -r '.system.branches.cpu.leaves.load1.value // "?"' "$CONTRACT" 2>/dev/null)"
    l5="$(jq -r '.system.branches.cpu.leaves.load1.load5 // "?"' "$CONTRACT" 2>/dev/null)"
    nc="$(jq -r '.system.branches.cpu.leaves.load1.ncpu // "?"' "$CONTRACT" 2>/dev/null)"
    residue="${residue}- 🟠 cpu=${cpu_br} load-driven (root_fail=${cpu_rf}, load1=${l1} / load5=${l5} over ${nc} cores): sustained saturation, no single runaway to renice → operator review (reduce load / close apps = HITL).\n"
  fi
  # disk → DELEGATED to disk-health-guardian (no dup)
  local ds; ds="$(jq -r '.system.branches.disk.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$ds" != "ok" ] && echo "  ↪  disk=${ds} → delegated to disk-health-guardian (it owns disk; no action here)"
  # burn_down (round-3) → observe-only LEADING indicator: forecast NEVER auto-deletes; seed so a session/operator
  # frees space EARLY, before the drain hits the floor (the 2026-07-14 lesson). The disk BRANCH (above) still owns
  # actual reclaim — this is the predictor, not the effector (sensor ≠ effector).
  if [ "$bd" = "warn" ] || [ "$bd" = "crit" ]; then
    residue="${residue}- 🟠 disk burn-down=${bd} (trend=${bd_trend}, ~${bd_drain} GB/hr, ~${bd_days}d to threshold): leading indicator — prune caches / reclaim EARLY (session/operator) before the floor.\n"
  fi
  # security → HITL (Q2 important, not autonomous)
  local secs; secs="$(jq -r '.system.branches.security.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$secs" != "ok" ] && residue="${residue}- 🟠 security=${secs} ($(jq -r '.system.branches.security.root_fail // "?"' "$CONTRACT")): re-enable firewall/SIP/gatekeeper = operator (System Settings).\n"
  # malware → HITL
  local ms; ms="$(jq -r '.system.branches.malware.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$ms" != "ok" ] && residue="${residue}- 🟠 malware=${ms} ($(jq -r '.system.branches.malware.root_fail // "?"' "$CONTRACT")): XProtect update / quarantine = operator (OS security).\n"
  # memory / process / network warn → report + HITL (kill is destructive)
  local mem; mem="$(jq -r '.system.branches.memory.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$mem" != "ok" ] && residue="${residue}- 🟠 memory=${mem}: freeing memory means killing a proc (destructive) = operator judgment.\n"
  local ps_; ps_="$(jq -r '.system.branches.process.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$ps_" != "ok" ] && residue="${residue}- 🟠 process=${ps_}: zombie/runaway-count anomaly → operator review (kill = HITL).\n"
  local net; net="$(jq -r '.system.branches.network.status // "ok"' "$CONTRACT" 2>/dev/null)"
  # round-6 F3: the collector emits "informational" (listeners collected, NOT thresholded) — treat it as
  # no-residue explicitly (it is NOT a measured "ok", but it is also NOT a fault to surface).
  [ "$net" != "ok" ] && [ "$net" != "informational" ] && residue="${residue}- 🟠 network=${net}: unexpected listener → operator review (never auto-close).\n"

  # ── agentic-tools (EKO-90-ext v1.2.0): cache-producer + claude-runtime ─────────
  # The 2026-07-14 lesson: the disk-guardian cleaned caches but could not beat a LIVE producer
  # (`uvx …@latest` MCP churn). This branch adds the producer-aware response: Tier-A autonomous
  # `uv cache prune` (LOW · non-destructive · Moderate-gated), Tier-B SEED a containment delegation
  # to an active agent (the responder NEVER auto-disables/removes — the secret-safe contract can't
  # name the plugin, and disable/remove is above Moderate → it stays HITL/armed-agent, per the ADR).
  local ats; ats="$(jq -r '.system.branches.agentic_tools.status // "ok"' "$CONTRACT" 2>/dev/null)"
  if [ "$ats" != "ok" ]; then
    local prod_st uvobj uvx claude_h
    prod_st="$(jq -r '.system.branches.agentic_tools.leaves.cache_producer.status // "ok"' "$CONTRACT" 2>/dev/null)"
    uvobj="$(jq -r '.system.branches.agentic_tools.leaves.cache_producer.uv_archive_objects // 0' "$CONTRACT" 2>/dev/null)"
    uvx="$(jq -r '.system.branches.agentic_tools.leaves.cache_producer.uvx_latest_procs // 0' "$CONTRACT" 2>/dev/null)"
    claude_h="$(jq -r '.system.branches.agentic_tools.leaves.claude_runtime.health // "?"' "$CONTRACT" 2>/dev/null)"
    if [ "$prod_st" != "ok" ]; then
      # Tier-A — LOW-stakes durable maintenance: `uv cache prune` (non-destructive; keeps tool installs).
      # Moderate scope → rides the SAME --engage+SHR_READY gate as renice (autonomous only when READY proven).
      local ofc; ofc="$(dirname "$0")/offender-containment.sh"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "  ✅ PROPOSE agentic-tools: cache-producer=${prod_st} (uv_objs=${uvobj}, uvx@latest=${uvx}) → uv cache prune (non-destructive) [dry-run]"
      elif [ -x "$ofc" ]; then
        echo "  🧹 agentic-tools: producer pressure → uv cache prune (Moderate autonomous, non-destructive)"
        "$ofc" --prune 2>>"$LOG" | sed 's/^/    /' || true
        log "AGENTIC-PRUNE producer=${prod_st} uvobj=${uvobj} uvx=${uvx}"
        acted=1
      fi
      # Tier-B — ROOT-fix (operator ADR; DISABLE tier ARMED 2026-07-14 via operator ratification). A LIVE
      # `uvx …@latest` producer is the ROOT (prune treats the symptom). In ENGAGE mode — which only holds
      # when an ACTIVE reflex proved SHR_READY (launchd NEVER sets it) — the responder now invokes the
      # containment executor, which DISABLES (reversible) registry-VETTED, currently-present offenders.
      # Uninstall stays a further explicit gate (OFC_ALLOW_UNINSTALL) — NOT auto-armed here (reversible-first).
      # Un-vetted / un-present producers still fall through to the HITL seed below (no-silent-drop / Taxis).
      if [ "$uvx" -gt 0 ] 2>/dev/null; then
        if [ "$DRY_RUN" -eq 0 ] && [ -x "$ofc" ]; then
          echo "  🔌 agentic-tools: live producer → offender-containment --engage (disable registry-vetted offenders; uninstall NOT auto-armed)"
          OFC_ARM=1 OFC_READY=1 "$ofc" --engage 2>>"$LOG" | sed 's/^/    /' || true
          log "OFFENDER-CONTAINMENT-ENGAGE uvx=${uvx} (disable-tier armed; uninstall not armed)"
          acted=1
        fi
        residue="${residue}- 🔴 agentic-tools: ${uvx} live \`uvx …@latest\` producer(s) re-inflating uv cache (ROOT; uv has no auto-GC). $([ "$DRY_RUN" -eq 0 ] && echo 'Containment ENGAGED on registry-vetted offenders (disable, reversible).' || echo 'Durable fix per operator ADR = disable/remove the offending no-source-fix plugin.') Un-vetted producers → \`bin/offender-containment.sh\` (registry + arm). Prune is a stopgap.\n"
      fi
    fi
    # claude runtime unhealthy → HITL (fixing = the operator's in-session /doctor; the collector's probe is read-only)
    if [ "$claude_h" != "healthy" ] && [ "$claude_h" != "?" ]; then
      residue="${residue}- 🟠 agentic-tools: claude runtime health=${claude_h} (from \`claude doctor\`) → run \`/doctor\` in-session to fix (operator).\n"
    fi
  fi

  if [ -n "$residue" ]; then
    echo "  HITL residue (auto-heal Moderate does not touch these):"
    printf '%b' "$residue" | sed 's/^/    /'
    seed_and_notify "$residue"
  fi
  log "cycle done: overall=${overall} acted=${acted} residue=$([ -n "$residue" ] && echo yes || echo no)"
  return 0
}

case "${1:-}" in
  --help|-h) usage; exit 0;;
  --comm-match) comm_match "${2:-}" "${3:-}" && { echo match; exit 0; } || { echo nomatch; exit 1; };;
  --denied) denied "${2:-}" && { echo denied; exit 0; } || { echo allowed; exit 1; };;
  --engage)
    # Fail-safe DENY-until-proven: the autonomous renice fires ONLY when the calling reflex has
    # proven the standing-autonomy READY predicate and signalled it via SHR_READY=1. A stray
    # --engage (launchd misconfig, curious operator) thus degrades to dry-run instead of auto-acting.
    if [ "${SHR_READY:-0}" = "1" ]; then DRY_RUN=0
    else DRY_RUN=1
      echo "[responder] --engage requires SHR_READY=1 (standing-autonomy READY proven by caller) → DRY-RUN (fail-safe)" >&2
    fi
    ;;
  --dry-run|"") DRY_RUN=1;;
  *) echo "[responder] unknown arg '${1}'"; usage; exit 2;;
esac
main
