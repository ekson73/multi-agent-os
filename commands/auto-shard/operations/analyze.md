# ShardAnalyzer Operation

> **Operation**: analyze | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Analyze a file to identify logical sections, their boundaries, and size metrics.

## Invocation

```bash
/auto-shard analyze <file_path> [--format table|json]
```

## Algorithm

```
┌─────────────────────────────────────────────────────────────────────┐
│  SHARD ANALYZER ALGORITHM                                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. READ file content                                               │
│  2. PARSE markdown structure:                                       │
│     - Identify heading levels (H1-H6)                               │
│     - Detect code blocks (``` boundaries)                           │
│     - Identify tables (| delimiters)                                │
│     - Find YAML frontmatter (--- boundaries)                        │
│                                                                     │
│  3. BUILD section tree:                                             │
│     Section {                                                       │
│       heading: string,                                              │
│       level: 1-6,                                                   │
│       start_line: int,                                              │
│       end_line: int,                                                │
│       byte_size: int,                                               │
│       children: Section[],                                          │
│       markers: [CXX] | [RXX] | version | etc                        │
│     }                                                               │
│                                                                     │
│  4. CALCULATE metrics:                                              │
│     - Total file size (bytes)                                       │
│     - Line count per section                                        │
│     - Percentage of total                                           │
│                                                                     │
│  5. IDENTIFY shardable sections:                                    │
│     - Has clear heading (H2 or H3 preferred)                        │
│     - Self-contained (no dangling references)                       │
│     - Size > 1KB (worth sharding)                                   │
│                                                                     │
│  6. OUTPUT section map                                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Section Detection Rules

### Primary Markers (High Confidence)

| Pattern | Example | Shardable |
|---------|---------|-----------|
| `## [CXX]` | `## [C01] Core Directive` | YES |
| `## [RXX]` | `## [R01] Context Rule` | YES |
| `## Named Section` | `## Git Workflow Standard` | YES |
| `### Subsection` | `### Quick Reference` | DEPENDS (parent) |

### Secondary Markers (Medium Confidence)

| Pattern | Indicates |
|---------|-----------|
| `> **Version**:` | Versioned section (good shard candidate) |
| `> **Spec**:` | Has external spec (reference only in main) |
| `---` (horizontal rule) | Section boundary |
| Empty line + H2 | New major section |

### Boundaries to Preserve

| Element | Rule |
|---------|------|
| Code blocks | Never split mid-block |
| Tables | Never split mid-table |
| Lists | Prefer keeping together |
| Frontmatter | Always keep in main file |

## Output Format

### Table (default)

```markdown
## Section Analysis: ~/.claude/CLAUDE.md

| # | Section | Level | Lines | Size | % | Shardable |
|---|---------|-------|-------|------|---|-----------|
| 1 | Frontmatter | - | 1-15 | 0.8KB | 1.5% | NO |
| 2 | [C01] Core Directive | H2 | 45-89 | 2.1KB | 3.8% | YES |
| 3 | [C02] Main Instructions | H2 | 90-210 | 5.8KB | 10.5% | YES |
| 4 | └─ Princípios Operacionais | H3 | 95-120 | 1.2KB | 2.2% | CHILD |
| 5 | └─ Regras Mandatórias | H3 | 121-180 | 2.8KB | 5.1% | CHILD |
| ... | ... | ... | ... | ... | ... | ... |

**Summary**:
- Total: 1,847 lines, 55KB
- Shardable sections: 12
- Recommended action: SHARD (exceeds 40KB threshold)
```

### JSON (--format json)

```json
{
  "file": "~/.claude/CLAUDE.md",
  "total_lines": 1847,
  "total_bytes": 56320,
  "threshold_status": "EXCEEDS_40KB",
  "sections": [
    {
      "id": 1,
      "heading": "Frontmatter",
      "level": 0,
      "start_line": 1,
      "end_line": 15,
      "bytes": 820,
      "percentage": 1.5,
      "shardable": false,
      "reason": "frontmatter"
    },
    {
      "id": 2,
      "heading": "[C01] Core Directive",
      "level": 2,
      "start_line": 45,
      "end_line": 89,
      "bytes": 2150,
      "percentage": 3.8,
      "shardable": true,
      "markers": ["C01", "version:1.0.0"],
      "children": []
    }
  ],
  "recommendation": {
    "action": "SHARD",
    "reason": "File exceeds 40KB threshold",
    "suggested_shards": 12
  }
}
```

## Edge Cases

| Case | Handling |
|------|----------|
| No headings | Treat entire file as single section |
| Only H1 | Use horizontal rules or patterns as boundaries |
| Nested deeply (H4+) | Collapse into parent H3 |
| Mixed heading levels | Build hierarchy, report inconsistencies |
| Empty sections | Flag as potential cleanup candidates |

## Integration

This operation is typically followed by:
- `classify` - To assign criticality levels
- `generate` - To create actual shard files (if full pipeline)

## Example Execution

**Input**: `/auto-shard analyze ~/.claude/CLAUDE.md`

**Claude should**:

1. Read the file content
2. Parse markdown structure identifying all H2/H3 headings
3. Calculate line ranges and byte sizes
4. Identify [CXX] patterns and version markers
5. Output the section table with recommendations

---

*Operation: analyze v1.0.0 | Parent: auto-shard | 2026-01-25*
