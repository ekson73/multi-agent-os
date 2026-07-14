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

PROC_DENYLIST=(
  kernel_task launchd windowserver loginwindow coreaudiod configd hidd powerd
  bluetoothd cfprefsd mds mds_stores mdworker syslogd distnoted securityd trustd
  1password op openclaw omniroute claude
)

usage() {
  cat <<'EOF'
health-respond.sh — system-health responder (EKO-90 part-2)
  (default)     DRY-RUN: read contract, rank, PROPOSE actions, seed HITL residue. Acts on nothing.
  --engage      Perform the Moderate autonomous renice of a clear cpu runaway (reversible-by-record).
  --help        This help.
Env: SHR_CONTRACT SHR_STATE_DIR SHR_LOG SHR_RENICE_TO SHR_LOCK_STALE_SEC SHR_ESCALATE_THROTTLE_SEC
EOF
}

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG" 2>/dev/null || true; }
notify() { [ "$NOTIFY" -eq 1 ] || return 0; osascript -e "display notification \"$1\" with title \"System-Health Responder\" subtitle \"$2\"" 2>/dev/null || true; }

acquire_lock() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  if mkdir "$LOCK" 2>/dev/null; then printf '%s' "$$" >"$LOCK/pid" 2>/dev/null || true; return 0; fi
  local age; age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$age" -gt "$LOCK_STALE_SEC" ]; then
    rm -rf "$LOCK" 2>/dev/null || true
    if mkdir "$LOCK" 2>/dev/null; then printf '%s' "$$" >"$LOCK/pid" 2>/dev/null || true
      log "engage-lock: stole stale lock (age ${age}s)"; return 0; fi
  fi
  return 1
}
release_lock() { rm -rf "$LOCK" 2>/dev/null || true; }

denied() {  # $1=comm → 0 if protected
  local c; c="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  local d; for d in "${PROC_DENYLIST[@]}"; do
    case "$c" in *"$d"*) return 0;; esac
  done
  return 1
}

# Moderate autonomous heal of a clear cpu runaway. Returns 0 acted/proposed, 1 skipped, 2 denied.
try_renice() {
  local pid="$1" comm="$2" pct="$3"
  if denied "$comm"; then
    echo "  🟠 cpu-runaway ${comm} (pid ${pid}, ${pct}%) — PROTECTED proc → seed+notify (never renice)"
    return 2
  fi
  local cur; cur="$(ps -o nice= -p "$pid" 2>/dev/null | tr -d ' ')"
  [ -n "$cur" ] || { echo "  ⏭  cpu-runaway pid ${pid} gone before action"; return 1; }
  # already at/below target priority → renicing DOWN needs root (BSD: non-root can only raise niceness);
  # renice to the same value is a no-op. Either way skip → the runaway becomes HITL residue (kill/quit=operator).
  if [ "$cur" -ge "$RENICE_TO" ] 2>/dev/null; then
    echo "  ⏭  cpu-runaway ${comm} (pid ${pid}) already deprioritized (nice=${cur} ≥ ${RENICE_TO}) — renice maxed → HITL"
    return 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  ✅ PROPOSE renice ${RENICE_TO} pid=${pid} comm=${comm} pct=${pct} (cur nice=${cur}) [dry-run]"
    return 0
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
  now="$(date +%s)"; last="$(cat "$stamp" 2>/dev/null || echo 0)"
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
  echo "System-health responder  [$([ "$DRY_RUN" -eq 1 ] && echo DRY-RUN || echo ENGAGE)]  contract.status=${overall}"
  if [ "$overall" = "ok" ]; then
    echo "  ✅ all classes ok — nothing to do"; log "no-op overall=ok"; return 0
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
    fi
  fi
  # disk → DELEGATED to disk-health-guardian (no dup)
  local ds; ds="$(jq -r '.system.branches.disk.status // "ok"' "$CONTRACT" 2>/dev/null)"
  [ "$ds" != "ok" ] && echo "  ↪  disk=${ds} → delegated to disk-health-guardian (it owns disk; no action here)"
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
  [ "$net" != "ok" ] && residue="${residue}- 🟠 network=${net}: unexpected listener → operator review (never auto-close).\n"

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
  --engage)  DRY_RUN=0;;
  --dry-run|"") DRY_RUN=1;;
  *) echo "[responder] unknown arg '${1}'"; usage; exit 2;;
esac
main
