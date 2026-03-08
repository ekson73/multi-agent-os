# IntegrityValidator Operation

> **Operation**: validate | **Version**: 1.0.0 | **Parent**: auto-shard

## Purpose

Verify integrity of sharded files using SHA256 hashes and validate all cross-references.

## Invocation

```bash
/auto-shard validate <path> [--fix] [--report-only]
```

## Flags

| Flag | Description |
|------|-------------|
| `--fix` | Attempt to fix detected issues |
| `--report-only` | Generate report without validation warnings |
| `--json` | Output in JSON format |

## Validation Checks

```
┌─────────────────────────────────────────────────────────────────────┐
│  INTEGRITY VALIDATION CHECKS                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. MANIFEST INTEGRITY                                              │
│     □ Manifest file exists                                          │
│     □ Manifest is valid JSON                                        │
│     □ All listed shards exist                                       │
│     □ No orphan shards (exist but not in manifest)                  │
│                                                                     │
│  2. CONTENT INTEGRITY (SHA256)                                      │
│     □ Each shard's current hash matches manifest                    │
│     □ Source file hash matches (if tracking)                        │
│     □ No unexpected modifications                                   │
│                                                                     │
│  3. LINK INTEGRITY                                                  │
│     □ All internal links resolve                                    │
│     □ All anchor targets exist                                      │
│     □ No circular references                                        │
│     □ Relative paths are correct                                    │
│                                                                     │
│  4. STRUCTURAL INTEGRITY                                            │
│     □ Main file references all critical shards                      │
│     □ Shards have proper headers                                    │
│     □ Auto-load shards are in rules/                                │
│     □ No duplicate content across shards                            │
│                                                                     │
│  5. CONSISTENCY CHECKS                                              │
│     □ Version numbers are consistent                                │
│     □ Dates are valid ISO 8601                                      │
│     □ No conflicting information                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Validation Algorithm

```
┌─────────────────────────────────────────────────────────────────────┐
│  VALIDATION ALGORITHM                                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. LOCATE manifest                                                 │
│     path/.shard-manifest.json                                       │
│                                                                     │
│  2. VALIDATE manifest structure                                     │
│     - Required fields present                                       │
│     - Version compatible                                            │
│                                                                     │
│  3. FOR EACH shard in manifest:                                     │
│                                                                     │
│     a. CHECK existence                                              │
│        - File exists at path?                                       │
│        - Report MISSING if not                                      │
│                                                                     │
│     b. VERIFY hash                                                  │
│        current_hash = sha256(file_content)                          │
│        IF current_hash != manifest.hash:                            │
│           report DRIFT                                              │
│                                                                     │
│     c. VALIDATE links                                               │
│        - Extract all links from shard                               │
│        - Check each resolves                                        │
│        - Report BROKEN if not                                       │
│                                                                     │
│  4. SCAN for orphans                                                │
│     - List all *.md in rules/ and docs/                             │
│     - Compare against manifest                                      │
│     - Report ORPHAN for untracked files                             │
│                                                                     │
│  5. CHECK main file                                                 │
│     - All critical shards referenced?                               │
│     - References use correct paths?                                 │
│                                                                     │
│  6. GENERATE report                                                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Issue Severity Levels

| Level | Code | Description | Example |
|-------|------|-------------|---------|
| **CRITICAL** | E | Must fix, blocks operations | Missing shard, corrupted manifest |
| **WARNING** | W | Should fix, may cause issues | Hash drift, orphan file |
| **INFO** | I | Informational, optional fix | Version outdated |

## Output Format

### Standard Report

```markdown
## Integrity Report: ~/.claude/

### Summary

| Check | Status | Issues |
|-------|--------|--------|
| Manifest | PASS | 0 |
| SHA256 Hashes | WARN | 2 |
| Link Resolution | PASS | 0 |
| Orphan Detection | WARN | 1 |
| Structure | PASS | 0 |

**Overall: 3 warnings, 0 errors**

### Details

#### SHA256 Hash Drift (WARNING)

| File | Expected | Current | Action |
|------|----------|---------|--------|
| rules/core-directive.md | abc123... | def456... | Content modified since sharding |
| docs/glossary.md | ghi789... | jkl012... | Content modified since sharding |

**Recommendation**: Run `/auto-shard validate --fix` to update manifest hashes, or investigate unexpected changes.

#### Orphan Files (WARNING)

| File | Location | Suggestion |
|------|----------|------------|
| docs/old-notes.md | ~/.claude/docs/ | Add to manifest or move to archive |

### File Inventory

| File | Hash | Links | Status |
|------|------|-------|--------|
| CLAUDE.md | abc... | 12/12 valid | OK |
| rules/core-directive.md | def... | 3/3 valid | DRIFT |
| rules/main-instructions.md | ghi... | 5/5 valid | OK |
| docs/git-worktree-protocol.md | jkl... | 2/2 valid | OK |
| ... | ... | ... | ... |

**Total: 12 files, 10 OK, 2 DRIFT, 0 MISSING**
```

### JSON Format (--json)

```json
{
  "timestamp": "2026-01-25T10:30:00-03:00",
  "path": "~/.claude/",
  "status": "WARNING",
  "summary": {
    "total_files": 12,
    "ok": 10,
    "drift": 2,
    "missing": 0,
    "orphan": 1,
    "broken_links": 0
  },
  "issues": [
    {
      "severity": "WARNING",
      "code": "HASH_DRIFT",
      "file": "rules/core-directive.md",
      "expected_hash": "abc123...",
      "current_hash": "def456...",
      "message": "Content modified since sharding"
    },
    {
      "severity": "WARNING",
      "code": "ORPHAN",
      "file": "docs/old-notes.md",
      "message": "File not tracked in manifest"
    }
  ],
  "files": [
    {
      "path": "rules/core-directive.md",
      "hash": "def456...",
      "expected_hash": "abc123...",
      "links_total": 3,
      "links_valid": 3,
      "status": "DRIFT"
    }
  ]
}
```

## Fix Actions

When `--fix` is provided:

| Issue | Fix Action |
|-------|------------|
| HASH_DRIFT | Update manifest with new hash |
| MISSING_SHARD | Remove from manifest, warn user |
| ORPHAN | Prompt to add to manifest or delete |
| BROKEN_LINK | Attempt to find correct target, update |
| DUPLICATE_CONTENT | Flag for manual review |

## Scheduled Validation

Recommend running validation:
- After any sharding operation
- Before committing changes
- As part of CI/CD (if applicable)
- Weekly for large repos

## Integration

This operation:
- **Requires**: `.shard-manifest.json`
- **Reads**: All shard files, main file
- **Modifies**: Only manifest (with `--fix`)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | Errors detected (CRITICAL issues) |
| 2 | Warnings detected (non-critical) |

## Example Execution

**Input**: `/auto-shard validate ~/.claude/`

**Claude should**:

1. Locate and load manifest
2. For each shard in manifest:
   - Verify file exists
   - Calculate current SHA256
   - Compare with manifest hash
   - Extract and validate all links
3. Scan for orphan files
4. Check main file references
5. Generate comprehensive report
6. Return appropriate exit code

---

*Operation: validate v1.0.0 | Parent: auto-shard | 2026-01-25*
