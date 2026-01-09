# Multi-Agent-OS Templates

This directory contains reusable templates for Claude Code configuration and integration.

## Contents

### statusline-command.sh

Enriched statusline for Claude Code with Multi-Agent-OS integration.

**Features:**
- Model name and version extraction
- Project basename display
- Git branch detection
- Worktree detection and display
- Multi-agent session state (from `.worktrees/sessions.json`)
- Cost tracking (USD)
- Context window usage with visual indicators (🟢🟡🟠🔴)
- Auto-compact threshold calculation

**Performance:**
- Target: < 100ms
- Measured: ~91ms (on macOS with jq/git)
- Dependencies: bash, jq, git

**Formats:**

1. **Wide** (>= 120 columns):
```
Opus 4.5 │ VKS_CEO │ ∠main │ 🔧eed7-hook │ ⏱active │ 💰$0.023 │ 🟢56% │ ⏳39% left
```

2. **Compact** (< 120 columns):
```
Opus | VKS_CEO/main | wt:eed7-hook | ● | $0.02 | 🟢56%↗39%
```

---

## Installation

### Automatic (via plugin sync)

If using multi-agent-os plugin, templates are synced automatically via `/multi-agent-os:sync`.

### Manual

```bash
# Copy template
cp statusline-command.sh ~/.claude/
chmod +x ~/.claude/statusline-command.sh

# Add to ~/.claude/settings.json:
{
  "statusline": {
    "command": "bash ~/.claude/statusline-command.sh"
  }
}

# Restart Claude Code
```

---

## Visual Indicators

### Context Usage Colors

| Usage % | Indicator | Meaning |
|---------|-----------|---------|
| 0-49%   | 🟢        | Comfortable - plenty of context |
| 50-69%  | 🟡        | Moderate - watch usage |
| 70-84%  | 🟠        | Caution - approaching threshold |
| 85%+    | 🔴        | Critical - auto-compact imminent |

### Session State Icons

| State    | Wide      | Compact | Description |
|----------|-----------|---------|-------------|
| active   | ⏱active   | ●       | Session running |
| paused   | ⏸paused   | ⏸       | Session paused |
| archived | 📦archived | 📦      | Session archived |

---

## Customization

### Context Thresholds

Edit lines 75-83 in `statusline-command.sh`:

```bash
if [ "$CONTEXT_USED_PCT" -ge 85 ]; then
  CONTEXT_INDICATOR="🔴"
elif [ "$CONTEXT_USED_PCT" -ge 70 ]; then
  CONTEXT_INDICATOR="🟠"
# ... adjust as needed
```

### Terminal Width Threshold

Edit line 136:

```bash
if [ "$TERM_WIDTH" -ge 120 ]; then
# Change 120 to preferred width
```

### Colors

ANSI codes used:
- `\033[32m` - Green
- `\033[33m` - Yellow
- `\033[35m` - Magenta
- `\033[36m` - Cyan
- `\033[90m` - Gray
- `\033[1m` - Bold

---

## Testing

```bash
# Test with sample data
echo '{"model":{"display_name":"Opus","id":"claude-opus-4-5-20251101"},"workspace":{"current_dir":"'$(pwd)'"}}' | bash statusline-command.sh

# Test context metrics
cat << 'TESTEOF' | bash statusline-command.sh
{
  "model": {"display_name": "Opus", "id": "claude-opus-4-5-20251101"},
  "workspace": {"current_dir": "/tmp"},
  "cost": {"total_cost_usd": 0.0234},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 170000, "output_tokens": 5000}
  }
}
TESTEOF
```

---

## Troubleshooting

### Statusline Not Showing

1. Check settings:
```bash
cat ~/.claude/settings.json | jq .statusline
```

2. Verify script exists:
```bash
ls -la ~/.claude/statusline-command.sh
```

3. Check jq is installed:
```bash
which jq || echo "Install jq: brew install jq"
```

### Session State Not Showing

Verify `.worktrees/sessions.json` exists with `active_sessions` array.

---

*Multi-Agent-OS Framework v1.0 | 2026-01-09*
