#!/usr/bin/env sh
# dormancy-score.sh — the ONE net-new computation of the session-reentry skill (M1).
#
# Maps a dormant/foreign session to a 0.00–1.00 dormancy scalar that SCALES how
# deep the re-entry reconstruction must go (grounds Monk-Trafton resumption-lag).
# Composes NOTHING — this is the thin net-new bit ADR-009 flagged; everything else
# in the skill reuses existing primitives.
#
# Model (deterministic — same inputs → same score):
#   age_norm    = min(1.0, age_days / 21.0)        # 3 weeks untouched = fully cold on age
#   foreign_add = 0.30 if --foreign else 0.00      # a foreign mind needs deeper reconstruction
#   score       = min(1.0, round(age_norm + foreign_add, 2))
# Bands → recommended_depth:
#   fresh <0.25 → L1 · warm 0.25–0.55 → L2 · deep 0.55–0.80 → L3 · cold >0.80 → full
#
# Usage:
#   dormancy-score.sh <session-path> [--foreign] [--now <epoch>] [--mtime <epoch>]
#   --mtime : artifact mtime epoch (default: newest file mtime under <session-path>)
#   --now   : reference "now" epoch (default: current time) — inject for deterministic tests
#   --foreign : the re-entering mind is NOT the author (escalates depth)
#
# Output: a single-line JSON envelope on stdout (the M1 output contract).
# License: MIT (matches multi-agent-os repo LICENSE).
set -eu

PATH_ARG=""; FOREIGN=0; NOW=""; MTIME=""
is_uint() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
# Self-shifting cases (shift 2 for value-flags) — no trailing loop-shift, so a
# value-flag as the LAST arg cannot trigger a set -e double-shift crash.
while [ $# -gt 0 ]; do
  case "$1" in
    --foreign) FOREIGN=1; shift ;;
    --now)     [ $# -ge 2 ] || { echo "[dormancy-score] --now needs an epoch value" >&2; exit 2; }; NOW="$2"; shift 2 ;;
    --mtime)   [ $# -ge 2 ] || { echo "[dormancy-score] --mtime needs an epoch value" >&2; exit 2; }; MTIME="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)       echo "[dormancy-score] unknown flag: $1" >&2; exit 2 ;;
    *)         [ -z "$PATH_ARG" ] || { echo "[dormancy-score] too many positional args: '$1'" >&2; exit 2; }; PATH_ARG="$1"; shift ;;
  esac
done

[ -n "$PATH_ARG" ] || { echo "[dormancy-score] missing <session-path>" >&2; exit 2; }

# Portable newest-mtime: BSD/macOS `stat -f %m` vs GNU/Linux `stat -c %Y`.
stat_mtime() {  # stat_mtime <file> -> epoch
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

if [ -z "$MTIME" ]; then
  if [ -d "$PATH_ARG" ]; then
    # newest file mtime under the dir (deterministic given the tree)
    MTIME="$(find "$PATH_ARG" -type f -exec sh -c 'for f; do stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null; done' _ {} + 2>/dev/null | sort -nr | head -n 1)"
  elif [ -e "$PATH_ARG" ]; then
    MTIME="$(stat_mtime "$PATH_ARG")"
  else
    echo "[dormancy-score] path not found: $PATH_ARG" >&2; exit 2
  fi
fi
[ -n "${MTIME:-}" ] || { echo "[dormancy-score] could not determine mtime for: $PATH_ARG" >&2; exit 2; }
is_uint "$MTIME" || { echo "[dormancy-score] --mtime must be epoch seconds (got '$MTIME')" >&2; exit 2; }

[ -n "$NOW" ] || NOW="$(date +%s)"
is_uint "$NOW" || { echo "[dormancy-score] --now must be epoch seconds (got '$NOW')" >&2; exit 2; }

# Float math + banding via awk (POSIX-portable, deterministic).
awk -v now="$NOW" -v mtime="$MTIME" -v foreign="$FOREIGN" 'BEGIN {
  age_days = (now - mtime) / 86400.0
  if (age_days < 0) age_days = 0            # future mtime → treat as fresh
  age_norm = age_days / 21.0
  if (age_norm > 1.0) age_norm = 1.0
  fadd = (foreign == 1) ? 0.30 : 0.00
  score = age_norm + fadd
  if (score > 1.0) score = 1.0
  score = int(score * 100 + 0.5) / 100.0    # round to 2 decimals (deterministic)
  if      (score < 0.25) { band="fresh"; depth="L1" }
  else if (score < 0.55) { band="warm";  depth="L2" }
  else if (score <= 0.80){ band="deep";  depth="L3" }
  else                   { band="cold";  depth="full" }
  fbool = (foreign == 1) ? "true" : "false"
  printf "{ \"score\": %.2f, \"band\": \"%s\", \"age_days\": %d, \"foreign\": %s, \"recommended_depth\": \"%s\", \"signals\": { \"mtime_days\": %d, \"foreign_author\": %s } }\n", \
    score, band, int(age_days+0.5), fbool, depth, int(age_days+0.5), fbool
}'
