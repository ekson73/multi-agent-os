#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# disk-health-guardian.sh — existing disk effector, monitor by default.
# Imported from the operator's 2026-10-13 backup; burn-rate/reporting retained.
# Cleanup requires --cleanup-uv AND DHG_APPROVED_CACHE matching the exact UV cache.
# No other cache, Tier-2 housekeeping, raw removal, or full UV clean is authorized.
# --reset-futile-uv requires the same approval binding after explicit recovery review.
# Usage: disk-health-guardian.sh [--dry-run|--cleanup-uv|--reset-futile-uv|--escalate-now]
# Log:   ~/.local/state/disk-health-guardian/guardian.log
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

DRY_RUN=1
REPORTING=1
RESET_FUTILE=0
ACTION_DEFERRED=0
case "${1:-}" in
  ''|--escalate-now) ;;
  --dry-run) REPORTING=0 ;;
  --cleanup-uv) DRY_RUN=0 ;;
  --reset-futile-uv) RESET_FUTILE=1 ;;
  *) printf 'Unknown mode: %s\n' "$1" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo 'Unexpected arguments' >&2; exit 2; }

DATA_VOL="/System/Volumes/Data"
STATE_DIR="$HOME/.local/state/disk-health-guardian"
LOG="$STATE_DIR/guardian.log"
umask 077
mkdir -p "$STATE_DIR"
# Cleanup/reset serialize the whole action; monitoring never waits on this lock.
ACTION_LOCK="$STATE_DIR/action.lock"
if [ "$DRY_RUN" -eq 0 ] || [ "$RESET_FUTILE" -eq 1 ]; then
  if ! mkdir "$ACTION_LOCK" 2>/dev/null; then
    echo 'DEFER action-lock held; inspect owner before manual recovery' >&2
    exit 2
  fi
  # Install cleanup immediately: owner metadata can fail under ENOSPC.
  trap 'rmdir "$ACTION_LOCK/$$" "$ACTION_LOCK" 2>/dev/null || true' EXIT
  mkdir "$ACTION_LOCK/$$"
  # Do not release exclusion while an interrupted child might still be active.
  # Monitoring stays available; operator reconciles owner/children before recovery.
  trap 'trap - EXIT; exit 2' HUP INT TERM
fi
GC_TIMEOUT=900
TIMEOUT_BIN="${DHG_TIMEOUT_BIN:-}"
if [ "${DHG_TIMEOUT_BIN+x}" != x ]; then
  for _c in /opt/homebrew/bin/timeout /opt/homebrew/bin/gtimeout /usr/local/bin/timeout /usr/local/bin/gtimeout /usr/bin/timeout; do
    [ -x "$_c" ] && { TIMEOUT_BIN="$_c"; break; }
  done
fi
case "$TIMEOUT_BIN" in /*) [ -x "$TIMEOUT_BIN" ] || TIMEOUT_BIN="" ;; *) TIMEOUT_BIN="" ;; esac

# ── Thresholds (free-GB based — the meaningful metric on a large disk. % is
#    misleading: 88% of a 926G disk = 111G free = healthy; reclaiming there just
#    thrashes caches. Trigger only on genuinely-low ABSOLUTE free space.) ───────
# Env-overridable (DHG_* ) for testing + tuning without editing the script.
LOW_FREE_GB="${DHG_LOW_FREE_GB:-15}"     # Tier-1: reclaim allowlist caches when free < this
TIER2_FREE_GB="${DHG_TIER2_FREE_GB:-10}" # Tier-2: delegate the macOS-specialist if STILL below
CRIT_FREE_GB="${DHG_CRIT_FREE_GB:-8}"    # escalate (notify+suggestions+agent-seed) if STILL below
# Tier-2 remains disabled: its broader deletion scope has no approval.

# Historical candidates retained for monitor reporting only; cleanup is UV-only.
ALLOWLIST=(
  "$HOME/.npm/_cacache"                     # npm content-addressable cache
  "$HOME/.npm/_logs"                        # npm logs
  "$HOME/Library/Caches/Homebrew/downloads" # brew bottle downloads
  "$HOME/Library/Caches/Homebrew/api"       # brew api cache
  "$HOME/.cache/pip"
  "$HOME/Library/Caches/pip"
  "$HOME/.cache/pnpm"
  "$HOME/Library/Caches/pnpm"
  "$HOME/.cache/yarn"
  "$HOME/Library/Caches/Yarn"
  "$HOME/.cache/uv"
  "$HOME/.cache/go-build"
  "$HOME/Library/Caches/go-build"
  "$HOME/.cache/ms-playwright"
  "$HOME/.cache/puppeteer"
  # Codex CLI marketplace staging — orphaned `marketplace-upgrade-<rand>` transaction
  # dirs left by interrupted/completed plugin-marketplace upgrades. Pure transient
  # staging (git clones, re-fetchable from origin). Empirical 2026-07-22: 33 GB of
  # 39 orphans from a single day filled the disk to 0 bytes while this guardian ran
  # every 10 min and could not see them (outside ALLOWED_ROOTS). Same class as the
  # [C15] marketplace-hygiene anti-pattern, Codex side.
  "$HOME/.codex/.tmp/marketplaces/.staging"
)

# ── Denylist roots (explicit — gate 4; belt-and-suspenders vs gate 3) ────────
DENYLIST=(
  "$HOME/.openclaw" "$HOME/openclaw" "$HOME/.omniroute"
  "$HOME/.claude" "$HOME/Documents" "$HOME/Desktop"
  "$HOME/.ssh" "$HOME/.config" "$HOME/.gnupg"
  "$HOME/Pictures" "$HOME/Movies" "$HOME/Music"
  "$HOME/Library/Mobile Documents" "$HOME/.Trash"
)

# ── Allowed cache roots (gate 3 — the strongest guard) ───────────────────────
ALLOWED_ROOTS=(
  "$HOME/.npm/"
  "$HOME/.cache/"
  "$HOME/Library/Caches/"
  # NARROW by design: the `.tmp/` subtree ONLY, never "$HOME/.codex/" wholesale —
  # sessions/, memories_1.sqlite, goals_1.sqlite, config.toml MUST stay unreachable.
  "$HOME/.codex/.tmp/"
)

ts()  { date +'%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s  %s\n' "$(ts)" "$*" >>"$LOG" 2>/dev/null || true; }  # ENOSPC must not abort the guardian at 0 bytes

# rotate log if it grows past ~4MB (keep last 2000 lines)
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG" 2>/dev/null || echo 0)" -gt 4194304 ]; then
  tail -n 2000 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

# df snapshot → sets CAP_PCT (capacity %) + AVAIL_GB (GiB free)
snapshot() {
  local line avail_kb
  line="$(df -k "$DATA_VOL" 2>/dev/null | awk 'NR==2')" || line=""
  avail_kb="$(printf '%s' "$line" | awk '{print $4}')"
  CAP_PCT="$(printf '%s' "$line" | awk '{gsub(/%/,"",$5); print $5}')"
  case "$avail_kb:$CAP_PCT" in
    *[!0-9:]*|:*|*:) log 'UNKNOWN df snapshot; no cleanup or healthy resolution'; exit 2 ;;
  esac
  AVAIL_GB=$(( 10#$avail_kb / 1024 / 1024 ))
}

# Candidate path check only; authorization and exact canonical binding are separate.
is_safe_target() {
  local t="$1" rp root deny
  [ -d "$t" ] || return 1                      # must exist + be a dir
  [ -L "$t" ] && return 1                       # gate: no symlink traversal
  rp="$(cd "$t" 2>/dev/null && pwd -P)" || return 1
  # gate 4: reject if under any denylist root
  for deny in "${DENYLIST[@]}"; do
    case "$rp/" in "$deny"/*|"$deny/") return 1 ;; esac
  done
  # gate 3: MUST begin with an allowed cache root
  for root in "${ALLOWED_ROOTS[@]}"; do
    case "$rp/" in "$root"*) return 0 ;; esac
  done
  return 1
}

# Native cleanup is the ONLY removal path. Preconditions are fail-closed.
futile_slug() { printf '%s' "$1" | tr '/ ' '__'; }
approved_uv() {
  local t="$HOME/.cache/uv" rp
  [ "${DHG_APPROVED_CACHE:-}" = "$t" ] || { log 'DEFER approval-required'; return 1; }
  is_safe_target "$t" || { log 'DEFER unsafe-cache'; return 1; }
  rp="$(cd "$t" && pwd -P)"
  [ "$rp" = "$t" ] || { log 'DEFER cache-symlink'; return 1; }
  [ "${UV_CACHE_DIR:-$t}" = "$t" ] && [ -z "${UV_NO_CACHE:-}" ] || { log 'DEFER cache-override'; return 1; }
}
native_gc() {
  local t="$1" uv="$HOME/.local/bin/uv" version binding rc=0 count=0 f
  approved_uv || return 2
  [ -n "$TIMEOUT_BIN" ] || { log 'DEFER timeout-missing'; return 2; }
  [ -x "$uv" ] || { log 'DEFER native-missing'; return 2; }
  version="$("$TIMEOUT_BIN" --kill-after=5s 10s "$uv" --version 2>>"$LOG")" || { log 'DEFER native-version'; return 2; }
  # 0.5.9 explicitly lacks safe concurrent cache modification. Only the reviewed
  # 0.13.0 contract is accepted; a newer version is not assumed compatible.
  case "$version" in 'uv 0.13.0'|'uv 0.13.0 ('*) ;; *) log 'DEFER unsupported-version'; return 2 ;; esac
  # Operator precondition, NOT a machine proof: producers are externally quiesced
  # for this invocation/cache. Never set/infer/persist this from daemon or pgrep.
  [ "${DHG_UV_PRODUCERS_QUIESCENT:-}" = 1 ] || { log 'DEFER producer-contract-required'; return 2; }
  binding="$("$TIMEOUT_BIN" --kill-after=5s 10s "$uv" --no-config --offline --cache-dir "$t" cache dir 2>>"$LOG")" || { log 'DEFER cache-binding'; return 2; }
  [ "$binding" = "$t" ] || { log 'DEFER cache-binding'; return 2; }
  # Additional veto only; absence never proves producer quiescence.
  pgrep -f '(^|/)(uv|uvx)([[:space:]]|$)' >/dev/null 2>&1 || rc=$?
  case "$rc" in 0) log 'DEFER native-busy'; return 2 ;; 1) ;; *) log 'DEFER busy-UNKNOWN'; return 2 ;; esac
  f="$STATE_DIR/futile/$(futile_slug "$t")"
  if [ -e "$f" ]; then
    count="$(cat "$f")" || { log 'DEFER attempt-state-unreadable'; return 2; }
    case "$count" in ''|*[!0-9]*|????*) log 'DEFER attempt-state-invalid'; return 2 ;; esac
  fi
  [ "$count" -lt 3 ] || { log 'DEFER attempt-cap; explicit recovery/reset required'; return 2; }
  # Reserve before executing: failed/interrupted attempts cannot evade the cap.
  mkdir -p "$STATE_DIR/futile" && printf '%s\n' "$((10#$count + 1))" > "$f" || { log 'DEFER attempt-state-write'; return 2; }
  rc=0
  "$TIMEOUT_BIN" --kill-after=5s "${GC_TIMEOUT}s" "$uv" --no-config --offline --cache-dir "$t" cache prune >/dev/null 2>>"$LOG" || rc=$?
  [ "$rc" -eq 0 ] || { log "DEFER native-exit=$rc (failure/timeout; no fallback)"; return 2; }
  return 0
}

if [ "$RESET_FUTILE" -eq 1 ]; then
  approved_uv || exit 2
  mkdir -p "$STATE_DIR/futile"
  printf '0\n' > "$STATE_DIR/futile/$(futile_slug "$HOME/.cache/uv")"
  log 'RESET explicit approved UV recovery; no cleanup performed'
  exit 0
fi
# An explicit request must reject an unsafe/missing cache even when disk is healthy.
if [ "$DRY_RUN" -eq 0 ]; then approved_uv || exit 2; fi

reclaim() {
  local t before after
  for t in "${ALLOWLIST[@]}"; do
    snapshot
    if [ "$AVAIL_GB" -ge "$LOW_FREE_GB" ]; then
      log "STOP-EARLY healthy again (free=${AVAIL_GB}G >= ${LOW_FREE_GB}G, cap=${CAP_PCT}%) — remaining allowlist skipped"
      break
    fi
    if ! is_safe_target "$t"; then
      if [ "$DRY_RUN" -eq 0 ] && [ "$t" = "$HOME/.cache/uv" ]; then
        log 'DEFER unsafe-cache'; ACTION_DEFERRED=2
      fi
      continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      log "DRY-RUN candidate $t (not authorized; size not measured)"
      continue
    fi
    if [ "$t" != "$HOME/.cache/uv" ]; then
      log "DEFER unapproved-target: $t"
      continue
    fi
    before="$AVAIL_GB"
    if ! native_gc "$t"; then ACTION_DEFERRED=2; continue; fi
    snapshot; after="$AVAIL_GB"
    log "NATIVE-GC $t via its own collector (free ${before}G -> ${after}G)"
    if [ "$after" -gt "$before" ]; then
      log "OBSERVED_NET_CHANGE +$((after - before))G after UV prune; attribution unverified (free ${before}G -> ${after}G)"
    else
      log "OBSERVED_NET_CHANGE $((after - before))G after UV prune; attribution unverified (free ${before}G -> ${after}G); attempt retained"
    fi
  done
}

# ── Home census — WHAT is big, including what we are NOT allowed to touch ─────
# /** [decision] the diagnostic probe scans ALL of $HOME (depth 1), not just ~/Library
#  *  @context 2026-07-22 incident: ~/.cache held ~762 GiB while this probe was
#  *           hardcoded to ~/Library (224 G). The single largest consumer on the
#  *           machine appeared in NO report — not SUGGESTIONS.md, not the agent
#  *           seed, not the notification. The guardian failed to ACT (allowlist-
#  *           bound BY DESIGN, acceptable) and also failed to REPORT (probe aimed
#  *           at the wrong directory, NOT acceptable). The second failure is the
#  *           serious one: it denies the human the chance to act in its place.
#  *  @reason ACTION may stay allowlist-bound; DETECTION must not be. Same split as
#  *          system-health-guardian (act-free collector) and openclaw's
#  *          "Detecção ≠ Ação". A guardian that cannot delete X is still useful if
#  *          it can NAME X; one that cannot see X is useless twice over.
#  *  @impact read-only. Deletes nothing, widens nothing deletable. Only makes the
#  *          invisible visible. Every future cache class is born reportable. */
CENSUS_TTL="${DHG_CENSUS_TTL:-43200}"      # 12h — consumer shape does not change hourly
# MEASURED 2026-07-22, not guessed: `du -d1` on ~/.cache ALONE exceeded 10 min here, so a
# 600s budget on the whole $HOME was guaranteed to be killed → publish nothing (see the
# buffering note below: a killed du yields zero, not a partial). 30 min at background QoS.
CENSUS_BUDGET="${DHG_CENSUS_BUDGET:-1800}" # hard watchdog on the DETACHED scan, not the cycle
# run the scan at LOW priority — it is a bulk metadata read competing with real work.
# macOS `taskpolicy -b` = background QoS band (throttled I/O); `nice` alone only helps CPU.
NICE_BIN=""; for _c in /usr/sbin/taskpolicy /usr/bin/taskpolicy /usr/bin/nice; do [ -x "$_c" ] && { NICE_BIN="$_c"; break; }; done
case "$NICE_BIN" in */taskpolicy) NICE_ARGS=(-b) ;; */nice) NICE_ARGS=(-n 19) ;; *) NICE_ARGS=() ;; esac
CENSUS_LOCK_TTL=3600                       # a lock older than this is stale → allow a respawn

# ASYNC BY MEASUREMENT, not by preference:
#   A full-$HOME `du` takes minutes here. Bounding it inline yields NOTHING, not a
#   partial — `du` block-buffers its stdio, and a SIGTERM'd process never flushes, so
#   the buffered lines die with it. MEASURED 2026-07-22: a 6-second-budgeted run
#   returned ZERO bytes, not a truncated ranking. So we never race it: detach the scan,
#   let it complete, and serve the PREVIOUS census meanwhile. Stale-but-real beats empty,
#   and the cost leaves the 10-minute launchd cycle's critical path entirely.
home_census() {
  local cache="$STATE_DIR/census.txt" lock="$STATE_DIR/census.lock" now age lockage
  now=$(date +%s)
  if [ "$AVAIL_GB" -le "$CRIT_FREE_GB" ] || [ -z "$TIMEOUT_BIN" ]; then
    log 'CENSUS DEFER critical-margin or timeout-missing; cached evidence only'
    [ -f "$cache" ] && { cat "$cache"; return 0; }
    return 1
  fi

  if [ -f "$cache" ]; then
    age=$(( now - $(stat -f %m "$cache" 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$CENSUS_TTL" ]; then cat "$cache"; return 0; fi
  fi

  # stale or absent → kick off a detached refresh (single-flight via lockfile)
  lockage=$(( now - $(stat -f %m "$lock" 2>/dev/null || echo 0) ))
  if [ ! -e "$lock" ] || [ "$lockage" -gt "$CENSUS_LOCK_TTL" ]; then
    : >"$lock" 2>/dev/null || true
    (
      # tmp+mv = the reader never sees a half-written census
      if [ -n "$TIMEOUT_BIN" ]; then
        "$TIMEOUT_BIN" "$CENSUS_BUDGET" ${NICE_BIN:+"$NICE_BIN" "${NICE_ARGS[@]}"} du -m -x -d1 "$HOME" 2>/dev/null
      else
        ${NICE_BIN:+"$NICE_BIN" "${NICE_ARGS[@]}"} du -m -x -d1 "$HOME" 2>/dev/null
      fi | sort -rn | head -14 \
         | awk -v h="$HOME" '{gb=$1/1024; $1=""; sub(/^ /,""); p=$0;
                              if (p==h) next;                    # drop the $HOME total row
                              sub("^"h"/","~/",p); printf "  - %7.1fG  %s\n", gb, p}' \
         >"$cache.tmp" 2>/dev/null
      [ -s "$cache.tmp" ] && mv -f "$cache.tmp" "$cache" || rm -f "$cache.tmp"
      rm -f "$lock"
    ) >/dev/null 2>&1 &
    log "CENSUS refresh detached (pid $!) — serving previous census this cycle"
  fi

  # serve whatever we have (annotated as stale by the caller); nothing yet → signal 1
  [ -f "$cache" ] && { cat "$cache"; return 0; }
  return 1
}

# write actionable suggestions + a full-$HOME consumer census (bounded, cached)
write_suggestions() {
  local f="$STATE_DIR/SUGGESTIONS.md" probe=""
  # `|| true` is load-bearing: home_census returns 1 when it can measure nothing, and
  # under `set -euo pipefail` that would abort escalate() before the agent-seed lands.
  probe="$(home_census || true)"
  {
    echo "# Disk Health — Suggestions ($(ts))"
    echo ""
    echo "Free: ${AVAIL_GB}G (cap ${CAP_PCT}%). See guardian.log for actual outcomes."
    echo "Monitor is the default; deletion requires separate reviewed authorization. Tier-2 is disabled."
    echo "The residue below needs a HUMAN/AGENT judgment call:"
    echo ""
    echo "## Likely big consumers (review + reclaim manually or approve deeper cleanup)"
    echo "- 🗑️  Empty Trash: \`osascript -e 'tell app \"Finder\" to empty trash'\` (restorable = user choice)"
    echo "- 📦  Old Downloads: \`ls -laShr ~/Downloads | tail -20\` → delete what you don't need"
    echo "- 🐳  Docker.raw / VMs: Parallels/UTM \`.pvm\`/\`.utm\` + \`~/Library/Containers/com.docker.docker\` (Docker.raw can be 10s of GB)"
    echo "- 🤖  Ollama models: \`du -sh ~/.ollama/models 2>/dev/null\` → \`ollama rm <model>\` for unused"
    echo "- 🧱  node_modules bloat: \`find ~/Projects -type d -name node_modules -prune 2>/dev/null | head\` (regenerable via install)"
    echo "- 🎞️  Large media: \`~/Movies\`, \`~/Music\` (user data — never auto-touched)"
    if [ -n "$probe" ]; then
      echo ""
      echo "## Top consumers in \$HOME (depth 1 — MEASURED, includes what I may not touch)"
      echo "_measured: $(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$STATE_DIR/census.txt" 2>/dev/null || echo unknown)_"
      echo "$probe"
      echo ""
      echo "> This census grants no deletion permission. Candidates require scoped approval."
      echo "> UV cleanup additionally requires compatible tooling and a verified producer contract."
      echo ">"
      echo "> ⛔ **These are APPARENT sizes — an upper bound, NOT a disk footprint.** On APFS a"
      echo "> \`cp -c\` clone is a SEPARATE INODE sharing blocks, so \`du\` counts every copy in"
      echo "> full and cannot dedupe them (measured: 200 MB file + 2 clones → du reports 606 MB,"
      echo "> 3x, while real usage does not grow at all). Clone-heavy trees are therefore"
      echo "> **systematically over-ranked** — notably \`uv\` (clone link-mode is its macOS"
      echo "> default), pnpm/bun node_modules, and Docker. Free-space delta is an observed"
      echo "> net volume change, not physical reclaim attributable to this target: other"
      echo "> writers and removals may run concurrently. Use this list to pick CANDIDATES;"
      echo "> neither du nor that net delta promises how much a target deletion will recover."
    fi
    echo ""
    echo "## Full scan command"
    echo "\`du -m -x -d1 \"\$HOME\" 2>/dev/null | sort -rn | head -25\`"
  } >"$f" 2>/dev/null || true
  log "SUGGESTIONS written → $f"
}

# write an agent-delegation seed: an active Claude session (preflight/morning-briefing)
# picks this up + delegates a macOS-cleanup SPECIALIST AGENT to triage judgment items.
write_agent_seed() {
  local seed="$STATE_DIR/NEEDS-AGENT-$(date +%Y%m%dT%H%M%S).md"
  {
    echo "---"
    echo "kind: disk-cleanup-agent-delegation-seed"
    echo "created: $(ts)"
    echo "free_gb: ${AVAIL_GB}"
    echo "cap_pct: ${CAP_PCT}"
    echo "---"
    echo ""
    echo "# Disk critical — delegate read-only triage to a macOS specialist"
    echo ""
    echo "The disk cleanup deployment is paused pending validation and scope approval."
    echo "No successful cleanup is inferred from this seed; inspect guardian.log."
    echo "Free is still ${AVAIL_GB}G (cap ${CAP_PCT}%). The remaining reclaimable space is JUDGMENT-gated."
    echo ""
    echo "## Task for the delegated agent (triage, not cleanup authorization)"
    echo "Triage — with the operator's non-destructive, protect-user-data, protect-secrets constraints —"
    echo "the judgment items in SUGGESTIONS.md (Trash · Downloads · Docker.raw · Parallels/UTM VMs ·"
    echo "ollama models · node_modules). Propose a ranked, reversible-first reclaim plan; NEVER touch"
    echo "~/.openclaw ~/.omniroute ~/.claude secrets Documents Desktop or non-regenerable user data."
    echo "See \`$STATE_DIR/SUGGESTIONS.md\` for the current top consumers."
  } >"$seed" 2>/dev/null || true
  log "AGENT-SEED written → $seed (an active session will delegate a macOS-cleanup specialist)"

  # BACKLOG ALARM — "an active session will pick this up" is an ASSUMPTION, so measure it.
  # /** [decision] count unconsumed seeds and shout when they pile up
  #  *  @context 2026-07-22: 4 seeds spanning 9 days (13/07 → 22/07), NONE consumed —
  #  *           including one written at 14:46 WHILE the disk was dying. The consumer
  #  *           (system-health-responder skill) is wired to zero fire-points, so every
  #  *           seed since 13/07 went to a dead-letter box in total silence.
  #  *  @reason a handoff whose pickup is never verified is a dropped handoff that LOOKS
  #  *          delivered. Writing the seed is not the outcome; the seed being READ is.
  #  *  @impact cannot fix the missing consumer from here (that is a settings.json hook,
  #  *          operator-gated) — but converts SILENT rot into LOUD rot, which is the part
  #  *          I do own. Detection where action is not permitted; same split as the census. */
  local backlog
  backlog=$(find "$STATE_DIR" -maxdepth 1 -name 'NEEDS-AGENT-*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${backlog:-0}" -ge 3 ]; then
    local oldest
    oldest=$(find "$STATE_DIR" -maxdepth 1 -name 'NEEDS-AGENT-*.md' 2>/dev/null | sort | head -1)
    log "⚠️  SEED-BACKLOG ${backlog} unconsumed agent-seeds (oldest: $(basename "${oldest:-?}")) — the consumer is NOT firing; seeds are rotting, not being handled"
    osascript -e "display notification \"${backlog} disk agent-seeds written, NONE consumed. The responder has no fire-point — nobody is reading these.\" with title \"Disk Health Guardian\" subtitle \"Handoff is rotting\"" 2>/dev/null || true
  fi
}

escalate() {
  # Debounce is SEVERITY-AWARE, not purely time-based (round-7 fix, 2026-07-22).
  #
  # The old rule was "at most one notification per 6h". That is a fail-open: the
  # FIRST notification (e.g. at 8G — merely bad) silenced every later one for 6h,
  # including 2G, 1G and 0G — catastrophically worse. Empirically observed the day
  # the disk hit 0 bytes: three consecutive `suppressed (notified <6h ago)` lines,
  # the last at free=0G. The alarm got QUIETER as the emergency got WORSE.
  #
  # New rule — re-notify when ANY holds:
  #   (a) 6h elapsed                      → the original periodic reminder
  #   (b) we lost >=2G since we last spoke → severity ratchet (the real fix)
  #   (c) free <= 2G and >=30min elapsed   → near-death floor, still spam-bounded
  #
  # Stamp format: "<epoch> <avail_gb_at_notify>". A legacy stamp (epoch only) yields
  # an empty gb → treated as +inf so rule (b) fires once, then self-heals to the
  # new format.
  local stamp="$STATE_DIR/last-escalate" now last last_gb elapsed reason=""
  now=$(date +%s)
  if [ -f "$stamp" ]; then
    read -r last last_gb <"$stamp" 2>/dev/null || { last=0; last_gb=""; }
    case "$last"    in ''|*[!0-9]*) last=0 ;; esac
    case "$last_gb" in ''|*[!0-9]*) last_gb=999999 ;; esac   # legacy stamp → force one notify
    elapsed=$(( now - last ))
    if   [ "$elapsed" -ge 21600 ];                              then reason="6h-elapsed"
    elif [ "$AVAIL_GB" -le $(( last_gb - 2 )) ];                then reason="worsened(${last_gb}G->${AVAIL_GB}G)"
    elif [ "$AVAIL_GB" -le 2 ] && [ "$elapsed" -ge 1800 ];      then reason="near-death(${AVAIL_GB}G)"
    else
      log "CRITICAL-ESCALATE suppressed (notified ${elapsed}s ago at ${last_gb}G, now ${AVAIL_GB}G — not worse by >=2G); cap=${CAP_PCT}%"
      return 0
    fi
    log "CRITICAL-ESCALATE re-arming: $reason"
  fi
  printf '%s %s\n' "$now" "$AVAIL_GB" >"$stamp"
  log "CRITICAL-ESCALATE free=${AVAIL_GB}G cap=${CAP_PCT}% — judgment residue; inspect actual cleanup outcomes"
  write_suggestions
  write_agent_seed
  osascript -e "display notification \"${AVAIL_GB}G free (${CAP_PCT}%) Review SUGGESTIONS.md; cleanup is approval-gated.\" with title \"Disk Health Guardian\" subtitle \"Critical — judgment residue\"" 2>/dev/null || true
}

# ── main ─────────────────────────────────────────────────────────────────────
snapshot
# test hook: exercise the escalate path (suggestions + agent-seed + notify) directly,
# without waiting for a real low-disk reclaim. Not used by launchd.
if [ "${1:-}" = "--escalate-now" ]; then
  log "TEST-ESCALATE-NOW free=${AVAIL_GB}G cap=${CAP_PCT}%"
  escalate
  exit 0
fi
# /** [decision] 2026-10-13: BURN-RATE early trigger + writer attribution + seed self-resolve
#  *  @context 2026-10-13 the Data volume drained 16G→0 in ~90min; the guardian only reacted
#  *           at a fixed <15G and never named the writer. Root writer was SWAP (/System/
#  *           Volumes/VM, same APFS container) grown by a process fan-out leak (~600 MCP
#  *           children of one `codex app-server`); seeds from 10/10 + 13/10 sat unconsumed.
#  *  @reason  act on the RATE, not just the level; name the writer every time we act.
#  *  @impact  early Tier-1 when drop>=3G/interval or time-to-zero<30min (and free<EARLY_FREE_GB);
#  *           ATTRIB line (swap, fan-out parents, hot-dir deltas, bounded du); seeds auto-move to
#  *           consumed/ after 2 healthy runs. Read-only except the existing Tier-1 allowlist. */
EARLY_FREE_GB="${DHG_EARLY_FREE_GB:-20}"
BURN_DROP_GB="${DHG_BURN_DROP_GB:-3}"
BURN_TTZ_MIN="${DHG_BURN_TTZ_MIN:-30}"
SAMPLES="$STATE_DIR/free-samples"
NOW_EPOCH=$(date +%s)
PREV_LINE="$(tail -1 "$SAMPLES" 2>/dev/null || true)"
PREV_EPOCH="${PREV_LINE%% *}"; PREV_GB="${PREV_LINE##* }"
case "$PREV_EPOCH" in ''|*[!0-9]*) PREV_EPOCH=0 ;; esac
case "$PREV_GB" in ''|*[!0-9]*) PREV_GB="$AVAIL_GB" ;; esac
{ tail -47 "$SAMPLES" 2>/dev/null || true; printf '%s %s\n' "$NOW_EPOCH" "$AVAIL_GB"; } > "$SAMPLES.tmp" 2>/dev/null && mv "$SAMPLES.tmp" "$SAMPLES" 2>/dev/null || true
DROP_GB=$(( PREV_GB - AVAIL_GB )); DT=$(( NOW_EPOCH - PREV_EPOCH ))
TTZ_MIN=9999
if [ "$PREV_EPOCH" -gt 0 ] && [ "$DT" -gt 0 ] && [ "$DROP_GB" -gt 0 ]; then
  TTZ_MIN=$(( AVAIL_GB * DT / DROP_GB / 60 ))
fi
BURN=0
if [ "$PREV_EPOCH" -gt 0 ] && [ "$DT" -le 3600 ] && { [ "$DROP_GB" -ge "$BURN_DROP_GB" ] || [ "$TTZ_MIN" -lt "$BURN_TTZ_MIN" ]; }; then
  BURN=1
fi

attribute_writer() {  # bounded, read-only: who is writing the volume?
  local swap fan hot="" d sz prev
  if [ "$AVAIL_GB" -le "$CRIT_FREE_GB" ]; then log 'ATTRIB DEFER bulk scans at critical margin'; return 0; fi
  swap="$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6}')"
  fan="$(ps -A -o ppid= 2>/dev/null | awk '$1>1{c[$1]++} END{for(p in c) print c[p], p}' | sort -rn | awk 'NR<=3{printf "%s ", $0}' || true)"
  for d in "$HOME/.codex/.tmp" "/private/tmp/claude-$(id -u)" "${TMPDIR:-/tmp}" "$HOME/.npm/_npx" "$HOME/.cache/uv" "$HOME/Library/Caches"; do
    [ -d "$d" ] || continue
    if [ -n "$TIMEOUT_BIN" ]; then sz="$("$TIMEOUT_BIN" 20 du -sxm "$d" 2>/dev/null | awk '{print $1}' || true)"; else sz=""; fi
    prev="$(awk -v k="$d" '$1==k{print $2}' "$STATE_DIR/hotdirs" 2>/dev/null | tail -1 || true)"
    if [ -n "$sz" ] && [ -n "$prev" ]; then hot="$hot$(basename "$d")=${sz}M(Δ$(( sz - prev ))M) "; else hot="$hot$(basename "$d")=${sz:-timeout}M "; fi
    [ -n "$sz" ] && printf '%s %s\n' "$d" "$sz" >> "$STATE_DIR/hotdirs.new" 2>/dev/null || true
  done
  [ -f "$STATE_DIR/hotdirs.new" ] && mv "$STATE_DIR/hotdirs.new" "$STATE_DIR/hotdirs" 2>/dev/null || true
  log "ATTRIB swap_used=${swap:-?} (swap lives in /System/Volumes/VM = SAME container) fanout(children ppid)=[${fan}] hot=[${hot}]"
}

resolve_seeds() {  # seeds whose condition cleared for 2 healthy runs → consumed/ (keep while critical)
  local hs="$STATE_DIR/.healthy-streak" n s
  n=$(( $(cat "$hs" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$hs" 2>/dev/null || true
  [ "$n" -ge 2 ] || return 0
  mkdir -p "$STATE_DIR/consumed"
  for s in "$STATE_DIR"/NEEDS-AGENT-*.md; do
    [ -f "$s" ] || continue
    printf '\n---\nAUTO-RESOLVED %s by disk-health-guardian: free=%sG >= %sG for %s consecutive runs; condition cleared.\n' "$(ts)" "$AVAIL_GB" "$LOW_FREE_GB" "$n" >> "$s" 2>/dev/null || true
    mv "$s" "$STATE_DIR/consumed/" 2>/dev/null && log "SEED-AUTO-RESOLVED $(basename "$s") (free=${AVAIL_GB}G healthy x${n})"
  done
}

if [ "$BURN" -eq 1 ]; then
  log "BURN-RATE drop=${DROP_GB}G in ${DT}s ttz≈${TTZ_MIN}min free=${AVAIL_GB}G"
fi
if [ "$AVAIL_GB" -lt "$LOW_FREE_GB" ] || { [ "$BURN" -eq 1 ] && [ "$AVAIL_GB" -lt "$EARLY_FREE_GB" ]; }; then
  echo 0 > "$STATE_DIR/.healthy-streak" 2>/dev/null || true
  attribute_writer
  [ "$BURN" -eq 1 ] && [ "$REPORTING" -eq 1 ] && [ "$AVAIL_GB" -lt "$LOW_FREE_GB" ] && [ "$TTZ_MIN" -lt "$BURN_TTZ_MIN" ] && \
    osascript -e "display notification \"Disk losing ${DROP_GB}G/interval, ~${TTZ_MIN}min to zero (${AVAIL_GB}G free). See guardian.log ATTRIB.\" with title \"Disk Health Guardian\" subtitle \"Burn-rate alarm\"" 2>/dev/null || true
  log "TRIGGER free=${AVAIL_GB}G (<${LOW_FREE_GB}G or burn) cap=${CAP_PCT}% dry_run=${DRY_RUN}"
  reclaim
  snapshot
  log "POST-RECLAIM free=${AVAIL_GB}G cap=${CAP_PCT}%"
  log "TIER2 DEFER unapproved broader cleanup (free=${AVAIL_GB}G, threshold=${TIER2_FREE_GB}G)"
  if [ "$REPORTING" -eq 1 ] && [ "$AVAIL_GB" -lt "$CRIT_FREE_GB" ]; then
    escalate
  fi
else
  log "HEARTBEAT healthy free=${AVAIL_GB}G cap=${CAP_PCT}% — no action"
  if [ "$REPORTING" -eq 1 ]; then resolve_seeds; fi
fi
exit "$ACTION_DEFERRED"
