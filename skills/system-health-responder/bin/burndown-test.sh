#!/usr/bin/env bash
# burndown-test.sh — unit tests for the reclaim-aware burn-down forecast (EKO-90-round3).
# Drives the collector's `--burndown` entrypoint with synthetic disk-guardian logs (no awk duplication —
# the test exercises the exact production compute_burndown()). The RECLAIM-JUMP case is the critical
# assertion: a naïve slope over the raw series would read "recovering", but the forecast MUST isolate the
# post-reclaim declining tail and report "draining". macOS `date` (BSD) for timestamp generation.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="${BURNDOWN_COLLECTOR:-$DIR/../collectors/system-health-guardian.sh}"
[ -f "$COLLECTOR" ] || { echo "FATAL: collector not found: $COLLECTOR" >&2; exit 2; }

PASS=0; FAIL=0
tmpd="$(mktemp -d -t burndown-test.XXXXXX)"; trap 'rm -rf "$tmpd"' EXIT

# ts N_HOURS_AGO → "YYYY-MM-DDTHH:MM:SS±ZZZZ" in the disk-guardian log's format
ts() { date -v-"$1"H '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null; }

# build_log FILE  "<hours_ago>:<free_gb>"...  → writes guardian.log lines (newest last)
build_log() { local f="$1"; shift; : > "$f"
  for spec in "$@"; do
    printf '%s  HEARTBEAT healthy free=%sG cap=50%% — no action\n' "$(ts "${spec%%:*}")" "${spec##*:}" >> "$f"
  done; }

# run FILE → the burn_down JSON from the collector (warn threshold pinned to 15, big window)
run() { DISK_GUARDIAN_LOG="$1" BURNDOWN_WINDOW=48 DISK_FREE_WARN_GB=15 "$COLLECTOR" --burndown 2>/dev/null; }

jget() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1]))' "$1"; }

check() { # NAME  JSON  KEY  EXPECTED-substring
  local name="$1" js="$2" key="$3" want="$4" got
  got="$(printf '%s' "$js" | jget "$key" 2>/dev/null)"
  if printf '%s' "$got" | grep -qiF "$want"; then echo "  ✓ $name: $key=$got"; PASS=$((PASS+1))
  else echo "  ✗ $name: $key=$got (expected ~$want)  [full: $js]"; FAIL=$((FAIL+1)); fi
}

echo "=== burndown-test — collector: $COLLECTOR ==="

# ── Test 1: DECLINING (natural drain, no reclaim) — 100→75 over 5h, ~5 GB/hr ──
L="$tmpd/decline.log"
build_log "$L" 5:100 4:95 3:90 2:85 1:80 0:75
J="$(run "$L")"; echo "[1 declining] $J"
check "declining" "$J" trend  draining          # the drain is detected
check "declining" "$J" status crit              # drain 5 GB/hr, headroom 60 → 0.5d < 1d → crit
check "declining" "$J" days_to_threshold "0."   # ~0.5 days

# ── Test 2: RECLAIM-JUMP (the CRITICAL case) — 50→40 drain, +60 reclaim jump, then 100→90 drain ──
# Naïve slope over [50,45,40,100,95,90] is POSITIVE (rising) → would say "recovering" (WRONG).
# Reclaim-aware MUST isolate the post-jump tail [100,95,90] → "draining".
L="$tmpd/reclaim.log"
build_log "$L" 5:50 4:45 3:40 2:100 1:95 0:90
J="$(run "$L")"; echo "[2 reclaim-jump] $J"
check "reclaim-jump" "$J" trend draining                 # ⭐ must NOT be stable-or-recovering
check "reclaim-jump" "$J" free_gb 90                      # last value is the post-jump 90
if printf '%s' "$J" | grep -qi 'stable-or-recovering'; then
  echo "  ✗ reclaim-jump: MISREAD as recovering (the confounding bug!) [full: $J]"; FAIL=$((FAIL+1))
else echo "  ✓ reclaim-jump: NOT misread as recovering (reclaim-aware isolation works)"; PASS=$((PASS+1)); fi

# ── Test 3: FLAT/RISING (guardian keeping pace) — 100→106 rising ──
L="$tmpd/rising.log"
build_log "$L" 3:100 2:102 1:104 0:106
J="$(run "$L")"; echo "[3 rising] $J"
check "rising" "$J" trend stable-or-recovering
check "rising" "$J" days_to_threshold None       # null → python prints None

# ── Test 4: insufficient samples ──
L="$tmpd/thin.log"; build_log "$L" 1:100 0:99
J="$(run "$L")"; echo "[4 thin] $J"
check "thin" "$J" status unknown

# ── Test 5: RFC3339 colon-offset timestamps (+00:00) — the tz-normalization fallback ──
# BSD `date` emits +0000 (no colon); a producer drift to strict RFC3339 (+00:00) MUST still parse
# (collector v1.3.1 normalizes the trailing offset colon), NOT silently drop every sample → unknown.
ts_rfc() { ts "$1" | sed -E 's/([+-][0-9][0-9])([0-9][0-9])$/\1:\2/'; }   # -0300 → -03:00
Lr="$tmpd/rfc3339.log"; : > "$Lr"
for spec in 5:100 4:95 3:90 2:85 1:80 0:75; do
  printf '%s  HEARTBEAT healthy free=%sG cap=50%% — no action\n' "$(ts_rfc "${spec%%:*}")" "${spec##*:}" >> "$Lr"
done
J="$(run "$Lr")"; echo "[5 rfc3339 +00:00] $J"
# proves the colon-offset samples WERE parsed (else "unknown"/insufficient-samples): a declining series → draining
check "rfc3339" "$J" trend  draining
check "rfc3339" "$J" free_gb 75

echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
