# RecursiveProcessor Operation

> **Operation**: recursive | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Handle recursive sharding when generated shards themselves exceed size thresholds.

## Invocation

```bash
/auto-shard recursive <path> [--max-depth 3] [--threshold 20KB]
```

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--max-depth` | 3 | Maximum recursion levels |
| `--threshold` | 20KB | Size threshold for re-sharding |
| `--dry-run` | - | Show what would happen |

## Recursion Rules

```
┌─────────────────────────────────────────────────────────────────────┐
│  RECURSION RULES                                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  WHEN TO RECURSE:                                                   │
│  • Shard size > threshold (default 20KB)                            │
│  • Shard has multiple H2/H3 sections                                │
│  • Current depth < max_depth                                        │
│                                                                     │
│  WHEN TO STOP:                                                      │
│  • Shard size <= threshold                                          │
│  • Shard is atomic (single section, no subsections)                 │
│  • Max depth reached                                                │
│  • Content cannot be logically split further                        │
│                                                                     │
│  DEPTH LIMITS:                                                      │
│  • Level 1: Main file → shards in rules/ or docs/                   │
│  • Level 2: Large shards → sub-shards in subdirectories             │
│  • Level 3: Sub-shards → micro-shards (rarely needed)               │
│  • Level 4+: BLOCKED (requires explicit --max-depth override)       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Recursion Algorithm

```
┌─────────────────────────────────────────────────────────────────────┐
│  RECURSIVE PROCESSOR ALGORITHM                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  FUNCTION process_recursive(file, depth=1):                         │
│                                                                     │
│    IF depth > max_depth:                                            │
│      RETURN warn("Max depth reached, stopping recursion")           │
│                                                                     │
│    size = get_file_size(file)                                       │
│                                                                     │
│    IF size <= threshold:                                            │
│      RETURN ok("File within threshold")                             │
│                                                                     │
│    sections = analyze(file)                                         │
│                                                                     │
│    IF len(sections) <= 1:                                           │
│      RETURN warn("Cannot split atomic content")                     │
│                                                                     │
│    # Determine sub-shard directory                                  │
│    parent_dir = dirname(file)                                       │
│    base_name = basename(file).replace('.md', '')                    │
│    sub_dir = f"{parent_dir}/{base_name}/"                           │
│                                                                     │
│    # Generate sub-shards                                            │
│    classifications = classify(file)                                 │
│    sub_shards = generate(file, destination=sub_dir)                 │
│                                                                     │
│    # Update parent shard with references                            │
│    update_refs(file, sub_shards)                                    │
│                                                                     │
│    # Recurse on large sub-shards                                    │
│    FOR shard IN sub_shards:                                         │
│      IF get_file_size(shard) > threshold:                           │
│        process_recursive(shard, depth + 1)                          │
│                                                                     │
│    RETURN ok(f"Created {len(sub_shards)} sub-shards at depth {depth}")│
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Directory Structure After Recursion

### Level 1 (Main → Shards)

```
~/.claude/
├── CLAUDE.md                    # 12KB (reduced from 55KB)
├── rules/
│   ├── core-directive.md        # 2KB
│   ├── main-instructions.md     # 25KB ← Too large, needs recursion
│   └── pr-review-protocol.md    # 4KB
└── docs/
    └── git-worktree-protocol.md # 3KB
```

### Level 2 (Large Shard → Sub-shards)

```
~/.claude/
├── CLAUDE.md
├── rules/
│   ├── core-directive.md
│   ├── main-instructions.md     # 5KB (reduced, links to sub-shards)
│   ├── main-instructions/       # ← NEW: Sub-shard directory
│   │   ├── pre-execution-rules.md    # 8KB
│   │   ├── autonomy-rules.md         # 6KB
│   │   └── error-handling.md         # 6KB
│   └── pr-review-protocol.md
└── docs/
    └── git-worktree-protocol.md
```

### Level 3 (Sub-shard → Micro-shards) - Rare

```
~/.claude/rules/main-instructions/
├── pre-execution-rules.md       # 3KB (reduced)
├── pre-execution-rules/         # ← Level 3
│   ├── step-1-verify.md
│   ├── step-2-validate.md
│   └── step-3-impact.md
├── autonomy-rules.md
└── error-handling.md
```

## Parent Shard Update

When a shard is recursively sharded, its content is replaced with references:

### Before (main-instructions.md - 25KB)

```markdown
# Main Instructions [C02]

## Princípios Operacionais

Long content...

## Regras Mandatórias Pré-Execução

Very long content...

## Regra de Autonomia

Long content...

## Tratamento de Erros

Long content...
```

### After (main-instructions.md - 5KB)

```markdown
# Main Instructions [C02]

> **Version**: 1.4.0 | **Sub-shards**: 3

This section has been split into sub-shards for optimal context usage.

## Sub-shards

| Section | Path | Size |
|---------|------|------|
| Regras Mandatórias Pré-Execução | [`./main-instructions/pre-execution-rules.md`](main-instructions/pre-execution-rules.md) | 8KB |
| Regra de Autonomia | [`./main-instructions/autonomy-rules.md`](main-instructions/autonomy-rules.md) | 6KB |
| Tratamento de Erros | [`./main-instructions/error-handling.md`](main-instructions/error-handling.md) | 6KB |

## Quick Reference

<!-- Kept in parent for quick access -->

### Princípios Operacionais (Summary)

- Antes de executar: contextualize, reflita, valide
- Multi-agent: use git-worktree
- QA contínuo: validação antes e após
```

## Manifest Update for Recursion

```json
{
  "version": "1.0.0",
  "shards": [
    {
      "id": "C02",
      "heading": "[C02] Main Instructions",
      "path": "rules/main-instructions.md",
      "criticality": "CRITICAL",
      "sha256": "...",
      "sub_shards": [
        {
          "id": "C02.1",
          "heading": "Regras Mandatórias Pré-Execução",
          "path": "rules/main-instructions/pre-execution-rules.md",
          "sha256": "..."
        },
        {
          "id": "C02.2",
          "heading": "Regra de Autonomia",
          "path": "rules/main-instructions/autonomy-rules.md",
          "sha256": "..."
        }
      ]
    }
  ]
}
```

## Output Format

```markdown
## Recursive Processing Report

### Recursion Tree

```
~/.claude/CLAUDE.md (55KB → 12KB)
├── rules/core-directive.md (2KB) ✓
├── rules/main-instructions.md (25KB → 5KB)
│   ├── rules/main-instructions/pre-execution-rules.md (8KB) ✓
│   ├── rules/main-instructions/autonomy-rules.md (6KB) ✓
│   └── rules/main-instructions/error-handling.md (6KB) ✓
├── rules/pr-review-protocol.md (4KB) ✓
└── docs/git-worktree-protocol.md (3KB) ✓
```

### Summary

| Metric | Value |
|--------|-------|
| Max depth reached | 2 |
| Total shards created | 7 |
| Recursive splits | 1 |
| Final largest file | 8KB |

### All files now under 20KB threshold.
```

## Safeguards

| Safeguard | Description |
|-----------|-------------|
| **Depth limit** | Hard cap at 3 levels (override with `--max-depth`) |
| **Atomic detection** | Won't split content without clear sections |
| **Circular prevention** | Tracks processed files to avoid loops |
| **Rollback** | If any level fails, rollback entire recursion |
| **Manual override** | `--no-recursive` in parent operations |

## Integration

This operation:
- **Called by**: `generate` (when shard exceeds threshold)
- **Calls**: `analyze`, `classify`, `generate`, `update-refs`
- **Modifies**: Creates subdirectories, updates manifest

## Example Execution

**Input**: `/auto-shard recursive ~/.claude/rules/main-instructions.md`

**Claude should**:

1. Check file size against threshold
2. If over threshold, analyze for sub-sections
3. Create subdirectory for sub-shards
4. Generate sub-shards with appropriate naming
5. Update parent shard with reference table
6. Update manifest with nested structure
7. Check if any sub-shard needs further recursion
8. Report final tree structure

---

*Operation: recursive v1.0.0 | Parent: auto-shard | 2026-01-25*
