# Skill Writer — Examples

Read this when starting a new Skill and you want a working template to adapt, rather than building the frontmatter and structure from scratch.

## Common patterns

### Read-only Skill

```yaml
---
name: code-reader
description: Read and analyze code without making changes. Use for code review, understanding codebases, or documentation.
allowed-tools: Read, Grep, Glob
---
```

### Script-based Skill

```yaml
---
name: data-processor
description: Process CSV and JSON data files with Python scripts. Use when analyzing data files or transforming datasets.
---

# Data Processor

## Instructions

1. Use the processing script:
\`\`\`bash
python scripts/process.py input.csv --output results.json
\`\`\`

2. Validate output with:
\`\`\`bash
python scripts/validate.py results.json
\`\`\`
```

### Multi-file Skill with progressive disclosure

```yaml
---
name: api-designer
description: Design REST APIs following best practices. Use when creating API endpoints, designing routes, or planning API architecture.
---

# API Designer

Quick start: See [examples.md](examples.md)

Detailed reference: See [reference.md](reference.md)

## Instructions

1. Gather requirements
2. Design endpoints (see examples.md)
3. Document with OpenAPI spec
4. Review against best practices (see reference.md)
```
