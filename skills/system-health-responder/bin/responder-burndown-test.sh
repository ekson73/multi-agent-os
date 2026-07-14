#!/usr/bin/env bash
# responder-burndown-test.sh — proves the responder ACTS on the top-level `.burn_down` leading
# indicator (EKO-90 round-3). `burn_down` is NOT a `.system.branches` leaf → it does not feed
# `.system.status`, so without explicit wiring a `burn_down:warn` while all branches are `ok` would
# be silently swallowed by the `system.status==ok` early-return (the "documented-but-inert" theater
# a guardian must not ship). These tests pin that wiring. DRY-RUN + tmp state + NOTIFY=0 (no seeds/
# notifications escape the sandbox).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESP="${RESPONDER:-$DIR/health-respond.sh}"
[ -f "$RESP" ] || { echo "FATAL: responder not found: $RESP" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq required" >&2; exit 2; }

PASS=0; FAIL=0
tmpd="$(mktemp -d -t responder-bd-test.XXXXXX)"; trap 'rm -rf "$tmpd"' EXIT

# run CONTRACT_JSON → responder stdout (DRY-RUN default; isolated state; no notifications)
run() {
  local c="$tmpd/contract.json"; printf '%s' "$1" > "$c"
  SHR_CONTRACT="$c" SHR_STATE_DIR="$tmpd/state" SHR_LOG="$tmpd/resp.log" NOTIFY=0 \
    bash "$RESP" 2>/dev/null
}
has()  { printf '%s' "$1" | grep -qiF "$2" && { echo "  ✓ $3"; PASS=$((PASS+1)); } || { echo "  ✗ $3  [out: $1]"; FAIL=$((FAIL+1)); }; }
lacks(){ printf '%s' "$1" | grep -qiF "$2" && { echo "  ✗ $3  [out: $1]"; FAIL=$((FAIL+1)); } || { echo "  ✓ $3"; PASS=$((PASS+1)); }; }

echo "=== responder-burndown-test — responder: $RESP ==="

# ── Test 1: burn_down=warn while system.status=ok → MUST surface (not early-return-swallowed) ──
OK_WARN='{"system":{"status":"ok"},"burn_down":{"status":"warn","trend":"draining","drain_gb_per_hr":2.1,"days_to_threshold":3.4,"threshold_gb":15}}'
O="$(run "$OK_WARN")"; echo "[1 ok+warn] $(printf '%s' "$O" | tr '\n' ' ')"
lacks "$O" "nothing to do" "did NOT early-return-swallow the burn_down warn"
has   "$O" "burn_down=warn" "header reports burn_down=warn"

# ── Test 2: burn_down=crit → surfaced as residue leading indicator ──
OK_CRIT='{"system":{"status":"ok"},"burn_down":{"status":"crit","trend":"draining","drain_gb_per_hr":9.0,"days_to_threshold":0.4,"threshold_gb":15}}'
O="$(run "$OK_CRIT")"; echo "[2 ok+crit] $(printf '%s' "$O" | tr '\n' ' ')"
has "$O" "burn-down=crit" "crit forecast surfaced in residue"

# ── Test 3: all-ok + burn_down=ok → correct clean-path early-return (didn't break the happy path) ──
ALL_OK='{"system":{"status":"ok"},"burn_down":{"status":"ok","trend":"stable-or-recovering","days_to_threshold":null}}'
O="$(run "$ALL_OK")"; echo "[3 all-ok] $(printf '%s' "$O" | tr '\n' ' ')"
has "$O" "nothing to do" "clean path still early-returns (no false residue)"

# ── Test 4: burn_down=unknown while system.status=ok → clean-path (unknown ≠ warn/crit) ──
OK_UNK='{"system":{"status":"ok"},"burn_down":{"status":"unknown","reason":"insufficient-samples"}}'
O="$(run "$OK_UNK")"; echo "[4 ok+unknown] $(printf '%s' "$O" | tr '\n' ' ')"
has "$O" "nothing to do" "unknown burn_down does not trigger action (honest, not noisy)"

echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
