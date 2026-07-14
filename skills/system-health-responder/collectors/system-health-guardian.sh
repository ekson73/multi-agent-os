#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# system-health-guardian.sh — READ-ONLY cross-resource health collector (EKO-90 part-1)
#
# /** [decision] deterministic bash + launchd (StartInterval=600), NOT an LLM loop.
#  *  @context operator EKO-90 2026-07-13: "avalie recursos [cpu,mem,disco,segurança,
#  *           malware,processos,threads] de 10 em 10 min, salve log + contrato
#  *           searchable [json/yaml] com tag taxonômico + drill-down até root-fail".
#  *           Extends the disk-health-guardian pattern to a cross-resource sampler.
#  *  @reason a sample-and-threshold conditional is code, not inference; amnesia-proof,
#  *          ~0 cost, reproducible. The PROBABILISTIC judgment (what to heal, is it
#  *          safe) belongs to the part-2 responder, NOT here.
#  *  @impact READ-ONLY — mutates NOTHING (even safer than disk-guardian, which prunes).
#  *          Emits a world-readable, SECRET-FREE health-contract for all ai-agents. */
#
# SECRET-SAFETY MODEL (⛔ absolute — the contract is world-readable):
#   • process sampling reads `comm` (executable NAME) ONLY — NEVER `command`/argv,
#     which routinely carries secrets (--api-key=…). No env dumps, no file contents.
#   • only metadata is emitted: counts · percentages · names · versions · booleans.
#   • security/malware surface = STATUS flags (enabled/stale), never a scanned value.
#
# NON-DESTRUCTIVE: this collector never writes outside its own STATE_DIR, never
#   deletes, never touches ~/.openclaw ~/openclaw ~/.omniroute ~/.claude or any
#   user data. Disk is delegated to the existing disk-health-guardian (no dup).
#
# Tool-tier: built-in os-native only (top/ps/vm_stat/iostat/df/log/system_profiler/
#   sysctl/lsof/csrutil/spctl/XProtect) — ZERO install. osquery = documented upgrade.
#
# Usage: system-health-guardian.sh [--once] [--stdout]
# Out:   ~/.local/state/system-health/health-contract.{json,yaml}  +  guardian.log
# Drill: jq -r '.system.status'  ·  jq '[.. |objects|select(.status?=="crit")]'  ·
#        walk .system.root_fail → .system.branches[…].root_fail → leaf
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

STATE_DIR="$HOME/.local/state/system-health"
CONTRACT_JSON="$STATE_DIR/health-contract.json"
CONTRACT_YAML="$STATE_DIR/health-contract.yaml"
LOG="$STATE_DIR/guardian.log"
mkdir -p "$STATE_DIR"

STDOUT=0
[ "${1:-}" = "--stdout" ] || [ "${2:-}" = "--stdout" ] && STDOUT=1

INTERVAL_SEC="${HEALTH_INTERVAL_SEC:-600}"   # informational; launchd owns the cadence

# ── Thresholds (env-overridable) ──────────────────────────────────────────────
CPU_LOAD_WARN_RATIO="${CPU_LOAD_WARN_RATIO:-0.90}"   # load1/ncpu → early WARN (spiky-OK, 1-min)
CPU_LOAD_CRIT_RATIO="${CPU_LOAD_CRIT_RATIO:-1.50}"   # load5/ncpu → CRIT (SUSTAINED, 5-min) — round-4 false-crit fix
MEM_AVAIL_WARN_PCT="${MEM_AVAIL_WARN_PCT:-15}"
MEM_AVAIL_CRIT_PCT="${MEM_AVAIL_CRIT_PCT:-8}"
DISK_FREE_WARN_GB="${DISK_FREE_WARN_GB:-15}"
DISK_FREE_CRIT_GB="${DISK_FREE_CRIT_GB:-8}"
PROC_CPU_WARN="${PROC_CPU_WARN:-70}"                 # single-proc %cpu (feeds responder renice target)
PROC_CPU_CRIT="${PROC_CPU_CRIT:-90}"
XPROTECT_STALE_WARN_DAYS="${XPROTECT_STALE_WARN_DAYS:-30}"      # auto-update OFF → WARN at Nd (the real risk)
XPROTECT_STALE_CRIT_DAYS="${XPROTECT_STALE_CRIT_DAYS:-60}"      # auto-update OFF → CRIT at Nd
XPROTECT_SELFHEAL_WARN_DAYS="${XPROTECT_SELFHEAL_WARN_DAYS:-60}" # auto-update ON → only >Nd WARNs, never crit (self-healing; Apple cadence)
SWUPDATE="${SWUPDATE:-/usr/sbin/softwareupdate}"                 # abs path (launchd minimal PATH); read-only --schedule

# jq / yq (mise installs — resolve absolute for launchd's minimal PATH)
JQ="$(command -v jq || echo /Users/$USER/.local/share/mise/installs/jq/1.7/jq)"
YQ="$(command -v yq || true)"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG"; }

# rank helper: worst of a set of statuses
worst() { local w=ok; for s in "$@"; do case "$s" in crit) echo crit; return;; warn) w=warn;; esac; done; echo "$w"; }
# numeric compare (bc-free, awk): status_from_num VALUE WARN CRIT  (higher = worse)
st_hi() { awk -v v="$1" -v w="$2" -v c="$3" 'BEGIN{ if(v>=c)print"crit"; else if(v>=w)print"warn"; else print"ok"}'; }
# status_from_num LOWER-is-worse: st_lo VALUE WARN CRIT  (lower = worse; e.g. free space)
st_lo() { awk -v v="$1" -v w="$2" -v c="$3" 'BEGIN{ if(v<=c)print"crit"; else if(v<=w)print"warn"; else print"ok"}'; }

# ── round-4 pure decision cores (unit-testable; mirror compute_burndown pattern) ──
# cpu_load_status: WARN keyed on load1 (spiky 1-min, early); CRIT keyed on load5 (sustained 5-min).
# A transient 1-min burst (IDE compile / indexer) WARNs but NEVER crits — the round-4 false-crit fix.
cpu_load_status() { # $1=load1 $2=load5 $3=ncpu $4=warn_ratio $5=crit_ratio
  local warn crit s1 s5
  warn="$(awk -v r="$4" -v n="$3" 'BEGIN{printf "%.4f", r*n}')"
  crit="$(awk -v r="$5" -v n="$3" 'BEGIN{printf "%.4f", r*n}')"
  s1="$(st_hi "$1" "$warn" "999999")"   # load1 → WARN band only (crit unreachable)
  s5="$(st_hi "$2" "$crit" "$crit")"    # load5 → CRIT band only (warn==crit threshold)
  worst "$s1" "$s5"
}
# xprotect_status: age-alone conflates "stale" with "Apple hasn't shipped". Gate on the auto-update
# channel — ON ⇒ self-healing (caps at WARN past a generous window, never crit); OFF ⇒ the real risk (full escalation).
xprotect_status() { # $1=age_days $2=autoupdate(on|off) $3=warn_days $4=crit_days $5=selfheal_warn_days
  if [ "$2" = "on" ]; then st_hi "$1" "$5" "999999"; else st_hi "$1" "$3" "$4"; fi
}

# ── BURN-DOWN forecast (EKO-90-round3 2026-07-14) — reclaim-aware disk-exhaustion prediction ──
# The PROACTIVE half of the guardian: predicts days-until-DISK_FREE_WARN_GB from the recent NATURAL drain
# rate. Reads the disk-guardian's own timestamped `free=<N>G` samples (no new state file). CORRECTNESS FIX
# (the confounding: free space JUMPS UP on the guardian's reclaim()/Tier-2 cache deletions, so a naïve
# slope reads "recovering" during a reclaim-masked drain) → we slope ONLY the tail AFTER the last reclaim
# up-jump (the natural-drain segment); flat/rising tail → "not draining". SECRET-SAFE (reads only free-
# space integers + timestamps; never argv). Cold-start honest (absent/thin log → "unknown", never faked).
DISK_GUARDIAN_LOG="${DISK_GUARDIAN_LOG:-$HOME/.local/state/disk-health-guardian/guardian.log}"
BURNDOWN_WINDOW="${BURNDOWN_WINDOW:-24}"                  # last N samples (~4h at 10-min cadence)
BURNDOWN_RECLAIM_JUMP_GB="${BURNDOWN_RECLAIM_JUMP_GB:-5}" # consecutive +Δfree > this = a reclaim event
compute_burndown() {
  local log="$DISK_GUARDIAN_LOG" pairs series="" ts f ep
  [ -f "$log" ] || { printf '{"status":"unknown","reason":"no-log"}'; return 0; }
  # extract last WINDOW `free=<N>G` samples as "ISO_TS free_gb" (free= is 5 chars, trailing G is 1)
  pairs="$(awk 'match($0,/free=[0-9]+G/){print $1, substr($0,RSTART+5,RLENGTH-6)}' "$log" 2>/dev/null | tail -n "$BURNDOWN_WINDOW" || true)"
  [ -n "$pairs" ] || { printf '{"status":"unknown","reason":"no-samples"}'; return 0; }
  # ISO-8601+offset → epoch (bounded: ≤WINDOW date calls; macOS awk lacks mktime so pre-convert)
  while read -r ts f; do
    [ -n "$ts" ] || continue
    ep="$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$ts" +%s 2>/dev/null || true)"
    if [ -z "$ep" ]; then   # RFC3339 colon-offset (+00:00) → normalize to +0000 (strip ONLY the trailing offset colon) & retry — no silent sample loss on format drift
      ep="$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$(printf '%s' "$ts" | sed -E 's/([+-][0-9][0-9]):([0-9][0-9])$/\1\2/')" +%s 2>/dev/null || true)"
    fi
    if [ -z "$ep" ]; then   # RFC3339 Zulu (…Z = UTC) — the convention the repo's OTHER logs use; parse as UTC (never a silent blind-spot)
      case "$ts" in *Z) ep="$(TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" +%s 2>/dev/null || true)";; esac
    fi
    [ -n "$ep" ] && series="${series}${ep} ${f}"$'\n'
  done <<EOF
$pairs
EOF
  [ -n "$series" ] || { printf '{"status":"unknown","reason":"ts-parse-failed"}'; return 0; }
  printf '%s' "$series" | awk -v warn="$DISK_FREE_WARN_GB" -v jump="$BURNDOWN_RECLAIM_JUMP_GB" '
    { e[NR]=$1; g[NR]=$2 }
    END {
      n=NR;
      if (n<3){ printf "{\"status\":\"unknown\",\"reason\":\"insufficient-samples\",\"samples\":%d}", n; exit }
      start=1; for(i=2;i<=n;i++) if (g[i]-g[i-1] > jump) start=i;   # tail after the LAST reclaim up-jump
      # short post-reclaim tail: DO NOT slope the full window (it re-includes the jump → the exact confounding
      # this is meant to avoid). Honest "unknown" until enough post-reclaim samples accrue (Tomé > a wrong trend).
      if (start>1 && n-start+1 < 3){ printf "{\"status\":\"unknown\",\"reason\":\"post-reclaim-tail-short\",\"samples\":%d}", n-start+1; exit }
      sx=0;sy=0;sxx=0;sxy=0;k=0; x0=e[start];
      for(i=start;i<=n;i++){ x=e[i]-x0; y=g[i]; sx+=x;sy+=y;sxx+=x*x;sxy+=x*y;k++ }
      den=k*sxx - sx*sx;
      if (den==0){ printf "{\"status\":\"unknown\",\"reason\":\"degenerate-time\",\"samples\":%d}", k; exit }
      sph=((k*sxy - sx*sy)/den)*3600.0;   # GB/hour, signed (negative = draining)
      last=g[n]; eps=0.05;
      if (sph >= -eps){ printf "{\"status\":\"ok\",\"trend\":\"stable-or-recovering\",\"drain_gb_per_hr\":0,\"days_to_threshold\":null,\"threshold_gb\":%d,\"samples\":%d,\"free_gb\":%d}", warn,k,last; exit }
      drain=-sph; headroom=last-warn;
      if (headroom<=0){ printf "{\"status\":\"crit\",\"trend\":\"draining\",\"drain_gb_per_hr\":%.2f,\"days_to_threshold\":0,\"threshold_gb\":%d,\"samples\":%d,\"free_gb\":%d}", drain,warn,k,last; exit }
      days=(headroom/drain)/24.0; st=(days<1)?"crit":((days<7)?"warn":"ok");
      printf "{\"status\":\"%s\",\"trend\":\"draining\",\"drain_gb_per_hr\":%.2f,\"days_to_threshold\":%.2f,\"threshold_gb\":%d,\"samples\":%d,\"free_gb\":%d}", st,drain,days,warn,k,last;
    }'
}
# testable entrypoint: `--burndown` runs ONLY the forecast (no probing, no contract write) — the unit test
# (bin/burndown-test.sh) drives this with a synthetic DISK_GUARDIAN_LOG (no awk duplication).
if [ "${1:-}" = "--burndown" ]; then compute_burndown; echo; exit 0; fi
# testable entrypoints for the round-4 pure decision cores (bin/threshold-test.sh drives these — no logic dup):
if [ "${1:-}" = "--cpu-load-status" ]; then cpu_load_status "${2:-0}" "${3:-0}" "${4:-1}" "${5:-0.90}" "${6:-1.50}"; exit 0; fi
if [ "${1:-}" = "--xprotect-status" ]; then xprotect_status "${2:-0}" "${3:-on}" "${4:-30}" "${5:-60}" "${6:-60}"; exit 0; fi

# ── CPU ───────────────────────────────────────────────────────────────────────
NCPU="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
# vm.loadavg → "{ 1.23 4.56 7.89 }" (1/5/15-min averages): $2=load1 (spiky), $3=load5 (sustained).
LOADAVG="$(sysctl -n vm.loadavg 2>/dev/null)"
LOAD1="$(awk '{print $2}' <<<"$LOADAVG")"; LOAD1="${LOAD1:-0}"
LOAD5="$(awk '{print $3}' <<<"$LOADAVG")"; LOAD5="${LOAD5:-$LOAD1}"
LOAD_RATIO="$(awk -v l="$LOAD1" -v n="$NCPU" 'BEGIN{printf "%.2f", (n>0)?l/n:l}')"
LOAD5_RATIO="$(awk -v l="$LOAD5" -v n="$NCPU" 'BEGIN{printf "%.2f", (n>0)?l/n:l}')"
# WARN on load1 (early), CRIT only on SUSTAINED load5 — a 1-min burst warns, never crits (round-4).
CPU_LOAD_ST="$(cpu_load_status "$LOAD1" "$LOAD5" "$NCPU" "$CPU_LOAD_WARN_RATIO" "$CPU_LOAD_CRIT_RATIO")"
# top cpu consumer (comm ONLY — never argv). Capture ps fully first (no head-on-pipe → no SIGPIPE under pipefail).
PS_BY_CPU="$(ps -A -r -o pid=,%cpu=,comm= 2>/dev/null || true)"
TOP_CPU_LINE="$(awk 'NR==1{pid=$1;cpu=$2;$1="";$2="";c=$0;sub(/^ +/,"",c);n=split(c,a,"/");print pid"|"cpu"|"a[n]; exit}' <<<"$PS_BY_CPU")"
TOP_CPU_PID="$(echo "$TOP_CPU_LINE" | cut -d'|' -f1)"; TOP_CPU_PCT="$(echo "$TOP_CPU_LINE" | cut -d'|' -f2)"; TOP_CPU_COMM="$(echo "$TOP_CPU_LINE" | cut -d'|' -f3)"
TOP_CPU_PCT="${TOP_CPU_PCT:-0}"
CPU_PROC_ST="$(st_hi "$TOP_CPU_PCT" "$PROC_CPU_WARN" "$PROC_CPU_CRIT")"
CPU_ST="$(worst "$CPU_LOAD_ST" "$CPU_PROC_ST")"

# ── MEMORY (available% from vm_stat; inactive+free+speculative+purgeable ≈ available) ──
PAGE_SZ="$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)"
MEM_TOTAL="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
VMS="$(vm_stat 2>/dev/null || true)"
pg() { echo "$VMS" | awk -F: -v k="$1" '$0 ~ k {gsub(/[^0-9]/,"",$2); print $2; exit}'; }
P_FREE="$(pg 'Pages free')"; P_INACT="$(pg 'Pages inactive')"; P_SPEC="$(pg 'Pages speculative')"; P_PURG="$(pg 'Pages purgeable')"
AVAIL_BYTES="$(awk -v f="${P_FREE:-0}" -v i="${P_INACT:-0}" -v s="${P_SPEC:-0}" -v p="${P_PURG:-0}" -v ps="$PAGE_SZ" 'BEGIN{print (f+i+s+p)*ps}')"
MEM_AVAIL_PCT="$(awk -v a="$AVAIL_BYTES" -v t="$MEM_TOTAL" 'BEGIN{printf "%.1f", (t>0)?a*100/t:0}')"
MEM_ST="$(st_lo "$MEM_AVAIL_PCT" "$MEM_AVAIL_WARN_PCT" "$MEM_AVAIL_CRIT_PCT")"
PS_BY_MEM="$(ps -A -m -o pid=,%mem=,comm= 2>/dev/null || true)"
TOP_MEM_LINE="$(awk 'NR==1{pid=$1;m=$2;$1="";$2="";c=$0;sub(/^ +/,"",c);n=split(c,a,"/");print pid"|"m"|"a[n]; exit}' <<<"$PS_BY_MEM")"
TOP_MEM_COMM="$(echo "$TOP_MEM_LINE" | cut -d'|' -f3)"; TOP_MEM_PCT="$(echo "$TOP_MEM_LINE" | cut -d'|' -f2)"; TOP_MEM_PCT="${TOP_MEM_PCT:-0}"

# ── DISK (delegate acting to disk-guardian; here we only REPORT the data volume) ──
DISK_FREE_GB="$(df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $4}')"; DISK_FREE_GB="${DISK_FREE_GB:-999}"
DISK_ST="$(st_lo "$DISK_FREE_GB" "$DISK_FREE_WARN_GB" "$DISK_FREE_CRIT_GB")"
DG_LIVE="absent"; [ -f "$HOME/Library/LaunchAgents/com.eko.disk-health-guardian.plist" ] && DG_LIVE="delegated"

# ── SECURITY (status flags — never a value) ───────────────────────────────────
SIP="$(csrutil status 2>/dev/null | grep -qi enabled && echo enabled || echo disabled)"
GK="$(spctl --status 2>/dev/null | grep -qi 'assessments enabled' && echo enabled || echo disabled)"
FW_RAW="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo unknown)"
FW="$(echo "$FW_RAW" | grep -qi 'enabled' && echo enabled || { echo "$FW_RAW" | grep -qi 'disabled' && echo disabled || echo unknown; })"
SEC_ST=ok
[ "$SIP" = disabled ] && SEC_ST=crit
[ "$GK" = disabled ] && SEC_ST="$(worst "$SEC_ST" warn)"
[ "$FW" = disabled ] && SEC_ST="$(worst "$SEC_ST" warn)"

# ── MALWARE (XProtect freshness — built-in AV signatures) ─────────────────────
XP_BUNDLE="/Library/Apple/System/Library/CoreServices/XProtect.bundle"
XP_VER="$(defaults read "$XP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
XP_MTIME="$(stat -f %m "$XP_BUNDLE" 2>/dev/null || echo 0)"
NOW_EPOCH="$(date +%s)"
XP_AGE_DAYS="$(awk -v m="$XP_MTIME" -v n="$NOW_EPOCH" 'BEGIN{printf "%.0f", (m>0)?(n-m)/86400:9999}')"
# auto-update channel (cheap ~20ms, no-sudo, local --schedule read). ON ⇒ freshness self-heals →
# 47d-but-latest is honestly ok (Apple cadence), not warn. OFF ⇒ the real risk → full age escalation.
XP_AUTOUPDATE="$("$SWUPDATE" --schedule 2>/dev/null | grep -qi 'turned on' && echo on || echo off)"
MAL_ST="$(xprotect_status "$XP_AGE_DAYS" "$XP_AUTOUPDATE" "$XPROTECT_STALE_WARN_DAYS" "$XPROTECT_STALE_CRIT_DAYS" "$XPROTECT_SELFHEAL_WARN_DAYS")"

# ── PROCESS / THREADS ─────────────────────────────────────────────────────────
PROC_COUNT="$(ps -A -o pid= 2>/dev/null | wc -l | tr -d ' ')"
THREAD_COUNT="$(ps -A -M 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
ZOMBIE_COUNT="$(ps -A -o stat= 2>/dev/null | grep -c '^Z' || true)"; ZOMBIE_COUNT="${ZOMBIE_COUNT:-0}"
# runaway = the top-cpu proc over threshold (reuse CPU sample) — this is the responder's renice candidate
PROC_ST="$(worst "$CPU_PROC_ST" "$(st_hi "$ZOMBIE_COUNT" 5 20)")"

# ── NETWORK (listener count — notify-only per safety-matrix) ──────────────────
LISTENERS="$(netstat -an -p tcp 2>/dev/null | grep -c LISTEN || true)"; LISTENERS="${LISTENERS:-0}"
ESTAB="$(netstat -an -p tcp 2>/dev/null | grep -c ESTABLISHED || true)"; ESTAB="${ESTAB:-0}"
NET_ST=ok   # MVP: informational; responder is notify-only for network

# ── AGENTIC-TOOLS health (EKO-90 ext v1.1.0 — operator /quiesce 2026-07-14) ────
# Adds `claude doctor` as a read-only "unattended show-only" probe (the BARE form is
# diagnostic-only — the *fixing* /doctor is in-session) + a cache-PRODUCER pressure
# signal (the leading indicator today's uvx-@latest disk-drain LACKED). SECRET-SAFE:
# emits only counts / names / status booleans — never a process's argv (note below).
TIMEOUT_BIN=""
for _c in /opt/homebrew/bin/timeout /opt/homebrew/bin/gtimeout /usr/local/bin/timeout /usr/local/bin/gtimeout /usr/bin/timeout; do
  [ -x "$_c" ] && { TIMEOUT_BIN="$_c"; break; }
done
run_bounded() { if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" "$1" "${@:2}" 2>/dev/null; else shift; "$@" 2>/dev/null; fi; }

# claude doctor — read-only agentic-runtime health (timeout-bounded; MUST NOT hang a 10-min cycle)
CLAUDE_ST=ok; CLAUDE_VER="unknown"; CLAUDE_HEALTH="absent"
if command -v claude >/dev/null 2>&1; then
  DOC_OUT="$(run_bounded 20 claude doctor || true)"
  CLAUDE_VER="$(printf '%s\n' "$DOC_OUT" | awk -F'[()]' '/^Running:/{print $2; exit}')"; CLAUDE_VER="${CLAUDE_VER:-unknown}"
  if printf '%s' "$DOC_OUT" | grep -qi 'No installation issues found'; then CLAUDE_HEALTH="healthy"; CLAUDE_ST=ok
  elif [ -n "$DOC_OUT" ]; then CLAUDE_HEALTH="issues-found"; CLAUDE_ST=warn
  else CLAUDE_HEALTH="doctor-timeout"; CLAUDE_ST=warn; fi
fi

# cache-PRODUCER pressure — leading indicator of producer-DRIVEN disk pressure (2026-07-14 lesson:
# N sessions re-spawning `uvx …@latest` re-inflate ~/.cache/uv/archive-v0 faster than the disk-guardian
# prunes the symptom). ARGV-FREE primary = archive object-count (one-level ls; fast; bounded). SECONDARY
# (emit COUNT only, never the matched string): live `uvx …@latest` proc count — argv is read to COUNT a
# pattern, the argv VALUE is NEVER emitted (metadata-count only → secret-safe per the model above).
UV_CACHE_DIR="$( { command -v uv >/dev/null 2>&1 && run_bounded 5 uv cache dir; } || echo "$HOME/.cache/uv" )"
UV_CACHE_DIR="${UV_CACHE_DIR:-$HOME/.cache/uv}"
UV_ARCHIVE_OBJS=0
[ -d "$UV_CACHE_DIR/archive-v0" ] && UV_ARCHIVE_OBJS="$(run_bounded 8 /bin/ls -1 "$UV_CACHE_DIR/archive-v0" | wc -l | tr -d ' ' || true)"
case "$UV_ARCHIVE_OBJS" in ''|*[!0-9]*) UV_ARCHIVE_OBJS=0 ;; esac
# `|| true`: pgrep exits 1 on NO-match → under `set -o pipefail` the pipeline fails → the VAR=$()
# assignment inherits exit 1 → `set -e` would abort (the classic set-e/$()/grep-no-match gotcha the
# original script guards every grep-c with). wc still prints "0" on empty stdin, so the value is right.
UVX_LATEST_PROCS="$(pgrep -f 'uvx .*@latest' 2>/dev/null | wc -l | tr -d ' ' || true)"
case "$UVX_LATEST_PROCS" in ''|*[!0-9]*) UVX_LATEST_PROCS=0 ;; esac
# ── ATTRIBUTION (EKO-90-round2 2026-07-14) — NAME an emergent producer, not just count it ──
# A transient `uvx …@latest` spawn can vanish before an operator can attribute it (lived it: pid 28935
# gone before it could be named). Record the PUBLIC PyPI package token(s) so the responder/registry can
# identify a re-emergent offender by name. SECRET-SAFE BY GRAMMAR: only tokens matching a strict package
# identifier `^[alnum][alnum._-]*@latest$` are accepted — a flag (`--key=…`) starts with `-`, a value with
# `=`/`/` — all rejected by the grammar. NEVER the full argv, NEVER a `--api-key=` value. (CWE-532/CWE-78.)
UVX_PRODUCERS=""
if [ "$UVX_LATEST_PROCS" -gt 0 ]; then
  _uvpids="$(pgrep -f 'uvx .*@latest' 2>/dev/null | tr '\n' ' ' || true)"
  if [ -n "${_uvpids// }" ]; then
    UVX_PRODUCERS="$(run_bounded 5 ps -o args= -p ${_uvpids} 2>/dev/null \
      | tr ' ' '\n' | grep -E '^[a-zA-Z0-9][a-zA-Z0-9._-]*@latest$' | sort -u | head -5 | paste -sd, - || true)"
  fi
fi
UV_OBJS_WARN="${UV_OBJS_WARN:-1500}"; UV_OBJS_CRIT="${UV_OBJS_CRIT:-4000}"
PRODUCER_ST="$(st_hi "$UV_ARCHIVE_OBJS" "$UV_OBJS_WARN" "$UV_OBJS_CRIT")"
# a LIVE @latest producer churning WHILE disk is already pressured = escalate (root-cause > symptom)
[ "$UVX_LATEST_PROCS" -gt 0 ] && [ "$DISK_ST" != ok ] && PRODUCER_ST="$(worst "$PRODUCER_ST" warn)"

AT_ST="$(worst "$CLAUDE_ST" "$PRODUCER_ST")"

# ── burn-down forecast (IMPLEMENTED round-3 — reclaim-aware; see compute_burndown() near the top) ──
# emits a structured object {status,trend,drain_gb_per_hr,days_to_threshold,threshold_gb,…} OR "unknown"/
# "ok stable-or-recovering". Never fabricates a number (Tomé). --argjson below already expects JSON.
BURN_DOWN="$(compute_burndown)"

# ── ROLL-UP ───────────────────────────────────────────────────────────────────
# each branch root_fail = its own worst leaf id; system root_fail = worst branch id
branch_rootfail() { # $1=branch-status ; $2..=leaf "id:status" pairs
  local bs="$1"; shift; local rf="null" id s
  [ "$bs" = ok ] && { echo null; return; }
  for pair in "$@"; do id="${pair%%:*}"; s="${pair##*:}"; [ "$s" = "$bs" ] && { rf="\"$id\""; break; }; done
  echo "$rf"
}
CPU_RF="$(branch_rootfail "$CPU_ST" "load1:$CPU_LOAD_ST" "top_consumer:$CPU_PROC_ST")"
MEM_RF="$(branch_rootfail "$MEM_ST" "available_pct:$MEM_ST")"
DISK_RF="$(branch_rootfail "$DISK_ST" "free_gb:$DISK_ST")"
SEC_RF="$(branch_rootfail "$SEC_ST" "sip:$([ "$SIP" = disabled ] && echo crit || echo ok)" "gatekeeper:$([ "$GK" = disabled ] && echo warn || echo ok)" "firewall:$([ "$FW" = disabled ] && echo warn || echo ok)")"
MAL_RF="$(branch_rootfail "$MAL_ST" "xprotect_freshness:$MAL_ST")"
PROC_RF="$(branch_rootfail "$PROC_ST" "runaway:$CPU_PROC_ST" "zombies:$(st_hi "$ZOMBIE_COUNT" 5 20)")"
NET_RF="$(branch_rootfail "$NET_ST" "listeners:$NET_ST")"

AT_RF="$(branch_rootfail "$AT_ST" "claude_runtime:$CLAUDE_ST" "cache_producer:$PRODUCER_ST")"
SYS_ST="$(worst "$CPU_ST" "$MEM_ST" "$DISK_ST" "$SEC_ST" "$MAL_ST" "$PROC_ST" "$NET_ST" "$AT_ST")"
SYS_RF="null"
for b in "cpu:$CPU_ST" "memory:$MEM_ST" "disk:$DISK_ST" "security:$SEC_ST" "malware:$MAL_ST" "process:$PROC_ST" "network:$NET_ST" "agentic_tools:$AT_ST"; do
  [ "${b##*:}" = "$SYS_ST" ] && [ "$SYS_ST" != ok ] && { SYS_RF="\"${b%%:*}\""; break; }
done

GEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo host)"

# ── EMIT CONTRACT (jq -n → guaranteed valid JSON + escaping) ──────────────────
"$JQ" -n \
  --arg gen "$GEN" --arg host "$HOST" --argjson interval "$INTERVAL_SEC" \
  --arg sys_st "$SYS_ST" --argjson sys_rf "$SYS_RF" \
  --arg cpu_st "$CPU_ST" --argjson cpu_rf "$CPU_RF" --arg ncpu "$NCPU" --arg load1 "$LOAD1" --arg load_ratio "$LOAD_RATIO" --arg load5 "$LOAD5" --arg load5_ratio "$LOAD5_RATIO" --arg cpu_load_st "$CPU_LOAD_ST" --arg top_cpu_comm "${TOP_CPU_COMM:-none}" --arg top_cpu_pct "$TOP_CPU_PCT" --arg top_cpu_pid "${TOP_CPU_PID:-0}" --arg cpu_proc_st "$CPU_PROC_ST" \
  --arg mem_st "$MEM_ST" --argjson mem_rf "$MEM_RF" --arg mem_avail_pct "$MEM_AVAIL_PCT" --arg top_mem_comm "${TOP_MEM_COMM:-none}" --arg top_mem_pct "$TOP_MEM_PCT" \
  --arg disk_st "$DISK_ST" --argjson disk_rf "$DISK_RF" --arg disk_free_gb "$DISK_FREE_GB" --arg dg_live "$DG_LIVE" \
  --arg sec_st "$SEC_ST" --argjson sec_rf "$SEC_RF" --arg sip "$SIP" --arg gk "$GK" --arg fw "$FW" \
  --arg mal_st "$MAL_ST" --argjson mal_rf "$MAL_RF" --arg xp_ver "$XP_VER" --arg xp_age "$XP_AGE_DAYS" --arg xp_au "$XP_AUTOUPDATE" \
  --arg proc_st "$PROC_ST" --argjson proc_rf "$PROC_RF" --arg proc_count "$PROC_COUNT" --arg thread_count "$THREAD_COUNT" --arg zombie "$ZOMBIE_COUNT" \
  --arg net_st "$NET_ST" --argjson net_rf "$NET_RF" --arg listeners "$LISTENERS" --arg estab "$ESTAB" \
  --argjson burn "$BURN_DOWN" \
  --arg at_st "$AT_ST" --argjson at_rf "$AT_RF" --arg claude_st "$CLAUDE_ST" --arg claude_ver "$CLAUDE_VER" --arg claude_health "$CLAUDE_HEALTH" --arg producer_st "$PRODUCER_ST" --arg uv_objs "$UV_ARCHIVE_OBJS" --arg uvx_latest "$UVX_LATEST_PROCS" --arg uvx_producers "$UVX_PRODUCERS" \
'def n(v): (v|tonumber?) // v;
{
  meta: { generated: $gen, host: $host, interval_sec: $interval, collector: "system-health-guardian", version: "1.4.0", secret_free: true,
          note: "world-readable, secret-free (metadata only: counts/%/names/versions/booleans; process=comm-name never argv)" },
  system: {
    status: $sys_st, tag: "resource.system", root_fail: $sys_rf,
    branches: {
      cpu:     { status: $cpu_st, tag: "resource.cpu", root_fail: $cpu_rf, leaves: {
                  load1:        { status: $cpu_load_st, tag: "resource.cpu.load1", value: n($load1), load5: n($load5), ncpu: n($ncpu), load_ratio: n($load_ratio), load5_ratio: n($load5_ratio) },
                  top_consumer: { status: $cpu_proc_st, tag: "resource.cpu.top_consumer", comm: $top_cpu_comm, pct: n($top_cpu_pct), pid: n($top_cpu_pid) } } },
      memory:  { status: $mem_st, tag: "resource.memory", root_fail: $mem_rf, leaves: {
                  available_pct: { status: $mem_st, tag: "resource.memory.available_pct", value: n($mem_avail_pct), top_consumer: $top_mem_comm, top_pct: n($top_mem_pct) } } },
      disk:    { status: $disk_st, tag: "resource.disk", root_fail: $disk_rf, delegated_to: $dg_live, leaves: {
                  free_gb: { status: $disk_st, tag: "resource.disk.free_gb", value: n($disk_free_gb) } } },
      security:{ status: $sec_st, tag: "resource.security", root_fail: $sec_rf, leaves: {
                  sip: { status: (if $sip=="disabled" then "crit" else "ok" end), tag: "resource.security.sip", value: $sip },
                  gatekeeper: { status: (if $gk=="disabled" then "warn" else "ok" end), tag: "resource.security.gatekeeper", value: $gk },
                  firewall: { status: (if $fw=="disabled" then "warn" else "ok" end), tag: "resource.security.firewall", value: $fw } } },
      malware: { status: $mal_st, tag: "resource.malware", root_fail: $mal_rf, leaves: {
                  xprotect_freshness: { status: $mal_st, tag: "resource.malware.xprotect_freshness", version: $xp_ver, age_days: n($xp_age), auto_update: $xp_au } } },
      process: { status: $proc_st, tag: "resource.process", root_fail: $proc_rf, leaves: {
                  runaway:  { status: $cpu_proc_st, tag: "resource.process.runaway", comm: $top_cpu_comm, cpu_pct: n($top_cpu_pct), pid: n($top_cpu_pid) },
                  counts:   { status: "ok", tag: "resource.process.counts", processes: n($proc_count), threads: n($thread_count), zombies: n($zombie) } } },
      network: { status: $net_st, tag: "resource.network", root_fail: $net_rf, leaves: {
                  listeners: { status: $net_st, tag: "resource.network.listeners", tcp_listen: n($listeners), tcp_established: n($estab) } } },
      agentic_tools: { status: $at_st, tag: "resource.agentic_tools", root_fail: $at_rf, leaves: {
                  claude_runtime: { status: $claude_st, tag: "resource.agentic_tools.claude_runtime", health: $claude_health, version: $claude_ver },
                  cache_producer: { status: $producer_st, tag: "resource.agentic_tools.cache_producer", uv_archive_objects: n($uv_objs), uvx_latest_procs: n($uvx_latest),
                                    uvx_latest_producers: ($uvx_producers | if . == "" then null else split(",") end) } } }
    }
  },
  burn_down: $burn
}' > "$CONTRACT_JSON.tmp" && mv "$CONTRACT_JSON.tmp" "$CONTRACT_JSON"
chmod 644 "$CONTRACT_JSON"

# yaml mirror (yq if present; else skip gracefully)
[ -n "$YQ" ] && "$YQ" -p=json -o=yaml "$CONTRACT_JSON" > "$CONTRACT_YAML.tmp" 2>/dev/null && mv "$CONTRACT_YAML.tmp" "$CONTRACT_YAML" && chmod 644 "$CONTRACT_YAML" || true

log "HEALTH system=$SYS_ST cpu=$CPU_ST mem=$MEM_ST($MEM_AVAIL_PCT%) disk=$DISK_ST(${DISK_FREE_GB}G) sec=$SEC_ST mal=$MAL_ST(${XP_AGE_DAYS}d) proc=$PROC_ST(${PROC_COUNT}p/${THREAD_COUNT}t) net=$NET_ST(${LISTENERS}L) at=$AT_ST(claude=$CLAUDE_HEALTH/uvobj=$UV_ARCHIVE_OBJS) root_fail=$SYS_RF"

[ "$STDOUT" = 1 ] && cat "$CONTRACT_JSON"
exit 0
