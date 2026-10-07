#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# test-delegation-authority-ssot.sh — governance consistency for agent delegation
#
# /** The delegation rules live in ONE place: skills/agentic-delegation/SKILL.md.
#  *  This test keeps the rest of the repo from drifting away from it:
#  *    1. the SSOT §4.1 states the authority-inheritance rule, the closed root
#  *       exception list, fail-closed handling and the never-delegable list;
#  *    2. the SSOT body has no back-reference to a host/personal layer;
#  *    3. no file states a delegation depth cap other than the SSOT's §8 value,
#  *       including Sentinel's config and docs;
#  *    4. the files that used to restate the rules now link the SSOT;
#  *    5. mutation fixtures: each known contradiction, injected into a copy,
#  *       must make checks 1-3 fail (proves the checks can see what they guard).
#  *  @usage  bash tests/governance/test-delegation-authority-ssot.sh [repo-root]
#  *  @exit   0 pass · 1 one or more checks failed
#  */
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
QUIET="${DAS_QUIET:-0}"           # 1 = fixture run: no per-check output
FAILS=0
ok()  { [ "$QUIET" = 1 ] || printf '  ✓ %s\n' "$1"; }
bad() { [ "$QUIET" = 1 ] || printf '  ✗ %s\n' "$1"; FAILS=$((FAILS + 1)); }

SSOT="$ROOT/skills/agentic-delegation/SKILL.md"
[ "$QUIET" = 1 ] || echo "delegation-authority SSOT consistency"
if [ ! -f "$SSOT" ]; then
    bad "SSOT missing: skills/agentic-delegation/SKILL.md"
    exit 1
fi

# ── 1. §4.1 normative content (checked inside §4.1 only) ─────────────────────
S41="$(sed -n '/^## 4\.1 /,/^## 5\./p' "$SSOT")"
if [ -z "$S41" ]; then
    bad "SSOT lacks a '## 4.1' section (authority inheritance)"
fi
for needle in 'depth_remaining' 'subset' 'never widens' 'fail-closed' \
              'no authorization grant' 'The list is closed' \
              '| E1 |' '| E2 |' '| E3 |' '| E4 |' \
              'HUMAN_DOMAIN' 'absolute guardrail' 'independent red-team' \
              'Final accountability' 'Audit judgment' 'Escalation choice' \
              'Memory judgment' 'World boundary' 'Enforcement today'; do
    printf '%s\n' "$S41" | grep -qiF -- "$needle" && ok "§4.1 states: $needle" || bad "§4.1 does not state: $needle"
done

# ── 2. layer purity (body only; Changelog history rows are left as written) ──
BODY="$(sed '/^## [0-9]*\.* *Changelog/,$d' "$SSOT")"
PURITY="host-local|auto-self-harness|~/\\.claude|operator-host|operator's own|when present at the host"
if printf '%s\n' "$BODY" | grep -nEi "$PURITY" >/dev/null; then
    bad "SSOT body references a host/personal layer:"
    [ "$QUIET" = 1 ] || printf '%s\n' "$BODY" | grep -nEi "$PURITY" | sed 's/^/      /'
else
    ok "SSOT has no back-reference to a personal layer"
fi

# ── 3. one depth cap ─────────────────────────────────────────────────────────
CAP="$(sed -nE 's/^- Max recursion depth: \*\*([0-9]+)\*\*.*/\1/p' "$SSOT" | head -1)"
if [ -z "$CAP" ]; then
    bad "SSOT §8 has no 'Max recursion depth: **N**' line"
else
    ok "SSOT depth cap = $CAP"
    # Agent delegation/recursion depth statements, several phrasings. Navigation
    # depth (--depth / --max-depth of a file or graph walk) is out of scope.
    RE='(delegation|recursion) depth[^0-9]{0,25}(≤|<=|>|hard-?cap(ped)?( at)?)[[:space:]]*[0-9]+'
    RE="$RE|max(imum)? (delegation )?depth[^0-9a-z]{0,6}[0-9]+"
    RE="$RE|depth[^.|]{0,40}allows[[:space:]]*(≤|<=)[[:space:]]*[0-9]+"
    hits="$(grep -rnoiE "$RE" "$ROOT/agents" "$ROOT/skills" "$ROOT/commands" "$ROOT/protocols" \
              "$ROOT/sentinel" "$ROOT/statusmap" --include='*.md' 2>/dev/null || true)"
    drift=0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        n="$(printf '%s' "$line" | grep -oE '[0-9]+$')"
        if [ "$n" != "$CAP" ]; then
            bad "depth cap $n ≠ SSOT $CAP: ${line#"$ROOT"/}"
            drift=1
        fi
    done <<EOF
$hits
EOF
    [ "$drift" -eq 0 ] && ok "no Markdown file states a delegation depth cap other than $CAP"

    SCFG="$ROOT/sentinel/config.json"
    if [ -f "$SCFG" ]; then
        sval="$(sed -nE 's/.*"max_delegation_depth":[[:space:]]*([0-9]+).*/\1/p' "$SCFG" | head -1)"
        [ "$sval" = "$CAP" ] && ok "sentinel/config.json max_delegation_depth = $CAP" \
            || bad "sentinel/config.json max_delegation_depth = ${sval:-?} ≠ SSOT $CAP"
    fi
    for f in sentinel/detection_rules.md sentinel/README.md \
             statusmap/templates/DELEGATION_PRE.md statusmap/templates/statusmap_templates.md; do
        [ -f "$ROOT/$f" ] || continue
        other="$(grep -noE '(max_depth=|max_delegation_depth`?:? *\|? *|delegation_depth > |default: )[0-9]+|usually [0-9]+' "$ROOT/$f" | grep -vE "[^0-9]$CAP\$" || true)"
        if [ -n "$other" ]; then
            bad "$f states a depth value other than $CAP: $(printf '%s' "$other" | tr '\n' ' ')"
        else
            ok "$f agrees with depth cap $CAP"
        fi
    done
fi

# ── 4. former restaters now link the SSOT ────────────────────────────────────
for f in agents/orchestrator.md commands/delegate.md protocols/agent-delegation.md \
         agents/COWORK-AUTONOMY-POLICY.md skills/delegate-governance/SKILL.md \
         skills/auto-pilot/SKILL.md commands/auto-pilot.md skills/quiesce/SKILL.md \
         skills/council-gate/SKILL.md agents/persona-pipeline.md \
         agents/perspective-trio.md agents/cascade-resolver.md agents/README.md; do
    if [ ! -f "$ROOT/$f" ]; then
        bad "expected file missing: $f"
    elif grep -q 'agentic-delegation' "$ROOT/$f"; then
        ok "$f links agentic-delegation"
    else
        bad "$f does not link skills/agentic-delegation"
    fi
done

# ── 5. mutation fixtures (only on the real tree, never recursively) ──────────
if [ "$QUIET" != 1 ]; then
    FIX="$(mktemp -d)"
    trap 'rm -rf "$FIX"' EXIT
    mutate() {  # mutate <label> <file> <sed-expression|append:TEXT>
        local label="$1" rel="$2" expr="$3" t="$FIX/t"
        rm -rf "$t"; mkdir -p "$t"
        (cd "$ROOT" && tar -cf - agents skills commands protocols sentinel statusmap) | tar -xf - -C "$t"
        case "$expr" in
            append:*) printf '\n%s\n' "${expr#append:}" >> "$t/$rel" ;;
            *) sed -i.bak "$expr" "$t/$rel" && rm -f "$t/$rel.bak" ;;
        esac
        if DAS_QUIET=1 bash "$SELF" "$t" >/dev/null 2>&1; then
            bad "fixture not detected: $label"
        else
            ok "fixture detected: $label"
        fi
    }
    # control: an unmodified copy must pass, else the fixtures prove nothing
    rm -rf "$FIX/c"; mkdir -p "$FIX/c"
    (cd "$ROOT" && tar -cf - agents skills commands protocols sentinel statusmap) | tar -xf - -C "$FIX/c"
    if DAS_QUIET=1 bash "$SELF" "$FIX/c" >/dev/null 2>&1; then
        ok "fixture control: unmodified copy passes"
    else
        bad "fixture control failed: an unmodified copy does not pass"
    fi
    mutate "depth > 3 in orchestrator"       agents/orchestrator.md 'append:- Delegation depth > 3? → STOP'
    mutate "'max depth 3' in a diagram"      agents/README.md 'append:└── Sub-Sub-Agent (max depth 3)'
    mutate "'manual mode allows ≤ 3'"        skills/auto-pilot/SKILL.md "append:depth for manual mode allows ≤ 3"
    mutate "Sentinel config cap 3"           sentinel/config.json 's/"max_delegation_depth": [0-9]*/"max_delegation_depth": 3/'
    mutate "SSOT loses 'never widens'"       skills/agentic-delegation/SKILL.md 's/never widens/may widen/g'
    mutate "SSOT loses fail-closed"          skills/agentic-delegation/SKILL.md 's/fail-closed/best-effort/g'
    mutate "SSOT exception list reopened"    skills/agentic-delegation/SKILL.md 's/The list is closed\./Other exceptions may apply./'
    mutate "personal-layer back-reference"   skills/agentic-delegation/SKILL.md "s/^> \*\*Scope\*\*:/> See the operator-host framework. **Scope**:/"
fi

[ "$QUIET" = 1 ] || echo ""
if [ "$FAILS" -eq 0 ]; then
    [ "$QUIET" = 1 ] || echo "PASS"
    exit 0
fi
[ "$QUIET" = 1 ] || echo "FAIL ($FAILS)"
exit 1
