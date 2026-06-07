#!/usr/bin/env bash
# Agentic Session Harness (ASH) — Stop hook (fallback path, co-equal graceful degradation)
# Function: idempotent fallback that writes a minimal journal entry when the primary
#   Stop subagent (type:agent) does NOT fire OR produces no entry (L1 limitation per spec §8).
# Spec: docs/governance/ash-schema.md §2 schema + §3 tenant fallback
# Idempotent: if subagent already wrote entry for this session, skip.
# Runs AFTER type:agent Stop subagent (registered in settings.json).
# Portability: AAIF cross-vendor compatible — uses POSIX-portable primitives (mkdir-based atomic lock + jq idempotency); adaptable to any host emitting Stop event with session_id stdin payload.
# No organization-specific content — promotion-eligible per Layer Purity Rule 2.
set -euo pipefail

# v1.4.0 hook-timing shims + tenant/transcript/goal helpers now live in lib.sh
# (DRY per ADR-014; behavior identical — see ash-schema.md §15). Source relative to
# THIS script's directory so it resolves regardless of caller cwd.
ASH_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "$ASH_HOOK_DIR/lib.sh"

INPUT=$(cat 2>/dev/null || echo '{}')
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$SID" ] || { echo '{}'; exit 0; }

# CWE-78 defense: validate SID format (UUID-like — alnum + hyphens only)
case "$SID" in
  *[!a-zA-Z0-9-]*|""|.|..) echo '{}'; exit 0 ;;
esac

# Entry-point sanity check on PROJECT_DIR (defense-in-depth)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJECT_DIR" in /*) ;; *) echo '{}'; exit 0 ;; esac
[ -d "$PROJECT_DIR" ] || { echo '{}'; exit 0; }

TODAY_UTC=$(date -u +%Y-%m)
DAY_UTC=$(date -u +%d)
# Format-validate date components (defense vs hypothetical malicious TZ/date override)
case "$TODAY_UTC" in [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;; *) echo '{}'; exit 1 ;; esac
case "$DAY_UTC" in [0-9][0-9]) ;; *) echo '{}'; exit 1 ;; esac
AUDIT_DIR="$PROJECT_DIR/.claude/audit/$TODAY_UTC"
JOURNAL="$AUDIT_DIR/$DAY_UTC.jsonl"
JLOCK="$JOURNAL.lock"   # journal-WIDE append lock (cross-session); see append critical-section below

mkdir -p "$AUDIT_DIR"

# Atomic idempotency lock — mkdir is atomic per POSIX. Lock dir per (session, day).
# Prevents race where 2 concurrent fallbacks both pass grep check before either writes.
LOCK_DIR="$AUDIT_DIR/.lock-${SID}-${DAY_UTC}"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Another instance is writing — exit silently, idempotency preserved.
  echo '{}'
  exit 0
fi
# Cleanup BOTH locks on any exit (per-session idempotency lock + journal-wide append lock).
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true; rmdir "$JLOCK" 2>/dev/null || true' EXIT

# Idempotency check — JSON-aware (robust to whitespace variations the Stop subagent may emit).
# Per Qodo R1 finding: grep substring is fragile when LLM may format JSON differently.
# v1.4.0: when subagent already wrote an entry we still emit a SECOND, minimal
# entry tagged hook_kind=fallback-after-subagent-success so duration aggregations
# can quantify "subagent latency proxy" via paired entries (peer_entry_ref TBD W4+).
SUBAGENT_ALREADY_WROTE=0
if [ -f "$JOURNAL" ] && jq -se --arg sid "$SID" 'any(.[]; .session? == $sid)' "$JOURNAL" 2>/dev/null | grep -q '^true$'; then
  SUBAGENT_ALREADY_WROTE=1
  # Operator preference (v1.4.0): preserve current behavior — exit silently when
  # subagent succeeded, to keep journals lean. Switch this branch to a duration-only
  # entry if subagent latency measurement becomes a priority.
  echo '{}'
  exit 0
fi

# Resolve tenant per §3 fallback chain (lib.sh — identical logic)
TENANT=$(ash_resolve_tenant "$PROJECT_DIR")

# Locate transcript (lib.sh)
TRANSCRIPT_REL=$(ash_locate_transcript_rel "$PROJECT_DIR" "$SID")
TRANSCRIPT_ABS="$PROJECT_DIR/$TRANSCRIPT_REL"
TRANSCRIPT_HASH=$(ash_sha256 "$TRANSCRIPT_ABS")

# Enrich: extract first operator-typed (string-content) user message as goal (lib.sh).
# Guard preserved: only attempt when transcript present (hash non-empty + readable).
GOAL_TEXT=""
if [ -n "$TRANSCRIPT_HASH" ] && [ -r "$TRANSCRIPT_ABS" ]; then
  GOAL_TEXT=$(ash_extract_goal "$TRANSCRIPT_ABS")
fi
[ -n "$GOAL_TEXT" ] || GOAL_TEXT="(fallback — empty or unparseable transcript)"

# Compose enriched fallback entry — goal carries operator's first directive verbatim;
# task remains a transcript-pointer (full task reconstruction needs the Stop subagent).
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROJECT_NAME=$(basename "$PROJECT_DIR")

# §17 decision-audit (v1.6.2): STRUCTURAL extraction of agent decisions from the transcript
# on this RELIABLY-FIRING fallback path. The Stop type:agent step-10 extraction empirically
# never wrote an entry (0/N real sessions); this makes capture deterministic + amnesia-proof.
# Emits §17.1 decisions[] with XDEC-<n> ids; decide-merge.sh then folds any manual DEC-<n>
# (staged via bin/agentic-decide) on top (the high-fidelity "why" ceiling), deduped by id.
# Anti-hallucination: no git/gh signal => "[]" (omitted from the sparse entry).
DECISIONS_JSON="[]"
if [ -n "$TRANSCRIPT_HASH" ] && [ -r "$TRANSCRIPT_ABS" ]; then
  DECISIONS_JSON=$(ash_extract_decisions "$TRANSCRIPT_ABS" "$NOW_UTC")
fi
case "$DECISIONS_JSON" in ''|*[![:print:][:space:]]*) DECISIONS_JSON="[]" ;; esac

# Journal-WIDE append lock: the per-session LOCK_DIR guards same-session idempotency, but two
# DIFFERENT sessions ending at once both append to the shared day JOURNAL; a JSONL line can exceed
# PIPE_BUF so concurrent `>>` is NOT atomic and can interleave/corrupt. Serialize the append
# (bounded retry — the hold is sub-ms so contention effectively never times out).
_jlocked=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if mkdir "$JLOCK" 2>/dev/null; then _jlocked=1; break; fi
  sleep 0.2
done

# Emit a row conforming to the FROZEN Layer-1 17-field contract (SPEC.md §2). The hook timing
# fields (hook_started_at/ended_at/duration_ms/hook_kind) were a Layer-2 v1.4.0 observability
# enrichment outside the frozen schema; omitted here for Layer-1 conformance (re-addable as a
# documented SPEC extension). schema_version is stamped from $ASH_SCHEMA_CURRENT (= "1.0.0").
jq -nc \
  --arg ts "$NOW_UTC" \
  --arg tenant "$TENANT" \
  --arg project "$PROJECT_NAME" \
  --arg sid "$SID" \
  --arg hash "$TRANSCRIPT_HASH" \
  --arg rel "$TRANSCRIPT_REL" \
  --arg goal "$GOAL_TEXT" \
  --arg schema_ver "$ASH_SCHEMA_CURRENT" \
  --argjson decisions "$DECISIONS_JSON" \
  '{
    schema_version: $schema_ver,
    ts: $ts,
    tenant: $tenant,
    project: $project,
    session: $sid,
    agent: "fallback-hook",
    goal: $goal,
    task: "(see transcript for executed steps)",
    transcript_hash: $hash,
    transcript_rel: $rel
  }
  + (if ($decisions | length) > 0 then {decisions: $decisions} else {} end)' >> "$JOURNAL"

[ "$_jlocked" = "1" ] && rmdir "$JLOCK" 2>/dev/null || true

echo '{}'
