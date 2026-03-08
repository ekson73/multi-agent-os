# CriticalityClassifier Operation

> **Operation**: classify | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Classify sections by criticality level to determine appropriate shard destination.

## Invocation

```bash
/auto-shard classify <file_path> [--format table|json]
```

## Criticality Levels

```
┌─────────────────────────────────────────────────────────────────────┐
│  CRITICALITY LEVELS                                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  CRITICAL  ──► rules/         ──► AUTO-LOAD every session          │
│  │                                                                  │
│  │  • Core behavior directives                                      │
│  │  • Mandatory rules (MUST/MUST-NOT)                               │
│  │  • Security constraints                                          │
│  │  • Error handling protocols                                      │
│  │  • Pre-execution requirements                                    │
│                                                                     │
│  HIGH      ──► docs/ (top)    ──► On-demand, frequently needed      │
│  │                                                                  │
│  │  • Protocol specifications                                       │
│  │  • Workflow definitions                                          │
│  │  • Integration guides                                            │
│  │  • Architecture decisions                                        │
│                                                                     │
│  MEDIUM    ──► docs/ (nested) ──► Reference material                │
│  │                                                                  │
│  │  • Glossaries                                                    │
│  │  • Naming conventions                                            │
│  │  • Examples and templates                                        │
│  │  • Team/project context                                          │
│                                                                     │
│  LOW       ──► docs/archive/  ──► Historical, rarely needed         │
│                                                                     │
│     • Changelogs                                                    │
│     • Migration notes                                               │
│     • Deprecated content                                            │
│     • Verbose explanations                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Classification Algorithm

```
FOR each section:
  score = 0

  # Keyword analysis
  IF contains("MUST", "OBRIGATÓRIO", "MANDATORY", "CRITICAL"):
    score += 40
  IF contains("SHOULD", "RECOMMENDED"):
    score += 20
  IF contains("MAY", "OPTIONAL", "NICE-TO-HAVE"):
    score += 5

  # Pattern analysis
  IF matches("[C0-9]"):  # Core directive pattern
    score += 50
  IF matches("[R0-9]"):  # Rule pattern
    score += 40
  IF contains("Protocol", "Standard"):
    score += 30
  IF contains("Changelog", "History", "Archive"):
    score -= 20
  IF contains("Example", "Template"):
    score += 10

  # Context analysis
  IF referenced_by_count > 3:
    score += 20
  IF has_version_marker:
    score += 10
  IF has_spec_reference:
    score -= 10  # Spec is the authority, this is summary

  # Size penalty for very large sections
  IF byte_size > 10KB:
    score -= 15  # Large sections should be further sharded

  # Map score to criticality
  RETURN:
    score >= 60  → CRITICAL
    score >= 35  → HIGH
    score >= 15  → MEDIUM
    score < 15   → LOW
```

## Keyword Dictionaries

### CRITICAL Indicators

```python
CRITICAL_KEYWORDS = [
    "MUST", "MUST-NOT", "OBRIGATÓRIO", "MANDATORY", "CRITICAL",
    "NEVER", "ALWAYS", "FORBIDDEN", "REQUIRED",
    "Core Directive", "Main Instructions", "Pre-Execution",
    "Error Handling", "Security", "Tratamento de Erros"
]

CRITICAL_PATTERNS = [
    r"\[C\d{2}\]",           # [C01], [C02], etc.
    r"\[R\d{2}\]",           # [R01], [R02], etc.
    r"Regra.*Fundamental",   # "Regra Fundamental"
    r"ANTES DE EXECUTAR",    # Pre-execution rules
]
```

### HIGH Indicators

```python
HIGH_KEYWORDS = [
    "SHOULD", "RECOMMENDED", "Protocol", "Standard", "Workflow",
    "Integration", "Architecture", "Spec", "Pattern"
]

HIGH_PATTERNS = [
    r"Version.*\d+\.\d+\.\d+",  # Versioned content
    r"Spec.*completa",          # Has full spec reference
    r"Quick Reference",         # Reference material
]
```

### LOW Indicators

```python
LOW_KEYWORDS = [
    "Changelog", "History", "Archive", "Deprecated", "Legacy",
    "Migration", "Old", "Previous", "Removed"
]

LOW_PATTERNS = [
    r"Master Changelog",
    r"Lessons Learned",
    r"\d{4}-\d{2}-\d{2}.*\d{4}-\d{2}-\d{2}",  # Date ranges (history)
]
```

## Output Format

### Table (default)

```markdown
## Criticality Classification: ~/.claude/CLAUDE.md

| Section | Score | Level | Destination | Reason |
|---------|-------|-------|-------------|--------|
| [C01] Core Directive | 90 | CRITICAL | rules/ | Core directive pattern, MUST keywords |
| [C02] Main Instructions | 85 | CRITICAL | rules/ | OBRIGATÓRIO, pre-execution |
| [C04] Git Worktree Protocol | 55 | HIGH | docs/ | Protocol, versioned |
| Glossário Global | 25 | MEDIUM | docs/reference/ | Reference only |
| Master Changelog | -5 | LOW | docs/archive/ | Historical, changelog |

**Summary**:
- CRITICAL: 4 sections → rules/ (auto-load)
- HIGH: 3 sections → docs/ (top-level)
- MEDIUM: 3 sections → docs/reference/
- LOW: 2 sections → docs/archive/
```

### JSON (--format json)

```json
{
  "file": "~/.claude/CLAUDE.md",
  "classifications": [
    {
      "section": "[C01] Core Directive",
      "score": 90,
      "level": "CRITICAL",
      "destination": "rules/",
      "keywords_found": ["MUST", "Core Directive"],
      "patterns_matched": ["[C01]"],
      "reason": "Core directive pattern with mandatory keywords"
    }
  ],
  "summary": {
    "CRITICAL": 4,
    "HIGH": 3,
    "MEDIUM": 3,
    "LOW": 2
  }
}
```

## Destination Mapping

| Level | Scope: User (~/.claude/) | Scope: Project (.claude/) |
|-------|--------------------------|---------------------------|
| CRITICAL | `~/.claude/rules/` | `.claude/rules/` |
| HIGH | `~/.claude/docs/` | `.claude/docs/` |
| MEDIUM | `~/.claude/docs/reference/` | `.claude/docs/reference/` |
| LOW | `~/.claude/docs/archive/` | `.claude/docs/archive/` |

## Override Mechanism

Users can force classification via frontmatter in sections:

```markdown
## My Section
<!-- criticality: CRITICAL -->
<!-- destination: rules/ -->
```

Or via inline marker:

```markdown
## My Section {criticality=HIGH}
```

## Edge Cases

| Case | Handling |
|------|----------|
| Mixed signals (MUST + Changelog) | Keyword weight wins, but flag for review |
| No clear indicators | Default to MEDIUM |
| Section references spec | Downgrade (spec is authority) |
| Very short section (<500 bytes) | Consider merging with parent |

## Integration

This operation:
- **Requires**: `analyze` output (section map)
- **Feeds into**: `generate` (uses destinations)

## Example Execution

**Input**: `/auto-shard classify ~/.claude/CLAUDE.md`

**Claude should**:

1. (If not done) Run `analyze` first to get section map
2. For each section, calculate criticality score
3. Map scores to levels (CRITICAL/HIGH/MEDIUM/LOW)
4. Determine destination paths
5. Output classification table with reasoning

---

*Operation: classify v1.0.0 | Parent: auto-shard | 2026-01-25*
