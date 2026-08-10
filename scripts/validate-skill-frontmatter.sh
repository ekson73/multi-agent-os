#!/usr/bin/env bash
# Fail if any SKILL.md under the repo lacks Agent Skills required frontmatter.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 <<'PY'
from pathlib import Path
import re, sys
root = Path(".")
bad = []
good = 0
skip_parts = {".git", ".worktrees", "node_modules"}
for p in root.rglob("SKILL.md"):
    if any(part in skip_parts for part in p.parts):
        continue
    text = p.read_text(encoding="utf-8", errors="replace")
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        bad.append(f"{p}: missing YAML frontmatter")
        continue
    fm = m.group(1)
    # allow name/description with optional quotes / multiline >
    has_name = re.search(r"(?m)^name:\s*\S", fm) is not None
    has_desc = re.search(r"(?m)^description:\s*\S", fm) is not None
    if not (has_name and has_desc):
        bad.append(f"{p}: frontmatter needs name + description")
    else:
        good += 1
if bad:
    print("FAIL skill frontmatter:")
    print("\n".join(bad))
    sys.exit(1)
print(f"OK {good} SKILL.md files have name+description frontmatter")
PY
