#!/usr/bin/env bash
# question-batch-gate v1.1.0 — Stop-event advisory gate against QUESTION-BATCHING.
#
# COMMUNITY PORT (2026-08-18): dogfooded 16/1622 real fires (~1%) over 2026-07-25 to
#   2026-08-18 in an operator's private `~/.claude` corpus before landing here — well
#   past the ≥2-cycle bar (`dogfooding-mandate` R1). Ported VERBATIM (byte-identical
#   logic; this repo's generic `set -euo pipefail` hook convention is deliberately
#   NOT applied — see "HOW it is safe / FAIL-SAFE" below, which the script's own
#   red-teamed design depends on). The `WHY`/`Refs` sections below cite the SOURCE
#   host's rule corpus by name as the ORIGIN of the pattern (Grice's Cooperative
#   Principle · mixed-initiative interaction discipline) — a consumer repo need not
#   have those exact files; the mechanism (heuristic question-count → advisory nudge
#   → self-answer-first) is host-agnostic. **NOT wired into this repo's own
#   `hooks/hooks.json` Stop[] array** — adding it there would silently change Stop-
#   event behaviour for every consumer that runs `/sync` or installs fresh, which is
#   an operator-confirmed decision (`[C13]`-equivalent), never an implicit one. A
#   consumer opts in by adding a `Stop[].hooks[]` entry pointing at this script.
#
# v1.1.0 (2026-07-29) ORDER FIX — measured, not guessed. See the block above the
#   counting stage: the path-safety gate used to run BEFORE the count, so the two
#   id-skip paths logged a HARDCODED `questions:0`. In the first 55 real invocations
#   after wiring, 19 (~35%) took that path — those ledger rows were indistinguishable
#   from a genuine zero-question turn, i.e. the self-blinding free-negative this very
#   header warns about. Counting is pure string work (no path, no filesystem), so it
#   now runs first; the allowlist gate sits immediately before the ONLY place the ids
#   become a path (the one-shot marker). Behaviour is unchanged on every other axis:
#   still always exit 0, still never injects without a claimable one-shot marker,
#   BLOCKING-2 traversal defence intact (proved by 2 dedicated tests).
#
# WHY (the operator's own root cause, 2026-07-25, verbatim pt-BR preserved per
#   `language-policy-en-pt` §3): "eu faço uma pergunta ela devolve +2, eu delego uma
#   tarefa ela me pergunta +10 coisas ... passou de 3 tarefas ao mesmo tempo, começo a
#   me perder". The AI is his primary load AMPLIFIER. `rules/user-rules.md` §Behavior
#   ("Cognitive load — I am the amplifier") binds **≤1 question per turn**, and
#   `harmonic` L10 / `agentic-first` §1.1.1 / `end-of-action-briefing` §7.1 all say the
#   same thing — yet NOTHING measured it. This hook is the missing fire-point.
#
# WHAT it measures (name == instrument, deliberately narrow per the "9 doors" lesson in
#   `agentic-observability-protocol` §4.1): the count of operator-facing questions in
#   `last_assistant_message`. It does NOT measure WIP — `~/.claude/todos/` does not
#   exist on this platform (probed 2026-07-25: 0 files; positive control `state/` = 1),
#   so concurrent-task count is NOT observable from a hook. Naming it `wip-*` would
#   promise WIP and deliver a question count — the exact name-vs-instrument gap.
#
# HOW it is safe:
#   * NEVER blocks. Always exit 0. Never exit 2 (exit 2 on Stop *prevents stopping*).
#   * LOOP-SAFE. Injecting additionalContext at Stop continues the turn, so an
#     always-firing gate would never let the agent stop. Guard = one-shot per
#     `prompt_id`, claimed with an ATOMIC `mkdir` (POSIX-atomic; a check-then-write
#     pair is TOCTOU-racy and was proven so by red-team). Deliberately does NOT rely
#     on `stop_hook_active` (Skopos: do not depend on a field the docs did not show
#     for this event — even though the binary does emit it).
#   * FAIL-SAFE. Missing dep / malformed input / unset HOME / write failure → exit 0.
#     A broken gate must degrade to the pre-gate baseline, never break a turn.
#   * PATH-SAFE. `session_id`/`prompt_id` come from the payload and are therefore
#     UNTRUSTED input to a filesystem path — they are rejected unless they match a
#     strict safe charset (`script-safety` §1; the sibling `context-handoff-monitor.js`
#     already guards this exact risk).
#   * MEASURABLE. EVERY invocation appends to `ledger.jsonl` — including the skip
#     paths — because a hook that is silent AND logs nothing is indistinguishable from
#     "installed and healthy" (the self-blinding free-negative, `agentic-observability-
#     protocol` §4.1). There is a plain-text fallback for the jq-missing case.
#
# HONEST LIMITS (anti-theater — stated, not glossed):
#   * The count is a HEURISTIC over markdown, not a parse of intent. Excluded:
#     fenced code (``` and ~~~), blockquotes (quoted operator voice), ATX headings
#     ("## Why?"), and table rows. Emphasis markers are stripped first so the agent's
#     own mandated bold style (`**Question?**`) is still counted.
#       - The §4.1 STATUS CHECKLIST tokens `persisted?` / `boy-scout?` live in a
#         FENCED BULLET LIST (end-of-action-briefing-protocol.md:105) and in prose
#         (:101, :116) — NOT in a table row. Verified by reading the file after a
#         red-team falsified an earlier, fabricated claim to the contrary.
#   * Rhetorical questions in prose are still counted → default threshold is 2, not 1.
#   * A `?` followed immediately by an emoji is not counted.
#   * If fence markers are unbalanced, fence-exclusion is disabled (fail toward
#     counting) so an unclosed fence cannot silently swallow a whole message.
#   * It cannot see `AskUserQuestion` tool calls (absent from `last_assistant_message`).
#   * `last_assistant_message` may be truncated by the harness (unverified residual) —
#     questions past any cut would be invisible.
#   * It is advisory: it reminds the agent, it cannot force a rewrite.
#
# NOT WIRED BY THIS FILE. `settings.json` is `[C17]` §2 HUMAN_DOMAIN / `[C13]` —
#   operator-confirmed only, and must also land in `templates/settings.template.json`.
#
# Tests: hooks/tests/question-batch-gate.test.sh
# Refs: rules/user-rules.md §Behavior · harmonic-self-conduct-laws L10 ·
#       agentic-first-decision-protocol §1.1/§1.1.1 · end-of-action-briefing §7.1/§4.1 ·
#       loose-end-triage-queue (Taxis) · agentic-observability-protocol (Metron) ·
#       environment-capability-reconnaissance (Skopos) §1.1.1 · script-safety §1 ·
#       red-teaming-mandatory-trigger (Elenchus, H6) · ai-as-pwd-axiom §2 (WARN-default)
set -uo pipefail 2>/dev/null || true

# ${HOME:-/tmp} — with `set -u`, a bare $HOME aborts the script BEFORE any fail-safe
# guard can run (red-team BLOCKING #1: reproduced exit 1 under `env -u HOME`).
STATE_DIR="${QBG_STATE_DIR:-${HOME:-/tmp}/.claude/state/question-batch-gate}"
THRESHOLD="${QBG_MAX_QUESTIONS:-2}"
case "$THRESHOLD" in ''|*[!0-9]*) THRESHOLD=2 ;; esac
[ -n "$STATE_DIR" ] || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
LEDGER="$STATE_DIR/ledger.jsonl"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || NOW="unknown"

# log <skip-reason|""> <questions> <fired> — ALWAYS called exactly once per invocation.
log() {
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg t "$NOW" --arg session "${sid:-}" --arg prompt "${pid:-}" \
           --arg skipped "$1" --argjson q "$2" --argjson fired "$3" \
      '{t:$t,session:$session,prompt_id:$prompt,questions:$q,fired:$fired}
       + (if $skipped == "" then {} else {skipped:$skipped} end)' \
      >> "$LEDGER" 2>/dev/null || true
  else
    printf '{"t":"%s","skipped":"%s","questions":%s,"fired":%s,"note":"jq-missing"}\n' \
      "$NOW" "$1" "$2" "$3" >> "$LEDGER" 2>/dev/null || true
  fi
}

sid=""; pid=""
command -v jq >/dev/null 2>&1 || { log "no_jq" 0 false; exit 0; }

payload="$(cat 2>/dev/null)" || { log "no_stdin" 0 false; exit 0; }
[ -n "$payload" ] || { log "empty_stdin" 0 false; exit 0; }

msg="$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)" \
  || { log "bad_json" 0 false; exit 0; }
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)" || sid=""
pid="$(printf '%s' "$payload" | jq -r '.prompt_id  // ""' 2>/dev/null)" || pid=""

[ -n "$msg" ] || { log "empty_message" 0 false; exit 0; }

# ---------------------------------------------------------------------------
# Count operator-facing questions. Runs BEFORE the path-safety gate below
# because counting is PURE STRING PROCESSING — it builds no path, touches no
# filesystem, and therefore needs no allowlist.
#
# (v1.1.0 ORDER FIX — measured, not guessed. In the first 55 real invocations
#  after wiring, 19 (~35%) hit `unsafe_or_absent_prompt_id`, and the old order
#  logged a HARDCODED `questions:0` on that path because the count had not run
#  yet. Those rows were indistinguishable from a genuine zero-question turn —
#  the self-blinding free-negative this file's own header warns about
#  (`agentic-observability-protocol` §4.1). The count is now always real.
#  Empirically the harness omits `prompt_id` intermittently WITHIN a single
#  session — `166633bd…` logged one invocation with a prompt_id and a later one
#  without — so this is not a per-session property that could be predicted.)
# ---------------------------------------------------------------------------
questions="$(printf '%s\n' "$msg" | awk '
  { lines[NR] = $0; if ($0 ~ /^[[:space:]]*(```|~~~)/) fences++ }
  END {
    trust_fence = (fences % 2 == 0)     # unbalanced => do not let a fence swallow text
    infence = 0
    for (i = 1; i <= NR; i++) {
      l = lines[i]
      if (l ~ /^[[:space:]]*(```|~~~)/) { if (trust_fence) infence = !infence; continue }
      if (trust_fence && infence)  continue
      if (l ~ /^[[:space:]]*>/)    continue   # blockquote = quoted operator voice
      if (l ~ /^[[:space:]]*\|/)   continue   # table row
      if (l ~ /^[[:space:]]*#/)    continue   # ATX heading ("## Why?")
      gsub(/[*_`~]/, "", l)                   # strip emphasis so **Question?** counts
      l = l " "
      n += gsub(/\?[)"\]}]*[[:space:]]/, "", l)
    }
    print n + 0
  }
' 2>/dev/null)" || questions=0
case "$questions" in ''|*[!0-9]*) questions=0 ;; esac

# Under threshold: nothing to claim, nothing to inject. Log the REAL count and
# leave — reached whether or not the ids are path-safe (v1.1.0 order fix).
if [ "$questions" -le "$THRESHOLD" ]; then log "" "$questions" false; exit 0; fi

# ---------------------------------------------------------------------------
# Path-safety gate — sited HERE, immediately before the ONLY place `sid`/`pid`
# become a filesystem path. They are UNTRUSTED payload fields, so they are
# rejected unless they match a strict allowlist, never a denylist
# (`script-safety` §1; red-team BLOCKING #2 proved `session_id:"../../../../tmp/x"`
# escaped $STATE_DIR). Absent/unsafe ids mean the one-shot marker cannot be
# claimed, and WITHOUT that loop-guard an advisory injection at Stop could
# re-fire forever — so this still skips, but now it skips having MEASURED and
# LOGGED the real question count instead of a hardcoded 0.
# ---------------------------------------------------------------------------
safe_id() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }
safe_id "$pid" || { log "unsafe_or_absent_prompt_id" "$questions" false; exit 0; }
safe_id "$sid" || { log "unsafe_session_id" "$questions" false; exit 0; }

# ---------------------------------------------------------------------------
# One-shot claim: ATOMIC mkdir. Succeeds for exactly one racer.
# ---------------------------------------------------------------------------
marker="$STATE_DIR/${#sid}.${sid}.${#pid}.${pid}.marker.d"
if ! mkdir "$marker" 2>/dev/null; then log "idempotent" "$questions" false; exit 0; fi
log "" "$questions" true

# Bounded housekeeping: drop one-shot markers older than 7 days. Scoped to our own
# dir, depth-1, literal suffix — never a computed path (`script-safety` §1).
find "$STATE_DIR" -maxdepth 1 -type d -name '*.marker.d' -mtime +7 -exec rm -rf {} + 2>/dev/null || true

read -r -d '' advice <<EOF || true
⚠️ question-batch-gate: this turn ends with ${questions} operator-facing questions (threshold ${THRESHOLD}).

The operator's binding constraint (\`rules/user-rules.md\` §Behavior — "Cognitive load — I am the amplifier"): **≤1 question per turn**, because each question he answers generates ~2 more tasks for him, and past ~3 concurrent tasks he loses the thread.

Before ending the turn: self-answer what you can (\`harmonic\` L10), run the MoE→Council ladder on the rest (\`agentic-first\` §1.1.1), and keep AT MOST the one question whose answer genuinely changes your next step — asked via \`AskUserQuestion\` with a recommended option first (\`end-of-action-briefing\` §7.1). Return finished work, not a question batch.

(Advisory only — nothing is blocked. Heuristic count; fenced code, blockquotes, headings and table rows are excluded. One injection per prompt.)
EOF

jq -cn --arg ctx "$advice" \
  '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$ctx}}' 2>/dev/null || true

exit 0
