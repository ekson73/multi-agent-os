# RBAD — Role-Based Agent Design

> Specific enough to FIT in an atomic scope (profession, area, role, persona).
> Generic enough to be REUSED for any task within that scope.

## Goldilocks Principle (Golden Rule)

```
A reusable agent is an ASSET.
A disposable agent is a COST.

Forge creates ASSETS, not costs.
```

## Atomicity Principle

```
ATOM = smallest indivisible unit that still has coherent identity.

An atomic agent:
  ✓ Has a name any professional recognizes (PM, DBA, QA, Auditor)
  ✓ Can receive ANY task within its scope and know what to do
  ✓ Does not need another agent to complete tasks in its domain
  ✓ Persists across sessions — is discovered, not recreated

A NON-atomic agent (anti-pattern):
  ✗ Name only makes sense for ONE task ("P0-1 fixer")
  ✗ Can only do exactly what it was created for
  ✗ Discarded after use — creation cost > value delivered
  ✗ Proliferates: each new task = new agent = technical debt
```

## Taxonomy — 6 Categories of Valid Agents

### Category 1: IT Roles (Industry Standard)

Standard software industry roles. Scope defined by function in the SDLC.

| Role | Abbreviation | Atomic Scope |
|------|-------------|--------------|
| Product Manager | PM | Product vision, roadmap, prioritization, PRDs |
| Product Owner | PO | Backlog, user stories, acceptance criteria |
| Scrum Master | SM | Agile process, ceremonies, impediments |
| Business Analyst | BA | Business requirements, gap analysis, BRDs |
| Software Architect | ARCH | ADRs, C4, technical decisions, trade-offs |
| Backend Developer | DEV-BE | APIs, business logic, server-side |
| Frontend Developer | DEV-FE | UI/UX implementation, components, SPA |
| DBA | DBA | Schema, migrations, queries, performance |
| DevOps Engineer | DEVOPS | CI/CD, infrastructure, containers, pipelines |
| QA Engineer | QA | Test plans, test cases, test automation |
| Security Engineer | SEC | OWASP, pentest, authentication, encryption |
| Code Reviewer | REVIEWER | Code review, standards, best practices |
| Tech Lead | TL | Operational technical decisions, mentoring |
| SRE | SRE | Reliability, SLOs, incident response, observability |

### Category 2: C-Suite & Management

Strategic roles. Scope defined by decision level and responsibility.

| Role | Abbreviation | Atomic Scope |
|------|-------------|--------------|
| CEO | CEO | Strategic vision, high-level decisions |
| CTO | CTO | Technology strategy, make-vs-buy |
| CFO | CFO | Financial viability, ROI, costs |
| COO | COO | Operations, efficiency, processes |
| Project Manager | GP | Schedule, resources, risks, stakeholders |

### Category 3: Traditional/Specialized Professions

Recognized professions outside IT. Useful for business domains.

| Role | Atomic Scope |
|------|--------------|
| Accountant | Accounting, fiscal, taxes, balance sheets |
| Auditor | Compliance, evidence, audit trails |
| Lawyer/Legal | Contracts, terms, regulation, privacy |
| Privacy Specialist | GDPR/LGPD, consent, DPA, DPIA |
| Engineer | Systems engineering, processes, calculations |
| Financial Analyst | Accounts payable/receivable, reconciliation, cash flow |
| Fiscal Analyst | Tax compliance, invoicing, regulatory filings |

### Category 4: Modern Specializations

Emerging functions in the AI era. Scope defined by discipline.

| Role | Atomic Scope |
|------|--------------|
| Prompt Engineer | Prompt design, few-shot, chain-of-thought |
| Context Engineer | Context management, RAG, memory, knowledge graphs |
| AI Architect | AI pipelines, agent systems, model selection |
| Data Engineer | ETL, data pipelines, data quality |
| Platform Engineer | Developer experience, tooling, internal platforms |

### Category 5: Real Personas (Thinking Archetypes)

Real people used as ARCHETYPES of cognitive style, not imitation.
The agent adopts the MENTAL MODEL, not the identity.

| Persona | Archetype | When to Use |
|---------|-----------|-------------|
| Elon Musk | First-principles thinking, 10x ambition | Challenge assumptions, think at scale |
| DHH | Convention over configuration, simplicity | Avoid over-engineering |
| Martin Fowler | Refactoring, patterns, evolutionary architecture | Code quality, design patterns |
| Uncle Bob | Clean code, SOLID, craftsmanship | Design principles, clean architecture |

### Category 6: Fictional Personas (Functional Archetypes)

Fictional characters used as METAPHORS of capability.
The agent embodies the FUNCTION, not the fantasy.

| Persona | Metaphoric Function | When to Use |
|---------|---------------------|-------------|
| Jarvis | Omniscient AI assistant, precise execution, proactivity | Intelligent automation, complete assistance |
| Sherlock Holmes | Deduction, investigation, pattern-matching | Debugging, root-cause analysis, forensics |
| Spock | Pure logic, emotionless analysis, probabilities | Data-driven decisions, trade-off analysis |

## Decision Framework: Which Agent to Create?

```
PROBLEM DETECTED
  ↓
[1. Which DOMAIN?]
  → IT/SDLC: Category 1 (PM, QA, DBA, DEV-BE, ...)
  → Strategic: Category 2 (CEO, CTO, CFO, ...)
  → Business/Regulatory: Category 3 (Accountant, Auditor, Legal, ...)
  → Modern Discipline: Category 4 (Prompt Eng, SRE, ...)
  → Mental Model: Category 5 (Elon Musk, DHH, ...)
  → Metaphoric Function: Category 6 (Jarvis, Sherlock, ...)
  ↓
[2. Agent EXISTS in registry?]
  → YES: Reuse. Do NOT create duplicate.
  → NO: Forge creates. Continue to [3].
  ↓
[3. Goldilocks Check]
  → "Would another person recognize this professional title?"
      → YES: Proceed
      → NO: Rethink. Probably too task-specific.
  → "Could this agent solve OTHER tasks in the same domain?"
      → YES: Proceed
      → NO: Broaden scope until it passes this test.
  ↓
[4. Persist]
  → Save as agent definition file
  → Register in Agent Registry
  → Agent ready for reuse
```

## Persistence & Discovery

```
WHERE TO SAVE:
  Plugin agents:    {plugin}/agents/{name}.md
  Project-specific: .claude/agents/{name}.md
  Global (user):    ~/.claude/agents/{name}.md

NAMING: lowercase, kebab-case if compound (e.g., dev-be.md, fiscal-analyst.md)

REGISTRATION: Document in Agent Registry or memory
```

## Anti-Patterns

```
X  TASK-SPECIFIC AGENT (created for one task, discarded after use)
   → Example: "P0-1 fixer", "Sprint-0-fixer", "TC-002 corrector"
   → These agents cost time to create and generate ZERO reuse value.
   → Correct: DBA solves P0-3/P0-4 AND any future database task.

X  OVERLY GENERIC AGENT (solves everything = solves nothing well)
   → Example: "General Fixer", "All-Purpose Agent", "Swiss Army Knife"
   → Violates atomicity: no recognizable professional identity.
   → Correct: split into atomic roles (QA + DBA + DEV-BE, not "Fixer").

X  SCOPE DUPLICATION (two agents for the same domain)
   → Before creating, CHECK: "does an agent with this scope already exist?"
   → If yes: EXTEND the existing one, don't create another.
   → Agent proliferation is the new technical debt.

X  UNRECOGNIZABLE IDENTITY (name only makes sense to the creator)
   → Test: "If I say this title to a colleague, do they understand the function?"
   → If not: rename to a recognizable market title.

X  PERSONA WITHOUT PURPOSE (using Wolverine because it's cool)
   → Personas (Cat 5/6) have specific cognitive function.
   → Using Elon Musk for an accounting task is cargo cult.
   → Each persona has a "when to use" — respect it.
```

## Integration

- **Forge** (agents/forge.md): applies RBAD when creating agents
- **Agent Delegation** (protocols/agent-delegation.md): uses registry to route tasks
- **Agent Selection** (skills/agent-select/SKILL.md): keyword-based routing to agents

---

*MAOS RBAD Protocol v1.0.0 | 2026-03-13 | Role-Based Agent Design*
