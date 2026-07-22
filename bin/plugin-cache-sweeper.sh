#!/usr/bin/env bash
# MAOS — plugin-cache-sweeper · reclaim orphaned Claude Code plugin staging clones
# ----------------------------------------------------------------------------
# WHY: the Claude Code plugin manager clones each marketplace into a staging
#   directory under the plugin cache and does not remove it once the operation
#   succeeds. They accumulate without bound. Measured on one workstation:
#   1318 orphaned clones / ~8.0 GB over 8 days, ~20-30 new per hour of active
#   use, contributing to a full-disk condition. Upstream report:
#   anthropics/claude-code#80367. This script is the local stanch until that
#   lands — and stays useful afterwards for crash-interrupted operations.
#
# GUARANTEES:
#   READ-ONLY BY DEFAULT. Without --apply this script deletes NOTHING; it only
#   reports what it would remove. Deletion requires the explicit --apply flag.
#   Exit is ALWAYS 0 — a housekeeping sweeper must never fail a session or a
#   scheduled cycle. Problems are reported in the envelope, not via exit codes.
#
# WHAT IT REMOVES (only with --apply, and only past all five gates):
#   <cache>/temp_git_<epoch_ms>_<rand>          marketplace git clones
#   <cache>/temp_subdir_<epoch_ms>_<rand>.clone subdir-extraction clones
#   <cache>/temp_github_<epoch_ms>_<rand>       github-source clones
#   All are complete git working trees with a valid `origin` — re-clonable, and
#   referenced by NO plugin configuration. Installed plugins are served from the
#   versioned <cache>/<marketplace>/<version>/ directories, never from these.
#
# WHAT IT NEVER TOUCHES:
#   <cache>/<marketplace>/    the real installs
#   anything outside <cache>  (physical-path boundary check, gate 3)
#   any name not starting with `temp_`                              (gate 0)
#   anything younger than the age floor                             (gate 1)
#   anything a symlink                                              (gate 2)
#   anything with an open file handle                               (gate 4)
#
# Portability: AAIF cross-vendor — POSIX Bash 3.2, no jq required. `timeout` and
#   `lsof` are probed and degrade gracefully when absent.
#
# Usage:
#   plugin-cache-sweeper.sh                 # report only (safe default)
#   plugin-cache-sweeper.sh --apply         # actually reclaim
#   plugin-cache-sweeper.sh --age-min 60    # override the 180-min age floor
#   plugin-cache-sweeper.sh --cache <dir>   # override cache location
#
# Output: JSON envelope on stdout, 1-line human summary on stderr.
set -uo pipefail

# ── configuration ───────────────────────────────────────────────────────────
CACHE="${PCS_CACHE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache}"
AGE_MIN="${PCS_AGE_MIN:-180}"
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)    APPLY=1 ;;
    --age-min)  shift; AGE_MIN="${1:-180}" ;;
    --cache)    shift; CACHE="${1:-$CACHE}" ;;
    -h|--help)  sed -n '2,45p' "$0"; exit 0 ;;
    *)          printf 'unknown argument: %s (try --help)\n' "$1" >&2; exit 0 ;;
  esac
  shift
done

emit() { # emit <swept> <would> <young> <refused> <remaining> <freed_mb> <inuse> <note>
  printf '{"tool":"plugin-cache-sweeper","cache":"%s","mode":"%s","age_min":%s,' \
    "$CACHE" "$([ "$APPLY" -eq 1 ] && echo apply || echo report)" "$AGE_MIN"
  printf '"swept":%s,"would_sweep":%s,"too_young":%s,"refused":%s,' "$1" "$2" "$3" "$4"
  printf '"remaining":%s,"freed_mb":%s,"in_use":%s,"note":"%s"}\n' "$5" "$6" "$7" "$8"
}

[ -d "$CACHE" ] || { emit 0 0 0 0 0 0 0 "cache-absent"; printf 'plugin-cache-sweeper: no cache at %s\n' "$CACHE" >&2; exit 0; }

# Resolve the boundary ONCE, physically. Every candidate must resolve inside it.
BOUND="$(cd "$CACHE" 2>/dev/null && pwd -P)" || { emit 0 0 0 0 0 0 0 "cache-unresolvable"; exit 0; }

free_mb() { df -m "$BOUND" 2>/dev/null | awk 'NR==2{print $4+0}'; }

# ── in-use detection ────────────────────────────────────────────────────────
# /** [decision] ONE GLOBAL lsof filtered by path — never `lsof +D <cache>`.
#  *  @context  MEASURED: `lsof +D` on a 565-clone cache exceeded 120 s and had
#  *            to be killed; the global pass answering the same question took 1 s.
#  *  @reason   `+D` is not "who holds this directory" — it DESCENDS the tree and
#  *            stats every file, so its cost scales with CONTENT (hundreds of git
#  *            clones x thousands of objects each), not with candidate count. The
#  *            global form reads the kernel's open-file table (bounded regardless
#  *            of what is on disk) and filters by path afterwards, in text.
#  *  @impact   Inverting the question — from "what is open INSIDE this dir" to
#  *            "of everything open, what falls under this path" — trades a disk
#  *            walk for a state read. Same answer, two orders of magnitude cheaper.
#  *  @impact   Hard timeout on top: a sweeper that HANGS is worse than one that
#  *            skips a gate. On timeout/absence the in-use set is empty and gate 4
#  *            degrades to a no-op — tolerable only because the age floor already
#  *            excludes in-flight work. */
TB=""; command -v timeout >/dev/null 2>&1 && TB="timeout 25"
INUSE=""
command -v lsof >/dev/null 2>&1 && \
  INUSE="$($TB lsof -n -w -F n 2>/dev/null | grep -o "temp_[a-z]*_[0-9]*_[a-z0-9]*" | sort -u)"
# NOT `grep -c . || echo 0`: grep -c ALWAYS prints the count and exits 1 when that
# count is zero, so the `||` fires too and the value becomes "0\n0". awk always
# exits 0 and always prints exactly one number.
INUSE_N=$(printf '%s' "$INUSE" | awk 'NF{n++} END{print n+0}')

# ── sweep ───────────────────────────────────────────────────────────────────
BEFORE="$(free_mb)"
swept=0; would=0; young=0; refused=0
CUTOFF=$(( $(date +%s) - AGE_MIN * 60 ))

while IFS= read -r t; do
  [ -n "$t" ] || continue
  b="$(basename "$t")"

  # gate 0 — the name must literally be staging (belt-and-suspenders over the glob)
  case "$b" in temp_*) : ;; *) refused=$((refused+1)); continue ;; esac

  # gate 1 — age, read from the name's EMBEDDED EPOCH, not from mtime.
  # /** [decision] the name carries a more trustworthy clock than the filesystem.
  #  *  @context  These dirs are named temp_<kind>_<epoch_ms>_<rand>. That epoch is
  #  *            the true birth time and is IMMUTABLE. mtime is a different clock:
  #  *            it moves on any content change — INCLUDING a partial deletion.
  #  *  @reason   MEASURED: 14 orphans born over a previous week all showed an mtime
  #  *            from the same recent minute and each held exactly 1 entry —
  #  *            carcasses of an `rm -rf` killed mid-flight. An interrupted cleanup
  #  *            REJUVENATES its own victim, so an mtime gate permanently shields
  #  *            the safest garbage on disk (an emptied dir) while happily
  #  *            considering intact clones. Exactly backwards.
  #  *  @impact   Reading the immutable clock costs zero syscalls and cannot be
  #  *            reset by a failed sweep. Falls back to mtime only when the name
  #  *            has no parseable epoch (unknown format ⇒ stay conservative). */
  ms="$(printf '%s' "$b" | sed -n 's/.*_\([0-9]\{13\}\)_.*/\1/p')"
  if [ -n "$ms" ]; then
    [ $(( ms / 1000 )) -gt "$CUTOFF" ] && { young=$((young+1)); continue; }
  else
    find "$t" -maxdepth 0 -mmin -"$AGE_MIN" 2>/dev/null | grep -q . && { young=$((young+1)); continue; }
  fi

  # gate 2 — must be a real directory, never a symlink we would traverse
  [ -d "$t" ] || { refused=$((refused+1)); continue; }
  [ -L "$t" ] && { refused=$((refused+1)); continue; }

  # gate 3 — the PHYSICAL path must resolve inside the boundary
  #          (defeats `..` components and symlinked parents)
  r="$(cd "$t" 2>/dev/null && pwd -P)" || { refused=$((refused+1)); continue; }
  case "$r" in "$BOUND"/*) : ;; *) refused=$((refused+1)); continue ;; esac

  # gate 4 — not currently open by any process
  printf '%s\n' "$INUSE" | grep -qx "$b" && { refused=$((refused+1)); continue; }

  if [ "$APPLY" -eq 1 ]; then
    rm -rf -- "$t" 2>/dev/null && swept=$((swept+1)) || refused=$((refused+1))
  else
    would=$((would+1))
  fi
done <<EOF
$(find "$CACHE" -maxdepth 1 -mindepth 1 -name 'temp_*' 2>/dev/null | sort)
EOF

AFTER="$(free_mb)"
REMAIN=$(find "$CACHE" -maxdepth 1 -mindepth 1 -name 'temp_*' 2>/dev/null | wc -l | tr -d ' ')
# Report the free-space DELTA, never a `du` estimate: on APFS a clonefile is a
# separate inode sharing blocks, so du counts every copy in full and systematically
# over-reports clone-heavy trees. The delta is what the filesystem cannot misstate.
# In report mode we deleted nothing, so freed MUST be 0 by definition. Without this
# the df delta leaks noise from OTHER processes into the field and the envelope claims
# space was reclaimed by a run that touched nothing — a small lie, but the kind that
# teaches a reader to stop trusting the number.
if [ "$APPLY" -eq 1 ]; then
  FREED=$(( ${AFTER:-0} - ${BEFORE:-0} )); [ "$FREED" -lt 0 ] && FREED=0
else
  FREED=0
fi

emit "$swept" "$would" "$young" "$refused" "$REMAIN" "$FREED" "$INUSE_N" "ok"
if [ "$APPLY" -eq 1 ]; then
  printf 'plugin-cache-sweeper: swept %s (too-young %s, refused %s), freed ~%s MB, %s left\n' \
    "$swept" "$young" "$refused" "$FREED" "$REMAIN" >&2
else
  printf 'plugin-cache-sweeper: would sweep %s (too-young %s, refused %s) of %s present — re-run with --apply\n' \
    "$would" "$young" "$refused" "$REMAIN" >&2
fi
exit 0
