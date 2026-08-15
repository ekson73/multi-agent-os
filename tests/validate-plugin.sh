#!/usr/bin/env bash
# /**
#  * Plugin Structure Validation Script
#  * @context Validates multi-agent-os plugin structure for Claude Code compatibility
#  * @reason Ensure all required files exist and have correct format
#  * @impact Prevents plugin installation failures
#  */

set -euo pipefail

PLUGIN_ROOT="${1:-$(pwd)}"
ERRORS=0
WARNINGS=0

echo "========================================"
echo "  Multi-Agent OS Plugin Validation"
echo "========================================"
echo ""
echo "Plugin Root: $PLUGIN_ROOT"
echo ""

# Helper functions
pass() {
    echo "  ✓ $1"
}

fail() {
    echo "  ✗ $1"
    ((ERRORS++)) || true
}

warn() {
    echo "  ⚠ $1"
    ((WARNINGS++)) || true
}

# Check required directories
echo "Checking required directories..."

for dir in ".claude-plugin" "hooks" "plugin-scripts" "commands" "agents" "skills"; do
    if [ -d "$PLUGIN_ROOT/$dir" ]; then
        pass "$dir/ exists"
    else
        fail "$dir/ missing"
    fi
done
echo ""

# Check plugin.json
echo "Checking plugin.json..."

if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    pass "plugin.json exists"

    # Validate JSON
    if python3 -c "import json; json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))" 2>/dev/null; then
        pass "plugin.json is valid JSON"
    else
        fail "plugin.json is invalid JSON"
    fi

    # Check required fields
    if grep -q '"name"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
        pass "plugin.json has 'name' field"
    else
        fail "plugin.json missing 'name' field"
    fi

    if grep -q '"hooks"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
        pass "plugin.json has 'hooks' field"
    else
        fail "plugin.json missing 'hooks' field (required for hooks)"
    fi
else
    fail "plugin.json missing"
fi
echo ""

# Check hooks.json
echo "Checking hooks.json..."

if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
    pass "hooks/hooks.json exists"

    # Validate JSON
    if python3 -c "import json; json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))" 2>/dev/null; then
        pass "hooks.json is valid JSON"
    else
        fail "hooks.json is invalid JSON"
    fi
else
    fail "hooks/hooks.json missing"
fi
echo ""

# Check hook scripts
echo "Checking hook scripts..."

for script in "session-start.sh" "pre-delegate.sh" "post-delegate.sh" "session-end.sh"; do
    if [ -f "$PLUGIN_ROOT/plugin-scripts/$script" ]; then
        pass "$script exists"
        if [ -x "$PLUGIN_ROOT/plugin-scripts/$script" ]; then
            pass "$script is executable"
        else
            fail "$script is not executable"
        fi
    else
        warn "$script missing (optional but recommended)"
    fi
done
echo ""

# Check skills (subdirectory format)
echo "Checking skills (subdirectory format)..."

SKILL_COUNT=0
for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        if [ -f "${skill_dir}SKILL.md" ]; then
            pass "skills/$skill_name/SKILL.md exists"
            ((SKILL_COUNT++)) || true
        else
            fail "skills/$skill_name/ missing SKILL.md"
        fi
    fi
done

if [ $SKILL_COUNT -eq 0 ]; then
    warn "No skills found in subdirectory format"
else
    pass "$SKILL_COUNT skills found"
fi
echo ""

# Check commands
echo "Checking commands..."

COMMAND_COUNT=0
for cmd in "$PLUGIN_ROOT/commands"/*.md; do
    if [ -f "$cmd" ]; then
        cmd_name=$(basename "$cmd")
        if [ "$cmd_name" != "README.md" ]; then
            # Check for frontmatter
            if head -1 "$cmd" | grep -q "^---"; then
                pass "$cmd_name has frontmatter"
            else
                warn "$cmd_name missing frontmatter"
            fi
            ((COMMAND_COUNT++)) || true
        fi
    fi
done

if [ $COMMAND_COUNT -eq 0 ]; then
    warn "No commands found"
else
    pass "$COMMAND_COUNT commands found"
fi
echo ""

# Check agents
echo "Checking agents..."

AGENT_COUNT=0
for agent in "$PLUGIN_ROOT/agents"/*.md; do
    if [ -f "$agent" ]; then
        agent_name=$(basename "$agent")
        if [ "$agent_name" != "README.md" ]; then
            # Check for frontmatter
            if head -1 "$agent" | grep -q "^---"; then
                pass "$agent_name has frontmatter"
            else
                warn "$agent_name missing frontmatter"
            fi
            ((AGENT_COUNT++)) || true
        fi
    fi
done

if [ $AGENT_COUNT -eq 0 ]; then
    warn "No agents found"
else
    pass "$AGENT_COUNT agents found"
fi
echo ""

# Delegation Framework (GaaS/GaaC) — protocols + skill + CLI
echo "Validating delegation framework..."

DELEGATION_DIR="$PLUGIN_ROOT/protocols/delegation"
for f in provider-matrix.md delegation-init-prompt.md delegation-dna-prompt.md delegation-finalize-prompt.md; do
    if [ -f "$DELEGATION_DIR/$f" ]; then
        pass "protocols/delegation/$f exists"
    else
        fail "protocols/delegation/$f missing"
    fi
done

# Token budget check: word-count × 1.3 ≤ 1500 per prompt
for f in delegation-init-prompt.md delegation-dna-prompt.md delegation-finalize-prompt.md; do
    if [ -f "$DELEGATION_DIR/$f" ]; then
        WC=$(wc -w < "$DELEGATION_DIR/$f" | tr -d ' ')
        EST=$(( WC * 13 / 10 ))
        if [ "$EST" -le 1500 ]; then
            pass "$f token budget OK (${WC}w ~${EST}tok ≤ 1500)"
        else
            fail "$f exceeds token budget (${WC}w ~${EST}tok > 1500)"
        fi
    fi
done

# CLI exists + executable + correct exit codes
DELEGATE_CLI="$PLUGIN_ROOT/plugin-scripts/gaac/delegate.sh"
if [ -x "$DELEGATE_CLI" ]; then
    pass "plugin-scripts/gaac/delegate.sh exists and is executable"

    for phase in init dna finalize; do
        if OUT=$(bash "$DELEGATE_CLI" "$phase" 2>/dev/null) && [ -n "$OUT" ]; then
            pass "delegate.sh $phase exits 0 with non-empty stdout"
        else
            fail "delegate.sh $phase failed or empty"
        fi
    done

    # Unknown phase must exit != 0
    if bash "$DELEGATE_CLI" bogus >/dev/null 2>&1; then
        fail "delegate.sh bogus should exit non-zero"
    else
        pass "delegate.sh unknown phase exits non-zero"
    fi

    # Simulated cross-provider contexts (env-isolated so ambient $TICKET can't skew)
    H1=$(env -u TICKET bash "$DELEGATE_CLI" init --ticket=VKS-1706 --provider=bitbucket 2>/dev/null)
    if echo "$H1" | grep -q "^TICKET_PROVIDER=jira$" && echo "$H1" | grep -q "^VCS_PROVIDER=bitbucket$"; then
        pass "delegate.sh detects jira+bitbucket context"
    else
        fail "delegate.sh should detect jira+bitbucket"
    fi

    H2=$(env -u TICKET bash "$DELEGATE_CLI" init --ticket=VKO-88 --provider=github 2>/dev/null)
    if echo "$H2" | grep -q "^TICKET_PROVIDER=linear$" && echo "$H2" | grep -q "^VCS_PROVIDER=github$"; then
        pass "delegate.sh detects linear+github context"
    else
        fail "delegate.sh should detect linear+github"
    fi

    H3=$(env -u TICKET bash "$DELEGATE_CLI" init --provider=none 2>/dev/null)
    if echo "$H3" | grep -q "^TICKET_PROVIDER=none$" && echo "$H3" | grep -q "^VCS_PROVIDER=none$"; then
        pass "delegate.sh handles no-ticket/no-remote fallback"
    else
        fail "delegate.sh should handle no-ticket fallback"
    fi

    # Invalid --provider must be rejected (exit 2)
    if env -u TICKET bash "$DELEGATE_CLI" init --provider=invalidprov >/dev/null 2>&1; then
        fail "delegate.sh should reject unknown --provider value"
    else
        pass "delegate.sh rejects unknown --provider value"
    fi
else
    fail "plugin-scripts/gaac/delegate.sh missing or not executable"
fi

# ─── Frontmatter must actually PARSE as YAML ─────────────────────────────────
# Root-cause fix (2026-08-14): every frontmatter check above greps for a LINE
# (`^name: x$`) and therefore reports PASS on a file whose YAML the loader
# rejects. A skill shipped with an unquoted plain scalar containing ': ' —
# structurally unloadable — while this script printed "✓ PASSED". A grep answers
# "does the text contain?", never "does the parser accept?"; the second question
# is the one that decides whether the artifact loads at all.
# Capability-detected: PyYAML absent → WARN, never a red build for a missing dep.
echo "Validating frontmatter parses as YAML..."
if python3 -c "import yaml" 2>/dev/null; then
    # Initialize IN THIS SCOPE before the capture below. `YAML_RC` is a generic-enough
    # name that an outer wrapper may already export it; without this reset a SUCCESSFUL
    # python run never executes `|| YAML_RC=$?`, so the inherited value survives and the
    # gate reports a crash that never happened. `${VAR:-0}` does NOT cover this: it
    # substitutes only when unset/null, not when set to garbage. Never read a variable
    # you did not initialize in your own scope.
    YAML_RC=0
    YAML_BAD=$(python3 - "$PLUGIN_ROOT" <<'PYEOF'
import glob, io, os, sys, yaml
root = sys.argv[1]
bad = []
seen = set()
# `**` + recursive=True: Python's `*` does NOT cross `/`, unlike git's pathspec of the
# same shape. With the non-recursive patterns this gate never saw agents/consultants/*.md
# nor commands/*/*.md — 30 artifacts that were reported as covered. See issue #327.
# NOTE both halves are load-bearing: `**` without recursive=True behaves as plain `*`.
for pat in ("skills/**/SKILL.md", "agents/**/*.md", "commands/**/*.md"):
    for p in sorted(glob.glob(os.path.join(root, pat), recursive=True)):
        # REACHED — must precede every `continue` below (see note under the except).
        # `.replace(os.sep, "/")`: on Windows os.path.relpath returns `agents\foo.md`
        # while `git ls-files` ALWAYS emits `/`, so without this every artifact lands in
        # `tracked - seen` and the assertion reports a false total reach gap on every run.
        # os.sep (not a literal "\\"): on POSIX os.sep == "/" so this is a no-op, which
        # matters because `\` is a legal filename character there and a literal replace
        # would corrupt it.
        seen.add(os.path.relpath(p, root).replace(os.sep, "/"))
                                             # below, or `seen` records "parsed" while the
                                             # assertion claims "reached" (they differ for
                                             # files with no frontmatter, which are skipped
                                             # on purpose and are NOT a reach gap).
        if os.path.basename(p) == "README.md":
            continue                      # docs, not artifacts (same rule as above)
        try:
            t = io.open(p, encoding="utf-8").read()
            if not t.startswith("---\n"):
                continue                  # 'missing frontmatter' is already warned above
            yaml.safe_load(t.split("---\n", 2)[1])
        except yaml.YAMLError as e:
            bad.append(f"{os.path.relpath(p, root)} :: {str(e).splitlines()[0]}")
        except Exception as e:
            bad.append(f"{os.path.relpath(p, root)} :: {type(e).__name__}: {e}")

# REACH ASSERTION — the gate must not silently under-reach again (issue #327).
# git's pathspec `*` crosses `/`, so these patterns are the ground truth for what
# SHOULD have been parsed. Degrade-safe: no git / not a repo -> skip, never fail,
# because this validator also runs from an installed plugin dir with no .git.
# `.git` absent is the ONE legitimate skip (installed plugin dir) — silent by design.
# Anything else is reported: a control that disables itself on any error is not a control,
# it is an invisible bypass. Narrow excepts only, so a real bug in this block propagates
# and is caught by the rc check in the shell above rather than swallowed here.
if os.path.exists(os.path.join(root, ".git")):
    import subprocess
    try:
        tracked = set()
        for pat in ("skills/*/SKILL.md", "agents/*.md", "commands/*.md"):
            out = subprocess.run(["git", "-C", root, "ls-files", pat],
                                 capture_output=True, text=True, timeout=10)
            if out.returncode != 0:
                raise OSError(f"git ls-files rc={out.returncode}")
            # splitlines(): git ls-files is newline-delimited. `.split()` would corrupt any
            # tracked path containing spaces (zero today — probed — but the gate's whole
            # purpose is to not silently under-report again, per #327).
            tracked.update(f.replace("\\", "/") for f in out.stdout.splitlines()
                           if os.path.basename(f) != "README.md")
        missed = sorted(tracked - seen)
        if missed:
            bad.append(f"REACH GAP :: {len(missed)} tracked artifact(s) the glob never parsed, "
                       f"e.g. {missed[0]} — the gate under-reaches (see #327)")
    except (OSError, subprocess.SubprocessError) as e:
        # .git IS here, so git failing is an anomaly, not the expected no-repo case.
        bad.append(f"REACH ASSERTION DID NOT RUN :: {type(e).__name__}: {e} — "
                   f"the under-reach guard was skipped; treat coverage as UNVERIFIED")

print("\n".join(bad))
PYEOF
) || YAML_RC=$?
    # `|| YAML_RC=$?` on the assignment above is load-bearing: this script runs under
    # `set -euo pipefail` (line 9), so a bare `X=$(python3 ...)` that exits non-zero
    # ABORTS the whole script right there — the run does fail (safe), but with no
    # message saying why, and any check written after it is unreachable. The `||`
    # keeps the failure local so it can be reported instead of just ending the script.
    # Emptiness alone is NOT the test: a python crash exits non-zero with EMPTY stdout,
    # which reads as "nothing bad found". Per script-safety §6 the authority is the
    # captured exit code.
    if [ "$YAML_RC" -ne 0 ]; then
        fail "frontmatter YAML check crashed (python rc=$YAML_RC) — result is UNKNOWN, not clean"
    elif [ -z "$YAML_BAD" ]; then
        pass "all artifact frontmatter parses as YAML"
    else
        while IFS= read -r line; do [ -n "$line" ] && fail "unparseable frontmatter: $line"; done <<< "$YAML_BAD"
    fi
else
    warn "PyYAML absent — frontmatter parse check SKIPPED (grep-only checks cannot catch a broken loader)"
fi
echo ""

# Skill frontmatter
SKILL_FILE="$PLUGIN_ROOT/skills/delegate-governance/SKILL.md"
if [ -f "$SKILL_FILE" ] && grep -q "^name: delegate-governance$" "$SKILL_FILE"; then
    pass "skills/delegate-governance/SKILL.md has correct frontmatter"
else
    fail "skills/delegate-governance/SKILL.md missing or frontmatter wrong"
fi
echo ""

# auto-pilot skill + command (v0.1.0)
echo "Validating auto-pilot..."

AP_SKILL="$PLUGIN_ROOT/skills/auto-pilot/SKILL.md"
if [ -f "$AP_SKILL" ]; then
    pass "skills/auto-pilot/SKILL.md exists"
    if grep -q "^name: auto-pilot$" "$AP_SKILL"; then
        pass "skills/auto-pilot/SKILL.md has correct frontmatter"
    else
        fail "skills/auto-pilot/SKILL.md missing 'name: auto-pilot' frontmatter"
    fi
    AP_SIZE=$(wc -c <"$AP_SKILL" | tr -d ' ')
    if [ "$AP_SIZE" -lt 12288 ]; then
        pass "skills/auto-pilot/SKILL.md size OK (${AP_SIZE}B < 12288B)"
    else
        fail "skills/auto-pilot/SKILL.md exceeds 12288B ceiling (${AP_SIZE}B)"
    fi
else
    fail "skills/auto-pilot/SKILL.md missing"
fi

AP_CMD="$PLUGIN_ROOT/commands/auto-pilot.md"
if [ -f "$AP_CMD" ]; then
    pass "commands/auto-pilot.md exists"
    if grep -q "^name: auto-pilot$" "$AP_CMD"; then
        pass "commands/auto-pilot.md has correct frontmatter"
    else
        fail "commands/auto-pilot.md missing 'name: auto-pilot' frontmatter"
    fi
else
    fail "commands/auto-pilot.md missing"
fi

# Reciprocity link from delegate-governance back to auto-pilot
if [ -f "$SKILL_FILE" ] && grep -q "skills/auto-pilot/SKILL.md" "$SKILL_FILE"; then
    pass "delegate-governance Related section links auto-pilot"
else
    fail "delegate-governance missing reciprocal link"
fi
echo ""

# signoff + continuation-broadcast (postflight P3.6 — ADR-010)
echo "Validating signoff + continuation-broadcast..."

BC_SCRIPT="$PLUGIN_ROOT/bin/continuation-broadcast.sh"
if [ -x "$BC_SCRIPT" ]; then
    pass "bin/continuation-broadcast.sh exists and is executable"
    if bash "$BC_SCRIPT" --help >/dev/null 2>&1; then
        pass "continuation-broadcast.sh --help exits 0"
    else
        fail "continuation-broadcast.sh --help should exit 0"
    fi
    # dry-run is the DEFAULT: a --scope all --file target is NOT mutated without --apply
    BC_TMP="$(mktemp)"; BC_JOBS="$(mktemp -d)"; printf 'x\n' > "$BC_TMP"
    CLAUDE_JOBS_DIR="$BC_JOBS" bash "$BC_SCRIPT" --ticket VKS-1 --seed s.json --scope all --file "$BC_TMP" >/dev/null 2>&1
    if [ "$(cat "$BC_TMP")" = "x" ]; then
        pass "continuation-broadcast dry-run default (no --apply ⇒ no mutation)"
    else
        fail "continuation-broadcast dry-run mutated a file without --apply"
    fi
    rm -f "$BC_TMP"; rm -rf "$BC_JOBS"
    # kill-switch ⇒ noop
    if MAOS_BROADCAST=0 bash "$BC_SCRIPT" --ticket VKS-1 2>/dev/null | grep -q '"status":"noop"'; then
        pass "continuation-broadcast MAOS_BROADCAST=0 kill-switch ⇒ noop"
    else
        fail "continuation-broadcast kill-switch should noop"
    fi
else
    fail "bin/continuation-broadcast.sh missing or not executable"
fi

BC_TESTS="$PLUGIN_ROOT/bin/tests/continuation-broadcast.test.sh"
if [ -f "$BC_TESTS" ]; then
    if bash "$BC_TESTS" >/dev/null 2>&1; then
        pass "bin/tests/continuation-broadcast.test.sh passes"
    else
        fail "bin/tests/continuation-broadcast.test.sh FAILED (run 'bash bin/tests/continuation-broadcast.test.sh')"
    fi
else
    fail "bin/tests/continuation-broadcast.test.sh missing"
fi

# research-dossier: the two f=0 gates, proven in BOTH directions (valid passes,
# each negative fixture fails for its OWN reason). Skips cleanly without node.
RD_TESTS="$PLUGIN_ROOT/bin/tests/research-dossier.test.sh"
if [ -f "$RD_TESTS" ]; then
    if bash "$RD_TESTS" >/dev/null 2>&1; then
        pass "bin/tests/research-dossier.test.sh passes"
    else
        fail "bin/tests/research-dossier.test.sh FAILED (run 'bash bin/tests/research-dossier.test.sh')"
    fi
else
    fail "bin/tests/research-dossier.test.sh missing"
fi

# signoff skill + command frontmatter
if [ -f "$PLUGIN_ROOT/skills/signoff/SKILL.md" ] && grep -q "^name: signoff$" "$PLUGIN_ROOT/skills/signoff/SKILL.md"; then
    pass "skills/signoff/SKILL.md has correct frontmatter"
else
    fail "skills/signoff/SKILL.md missing or frontmatter wrong"
fi
if [ -f "$PLUGIN_ROOT/commands/signoff.md" ] && grep -q "^name: signoff$" "$PLUGIN_ROOT/commands/signoff.md"; then
    pass "commands/signoff.md has correct frontmatter"
else
    fail "commands/signoff.md missing or frontmatter wrong"
fi

# supporting SSOT docs
for d in skills/postflight/references/continuation-broadcast-protocol.md \
         skills/postflight/references/close-out-hunt-checklist.md \
         docs/adrs/ADR-010-continuation-broadcast.md; do
    if [ -f "$PLUGIN_ROOT/$d" ]; then pass "$d exists"; else fail "$d missing"; fi
done
echo ""

# MAOS-Tips corpus (ADR-008) — integrity + anti-orphan gate
echo "Validating MAOS-Tips..."

TIPS_VALIDATOR="$PLUGIN_ROOT/tips/validate-tips.sh"
TIPS_HOOK="$PLUGIN_ROOT/plugin-scripts/session-tip.sh"
if [ -f "$TIPS_VALIDATOR" ]; then
    if [ -x "$TIPS_HOOK" ]; then
        pass "plugin-scripts/session-tip.sh is executable"
    else
        fail "plugin-scripts/session-tip.sh is not executable"
    fi
    if bash "$TIPS_VALIDATOR" "$PLUGIN_ROOT" >/dev/null 2>&1; then
        pass "tips/validate-tips.sh passes (zero orphan tips)"
    else
        fail "tips/validate-tips.sh FAILED (run 'bash tips/validate-tips.sh' for details)"
    fi
else
    warn "tips/validate-tips.sh missing (MAOS-Tips not installed)"
fi
echo ""

# OODA operator-profile: portable context must not become an authority bypass.
OODA_PROFILE_TESTS="$PLUGIN_ROOT/skills/ooda-loop/tests/operator-profile-contract.test.mjs"
if [ -f "$OODA_PROFILE_TESTS" ]; then
    if node --test "$OODA_PROFILE_TESTS" >/dev/null 2>&1; then
        pass "skills/ooda-loop/tests/operator-profile-contract.test.mjs passes"
    else
        fail "skills/ooda-loop/tests/operator-profile-contract.test.mjs FAILED (run 'node --test skills/ooda-loop/tests/operator-profile-contract.test.mjs')"
    fi
else
    fail "skills/ooda-loop/tests/operator-profile-contract.test.mjs missing"
fi
echo ""

# Agent Skills frontmatter (skills.sh / multi-harness portable path)
echo "Checking Agent Skills frontmatter..."
if [ -x "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh" ] || [ -f "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh" ]; then
    if bash "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh"; then
        pass "scripts/validate-skill-frontmatter.sh passes"
    else
        fail "scripts/validate-skill-frontmatter.sh FAILED (SKILL.md needs name+description YAML frontmatter)"
    fi
else
    fail "scripts/validate-skill-frontmatter.sh missing"
fi
echo ""

# Summary
echo "========================================"
echo "  Validation Summary"
echo "========================================"
echo ""
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "  Status: ✓ PASSED"
    echo ""
    echo "  Plugin is ready for use!"
    exit 0
else
    echo "  Status: ✗ FAILED"
    echo ""
    echo "  Please fix the errors above before using the plugin."
    exit 1
fi
