#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: reload-session.sh
# Purpose: SessionStart[source=compact] continuation-RELOAD. The ONLY hook that can inject
#   context across a compaction (via additionalContext). When a session restarts right after
#   the harness compacted the conversation, this reads the continuation-seed the SAVE-side
#   hooks left on disk (PreCompact skeleton + PostCompact compact_summary + any /maos:postflight
#   rich synthesis) and injects a bounded, FACTUAL continuation block so the fresh amnesic agent
#   wakes oriented on the prior work instead of blank.
#
#   Sibling of preflight-session.sh (each SessionStart hook emits ONE JSON object; multiple
#   hooks' additionalContext concatenate). Reads the seed from the FILE, not stdin — immune to
#   the undocumented PostCompact↔SessionStart ordering (monotonic enrichment on disk).
#   NEVER blocks (always exit 0, always valid JSON). NEVER fabricates (no seed / no jq → nothing).
# Version: 0.1.1
# Protocol: C04 (Git Worktree), C06 (AI-Native Environment)
# Event: SessionStart (matcher "")
#
# Predicate: source=compact → inject. source=resume → opt-in (MAOS_RELOAD_ON_RESUME=1; default
#   off — resume already replays the transcript). source=startup|clear → NEVER (cold boot /
#   deliberate wipe; recover on-demand via /maos:session-reentry). POSTFLIGHT_SEED_DIR overrides.
#   Opt-out: MAOS_NO_RELOAD=1 → skip entirely.
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

[ "${MAOS_NO_RELOAD:-0}" = "1" ] && exit 0

# ── Read the SessionStart stdin (best-effort; bounded) ────────────────────────
STDIN_JSON=""
[ ! -t 0 ] && STDIN_JSON="$(timeout 1 cat 2>/dev/null || true)"
get_field() { # $1=field → value or "" (jq if present, else grep fallback)
  local f="$1"
  if command -v jq >/dev/null 2>&1 && [ -n "$STDIN_JSON" ]; then
    printf '%s' "$STDIN_JSON" | jq -r ".${f} // empty" 2>/dev/null
  else
    printf '%s' "$STDIN_JSON" | grep -o "\"${f}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"'"${f}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
  fi
}

# ── Predicate: inject ONLY on compaction (resume opt-in; startup/clear never) ──
SOURCE="$(get_field source)"
case "$SOURCE" in
  compact) : ;;
  resume)  [ "${MAOS_RELOAD_ON_RESUME:-0}" = "1" ] || exit 0 ;;
  *)       exit 0 ;;
esac

# The render needs jq — a deterministic factual block, never a hand-waved paraphrase.
command -v jq >/dev/null 2>&1 || exit 0

# ── Repo + seed resolution (multi-probe; mirrors preflight-session.sh) ─────────
REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || exit 0
SEED=""
SEED_GITDIR="$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null || true)"
SEED_COMMON="$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
for _d in "${POSTFLIGHT_SEED_DIR:-}" "${SEED_GITDIR:+$SEED_GITDIR/maos}" "${SEED_COMMON:+$SEED_COMMON/maos}" "$REPO/.git/maos"; do
  [ -n "$_d" ] || continue
  if [ -f "$_d/continuation-seed.latest.json" ]; then SEED="$_d/continuation-seed.latest.json"; break; fi
done
[ -n "$SEED" ] || exit 0                       # no seed → nothing to inject
jq -e . "$SEED" >/dev/null 2>&1 || exit 0       # corrupt → nothing (never fabricate)

# ── Deterministic render (fixed priority; FACTS not imperatives; compact_summary capped) ──
# Priority: active_world → goal → dod → next_actions → gaps → compact_summary → refs →
# resume_instructions. active_world (1.4.0) renders FIRST, before the mission — which
# identity/credential world a resuming agent is in is foundational orientation (Two-Worlds
# hard boundary, `~/.claude/rules/user-rules.md`), and must land before any task detail.
BODY="$(jq -r '
  .params as $p
  | ($p.refs // {}) as $r
  | ($p.git // {}) as $g
  | ( if ($p.dod|type)=="array" then $p.dod
      elif ($p.acceptance|type)=="array" then $p.acceptance
      else [] end ) as $dod
  | [
      "Prior-session continuation seed loaded (kind=\($p.kind // "unknown"), captured \($p.captured_at // "n/a")). The following is verified prior state — resume from it rather than re-deriving.",
      ( if ($p.active_world // "") != "" then "Active world: \($p.active_world) (Two-Worlds boundary — do not cross identities/repos/credentials)." else empty end ),
      ( if (($p.goal // $p.mission[0]) // "") != "" then "Mission: \(($p.goal // $p.mission[0]))." else empty end ),
      ( if ($dod|length) > 0 then "Definition of Done: " + ($dod|map(tostring)|join(" · ")) + "." else empty end ),
      ( if ($p.next_actions|type)=="array" and ($p.next_actions|length) > 0 then
          "Next actions: " + ($p.next_actions|map( if type=="object" then ((.task // "?") + (if .blocked_by then " [blocked: \(.blocked_by)]" else "" end)) else tostring end )|join(" · ")) + "."
        else empty end ),
      ( if ($p.gaps|type)=="array" and ($p.gaps|length) > 0 then "Open gaps: " + ($p.gaps|map(tostring)|join(" · ")) + "." else empty end ),
      ( if ($p.compact_summary.present // false) and (($p.compact_summary.text // "") != "") then
          "Harness compaction summary: " + ($p.compact_summary.text[0:3500]) + (if ($p.compact_summary.text|length) > 3500 then " …(summary clipped)" else "" end)
        elif ($p.compact_summary.redacted // false) then "Harness compaction summary was present but redacted (a secret pattern was detected)."
        else empty end ),
      "Refs: branch \($g.branch // $r.git // "?"), ticket \($r.ticket // "none"), session \($r.session // "?")" + (if (($g.tree_state) // "") != "" then ", git tree \($g.tree_state), unpushed \($g.unpushed_commits // 0)" else "" end) + ".",
      ( if ($p.resume_instructions // "") != "" then "Resume instructions from the seed: \($p.resume_instructions)" else empty end )
    ]
  | map(select(. != null and . != ""))
  | join("\n")
' "$SEED" 2>/dev/null || true)"
[ -n "$BODY" ] || exit 0

# ── Bounded truncation (footer ALWAYS survives) ───────────────────────────────
# additionalContext is capped (≤10k). Budget the body at ~9000 chars, cut at a line boundary,
# THEN append the footer — so the re-entry pointers are never pushed out by a huge summary.
FOOTER="Full structured re-entry: run /maos:session-reentry. Orient git state: run /maos:preflight."
MAXBODY=9000
if [ "${#BODY}" -gt "$MAXBODY" ]; then
  BODY="$(printf '%s' "${BODY:0:$MAXBODY}" | sed '$d')"   # drop the partial last line
  BODY="${BODY}
…(seed truncated for injection; the full seed is on disk)"
fi
CTX="${BODY}
${FOOTER}"

# ── Secret-scan the final CTX before injection (defense-in-depth; fail-closed) ─
# The rich seed's goal/dod/next_actions/resume_instructions come from /maos:postflight and are
# NOT guaranteed secret-scanned at their source (only compact_summary is scrubbed SAVE-side by
# postflight-postcompact.sh). ⛔ ABSOLUTE — NEVER inject a secret into a fresh session's context:
# on ANY match WITHHOLD the body, inject only a safe on-disk pointer. Idiom verbatim from
# postflight-postcompact.sh:66 (bin/spawn-continuation.sh lineage).
if printf '%s' "$CTX" | grep -Eiq '(-----BEGIN [A-Z ]*PRIVATE KEY|aws_secret_access_key|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|password["'\'' :=]+[^ "'\'']{6,})'; then
  echo "🔒 reload (post-compact): secret pattern detected in seed → body WITHHELD from injection (seed retained on disk: ${SEED})." >&2
  CTX="A prior-session continuation seed is present on disk but was WITHHELD from injection — a secret pattern was detected in it. Do NOT reconstruct it from memory. Review the seed manually on disk, then continue.
${FOOTER}"
fi

# ── json_escape (inline; no lib dependency for a reader) + emit ───────────────
json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }

echo "🧭 reload (post-compact): injected continuation seed → ${SEED} (source=${SOURCE})." >&2
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$CTX")"
exit 0
