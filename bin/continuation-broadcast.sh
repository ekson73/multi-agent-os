#!/usr/bin/env bash
# /**
#  * multi-agent-os · bin/continuation-broadcast.sh   (postflight P3.6 — BROADCAST)
#  * @context End-of-session continuation: postflight P3 emits a continuation SEED and P2.5 files
#  *          a continuation TICKET. This script BROADCASTS a bounded, structured, idempotent
#  *          back-pointer MARKER — an *additional discovery sink* of that ONE canonical seed/ticket
#  *          — into selected work artifacts (the exit commit's trailer, the open PR body, and,
#  *          only under --scope all, caller-named docs/changelogs) so a fresh amnesic agent that
#  *          lands on the artifact DISCOVERS there is pending work + where to resume it.
#  * @reason  The seed/ticket are the SSOT, but a fresh agent opening a commit/PR/doc doesn't know
#  *          to look for them. The marker makes the tracked continuation *discoverable at the point
#  *          of future contact* — it is exit-hygiene's "registered with traceability" (Axiom 4 +
#  *          Delegation gate) surfaced where it will be found. It is NOT a free-form "fix next
#  *          session" TODO: it is structured, back-pointer-only (duplicates no content), and
#  *          idempotent (upsert, never append-duplicate). Reconciliation: docs/adrs/ADR-010.
#  * @impact  Reads/writes ONLY: stdout (the commit-trailer text), the named PR body (via gh,
#  *          idempotent upsert), and caller-named --file targets (--scope all only; ADRs REFUSED
#  *          — a decision record is not a transient worklist). --dry-run is the DEFAULT (writes
#  *          nothing); mutation requires --apply. Guardrails: kill-switch · dry-run-default ·
#  *          idempotent-upsert · ADR-refusal · payload-sanitization (metadata-only) · audit-trail.
#  * @note    DRY: consumes postflight's P3 seed path + P2.5 ticket key — it does NOT generate them
#  *          (never re-implements the seed/ticket). It only points AT them.
#  * @version 0.2.0
#  * @hardening v0.2.0 — MoE-council security pass: upsert is fail-closed on malformed/duplicated
#  *          sentinels (never mass-deletes to EOF); sentinel/newline-injected payloads refused;
#  *          symlink + case-insensitive + MADR `decisions/` ADR-refusal; `shift 2` arg-guards;
#  *          mktemp fail-closed (no predictable /tmp); the seed referent is VERIFIED (no unbacked
#  *          marker); the block is byte-idempotent (no churning timestamp) + self-cleans when stale.
#  * Portability: AAIF cross-vendor — POSIX Bash 3.2; jq NOT required; no associative arrays.
#  * Exit codes ([C06]): 0 success/graceful-noop · 1 usage/validation · 2 setup/write-fail.
#  */
set -uo pipefail   # NOT -e: a fallible sink must reach its skip-with-note path, never abort the run.

SENTINEL_START='<!-- MAOS-CONTINUE:START -->'
SENTINEL_END='<!-- MAOS-CONTINUE:END -->'
TRAILER_TOKEN='Continue-Here'

# ── self-contained json-escape (match spawn-continuation / precompact convention) ──
json_escape() {
  local s="$1"; s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}; printf '%s' "$s"
}

usage() {
  cat <<EOF
continuation-broadcast — inject a structured, idempotent continuation back-pointer MARKER into
work artifacts (postflight P3.6 BROADCAST). Points at the ONE canonical continuation ticket/seed;
never free-form. --dry-run is the DEFAULT (mutation requires --apply). Reconciliation: docs/adrs/ADR-010.

Usage:
  $(basename "$0") (--ticket <KEY> | --seed <path>) [options]

Pointer (at least one required — nothing to point at otherwise):
  --ticket <KEY>     the P2.5 continuation ticket key (e.g. VKS-123) or 'none'
  --seed <path>      the P3 continuation seed file (repo-relative preferred; abs is relativized)

Sinks:
  --scope <s>        conservative (default) = commit-trailer + PR-body only (exit-hygiene-safe)
                     all                    = ALSO the caller-named --file targets (ADRs refused)
  --pr <N>           PR number → idempotent-upsert the marker block into the PR body (needs gh)
  --file <path>      a file sink (repeatable; honored ONLY under --scope all; ADR paths refused)
  --session <id>     source session id for the marker payload (default: \$CLAUDE_CODE_SESSION_ID)

Mode:
  --dry-run          print what WOULD be written; touch nothing            (DEFAULT)
  --apply            actually write the enabled sinks
  --help

Guardrails:
  MAOS_BROADCAST=0   hard kill-switch — never broadcast (deterministic opt-out).

The commit-trailer is always printed to stdout (append it to the exit commit message):
  $TRAILER_TOKEN: <KEY> · seed:<relpath>
EOF
  exit "${1:-0}"
}

# ── parse args ────────────────────────────────────────────────────────────────
TICKET="" SEED="" SCOPE="conservative" PR="" SESSION="" APPLY=0
FILES=""   # newline-separated (Bash 3.2: no arrays needed for append+iterate)
# A value-expecting flag as the LAST arg must NOT `shift 2` past $#=1 (bash 3.2 errors,
# $# stays, the case re-reads the same flag → infinite loop). Guard the value's presence.
_need2() { [ "$1" -ge 2 ] || { printf 'continuation-broadcast: %s requires a value\n' "$2" >&2; usage 1; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket)   _need2 "$#" --ticket;  TICKET="$2"; shift 2 ;;
    --seed)     _need2 "$#" --seed;    SEED="$2"; shift 2 ;;
    --scope)    _need2 "$#" --scope;   SCOPE="$2"; shift 2 ;;
    --pr)       _need2 "$#" --pr;      PR="$2"; shift 2 ;;
    --file)     _need2 "$#" --file;    FILES="${FILES}${2}"$'\n'; shift 2 ;;
    --session)  _need2 "$#" --session; SESSION="$2"; shift 2 ;;
    --apply)    APPLY=1; shift ;;
    --dry-run)  APPLY=0; shift ;;
    --help|-h)  usage 0 ;;
    *) printf 'continuation-broadcast: unknown arg: %s\n' "$1" >&2; usage 1 ;;
  esac
done

# ── G1 kill-switch ──────────────────────────────────────────────────────────
if [ "${MAOS_BROADCAST:-1}" = "0" ]; then
  printf '{"status":"noop","reason":"MAOS_BROADCAST=0 (kill-switch)","action":"none"}\n'; exit 0
fi

# ── validate scope + defaults ─────────────────────────────────────────────────
case "$SCOPE" in conservative|all) ;; *) printf 'continuation-broadcast: --scope must be conservative|all\n' >&2; usage 1 ;; esac
SESSION="${SESSION:-${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-unknown}}}"
[ -n "$TICKET" ] || TICKET="none"

# ── relativize the seed path (marker is metadata-only: no abs/home leak) ─────
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SEED_REL="$SEED"
case "$SEED" in
  "$REPO_ROOT"/*) SEED_REL="${SEED#"$REPO_ROOT"/}" ;;
  "$HOME"/*)      SEED_REL="~/${SEED#"$HOME"/}" ;;
esac

# ── verify the seed REFERENT exists (ADR-010: point at a REGISTERED continuation, not a promise) ──
# Only a seed file that actually exists may back the marker; an unfound --seed is dropped as backing.
# (The ticket is caller-registered by postflight P2.5 — asserted, per ADR-010.)
SEED_VERIFIED=0
if [ -n "$SEED" ]; then
  if [ -f "$SEED" ] || { [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/$SEED_REL" ]; }; then
    SEED_VERIFIED=1
  else
    printf 'continuation-broadcast: --seed %s not found — dropping it as backing (not a verified referent)\n' "$SEED" >&2
    SEED_REL=""   # never point at an unbacked seed
  fi
fi

# ── must have something REAL to point at (a verified seed OR a named ticket) ──
if { [ -z "$TICKET" ] || [ "$TICKET" = "none" ]; } && [ "$SEED_VERIFIED" != 1 ]; then
  printf '{"status":"noop","reason":"nothing verifiably to point at (no --ticket and no existing --seed) — broadcast skipped","action":"none"}\n'; exit 0
fi

# ── G-inject: the payload is metadata-only — it may NOT carry a sentinel/comment/newline ─────
# (else a crafted ticket/seed/session could restructure the marker block or forge a JSON/log line).
for _v in "$TICKET" "$SEED_REL" "$SESSION"; do
  case "$_v" in
    *MAOS-CONTINUE*|*'<!--'*|*'-->'*)
      printf '{"status":"error","reason":"marker payload may not contain sentinel/comment markers"}\n' >&2; exit 1 ;;
  esac
  case "$_v" in
    *$'\n'*|*$'\r'*|*$'\t'*)
      printf '{"status":"error","reason":"marker payload may not contain newlines/tabs (metadata is single-line)"}\n' >&2; exit 1 ;;
  esac
done

# ── G-sanitize: refuse anything that smells like a live secret (defense-in-depth) ──
if printf '%s %s %s' "$TICKET" "$SEED_REL" "$SESSION" \
   | grep -Eiq '(-----BEGIN [A-Z ]*PRIVATE KEY|aws_secret_access_key|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{12,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{20,}|glpat-[A-Za-z0-9_-]{16,}|password["'\'' :=]+[^ "'\'']{6,})'; then
  printf '{"status":"error","reason":"marker payload appears to contain a secret — refusing (metadata-only)"}\n' >&2; exit 1
fi

NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"   # audit-log only (NOT in the block)

# ── build the ONE marker block (single source → identical across every sink) ──
# Line 1/4: sentinels (idempotent-upsert delimiters). Line 2: machine JSON payload. Line 3: human mirror.
# The block is BYTE-IDEMPOTENT: it carries no timestamp, so a re-apply on unchanged inputs is a true
# no-op (identical bytes) — never a timestamp-only churn write.
SEED_HINT=""; [ -n "$SEED_REL" ] && SEED_HINT=" (seed: \`${SEED_REL}\`)"
TICKET_HINT="$TICKET"; [ "$TICKET" = "none" ] && TICKET_HINT="the continuation seed"
BLOCK_FILE="$(mktemp 2>/dev/null)" || { printf '{"status":"error","reason":"mktemp failed — refusing (no predictable-path fallback)"}\n' >&2; exit 2; }
trap 'rm -f "$BLOCK_FILE" 2>/dev/null' EXIT
{
  printf '%s\n' "$SENTINEL_START"
  printf '<!-- MAOS-CONTINUE {"ticket":"%s","seed":"%s","session":"%s"} -->\n' \
    "$(json_escape "$TICKET")" "$(json_escape "$SEED_REL")" "$(json_escape "$SESSION")"
  printf '> 🔁 **Continuation pending** — resume at **%s**%s. A fresh amnesic agent: run `/maos:preflight`, then continue from the ticket/seed. _(structured back-pointer to the tracked continuation, not a TODO — see `docs/adrs/ADR-010-continuation-broadcast.md`. If **%s** is already resolved/closed this marker is STALE — delete this block.)_\n' \
    "$TICKET_HINT" "$SEED_HINT" "$TICKET_HINT"
  printf '%s\n' "$SENTINEL_END"
} > "$BLOCK_FILE"

# the commit-trailer form (single line; git-trailer parseable — token before the first ": ")
TRAILER="${TRAILER_TOKEN}: ${TICKET} · seed:${SEED_REL:-none}"

# ── idempotent-upsert helper — replace exactly one well-formed sentinel region, else append ──
# Reads the block from $BLOCK_FILE (multi-line-safe). Atomic (tmp → mv).
# FAIL-CLOSED (returns 2, writes NOTHING) on any malformed/ambiguous sentinel state so a stray or
# tool-mangled marker in a PR body / doc can NEVER cause a mass-delete-to-EOF or a duplicated block:
#   • no sentinels           → append one fresh block (return 0)
#   • exactly ONE START, ONE END, START-line before END-line → replace that region in place (return 0)
#   • anything else (dangling START/END, duplicate sentinels, END-before-START, substring-only
#     mentions on a partial line) → REFUSE (return 2)
# Sentinels are matched as WHOLE LINES (grep -xF / awk $0==) so a mention inside prose or a code
# fence never counts unless it is its own exact line.
upsert_block() {
  local file="$1" tmp ns ne ls le
  tmp="${file}.mcont.tmp.$$"
  ns="$(grep -cxF "$SENTINEL_START" "$file" 2>/dev/null)"; ns="${ns:-0}"
  ne="$(grep -cxF "$SENTINEL_END"   "$file" 2>/dev/null)"; ne="${ne:-0}"
  if [ "$ns" -eq 0 ] && [ "$ne" -eq 0 ]; then
    { printf '\n'; cat "$BLOCK_FILE"; } >> "$file" 2>/dev/null && return 0
    return 1
  fi
  # any sentinel present → require exactly one balanced, correctly-ordered pair, else fail closed.
  [ "$ns" -eq 1 ] && [ "$ne" -eq 1 ] || return 2
  ls="$(grep -nxF "$SENTINEL_START" "$file" 2>/dev/null | head -1 | cut -d: -f1)"
  le="$(grep -nxF "$SENTINEL_END"   "$file" 2>/dev/null | head -1 | cut -d: -f1)"
  { [ -n "$ls" ] && [ -n "$le" ] && [ "$ls" -lt "$le" ]; } || return 2
  awk -v bf="$BLOCK_FILE" -v s="$SENTINEL_START" -v e="$SENTINEL_END" '
    BEGIN { blk=""; while ((getline line < bf) > 0) blk = blk line "\n" }
    $0 == s          { printf "%s", blk; skip=1; next }   # emit replacement at START
    skip==1 && $0==e { skip=0; next }                     # consume through END
    skip!=1          { print }                            # keep everything outside the region
  ' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file" && return 0
  rm -f "$tmp" 2>/dev/null; return 1
}

# ── audit-trail (append one line per applied sink; best-effort) ───────────────
JOBS_DIR="${CLAUDE_JOBS_DIR:-${HOME:-/tmp}/.claude/jobs}"
AUDIT_LOG="${JOBS_DIR}/continuation-broadcasts.log"
audit() { # sink, target, action
  [ "$APPLY" = 1 ] || return 0
  mkdir -p "$JOBS_DIR" 2>/dev/null || true
  printf '%s\tsink=%s\ttarget=%s\taction=%s\tticket=%s\tsession=%s\n' \
    "$NOW_UTC" "$1" "$2" "$3" "$TICKET" "$SESSION" >> "$AUDIT_LOG" 2>/dev/null || true
}

# ── collect per-sink results (JSON array assembled at the end) ────────────────
SINKS_JSON=""
add_sink() { # sink, target, action, reason
  local frag; frag=$(printf '{"sink":"%s","target":"%s","action":"%s","reason":"%s"}' \
    "$(json_escape "$1")" "$(json_escape "$2")" "$(json_escape "$3")" "$(json_escape "$4")")
  if [ -z "$SINKS_JSON" ]; then SINKS_JSON="$frag"; else SINKS_JSON="${SINKS_JSON},${frag}"; fi
}

# ── SINK 1: commit-trailer (always — it is just text the caller appends) ─────
# Printed to stderr as guidance; emitted in the JSON so the caller can consume it.
printf '↳ commit-trailer (append to the exit commit message):\n    %s\n' "$TRAILER" >&2
add_sink "commit-trailer" "exit-commit-message" "emitted" "append the trailer line to the closing commit"

# ── SINK 2: PR body (idempotent upsert via gh) ───────────────────────────────
if [ -n "$PR" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    add_sink "pr-body" "PR#${PR}" "skipped" "gh not found (capability-detect)"
  elif [ "$APPLY" != 1 ]; then
    printf '↳ [dry-run] would upsert the marker block into PR #%s body\n' "$PR" >&2
    add_sink "pr-body" "PR#${PR}" "would-write" "dry-run (pass --apply to write)"
  else
    BODY_TMP="$(mktemp 2>/dev/null)" || { printf '{"status":"error","reason":"mktemp failed"}\n' >&2; exit 2; }
    if gh pr view "$PR" --json body -q .body > "$BODY_TMP" 2>/dev/null; then
      upsert_block "$BODY_TMP"; urc=$?
      if [ "$urc" -eq 0 ]; then
        if gh pr edit "$PR" --body-file "$BODY_TMP" >/dev/null 2>&1; then
          add_sink "pr-body" "PR#${PR}" "written" "idempotent upsert"; audit "pr-body" "PR#${PR}" "written"
        else
          add_sink "pr-body" "PR#${PR}" "skipped" "gh pr edit failed (permissions/network)"
        fi
      elif [ "$urc" -eq 2 ]; then
        add_sink "pr-body" "PR#${PR}" "refused" "existing marker malformed (dangling/duplicate sentinel) — body left untouched (fail-closed)"
      else
        add_sink "pr-body" "PR#${PR}" "skipped" "upsert write failed"
      fi
    else
      add_sink "pr-body" "PR#${PR}" "skipped" "gh pr view failed (no such PR / no access)"
    fi
    rm -f "$BODY_TMP" 2>/dev/null || true
  fi
fi

# ── SINK 3: files (ONLY under --scope all; caller-named; ADRs refused) ───────
if [ -n "$FILES" ]; then
  if [ "$SCOPE" != "all" ]; then
    add_sink "file" "(deferred)" "skipped" "--file honored only under --scope all (conservative default)"
  else
    # Here-string (NOT a pipe) keeps the loop in THIS shell so add_sink mutations to SINKS_JSON
    # persist (a `printf | while` subshell would silently drop the file-sink results).
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      # Reject symlinks: the refusal below matches the NAME, but append/`mv` FOLLOW the link — a
      # symlinked path could otherwise smuggle a write into an ADR or an arbitrary file (F3).
      if [ -L "$f" ]; then
        add_sink "file" "$f" "refused" "symlink — refusing (could redirect the write outside the named target)"; continue
      fi
      # ADR / MADR decision-record refusal — case-INSENSITIVE, covers adrs//adr//decisions/ dirs and
      # numbered MADR basenames (0001-*.md) as well as ADR-*.md / adr-*.md anywhere (F2/F9).
      flc="$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')"; bn="${flc##*/}"
      case "$flc" in
        */adrs/*|*/adr/*|*/decisions/*|adr-*.md|*/adr-*.md)
          add_sink "file" "$f" "refused" "ADR/decision record — immutable, not a transient worklist (ADR-010)"; continue ;;
      esac
      case "$bn" in
        [0-9][0-9][0-9][0-9]-*.md)
          add_sink "file" "$f" "refused" "MADR numbered decision record — immutable, not a transient worklist (ADR-010)"; continue ;;
      esac
      if [ ! -f "$f" ]; then
        add_sink "file" "$f" "skipped" "no such file (or not a regular file)"; continue
      fi
      if [ "$APPLY" != 1 ]; then
        printf '↳ [dry-run] would upsert the marker block into %s\n' "$f" >&2
        add_sink "file" "$f" "would-write" "dry-run (pass --apply to write)"; continue
      fi
      upsert_block "$f"; urc=$?
      if [ "$urc" -eq 0 ]; then
        add_sink "file" "$f" "written" "idempotent upsert"; audit "file" "$f" "written"
      elif [ "$urc" -eq 2 ]; then
        add_sink "file" "$f" "refused" "existing marker malformed (dangling/duplicate sentinel) — left untouched (fail-closed)"
      else
        add_sink "file" "$f" "skipped" "write failed"
      fi
    done <<< "$FILES"
  fi
fi

# ── emit JSON summary ─────────────────────────────────────────────────────────
MODE="$([ "$APPLY" = 1 ] && echo apply || echo dry-run)"
printf '{"status":"ok","mode":"%s","scope":"%s","ticket":"%s","seed":"%s","session":"%s","trailer":"%s","sinks":[%s]}\n' \
  "$MODE" "$SCOPE" "$(json_escape "$TICKET")" "$(json_escape "$SEED_REL")" "$(json_escape "$SESSION")" \
  "$(json_escape "$TRAILER")" "$SINKS_JSON"
exit 0
