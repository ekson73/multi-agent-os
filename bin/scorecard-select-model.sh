#!/usr/bin/env bash
# scorecard-select-model.sh — dynamic context-based model selector for the
# postflight end-of-action scorecard (bin/scorecard.py has 8 layout models).
# Closes issue #132 (operator green-light 2026-06-11: keep ALL models as official
# templates; select dynamically/selectively/hybridly per invocation).
#
# ARCHITECTURE (who judges what — the deterministic/probabilistic split):
#   - The INVOKING AGENT (probabilistic) distils the session's qualitative factors
#     [contexto · escopo · propósito · objetivo · risco · segurança · impacto ·
#      urgência · importância · criticidade · human/agent] into the small flag set
#     below. That distillation is the agent's judgment call.
#   - THIS SCRIPT (deterministic) maps flags → model via a first-match decision
#     table. Same flags → same model, always (CI-testable contract).
#   - NON-DETERMINISTIC OVERRIDE (opt-in hybrid): the agent may bypass the table
#     with POSTFLIGHT_SCORECARD_MODEL=<id|name> (+ a reason in its own log) when
#     its contextual judgment disagrees with the table. Highest precedence.
#
# WHY a separate front-door (and why scorecard-next-model.sh survives):
#   scorecard.py stays a PURE renderer; scorecard-next-model.sh stays the
#   round-robin engine (state-holding, operator-exposure mechanism — preserved
#   as a selectable mode per boy-scout/continuity, NOT deleted). This script is
#   the selection POLICY front-door that postflight P2 calls.
#
# Usage:
#   scorecard-select-model.sh [--mode dynamic|round-robin]
#                             [--audience human|agent] [--purpose end-of-action|briefing|handoff]
#                             [--items N] [--open N] [--risk low|med|high]
#                             [--urgency low|med|high] [--explain]
#   scorecard-select-model.sh -h|--help
#
# Flags (all optional — omitted flags take the conservative default):
#   --mode      dynamic (default) → decision table below.
#               round-robin       → delegate to scorecard-next-model.sh (interim
#                                   exposure mechanism, operator decision 2026-06-10).
#   --audience  human (default) | agent  — who reads the render. agent → Telemetry.
#   --purpose   end-of-action (default) | briefing | handoff
#               briefing → Briefing Card (M8); handoff → Telemetry (M6).
#   --items     checklist size (int ≥0; default 0)
#   --open      open/pending items (int ≥0; default 0)
#   --risk      MAX of the session's [risco, segurança, impacto, criticidade]
#               distilled by the agent: low (default) | med | high
#   --urgency   low (default) | med | high
#   --explain   print the matched rule to stderr (diagnostic; stdout unchanged)
#
# DECISION TABLE (first match wins — deterministic):
#   R0  POSTFLIGHT_SCORECARD_MODEL set+valid → pin (printed verbatim; any mode)
#   R1  --audience agent                     → 6  Telemetry (JSON-RPC sidecar)
#   R2  --purpose briefing                   → 8  Briefing Card (morning-briefing V2)
#   R3  --purpose handoff                    → 6  Telemetry (agent-to-agent seed)
#   R4  --risk high OR --urgency high        → 1  Cockpit (full debrief for stakes)
#   R5  trivial: items ≤2 AND open == 0      → 7  Executive One-Liner
#       (fires ONLY when --items/--open were explicitly provided — "no information"
#        is NOT "trivial"; a bare call falls through to R8)
#   R6  open-heavy: open ≥4 OR open ≥ items/2 (open ≥2) → 5  Kanban (what's-left headline)
#   R7  backlog-heavy: items ≥8              → 4  Burndown Ledger
#   R8  default                              → 2  Traffic-Light Strip (gallery 🥇 91)
#   (M3 KPI Tiles stays on-demand via --model 3 / pin — no automatic rule earns it
#    over M1/M2 in the rubric; see gallery.md.)
#
# Output contract: prints exactly ONE model token (1..8 or the pinned name) and
# ALWAYS exits 0 — drop-in compatible with `N=$(...)` in postflight P2. Invalid
# flag values warn to stderr and fall back to their defaults (never abort a
# session-end debrief).
#
# Bash 3.2-safe, self-contained. Composed by skills/postflight (P2 DEBRIEF).
# License: MIT (matches the multi-agent-os repo LICENSE).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || printf '.')"
RR="$DIR/scorecard-next-model.sh"
SCORECARD="$DIR/scorecard.py"
N_MODELS=8

# ── defaults (conservative) ──────────────────────────────────────────────────
MODE="dynamic"
AUDIENCE="human"
PURPOSE="end-of-action"
ITEMS=0
OPEN=0
SIZED=0   # 1 when --items/--open explicitly provided (gates R5: no-info ≠ trivial)
RISK="low"
URGENCY="low"
EXPLAIN=0

_warn() { printf 'scorecard-select-model: %s\n' "$1" >&2; }

_enum() {  # $1=value $2=flag-name $3=default $4...=allowed; junk → default + warn
  local v="$1" flag="$2" def="$3"; shift 3
  local a
  for a in "$@"; do [ "$v" = "$a" ] && { printf '%s' "$v"; return; }; done
  _warn "ignoring invalid value '$v' for $flag — using $def"
  printf '%s' "$def"
}

# ── arg parse (tolerant: unknown flags warn + skip; never abort) ─────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)     MODE="$(_enum "${2:-}" --mode dynamic dynamic round-robin)"; shift 2 ;;
    --audience) AUDIENCE="$(_enum "${2:-}" --audience human human agent)"; shift 2 ;;
    --purpose)  PURPOSE="$(_enum "${2:-}" --purpose end-of-action end-of-action briefing handoff)"; shift 2 ;;
    --items)    # invalid value = NO information → do NOT mark SIZED (can't earn R5)
      case "${2:-}" in
        '' | *[!0-9]*) _warn "ignoring non-numeric value '${2:-}' for --items" ;;
        *) ITEMS="$2"; SIZED=1 ;;
      esac; shift 2 ;;
    --open)
      case "${2:-}" in
        '' | *[!0-9]*) _warn "ignoring non-numeric value '${2:-}' for --open" ;;
        *) OPEN="$2"; SIZED=1 ;;
      esac; shift 2 ;;
    --risk)     RISK="$(_enum "${2:-}" --risk low low med high)"; shift 2 ;;
    --urgency)  URGENCY="$(_enum "${2:-}" --urgency low low med high)"; shift 2 ;;
    --explain)  EXPLAIN=1; shift ;;
    -h|--help)  sed -n '2,68p' "$0"; exit 0 ;;
    *)          _warn "ignoring unknown flag '$1'"; shift ;;
  esac
done

_emit() {  # $1=model $2=rule-id $3=rule-gloss
  [ "$EXPLAIN" = "1" ] && _warn "rule $2 matched → model $1 ($3)"
  printf '%s\n' "$1"
  exit 0
}

# ── R0: pin override (highest precedence in ANY mode) ────────────────────────
# Validation mirrors scorecard-next-model.sh: numeric in range accepted as-is;
# names probed against scorecard.py (the alias-registry SSOT); unprobeable → accept.
_is_valid_model() {
  case "$1" in
    '') return 1 ;;
    *[!0-9]*) ;;
    *) if [ "$1" -ge 1 ] && [ "$1" -le "$N_MODELS" ]; then return 0; else return 1; fi ;;
  esac
  command -v python3 >/dev/null 2>&1 && [ -f "$SCORECARD" ] || return 0
  python3 "$SCORECARD" --model "$1" --demo --no-color >/dev/null 2>&1
}
if [ -n "${POSTFLIGHT_SCORECARD_MODEL:-}" ]; then
  if _is_valid_model "$POSTFLIGHT_SCORECARD_MODEL"; then
    _emit "$POSTFLIGHT_SCORECARD_MODEL" R0 "env pin POSTFLIGHT_SCORECARD_MODEL"
  fi
  _warn "ignoring invalid POSTFLIGHT_SCORECARD_MODEL=$POSTFLIGHT_SCORECARD_MODEL — continuing with --mode=$MODE"
fi

# ── round-robin mode: delegate to the preserved interim engine ───────────────
if [ "$MODE" = "round-robin" ]; then
  if [ -x "$RR" ]; then
    out="$("$RR" 2>/dev/null)"
    case "$out" in
      '' | *[!0-9]*) _warn "round-robin engine returned junk — falling back to model 2"; _emit 2 RR-FB "round-robin fallback" ;;
      *) _emit "$out" RR "delegated to scorecard-next-model.sh" ;;
    esac
  fi
  _warn "scorecard-next-model.sh not found/executable — falling back to model 2"
  _emit 2 RR-FB "round-robin engine missing"
fi

# ── dynamic mode: first-match decision table ─────────────────────────────────
[ "$AUDIENCE" = "agent" ]    && _emit 6 R1 "agent audience → Telemetry"
[ "$PURPOSE" = "briefing" ]  && _emit 8 R2 "briefing purpose → Briefing Card"
[ "$PURPOSE" = "handoff" ]   && _emit 6 R3 "handoff purpose → Telemetry"
if [ "$RISK" = "high" ] || [ "$URGENCY" = "high" ]; then
  _emit 1 R4 "high risk/urgency → Cockpit full debrief"
fi
if [ "$SIZED" = "1" ] && [ "$ITEMS" -le 2 ] && [ "$OPEN" -eq 0 ]; then
  _emit 7 R5 "trivial session → Executive One-Liner"
fi
if [ "$OPEN" -ge 4 ] || { [ "$OPEN" -ge 2 ] && [ $((OPEN * 2)) -ge "$ITEMS" ]; }; then
  _emit 5 R6 "open-heavy → Kanban Lanes"
fi
[ "$ITEMS" -ge 8 ] && _emit 4 R7 "backlog-heavy → Burndown Ledger"
_emit 2 R8 "default → Traffic-Light Strip (gallery winner)"
