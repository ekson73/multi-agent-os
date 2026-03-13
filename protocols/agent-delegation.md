# Agent Delegation Protocol

> When facing a problem, the first question is: "Who is the BEST agent for this?"
> Not who CAN solve it, but who is OPTIMAL for solving it.

## Fundamental Principle

An agent that solves everything is an agent optimized for nothing.
Precise delegation is not weakness — it is systemic intelligence.

## Delegation Chain (Decision Flow)

```
PROBLEM DETECTED
  ↓
"Who is the best agent/role/professional for this?"
  ↓
[Known agent exists in registry?]
  → YES: Delegate → Resolve → Done
  → NO:
      ↓
    [Forge available?]
      → YES: Delegate to Forge to create specialized agent
              → New agent created → Delegate → Resolve → Done
      → NO:
          ↓
        Bootstrap Forge (see agents/forge.md §Bootstrap Protocol)
          → Forge created → Forge creates agent → Problem resolved → Done

[No agent can resolve? (final fallback)]
  → ESCALATE to user with full context:
      1. What was attempted (agents, approaches)
      2. Why it failed (technical limitation, scope, ambiguity)
      3. Options identified (even if partial)
  → Do NOT invent a solution. Do NOT silence failure. Escalation is valid.
```

## When to Delegate vs. Resolve Directly

```
RESOLVE DIRECTLY (no delegation):
  ✓ Problem within clear scope of current agent
  ✓ Obvious solution in <15 min
  ✓ Does not require specialized expertise
  ✓ Successfully done before

DELEGATE:
  → Problem requires expertise the current agent lacks
  → Solution would involve 30+ min research outside scope
  → A clearly more qualified agent exists
  → Problem requires different perspective (avoid cognitive biases)
  → Specialized domain: fiscal, medical, legal, security, etc.
  → Architectural decision with broad systemic impact
```

## Delegation Context Format

The receiving agent NEEDS complete context. Always provide:

```
1. CONTEXT: What was done so far, current state
2. OBJECTIVE: What needs to be achieved (outcome, not task)
3. CONSTRAINTS: What CANNOT be done, limits, boundaries
4. EXPECTED OUTPUT: Format, detail level, deliverables
5. PRIORITY: P0/P1/P2, current session or can be deferred
```

## Escalation Protocol (Fallback to User)

When no agent — existing or newly created — can solve the problem:

```
ESCALATE with:
  1. What was attempted (agents used, approaches tried)
  2. Why it failed (technical limitation, scope gap, ambiguity)
  3. Options identified (even partial ones)
  4. Recommended next steps (even if uncertain)

Do NOT:
  - Invent a solution you're not confident about
  - Silence the failure
  - Claim partial success when the core problem is unresolved
```

## Anti-Patterns

```
X  "I'll solve it myself because it's faster"
   → It's not faster if you're not the right agent. It's EASIER, not FASTER.
   → Immediate ease = systemic inefficiency.

X  Creating a new agent for every small problem
   → First ask: "does an existing agent serve?"
   → Agent proliferation is the new technical debt.

X  Creating task-specific disposable agents
   → Agents named by task ID ("P0-1 fixer") are COSTS, not ASSETS.
   → Create agents by market ROLE (DBA, QA, DEV-BE) that solve this AND future tasks.

X  Delegating without sufficient context
   → An agent without context will make wrong decisions.
   → Cost: rework + loss of systemic coherence.

X  Delegating and forgetting (no tracking)
   → Every delegation needs traceability: ticket, memory note, or PR comment.

X  Resolving specialized domains directly without delegating
   → Fiscal, legal, security, medical: always seek an agent with expertise.
   → Consequences of errors in these domains are P0.
```

## Integration

- **Forge** (agents/forge.md): activated when no existing agent serves the task
- **RBAD** (protocols/rbad.md): design framework Forge applies when creating agents
- **Exit Hygiene** (protocols/exit-hygiene.md): verify delegations have traceability at session end
- **Action Priority** (protocols/action-priority.md): classify urgency before delegating

---

*MAOS Agent Delegation Protocol v1.0.0 | 2026-03-13*
