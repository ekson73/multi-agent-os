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
