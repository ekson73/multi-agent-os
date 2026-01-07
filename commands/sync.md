---
name: sync
description: Sync content from multi-agent-os framework to consumer project
---

# /sync Command

Synchronizes protocols and configurations from the multi-agent-os framework to consumer projects.

## Usage

```
/sync [scope] [options]
```

## Scopes

| Scope | Description |
|-------|-------------|
| `all` | Sync all protocols and configurations |
| `protocols` | Sync protocol documents only |
| `sentinel` | Sync Sentinel Protocol rules |
| `skills` | Sync skill definitions |
| `config` | Sync configuration files |

## Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without applying |
| `--force` | Override local changes |
| `--check-ttl` | Show TTL status of synced content |

## Examples

```
/sync all                    # Sync everything
/sync protocols --dry-run    # Preview protocol sync
/sync sentinel --check-ttl   # Sync and show TTL status
```

## Workflow

1. Check upstream repository for updates
2. Compare versions (local vs remote)
3. Download updated files
4. Update PROV tags with sync date
5. Recalculate TTL expiration dates
6. Report sync summary

## Output

```
Sync Summary — multi-agent-os
─────────────────────────────────────────────────
Updated: 3 files
Unchanged: 12 files
New: 1 file

Files updated:
  protocols/hmp.md (v1.0 → v1.1)
  sentinel/rules.md (v1.0.1 → v1.0.2)
  skills/audit/SKILL.md (v1.1 → v1.2)

New files:
  protocols/new-protocol.md (v1.0)

TTL Status:
  🟢 FRESH: 14 files
  🟡 EXPIRING: 2 files
  🔴 EXPIRED: 0 files
```
