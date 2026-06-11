#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: postflight-precompact.sh
# Purpose: PreCompact safety-net for the `postflight` bundle. Fires right before the
#   operator (or auto-compaction at high context) compacts/clears the conversation —
#   exactly when an amnesic agent is about to lose its volatile context. Writes a
#   DETERMINISTIC continuation-seed snapshot (git/session metadata) to a durable file
#   so continuity NEVER fully fails, even if the `postflight` skill was not invoked.
#
#   This hook is the DETERMINISTIC SKELETON. It does NOT fake the agentic synthesis
#   (objectives N-Tree, Eisenhower next-actions, resume prose) — that is the skill's
#   job (PROBABILISTIC MUSCLE). The hook captures only cheap, factual state + a nudge
#   to run /maos:postflight for the rich seed. NEVER blocks the session (always exit 0).
# Version: 0.1.1
# Protocol: C04 (Git Worktree), C06 (AI-Native Environment)
# Event: PreCompact
#
# Opt-out: POSTFLIGHT_NO_AUTOSNAPSHOT=1 → skip entirely.
# Opt-in : POSTFLIGHT_SNAPSHOT_PRS=1 → also fetch open-PR state via gh (network; default
#          off = fast + offline-safe). POSTFLIGHT_SEED_DIR=<path> → override snapshot dir.
# ═══════════════════════════════════════════════════════════════════════════════

# NOTE: deliberately `set -uo pipefail` WITHOUT `-e`. This is a PreCompact safety-net hook
# bound to a "never blocks / exit 0 always" contract — a failing git/probe command must NOT
# abort before it reaches `exit 0`. `-u` (plus defaulted `${VAR:-…}` expansions) still catches
# our own typos; every fallible command is individually guarded (`|| …` / `2>/dev/null`).
set -uo pipefail

# Opt-out → no-op (never block).
[ "${POSTFLIGHT_NO_AUTOSNAPSHOT:-0}" = "1" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
# Helpers are best-effort: if the lib is absent the hook still degrades to a no-op snapshot.
[ -f "${LIB_DIR}/common.sh" ] && source "${LIB_DIR}/common.sh" 2>/dev/null || true
[ -f "${LIB_DIR}/git-branch-detect.sh" ] && source "${LIB_DIR}/git-branch-detect.sh" 2>/dev/null || true

# Minimal json-escape fallback if common.sh was unavailable.
if ! command -v json_escape >/dev/null 2>&1; then
  json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }
fi

# ── Read the PreCompact stdin (best-effort; bounded) ──────────────────────────
STDIN_JSON=""
if [ ! -t 0 ]; then STDIN_JSON="$(timeout 1 cat 2>/dev/null || true)"; fi
get_field() { # $1=field → value or "" (jq if present, else grep fallback)
  local f="$1"
  if command -v jq >/dev/null 2>&1 && [ -n "$STDIN_JSON" ]; then
    printf '%s' "$STDIN_JSON" | jq -r ".${f} // empty" 2>/dev/null
  else
    printf '%s' "$STDIN_JSON" | grep -o "\"${f}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"'"${f}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
  fi
}
SESSION_ID="$(get_field session_id)"; [ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TRIGGER="$(get_field trigger)";       [ -z "$TRIGGER" ] && TRIGGER="unknown"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Repo = the project dir Claude Code runs in (read-only probe) ──────────────
REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0   # not a git repo → nothing to snapshot (vendor-neutral, silent off-git)
fi
REPO_NAME="$(basename "$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || echo "$REPO")")"

# ── Deterministic git state (prefer lib; fall back to plain git) ──────────────
if command -v gbd_current_branch >/dev/null 2>&1; then
  BRANCH="$(gbd_current_branch "$REPO" 2>/dev/null || echo unknown)"
  UPSTREAM="$(gbd_upstream "$REPO" 2>/dev/null || echo none)"
  STATE="$(gbd_tree_state "$REPO" 2>/dev/null || echo unknown)"
else
  BRANCH="$(git -C "$REPO" branch --show-current 2>/dev/null || echo unknown)"
  UPSTREAM="$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo none)"
  STATE="$([ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ] && echo DIRTY || echo CLEAN)"
fi
WORKTREES="$(git -C "$REPO" worktree list 2>/dev/null | wc -l | tr -d ' ')"
UNPUSHED="$(git -C "$REPO" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')"

# ── Optional open-PR state (opt-in; network) ──────────────────────────────────
PRS="[]"
if [ "${POSTFLIGHT_SNAPSHOT_PRS:-0}" = "1" ] && command -v gh >/dev/null 2>&1; then
  PRS="$(timeout 6 gh pr list --repo "$(git -C "$REPO" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]([^/]+/[^/.]+).*#\1#')" --state open --json number,title,state --jq 'map("#\(.number) \(.state)")' 2>/dev/null || echo '[]')"
  [ -z "$PRS" ] && PRS="[]"
fi

# ── Write the deterministic seed snapshot to a durable file (survives compaction)
# Default location is INSIDE the git dir (always git-ignored) so the snapshot never makes the
# working tree appear DIRTY at compaction time. Override with POSTFLIGHT_SEED_DIR.
GIT_DIR="$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null || echo "${REPO}/.git")"
SEED_DIR="${POSTFLIGHT_SEED_DIR:-${GIT_DIR}/maos}"
mkdir -p "$SEED_DIR" 2>/dev/null || true
SEED_FILE="${SEED_DIR}/continuation-seed.latest.json"
SEED_JSON=$(cat <<JSON
{"jsonrpc":"2.0","method":"session.continuation","params":{"kind":"deterministic-snapshot","captured_at":"$(json_escape "$TS")","trigger":"$(json_escape "$TRIGGER")","session_id":"$(json_escape "$SESSION_ID")","git":{"repo":"$(json_escape "$REPO_NAME")","branch":"$(json_escape "$BRANCH")","upstream":"$(json_escape "$UPSTREAM")","tree_state":"$(json_escape "$STATE")","worktrees":${WORKTREES:-0},"unpushed_commits":${UNPUSHED:-0},"open_prs":${PRS}},"resume_instructions":"Run /maos:preflight to orient, then /maos:postflight for the full agentic continuation seed (this file is a deterministic skeleton, not the synthesized seed)."},"data":{"layer":"community"}}
JSON
)
# Atomic write (tmp → mv); never fail the hook.
if printf '%s\n' "$SEED_JSON" > "${SEED_FILE}.tmp" 2>/dev/null; then
  mv -f "${SEED_FILE}.tmp" "$SEED_FILE" 2>/dev/null || rm -f "${SEED_FILE}.tmp" 2>/dev/null || true
fi
# Durable cross-session copy (best-effort).
AUDIT_SEED_DIR="${CLAUDE_AUDIT_DIR:-${HOME:-/tmp}/.claude/audit}/continuation-seeds"
if mkdir -p "$AUDIT_SEED_DIR" 2>/dev/null; then
  printf '%s\n' "$SEED_JSON" > "${AUDIT_SEED_DIR}/${SESSION_ID}.json" 2>/dev/null || true
fi

# Audit (no-op unless an audit dir exists). Isolated in a SUBSHELL so a `set -u` exit from
# the sourced lib (e.g. an unguarded ${HOME} in common.sh when HOME is unset) dies in the
# subshell and is caught by `|| true` — it cannot escape to abort this never-blocks hook.
( command -v log_audit >/dev/null 2>&1 \
    && log_audit "postflight_precompact" "{\"branch\":\"$(json_escape "$BRANCH")\",\"tree\":\"$(json_escape "$STATE")\",\"unpushed\":${UNPUSHED:-0},\"trigger\":\"$(json_escape "$TRIGGER")\"}" ) >/dev/null 2>&1 || true

# Human nudge → stderr (visible, non-blocking).
echo "🛬 postflight (pre-compact): snapshot saved → ${SEED_FILE} (branch=${BRANCH}, tree=${STATE}, unpushed=${UNPUSHED:-0}). Run /maos:postflight for the full continuation seed." >&2

# Valid JSON on stdout (repo hook contract) — surfaces the seed pointer to the operator.
# SCHEMA FIX 2026-06-11: PreCompact hook output accepts only ROOT-LEVEL fields (e.g.
# `systemMessage`, `continue`, `suppressOutput`). The previous
# `{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":...}}` shape is
# INVALID for this event and reproducibly failed Claude Code's hook JSON validation
# ("Hook JSON output validation failed — (root): Invalid input"). `additionalContext` is a
# SessionStart/UserPromptSubmit affordance, not a PreCompact one.
printf '{"systemMessage":"%s"}\n' \
  "$(json_escape "postflight pre-compact snapshot → ${SEED_FILE} (branch=${BRANCH}, tree=${STATE}, unpushed=${UNPUSHED:-0}); run /maos:postflight for the full continuation seed.")"

exit 0
