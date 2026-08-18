---
name: eisenhower-matrix
description: List unresolved pendencies --scope=current --sort=Eisenhower (Triple-AAA Governance×Test×Production×Compliance)
type: command
skill: eisenhower-matrix
---

# /eisenhower-matrix — thin wrapper

Invokes `skills/eisenhower-matrix` (executable since v0.2.0) with:

```
eisenhower-matrix --scope=[current|session|repo|vault|all] --sort=[Eisenhower|default|created|updated|urgent|important] [--json] [--include=pending|all]
```

Defaults: `--scope=current --sort=Eisenhower --include=pending` (`--sort=default` → `Eisenhower`).

Executable surface (what the skill drives):

```
bin/work-compass-aggregate.py --sort=Eisenhower --pendency-scope=current --include=pending [--json]
```

See `skills/eisenhower-matrix/SKILL.md` for the classifier (transparent derived
urgency×importance ranks), AAA row contract, and output envelope. This file exists so
`/eisenhower-matrix` fires (skill alone is model/`plugin:`-only).
