#!/usr/bin/env bash
# /**
#  * multi-agent-os · bin/spawn-continuation.sh   (postflight P3.5 — tool 5.1)
#  * @context End-of-session continuation: postflight P3 emits a continuation SEED; this script
#  *          is the SPAWN primitive that launches a fresh, named `claude` session pre-seeded with
#  *          it — closing the loop `preflight -> work -> postflight -> (spawn) -> preflight ...`.
#  * @reason  postflight already PRINTS + clipboards the seed (manual resume). This adds the
#  *          autonomous hand-off the operator requested (tool 5.1) — WITHOUT reinventing the seed
#  *          (it consumes postflight's P3 JSON-RPC seed) and WITHOUT blocking the session.
#  * @impact  Spawns ONE detached `claude` session (tmux/cmux) named with the D1 locus
#  *          (`<status> · <anchor> · <slug> · #<short>`, rendered by bin/locus.sh — the session
#  *          name IS the geo-location), with the seed injected as durable system context.
#  *          High-blast (a real session burns tokens) → 7 guardrails: kill-switch · idempotency ·
#  *          anti-recursion depth-cap · capability-detect graceful-noop · seed sanitization ·
#  *          audit-trail · --dry-run.
#  * @note    EMOJI-FIRST NAME EXPERIMENT (operator decision 2026-06-10): the D1 name keeps the
#  *          status emoji + middle-dot `·` + spaces VERBATIM ("testarmos só com ícones primeiro;
#  *          se eu ver algum problema eu relato"). Potential problems: tmux target-matching /
#  *          truncation of unicode names, terminal-font rendering, any consumer that treats the
#  *          session name as a filesystem path. Possible solution if a real problem is reported:
#  *          an ASCII-safe D1 variant (3-letter color token red|org|yel|grn + `-` separator).
#  *          Escape hatch TODAY: POSTFLIGHT_NAME_STYLE=legacy restores the old ascii
#  *          `<ticket>-<slug>-#<short>` name (also the auto-fallback when locus.sh is absent).
#  *          Jobs-registry dirs use SHORT (hex), never NAME — the filesystem is unaffected.
#  * @version 0.2.0
#  * Portability: AAIF cross-vendor — POSIX Bash 3.2; jq optional; no associative arrays.
#  * Exit codes ([C06]): 0 success/graceful-noop · 1 usage/validation · 2 setup.
#  */
set -uo pipefail   # NOT -e: a fallible probe must reach the graceful-noop path, never abort mid-spawn.

# ── self-contained json-escape (match seed.sh / precompact convention) ────────
json_escape() {
  local s="$1"; s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}; printf '%s' "$s"
}

# ── safe single-quote for shell-command-string embedding ('…' with '\'' escapes) ──
# NAME can carry a branch-derived anchor (git refnames MAY contain ' " ` $ ;) — every
# interpolation of NAME/UUID/SEED_FILE into a shell string MUST go through shq (anti-injection).
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

usage() {
  cat <<EOF
spawn-continuation — launch a fresh, seeded \`claude\` continuation session (postflight P3.5 / tool 5.1).

Usage:
  $(basename "$0") --slug <kebab> [--ticket <KEY>] [--seed <file|->] [options]

Required:
  --slug <kebab>     short kebab description for the session name   ([A-Za-z0-9._-])

Optional:
  --ticket <KEY>     ticket id — locus anchor input + legacy-name prefix (e.g. TICKET-123)
  --status <GLYPH>   D1 locus status glyph for the session name: 🔴 🟠 🟡 🟢 (default 🟡)
  --seed  <file|->   path to the postflight P3 continuation seed (JSON), or - for stdin.
                     If omitted, a minimal seed is synthesized from git state.
  --no-spawn         do everything EXCEPT launch (register + print the resume command). Default: spawn ON.
  --dry-run          print the exact \`claude …\` command + plan; touch nothing, launch nothing.
  --force            override the once-per-source-session idempotency marker.
  --depth-cap N      anti-recursion cap for auto-chained spawns (default 1).
  --help

Environment guardrails:
  POSTFLIGHT_SPAWN=0          hard kill-switch — never spawn (deterministic opt-out).
  POSTFLIGHT_SPAWN_DEPTH=N    current auto-chain depth (default 0); >= --depth-cap => graceful no-op.
  POSTFLIGHT_NAME_STYLE       locus (default: D1 emoji name via bin/locus.sh) | legacy
                              (ascii <ticket>-<slug>-#<short> — the pre-0.2.0 name; also the
                              auto-fallback when locus.sh is absent).
  CLAUDE_CODE_SESSION_ID      source session id (idempotency key); falls back to a derived key.
  MAOS_SPAWN_LAUNCHER         force launcher: tmux | cmux | print (default: auto-detect).

Spawns ONE detached session. Re-enter later with:  claude --resume <uuid>
(or, while the tmux pane is alive:  tmux attach -t <name>).  Note: --session-id CREATES a
session (once); to RE-ENTER an existing one use --resume (avoids "session id already in use").
EOF
  exit "${1:-0}"
}

# ── parse args ────────────────────────────────────────────────────────────────
TICKET="" SLUG="" STATUS="🟡" SEED_SRC="" NO_SPAWN=0 DRY_RUN=0 FORCE=0 DEPTH_CAP=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket)    TICKET="${2:-}"; shift 2 ;;
    --status)    STATUS="${2:-🟡}"; shift 2 ;;
    --slug)      SLUG="${2:-}"; shift 2 ;;
    --seed)      SEED_SRC="${2:-}"; shift 2 ;;
    --no-spawn)  NO_SPAWN=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --force)     FORCE=1; shift ;;
    --depth-cap) DEPTH_CAP="${2:-1}"; shift 2 ;;
    --help|-h)   usage 0 ;;
    *) printf 'spawn-continuation: unknown arg: %s\n' "$1" >&2; usage 1 ;;
  esac
done
[ -n "$SLUG" ] || { printf 'spawn-continuation: --slug is required\n' >&2; usage 1; }

# --status is a Tier-B glyph: WHITELIST the 4 locus statuses (anti-injection + grammar-honest;
# anything else — including shell metacharacters — falls back to the 🟡 default).
case "$STATUS" in 🔴|🟠|🟡|🟢) ;; *) STATUS="🟡" ;; esac

# sanitize name parts (filesystem + session-name safe)
clean() { printf '%s' "$1" | tr -cd 'A-Za-z0-9._-' | sed 's/^\.*//'; }
TICKET="$(clean "$TICKET")"; SLUG="$(clean "$SLUG")"
[ -n "$SLUG" ] || { printf 'spawn-continuation: --slug has no name-safe characters\n' >&2; exit 1; }

# ── G1 kill-switch ──────────────────────────────────────────────────────────
if [ "${POSTFLIGHT_SPAWN:-1}" = "0" ]; then
  printf '{"status":"noop","reason":"POSTFLIGHT_SPAWN=0 (kill-switch)","action":"none"}\n'; exit 0
fi

# ── G3 anti-recursion depth-cap ─────────────────────────────────────────────
DEPTH="${POSTFLIGHT_SPAWN_DEPTH:-0}"
case "$DEPTH" in (''|*[!0-9]*) DEPTH=0 ;; esac
if [ "$DEPTH" -ge "$DEPTH_CAP" ]; then
  printf '{"status":"noop","reason":"depth %s >= cap %s (anti-recursion)","action":"none"}\n' "$DEPTH" "$DEPTH_CAP"; exit 0
fi

# ── identity: source session (idempotency key) + new uuid ────────────────────
SRC_SESSION="${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-$(printf '%s-%s' "$(hostname 2>/dev/null || echo host)" "$PPID")}}"
new_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then uuidgen | tr 'A-Z' 'a-z'
  elif [ -r /proc/sys/kernel/random/uuid ]; then cat /proc/sys/kernel/random/uuid
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import uuid;print(uuid.uuid4())'
  else printf '%s-%s-%s' "$$" "$PPID" "$(date -u +%s 2>/dev/null || echo 0)"; fi
}
UUID="$(new_uuid)"
SHORT="$(printf '%s' "$UUID" | tr -cd 'a-f0-9' | cut -c1-8)"
[ -n "$SHORT" ] || SHORT="$(printf '%s' "$UUID" | tr -cd 'A-Za-z0-9' | cut -c1-8)"

# ── session NAME = D1 locus (the name IS the geo-location) ───────────────────
# Rendered by bin/locus.sh (grammar SSOT: skills/postflight/references/locus-spec.md):
#   <status> · <anchor> · <slug> · #<short>     e.g.  🟡 · VKS-123 · payment-retry · #a1b2c3d4
# The anchor is Tier-A COMPUTED by locus (ticket › PR › branch — anti-theater: never asserted).
# Emoji-first experiment — see @note in the header. Fallback to the legacy ascii name when
# locus.sh is absent OR POSTFLIGHT_NAME_STYLE=legacy. (MAOS_LOCUS_BIN overrides the renderer
# path — test seam.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
LOCUS_BIN="${MAOS_LOCUS_BIN:-$SCRIPT_DIR/locus.sh}"
NAME=""
if [ "${POSTFLIGHT_NAME_STYLE:-locus}" != "legacy" ] && [ -f "$LOCUS_BIN" ]; then
  NAME="$(bash "$LOCUS_BIN" --density name --status "$STATUS" --slug "$SLUG" --seq "$SHORT" 2>/dev/null </dev/null)" || NAME=""
fi
if [ -z "$NAME" ]; then   # legacy ascii name (pre-0.2.0 shape)
  if [ -n "$TICKET" ]; then NAME="${TICKET}-${SLUG}-#${SHORT}"; else NAME="${SLUG}-#${SHORT}"; fi
fi

# ── jobs registry dirs (match the ~/.claude/jobs convention) ─────────────────
JOBS_DIR="${CLAUDE_JOBS_DIR:-${HOME:-/tmp}/.claude/jobs}"
SRC_KEY="$(clean "$SRC_SESSION")"; [ -n "$SRC_KEY" ] || SRC_KEY="unknown"
SRC_JOB_DIR="${JOBS_DIR}/${SRC_KEY}"
MARKER="${SRC_JOB_DIR}/.continuation-spawned"

# ── G2 idempotency ──────────────────────────────────────────────────────────
if [ "$FORCE" != "1" ] && [ -f "$MARKER" ]; then
  printf '{"status":"noop","reason":"already spawned a continuation for source session %s (use --force)","marker":"%s"}\n' \
    "$(json_escape "$SRC_KEY")" "$(json_escape "$MARKER")"; exit 0
fi

# ── read + G5 sanitize the seed ──────────────────────────────────────────────
read_seed() {
  if [ "$SEED_SRC" = "-" ]; then cat
  elif [ -n "$SEED_SRC" ] && [ -f "$SEED_SRC" ]; then cat "$SEED_SRC"
  else
    # minimal synthesized seed from git state (postflight P3 normally supplies the rich one)
    local repo branch; repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
    branch="$(git branch --show-current 2>/dev/null || echo unknown)"
    printf '{"jsonrpc":"2.0","method":"session.continuation","params":{"goal":"%s","git":{"repo":"%s","branch":"%s"},"resume_instructions":"Run /maos:preflight to orient, then resume the first non-blocked next-action. (minimal seed — re-run /maos:postflight for the full debrief.)"},"data":{"layer":"community"}}' \
      "$(json_escape "continue work on ${SLUG}")" "$(json_escape "$repo")" "$(json_escape "$branch")"
  fi
}
SEED_RAW="$(read_seed)"
# Defense-in-depth: refuse to inject anything that smells like a live secret (seed must be metadata-only).
if printf '%s' "$SEED_RAW" | grep -Eiq '(-----BEGIN [A-Z ]*PRIVATE KEY|aws_secret_access_key|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|password["'\'' :=]+[^ "'\'']{6,})'; then
  printf '{"status":"error","reason":"seed appears to contain a secret — refusing to inject (sanitize the seed, metadata-only)"}\n' >&2; exit 1
fi

# ── build the resume command (array — no eval) ───────────────────────────────
set -- claude --name "$NAME" --session-id "$UUID" --append-system-prompt "$SEED_RAW"
# human-printable form (seed elided)
CMD_PRINT="claude --name $(shq "$NAME") --session-id $(shq "$UUID") --append-system-prompt '<postflight-seed:${#SEED_RAW} bytes>'"

# ── G4 launcher capability-detect ────────────────────────────────────────────
LAUNCHER="${MAOS_SPAWN_LAUNCHER:-auto}"
if [ "$LAUNCHER" = "auto" ]; then
  # tmux FIRST: it is the only VERIFIABLE + attachable detached launcher here. cmux has no
  # documented "run an arbitrary command in a detached pane" primitive (its CLI opens
  # paths/URLs, not commands), so auto-detect does NOT route to a fake cmux spawn — without
  # tmux we fall to register+print (honest resume command), never a false "spawned".
  if   command -v tmux >/dev/null 2>&1; then LAUNCHER="tmux"
  elif command -v claude >/dev/null 2>&1; then LAUNCHER="print"   # detacher absent/unverifiable → register+print
  else LAUNCHER="none"; fi
fi

emit_plan() { # status, launched(bool)
  printf '{"status":"%s","name":"%s","session_id":"%s","launcher":"%s","depth":%s,"src_session":"%s","resume_cmd":"%s","attach":"%s"}\n' \
    "$1" "$(json_escape "$NAME")" "$(json_escape "$UUID")" "$(json_escape "$LAUNCHER")" "$DEPTH" \
    "$(json_escape "$SRC_KEY")" "$(json_escape "$CMD_PRINT")" "$(json_escape "claude --resume ${UUID}")"
}

# ── --dry-run: print plan, touch nothing ─────────────────────────────────────
if [ "$DRY_RUN" = "1" ]; then
  echo "🛫 [dry-run] would spawn continuation session:" >&2
  echo "   $CMD_PRINT" >&2
  emit_plan "dry-run"; exit 0
fi

# ── persist intent to the jobs registry (always — even on --no-spawn / print) ─
mkdir -p "$SRC_JOB_DIR" "${JOBS_DIR}/${SHORT}" 2>/dev/null || true
SEED_FILE="${JOBS_DIR}/${SHORT}/continuation-seed.json"
printf '%s\n' "$SEED_RAW" > "$SEED_FILE" 2>/dev/null || true
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
# state.json mirrors the ~/.claude/jobs/<short>/state.json shape (name · sessionId · intent · respawnFlags).
printf '{"sessionId":"%s","daemonShort":"%s","name":"%s","intent":"postflight P3.5 continuation of %s","respawnFlags":["--name","%s","--session-id","%s","--append-system-prompt","@%s"],"createdAt":"%s","srcSession":"%s","layer":"community"}\n' \
  "$(json_escape "$UUID")" "$SHORT" "$(json_escape "$NAME")" "$(json_escape "$SRC_KEY")" \
  "$(json_escape "$NAME")" "$(json_escape "$UUID")" "$(json_escape "$SEED_FILE")" \
  "$NOW_UTC" "$(json_escape "$SRC_KEY")" > "${JOBS_DIR}/${SHORT}/state.json" 2>/dev/null || true

# ── G6 audit-trail (append one line; best-effort) ────────────────────────────
AUDIT_LOG="${JOBS_DIR}/continuation-spawns.log"
printf '%s\tname=%s\tuuid=%s\tsrc=%s\tlauncher=%s\tspawn=%s\n' \
  "$NOW_UTC" "$NAME" "$UUID" "$SRC_KEY" "$LAUNCHER" "$([ "$NO_SPAWN" = 1 ] && echo no || echo yes)" \
  >> "$AUDIT_LOG" 2>/dev/null || true

# ── --no-spawn OR no launcher: register + print the command (graceful) ───────
if [ "$NO_SPAWN" = "1" ] || [ "$LAUNCHER" = "none" ] || [ "$LAUNCHER" = "print" ]; then
  reason="$([ "$NO_SPAWN" = 1 ] && echo '--no-spawn' || echo "no detached launcher (tmux/cmux) found")"
  echo "🛫 continuation prepared (${reason}). Seed → ${SEED_FILE}" >&2
  echo "   Start it:  claude --name $(shq "$NAME") --session-id $(shq "$UUID") --append-system-prompt \"\$(cat $(shq "$SEED_FILE"))\"" >&2
  echo "   Re-enter:  claude --resume '${UUID}'   (after it has been started once)" >&2
  emit_plan "registered"; exit 0
fi

# ── spawn detached (the child runs at depth+1; idempotency marker set) ───────
touch "$MARKER" 2>/dev/null || true
CHILD_DEPTH=$((DEPTH + 1))
case "$LAUNCHER" in
  tmux)
    # interactive claude in a detached tmux session, pre-seeded, attachable.
    POSTFLIGHT_SPAWN_DEPTH="$CHILD_DEPTH" tmux new-session -d -s "$NAME" \
      "POSTFLIGHT_SPAWN_DEPTH=$CHILD_DEPTH claude --name $(shq "$NAME") --session-id $(shq "$UUID") --append-system-prompt \"\$(cat $(shq "$SEED_FILE"))\"" 2>/dev/null \
      && { echo "🛫 spawned (tmux): $NAME" >&2
           echo "   re-enter:  tmux attach -t $(shq "$NAME")   (or, once the pane exits:  claude --resume '$UUID')" >&2
           emit_plan "spawned"; exit 0; }
    ;;
  cmux)
    # cmux exposes no verified "run an arbitrary detached command" primitive (its CLI opens
    # paths/URLs, not commands). NEVER fake a spawn — fall through to the honest register+print.
    : ;;
esac
# launcher failed → fall back to registered (never leave the operator stranded)
rm -f "$MARKER" 2>/dev/null || true   # spawn didn't happen → let a retry through
echo "🛫 launcher '$LAUNCHER' failed; continuation registered. Start manually:" >&2
echo "   Start it:  claude --name '${NAME}' --session-id '${UUID}' --append-system-prompt \"\$(cat '${SEED_FILE}')\"" >&2
echo "   Re-enter:  claude --resume '${UUID}'   (after it has been started once)" >&2
emit_plan "registered"; exit 0
