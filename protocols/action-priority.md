# Action Priority Protocol

> "Do not postpone what can be done now."
> "But do not do now what should never be done."

## Fundamental Principle

```
Immediate action without filter is impulsiveness.
Filter without action is procrastination in disguise.
This protocol = Action + Filter. Together. Always.

CYCLE: Detected task → Classify (Eisenhower) → Check dependencies →
       Do | Schedule | Delegate | Eliminate
```

## Eisenhower Matrix

```
                    URGENT              NOT URGENT
               ┌─────────────────┬─────────────────────┐
   IMPORTANT   │   Q1: DO NOW    │   Q2: SCHEDULE      │
               │                 │   with timebox       │
               │  → Execute      │  → Reserve slot      │
               │  → No delay     │  → If postponed 2x,  │
               │  → Blocks       │    promote to Q1     │
               │    everything   │                      │
               ├─────────────────┼─────────────────────┤
  NOT          │   Q3: DELEGATE  │   Q4: ELIMINATE      │
  IMPORTANT    │                 │   from queue         │
               │  → Don't do it  │  → Discard           │
               │  → Delegate     │  → If can't          │
               │  → If can't     │    eliminate, Q3     │
               │    delegate: Q2 │                      │
               └─────────────────┴─────────────────────┘
```

### Action by Quadrant

| Quadrant | Label | Action |
|----------|-------|--------|
| Q1 | Urgent + Important | Do now. Block everything else. |
| Q2 | Not urgent + Important | Schedule timebox. Protect from false urgency. |
| Q3 | Urgent + Not important | Delegate. If impossible, minimize and schedule. |
| Q4 | Not urgent + Not important | Eliminate. Does not enter the queue. |

## Interdependency Matrix

After classifying by Eisenhower, check dependencies:

```
CURRENT TASK
  ↓
[Blocks other tasks?]
  → YES: Priority INCREASES (resolve now — unblocks the flow)
  → NO: continue

[Blocked by another task?]
  → YES: Park it. Go resolve the blocker first.
  → NO: continue

[Parallel (independent)?]
  → YES: Can parallelize via agents or sequence by Eisenhower
  → NO: check for deadlock

[Circular dependency (deadlock)?]
  → Escalate to user. Do not invent solution alone.
```

### Dependency Types

| Type | Symbol | Action |
|------|--------|--------|
| Blocks others | `→` | Resolve FIRST (value multiplier) |
| Blocked by another | `←` | Park. Resolve the blocker. |
| Parallel | `‖` | Parallelize or sequence by Q |
| Circular | `↺` | Escalate to user |

## Tiebreaker Rule

When two tasks have the same Q and same dependency position:

```
1. Oldest in queue → higher priority
2. Lower context-switching cost → preferred
3. Higher number of dependents → preferred
4. If still tied → arbitrary choice + document
```

## Escape Hatch (When Uncertain)

```
UNCERTAIN ABOUT CLASSIFICATION?
  → Ask: "If I do this now, does the flow advance or stop?"
      → Advances: do it
      → Stops/neutral: classify as Q2 and schedule

UNCERTAIN ABOUT DEPENDENCY?
  → Assume independent. Execute. Adjust if necessary.

UNCERTAIN ABOUT EVERYTHING?
  → Act on the most visible Q1 task.
  → If no Q1 visible: act on the oldest open task.
  → NEVER stay idle due to classification uncertainty.
```

## Timebox for Q2 (Anti-Chronic-Postponement)

```
Q2 TIMEBOX RULE:
  - Every work session MUST have >= 1 Q2 slot
  - If a Q2 task is postponed for 2 consecutive sessions:
      → Promote to Q1 (became important AND urgent by postponement)
  - If a Q2 task never enters a timebox:
      → It's procrastination disguised as "not urgent"
```

## Anti-Patterns

```
X  Urgency bias: treating Q3 as Q1 because it SEEMS urgent
   → Ask: "Important for WHOM?" If not for the main objective,
     it's Q3. Delegate.

X  Analysis paralysis: classifying more than acting
   → This protocol is for quick decisions, not alignment meetings.
     If classification takes >30s, use the Escape Hatch.

X  "False zen": postponing with excuse of "not a priority now"
   → Procrastination with Eisenhower vocabulary is still procrastination.
     If the task is never a priority, eliminate it (Q4) or accept it's chronic Q2.

X  Eternal Q2: important tasks that never become urgent, so never get done
   → Apply Timebox Q2. If necessary, artificially promote to Q1.

X  Doing Q4 because it's "easy and fast"
   → "Easy and fast" is not an Eisenhower criterion. If not important,
     don't do it — even if it takes 30 seconds.

X  Ignoring dependencies and blocking the team's flow
   → Always check: "what am I blocking?" before starting.
```

## Integration

- **Exit Hygiene** (protocols/exit-hygiene.md): at session end, check Q2 tasks for next session
- **Agent Delegation** (protocols/agent-delegation.md): Q3 tasks → delegate to best agent

---

*MAOS Action Priority Protocol v1.0.0 | 2026-03-13 | Based on Eisenhower Matrix*
