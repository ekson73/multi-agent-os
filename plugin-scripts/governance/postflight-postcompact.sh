#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: postflight-postcompact.sh
# Purpose: PostCompact enrichment for the `postflight` bundle. Fires RIGHT AFTER the
#   harness compacts the conversation — the moment the harness hands us its OWN summary
#   of the conversation (intent, concepts, files+snippets, errors+fixes, pendencies).
#   This hook MERGES that `compact_summary` into `params.compact_summary` of the SAME
#   continuation-seed the PreCompact skeleton wrote, so the SessionStart[compact] reload
#   can inject the richest available continuation packet.
#
#   DETERMINISTIC + no LLM. Enriches the seed MONOTONICALLY (never downgrades kind, never
#   removes fields). NEVER blocks (fail-open, always exit 0, NEVER exit 2 — a PostCompact
#   that vetoes during an API-context-limit recovery would fail the user's request).
# Version: 0.1.2
# Protocol: C04 (Git Worktree), C06 (AI-Native Environment)
# Event: PostCompact
#
# Opt-out: POSTFLIGHT_NO_AUTOSNAPSHOT=1 → skip entirely.
#          POSTFLIGHT_SEED_DIR=<path> → override seed dir (matches the producer).
# ═══════════════════════════════════════════════════════════════════════════════

# `set -uo pipefail` WITHOUT `-e` — a PostCompact safety-net bound to "never blocks / exit 0".
set -uo pipefail

# Opt-out → no-op.
[ "${POSTFLIGHT_NO_AUTOSNAPSHOT:-0}" = "1" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
[ -f "${LIB_DIR}/common.sh" ] && source "${LIB_DIR}/common.sh" 2>/dev/null || true
[ -f "${LIB_DIR}/seed-io.sh" ] && source "${LIB_DIR}/seed-io.sh" 2>/dev/null || true

# Minimal json-escape fallback (for the stderr note / audit only; the merge itself uses jq).
if ! command -v json_escape >/dev/null 2>&1; then
  json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }
fi

# HARD deps: the merge is a jq operation over large/multiline text, and the write needs the
# shared lock+path from seed-io. Either absent → no-op (fail-open, never fabricate).
command -v jq       >/dev/null 2>&1 || { echo "🛬 postflight (post-compact): jq absent → skip merge (fail-open)." >&2; exit 0; }
command -v seed_dir >/dev/null 2>&1 || { echo "🛬 postflight (post-compact): seed-io lib absent → skip." >&2; exit 0; }

# ── Read PostCompact stdin (best-effort; bounded) ─────────────────────────────
STDIN_JSON=""
[ ! -t 0 ] && STDIN_JSON="$(timeout 1 cat 2>/dev/null || true)"
[ -z "$STDIN_JSON" ] && exit 0

SESSION_ID="$(printf '%s' "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null)"; [ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TRIGGER="$(printf '%s' "$STDIN_JSON" | jq -r '.trigger // "unknown"' 2>/dev/null)"; [ -z "$TRIGGER" ] && TRIGGER="unknown"
# compact_summary: assumed a top-level STRING; DEFENSIVELY tolerate an object carrying .text/.summary
# (the exact stdin shape is undocumented — verify live, adjust this jq if the payload differs).
SUMMARY="$(printf '%s' "$STDIN_JSON" | jq -r 'if (.compact_summary|type)=="object" then (.compact_summary.text // .compact_summary.summary // empty) elif (.compact_summary|type)=="string" then .compact_summary else empty end' 2>/dev/null || true)"
[ -z "$SUMMARY" ] && exit 0   # nothing to merge

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Repo + seed path (SAME resolution the PreCompact producer used) ────────────
REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || exit 0   # off-git → nothing to enrich
SEED_DIR="$(seed_dir "$REPO")"
SEED_FILE="${SEED_DIR}/continuation-seed.latest.json"

# ── active_world (contract 1.4.0) — computed here too, in case this hook synthesizes the
# minimal-skeleton fallback below (PreCompact skipped) or is backfilling an older seed that
# predates this field. Never overwrites a value a prior producer already set (see the //= merge).
ACTIVE_WORLD="$(seed_active_world "$REPO" 2>/dev/null || echo unknown)"

# ── Secret scan BEFORE persisting (⛔ ABSOLUTE — the summary may quote code with live secrets)
# Idiom verbatim from bin/spawn-continuation.sh: on a hit, DROP the text + flag redacted.
REDACTED=false
if printf '%s' "$SUMMARY" | grep -Eiq '(-----BEGIN [A-Z ]*PRIVATE KEY|aws_secret_access_key|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|password["'\'' :=]+[^ "'\'']{6,})'; then
  SUMMARY=""; REDACTED=true
fi

# ── Size guard (16 KiB) — keep the seed lean; flag truncation ─────────────────
TRUNCATED=false
BYTES="$(printf '%s' "$SUMMARY" | wc -c | tr -d ' ')"; case "$BYTES" in ''|*[!0-9]*) BYTES=0 ;; esac
MAX=16384
if [ "$BYTES" -gt "$MAX" ]; then
  SUMMARY="$(printf '%s' "$SUMMARY" | head -c "$MAX")"
  TRUNCATED=true
  BYTES="$MAX"
fi

# Build the compact_summary object (jq --arg → safe escaping of multiline text).
CS_OBJ="$(jq -n --arg trig "$TRIGGER" --arg cap "$TS" --argjson bytes "$BYTES" \
  --argjson trunc "$TRUNCATED" --argjson redact "$REDACTED" --arg text "$SUMMARY" \
  '{present:true, trigger:$trig, captured_at:$cap, bytes:$bytes, truncated:$trunc, redacted:$redact, text:$text}' 2>/dev/null || true)"
[ -z "$CS_OBJ" ] && exit 0   # jq failed → never write garbage

# ── Merge into the seed, lock-serialized + atomic (never downgrade kind) ──────
if seed_lock "$SEED_DIR"; then
  MERGED=""
  if [ -f "$SEED_FILE" ] && jq -e . "$SEED_FILE" >/dev/null 2>&1; then
    # Enrich the existing seed (any kind) — set params.compact_summary, and backfill
    # params.active_world ONLY if absent (//= never clobbers a value a prior producer set).
    MERGED="$(jq --argjson cs "$CS_OBJ" --arg aw "$ACTIVE_WORLD" \
      '.params.compact_summary = $cs | .params.active_world //= $aw' "$SEED_FILE" 2>/dev/null || true)"
  else
    # No (or corrupt) seed → PreCompact was skipped (e.g. an auto-compaction not paired with a
    # PreCompact). Synthesize a MINIMAL skeleton so the harness summary is not lost (safe, not lossy).
    MERGED="$(jq -n --argjson cs "$CS_OBJ" --arg sid "$SESSION_ID" --arg trig "$TRIGGER" --arg cap "$TS" --arg aw "$ACTIVE_WORLD" \
      '{jsonrpc:"2.0",method:"session.continuation",params:{kind:"deterministic-snapshot",captured_at:$cap,trigger:$trig,session_id:$sid,active_world:$aw,compact_summary:$cs,resume_instructions:"Run /maos:preflight to orient, then /maos:postflight for the full continuation seed (this seed carries only the harness compact_summary — PreCompact did not run)."},data:{layer:"community",contract:"skills/postflight/references/continuation-seed-contract.md",contract_version:"1.4.0"}}' 2>/dev/null || true)"
  fi
  [ -n "$MERGED" ] && seed_write_atomic "$SEED_FILE" "$MERGED"
  seed_unlock
fi
# lock unavailable after ~3s → another writer active; skip (safe — the summary merge is best-effort).

# Audit (no-op unless an audit dir exists); isolated in a subshell (see precompact rationale).
( command -v log_audit >/dev/null 2>&1 \
    && log_audit "postflight_postcompact" "{\"session\":\"$(json_escape "$SESSION_ID")\",\"trigger\":\"$(json_escape "$TRIGGER")\",\"bytes\":${BYTES:-0},\"redacted\":${REDACTED},\"truncated\":${TRUNCATED}}" ) >/dev/null 2>&1 || true

echo "🛬 postflight (post-compact): merged compact_summary → ${SEED_FILE} (bytes=${BYTES:-0}, redacted=${REDACTED}, truncated=${TRUNCATED})." >&2

# PostCompact stdout is treated as debug output (side-effect only, not a control channel). Emit
# NOTHING on stdout — conservative-safe for this event (no schema to satisfy, no validation to fail).
exit 0
