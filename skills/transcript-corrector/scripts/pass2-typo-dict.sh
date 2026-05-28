#!/usr/bin/env bash
# /**
#  * Pass 2 — common-typos dictionary lookup + replacement
#  * @context Applies search-and-replace from common-typos-<lang>.yaml.
#  *          Each entry: {wrong, correct, confidence?, context?}.
#  *          Confidence defaults to 1.0 (exact-match typos are deterministic).
#  * @reason Quick, deterministic correction layer that complements Pass 1
#  *          (phonetic-substitution for proper names is in Pass 1; Pass 2
#  *          is for non-name typos: misspellings, common ASR mishearings of
#  *          domain terms).
#  * @impact Default-empty for v1.0.0; PDCA cycles 1-3 populate the catalog.
#  *          Skill remains functional with empty dict (no-op pass).
#  */
set -euo pipefail

INPUT=""; OUTPUT=""; CATALOG=""; AUDIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --audit-append) AUDIT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$INPUT" ] && [ -n "$OUTPUT" ] && [ -n "$CATALOG" ] && [ -n "$AUDIT" ] \
  || { echo "Missing --input/--output/--catalog/--audit-append" >&2; exit 1; }

# If catalog is empty (typos: [] OR no typos key), no-op pass through.
if ! grep -q '^\s*-\s*wrong:' "$CATALOG" 2>/dev/null; then
  cp "$INPUT" "$OUTPUT"
  exit 0
fi

# Parse YAML entries via awk (sufficient for our flat structure).
# Each entry yields lines: WRONG=<x> CORRECT=<y> CONFIDENCE=<z>
python3 - "$INPUT" "$OUTPUT" "$CATALOG" "$AUDIT" <<'PYEOF'
import json
import re
import sys
from pathlib import Path

inp, out, cat, audit_path = map(Path, sys.argv[1:5])
text = inp.read_text(encoding="utf-8")
audit = json.loads(audit_path.read_text() or "[]") if audit_path.exists() else []

# Minimal YAML reader for the typo catalog
entries: list[dict] = []
current: dict = {}
pat_wrong = re.compile(r'^\s*-\s+wrong:\s*"?([^"\n]+?)"?\s*$')
pat_correct = re.compile(r'^\s+correct:\s*"?([^"\n]+?)"?\s*$')
pat_conf = re.compile(r'^\s+confidence:\s*([0-9.]+)\s*$')
for raw in cat.read_text(encoding="utf-8").splitlines():
    if pat_wrong.match(raw):
        if current:
            entries.append(current)
        current = {"wrong": pat_wrong.match(raw).group(1).strip(),
                   "correct": "", "confidence": 1.0}
    elif pat_correct.match(raw):
        current["correct"] = pat_correct.match(raw).group(1).strip()
    elif pat_conf.match(raw):
        current["confidence"] = float(pat_conf.match(raw).group(1))
if current and current.get("wrong"):
    entries.append(current)

out_text = text
for e in entries:
    if not e.get("wrong") or not e.get("correct"):
        continue
    pattern = re.compile(rf"\b{re.escape(e['wrong'])}\b")
    # Count occurrences (for audit) before replacing
    matches = list(pattern.finditer(out_text))
    if not matches:
        continue
    for m in matches:
        line_no = out_text[:m.start()].count("\n") + 1
        audit.append({
            "pass": 2, "line": line_no,
            "original": e["wrong"], "corrected": e["correct"],
            "confidence": e["confidence"], "rule": "typo-dict",
            "applied": True
        })
    out_text = pattern.sub(e["correct"], out_text)

out.write_text(out_text, encoding="utf-8")
audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2))
PYEOF
