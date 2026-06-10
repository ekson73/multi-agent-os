#!/usr/bin/env bash
# scorecard-next-model.sh — deterministic 1→7 round-robin selector for the
# postflight end-of-action scorecard (bin/scorecard.py has 7 layout models).
#
# WHY this exists (and why NOT inside scorecard.py):
#   scorecard.py is a PURE renderer by contract (same params → same output, no
#   side-effects). Rotation needs persistent state (a pointer), which is a
#   side-effect — so it lives HERE, outside the renderer, keeping it pure.
#
# WHY user-scope state (~/.claude/jobs/), not a repo file:
#   The goal (operator decision 2026-06-10: "deixe lançado em round-robin até eu
#   me acostumar e decidir") is to expose the OPERATOR to all 7 models over time
#   so they can pick a favourite. That exposure is operator-GLOBAL, not per-repo —
#   a repo-local pointer would cycle independently per repo and never give even
#   coverage. The pointer is therefore user-scope.
#
# Usage:
#   scorecard-next-model.sh             # advance the pointer + print next model id (1..7)
#   scorecard-next-model.sh --peek      # print the next model id WITHOUT advancing
#   scorecard-next-model.sh --current   # print the last-used model id (0 if none yet)
#   scorecard-next-model.sh --reset     # reset pointer to 0 (next advance → 1)
#   scorecard-next-model.sh -h|--help   # this header
#
# Override (pin a model, skip rotation entirely — mirrors the POSTFLIGHT_SPAWN=0 idiom):
#   export POSTFLIGHT_SCORECARD_MODEL=<1..7|cockpit|telemetry|...>
#     → validated against bin/scorecard.py (the model-registry SSOT); if valid, prints it
#       verbatim and NEVER touches the pointer (deterministic pin). An INVALID value (typo)
#       warns to stderr + falls back to round-robin, so it can never break the downstream
#       `scorecard.py --model` render (which rejects unknown values with exit 2).
#
# State file: ${POSTFLIGHT_SCORECARD_STATE:-$HOME/.claude/jobs/.postflight-scorecard-model}
#   A single integer (the last-used model id, 1..7; 0 = none yet). A missing or
#   invalid pointer is treated as 0 (next → 1). The write is atomic (temp-then-mv,
#   no torn file). Any failure degrades gracefully: a valid model is always printed
#   and the script always exits 0 — it must NEVER abort a session-end debrief.
#
# Bash 3.2-safe, self-contained. Composed by skills/postflight (P2 DEBRIEF).
# License: MIT (matches the multi-agent-os repo LICENSE).

N_MODELS=7
STATE="${POSTFLIGHT_SCORECARD_STATE:-$HOME/.claude/jobs/.postflight-scorecard-model}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || printf '.')"
SCORECARD="$DIR/scorecard.py"

# Is VALUE a model bin/scorecard.py accepts? Delegate to scorecard.py (the SSOT for the
# id/alias registry) rather than duplicating its alias list here (DRY — a local copy would
# drift). A stable numeric id (1..N_MODELS) needs no probe. If python3/scorecard.py are not
# available we cannot validate → accept (graceful; the selector must never block).
_is_valid_model() {
  case "$1" in
    '') return 1 ;;
    *[!0-9]*) ;;                                            # non-numeric → probe scorecard.py below
    *) if [ "$1" -ge 1 ] && [ "$1" -le "$N_MODELS" ]; then return 0; else return 1; fi ;;
  esac
  command -v python3 >/dev/null 2>&1 && [ -f "$SCORECARD" ] || return 0   # cannot probe → accept
  python3 "$SCORECARD" --model "$1" --demo --no-color >/dev/null 2>&1
}

# --- override: pin a model, skip rotation. Validate first so a typo can't break the
#     downstream `scorecard.py --model` render; an invalid value warns + falls through to
#     round-robin (never emits an unrenderable token, honouring the always-valid contract).
if [ -n "${POSTFLIGHT_SCORECARD_MODEL:-}" ]; then
  if _is_valid_model "$POSTFLIGHT_SCORECARD_MODEL"; then
    printf '%s\n' "$POSTFLIGHT_SCORECARD_MODEL"
    exit 0
  fi
  printf 'scorecard-next-model: ignoring invalid POSTFLIGHT_SCORECARD_MODEL=%s (not a scorecard.py model) — falling back to round-robin\n' "$POSTFLIGHT_SCORECARD_MODEL" >&2
fi

mode="${1:-advance}"

_read() {  # echo the sanitised last-used id (0..N_MODELS); unreadable/non-numeric/out-of-range → 0
  local v=0
  # Read ONLY a regular file (excludes FIFO/device/dir → cannot block) and ONLY its first
  # line (bounds a huge/garbage file → cannot stall) — preserves the "never abort" contract.
  if [ -f "$STATE" ]; then IFS= read -r v <"$STATE" 2>/dev/null || v=0; fi
  case "$v" in '' | *[!0-9]*) v=0 ;; esac
  if [ "$v" -gt "$N_MODELS" ] 2>/dev/null; then v=0; fi
  printf '%s' "$v"
}

_write() {  # atomic temp-then-mv; graceful (never errors out the caller)
  local v="$1" dir tmp
  dir="$(dirname "$STATE")"
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$STATE.tmp.$$"
  printf '%s\n' "$v" >"$tmp" 2>/dev/null && mv -f "$tmp" "$STATE" 2>/dev/null
  return 0
}

cur="$(_read)"
next=$(( cur % N_MODELS + 1 ))   # 0→1, 1→2, …, 7→1 (round-robin wrap)

case "$mode" in
  --peek)    printf '%s\n' "$next" ;;
  --current) printf '%s\n' "$cur" ;;
  --reset)   _write 0; printf '%s\n' "0" ;;
  -h|--help) sed -n '2,40p' "$0" ;;
  *)         _write "$next"; printf '%s\n' "$next" ;;
esac
exit 0
