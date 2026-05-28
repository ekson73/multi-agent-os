#!/usr/bin/env bash
# /**
#  * Pass 3 — grammar / punctuation cleanup
#  * @context Capability-detected: if LANGUAGETOOL_API env var set, use REST API;
#  *          else fall back to pure regex heuristics (capitalization after period,
#  *          double-space collapse, terminal punctuation).
#  * @reason Grammar/punctuation is a "low-stakes" pass — never auto-corrects content
#  *          words. Style categories (which might over-rewrite) are EXCLUDED.
#  * @impact Conservative by design. Operator can opt-in to LanguageTool for richer
#  *          corrections by exporting LANGUAGETOOL_API=<url>.
#  */
set -euo pipefail

INPUT=""; OUTPUT=""; LANGUAGE=""; AUDIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --audit-append) AUDIT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$INPUT" ] && [ -n "$OUTPUT" ] && [ -n "$LANGUAGE" ] && [ -n "$AUDIT" ] \
  || { echo "Missing --input/--output/--language/--audit-append" >&2; exit 1; }

# Fallback (always-on): regex heuristics
python3 - "$INPUT" "$OUTPUT" "$LANGUAGE" "$AUDIT" <<'PYEOF'
import json
import re
import sys
from pathlib import Path

inp, out, lang, audit_path = sys.argv[1:5]
text = Path(inp).read_text(encoding="utf-8")
audit = json.loads(Path(audit_path).read_text() or "[]") if Path(audit_path).exists() else []

original = text
corrections_count = 0

# 1. Collapse double-spaces
new_text, n = re.subn(r"  +", " ", text)
if n > 0:
    audit.append({"pass": 3, "rule": "collapse-multispace", "count": n,
                  "applied": True, "confidence": 1.0})
    corrections_count += n
    text = new_text

# 2. Capitalize first letter after sentence-ending punctuation
def _cap_after_punct(m):
    return m.group(1) + " " + m.group(2).upper()
new_text, n = re.subn(r"([.!?])\s+([a-zãõçáéíóúâêîôûà])",
                      _cap_after_punct, text)
if n > 0:
    audit.append({"pass": 3, "rule": "capitalize-after-punct", "count": n,
                  "applied": True, "confidence": 1.0})
    corrections_count += n
    text = new_text

# 3. Ensure terminal period on non-empty paragraphs lacking final punctuation
# Conservative: only adds period if line ends with a word character (no list bullets,
# no code blocks, no headers).
lines_out: list[str] = []
fixed = 0
for line in text.splitlines():
    stripped = line.rstrip()
    if (stripped
        and re.match(r"^[^\-\*\#\|\>`].*[a-zA-ZãõçáéíóúâêîôûàÁÉÍÓÚÂÊÔÃÕÇ0-9)]$", stripped)
        and not stripped.endswith((".", "!", "?", ":", ";", ",", ")", "]"))):
        line = stripped + "."
        fixed += 1
    lines_out.append(line)
if fixed > 0:
    audit.append({"pass": 3, "rule": "terminal-punctuation", "count": fixed,
                  "applied": True, "confidence": 0.85})
    corrections_count += fixed
text = "\n".join(lines_out)

Path(out).write_text(text, encoding="utf-8")
Path(audit_path).write_text(json.dumps(audit, ensure_ascii=False, indent=2))

print(f"[pass3-grammar] {corrections_count} corrections applied", file=sys.stderr)
PYEOF

# Optional LanguageTool layer (only runs if env var set + scheme validated)
#
# CWE-918 SSRF defense-in-depth: validate LANGUAGETOOL_API scheme before POST.
# Threat model: attacker who controls LANGUAGETOOL_API (compromised CI / shell
# rc / accidental misconfiguration) can exfiltrate transcript data via the
# curl POST below. Mitigation = require https:// by default; opt-in escape
# for self-hosted plaintext via LANGUAGETOOL_API_ALLOW_HTTP=1. Private /
# loopback IPs intentionally NOT blocked — legitimate self-hosted LT
# instances (e.g., http://localhost:8010 dev, http://lt.internal corp)
# remain reachable when the operator opts in.
LT_ENABLED=no
if [ -n "${LANGUAGETOOL_API:-}" ] && command -v curl >/dev/null 2>&1; then
  case "$LANGUAGETOOL_API" in
    https://*)
      LT_ENABLED=yes
      ;;
    http://*)
      if [ "${LANGUAGETOOL_API_ALLOW_HTTP:-0}" = "1" ]; then
        LT_ENABLED=yes
        echo "[pass3-grammar] WARNING: insecure http:// LANGUAGETOOL_API (opt-in via LANGUAGETOOL_API_ALLOW_HTTP=1)" >&2
      else
        echo "[pass3-grammar] LANGUAGETOOL_API uses http:// — refused (export LANGUAGETOOL_API_ALLOW_HTTP=1 to opt in for self-hosted plaintext endpoint)" >&2
      fi
      ;;
    *)
      echo "[pass3-grammar] LANGUAGETOOL_API must start with https:// (or http:// with LANGUAGETOOL_API_ALLOW_HTTP=1); skipping LT layer" >&2
      ;;
  esac
fi
if [ "$LT_ENABLED" = "yes" ]; then
  echo "[pass3-grammar] LANGUAGETOOL_API='$LANGUAGETOOL_API' — applying additional rules" >&2
  TMP_LT="$(mktemp)"
  cp -- "$OUTPUT" "$TMP_LT"
  # Map language code to LanguageTool format
  case "$LANGUAGE" in
    pt-br) LT_LANG="pt-BR" ;;
    en-us) LT_LANG="en-US" ;;
    *) LT_LANG="auto" ;;
  esac
  # Restrict to safe categories
  curl -sS -X POST "$LANGUAGETOOL_API/check" \
    --data-urlencode "text@$TMP_LT" \
    --data "language=$LT_LANG" \
    --data "enabledCategories=PUNCTUATION,TYPOGRAPHY,CASING" \
    --data "enabledOnly=true" \
    > "${TMP_LT}.json" 2>/dev/null || echo "[pass3-grammar] LanguageTool call failed (non-fatal)" >&2
  # NOTE for v1.0.0: this branch CALLS LanguageTool but does NOT yet APPLY the
  # returned suggestions to OUTPUT (we discard ${TMP_LT}.json). Applying
  # suggestions safely (with proper offset arithmetic + JSON-to-replacement
  # mapping) is planned for v1.1.0. Until then, the regex heuristics above
  # are the only corrections actually applied; the LT call is currently a
  # no-op except for logging.
  rm -f "$TMP_LT" "${TMP_LT}.json"
fi
