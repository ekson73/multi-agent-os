# Framework Consumption Model

## Overview

The `multi-agent-os` repository is the **canonical source of truth** for multi-agent coordination protocols. Downstream projects consume (not duplicate) these protocols.

**Version**: 1.0 | **Updated**: 2026-01-07

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│  FRAMEWORK CONSUMPTION MODEL                                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│                      ┌─────────────────────┐                          │
│                      │   multi-agent-os    │                          │
│                      │  (Source of Truth)  │                          │
│                      └──────────┬──────────┘                          │
│                                 │                                      │
│            ┌────────────────────┼────────────────────┐                │
│            │                    │                    │                │
│            ▼                    ▼                    ▼                │
│    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐         │
│    │ VKS_*         │   │ ai-projects   │   │ vks-jee-*-api │         │
│    │ (Presentation)│   │ (Automation)  │   │ (Backend)     │         │
│    └───────────────┘   └───────────────┘   └───────────────┘         │
│         Consumer            Consumer            Consumer              │
│                                                                        │
│  FLOW DIRECTION: Framework → Consumers (never reverse)                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Source of Truth Principle

```
┌────────────────────────────────────────────────────────────────────────┐
│  CANONICAL SOURCE — FRAMEWORK AUTHORITY                                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  multi-agent-os DEFINES:                                               │
│                                                                        │
│  • Sentinel Protocol (detection rules, audit logging)                  │
│  • Status Map System (templates, inference engine)                     │
│  • Anti-Conflict Protocol (worktree policy, lock files)               │
│  • Hierarchical Merge Protocol (branch convergence)                   │
│  • Agent Naming Conventions                                            │
│  • Skills and Commands catalog                                         │
│                                                                        │
│  Consumers ADAPT (not redefine) these protocols for their context.    │
│                                                                        │
│  IF A PROTOCOL NEEDS CHANGE:                                           │
│  1. Propose change in multi-agent-os                                   │
│  2. Get approval/merge                                                 │
│  3. Sync to consumers                                                  │
│                                                                        │
│  NEVER: Modify protocol in consumer and expect framework to follow    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Consumer Responsibilities

### 1. Reference, Don't Duplicate

```markdown
# Consumer CLAUDE.md (CORRECT)

## Multi-Agent Protocol

See `multi-agent-os` framework for canonical protocols:
- [Hierarchical Merge Protocol](protocols/hierarchical-merge-protocol.md)
- [Worktree Guide](docs/worktrees-guide.md)

Project-specific adaptations documented below.
```

```markdown
# Consumer CLAUDE.md (INCORRECT)

## Multi-Agent Protocol

[Full copy of protocol here...]

# Problem: Duplicate source of truth, will drift
```

### 2. Adaptation vs Modification

| Action | Allowed | Location |
|--------|---------|----------|
| Reference framework protocol | Yes | Consumer CLAUDE.md |
| Add project-specific rules | Yes | Consumer CLAUDE.md |
| Override framework defaults | Yes (documented) | Consumer CLAUDE.md |
| Modify framework protocol | No | Must be in framework repo |
| Remove framework rules | No | Can only add exceptions |

### 3. Sync Strategy

```bash
# Consumer project sync from framework
# (Manual for now, automation planned)

# 1. Check framework for updates
cd ~/.multi-agent-os
git pull origin main

# 2. Review changelog
cat CHANGELOG.md | head -50

# 3. If relevant updates, review and apply to consumer
# (Usually just reference updates, not copy)
```

---

## Framework Update Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│  PROTOCOL CHANGE WORKFLOW                                              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. IDENTIFY NEED                                                      │
│     └─ Consumer discovers gap or improvement opportunity               │
│                                                                        │
│  2. PROPOSE IN FRAMEWORK                                               │
│     └─ Create issue/PR in multi-agent-os repo                         │
│     └─ Document rationale and impact                                   │
│                                                                        │
│  3. REVIEW & APPROVE                                                   │
│     └─ Framework maintainer reviews                                    │
│     └─ Consider impact on all consumers                                │
│                                                                        │
│  4. MERGE TO FRAMEWORK                                                 │
│     └─ Update protocol documentation                                   │
│     └─ Update version number                                           │
│     └─ Update CHANGELOG.md                                             │
│                                                                        │
│  5. NOTIFY CONSUMERS                                                   │
│     └─ Consumers check for updates                                     │
│     └─ Apply new version (reference update or adaptation)             │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Consumer Adaptation Example

### VKS_Apresentacao_CEO_2027Q3 Adaptations

The VKS presentation project consumes multi-agent-os protocols with these adaptations:

```markdown
## Framework Reference

This project follows protocols from `multi-agent-os` framework:
- Base: Hierarchical Merge Protocol v1.0
- Base: Anti-Conflict Protocol v3.2

## Project-Specific Adaptations

### 1. Protected Files (Extension)
Added to framework protected list:
- `02_processed_data/*.csv` — Source of truth for timeline data
- `09_notebooklm/input/*.md` — Client-facing content

### 2. Naming Convention (Override)
Framework default: `{agent}-{feature}`
Project override: `{agent-hex}-{feature}` (shorter IDs for readability)

### 3. Language (Adaptation)
Framework: English
Project: Portuguese (pt-br) for documents, English for code
```

---

## Version Compatibility

| Framework Version | Consumer Compatibility |
|-------------------|------------------------|
| v1.x | Compatible with all v1.x consumers |
| v2.x | May require consumer adaptation |

### Semantic Versioning for Protocols

- **MAJOR (v2.0)**: Breaking changes that require consumer updates
- **MINOR (v1.1)**: New features, backward compatible
- **PATCH (v1.0.1)**: Bug fixes, clarifications, no behavior change

---

## Installation for Consumers

### Option 1: Global Install (Recommended)

```bash
# Clone framework to home directory
git clone https://github.com/ekson73/multi-agent-os.git ~/.multi-agent-os

# Run install script (symlinks to ~/.claude/)
cd ~/.multi-agent-os
./install/install.sh
```

### Option 2: Per-Project Reference

```bash
# Add as submodule (version-locked)
git submodule add https://github.com/ekson73/multi-agent-os.git .multi-agent-os

# Reference in CLAUDE.md
# See .multi-agent-os/protocols/ for coordination protocols
```

### Option 3: Copy & Attribute (Not Recommended)

If network isolation requires local copy:
- Copy only needed files
- Include clear attribution and version
- Document as "snapshot of multi-agent-os v1.0"
- Accept drift risk

---

## TTL Policy & Consumer Header Template

### TTL by Information Type

When consuming framework content, calculate expiration based on content type:

| Type | TTL (days) | Rationale |
|------|------------|-----------|
| Protocol/Standard | 90 | Core protocols are stable |
| API Documentation | 60 | Interfaces change moderately |
| Configuration | 30 | Configs may need frequent updates |
| Roadmap/Timeline | 14 | Time-sensitive information |
| Security Policy | 90 | Security requires stability |
| Decision Record | 180 | Decisions are long-lived |
| Tutorial/Guide | 60 | Examples may need updates |
| Reference Data | 30 | Data freshness matters |

### Consumer Header Template

When duplicating content from framework to consumer project, add this header:

```html
<!-- ═══════════════════════════════════════════════════════════════════════
     SOURCE OF TRUTH: multi-agent-os (framework)
     ═══════════════════════════════════════════════════════════════════════
     Canonical: github.com/ekson73/multi-agent-os/{path-to-file}
     Version: {version}
     Last sync: {YYYY-MM-DD}

     TTL POLICY:
     Type: {type-from-table-above}
     TTL: {days} days
     Expires: {sync-date + TTL}
     Status: {FRESH|EXPIRING|EXPIRED}

     ACTIONS BY STATE:
     🟢 FRESH (now < expires-7d): Use normally
     🟡 EXPIRING (expires-7d < now < expires): Alert, plan review
     🔴 EXPIRED (now >= expires): Block usage until refresh from upstream

     Este conteudo e CONSUMIDO do framework multi-agent-os.
     Atualizacoes devem ser feitas UPSTREAM FIRST, depois sincronizadas aqui.
     Customizacoes locais sao permitidas, mas devem ser claramente marcadas.
     ═══════════════════════════════════════════════════════════════════════ -->
```

### Header Field Definitions

| Field | Description | Example |
|-------|-------------|---------|
| `Canonical` | Full URL to source file in framework | `github.com/ekson73/multi-agent-os/protocols/hmp.md` |
| `Version` | Version of the protocol being consumed | `v1.0` |
| `Last sync` | Date content was synced from framework | `2026-01-07` |
| `Type` | Content type (from TTL table) | `Protocol/Standard` |
| `TTL` | Time-to-live in days | `90 days` |
| `Expires` | Calculated date (sync + TTL) | `2026-04-07` |
| `Status` | Current freshness state | `FRESH`, `EXPIRING`, or `EXPIRED` |

### Status State Machine

```
┌─────────────────────────────────────────────────────────────────────────┐
│  TTL STATUS STATE MACHINE                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  SYNC ───► 🟢 FRESH ──────────────────────► 🟡 EXPIRING ───► 🔴 EXPIRED │
│            │                                │                │          │
│            │  (now < expires - 7d)          │  (7d window)   │          │
│            │                                │                │          │
│            │                                │                ▼          │
│            │                                │           BLOCK USAGE     │
│            │                                │                │          │
│            │                                │                ▼          │
│            │                                │           REFRESH         │
│            │                                │           FROM UPSTREAM   │
│            └────────────────────────────────┴───────────────────────────│
│                                                         │               │
│                                                         ▼               │
│                                                    SYNC again           │
│                                                    (back to FRESH)      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Agent Behavior by Status

| Status | Agent Should | Human Should |
|--------|--------------|--------------|
| 🟢 FRESH | Use content normally | No action needed |
| 🟡 EXPIRING | Warn human, suggest review | Schedule sync review |
| 🔴 EXPIRED | Block usage, require refresh | Sync from upstream |

---

## PROV Tag — Compact Provenance Stamp

For smaller files or contexts where full headers are excessive, use **PROV** (Provenance) tags.

### Why "PROV"?

| Term Considered | Verdict |
|-----------------|---------|
| PEDIGREE | Good but biology-oriented |
| LINEAGE | Too genealogical |
| ORIGIN | Too generic |
| DNA | Confusing with bioinformatics |
| FINGERPRINT | Confusing with hashes |
| **PROV** | **Winner** — short, data-lineage standard |

**PROV** is used in data engineering and ML for tracking data provenance (origin + transformations).

### PROV Tag Formats

**IMPORTANT**: Always use **full GitHub URL** for traceability, enabling:
- Click-to-navigate for manual review
- Automated sync scripts
- Existence validation
- Unambiguous source identification

#### Format: COMPACT (1 line, recommended)

```html
<!-- PROV: github.com/ekson73/multi-agent-os/blob/main/protocols/hmp.md | v1.0 | sync:2026-01-07 | TTL:90d | exp:2026-04-07 -->
```

#### Format: INLINE (1 line, Markdown-safe comment)

```markdown
[//]: # (PROV: github.com/ekson73/multi-agent-os/blob/main/protocols/hmp.md|v1.0|2026-01-07|TTL90|exp:2026-04-07)
```

#### Format: JSON (for .json files)

```json
{
  "_prov": "github.com/ekson73/multi-agent-os/blob/main/protocols/hmp.md|v1.0|2026-01-07|TTL90|exp:2026-04-07",
  ...rest of file...
}
```

#### Format: YAML (for .yaml/.yml files)

```yaml
# PROV: github.com/ekson73/multi-agent-os/blob/main/protocols/hmp.md|v1.0|2026-01-07|TTL90|exp:2026-04-07
...rest of file...
```

### PROV Tag Specification

```
PROV: {full-url} | v{version} | sync:{YYYY-MM-DD} | TTL:{days}d | exp:{YYYY-MM-DD}
```

| Field | Format | Example |
|-------|--------|---------|
| `full-url` | Complete GitHub URL to source file | `github.com/ekson73/multi-agent-os/blob/main/protocols/hmp.md` |
| `version` | `v{semver}` | `v1.0` |
| `sync` | `sync:{ISO-date}` | `sync:2026-01-07` |
| `TTL` | `TTL:{days}d` | `TTL:90d` |
| `exp` | `exp:{ISO-date}` | `exp:2026-04-07` |

**Why full URL instead of relative path?**

| Approach | Traceability | Automation | Navigation |
|----------|--------------|------------|------------|
| Relative path (`repo/file.md`) | Requires knowledge of base URL | Scripts need URL construction | Manual lookup required |
| **Full URL** | Complete and unambiguous | Direct use in scripts | Click-to-navigate |

### When to Use Each Format

| Context | Recommended Format |
|---------|-------------------|
| Main protocol docs (CLAUDE.md, README.md) | **FULL** (15-line header) |
| Section-level content in larger files | **COMPACT** (3-line) |
| Config files, small utilities | **INLINE** (1-line) |
| JSON/YAML configs | **JSON/YAML** format |
| Code comments | **INLINE** |

### PROV vs Full Header Decision Tree

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PROV FORMAT SELECTION                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Is content > 100 lines?                                                │
│    YES → Use FULL header                                                │
│    NO  ↓                                                                │
│                                                                         │
│  Is content a standalone file?                                          │
│    YES → Use COMPACT (3-line)                                           │
│    NO  ↓                                                                │
│                                                                         │
│  Is content embedded in another file?                                   │
│    YES → Use INLINE (1-line)                                            │
│    NO  → Use COMPACT (3-line)                                           │
│                                                                         │
│  Is file JSON/YAML?                                                     │
│    YES → Use JSON/YAML format                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Framework Files Reference

| Directory | Content | Consumer Access |
|-----------|---------|-----------------|
| `protocols/` | Coordination protocols (HMP, etc.) | Reference/Read |
| `docs/` | Guides and best practices | Reference/Read |
| `sentinel/` | Anomaly detection rules | Use via ~/.claude/ |
| `statusmap/` | Observability templates | Use via ~/.claude/ |
| `skills/` | Reusable agent skills | Use via ~/.claude/ |
| `scripts/` | Automation scripts | Execute locally |
| `install/` | Installation scripts | Run once |

---

## References

- [Multi-Agent OS README](../README.md)
- [Hierarchical Merge Protocol](../protocols/hierarchical-merge-protocol.md)
- [Worktrees Guide](worktrees-guide.md)

---

## Metadata

| Field | Value |
|-------|-------|
| Created by | `Claude-Dev-docs-001` |
| Delegated by | `Claude-Orch-Prime-20260107-docs` |
| Date | 2026-01-07 |
| Version | 1.0 |

**Changelog**:
- v1.0 (2026-01-07): Initial version — Source of Truth principle, Consumer responsibilities, Update flow

*Signature: Claude-Dev-docs-001 | 2026-01-07T12:20:00-03:00*
