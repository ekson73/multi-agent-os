---
name: eisenhower-matrix
description: List unresolved pendencies --scope=current --sort=Eisenhower (triple-A)
type: command
skill: eisenhower-matrix
---

# /eisenhower-matrix — thin wrapper

Invokes `skills/eisenhower-matrix` with:

```
eisenhower-matrix --scope=[current|session|repo|vault|all] --sort=[Eisenhower|default|created|updated|urgent|important] [--json] [--dry-run] [--include=pending|all]
```

Defaults: `--scope=current --sort=Eisenhower` (`--sort=default` → `Eisenhower`).

See `skills/eisenhower-matrix/SKILL.md` for classifier, AAA, and output contract. This file exists so `/eisenhower-matrix` fires (skill alone is model/`plugin:`-only).
