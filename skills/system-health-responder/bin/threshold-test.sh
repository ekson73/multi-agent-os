#!/usr/bin/env bash
# threshold-test.sh — unit tests for the round-4 threshold decision cores (EKO-90-round4).
# Drives the collector's `--cpu-load-status` / `--xprotect-status` entrypoints with synthetic inputs (no
# awk/logic duplication — the test exercises the EXACT production cpu_load_status() / xprotect_status()).
#
# Two false-positive classes this session surfaced, and the assertions that pin their fixes:
#   • CPU: a transient 1-min burst (load1 high, load5 settled) must WARN, never CRIT — crit requires
#     SUSTAINED load5. (Empirical: load1=27.33/12cores tripped a false-crit that settled in ~4 min.)
#   • XProtect: age-alone conflates "genuinely stale" with "Apple hasn't shipped". With auto-update ON the
#     freshness self-heals → 47d-but-latest is honestly OK, never crit; with auto-update OFF (the real risk)
#     the full age escalation applies. (Empirical: 5347 IS Apple's latest for macOS 26.5.2, auto-update on.)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="${THRESHOLD_COLLECTOR:-$DIR/../collectors/system-health-guardian.sh}"
[ -f "$COLLECTOR" ] || { echo "FATAL: collector not found: $COLLECTOR" >&2; exit 2; }

PASS=0; FAIL=0
ck() { # ck "<label>" "<got>" "<want>"
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: $1 → got '$2' want '$3'"; fi
}
cpu() { "$COLLECTOR" --cpu-load-status "$@" 2>/dev/null; }   # load1 load5 ncpu warn_ratio crit_ratio
xp()  { "$COLLECTOR" --xprotect-status "$@" 2>/dev/null; }   # age autoupdate warn crit selfheal

echo "── cpu_load_status (warn=load1 spiky · crit=load5 sustained) ──"
ck "burst load1=27 load5=6 12c → warn (NOT crit) [the false-crit fix]" "$(cpu 27.33 6.0 12 0.90 1.50)" "warn"
ck "sustained load5=20 12c → crit"                                     "$(cpu 20 20 12 0.90 1.50)"    "crit"
ck "calm load1=2 load5=2 12c → ok"                                     "$(cpu 2 2 12 0.90 1.50)"      "ok"
ck "warn-load1 + crit-load5 → crit"                                    "$(cpu 15 19 12 0.90 1.50)"    "crit"
ck "just-over-warn load1=11 load5=3 12c → warn"                        "$(cpu 11 3 12 0.90 1.50)"     "warn"
ck "load5 alone crit, load1 calm → crit (sustained detected)"          "$(cpu 3 19 12 0.90 1.50)"     "crit"
ck "at-warn-boundary load1=10.8 (0.90*12) → warn"                      "$(cpu 10.8 5 12 0.90 1.50)"   "warn"

echo "── xprotect_status (auto-update-gated freshness) ──"
ck "auto-ON 47d → ok (self-healing, <60 window) [the false-warn fix]"  "$(xp 47 on 30 60 60)"  "ok"
ck "auto-ON 65d → warn (unusually long)"                               "$(xp 65 on 30 60 60)"  "warn"
ck "auto-ON 9999d → warn (NEVER crit while self-healing)"              "$(xp 9999 on 30 60 60)" "warn"
ck "auto-OFF 47d → warn (the real risk surfaces)"                      "$(xp 47 off 30 60 60)" "warn"
ck "auto-OFF 65d → crit (real-risk escalation)"                        "$(xp 65 off 30 60 60)" "crit"
ck "auto-OFF 10d → ok"                                                 "$(xp 10 off 30 60 60)" "ok"

echo "── xprotect_status UNKNOWN (probe failed → fail-safe, warn-capable NEVER crit) [v1.4.1, CodeRabbit] ──"
ck "unknown 10d → ok (below warn)"                                     "$(xp 10 unknown 30 60 60)"   "ok"
ck "unknown 47d → warn (past warn horizon)"                            "$(xp 47 unknown 30 60 60)"   "warn"
ck "unknown 9999d → warn (NEVER crit — probe error ≠ false-crit)"      "$(xp 9999 unknown 30 60 60)" "warn"

echo
echo "threshold-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
