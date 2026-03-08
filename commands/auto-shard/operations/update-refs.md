# ReferenceUpdater Operation

> **Operation**: update-refs | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Update cross-references and links after sharding to ensure all internal references remain valid.

## Invocation

```bash
/auto-shard update-refs <file_path> [--dry-run] [--scope all|main|shards]
```

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would change without modifying |
| `--scope all` | Update main file and all shards (default) |
| `--scope main` | Only update main file |
| `--scope shards` | Only update shard files |

## Reference Types

```
┌─────────────────────────────────────────────────────────────────────┐
│  REFERENCE TYPES TO UPDATE                                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. MARKDOWN LINKS                                                  │
│     [text](path/to/file.md)                                         │
│     [text](path/to/file.md#section)                                 │
│                                                                     │
│  2. INLINE REFERENCES                                               │
│     See: `path/to/file.md`                                          │
│     Spec: path/to/spec.md                                           │
│     > **Spec completa**: `path/to/spec.md`                          │
│                                                                     │
│  3. SECTION ANCHORS                                                 │
│     [text](#section-heading)                                        │
│     → May need to become [text](shard.md#section-heading)           │
│                                                                     │
│  4. CODE REFERENCES                                                 │
│     # See: ~/.claude/docs/file.md                                   │
│     <!-- Source: path/to/original.md -->                            │
│                                                                     │
│  5. RELATIVE PATHS                                                  │
│     ../docs/file.md                                                 │
│     ./rules/rule.md                                                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Update Algorithm

```
┌─────────────────────────────────────────────────────────────────────┐
│  REFERENCE UPDATER ALGORITHM                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. LOAD manifest (.shard-manifest.json)                            │
│     - Get list of shards and their paths                            │
│     - Build section→shard mapping                                   │
│                                                                     │
│  2. SCAN for references:                                            │
│     - Markdown links: \[.*?\]\((.*?)\)                              │
│     - Inline refs: See: `(.*?)`                                     │
│     - Spec refs: \*\*Spec.*?\*\*: `(.*?)`                           │
│     - Comment refs: <!-- Source: (.*?) -->                          │
│                                                                     │
│  3. FOR EACH reference:                                             │
│                                                                     │
│     a. RESOLVE current path                                         │
│        - Absolute or relative?                                      │
│        - Does target exist?                                         │
│                                                                     │
│     b. CHECK if target was sharded                                  │
│        - Look up in manifest                                        │
│        - If sharded → needs update                                  │
│                                                                     │
│     c. COMPUTE new path                                             │
│        - From current file to new shard location                    │
│        - Preserve anchor if present                                 │
│                                                                     │
│     d. UPDATE reference in file                                     │
│                                                                     │
│  4. VALIDATE all links                                              │
│     - Check each updated reference resolves                         │
│     - Report any broken links                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Path Resolution Rules

### From Main File to Shard

```markdown
# In ~/.claude/CLAUDE.md

# Before (internal section reference)
See: [C01] Core Directive

# After (link to shard)
See: [`rules/core-directive.md`](rules/core-directive.md)
```

### From Shard to Shard

```markdown
# In ~/.claude/rules/core-directive.md

# Before (if content referenced another section)
follows [C02] Main Instructions

# After (relative path between shards)
follows [`main-instructions.md`](main-instructions.md)
```

### From Shard to Main

```markdown
# In ~/.claude/docs/some-doc.md

# Before
See CLAUDE.md for overview

# After
See [`../CLAUDE.md`](../CLAUDE.md) for overview
```

## Relative Path Calculation

```python
def calculate_relative_path(from_file, to_file):
    """
    Calculate relative path from one file to another.

    Examples:
    - from: ~/.claude/rules/a.md, to: ~/.claude/rules/b.md → "b.md"
    - from: ~/.claude/rules/a.md, to: ~/.claude/docs/b.md → "../docs/b.md"
    - from: ~/.claude/CLAUDE.md, to: ~/.claude/rules/a.md → "rules/a.md"
    """
    from_dir = os.path.dirname(from_file)
    return os.path.relpath(to_file, from_dir)
```

## Anchor Handling

### Section Moved to Shard

```markdown
# In main file, before
[link to section](#c01-core-directive)

# After sharding, link must update
[link to section](rules/core-directive.md#c01-core-directive)
```

### Anchor Generation

```python
def generate_anchor(heading):
    """
    Convert heading to GitHub-style anchor.

    "[C01] Core Directive" → "c01-core-directive"
    "Git Worktree Protocol" → "git-worktree-protocol"
    """
    anchor = heading.lower()
    anchor = re.sub(r'[^\w\s-]', '', anchor)  # Remove special chars
    anchor = re.sub(r'\s+', '-', anchor)       # Spaces to hyphens
    return anchor
```

## Output Format

### Dry-run

```markdown
## Reference Update Preview

### Main File: ~/.claude/CLAUDE.md

| Line | Current | New |
|------|---------|-----|
| 45 | `See [C04] section` | `See [rules/git-worktree-protocol.md](rules/git-worktree-protocol.md)` |
| 120 | `#c01-core-directive` | `rules/core-directive.md#c01-core-directive` |

### Shard: rules/main-instructions.md

| Line | Current | New |
|------|---------|-----|
| 23 | `follows [C01]` | `follows [core-directive.md](core-directive.md)` |

**Summary**:
- References found: 15
- Updates needed: 8
- No changes made (dry-run)
```

### Actual Execution

```markdown
## Reference Update Complete

### Files Modified

| File | Updates |
|------|---------|
| ~/.claude/CLAUDE.md | 5 references |
| rules/main-instructions.md | 2 references |
| docs/git-worktree-protocol.md | 1 reference |

### Validation

- All 8 updated references: VALID
- No broken links detected

**Update successful**
```

## Edge Cases

| Case | Handling |
|------|----------|
| Circular references | Detect and warn, don't create loops |
| External URLs | Skip (not internal references) |
| Broken link (pre-existing) | Report, don't fix (out of scope) |
| Reference to non-existent section | Warn, keep original |
| Anchor collision | Use first match, warn about ambiguity |

## Integration

This operation:
- **Requires**: `generate` output (shards exist)
- **Uses**: `.shard-manifest.json` for mapping
- **Triggers**: `validate` (to verify all links work)

## Example Execution

**Input**: `/auto-shard update-refs ~/.claude/CLAUDE.md`

**Claude should**:

1. Load manifest to get shard mapping
2. Scan main file for all references
3. For each reference, check if target was sharded
4. Calculate new relative paths
5. Update references in place
6. Repeat for each shard file
7. Validate all links resolve
8. Report changes made

---

*Operation: update-refs v1.0.0 | Parent: auto-shard | 2026-01-25*
