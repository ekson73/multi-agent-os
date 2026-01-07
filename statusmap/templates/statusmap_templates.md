# Status Map Templates v1.0

## Overview

Status Maps are ASCII visualizations for observability that provide quick, human-readable system state snapshots. They integrate with the Sentinel Protocol to offer real-time awareness of agent orchestration status.

**Version**: 1.0.0
**Author**: Claude-Opus-4.5-20260106
**Created**: 2026-01-06
**Standards**: ASCII Box Drawing, 80-char max width

---

## Template Index

| Template | Purpose | Target Time |
|----------|---------|-------------|
| `SESSION_START` | Initial state when agent begins session | 10s |
| `COMPACT` | Quick check between tasks | 5s |
| `DELEGATION_PRE` | Before delegating to sub-agent | 8s |
| `DELEGATION_POST` | After sub-agent returns | 10s |
| `PRE_COMMIT` | Validation before git commit | 8s |
| `ERROR_DEBUG` | When error or blockage occurs | 15s |
| `SESSION_END` | Handoff when ending session | 20s |
| `FULL_REPORT` | Complete analysis report | 60s |

---

## Design Conventions

### Box Drawing Characters

```
Single line:  ┌─┬─┐  │  ├─┼─┤  └─┴─┘
Double line:  ╔═╦═╗  ║  ╠═╬═╣  ╚═╩═╝
Mixed:        ╒═╤═╕  │  ╞═╪═╡  ╘═╧═╛
Rounded:      ╭─┬─╮  │  ├─┼─┤  ╰─┴─╯
```

### Status Indicators

| Indicator | Meaning | Fallback |
|-----------|---------|----------|
| `[OK]` | Success/Normal | Green |
| `[WARN]` | Warning/Attention | Yellow |
| `[FAIL]` | Error/Critical | Red |
| `[SKIP]` | Skipped/N/A | Gray |
| `[LOCK]` | Protected/Locked | Blue |
| `[BUSY]` | In Progress | Cyan |

### Collapsible Sections

```
[+] Section Title (collapsed - 5 items)
[-] Section Title (expanded)
    └── Content visible here
```

---

## TEMPLATE 1: SESSION_START

**Purpose**: Show initial state when agent begins a session
**Target Time**: 10 seconds
**Trigger**: Agent initialization, session handoff received

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  SESSION START — Status Map                              2026-01-06 12:30:00 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  AGENT ID: Claude-Orch-Prime-20260106-c614                                   ║
║  SESSION:  session_20260106_c614                                             ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  GIT STATUS                                                                  ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Branch:     main                                                    [OK]    ║
║  Clean:      No (3 modified, 2 untracked)                           [WARN]   ║
║  Stash:      0 entries                                               [OK]    ║
║  Remote:     origin/main (up to date)                                [OK]    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ACTIVE SESSIONS                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Orchestrator:   Claude-Orch-Prime-20260106-c614                    [BUSY]   ║
║  Sub-agents:     0 active                                            [OK]    ║
║  Worktrees:      1 (main)                                            [OK]    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PENDING TASKS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  From handoff:   2 tasks received                                            ║
║  Priority HIGH:  1 (Create Status Map templates)                             ║
║  Priority MED:   1 (Review sentinel integration)                             ║
║  Blocked:        0                                                   [OK]    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PROTECTED FILES                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  CLAUDE.md                                                          [LOCK]   ║
║  02_processed_data/roadmap_macro_2027Q3.csv                         [LOCK]   ║
║  .claude/sentinel/config.json                                       [LOCK]   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL HEALTH                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Protocol:       v1.0.0                                              [OK]    ║
║  Last audit:     2026-01-06 12:15:00                                 [OK]    ║
║  Health score:   98/100                                              [OK]    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  SESSION START — Status Map                              {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  AGENT ID: {agent_id}                                                        ║
║  SESSION:  {session_id}                                                      ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  GIT STATUS                                                                  ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Branch:     {branch_name}                                     {branch_status}║
║  Clean:      {clean_status}                                    {clean_indicator}║
║  Stash:      {stash_count} entries                             {stash_status}║
║  Remote:     {remote_status}                                   {remote_indicator}║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ACTIVE SESSIONS                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Orchestrator:   {orch_id}                                     {orch_status} ║
║  Sub-agents:     {subagent_count} active                       {agent_status}║
║  Worktrees:      {worktree_count} ({worktree_list})            {wt_status}   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PENDING TASKS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  From handoff:   {handoff_tasks} tasks received                              ║
║  Priority HIGH:  {high_count} ({high_desc})                                  ║
║  Priority MED:   {med_count} ({med_desc})                                    ║
║  Blocked:        {blocked_count}                               {blocked_status}║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PROTECTED FILES                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  {protected_file_1}                                            {lock_status} ║
║  {protected_file_2}                                            {lock_status} ║
║  {protected_file_3}                                            {lock_status} ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL HEALTH                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Protocol:       {sentinel_version}                            {proto_status}║
║  Last audit:     {last_audit_time}                             {audit_status}║
║  Health score:   {health_score}/100                            {health_indicator}║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `timestamp` | Yes | ISO 8601 datetime |
| `agent_id` | Yes | Current agent identifier |
| `session_id` | Yes | Session file identifier |
| `branch_name` | Yes | Git current branch |
| `clean_status` | Yes | Git working tree status |
| `stash_count` | No | Number of stash entries |
| `remote_status` | Yes | Remote sync status |
| `orch_id` | Yes | Orchestrator agent ID |
| `subagent_count` | Yes | Active sub-agents |
| `worktree_count` | No | Git worktrees count |
| `handoff_tasks` | No | Tasks from previous session |
| `high_count` | No | HIGH priority tasks |
| `blocked_count` | Yes | Blocked tasks |
| `protected_file_*` | No | List of protected files |
| `sentinel_version` | Yes | Sentinel Protocol version |
| `health_score` | Yes | Current health score |

---

## TEMPLATE 2: COMPACT (Quick Check)

**Purpose**: Quick status verification between tasks
**Target Time**: 5 seconds
**Trigger**: Between task completions, periodic check

### Example (Filled)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ QUICK STATUS │ 2026-01-06 12:45:00 │ Claude-Orch-Prime-20260106-c614       │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIT:      main [OK] │ 3M 2U │ ahead 0                                      │
│ AGENTS:   1 active  │ 0 pending │ depth: 1/3                               │
│ SENTINEL: 98/100    │ 0 alerts  │ hooks: enabled                           │
│ NEXT:     Create DELEGATION_PRE template (HIGH)                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Skeleton (Placeholders)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ QUICK STATUS │ {timestamp} │ {agent_id}                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIT:      {branch} {branch_status} │ {modified}M {untracked}U │ ahead {ahead}│
│ AGENTS:   {active} active │ {pending} pending │ depth: {depth}/{max_depth} │
│ SENTINEL: {score}/100 │ {alerts} alerts │ hooks: {hooks_status}            │
│ NEXT:     {next_task} ({priority})                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `timestamp` | Yes | ISO 8601 datetime |
| `agent_id` | Yes | Current agent ID |
| `branch` | Yes | Git branch name |
| `branch_status` | Yes | [OK]/[WARN]/[FAIL] |
| `modified` | Yes | Count modified files |
| `untracked` | Yes | Count untracked files |
| `ahead` | Yes | Commits ahead of remote |
| `active` | Yes | Active sub-agents |
| `pending` | Yes | Pending delegations |
| `depth` | Yes | Current delegation depth |
| `max_depth` | Yes | Max allowed depth (usually 3) |
| `score` | Yes | Sentinel health score |
| `alerts` | Yes | Active alerts count |
| `hooks_status` | Yes | enabled/disabled |
| `next_task` | No | Next task description |
| `priority` | No | HIGH/MED/LOW |

---

## TEMPLATE 3: DELEGATION_PRE

**Purpose**: Validate state before delegating to sub-agent
**Target Time**: 8 seconds
**Trigger**: Before Task tool invocation

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PRE-DELEGATION CHECK                                    2026-01-06 13:00:00 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  TASK DETAILS                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Task ID:        task-003                                                    ║
║  Description:    Review VKS-550 for MVP inclusion criteria                   ║
║  Complexity:     MEDIUM                                                      ║
║  Est. Duration:  45s                                                         ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TARGET AGENT                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Agent Type:     PO (Product Owner)                                          ║
║  Agent ID:       Claude-PO-c614-003                                          ║
║  Depth:          1 → 2 (within limit 3)                              [OK]    ║
║  Specialization: Backlog analysis, MVP criteria                              ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RISK ASSESSMENT                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Loop Risk:      NONE (first delegation of this task)                [OK]    ║
║  Depth Risk:     LOW (2/3 depth)                                     [OK]    ║
║  Scope Risk:     LOW (clear boundaries defined)                      [OK]    ║
║  Time Risk:      NONE (45s well within 5min limit)                   [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DEPENDENCIES                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Required Files: roadmap_macro_2027Q3.csv, riscos_marcos_2027Q3.md           ║
║  Requires Lock:  No                                                  [OK]    ║
║  Blocked By:     None                                                [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL VERDICT                                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    ████████████████████████████████████████  PROCEED                [OK]    ║
║                                                                              ║
║    All checks passed. Delegation approved.                                   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PRE-DELEGATION CHECK                                    {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  TASK DETAILS                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Task ID:        {task_id}                                                   ║
║  Description:    {task_description}                                          ║
║  Complexity:     {complexity}                                                ║
║  Est. Duration:  {est_duration}                                              ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TARGET AGENT                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Agent Type:     {agent_type}                                                ║
║  Agent ID:       {target_agent_id}                                           ║
║  Depth:          {current_depth} → {new_depth} ({depth_assessment})  {depth_status}║
║  Specialization: {agent_specialization}                                      ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RISK ASSESSMENT                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Loop Risk:      {loop_risk} ({loop_details})                        {loop_status}║
║  Depth Risk:     {depth_risk} ({depth_details})                      {depth_indicator}║
║  Scope Risk:     {scope_risk} ({scope_details})                      {scope_status}║
║  Time Risk:      {time_risk} ({time_details})                        {time_status}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DEPENDENCIES                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Required Files: {required_files}                                            ║
║  Requires Lock:  {lock_required}                                     {lock_status}║
║  Blocked By:     {blockers}                                          {block_status}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL VERDICT                                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    {progress_bar}  {verdict}                                         {verdict_status}║
║                                                                              ║
║    {verdict_message}                                                         ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `task_id` | Yes | Unique task identifier |
| `task_description` | Yes | Brief task description (max 60 chars) |
| `complexity` | Yes | LOW/MEDIUM/HIGH/CRITICAL |
| `est_duration` | No | Estimated execution time |
| `agent_type` | Yes | Target agent type (PO, Dev, QA, etc.) |
| `target_agent_id` | Yes | Full agent identifier |
| `current_depth` | Yes | Current delegation depth |
| `new_depth` | Yes | Depth after delegation |
| `loop_risk` | Yes | NONE/LOW/MEDIUM/HIGH |
| `depth_risk` | Yes | NONE/LOW/MEDIUM/HIGH |
| `scope_risk` | Yes | NONE/LOW/MEDIUM/HIGH |
| `time_risk` | Yes | NONE/LOW/MEDIUM/HIGH |
| `required_files` | No | Files needed for task |
| `lock_required` | Yes | Yes/No |
| `blockers` | No | Blocking tasks/issues |
| `verdict` | Yes | PROCEED/CAUTION/BLOCK |
| `verdict_message` | Yes | Human-readable verdict |

---

## TEMPLATE 4: DELEGATION_POST

**Purpose**: Report state after sub-agent returns
**Target Time**: 10 seconds
**Trigger**: After Task tool returns

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  POST-DELEGATION REPORT                                  2026-01-06 13:01:15 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  AGENT RESULT                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Agent ID:       Claude-PO-c614-003                                          ║
║  Task ID:        task-003                                                    ║
║  Status:         COMPLETED                                           [OK]    ║
║  Exit Code:      Success                                                     ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  EXECUTION METRICS                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Duration:       38,450ms (38.5s)                                    [OK]    ║
║  Est. vs Actual: 45s → 38.5s (14% faster)                            [OK]    ║
║  Tokens Used:    2,847 input / 1,523 output                                  ║
║  Tool Calls:     3 (Read: 2, Grep: 1)                                        ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FILES CHANGED                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [M] 03_documents/analise_critica_recursiva_2027Q3.md               [OK]    ║
║  [A] 03_documents/vks550_mvp_assessment_2027Q3.md                   [OK]    ║
║  Total: 1 modified, 1 added, 0 deleted                                       ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  QUALITY ASSESSMENT                                                          ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Task Relevance:  HIGH (output matches task scope)                   [OK]    ║
║  Completeness:    100% (all acceptance criteria met)                 [OK]    ║
║  Naming Conv.:    PASS (ISO 8601 dates, snake_case)                  [OK]    ║
║  Quality Score:   95/100                                             [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL ANALYSIS                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Loop Check:      PASS (no re-delegation detected)                   [OK]    ║
║  Drift Check:     PASS (output relevant to task)                     [OK]    ║
║  Error Check:     PASS (no errors during execution)                  [OK]    ║
║  Anomalies:       0 detected                                         [OK]    ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  POST-DELEGATION REPORT                                  {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  AGENT RESULT                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Agent ID:       {agent_id}                                                  ║
║  Task ID:        {task_id}                                                   ║
║  Status:         {completion_status}                                 {status_indicator}║
║  Exit Code:      {exit_code}                                                 ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  EXECUTION METRICS                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Duration:       {duration_ms}ms ({duration_human})                  {duration_status}║
║  Est. vs Actual: {estimated} → {actual} ({variance})                 {variance_status}║
║  Tokens Used:    {input_tokens} input / {output_tokens} output               ║
║  Tool Calls:     {tool_count} ({tool_breakdown})                             ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  FILES CHANGED                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  {file_change_1}                                                    {file_status_1}║
║  {file_change_2}                                                    {file_status_2}║
║  Total: {modified} modified, {added} added, {deleted} deleted                ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  QUALITY ASSESSMENT                                                          ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Task Relevance:  {relevance_level} ({relevance_note})               {relevance_status}║
║  Completeness:    {completeness_pct}% ({completeness_note})          {complete_status}║
║  Naming Conv.:    {naming_result} ({naming_note})                    {naming_status}║
║  Quality Score:   {quality_score}/100                                {quality_status}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SENTINEL ANALYSIS                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Loop Check:      {loop_result} ({loop_note})                        {loop_status}║
║  Drift Check:     {drift_result} ({drift_note})                      {drift_status}║
║  Error Check:     {error_result} ({error_note})                      {error_status}║
║  Anomalies:       {anomaly_count} detected                           {anomaly_status}║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `agent_id` | Yes | Returning agent identifier |
| `task_id` | Yes | Completed task ID |
| `completion_status` | Yes | COMPLETED/PARTIAL/FAILED |
| `exit_code` | Yes | Success/Error/Timeout |
| `duration_ms` | Yes | Execution time in milliseconds |
| `duration_human` | Yes | Human readable duration |
| `estimated` | No | Estimated duration |
| `actual` | Yes | Actual duration |
| `variance` | No | % faster/slower |
| `input_tokens` | Yes | Input tokens consumed |
| `output_tokens` | Yes | Output tokens generated |
| `tool_count` | Yes | Number of tool calls |
| `tool_breakdown` | No | Summary by tool type |
| `file_change_*` | No | [M]/[A]/[D] + filepath |
| `modified` | Yes | Count modified files |
| `added` | Yes | Count added files |
| `deleted` | Yes | Count deleted files |
| `relevance_level` | Yes | HIGH/MEDIUM/LOW |
| `completeness_pct` | Yes | 0-100 |
| `quality_score` | Yes | 0-100 |
| `loop_result` | Yes | PASS/FAIL |
| `drift_result` | Yes | PASS/WARN/FAIL |
| `anomaly_count` | Yes | Number detected |

---

## TEMPLATE 5: PRE_COMMIT

**Purpose**: Validate state before git commit
**Target Time**: 8 seconds
**Trigger**: Before git commit operation

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PRE-COMMIT VALIDATION                                   2026-01-06 14:30:00 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  FILES TO COMMIT                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  STAGED (4 files):                                                           ║
║    [M] .claude/statusmap/templates/statusmap_templates.md           [OK]    ║
║    [M] 03_documents/analise_critica_recursiva_2027Q3.md             [OK]    ║
║    [A] 03_documents/vks550_mvp_assessment_2027Q3.md                 [OK]    ║
║    [M] README.md                                                    [OK]    ║
║                                                                              ║
║  NOT STAGED (2 files):                                                       ║
║    [M] 01_source_data/jira_export_2025-12-26.csv                   [SKIP]   ║
║    [M] 02_processed_data/roadmap_macro_2027Q3.csv                  [LOCK]   ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONFLICT CHECK                                                              ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Merge conflicts:     None                                           [OK]    ║
║  Rebase in progress:  No                                             [OK]    ║
║  Cherry-pick active:  No                                             [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PROTECTED FILE CHECK                                                        ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  CLAUDE.md:                   Not in staging                         [OK]    ║
║  roadmap_macro_2027Q3.csv:    Not in staging                         [OK]    ║
║  config.json (sentinel):      Not in staging                         [OK]    ║
║                                                                              ║
║  [!] Protected files safe — no unintended changes                    [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOCK STATUS                                                                 ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Active locks:        1                                                      ║
║    → 02_processed_data/roadmap_macro_2027Q3.csv (Source of Truth)   [LOCK]   ║
║  Lock conflicts:      None                                           [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMIT PREVIEW                                                              ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Message:  feat(statusmap): add 8 ASCII status map templates                 ║
║  Author:   Claude-Orch-Prime-20260106-c614                                   ║
║  Files:    4 staged                                                          ║
║  Size:     +847 -12 lines                                                    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  VALIDATION RESULT                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    ████████████████████████████████████████  SAFE TO COMMIT          [OK]    ║
║                                                                              ║
║    All checks passed. Proceed with commit.                                   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PRE-COMMIT VALIDATION                                   {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  FILES TO COMMIT                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  STAGED ({staged_count} files):                                              ║
║    {staged_file_1}                                                  {staged_status_1}║
║    {staged_file_2}                                                  {staged_status_2}║
║    {staged_file_3}                                                  {staged_status_3}║
║                                                                              ║
║  NOT STAGED ({unstaged_count} files):                                        ║
║    {unstaged_file_1}                                                {unstaged_status_1}║
║    {unstaged_file_2}                                                {unstaged_status_2}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONFLICT CHECK                                                              ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Merge conflicts:     {conflict_status}                              {conflict_indicator}║
║  Rebase in progress:  {rebase_status}                                {rebase_indicator}║
║  Cherry-pick active:  {cherrypick_status}                            {cherrypick_indicator}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PROTECTED FILE CHECK                                                        ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  {protected_1}:       {protected_1_status}                           {protected_1_indicator}║
║  {protected_2}:       {protected_2_status}                           {protected_2_indicator}║
║  {protected_3}:       {protected_3_status}                           {protected_3_indicator}║
║                                                                              ║
║  {protected_summary}                                                 {protected_result}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LOCK STATUS                                                                 ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Active locks:        {lock_count}                                           ║
║    → {locked_file} ({lock_reason})                                  {lock_indicator}║
║  Lock conflicts:      {lock_conflict_status}                         {lock_conflict_indicator}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMMIT PREVIEW                                                              ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Message:  {commit_message}                                                  ║
║  Author:   {commit_author}                                                   ║
║  Files:    {file_count} staged                                               ║
║  Size:     +{lines_added} -{lines_removed} lines                             ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  VALIDATION RESULT                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    {progress_bar}  {validation_verdict}                              {verdict_indicator}║
║                                                                              ║
║    {validation_message}                                                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `staged_count` | Yes | Number of staged files |
| `staged_file_*` | Yes | [M]/[A]/[D] + filepath |
| `unstaged_count` | Yes | Number of unstaged files |
| `unstaged_file_*` | No | [M]/[A]/[D] + filepath |
| `conflict_status` | Yes | None/Count |
| `rebase_status` | Yes | Yes/No |
| `cherrypick_status` | Yes | Yes/No |
| `protected_*` | Yes | Protected file status |
| `lock_count` | Yes | Active locks count |
| `locked_file` | No | Locked file path |
| `lock_reason` | No | Why file is locked |
| `lock_conflict_status` | Yes | None/Conflict details |
| `commit_message` | Yes | Proposed commit message |
| `commit_author` | Yes | Agent/User ID |
| `file_count` | Yes | Files to commit |
| `lines_added` | Yes | Lines added |
| `lines_removed` | Yes | Lines removed |
| `validation_verdict` | Yes | SAFE TO COMMIT/CAUTION/BLOCKED |
| `validation_message` | Yes | Human-readable verdict |

---

## TEMPLATE 6: ERROR_DEBUG

**Purpose**: Diagnostic display when error or blockage occurs
**Target Time**: 15 seconds
**Trigger**: Exception, timeout, blocked state

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  ERROR DEBUG — Diagnostic Report                         2026-01-06 15:00:00 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ERROR CLASSIFICATION                                                        ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Type:           LOOP_DETECTED                                      [FAIL]   ║
║  Severity:       HIGH                                                        ║
║  Rule Violated:  RULE-001 (Loop Detection)                                   ║
║  Sentinel Code:  SENTINEL-LOOP-001                                           ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONTEXT                                                                     ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Session:        Claude-Orch-Prime-20260106-c614                             ║
║  Agent:          Claude-Dev-c614-005                                         ║
║  Task:           task-007 (Review code formatting)                           ║
║  Depth:          2/3                                                         ║
║  Time in Task:   127,500ms (2m 7.5s)                                         ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ERROR DETAILS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Message:        Agent attempted to re-delegate same task                    ║
║  Location:       POST_DELEGATE hook                                          ║
║                                                                              ║
║  Delegation Chain:                                                           ║
║    Orch → Dev-005 → Dev-005 (BLOCKED)                                        ║
║           ^^^^^^^^^^^^^^^                                                    ║
║           Task similarity: 0.92 (threshold: 0.85)                            ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LAST ACTIONS (5)                                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [14:57:33] Orch received task-007                                           ║
║  [14:57:34] PRE_DELEGATE: Dev-005 selected                           [OK]    ║
║  [14:57:35] Dev-005 started execution                                        ║
║  [14:59:40] Dev-005 attempted re-delegation                         [FAIL]   ║
║  [14:59:40] SENTINEL blocked: Loop detected                                  ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOVERY OPTIONS                                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  [1] RETRY with different agent                                              ║
║      → Suggest: Claude-QA-c614 for code review                               ║
║                                                                              ║
║  [2] DECOMPOSE task into smaller units                                       ║
║      → Split: formatting check / style validation                            ║
║                                                                              ║
║  [3] EXECUTE directly (no delegation)                                        ║
║      → Orchestrator handles task inline                                      ║
║                                                                              ║
║  [4] ESCALATE to human                                                       ║
║      → Request manual intervention                                           ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOMMENDED ACTION                                                          ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    → Option [1]: RETRY with Claude-QA-c614                                   ║
║                                                                              ║
║    Rationale: QA agent specializes in code review; prevents loop             ║
║    Risk: LOW                                                                 ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  ERROR DEBUG — Diagnostic Report                         {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ERROR CLASSIFICATION                                                        ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Type:           {error_type}                                       {type_indicator}║
║  Severity:       {severity}                                                  ║
║  Rule Violated:  {rule_id} ({rule_name})                                     ║
║  Sentinel Code:  {sentinel_code}                                             ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  CONTEXT                                                                     ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Session:        {session_id}                                                ║
║  Agent:          {agent_id}                                                  ║
║  Task:           {task_id} ({task_brief})                                    ║
║  Depth:          {depth}/{max_depth}                                         ║
║  Time in Task:   {task_time_ms}ms ({task_time_human})                        ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ERROR DETAILS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Message:        {error_message}                                             ║
║  Location:       {error_location}                                            ║
║                                                                              ║
║  {error_visual_context}                                                      ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LAST ACTIONS ({action_count})                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [{action_1_time}] {action_1_desc}                                   {action_1_status}║
║  [{action_2_time}] {action_2_desc}                                   {action_2_status}║
║  [{action_3_time}] {action_3_desc}                                   {action_3_status}║
║  [{action_4_time}] {action_4_desc}                                   {action_4_status}║
║  [{action_5_time}] {action_5_desc}                                   {action_5_status}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOVERY OPTIONS                                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  [1] {recovery_option_1_title}                                               ║
║      → {recovery_option_1_detail}                                            ║
║                                                                              ║
║  [2] {recovery_option_2_title}                                               ║
║      → {recovery_option_2_detail}                                            ║
║                                                                              ║
║  [3] {recovery_option_3_title}                                               ║
║      → {recovery_option_3_detail}                                            ║
║                                                                              ║
║  [4] {recovery_option_4_title}                                               ║
║      → {recovery_option_4_detail}                                            ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOMMENDED ACTION                                                          ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║    → Option [{recommended_option}]: {recommended_action}                     ║
║                                                                              ║
║    Rationale: {recommendation_rationale}                                     ║
║    Risk: {recommendation_risk}                                               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `error_type` | Yes | LOOP_DETECTED, TIMEOUT, DEPTH_EXCEEDED, etc. |
| `severity` | Yes | HIGH/MEDIUM/LOW |
| `rule_id` | Yes | Violated rule identifier |
| `rule_name` | Yes | Human-readable rule name |
| `sentinel_code` | Yes | Sentinel error code |
| `session_id` | Yes | Current session |
| `agent_id` | Yes | Agent that errored |
| `task_id` | Yes | Task being executed |
| `task_brief` | No | Brief task description |
| `depth` | Yes | Current delegation depth |
| `task_time_ms` | Yes | Time spent in task |
| `error_message` | Yes | Error description |
| `error_location` | Yes | Where error occurred |
| `error_visual_context` | No | Visual representation of error |
| `action_*_time` | Yes | Timestamp of action |
| `action_*_desc` | Yes | Action description |
| `recovery_option_*` | Yes | Recovery options (min 2) |
| `recommended_option` | Yes | Recommended recovery number |
| `recommended_action` | Yes | Recommended action title |
| `recommendation_rationale` | Yes | Why this is recommended |
| `recommendation_risk` | Yes | Risk level of recommendation |

---

## TEMPLATE 7: SESSION_END

**Purpose**: Handoff report when ending session
**Target Time**: 20 seconds
**Trigger**: Session termination, handoff request

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  SESSION END — Handoff Report                            2026-01-06 18:00:00 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  SESSION SUMMARY                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Session ID:     Claude-Orch-Prime-20260106-c614                             ║
║  Started:        2026-01-06 12:30:00                                         ║
║  Duration:       5h 30m                                                      ║
║  Health Score:   94/100                                              [OK]    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TASK METRICS                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Tasks Received:    8                                                        ║
║  Tasks Completed:   7                                                [OK]    ║
║  Tasks Partial:     1                                               [WARN]   ║
║  Tasks Failed:      0                                                [OK]    ║
║  Delegations:       12 (depth max: 2)                                        ║
║  Total Tokens:      45,320 in / 28,450 out                                   ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DELIVERABLES                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [+] Files Created (4)                                                       ║
║      .claude/statusmap/templates/statusmap_templates.md                      ║
║      03_documents/vks550_mvp_assessment_2027Q3.md                            ║
║      03_documents/analise_folga_expansao_2027Q3.md                           ║
║      09_notebooklm/input/backlog_executivo_2027Q3.md                         ║
║                                                                              ║
║  [+] Files Modified (6)                                                      ║
║      README.md                                                               ║
║      03_documents/analise_critica_recursiva_2027Q3.md                        ║
║      09_notebooklm/input/notebooklm_narrative_2027Q3.md                      ║
║      ... (3 more)                                                            ║
║                                                                              ║
║  [+] Commits Made (2)                                                        ║
║      a1b2c3d feat(statusmap): add 8 ASCII status map templates               ║
║      e4f5g6h docs: update recursive analysis with VKS-550                    ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PENDING ITEMS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  [!] PARTIAL: Sentinel integration test                             [WARN]   ║
║      Status:  80% complete                                                   ║
║      Blocker: Needs real multi-agent session to validate                     ║
║      Next:    Run `/audit session` after next complex delegation             ║
║                                                                              ║
║  [i] DEFERRED: NotebookLM video generation                          [SKIP]   ║
║      Reason:  Requires external tool (NotebookLM)                            ║
║      Action:  User to upload to NotebookLM manually                          ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  GIT STATUS AT END                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Branch:          main                                               [OK]    ║
║  Uncommitted:     0                                                  [OK]    ║
║  Ahead of remote: 2 commits                                         [WARN]   ║
║  Stash:           0 entries                                          [OK]    ║
║                                                                              ║
║  [!] Note: 2 commits not pushed. Run `git push` before handoff.              ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOMMENDATIONS FOR NEXT SESSION                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  1. Push pending commits to remote                                           ║
║     → `git push origin main`                                                 ║
║                                                                              ║
║  2. Complete Sentinel integration test                                       ║
║     → Run `/audit session` after next multi-agent task                       ║
║                                                                              ║
║  3. Review VKS-550 assessment with PO                                        ║
║     → File: 03_documents/vks550_mvp_assessment_2027Q3.md                     ║
║                                                                              ║
║  4. Consider increasing Sentinel health score threshold                      ║
║     → Current: 70 | Suggested: 80                                            ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  HANDOFF CHECKLIST                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [x] All critical tasks completed                                            ║
║  [x] Audit log written                                                       ║
║  [x] Session traces persisted                                                ║
║  [ ] Commits pushed to remote                                                ║
║  [x] Pending items documented                                                ║
║  [x] Recommendations provided                                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton (Placeholders)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  SESSION END — Handoff Report                            {timestamp}         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  SESSION SUMMARY                                                             ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Session ID:     {session_id}                                                ║
║  Started:        {start_time}                                                ║
║  Duration:       {duration}                                                  ║
║  Health Score:   {health_score}/100                                  {health_indicator}║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  TASK METRICS                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Tasks Received:    {tasks_received}                                         ║
║  Tasks Completed:   {tasks_completed}                                {complete_indicator}║
║  Tasks Partial:     {tasks_partial}                                  {partial_indicator}║
║  Tasks Failed:      {tasks_failed}                                   {failed_indicator}║
║  Delegations:       {delegations} (depth max: {max_depth_used})              ║
║  Total Tokens:      {tokens_in} in / {tokens_out} out                        ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DELIVERABLES                                                                ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [+] Files Created ({created_count})                                         ║
║      {created_file_1}                                                        ║
║      {created_file_2}                                                        ║
║                                                                              ║
║  [+] Files Modified ({modified_count})                                       ║
║      {modified_file_1}                                                       ║
║      {modified_file_2}                                                       ║
║                                                                              ║
║  [+] Commits Made ({commit_count})                                           ║
║      {commit_1_hash} {commit_1_message}                                      ║
║      {commit_2_hash} {commit_2_message}                                      ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PENDING ITEMS                                                               ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  [!] {pending_type_1}: {pending_title_1}                             {pending_status_1}║
║      Status:  {pending_progress_1}                                           ║
║      Blocker: {pending_blocker_1}                                            ║
║      Next:    {pending_next_action_1}                                        ║
║                                                                              ║
║  [i] {pending_type_2}: {pending_title_2}                             {pending_status_2}║
║      Reason:  {pending_reason_2}                                             ║
║      Action:  {pending_action_2}                                             ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  GIT STATUS AT END                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  Branch:          {branch}                                           {branch_status}║
║  Uncommitted:     {uncommitted_count}                                {uncommitted_status}║
║  Ahead of remote: {ahead_count} commits                              {ahead_status}║
║  Stash:           {stash_count} entries                              {stash_status}║
║                                                                              ║
║  {git_note}                                                                  ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECOMMENDATIONS FOR NEXT SESSION                                            ║
╟──────────────────────────────────────────────────────────────────────────────╢
║                                                                              ║
║  1. {recommendation_1_title}                                                 ║
║     → {recommendation_1_detail}                                              ║
║                                                                              ║
║  2. {recommendation_2_title}                                                 ║
║     → {recommendation_2_detail}                                              ║
║                                                                              ║
║  3. {recommendation_3_title}                                                 ║
║     → {recommendation_3_detail}                                              ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  HANDOFF CHECKLIST                                                           ║
╟──────────────────────────────────────────────────────────────────────────────╢
║  [{check_1}] {checklist_item_1}                                              ║
║  [{check_2}] {checklist_item_2}                                              ║
║  [{check_3}] {checklist_item_3}                                              ║
║  [{check_4}] {checklist_item_4}                                              ║
║  [{check_5}] {checklist_item_5}                                              ║
║  [{check_6}] {checklist_item_6}                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `session_id` | Yes | Session identifier |
| `start_time` | Yes | Session start timestamp |
| `duration` | Yes | Total session duration |
| `health_score` | Yes | Final health score |
| `tasks_received` | Yes | Total tasks received |
| `tasks_completed` | Yes | Successfully completed |
| `tasks_partial` | Yes | Partially completed |
| `tasks_failed` | Yes | Failed tasks |
| `delegations` | Yes | Total delegations made |
| `max_depth_used` | Yes | Maximum depth reached |
| `tokens_in` | Yes | Total input tokens |
| `tokens_out` | Yes | Total output tokens |
| `created_count` | Yes | Files created count |
| `created_file_*` | No | Created file paths |
| `modified_count` | Yes | Files modified count |
| `modified_file_*` | No | Modified file paths |
| `commit_count` | Yes | Commits made |
| `commit_*_hash` | No | Commit short hash |
| `commit_*_message` | No | Commit message |
| `pending_*` | No | Pending item details |
| `branch` | Yes | Current branch |
| `uncommitted_count` | Yes | Uncommitted changes |
| `ahead_count` | Yes | Commits ahead of remote |
| `stash_count` | Yes | Stash entries |
| `recommendation_*` | Yes | Min 2 recommendations |
| `check_*` | Yes | x/space for checklist |
| `checklist_item_*` | Yes | Checklist item text |

---

## TEMPLATE 8: FULL_REPORT

**Purpose**: Comprehensive analysis report for deep review
**Target Time**: 60 seconds
**Trigger**: End of major milestone, audit request, stakeholder review

### Example (Filled)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                         FULL STATUS REPORT                                   ║
║                                                                              ║
║                   VKS_Apresentacao_CEO_2027Q3                                ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Generated:      2026-01-06 18:00:00                                         ║
║  Report Version: 1.0.0                                                       ║
║  Session ID:     Claude-Orch-Prime-20260106-c614                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 1: EXECUTIVE SUMMARY                                                │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────┬────────────────────────────────────┐
│  HEALTH SCORE                           │  SESSION METRICS                   │
├─────────────────────────────────────────┼────────────────────────────────────┤
│                                         │                                    │
│    ████████████████████░░░░  94/100     │  Duration:      5h 30m             │
│                                         │  Tasks:         7/8 completed      │
│    Status: EXCELLENT                    │  Delegations:   12                 │
│                                         │  Anomalies:     1 (resolved)       │
│                                         │  Tokens:        73,770 total       │
│                                         │                                    │
└─────────────────────────────────────────┴────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 2: GIT REPOSITORY STATUS                                            │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Branch Information                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  Current Branch:     main                                            [OK]   │
│  Remote Tracking:    origin/main                                     [OK]   │
│  Ahead:              2 commits                                      [WARN]  │
│  Behind:             0 commits                                       [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Working Tree Status                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  Clean:              Yes                                             [OK]   │
│  Staged:             0 files                                                │
│  Modified:           0 files                                                │
│  Untracked:          0 files                                                │
│  Stash:              0 entries                                       [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Recent Commits (Last 5)                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  e4f5g6h  2026-01-06 17:45  docs: update recursive analysis with VKS-550   │
│  a1b2c3d  2026-01-06 15:30  feat(statusmap): add 8 ASCII status map templ  │
│  7656d9b  2026-01-06 10:00  refactor(notebooklm): harmonize dates to ISO   │
│  2b3a45c  2026-01-05 22:00  refactor(harmonization): apply ISO 8601 dates  │
│  d48bd1e  2026-01-05 20:00  feat(harmonization): add validation report     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Worktrees                                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  main (current):     /Users/.../VKS_Apresentacao_CEO_2027Q3          [OK]   │
│  Active worktrees:   1                                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 3: AGENT ORCHESTRATION                                              │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Active Agents                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Orchestrator:       Claude-Orch-Prime-20260106-c614                [BUSY]  │
│  Sub-agents active:  0                                               [OK]   │
│  Sub-agents spawned: 5 (session total)                                      │
│  Max depth reached:  2/3                                             [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Agent Activity Summary                                                     │
├───────────────────────────┬───────┬─────────┬────────┬──────────────────────┤
│  Agent                    │ Tasks │ Success │ Errors │ Avg Duration         │
├───────────────────────────┼───────┼─────────┼────────┼──────────────────────┤
│  Orch-Prime-c614          │   8   │  100%   │   0    │ N/A (coordinator)    │
│  PO-c614-001              │   2   │  100%   │   0    │ 42s                  │
│  Dev-c614-002             │   3   │  100%   │   0    │ 58s                  │
│  Editor-c614-003          │   4   │  100%   │   0    │ 25s                  │
│  QA-c614-004              │   1   │  100%   │   0    │ 35s                  │
│  Dev-c614-005             │   1   │   0%    │   1    │ 127s (blocked)       │
└───────────────────────────┴───────┴─────────┴────────┴──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Delegation Flow (Mermaid)                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    Orch-Prime-c614                                                          │
│         │                                                                   │
│         ├──► PO-c614-001 (tasks 1, 3)                                       │
│         │                                                                   │
│         ├──► Dev-c614-002 (tasks 2, 5, 6)                                   │
│         │         └──► Editor-c614-003 (task 2.1)                           │
│         │                                                                   │
│         ├──► Editor-c614-003 (tasks 4, 7, 8)                                │
│         │                                                                   │
│         ├──► QA-c614-004 (task 7)                                           │
│         │                                                                   │
│         └──► Dev-c614-005 (task 7) [BLOCKED - Loop]                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 4: SENTINEL PROTOCOL                                                │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Protocol Status                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Version:            v1.0.0                                          [OK]   │
│  Hooks Enabled:      Yes                                             [OK]   │
│  Enforcement Mode:   Soft                                                   │
│  Last Health Check:  2026-01-06 17:55:00                             [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Detection Rules Status                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  RULE-001 Loop Detection:        ACTIVE   │ Triggered: 1                    │
│  RULE-002 Depth Violation:       ACTIVE   │ Triggered: 0                    │
│  RULE-003 Task Drift:            ACTIVE   │ Triggered: 0                    │
│  RULE-004 Error Cascade:         ACTIVE   │ Triggered: 0                    │
│  RULE-005 Stagnation:            ACTIVE   │ Triggered: 0                    │
│  RULE-006 Agent Mismatch:        ACTIVE   │ Triggered: 0                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Anomaly Log                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  # │ Time       │ Agent        │ Rule     │ Severity │ Status              │
├───┼────────────┼──────────────┼──────────┼──────────┼─────────────────────┤
│  1 │ 14:59:40   │ Dev-c614-005 │ RULE-001 │ HIGH     │ RESOLVED (retry)    │
└───┴────────────┴──────────────┴──────────┴──────────┴─────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Health Score Breakdown                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  Base Score:                                             100                │
│  ─────────────────────────────────────────────────────────────              │
│  (+) Clean delegations (11):                              +22               │
│  (+) Fast executions (8):                                  +8               │
│  (+) Successful recovery (1):                              +5               │
│  (-) Loop detected (1):                                   -20               │
│  (-) Stagnation (2m+ task):                               -5                │
│  ─────────────────────────────────────────────────────────────              │
│  Adjustments:                                            +10                │
│  ─────────────────────────────────────────────────────────────              │
│  Calculated:                                             110                │
│  Final (capped):                                          94                │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 5: TASK TRACKING                                                    │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Task Summary                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  Total Received:     8                                                      │
│  Completed:          7 (87.5%)                                       [OK]   │
│  Partial:            1 (12.5%)                                      [WARN]  │
│  Failed:             0 (0%)                                          [OK]   │
│  Blocked:            0                                               [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Task Details                                                               │
├───┬────────────────────────────────────────────────┬──────────┬─────────────┤
│ # │ Task                                           │ Status   │ Duration    │
├───┼────────────────────────────────────────────────┼──────────┼─────────────┤
│ 1 │ Create Status Map templates                    │ COMPLETE │ 45m         │
│ 2 │ Review VKS-550 MVP inclusion                   │ COMPLETE │ 38s         │
│ 3 │ Update recursive analysis                      │ COMPLETE │ 42s         │
│ 4 │ Harmonize NotebookLM inputs                    │ COMPLETE │ 15m         │
│ 5 │ Create backlog executivo markdown              │ COMPLETE │ 28s         │
│ 6 │ Validate dependency edges                      │ COMPLETE │ 35s         │
│ 7 │ Run Sentinel integration test                  │ PARTIAL  │ --          │
│ 8 │ Generate session handoff report                │ COMPLETE │ 20s         │
└───┴────────────────────────────────────────────────┴──────────┴─────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 6: PROTECTED FILES                                                  │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Protected File Status                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  File                                       │ Status   │ Last Modified      │
├─────────────────────────────────────────────┼──────────┼────────────────────┤
│  CLAUDE.md                                  │ [LOCK]   │ 2026-01-05 22:00   │
│  02_processed_data/roadmap_macro_2027Q3.csv │ [LOCK]   │ 2026-01-05 20:00   │
│  .claude/sentinel/config.json               │ [LOCK]   │ 2026-01-06 10:00   │
│  _deprecated/* (audit only)                 │ [LOCK]   │ N/A                │
└─────────────────────────────────────────────┴──────────┴────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Access Attempts                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Read attempts:      12 (all authorized)                             [OK]   │
│  Write attempts:     0                                               [OK]   │
│  Blocked attempts:   0                                               [OK]   │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 7: RESOURCE CONSUMPTION                                             │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Token Usage                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input Tokens:       45,320                                                 │
│  Output Tokens:      28,450                                                 │
│  Total:              73,770                                                 │
│  ─────────────────────────────────────────────────────────────              │
│  By Agent:                                                                  │
│    Orch-Prime-c614:  35,000 (47%)                                           │
│    Dev agents:       22,000 (30%)                                           │
│    PO/QA agents:     10,000 (14%)                                           │
│    Editor agents:     6,770 (9%)                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Tool Calls                                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  Total Calls:        87                                                     │
│  ─────────────────────────────────────────────────────────────              │
│  Read:               34 (39%)                                               │
│  Write:               8 (9%)                                                │
│  Edit:               12 (14%)                                               │
│  Bash:               15 (17%)                                               │
│  Grep:                9 (10%)                                               │
│  Glob:                6 (7%)                                                │
│  Task:                3 (3%)                                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Time Distribution                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  Total Session:      5h 30m (330m)                                          │
│  ─────────────────────────────────────────────────────────────              │
│  Active execution:   2h 15m (68%)                                           │
│  Waiting (user):     2h 45m (28%)                                           │
│  Tool latency:       30m (9%)                                               │
│  ─────────────────────────────────────────────────────────────              │
│  Avg task time:      18.5m                                                  │
│  Fastest task:       20s (task 8)                                           │
│  Slowest task:       45m (task 1)                                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 8: RECOMMENDATIONS                                                  │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Immediate Actions                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [1] Push commits to remote                                                 │
│      Priority: HIGH                                                         │
│      Command:  git push origin main                                         │
│      Reason:   2 commits not synced; risk of work loss                      │
│                                                                             │
│  [2] Complete Sentinel integration test                                     │
│      Priority: MEDIUM                                                       │
│      Action:   Run /audit session after next multi-agent task               │
│      Reason:   Validate real-world hook execution                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Process Improvements                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [3] Increase health score threshold                                        │
│      Current:  70 (acceptable)                                              │
│      Suggest:  80 (good)                                                    │
│      Reason:   Higher baseline ensures better session quality               │
│                                                                             │
│  [4] Add Dev agent loop prevention context                                  │
│      Issue:    Dev-c614-005 attempted self-delegation                       │
│      Fix:      Include anti-loop instruction in Dev context prep            │
│      File:     .claude/skills/context-prep.md                               │
│                                                                             │
│  [5] Document Status Map usage patterns                                     │
│      Action:   Create usage guide for templates                             │
│      Location: .claude/statusmap/README.md                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Future Enhancements                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [6] Implement automatic Status Map generation                              │
│      Scope:    Create /status skill to render maps on demand                │
│      Benefit:  Faster observability, consistent formatting                  │
│                                                                             │
│  [7] Add Slack alert integration                                            │
│      Scope:    Configure webhook for HIGH severity anomalies                │
│      Config:   .claude/sentinel/config.json                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                           END OF FULL REPORT                                 ║
║                                                                              ║
║  Report ID:      RPT-20260106-c614-001                                       ║
║  Generated by:   Claude-Orch-Prime-20260106-c614                             ║
║  Timestamp:      2026-01-06 18:00:00 -03:00                                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Skeleton Structure

The FULL_REPORT template is modular. Each section can be generated independently:

```
FULL_REPORT Structure:
├── Header (Project name, timestamp, session ID)
├── Section 1: Executive Summary
│   ├── Health Score visual
│   └── Session Metrics summary
├── Section 2: Git Repository Status
│   ├── Branch Information
│   ├── Working Tree Status
│   ├── Recent Commits
│   └── Worktrees
├── Section 3: Agent Orchestration
│   ├── Active Agents
│   ├── Agent Activity Summary (table)
│   └── Delegation Flow (visual)
├── Section 4: Sentinel Protocol
│   ├── Protocol Status
│   ├── Detection Rules Status
│   ├── Anomaly Log
│   └── Health Score Breakdown
├── Section 5: Task Tracking
│   ├── Task Summary
│   └── Task Details (table)
├── Section 6: Protected Files
│   ├── Protected File Status
│   └── Access Attempts
├── Section 7: Resource Consumption
│   ├── Token Usage
│   ├── Tool Calls
│   └── Time Distribution
├── Section 8: Recommendations
│   ├── Immediate Actions
│   ├── Process Improvements
│   └── Future Enhancements
└── Footer (Report ID, generator, timestamp)
```

### Field Reference (Key Fields Only)

| Section | Key Fields | Required |
|---------|------------|----------|
| Header | project_name, timestamp, session_id | Yes |
| Exec Summary | health_score, duration, tasks_ratio, delegations, anomalies, tokens | Yes |
| Git | branch, ahead, behind, clean, staged, modified, untracked, commits | Yes |
| Agents | orch_id, subagents_active, subagents_spawned, max_depth, agent_table | Yes |
| Sentinel | version, hooks_enabled, mode, rules_status, anomaly_log, score_breakdown | Yes |
| Tasks | total, completed, partial, failed, blocked, task_table | Yes |
| Protected | file_list, access_attempts | Yes |
| Resources | tokens_in, tokens_out, tool_calls, time_distribution | Yes |
| Recommendations | immediate, improvements, future | Yes |

---

## Usage Guidelines

### When to Use Each Template

| Scenario | Template | Why |
|----------|----------|-----|
| Starting work | SESSION_START | Establish baseline state |
| Between tasks | COMPACT | Quick sanity check |
| Before delegating | DELEGATION_PRE | Validate safety |
| After delegation returns | DELEGATION_POST | Verify quality |
| Before git commit | PRE_COMMIT | Prevent accidents |
| Error occurs | ERROR_DEBUG | Diagnose and recover |
| Ending session | SESSION_END | Clean handoff |
| Milestone review | FULL_REPORT | Deep analysis |

### Rendering Tips

1. **Terminal Compatibility**: All templates fit 80-char width
2. **Copy/Paste**: Templates render correctly in most terminals
3. **Monospace Required**: Use fixed-width fonts for proper alignment
4. **Indicators**: If terminal doesn't support Unicode, use fallback text indicators

### Integration with Sentinel

Templates can be auto-populated from Sentinel audit logs:

```
/audit session --format statusmap:SESSION_END
/audit health --format statusmap:COMPACT
/audit anomalies --format statusmap:ERROR_DEBUG
```

---

## Changelog

### v1.0.0 (2026-01-06)
- Initial release with 8 templates
- SESSION_START, COMPACT, DELEGATION_PRE, DELEGATION_POST
- PRE_COMMIT, ERROR_DEBUG, SESSION_END, FULL_REPORT
- Field reference documentation
- Design conventions established

---

*Status Map Templates v1.0.0 | Claude-Opus-4.5-20260106 | 2026-01-06*
