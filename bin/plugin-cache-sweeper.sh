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
BAD_OPT=""   # set by the arg loop when an option's value is absent/empty; gate -3 refuses on it

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)    APPLY=1 ;;
    # ⛔ A MISSING value must NOT fall back to the default. `--cache` with nothing after it used to
    #    silently keep the DEFAULT cache — so `--apply --cache` (value lost to a typo, an unquoted
    #    empty shell var, or a truncated wrapper) aimed the deletion at the operator's REAL plugin
    #    cache while the envelope reported that path as if it had been requested. `${1:-default}`
    #    cannot distinguish "absent" from "empty"; both are refusals here (coderabbit #282 round 2).
    --age-min)  if [ $# -ge 2 ] && [ -n "${2:-}" ]; then shift; AGE_MIN="$1"; else BAD_OPT="--age-min"; break; fi ;;
    --cache)    if [ $# -ge 2 ] && [ -n "${2:-}" ]; then shift; CACHE="$1";   else BAD_OPT="--cache";   break; fi ;;
    -h|--help)  sed -n '2,45p' "$0"; exit 0 ;;
    *)          printf 'unknown argument: %s (try --help)\n' "$1" >&2; exit 0 ;;
  esac
  shift
done

# JSON-escape a string field. The cache path is caller-supplied (--cache / PCS_CACHE)
# and a quote or backslash in it would otherwise terminate the field early and emit
# malformed JSON to a machine consumer.
# JSON-escape a string field: backslash, quote, tab, and embedded newlines.
# ⛔ RAW C0 CONTROL CHARS ARE REJECTED UPSTREAM, NOT ESCAPED HERE (see the reject gate below).
#    RFC 8259 forbids U+0000-U+001F raw inside a string, and a `\uXXXX` escaper written in awk
#    is a TRAP: awk strings cannot hold NUL, so a 32-entry lookup table silently SHIFTS and the
#    envelope then parses cleanly while decoding the WRONG byte (measured: \x01 decoded as \x00,
#    \x0b as \t — a collision). Valid JSON pointing at a byte the caller never passed is worse
#    than invalid JSON: the first fails loudly, the second lies. A cache path has no legitimate
#    use for a control char, so the honest handling is to refuse the input (Gordian).
json_esc() {
  printf '%s' "$1" | awk 'BEGIN{ORS=""}
    { gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t")
      if (NR>1) printf "\\n"
      printf "%s", $0 }'
}


emit() { # emit <swept> <would> <young> <refused> <remaining> <freed_mb> <inuse> <note>
  printf '{"tool":"plugin-cache-sweeper","cache":"%s","mode":"%s","age_min":%s,' \
    "$(json_esc "$CACHE")" "$([ "$APPLY" -eq 1 ] && echo apply || echo report)" "$AGE_MIN"
  printf '"swept":%s,"would_sweep":%s,"too_young":%s,"refused":%s,' "$1" "$2" "$3" "$4"
  printf '"remaining":%s,"freed_mb":%s,"in_use":%s,"note":"%s"}\n' "$5" "$6" "$7" "$(json_esc "$8")"
}

# gate -3 — an option whose value was absent or empty. MUST come first: the later gates read
# $CACHE/$AGE_MIN, and acting on a value the caller never supplied is the whole defect.
if [ -n "$BAD_OPT" ]; then
  emit 0 0 0 0 0 0 0 "missing-option-value"
  printf 'plugin-cache-sweeper: %s requires a non-empty value — nothing swept\n' "$BAD_OPT" >&2
  exit 0
fi

# gate -2 — refuse a CACHE path carrying a raw C0 control char. Fails CLOSED (sweeps nothing,
# reports, exits 0) exactly like the age gate: a path we cannot faithfully serialize is a path we
# must not act on. `tr -d` keeps the comparison byte-exact and needs no locale assumption.
# ⛔ MUST sit AFTER emit() is defined — placed above it this called an undefined function and
#    emitted NOTHING at all (measured: `emit: command not found`, empty stdout, so a machine
#    consumer got no envelope instead of a refusal). A fail-closed gate that cannot report is a
#    silent exit, not a guard.
if [ "$(printf '%s' "$CACHE" | LC_ALL=C tr -d '\001-\037' | wc -c)" != "$(printf '%s' "$CACHE" | wc -c)" ]; then
  # ⛔ SANITIZE BEFORE REPORTING — the refusal envelope must itself be parseable. Emitting the
  #    offending path verbatim reproduced the exact defect being refused (measured: the gate fired
  #    correctly, note=invalid-cache-path swept=0, yet `python json.load` still rejected the output
  #    at the `cache` field). A guard whose own report is malformed hands the machine consumer
  #    nothing to act on. `?` marks each removed byte so the path stays recognizable to a human.
  CACHE="$(printf '%s' "$CACHE" | LC_ALL=C tr '\001-\037' '?')"
  emit 0 0 0 0 0 0 0 "invalid-cache-path"
  printf 'plugin-cache-sweeper: --cache contains a control character — nothing swept\n' >&2
  exit 0
fi

# gate -1 — the age floor must be a non-negative integer BEFORE it reaches the
# envelope. `age_min` is a JSON *number* field, so a non-numeric value is
# interpolated raw and produces invalid JSON (a crafted value injects arbitrary
# text into a machine-parsed envelope). Fail CLOSED: sweep nothing, report the
# refusal, and still exit 0 — the never-fail-a-session guarantee is unconditional.
case "$AGE_MIN" in
  ''|*[!0-9]*)
    BAD_AGE="$AGE_MIN"; AGE_MIN=0
    emit 0 0 0 0 0 0 0 "invalid-age-min"
    printf 'plugin-cache-sweeper: --age-min must be a non-negative integer (got %s) — nothing swept\n' \
      "$BAD_AGE" >&2
    exit 0 ;;
esac

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
# INUSE_OK is the gate-4 TRUST flag, not a convenience: the empty-set and the
# could-not-look cases are indistinguishable in `INUSE` alone, and reading a
# blind "" as "nothing is open" is the free-negative that turns a safety gate
# into a no-op precisely when it matters. Only a probe that RAN may license a
# delete; absent/timed-out `lsof` ⇒ gate 4 refuses everything under --apply.
INUSE_OK=0
if command -v lsof >/dev/null 2>&1; then
  # Capture lsof SEPARATELY from the filter. Piping them together conflates two
  # opposite meanings into one rc: `grep -o` exits 1 on NO MATCH, which is the
  # HEALTHY common case (nothing open) — reading that as "the probe failed" would
  # refuse every delete forever. Only lsof's own rc may clear the trust flag.
  RAW="$($TB lsof -n -w -F n 2>/dev/null)"; LSOF_RC=$?
  if [ "$LSOF_RC" -eq 0 ]; then
    INUSE_OK=1
    # ⛔ SCOPE TO $BOUND BEFORE NAME-MATCHING. lsof reports every open path on the machine, and
    #    gate 4 compares BASENAMES — so an open file in an unrelated directory that merely SHARES a
    #    candidate's name refused the legitimate in-cache candidate forever (measured: a namesake
    #    held open outside the cache → swept=0 refused=1 in_use=1, the in-cache orphan blocked).
    #    Filter to `$BOUND/` paths FIRST (keeping the full path through the boundary test), then
    #    derive names only from what survived. Over-refusing is safer than over-deleting, but a
    #    permanent false refusal makes the sweeper useless at its one job.
    # ⛔ THE IN-USE FILTER MUST ADMIT *EXACTLY* THE CANDIDATE CLASS — `temp_*`, the same glob the
    #    enumeration (`find -name 'temp_*'`) and gate 0 (`case "$b" in temp_*)`) use. A NARROWER
    #    pattern here is FAIL-OPEN, not strict: gate 4 compares whole basenames, so any held-open
    #    candidate the pattern drops becomes INVISIBLE to the gate and is deleted WHILE IN USE.
    #    Measured on a 5-dir fixture — a prior `temp_[a-z]*_[0-9]*_[a-z0-9]*(\.clone)?` matcher let
    #    3 of 3 held-open candidates through (`temp_weird` no-epoch · `temp_UPPER_123_x` uppercase ·
    #    `temp_a-b_123_x` hyphen): each IS a candidate, each was open, and the gate saw NONE of them.
    #    ⚠️ Tightening the epoch segment (e.g. requiring exactly 13 digits) moves in the WRONG
    #    direction — it shrinks the admitted set, so it ADDS members to that invisible set.
    #    The asymmetry is the bug: any divergence between "what we may delete" and "what we check
    #    for use" is a silent exemption. Keep both sides on ONE class, and let the LATER gates
    #    (embedded-epoch age, boundary, ownership) do the narrowing — they refuse, they never exempt.
    # ⛔ NEVER INTERPOLATE $BOUND INTO A REGEX. The previous extraction embedded it in a `sed`
    #    s|…|…| expression, so any `|` in the cache path became the DELIMITER: measured with
    #    `--cache '/tmp/cache|with-pipe'`, sed died (`bad flag in substitute command`), INUSE came
    #    back EMPTY, `INUSE_OK=1` was still trusted (assigned on lsof's rc alone, before the
    #    filter), and a held-open candidate was DELETED — `swept:1 in_use:0` with a live handle.
    #    Escaping `|` would only patch this delimiter; the defect is the regex itself, whose
    #    metacharacter set is unbounded relative to what a filesystem path may legally contain.
    #    ⇒ Strip the prefix with shell parameter expansion (${line#"$BOUND"/}) — no regex, no
    #    delimiter, nothing to escape — and derive the basename by cutting at the first `/`.
    #    The quotes in ${line#"$BOUND"/} are load-bearing: unquoted, $BOUND would be read as a
    #    PATTERN and a path containing `*`/`?`/`[` would strip the wrong prefix.
    # ⛔ AND MAKE FILTER FAILURE CLEAR THE TRUST FLAG. `INUSE_OK=1` on lsof's rc alone means "I
    #    looked", not "I parsed what I saw" — the gap the pipe exploited. Any failure while
    #    building the set now sets INUSE_OK=0, so gate 4 refuses instead of trusting a blind "".
    # ⛔ BALANCED-PAREN case patterns — `(pat)` not `pat)`. Bash 3.2 (the macOS system bash, and
    #    this file's declared floor) mis-parses an UNBALANCED `)` inside `$( )`: measured, the
    #    substitution died with `syntax error near unexpected token 'newline'`, INUSE captured the
    #    literal REST OF THE SOURCE TEXT, and the script then aborted on `b: unbound variable`.
    #    ⚠️ That abort LOOKED like a pass — the held-open candidate "survived" because the process
    #    died before the sweep, not because gate 4 refused it. Only the positive control (a plain
    #    path must still RECLAIM) exposed it: it over-refused too, i.e. the tool was simply broken.
    INUSE="$(
      printf '%s\n' "$RAW" | while IFS= read -r line; do
        case "$line" in (n"$BOUND"/*) ;; (*) continue ;; esac
        rest="${line#n}"; rest="${rest#"$BOUND"/}"
        b="${rest%%/*}"
        case "$b" in (temp_*) printf '%s\n' "$b" ;; esac
      done | sort -u
    )" || INUSE_OK=0
  fi
  unset RAW
fi
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

  # gate 4 — not currently open by any process.
  # -F is load-bearing: a candidate name can contain `.` (…_<rand>.clone) and as a
  # REGEX that dot matches any character, so a plain -x compare could match the
  # wrong entry. Fixed-string keeps the comparison literal.
  printf '%s\n' "$INUSE" | grep -Fqx "$b" && { refused=$((refused+1)); continue; }
  # …and if the probe never RAN, we do not know. Under --apply that unknown is a
  # refusal, not a pass: an untrusted gate must not license an irreversible delete.
  # Report mode still counts the candidate (it deletes nothing by construction).
  [ "$APPLY" -eq 1 ] && [ "$INUSE_OK" -eq 0 ] && { refused=$((refused+1)); continue; }

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
