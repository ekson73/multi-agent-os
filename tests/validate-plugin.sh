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
