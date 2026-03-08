# Session Identifiers - Unified Reference

> Documento consolidado harmonizando pesquisa de identificadores de sessao Claude Code e Multi-Agent-OS (MAOS) para integracao na status bar.

**Data**: 2026-01-09
**Autor**: Claude-Consolidator-e00a-001
**Versao**: 2.1 (Unified)
**Fontes**: session-identifiers-research.md (v1.0), ADR-001-session-identity.md (v1.0)

---

## Sumario

1. [Executive Summary](#executive-summary)
2. [Identifier Inventory (Unified)](#identifier-inventory-unified)
3. [Correlation Mechanism](#correlation-mechanism)
4. [Context Window Metrics](#context-window-metrics)
5. [Status Bar Templates](#status-bar-templates)
6. [Usage Scenarios](#usage-scenarios)
7. [Schema Proposal v2.1](#schema-proposal-v21)
8. [Implementation Recommendations](#implementation-recommendations)
9. [Corrections & Clarifications](#corrections--clarifications)

---

## Executive Summary

### Consensus Points (High Confidence)

| Point | Agreed By | Confidence |
|-------|-----------|------------|
| Git branch-based identity (Scenario 5) is optimal | ADR-001 (3 agents), research.md | HIGH |
| 4-char hex short ID as correlation key | Both sources | HIGH |
| Worktree isolation is mandatory for multi-agent | Both sources | HIGH |
| Session registry in \`.worktrees/sessions.json\` | Both sources | HIGH |
| Heartbeat mechanism for stale detection | Both sources | HIGH |

### Areas Harmonized

| Topic | Source 1 Position | Source 2 Position | Unified Resolution |
|-------|-------------------|-------------------|-------------------|
| Short ID extraction | Last 4 chars of Claude session UUID | Last 4 chars of MAOS session ID | **Both valid** - MAOS ID already ends in 4-hex; Claude UUID can be truncated |
| Branch naming | \`{shortId}-{feature}\` | \`{tipo}/{feature}-{shortId}\` | **Flexible** - Support both patterns |
| Context threshold | 95% for auto-compact | Not addressed | **Adopted** from research.md |
| Parent-child sessions | Implicit | Explicit schema | **Adopted** explicit schema from ADR-001 |

### Gaps Filled by This Document

1. Multiple status bar template variants for different use cases
2. Scenario-based configuration recommendations
3. Unified schema v2.1 combining both sources
4. Implementation priority matrix

---

## Identifier Inventory (Unified)

### Layer 1: Claude Code Native Identifiers

| Identifier | Format | Source | Example | Mutability |
|------------|--------|--------|---------|------------|
| \`session_id\` | UUID v4 (36 chars) | \`.session_id\` | \`75a91227-c977-4c75-8921-ba01e070dd21\` | Immutable |
| \`session_name\` | String (~50 chars) | \`/rename\` command | \`auth-refactor\` | Mutable |
| \`transcript_path\` | File path | \`.transcript_path\` | \`~/.claude/projects/.../abc.jsonl\` | Immutable |
| \`model.id\` | String | \`.model.id\` | \`claude-opus-4-5-20251101\` | Per-session |
| \`model.display_name\` | String | \`.model.display_name\` | \`Opus\` | Per-session |
| \`cost.total_cost_usd\` | Float | \`.cost.total_cost_usd\` | \`0.0234\` | Accumulative |
| \`cost.total_duration_ms\` | Integer | \`.cost.total_duration_ms\` | \`45000\` | Accumulative |
| \`version\` | String | \`.version\` | \`1.0.80\` | Per-session |
| \`project_dir\` | Absolute path | \`.workspace.project_dir\` | \`/Users/.../VKS_CEO\` | Per-session |
| \`current_dir\` | Absolute path | \`.workspace.current_dir\` | \`/Users/.../VKS_CEO\` | Dynamic |

### Layer 2: Context Window Metrics

| Identifier | Format | Source | Example | Notes |
|------------|--------|--------|---------|-------|
| \`context_window_size\` | Integer | \`.context_window.context_window_size\` | \`200000\` | Model max |
| \`input_tokens\` | Integer | \`.context_window.current_usage.input_tokens\` | \`112000\` | Current used |
| \`output_tokens\` | Integer | \`.context_window.current_usage.output_tokens\` | \`4521\` | Responses |
| \`cache_creation_tokens\` | Integer | \`.context_window.current_usage.cache_creation_input_tokens\` | \`25000\` | Cache writes |
| \`cache_read_tokens\` | Integer | \`.context_window.current_usage.cache_read_input_tokens\` | \`50000\` | Cache hits |
| **Calculated:** |
| \`context_used_pct\` | Float | Calculated | \`56%\` | \`(input / max) * 100\` |
| \`context_left_pct\` | Float | Calculated | \`44%\` | \`100 - used_pct\` |
| \`until_compact_pct\` | Float | Calculated | \`39%\` | \`95 - used_pct\` |

### Layer 3: Multi-Agent-OS (MAOS) Identifiers

| Identifier | Format | Source | Example | Scope |
|------------|--------|--------|---------|-------|
| \`maos_session_id\` | \`Claude-{Role}-{variant}-{YYYYMMDD}-{4hex}\` | sessions.json | \`Claude-Orch-Prime-20260109-b7d2\` | Per orchestrator |
| \`short_id\` | 4 hex chars | Extracted | \`b7d2\` | Correlation key |
| \`branch_name\` | \`{shortId}-{feature}\` | Git | \`b7d2-session-sync\` | Per worktree |
| \`worktree_path\` | Relative path | Filesystem | \`.worktrees/b7d2-session-sync/\` | Per task |
| \`session_state\` | Enum | sessions.json | \`active\`, \`paused\`, \`abandoned\` | Dynamic |
| \`parent_session_id\` | Reference | sessions.json | \`Claude-Orch-Prime-20260109-b7d2\` | For sub-agents |
| \`heartbeat\` | ISO 8601 | sessions.json | \`2026-01-09T15:30:00-03:00\` | Every 15 min |

### Layer 4: Git Native Identifiers

| Identifier | Format | Source | Example | Notes |
|------------|--------|--------|---------|-------|
| \`git_branch\` | String | \`git branch --show-current\` | \`main\`, \`feat/xyz\` | Current branch |
| \`git_worktree_count\` | Integer | \`git worktree list\` | \`3\` | Active worktrees |
| \`git_remote\` | URL | \`git remote get-url origin\` | \`github.com/...\` | Remote repo |
| \`git_head\` | SHA (7 chars) | \`git rev-parse --short HEAD\` | \`de7b6e2\` | Latest commit |

---

## Correlation Mechanism

### Primary Correlation: Short ID

\`\`\`
+-----------------------------------------------------------------------------+
|  CORRELATION FLOW (Unified)                                                  |
+-----------------------------------------------------------------------------+
|                                                                              |
|  SCENARIO A: MAOS Session -> Short ID                                        |
|  -------------------------------------------------------------------------- |
|  Claude-Orch-Prime-20260109-b7d2                                            |
|                                |                                            |
|                                +-> short_id = "b7d2" (last 4 chars)         |
|                                                                              |
|  SCENARIO B: Claude Code Session -> Short ID                                 |
|  -------------------------------------------------------------------------- |
|  75a91227-c977-4c75-8921-ba01e070dd21                                       |
|                                              |                              |
|                                              +-> short_id = "dd21" (last 4) |
|                                                                              |
|  CORRELATION TABLE                                                           |
|  -------------------------------------------------------------------------- |
|  +----------------------------+-----------------------------------------+   |
|  |      MAOS Session ID       |         Claude Code Session ID          |   |
|  +----------------------------+-----------------------------------------+   |
|  | Claude-Orch-Prime-...-b7d2 | 75a91227-c977-4c75-8921-ba01e070b7d2   |   |
|  |         short_id = b7d2    |        short_id = b7d2 (sync!)         |   |
|  +----------------------------+-----------------------------------------+   |
|                                                                              |
|  NOTE: For new sessions, MAOS generates 4-hex, Claude Code receives UUID.   |
|  Correlation is established by extracting short_id from MAOS session.       |
|                                                                              |
+-----------------------------------------------------------------------------+
\`\`\`

### Branch -> Worktree -> Session Mapping

\`\`\`bash
# Short ID -> Branch -> Worktree
SHORT_ID="b7d2"
BRANCH_NAME="\${SHORT_ID}-session-sync"
WORKTREE_PATH=".worktrees/\${BRANCH_NAME}/"

# Reverse lookup
BRANCH_NAME=\$(git branch --show-current)
SHORT_ID=\$(echo "\$BRANCH_NAME" | grep -oE '^[a-f0-9]{4}')
SESSION=\$(jq -r ".sessions[] | select(.shortId==\"\$SHORT_ID\")" .worktrees/sessions.json)
\`\`\`

---

## Context Window Metrics

### Calculation Reference

\`\`\`bash
# Extract from Claude Code status JSON
CURRENT=\$(jq -r '.context_window.current_usage.input_tokens // 0' <<< "\$STATUS_JSON")
MAX=\$(jq -r '.context_window.context_window_size // 200000' <<< "\$STATUS_JSON")

# Calculate percentages
USED_PCT=\$((CURRENT * 100 / MAX))
LEFT_PCT=\$((100 - USED_PCT))
UNTIL_COMPACT=\$((95 - USED_PCT))  # Auto-compact triggers at ~95%
\`\`\`

### Visual Indicators

| Used % | Until Compact | Indicator | Color | Action |
|--------|---------------|-----------|-------|--------|
| 0-50%  | 45%+          | \`[====    ]\` | Green | Comfortable |
| 50-70% | 25-45%        | \`[======  ]\` | Yellow | Attention |
| 70-85% | 10-25%        | \`[======= ]\` | Orange | Caution |
| 85-95% | 0-10%         | \`[========]\` | Red | Critical |
| 95%+   | 0%            | \`[COMPACT!]\` | Flashing | Auto-compact imminent |

### Model-Specific Context Limits

| Model | Context Window | 95% Threshold |
|-------|---------------|---------------|
| Opus 4.5 | 200,000 | 190,000 |
| Sonnet 4 | 200,000 | 190,000 |
| Haiku 3.5 | 200,000 | 190,000 |

---

## Status Bar Templates

### Template 1: Minimal (Cost Focus)

**Use Case**: Solo developer, cost-conscious, minimal distraction

\`\`\`
+----------------------------------------+
| Opus | \$0.02 | 56%                      |
+----------------------------------------+
   |       |      |
   Model   Cost   Context Used %
\`\`\`

**Format String**: \`{model} | \${cost} | {ctx_pct}%\`

**Example Outputs**:
\`\`\`
Opus | \$0.02 | 56%
Sonnet | \$0.15 | 78%
Haiku | \$0.00 | 12%
\`\`\`

---

### Template 2: Standard (Balanced)

**Use Case**: General development, branch awareness

\`\`\`
+-------------------------------------------------------------+
| Opus 4.5 | VKS_CEO | main | \$0.02 | 56% (39% left)          |
+-------------------------------------------------------------+
     |          |        |       |         |
     Model      Project  Branch  Cost      Context + Until Compact
\`\`\`

**Format String**: \`{model} | {project} | {branch} | \${cost} | {ctx_pct}% ({until_compact}% left)\`

**Example Outputs**:
\`\`\`
Opus 4.5 | VKS_CEO | main | \$0.02 | 56% (39% left)
Sonnet 4 | api-gateway | feat/auth | \$0.15 | 78% (17% left)
\`\`\`

---

### Template 3: Full (All Identifiers)

**Use Case**: Debugging, audit, transparency

\`\`\`
+-----------------------------------------------------------------------------------------------------------+
| Opus 4.5 | VKS_CEO | main | wt:b7d2-sync | active | \$0.02 | 56% | 39% until compact | v1.0.80             |
+-----------------------------------------------------------------------------------------------------------+
     |          |        |          |           |        |       |              |              |
     Model      Project  Branch     Worktree    State    Cost    Used%         Until          Version
\`\`\`

**Format String**: \`{model} | {project} | {branch} | wt:{worktree} | {state} | \${cost} | {ctx_pct}% | {until_compact}% until compact | v{version}\`

**Example Outputs**:
\`\`\`
Opus 4.5 | VKS_CEO | main | wt:b7d2-sync | active | \$0.02 | 56% | 39% until compact | v1.0.80
Sonnet 4 | api-gw | feat/auth | wt:a3f1-auth | paused | \$0.15 | 78% | 17% until compact | v1.0.79
\`\`\`

---

### Template 4: MAOS-Focused (Multi-Agent Orchestration)

**Use Case**: Multi-agent sessions, worktree management, orchestration

\`\`\`
+-------------------------------------------------------------------------------------+
| b7d2 | Orch-Prime | wt:b7d2-sync | ACTIVE | depth:1 | children:3 | \$0.02 | 56%      |
+-------------------------------------------------------------------------------------+
   |         |             |           |          |            |          |       |
   ShortID   Role          Worktree    State      Depth        SubAgents  Cost    Context
\`\`\`

**Format String**: \`{short_id} | {role} | wt:{worktree} | {state} | depth:{depth} | children:{children} | \${cost} | {ctx_pct}%\`

**Example Outputs**:
\`\`\`
b7d2 | Orch-Prime | wt:b7d2-sync | ACTIVE | depth:0 | children:3 | \$0.02 | 56%
a3f1 | Analyst | wt:a3f1-research | ACTIVE | depth:1 | children:0 | \$0.08 | 34%
c614 | QA | wt:c614-validation | PAUSED | depth:1 | children:0 | \$0.04 | 22%
\`\`\`

---

### Template 5: Debug (Internal IDs Visible)

**Use Case**: Troubleshooting, correlation debugging, development

\`\`\`
+-----------------------------------------------------------------------------------------------------------------------+
| CC:dd21 | MAOS:b7d2 | Opus 4.5 | VKS_CEO | main | wt:b7d2-sync | active | \$0.02 | 112k/200k (56%) | PID:12345        |
+-----------------------------------------------------------------------------------------------------------------------+
     |          |          |           |        |          |           |        |            |                |
     CC-ShortID MAOS-ID    Model       Project  Branch     Worktree    State    Cost         Tokens (pct)     Process
\`\`\`

**Format String**: \`CC:{cc_short} | MAOS:{maos_short} | {model} | {project} | {branch} | wt:{worktree} | {state} | \${cost} | {tokens}/{max} ({ctx_pct}%) | PID:{pid}\`

**Example Outputs**:
\`\`\`
CC:dd21 | MAOS:b7d2 | Opus 4.5 | VKS_CEO | main | wt:b7d2-sync | active | \$0.02 | 112k/200k (56%) | PID:12345
CC:e070 | MAOS:a3f1 | Sonnet 4 | api-gw | feat/x | wt:a3f1-feat | paused | \$0.15 | 156k/200k (78%) | PID:12346
\`\`\`

---

### Template 6: Compact Single-Line (Terminal Constrained)

**Use Case**: Narrow terminals, tmux panes, minimal width

\`\`\`
O|VKS|main|\$0.02|56%
\`\`\`

**Format String**: \`{model_char}|{proj_abbr}|{branch}|\${cost}|{ctx_pct}%\`

**Legend**:
- Model char: O=Opus, S=Sonnet, H=Haiku
- proj_abbr: First 3 chars of project

**Example Outputs**:
\`\`\`
O|VKS|main|\$0.02|56%
S|api|feat|\$0.15|78%
H|cli|fix|\$0.00|12%
\`\`\`

---

### Template Comparison Matrix

| Template | Width | Identifiers | Best For |
|----------|-------|-------------|----------|
| Minimal | ~20 chars | 3 | Cost tracking, minimal UI |
| Standard | ~60 chars | 5 | Daily development |
| Full | ~100 chars | 9 | Transparency, audit |
| MAOS-Focused | ~80 chars | 8 | Multi-agent orchestration |
| Debug | ~120 chars | 10 | Troubleshooting |
| Compact | ~20 chars | 5 | Narrow terminals |

---

## Usage Scenarios

### Scenario 1: Solo Developer (No MAOS)

**Profile**: Individual developer using Claude Code without multi-agent orchestration.

**Configuration**:
\`\`\`json
{
  "scenario": "solo",
  "maos_enabled": false,
  "status_template": "standard",
  "identifiers": {
    "required": ["model", "project", "branch", "cost", "context_pct"],
    "optional": ["version", "session_name"],
    "hidden": ["maos_*", "worktree_*", "parent_*"]
  },
  "concurrency": {
    "max_sessions": 1,
    "worktree_required": false
  }
}
\`\`\`

**Status Bar Example**:
\`\`\`
Opus 4.5 | my-project | feat/auth | \$0.02 | 56% (39% left)
\`\`\`

**Workflow**:
1. Start Claude Code in project directory
2. Work directly on branch (no worktree required)
3. Monitor cost and context via status bar
4. No session registry needed

---

### Scenario 2: Multi-Agent Orchestration (Full MAOS)

**Profile**: Orchestrator managing multiple sub-agents with worktree isolation.

**Configuration**:
\`\`\`json
{
  "scenario": "multi-agent",
  "maos_enabled": true,
  "status_template": "maos-focused",
  "identifiers": {
    "required": ["short_id", "role", "worktree", "state", "depth", "children"],
    "optional": ["cost", "context_pct"],
    "hidden": ["cc_session_id"]
  },
  "concurrency": {
    "max_sessions": 10,
    "worktree_required": true,
    "max_depth": 3
  },
  "registry": {
    "file": ".worktrees/sessions.json",
    "heartbeat_interval": "15m",
    "stale_timeout": "30m"
  }
}
\`\`\`

**Status Bar Example (Orchestrator)**:
\`\`\`
b7d2 | Orch-Prime | wt:b7d2-sync | ACTIVE | depth:0 | children:3 | \$0.02 | 56%
\`\`\`

**Status Bar Example (Sub-Agent)**:
\`\`\`
a3f1 | Analyst | wt:a3f1-research | ACTIVE | depth:1 | parent:b7d2 | \$0.08 | 34%
\`\`\`

**Workflow**:
1. Orchestrator generates session ID: \`Claude-Orch-Prime-{date}-{4hex}\`
2. Extracts short_id, creates branch and worktree
3. Registers in sessions.json with heartbeat
4. Delegates to sub-agents, each with own worktree
5. Sub-agents inherit parent short_id in their branch naming
6. QA validation before session close
7. Merge worktrees and cleanup

---

### Scenario 3: Hybrid (CC Session with Optional Worktrees)

**Profile**: Developer who occasionally uses MAOS features but not always.

**Configuration**:
\`\`\`json
{
  "scenario": "hybrid",
  "maos_enabled": "optional",
  "status_template": "standard",
  "identifiers": {
    "required": ["model", "project", "branch", "cost", "context_pct"],
    "conditional": {
      "if_worktree": ["worktree", "state"],
      "if_maos": ["short_id", "role"]
    }
  },
  "concurrency": {
    "max_sessions": 3,
    "worktree_required": false,
    "worktree_recommended_for": ["parallel_tasks", "risky_changes", "protected_files"]
  }
}
\`\`\`

**Status Bar Example (No Worktree)**:
\`\`\`
Opus 4.5 | VKS_CEO | main | \$0.02 | 56% (39% left)
\`\`\`

**Status Bar Example (With Worktree)**:
\`\`\`
Opus 4.5 | VKS_CEO | main | wt:b7d2-fix | active | \$0.02 | 56%
\`\`\`

**Workflow**:
1. Start Claude Code normally
2. For simple changes: work directly on branch
3. For complex/parallel/risky: create worktree on-demand
4. Optionally register in sessions.json
5. Cleanup worktrees when done

---

### Scenario Decision Matrix

| Factor | Solo | Full MAOS | Hybrid |
|--------|------|-----------|--------|
| Multi-agent coordination | No | Yes | Optional |
| Worktree required | No | Yes | Conditional |
| Session registry | No | Yes | Optional |
| Heartbeat required | No | Yes | If registered |
| QA validation | No | Yes | Recommended |
| Max concurrent sessions | 1 | 10+ | 3 |
| Learning curve | Low | High | Medium |

---

## Schema Proposal v2.1

### Session Registry Schema (sessions.json)

\`\`\`json
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "MAOS Session Registry v2.1",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "const": "2.1"
    },
    "last_updated": {
      "type": "string",
      "format": "date-time"
    },
    "last_updated_by": {
      "type": "string",
      "pattern": "^Claude-[A-Za-z]+-[A-Za-z]*-?[0-9]{8}-[a-f0-9]{4}\$"
    },
    "active_sessions": {
      "type": "array",
      "items": { "\$ref": "#/\$defs/session" }
    },
    "completed_sessions": {
      "type": "array",
      "items": { "\$ref": "#/\$defs/session" }
    }
  },
  "\$defs": {
    "session": {
      "type": "object",
      "required": ["session_id", "short_id", "started_at", "state"],
      "properties": {
        "session_id": {
          "type": "string",
          "description": "Full MAOS session ID",
          "pattern": "^Claude-[A-Za-z]+-[A-Za-z]*-?[0-9]{8}-[a-f0-9]{4}\$",
          "examples": ["Claude-Orch-Prime-20260109-b7d2"]
        },
        "short_id": {
          "type": "string",
          "description": "4-char hex correlation key",
          "pattern": "^[a-f0-9]{4}\$",
          "examples": ["b7d2"]
        },
        "cc_session_id": {
          "type": "string",
          "description": "Claude Code native UUID (optional, for correlation)",
          "format": "uuid",
          "examples": ["75a91227-c977-4c75-8921-ba01e070dd21"]
        },
        "role": {
          "type": "string",
          "enum": ["Orch-Prime", "Analyst", "Architect", "Dev", "PM", "PO", "QA", "DevOps", "UX", "Editor", "Consolidator", "CEO", "Legal"],
          "description": "Agent role/persona"
        },
        "branch_name": {
          "type": "string",
          "description": "Git branch associated with session",
          "pattern": "^[a-f0-9]{4}-[a-z0-9-]+\$",
          "examples": ["b7d2-session-sync"]
        },
        "worktree_path": {
          "type": ["string", "null"],
          "description": "Relative path to worktree directory",
          "examples": [".worktrees/b7d2-session-sync/", null]
        },
        "started_at": {
          "type": "string",
          "format": "date-time"
        },
        "completed_at": {
          "type": "string",
          "format": "date-time"
        },
        "last_heartbeat": {
          "type": "string",
          "format": "date-time",
          "description": "Last activity timestamp (update every 15 min)"
        },
        "state": {
          "type": "string",
          "enum": ["active", "paused", "blocked", "abandoned", "completed"],
          "description": "Current session state"
        },
        "pause_reason": {
          "type": "string",
          "enum": ["dependency", "end_of_day", "context_limit", "user_request"],
          "description": "Reason for pause (if state=paused)"
        },
        "current_task": {
          "type": "string",
          "description": "Human-readable current task description"
        },
        "task_id": {
          "type": "string",
          "description": "Reference to tasks.md task ID",
          "examples": ["TASK-001"]
        },
        "parent_session_id": {
          "type": ["string", "null"],
          "description": "Parent session for sub-agents",
          "examples": ["Claude-Orch-Prime-20260109-b7d2", null]
        },
        "depth": {
          "type": "integer",
          "minimum": 0,
          "maximum": 3,
          "description": "Delegation depth (0=orchestrator, 1-3=sub-agents)"
        },
        "children": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of child session IDs"
        },
        "pid": {
          "type": "integer",
          "description": "Process ID for orphan detection"
        },
        "result": {
          "type": "string",
          "description": "Summary of session outcome (for completed)"
        },
        "qa_result": {
          "\$ref": "#/\$defs/qa_result"
        },
        "notes": {
          "type": "string"
        }
      }
    },
    "qa_result": {
      "type": ["object", "null"],
      "properties": {
        "qa_passed": { "type": "boolean" },
        "score": { "type": "integer", "minimum": 0, "maximum": 100 },
        "issues": { "type": "array", "items": { "type": "string" } },
        "checks": {
          "type": "object",
          "properties": {
            "commits_verified": { "type": "boolean" },
            "tasks_md_updated": { "type": "boolean" },
            "sessions_json_consistent": { "type": "boolean" },
            "documents_signed": { "type": "boolean" },
            "worktrees_clean": { "type": "boolean" },
            "no_orphan_files": { "type": "boolean" }
          }
        },
        "validated_by": { "type": "string" },
        "validated_at": { "type": "string", "format": "date-time" }
      }
    }
  }
}
\`\`\`

### Example Session Entry (v2.1)

\`\`\`json
{
  "session_id": "Claude-Orch-Prime-20260109-b7d2",
  "short_id": "b7d2",
  "cc_session_id": "75a91227-c977-4c75-8921-ba01e070b7d2",
  "role": "Orch-Prime",
  "branch_name": "b7d2-session-sync",
  "worktree_path": ".worktrees/b7d2-session-sync/",
  "started_at": "2026-01-09T14:30:00-03:00",
  "last_heartbeat": "2026-01-09T15:45:00-03:00",
  "state": "active",
  "current_task": "Creating unified session identifiers document",
  "task_id": "TASK-012",
  "parent_session_id": null,
  "depth": 0,
  "children": ["Claude-Analyst-b7d2-001", "Claude-QA-b7d2-002"],
  "pid": 12345
}
\`\`\`

### Sub-Agent Entry Example (v2.1)

\`\`\`json
{
  "session_id": "Claude-Analyst-b7d2-001",
  "short_id": "b7d2",
  "role": "Analyst",
  "branch_name": "b7d2-research",
  "worktree_path": ".worktrees/b7d2-research/",
  "started_at": "2026-01-09T14:45:00-03:00",
  "last_heartbeat": "2026-01-09T15:30:00-03:00",
  "state": "completed",
  "completed_at": "2026-01-09T15:35:00-03:00",
  "current_task": "Research existing documentation patterns",
  "parent_session_id": "Claude-Orch-Prime-20260109-b7d2",
  "depth": 1,
  "children": [],
  "result": "Identified 6 documentation patterns with recommendations"
}
\`\`\`

---

## Implementation Recommendations

### Priority Matrix

| Priority | Item | Effort | Impact | Notes |
|----------|------|--------|--------|-------|
| P0 | Session registry schema v2.1 | Low | High | Foundation for all features |
| P0 | Short ID extraction function | Low | High | Correlation key |
| P1 | Standard status bar template | Medium | High | Daily use |
| P1 | Heartbeat mechanism | Medium | High | Stale detection |
| P2 | MAOS-focused template | Medium | Medium | Multi-agent use |
| P2 | Parent-child tracking | Medium | Medium | Orchestration visibility |
| P3 | Debug template | Low | Low | Troubleshooting only |
| P3 | Full audit logging | High | Low | Compliance only |

### Implementation Phases

**Phase 1: Core (Week 1)**
- Implement schema v2.1 in sessions.json
- Create short_id extraction utility
- Implement standard status bar template
- Add heartbeat update mechanism

**Phase 2: Multi-Agent (Week 2)**
- Implement MAOS-focused template
- Add parent-child session tracking
- Create worktree-session correlation
- Implement depth tracking

**Phase 3: Polish (Week 3)**
- Add all template variants
- Implement template switching
- Create scenario-based defaults
- Documentation and training

### Configuration File Structure

\`\`\`yaml
# .claude/status-bar.yaml
version: "2.1"
scenario: "hybrid"  # solo | multi-agent | hybrid

template:
  active: "standard"
  available:
    - minimal
    - standard
    - full
    - maos-focused
    - debug
    - compact

identifiers:
  always_show:
    - model
    - cost
    - context_pct
  conditional:
    if_maos: [short_id, role, worktree, state]
    if_debug: [cc_session_id, pid, tokens]

thresholds:
  context_warning: 70
  context_critical: 85
  context_compact: 95

colors:
  context_ok: green
  context_warning: yellow
  context_critical: red
\`\`\`

---

## Corrections & Clarifications

### Corrections from Source Documents

| Item | Original | Corrected | Reason |
|------|----------|-----------|--------|
| Short ID source | "Last 4 chars of Claude Code UUID" | "Last 4 chars of MAOS session ID" | MAOS ID is authoritative; CC UUID correlation is secondary |
| Context threshold | Implicit | Explicit 95% | Clarified auto-compact trigger point |
| Branch naming | Two competing patterns | Both valid, flexible | Allow project-specific conventions |
| QA requirement | Mentioned but not enforced | Mandatory for multi-agent | Protocol v3.2 enforcement |

### Clarifications

1. **Short ID Uniqueness**: 4-hex provides 65,536 unique values. With timestamp in session ID, collision risk is negligible (~0.15% with 50 concurrent sessions per day).

2. **Worktree vs Branch**: Worktree is mandatory for file isolation in multi-agent; branch naming is flexible. Both \`{shortId}-{feature}\` and \`{tipo}/{feature}-{shortId}\` are valid.

3. **Heartbeat Purpose**: Primarily for stale detection (30 min timeout), not for real-time sync. Update every 15 minutes during active work.

4. **Parent-Child Inheritance**: Sub-agents inherit parent's short_id for branch naming but generate unique session_id with sequence number.

5. **CC Session ID Correlation**: Optional field for debugging/audit. MAOS session ID is primary; CC UUID is secondary reference.

---

## Changelog

| Data | Versao | Descricao |
|------|--------|-----------|
| 2026-01-09 | 2.1 | Unified document merging research.md and ADR-001 |

---

## References

### Source Documents
- `session-identifiers-research.md` (v1.0)
- `multi-agent-os/docs/adrs/ADR-001-session-identity.md` (v1.0)

### Related Documentation
- \`.claude/docs/multi-agent-collaboration.md\`
- \`.claude/docs/orchestration-framework.md\`
- \`.worktrees/sessions.json\`

### External References
- Git Worktree Documentation: https://git-scm.com/docs/git-worktree
- Claude Code Documentation: https://docs.anthropic.com/claude/code
- JSON Schema: https://json-schema.org/draft/2020-12/schema

---

*Assinatura: Claude-Consolidator-e00a-001 | 2026-01-09T16:00:00-03:00*
