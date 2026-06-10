#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Tool: geo-snippet.sh
# Purpose: Render the end-of-session "geo-localization" recap snippet (SSOT grammar
#          in skills/postflight/references/geo-snippet-spec.md) at one of 4 densities.
#          One glance: which session · what status · which anchor · what work · is it
#          blocked · does it need a human. A memory ramp for amnesic agents + a radar
#          for the human operator. ("What is not seen is not remembered.")
# Version: 1.0.0
# Protocol: C06 (AI-Native Environment).
#
# Anti-theater contract: the tool COMPUTES Tier-A fields (anchor, project, branch,
#   compass ↑N↓M, peers, deploy-risk ⚠R1) and ACCEPTS Tier-B self-report fields as
#   flags (--status, --slug, --seq, --enrich, --pulse) — the agent is the authority
#   on its own state; the tool never fabricates it. The objectives tree (D3) is read
#   from stdin (agent-supplied), never auto-generated.
#
# Safety: READ-ONLY (never mutates refs/index/worktree), capability-detected,
#   graceful-degrade (no gh → branch anchor; no peer-lib → omit peers; no upstream →
#   omit compass), ALWAYS exits 0 — must never block a session end.
#
# Usage:
#   geo-snippet --density name|status|ntree|conv [--status GLYPH] [--slug SLUG]
#               [--seq N] [--enrich STR] [--pulse n/m] [--base REF]
#   # D3 reads tree item-lines from stdin: "<glyph> <slug> [· <enrich>]" (one per line)
#
# Env: GEO_TICKET_RE  ticket-key regex (default '[A-Z]{2,}-[0-9]+')
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail   # intentionally NO -e: a degrade-always reporter must finish + exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
TICKET_RE="${GEO_TICKET_RE:-[A-Z]{2,}-[0-9]+}"

DENSITY="" ; STATUS="🟡" ; SLUG="" ; SEQ="" ; ENRICH="" ; PULSE="" ; BASE=""

usage() {
  printf '%s\n' \
    'usage: geo-snippet --density name|status|ntree|conv [--status GLYPH] [--slug SLUG]' \
    '                   [--seq N] [--enrich STR] [--pulse n/m] [--base REF]' \
    '       # density=ntree reads tree item-lines from stdin (one per line)' >&2
}

# ── arg parse (supports --key value AND --key=value) ───────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --density=*) DENSITY="${1#*=}" ;;     --density) DENSITY="${2:-}"; shift ;;
    --status=*)  STATUS="${1#*=}" ;;      --status)  STATUS="${2:-}";  shift ;;
    --slug=*)    SLUG="${1#*=}" ;;        --slug)    SLUG="${2:-}";    shift ;;
    --seq=*)     SEQ="${1#*=}" ;;         --seq)     SEQ="${2:-}";     shift ;;
    --enrich=*)  ENRICH="${1#*=}" ;;      --enrich)  ENRICH="${2:-}";  shift ;;
    --pulse=*)   PULSE="${1#*=}" ;;       --pulse)   PULSE="${2:-}";   shift ;;
    --base=*)    BASE="${1#*=}" ;;        --base)    BASE="${2:-}";    shift ;;
    -h|--help)   usage; exit 0 ;;
    *) ;;   # ignore unknowns (never block)
  esac
  shift
done
case "$DENSITY" in
  name|status|ntree|conv) ;;
  *) usage; exit 0 ;;
esac

# ── helpers ────────────────────────────────────────────────────────────────────
have()  { command -v "$1" >/dev/null 2>&1; }
# join non-empty parts with ' · '
emit()  { local out="" p; for p in "$@"; do [ -n "$p" ] || continue
            if [ -z "$out" ]; then out="$p"; else out="$out · $p"; fi; done; printf '%s\n' "$out"; }

# ── Tier-A computed fields (git/gh/fs/peer) ────────────────────────────────────
repo_top()   { git rev-parse --show-toplevel 2>/dev/null || true; }
cur_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || true; }

default_branch() {
  local d c
  d="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')" || true
  [ -n "$d" ] && { printf '%s' "$d"; return; }
  for c in main master; do
    git show-ref --verify --quiet "refs/heads/$c" 2>/dev/null && { printf '%s' "$c"; return; }
  done
  printf 'main'
}

compute_anchor() {   # salience: ticket › PR › branch
  local b="$1" t pr
  t="$(printf '%s' "$b" | grep -oE "$TICKET_RE" 2>/dev/null | head -1)" || true
  [ -z "$t" ] && t="$(git log -1 --format='%s' 2>/dev/null | grep -oE "$TICKET_RE" 2>/dev/null | head -1)" || true
  [ -n "$t" ] && { printf '%s' "$t"; return; }
  if have gh && [ -n "$b" ]; then
    pr="$(gh pr list --head "$b" --state open --json number -q '.[0].number' 2>/dev/null)" || true
    [ -n "$pr" ] && { printf 'PR#%s' "$pr"; return; }
  fi
  printf '%s' "$b"
}

compute_compass() {  # ↑ahead↓behind vs base (git rev-list left=behind right=ahead)
  local base="$1" out behind ahead
  [ -n "$base" ] || return 0
  git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || return 0
  out="$(git rev-list --left-right --count "$base"...HEAD 2>/dev/null)" || return 0
  [ -n "$out" ] || return 0
  behind="$(printf '%s' "$out" | awk '{print $1}')"
  ahead="$(printf '%s' "$out"  | awk '{print $2}')"
  printf '↑%s↓%s' "${ahead:-0}" "${behind:-0}"
}

compute_peers() {    # peers:N via the maos peer-session-detect lib (omit if UNKNOWN/absent)
  local top="$1" lib val
  lib="$SCRIPT_DIR/../plugin-scripts/governance/lib/peer-session-detect.sh"
  [ -f "$lib" ] || return 0
  # shellcheck disable=SC1090
  . "$lib" 2>/dev/null || return 0
  have_fn psd_peer_sessions || return 0
  val="$(psd_peer_sessions "$top" 2>/dev/null)" || true
  case "$val" in ''|UNKNOWN|*[!0-9]*) return 0 ;; esac
  printf '%s' "$val"
}
have_fn() { command -v "$1" >/dev/null 2>&1; }

compute_risk() {     # ⚠R1: on default branch AND a deploy-on-push workflow present (heuristic, Tier-A)
  local b="$1" top
  [ "$b" = "$(default_branch)" ] || return 0
  top="$(repo_top)"; [ -n "$top" ] || return 0
  [ -d "$top/.github/workflows" ] || return 0
  grep -rliE 'deploy' "$top/.github/workflows" >/dev/null 2>&1 && printf '⚠R1'
  return 0
}

# ── derive ─────────────────────────────────────────────────────────────────────
[ -n "$BASE" ] || BASE="origin/$(default_branch)"
BRANCH="$(cur_branch)"
PROJECT="$(top="$(repo_top)"; [ -n "$top" ] && basename "$top")"
ANCHOR="$(compute_anchor "$BRANCH")"
COMPASS="$(compute_compass "$BASE")"
PEERS="$(compute_peers "$(repo_top)")"
RISK="$(compute_risk "$BRANCH")"

# slug: explicit, else derived from branch (strip type/ prefix and TICKET- prefix), capped ≤24
if [ -z "$SLUG" ]; then
  SLUG="$(printf '%s' "$BRANCH" | sed -E 's@^[a-z]+/@@; s@^[A-Z]+-[0-9]+-@@')"
fi
SLUG="$(printf '%s' "$SLUG" | cut -c1-24)"

# D1 enrich = explicit only (keep the name clean — clarity>density); D2/D3 surface
# compass/pulse/peers as their own computed fields, so the name never duplicates them.
ENRICH_OUT="$ENRICH"
SEQTOK="" ; [ -n "$SEQ" ] && SEQTOK="#$SEQ"
PULSETOK="" ; [ -n "$PULSE" ] && PULSETOK="${PULSE}🟢"
PEERSTOK="" ; [ -n "$PEERS" ] && PEERSTOK="peers:$PEERS"

# ── render ─────────────────────────────────────────────────────────────────────
case "$DENSITY" in
  name)
    # <status> · <anchor> · <slug> [· #seq] [· enrich]
    emit "$STATUS" "$ANCHOR" "$SLUG" "$SEQTOK" "$ENRICH_OUT"
    ;;
  status)
    # <status> <project>:<branch> · <slug> [· #seq] [· compass] [· pulse] [· peers] [· risk]
    emit "$STATUS ${PROJECT:+$PROJECT:}$BRANCH" "$SLUG" "$SEQTOK" "$COMPASS" "$PULSETOK" "$PEERSTOK" "$RISK"
    ;;
  ntree)
    # header (like name + compass) then tree items from stdin (agent-supplied)
    emit "$STATUS" "$ANCHOR" "$SLUG" "$SEQTOK" "$COMPASS"
    if [ ! -t 0 ]; then
      items=()
      while IFS= read -r line || [ -n "$line" ]; do [ -n "$line" ] && items+=("$line"); done
      n=${#items[@]} ; i=0
      for line in "${items[@]:-}"; do
        [ -n "$line" ] || continue
        i=$((i + 1))
        if [ "$i" -eq "$n" ]; then printf '└─ %s\n' "$line"; else printf '├─ %s\n' "$line"; fi
      done
    fi
    ;;
  conv)
    printf 'conv: base-3+🟠 · anchor=ticket›PR›branch›task · #seq=chain/omit · enrich-auto · Tier A/B/C\n'
    ;;
esac
exit 0
