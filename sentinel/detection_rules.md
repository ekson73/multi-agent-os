# Sentinel Detection Rules

## Overview

This document defines the anomaly detection rules used by the Sentinel Protocol to identify issues in agent orchestration flows.

**Version**: 1.0.1
**Author**: Claude-Orch-Prime-20260106-86fa
**Created**: 2026-01-06

---

## Rule Categories

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DETECTION RULE CATEGORIES                                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  STRUCTURAL RULES         BEHAVIORAL RULES        PERFORMANCE RULES    │
│  ─────────────────       ─────────────────       ─────────────────     │
│  • Loop Detection        • Task Drift            • Stagnation          │
│  • Depth Violation       • Output Quality        • Token Bloat         │
│  • Agent Mismatch        • Error Cascade         • Timeout             │
│  • Chain Break           • Escalation Abuse      • Retry Storm         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Rule Definitions

### RULE-001: Loop Detection

**Category**: Structural
**Severity**: HIGH
**Auto-block**: Yes

**Description**: Detects when the same or very similar task is delegated multiple times, indicating an infinite loop.

**Condition**:
```python
def check_loop(current_task, task_history, delegation_chain):
    # Check 1: Direct similarity loop (existing)
    for previous_task in task_history:
        similarity = calculate_similarity(current_task, previous_task)
        if similarity > 0.85:  # 85% similarity threshold
            if previous_task.agent_type == current_task.target_agent:
                return ALERT("Loop detected: same task to same agent type")

    # Check 2: Cross-chain transitive loop (NEW)
    target_agent_type = current_task.target_agent
    for agent_id in delegation_chain:
        if get_agent_type(agent_id) == target_agent_type:
            return ALERT(f"Cross-chain loop detected: {target_agent_type} already in chain {delegation_chain}")

    return PASS
```

> **Fixed in v1.0.1**: Added cross-chain transitive loop detection. Previously only detected direct A→A loops; now detects A→B→C→A loops by tracking agent types in the entire delegation chain.

**Triggers**:
- Same task description delegated 2+ times
- Same agent type receives similar task within chain
- Task similarity > 85% with previous task in chain

**Action**:
1. BLOCK delegation
2. ALERT orchestrator with loop details
3. RECOMMEND: "Break loop by modifying task or using different agent"

**Example**:
```
Chain: Orch → Analyst → Analyst (LOOP!)
Task: "Analyze requirements"
Both Analyst instances received essentially the same task.
```

---

### RULE-002: Depth Violation

**Category**: Structural
**Severity**: HIGH
**Auto-block**: Yes

**Description**: Detects when delegation depth exceeds maximum allowed (default: 3).

**Condition**:
```python
def check_depth(delegation_depth, max_depth=3):
    if delegation_depth > max_depth:
        return ALERT(f"Depth violation: {delegation_depth} > {max_depth}")
    return PASS
```

**Triggers**:
- delegation_depth > 3

**Action**:
1. BLOCK further delegation
2. ALERT orchestrator
3. RECOMMEND: "Consolidate task or escalate to parent"

**Example**:
```
Chain: Orch → PM → Analyst → Dev → QA (depth=4, VIOLATION!)
```

---

### RULE-003: Task Drift

**Category**: Behavioral
**Severity**: MEDIUM
**Auto-block**: No

**Description**: Detects when agent output is unrelated to the assigned task.

**Condition**:
```python
def check_task_drift(task_description, agent_output, execution_result):
    # Skip drift detection if agent encountered an error
    if execution_result.error is not None:
        return PASS  # Error handling takes precedence, not drift

    if not execution_result.success:
        return PASS  # Failed execution, not drift

    # Only check drift for successful executions
    relevance = calculate_semantic_relevance(task_description, agent_output)
    if relevance < 0.5:  # 50% relevance threshold
        return ALERT(f"Task drift: output relevance {relevance:.0%} (success but off-topic)")
    return PASS
```

> **Fixed in v1.0.1**: Added execution_result parameter to distinguish between error failures and semantic drift. Now only triggers drift alerts for successful executions that produce off-topic output, not for error conditions.

**Triggers**:
- Output semantically unrelated to input task
- Missing expected deliverables
- Output addresses different problem

**Action**:
1. LOG anomaly
2. ALERT orchestrator
3. RECOMMEND: "Review output, consider re-delegation with clearer constraints"

---

### RULE-004: Error Cascade

**Category**: Behavioral
**Severity**: HIGH
**Auto-block**: Conditional

**Description**: Detects consecutive errors indicating systemic problem.

**Condition**:
```python
def check_error_cascade(error_count, consecutive=True):
    if consecutive and error_count >= 2:
        return ALERT(f"Error cascade: {error_count} consecutive errors")
    if not consecutive and error_count >= 3:
        return ALERT(f"Error pattern: {error_count} errors in session")
    return PASS
```

**Triggers**:
- 2+ consecutive task failures
- 3+ failures in same session (any position)

**Action**:
1. ALERT orchestrator immediately
2. RECOMMEND: "Investigate root cause before continuing"
3. If 3+ consecutive: AUTO-BLOCK further delegation

---

### RULE-005: Stagnation

**Category**: Performance
**Severity**: MEDIUM
**Auto-block**: No

**Description**: Detects when agent execution takes unusually long.

**Condition**:
```python
def check_stagnation(execution_time_ms, threshold_ms=300000):  # 5 min
    if execution_time_ms > threshold_ms:
        return ALERT(f"Stagnation: {execution_time_ms/1000:.0f}s > threshold")
    return PASS
```

**Triggers**:
- Execution time > 5 minutes (default)
- No progress indicators for extended period

**Action**:
1. LOG warning
2. NOTIFY orchestrator
3. RECOMMEND: "Check if agent is blocked, consider timeout"

---

### RULE-006: Agent Mismatch

**Category**: Structural
**Severity**: LOW
**Auto-block**: No

**Description**: Detects when task is delegated to suboptimal agent.

**Condition**:
```python
def check_agent_mismatch(task_keywords, selected_agent):
    optimal_agent = agent_select(task_keywords)
    if optimal_agent != selected_agent:
        confidence_diff = optimal_agent.score - selected_agent.score
        if confidence_diff > 0.20:  # 20% difference threshold
            return ALERT(f"Agent mismatch: {optimal_agent} better fit")
    return PASS
```

**Triggers**:
- Better agent available with >20% higher match score
- Task keywords strongly indicate different agent

**Action**:
1. LOG observation
2. SUGGEST (non-blocking): "Consider {optimal_agent} for better match"

---

### RULE-007: Chain Break

**Category**: Structural
**Severity**: MEDIUM
**Auto-block**: No

**Description**: Detects when delegation chain is unexpectedly broken.

**Condition**:
```python
def check_chain_break(expected_return, actual_return):
    # Null guards
    if expected_return is None:
        return PASS  # No expectation, nothing to check

    if actual_return is None:
        if expected_return is not None:
            return ALERT("Chain break: expected return not received")
        return PASS

    # Safe parent comparison with null handling
    expected_parent = getattr(expected_return, 'parent', None)
    actual_parent = getattr(actual_return, 'parent', None)

    if expected_parent is None and actual_parent is None:
        return PASS  # Both are root, no break

    if expected_parent != actual_parent:
        return ALERT(f"Chain break: return to wrong parent (expected: {expected_parent}, actual: {actual_parent})")

    return PASS
```

> **Fixed in v1.0.1**: Added comprehensive null guards to prevent NullPointerException. Uses safe attribute access with getattr() and handles all null/None edge cases for parent references.

**Triggers**:
- Agent doesn't return to expected parent
- Orphaned task without completion
- Missing consolidation step

**Action**:
1. ALERT orchestrator
2. RECOMMEND: "Verify agent completion, check for orphaned tasks"

---

### RULE-008: Escalation Abuse

**Category**: Behavioral
**Severity**: MEDIUM
**Auto-block**: Conditional

**Description**: Detects excessive escalation pattern indicating agent avoidance.

**Condition**:
```python
def check_escalation_abuse(agent_id, escalation_count, task_count):
    escalation_rate = escalation_count / max(task_count, 1)
    if escalation_rate > 0.5:  # More than 50% tasks escalated
        return ALERT(f"Escalation abuse: {escalation_rate:.0%} rate")
    return PASS
```

**Triggers**:
- Agent escalates >50% of received tasks
- 3+ consecutive escalations without execution

**Action**:
1. LOG pattern
2. ALERT orchestrator
3. RECOMMEND: "Review agent constraints or task decomposition"

---

### RULE-009: Token Bloat

**Category**: Performance
**Severity**: LOW
**Auto-block**: No

**Description**: Detects excessive token usage indicating inefficiency.

**Condition**:
```python
def check_token_bloat(tokens_used, task_complexity):
    expected_tokens = estimate_tokens(task_complexity)
    if tokens_used > expected_tokens * 3:  # 3x threshold
        return ALERT(f"Token bloat: {tokens_used} >> expected {expected_tokens}")
    return PASS
```

**Triggers**:
- Token usage >3x expected for task complexity
- Unusually verbose outputs

**Action**:
1. LOG observation
2. SUGGEST: "Consider more concise prompts or outputs"

---

### RULE-010: Retry Storm

**Category**: Performance
**Severity**: HIGH
**Auto-block**: Yes

**Description**: Detects rapid retry pattern indicating stuck state.

**Condition**:
```python
def check_retry_storm(retry_count, time_window_ms=60000):  # 1 minute
    retries_in_window = count_retries_within(time_window_ms)
    if retries_in_window >= 5:
        return ALERT(f"Retry storm: {retries_in_window} retries in 1 min")
    return PASS
```

**Triggers**:
- 5+ retries within 1 minute
- Rapid succession of same operation

**Action**:
1. AUTO-BLOCK retries
2. ALERT orchestrator
3. REQUIRE manual intervention

---

## Severity Levels

| Level | Color | Auto-Block | Description |
|-------|-------|------------|-------------|
| HIGH | 🔴 | Yes | Critical issue, immediate action required |
| MEDIUM | 🟡 | No | Significant concern, review recommended |
| LOW | 🟢 | No | Minor observation, informational |

---

## Rule Execution Order

Rules are evaluated in priority order:

```
1. RULE-010: Retry Storm      (block immediately if true)
2. RULE-001: Loop Detection   (block immediately if true)
3. RULE-002: Depth Violation  (block immediately if true)
4. RULE-004: Error Cascade    (block if 3+ consecutive)
5. RULE-007: Chain Break      (alert and log)
6. RULE-003: Task Drift       (alert and log)
7. RULE-008: Escalation Abuse (alert if pattern detected)
8. RULE-005: Stagnation       (alert on timeout)
9. RULE-006: Agent Mismatch   (suggest only)
10. RULE-009: Token Bloat     (log only)
```

---

## Custom Rules

To add custom rules, create entries following this template:

```markdown
### RULE-XXX: {Name}

**Category**: {Structural|Behavioral|Performance}
**Severity**: {HIGH|MEDIUM|LOW}
**Auto-block**: {Yes|No|Conditional}

**Description**: {What the rule detects}

**Condition**:
```python
def check_{rule_name}(parameters):
    # Detection logic
    return ALERT("message") or PASS
```

**Triggers**:
- {Condition 1}
- {Condition 2}

**Action**:
1. {Action 1}
2. {Action 2}
```

---

## Tuning Parameters

Default thresholds can be adjusted:

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `max_delegation_depth` | 3 | 2-5 | Maximum chain depth |
| `task_similarity_threshold` | 0.85 | 0.7-0.95 | Loop detection sensitivity |
| `task_relevance_threshold` | 0.50 | 0.3-0.7 | Drift detection sensitivity |
| `stagnation_timeout_ms` | 300000 | 60000-600000 | Stagnation threshold |
| `error_cascade_threshold` | 2 | 2-5 | Consecutive errors to alert |
| `token_bloat_multiplier` | 3.0 | 2.0-5.0 | Token usage multiplier |
| `retry_storm_threshold` | 5 | 3-10 | Retries per minute |

---

*Detection Rules v1.0.1 | Created by Claude-Orch-Prime-20260106-86fa | 2026-01-06*

---

## Changelog

### v1.0.1 (2026-01-06)

**Bug Fixes**:

1. **RULE-001 (Loop Detection)**: Fixed cross-chain transitive loop detection. Previously only detected direct A→A loops; now properly detects A→B→C→A loops by tracking agent types throughout the entire delegation chain.

2. **RULE-003 (Task Drift)**: Fixed false positive drift alerts on error conditions. Added `execution_result` parameter to distinguish between agent errors and genuine semantic drift. Drift alerts now only trigger for successful executions that produce off-topic output.

3. **RULE-007 (Chain Break)**: Fixed NullPointerException when parent references are null. Added comprehensive null guards using safe attribute access (`getattr`) and proper handling of all null/None edge cases for parent comparisons.

### v1.0.0 (2026-01-06)

- Initial release with 10 detection rules
- Structural rules: Loop Detection, Depth Violation, Agent Mismatch, Chain Break
- Behavioral rules: Task Drift, Output Quality, Error Cascade, Escalation Abuse
- Performance rules: Stagnation, Token Bloat, Timeout, Retry Storm
