# ShardGenerator Operation

> **Operation**: generate | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Create shard files from analyzed sections and update the main file with references.

## Invocation

```bash
/auto-shard generate <file_path> [--dry-run] [--no-backup]
```

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be created without writing files |
| `--no-backup` | Skip backup creation (not recommended) |
| `--force` | Overwrite existing shards |

## Generation Algorithm

```
┌─────────────────────────────────────────────────────────────────────┐
│  SHARD GENERATOR ALGORITHM                                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. BACKUP original file                                            │
│     → {filename}.backup.{timestamp}                                 │
│                                                                     │
│  2. FOR EACH classified section:                                    │
│                                                                     │
│     a. GENERATE shard filename:                                     │
│        - Extract key terms from heading                             │
│        - Convert to kebab-case                                      │
│        - Add .md extension                                          │
│        Example: "[C01] Core Directive" → "core-directive.md"        │
│                                                                     │
│     b. DETERMINE destination:                                       │
│        - CRITICAL → rules/                                          │
│        - HIGH/MEDIUM/LOW → docs/ (with subdirs)                     │
│                                                                     │
│     c. CREATE shard file:                                           │
│        - Add auto-load frontmatter (if rules/)                      │
│        - Copy section content                                       │
│        - Add provenance footer                                      │
│                                                                     │
│     d. CALCULATE SHA256 hash                                        │
│        - Store in manifest for integrity validation                 │
│                                                                     │
│  3. UPDATE main file:                                               │
│     - Replace section content with reference link                   │
│     - Keep section heading as anchor                                │
│     - Add "See: path/to/shard.md" reference                         │
│                                                                     │
│  4. WRITE manifest:                                                 │
│     → {dir}/.shard-manifest.json                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Filename Generation

### Rules

| Rule | Example |
|------|---------|
| Remove [CXX] markers | `[C01] Core Directive` → `core-directive` |
| Remove [RXX] markers | `[R01] Context Rule` → `context-rule` |
| Kebab-case | `Git Worktree Protocol` → `git-worktree-protocol` |
| Remove special chars | `Versioning & Changelog` → `versioning-changelog` |
| Max 50 chars | Truncate if longer |
| Add .md extension | Always |

### Collision Handling

```
If "core-directive.md" exists:
  1. Check if content matches (SHA256)
  2. If matches → Skip (already sharded)
  3. If different → Generate "core-directive-2.md"
  4. Flag for manual review
```

## Shard File Template

### For rules/ (CRITICAL)

```markdown
# {Section Heading}

<!-- Auto-loaded rule | Version: {version} | {date} -->
<!-- Source: {original_file} | Section: {section_id} -->
<!-- SHA256: {hash} -->

{section_content}

---

*Extracted from: {original_file} | Section: {heading} | {date}*
```

### For docs/ (HIGH/MEDIUM/LOW)

```markdown
# {Section Heading}

<!-- On-demand doc | Version: {version} | {date} -->
<!-- Source: {original_file} | Section: {section_id} -->

{section_content}

---

*Extracted from: {original_file} | Section: {heading} | {date}*
```

## Main File Update

### Before

```markdown
## [C01] Core Directive

> **Version**: 1.0.0 (2026-01-20)

```core-directive
OBJETIVO: resultados ótimos + evitar entropia...
```

### Cadeia de Delegação Padrão

...long content...
```

### After

```markdown
## [C01] Core Directive

> **Version**: 1.0.0 | **Shard**: `rules/core-directive.md`
>
> See full content: [`~/.claude/rules/core-directive.md`](rules/core-directive.md)

<!-- SHA256: abc123... | Auto-load: YES -->
```

## Manifest Format

`.shard-manifest.json`:

```json
{
  "version": "1.0.0",
  "generated_at": "2026-01-25T10:30:00-03:00",
  "source_file": "~/.claude/CLAUDE.md",
  "source_hash": "original_file_sha256",
  "shards": [
    {
      "id": "C01",
      "heading": "[C01] Core Directive",
      "path": "rules/core-directive.md",
      "criticality": "CRITICAL",
      "sha256": "shard_content_hash",
      "lines": "45-89",
      "bytes": 2150,
      "auto_load": true
    }
  ],
  "stats": {
    "original_size": 56320,
    "reduced_size": 12500,
    "reduction_percent": 77.8,
    "shard_count": 12
  }
}
```

## Output Format

### Dry-run Output

```markdown
## Dry-Run: Would generate 12 shards

### CRITICAL (rules/) - Auto-load

| Shard | Path | Size | SHA256 |
|-------|------|------|--------|
| [C01] Core Directive | rules/core-directive.md | 2.1KB | abc123... |
| [C02] Main Instructions | rules/main-instructions.md | 5.8KB | def456... |

### HIGH (docs/)

| Shard | Path | Size | SHA256 |
|-------|------|------|--------|
| Git Worktree Protocol | docs/git-worktree-protocol.md | 3.2KB | ghi789... |

### Changes to main file

- Original: 55KB (1,847 lines)
- After: 12KB (340 lines)
- Reduction: 78%

**No files modified (dry-run mode)**
```

### Actual Execution Output

```markdown
## Generated 12 shards

### Files Created

| Path | Size | Status |
|------|------|--------|
| rules/core-directive.md | 2.1KB | CREATED |
| rules/main-instructions.md | 5.8KB | CREATED |
| docs/git-worktree-protocol.md | 3.2KB | CREATED |
| ... | ... | ... |

### Main File Updated

- Backup: ~/.claude/CLAUDE.md.backup.20260125T103000
- New size: 12KB (was 55KB)
- Reduction: 78%

### Manifest

- Location: ~/.claude/.shard-manifest.json
- Shards tracked: 12

**All operations completed successfully**
```

## Error Handling

| Error | Action |
|-------|--------|
| Destination dir doesn't exist | Create it |
| File already exists (different content) | Rename with -N suffix, warn |
| Write permission denied | Abort, report error |
| Disk full | Abort, rollback, report |

## Rollback Capability

If any error occurs mid-generation:

1. Delete all newly created shards
2. Restore main file from backup
3. Remove partial manifest
4. Report what was rolled back

## Integration

This operation:
- **Requires**: `analyze` and `classify` output
- **Triggers**: `update-refs` (automatically in full pipeline)
- **Produces**: Shard files + manifest

## Example Execution

**Input**: `/auto-shard generate ~/.claude/CLAUDE.md`

**Claude should**:

1. Create backup of original file
2. For each classified section:
   - Generate filename
   - Create shard with appropriate template
   - Calculate and store SHA256
3. Update main file with references
4. Write manifest
5. Report results

---

*Operation: generate v1.0.0 | Parent: auto-shard | 2026-01-25*
