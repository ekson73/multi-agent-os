# Sentinel Protocol

## Overview

The Sentinel Protocol is an embedded observability system for the AI Agent Orchestration Framework. It provides automatic monitoring, anomaly detection, and audit capabilities without adding significant overhead to agent operations.

**Protocol Version**: 1.0.0 (Implementation Ready)
**Status**: RFC 0.1 → v1.0.0 (Implemented 2026-01-06)
**Author**: Claude-Orch-Prime-20260106-86fa
**Created**: 2026-01-06
**Standards Alignment**: OpenTelemetry GenAI Semantic Conventions

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SENTINEL PROTOCOL - OBSERVABILITY SYSTEM                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌───────────────────────────────────────────────────────────────┐    │
│   │                     TRACE HOOKS (Automatic)                    │    │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │    │
│   │  │ PRE_DELEGATE│  │POST_DELEGATE│  │  ON_ERROR   │           │    │
│   │  │   (before)  │  │   (after)   │  │  (failure)  │           │    │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘           │    │
│   └─────────┼────────────────┼────────────────┼───────────────────┘    │
│             │                │                │                         │
│             ▼                ▼                ▼                         │
│   ┌───────────────────────────────────────────────────────────────┐    │
│   │                    AUDIT LOG (Persistent)                      │    │
│   │         .claude/audit/session_{YYYYMMDD}_{hex}.jsonl          │    │
│   └───────────────────────────────────────────────────────────────┘    │
│             │                                                           │
│             ▼                                                           │
│   ┌───────────────────────────────────────────────────────────────┐    │
│   │                 DETECTION ENGINE (Analysis)                    │    │
│   │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ │    │
│   │  │  Loop   │ │  Depth  │ │  Task   │ │  Error  │ │Stagnation│ │    │
│   │  │Detection│ │Violation│ │  Drift  │ │ Cascade │ │ Timeout │ │    │
│   │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ │    │
│   └───────┼───────────┼───────────┼───────────┼───────────┼───────┘    │
│           │           │           │           │           │             │
│           └───────────┴───────────┼───────────┴───────────┘             │
│                                   ▼                                     │
│                         ┌─────────────────┐                            │
│                         │  ALERT SYSTEM   │                            │
│                         │ (Notify Orch)   │                            │
│                         └────────┬────────┘                            │
│                                  │                                      │
│                    ┌─────────────┴─────────────┐                       │
│                    ▼                           ▼                        │
│            ┌─────────────┐             ┌─────────────┐                 │
│            │    LOG      │             │  ESCALATE   │                 │
│            │  (passive)  │             │ (corrector) │                 │
│            └─────────────┘             └─────────────┘                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
.claude/
├── sentinel/
│   ├── README.md                 ← This file (v1.0)
│   ├── config.json               ← Configuration (NEW)
│   ├── detection_rules.md        ← Rules v1.0.1 (bugs fixed)
│   ├── schema/
│   │   ├── trace_schema.json     ← Trace format (NEW)
│   │   └── alert_schema.json     ← Alert format (NEW)
│   ├── lib/
│   │   ├── trace_writer.md       ← Persistence patterns (NEW)
│   │   └── alert_handler.md      ← Alert patterns (NEW)
│   └── rules/
│       └── (reserved for future)
├── audit/
│   ├── session_index.json        ← Fast lookup index (NEW)
│   └── session_*.jsonl           ← Session traces
└── skills/
    └── audit.md                  ← Audit skill v1.1.0
```

---

## Why Protocol Instead of Sub-Agent?

Based on research of industry patterns (OpenTelemetry, AgentOps, LangSmith), a **protocol-based approach** is superior to a traditional observer sub-agent:

| Aspect | Sub-Agent Approach | Protocol Approach |
|--------|-------------------|-------------------|
| Overhead | High (2 calls per action) | Low (inline hooks) |
| Reliability | May be "forgotten" | Always executes |
| Latency | Adds round-trip per action | Minimal (async) |
| Persistence | Ephemeral | Audit log persists |
| Analysis | Real-time only | Historical + real-time |
| Standards | Custom | OpenTelemetry aligned |

---

## Components

### 1. Trace Hooks (Automatic)

Hooks are automatically invoked at key points in the delegation lifecycle:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `PRE_DELEGATE` | Before Task tool call | Log intent, check rules |
| `POST_DELEGATE` | After Task tool returns | Log result, detect anomalies |
| `ON_ERROR` | When agent fails | Log error, trigger analysis |
| `ON_ESCALATE` | When agent escalates | Track escalation chain |

### 2. Audit Log (Persistent)

All traces are persisted to JSONL files for historical analysis:

```
.claude/audit/
├── session_20260106_86fa.jsonl   ← Current session
├── session_20260105_a1b2.jsonl   ← Previous sessions
└── ...
```

**Trace Schema**:
```json
{
  "trace_id": "uuid-v4",
  "timestamp": "2026-01-06T19:45:00-03:00",
  "session_id": "Claude-Orch-Prime-20260106-86fa",
  "agent_id": "Claude-PO-86fa-001",
  "action": "delegate",
  "phase": "pre|post",
  "context": {
    "parent_agent": "Claude-Orch-Prime-20260106-86fa",
    "delegation_depth": 1,
    "task_id": "task-001",
    "task_description": "Analyze VKS-550 for MVP inclusion",
    "target_agent": "Claude-PO"
  },
  "metrics": {
    "duration_ms": 45000,
    "tokens_used": 2500,
    "success": true,
    "error": null
  },
  "analysis": {
    "loop_risk": "none",
    "task_similarity_to_parent": 0.15,
    "depth_violation": false,
    "recommended_action": null
  }
}
```

### 3. Detection Engine (Analysis)

Predefined rules that analyze traces for anomalies:

| Rule | Condition | Severity | Action |
|------|-----------|----------|--------|
| Loop Detection | Same task delegated 2+ times | HIGH | Alert + Block |
| Depth Violation | delegation_depth > 3 | HIGH | Alert + Block |
| Task Drift | output unrelated to task | MEDIUM | Alert |
| Error Cascade | 2+ consecutive errors | HIGH | Alert + Escalate |
| Stagnation | execution > 5min | MEDIUM | Alert |
| Agent Mismatch | wrong agent for task | LOW | Log |

See `detection_rules.md` for detailed rule definitions.

### 4. Alert System (Notification)

When anomaly detected:

1. **Log**: Record anomaly in audit log
2. **Notify**: Alert Orchestrator with summary
3. **Recommend**: Suggest corrective action
4. **Escalate** (optional): Dispatch corrector sub-agent

---

## Usage

### Automatic (Hooks)

Hooks fire automatically — no manual invocation needed. Every delegation goes through:

```
User Request
    │
    ▼
Orchestrator receives task
    │
    ├──► [PRE_DELEGATE Hook] ──► Log + Validate
    │
    ▼
Select agent (/agent-select)
    │
    ├──► [Sentinel Analyzes] ──► Check rules
    │
    ├── PASS ───────────────────────────────────┐
    │                                           │
    └── ALERT! ──► Notify Orch ──► Block/Fix    │
                                                │
                                                ▼
                                          Sub-Agent executes
                                                │
    ┌───────────────────────────────────────────┘
    │
    ├──► [POST_DELEGATE Hook] ──► Log + Analyze result
    │
    ▼
Return to Orchestrator
```

### Manual (/audit skill)

For on-demand deep analysis, use the `/audit` skill:

```
/audit session          # Full session audit
/audit agent <id>       # Audit specific agent
/audit task <id>        # Audit specific task
/audit flow             # Delegation flow analysis
/audit anomalies        # List all detected anomalies
```

See `.claude/skills/audit.md` for full documentation.

---

## Quick Start

### 1. Verify Installation
Check that all required files exist:
```bash
ls -la .claude/sentinel/
ls -la .claude/sentinel/schema/
ls -la .claude/sentinel/lib/
ls -la .claude/audit/
```

### 2. Review Configuration
```bash
cat .claude/sentinel/config.json
```

Key settings:
- `detection.loop.similarity_threshold`: 0.85
- `detection.depth.max_delegation_depth`: 3
- `hooks.enforcement_mode`: "soft"

### 3. Test Audit Skill
```
/audit health    # Check current health score
/audit config    # View configuration
/audit session   # Full session audit
```

### 4. Enable Alerts (Optional)
Edit `config.json` to enable Slack alerts:
```json
{
  "alerts": {
    "slack": {
      "enabled": true,
      "webhook_url": "your-webhook-url"
    }
  }
}
```

---

## Integration with Orchestrator

The Sentinel Protocol is referenced in the Orchestrator's decision tree:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DELEGATION PROTOCOL (with Sentinel)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  [Task Received]                                                        │
│        │                                                                │
│        ▼                                                                │
│  ┌─────────────────┐                                                    │
│  │ SENTINEL CHECK  │ ◄── PRE_DELEGATE Hook                             │
│  │ (validate task) │                                                    │
│  └────────┬────────┘                                                    │
│           │                                                             │
│     ┌─────┴─────┐                                                       │
│     │           │                                                       │
│   PASS        BLOCK                                                     │
│     │           │                                                       │
│     ▼           ▼                                                       │
│  Continue    Alert + Stop                                               │
│     │                                                                   │
│     ▼                                                                   │
│  /agent-select ──► /context-prep ──► /delegate                         │
│                                           │                             │
│                                           ▼                             │
│                                    ┌─────────────────┐                  │
│                                    │ SENTINEL CHECK  │ ◄── POST Hook   │
│                                    │ (validate result)│                 │
│                                    └────────┬────────┘                  │
│                                             │                           │
│                                       ┌─────┴─────┐                     │
│                                       │           │                     │
│                                     PASS        ALERT                   │
│                                       │           │                     │
│                                       ▼           ▼                     │
│                                   Accept     Log + Recommend            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Health Score

The Sentinel calculates a session health score (0-100):

```
HEALTH SCORE CALCULATION
═══════════════════════════════════════════════════════════════════════════

Base Score: 100

Deductions:
  - Loop detected: -20 per occurrence
  - Depth violation: -15 per occurrence
  - Error cascade: -15 per occurrence
  - Task drift: -10 per occurrence
  - Stagnation: -5 per occurrence
  - Agent mismatch: -3 per occurrence

Bonuses:
  + Clean delegation (no issues): +2 per delegation
  + Fast execution (<30s): +1 per task
  + Successful escalation handling: +5 per recovery

Final Score: max(0, min(100, calculated_score))

Interpretation:
  90-100: Excellent - Optimal agent coordination
  70-89:  Good - Minor issues, acceptable
  50-69:  Fair - Review recommended
  <50:    Poor - Intervention required
```

---

## Files in This Package

| File | Version | Purpose |
|------|---------|---------|
| `README.md` | 1.0.0 | This documentation |
| `config.json` | 1.0.0 | Configurable thresholds and settings |
| `detection_rules.md` | 1.0.1 | Detection rule definitions (3 bugs fixed) |
| `schema/trace_schema.json` | 1.0.0 | JSON Schema for trace validation |
| `schema/alert_schema.json` | 1.0.0 | JSON Schema for alert format |
| `lib/trace_writer.md` | 1.0.0 | JSONL persistence patterns |
| `lib/alert_handler.md` | 1.0.0 | Alert routing and notification |

### Related Files

| Path | Version | Purpose |
|------|---------|---------|
| `.claude/skills/audit.md` | 1.1.0 | Manual audit skill |
| `.claude/audit/session_index.json` | 1.0.0 | Session lookup index |
| `CLAUDE.md` | - | Hook Protocol Directive |

---

## Implementation Status

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SENTINEL PROTOCOL v1.0 — IMPLEMENTATION STATUS                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  M1: Foundation     │ ✅ COMPLETE │ Schemas, config, structure          │
│  M2: Persistence    │ ✅ COMPLETE │ JSONL writer, session index         │
│  M3: Detection      │ ✅ COMPLETE │ 3 critical bugs fixed               │
│  M4: Integration    │ ✅ COMPLETE │ Hooks, alerts, audit skill          │
│  M5: Polish         │ ✅ COMPLETE │ Documentation updated               │
│                                                                         │
│  Overall: PRODUCTION READY                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Multi-Agent Validation (Pre-Implementation)
- **8 agents** analyzed the RFC
- **Score**: 6.7/10 (design excellent, needed implementation)
- **3 critical bugs** identified and fixed in v1.0.1
- **7 additional gaps** discovered and addressed

---

## References

- [OpenTelemetry AI Agent Observability](https://opentelemetry.io/blog/2025/ai-agent-observability/)
- [AgentOps SDK](https://github.com/AgentOps-AI/agentops)
- [Microsoft AI Agent Design Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
- [AWS Multi-Agent Orchestration Guidance](https://aws.amazon.com/solutions/guidance/multi-agent-orchestration-on-aws/)

---

*Sentinel Protocol v1.0.0 | Implemented by Claude-Orch-Prime-20260106-c614 | 2026-01-06*
