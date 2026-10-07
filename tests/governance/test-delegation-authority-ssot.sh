#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# test-delegation-authority-ssot.sh — governance consistency for agent delegation
#
# /** The delegation rules live in ONE place: skills/agentic-delegation/SKILL.md.
#  *  This test keeps the rest of the repo from drifting away from it:
#  *    1. the SSOT states the authority-inheritance rule (§4.1) and the
#  *       non-delegable list;
#  *    2. the SSOT has no back-reference to a host-local/personal layer;
#  *    3. no other file states a delegation/recursion depth cap different from
#  *       the SSOT's §8 value (they should link, not restate a different number);
#  *    4. the files that used to restate the rules now link the SSOT.
#  *  @usage  bash tests/governance/test-delegation-authority-ssot.sh [repo-root]
#  *  @exit   0 pass · 1 one or more checks failed
#  */
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SSOT="$ROOT/skills/agentic-delegation/SKILL.md"
FAILS=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; FAILS=$((FAILS + 1)); }

echo "delegation-authority SSOT consistency"

if [ ! -f "$SSOT" ]; then
    bad "SSOT missing: skills/agentic-delegation/SKILL.md"
    exit 1
fi

# ── 1. inheritance rule + non-delegable list ─────────────────────────────────
grep -qE '^## 4\.1 ' "$SSOT" && ok "SSOT has §4.1" || bad "SSOT lacks a '## 4.1' section (authority inheritance)"
for needle in 'depth_remaining' 'subset' 'never widens'; do
    grep -qi -- "$needle" "$SSOT" && ok "SSOT states '$needle'" || bad "SSOT does not state '$needle'"
done
# the non-delegable items, each must appear in the SSOT
for needle in 'HUMAN_DOMAIN' 'absolute guardrail' 'independent red-team' \
              'final accountability' 'audit judgment' 'escalation choice' \
              'memory judgment' 'world boundary'; do
    grep -qi -- "$needle" "$SSOT" && ok "non-delegable listed: $needle" || bad "non-delegable not listed: $needle"
done

# ── 2. layer purity ──────────────────────────────────────────────────────────
# History rows in the Changelog are left as written; the check covers the body.
BODY="$(sed '/^## [0-9]*\.* *Changelog/,$d' "$SSOT")"
if printf '%s\n' "$BODY" | grep -nEi 'host-local|auto-self-harness|~/\.claude' >/dev/null; then
    bad "SSOT references a host-local/personal layer:"
    printf '%s\n' "$BODY" | grep -nEi 'host-local|auto-self-harness|~/\.claude' | sed 's/^/      /'
else
    ok "SSOT has no back-reference to a personal layer"
fi

# ── 3. one depth cap ─────────────────────────────────────────────────────────
CAP="$(sed -nE 's/^- Max recursion depth: \*\*([0-9]+)\*\*.*/\1/p' "$SSOT" | head -1)"
if [ -z "$CAP" ]; then
    bad "SSOT §8 has no 'Max recursion depth: **N**' line"
else
    ok "SSOT depth cap = $CAP"
    # Scope: statements about agent delegation/recursion depth with a comparison.
    # Navigation depth (--depth, --max-depth of a file walk) is not delegation.
    RE='(delegation|recursion) depth[^0-9]{0,25}(≤|<=|>|hard-?cap(ped)?( at)?)[[:space:]]*[0-9]+'
    hits="$(grep -rnoiE "$RE" "$ROOT/agents" "$ROOT/skills" "$ROOT/commands" "$ROOT/protocols" \
              --include='*.md' 2>/dev/null || true)"
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
    [ "$drift" -eq 0 ] && ok "no file states a delegation depth cap other than $CAP"
fi

# ── 4. former restaters now link the SSOT ────────────────────────────────────
for f in agents/orchestrator.md commands/delegate.md protocols/agent-delegation.md \
         agents/COWORK-AUTONOMY-POLICY.md skills/delegate-governance/SKILL.md \
         skills/auto-pilot/SKILL.md commands/auto-pilot.md skills/quiesce/SKILL.md \
         skills/council-gate/SKILL.md agents/persona-pipeline.md \
         agents/perspective-trio.md agents/cascade-resolver.md; do
    if [ ! -f "$ROOT/$f" ]; then
        bad "expected file missing: $f"
    elif grep -q 'agentic-delegation' "$ROOT/$f"; then
        ok "$f links agentic-delegation"
    else
        bad "$f does not link skills/agentic-delegation"
    fi
done

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo "PASS"
    exit 0
fi
echo "FAIL ($FAILS)"
exit 1
