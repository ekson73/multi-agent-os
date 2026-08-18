---
name: eisenhower-matrix
description: List unresolved pendencies --scope=current --sort=Eisenhower (Triple-A×3: Test/Production/Compliance)
type: command
skill: eisenhower-matrix
---

# /eisenhower-matrix — thin wrapper

Invokes `skills/eisenhower-matrix` with:

```
eisenhower-matrix --scope=[current|session|project|global|repo|vault|jira:*|worktree|all] --sort=[Eisenhower|Prisma|priority|age] --format=[json-rpc|human] [--json] [--include=pending|all] --lang=[en-us|pt-br]
```

Defaults: `--scope=current --sort=Eisenhower --format=json-rpc` (`--sort=default` → `Eisenhower`, `--json` → `json-rpc`).

See `skills/eisenhower-matrix/SKILL.md` for classifier, AAA, output contract, and B-Tree. This file exists so `/eisenhower-matrix` fires (skill alone is model/`plugin:`-only). Harmonized v0.3.0 Triple-A×3 + Prisma regulatory.
