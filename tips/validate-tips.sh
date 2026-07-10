#!/usr/bin/env bash
# /**
#  * validate-tips.sh — anti-orphan / anti-theater integrity gate for the MAOS-Tips corpus.
#  * @context A hand-curated tip catalog ROTS (AWARENESS-REGISTRY drift proved it: "~31 skills"
#  *   for 63 real). This makes "zero orphan tips" a CI gate: every tool a tip points at must
#  *   actually exist, and a tip's family must match the tool's own declared metadata.family.
#  * @checks (1) jq + valid JSON  (2) unique ids  (3) each tool_path resolves (+ skill name: check)
#  *   (4) tip.family ∈ families  (5) family.route → skills/<route>/SKILL.md exists
#  *   (6) family-sync: a skill that DECLARES metadata.family must match its tip's family
#  *   (7) smoke-run: the hook renders one tip.
#  * @exit 0 = all pass · 1 = any failure. Invoked standalone + from tests/validate-plugin.sh.
#  */
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(dirname "$SCRIPT_DIR")}"     # arg1 override (validate-plugin.sh passes PLUGIN_ROOT); default = repo root
CATALOG="${ROOT}/tips/catalog.json"
HOOK="${ROOT}/plugin-scripts/session-tip.sh"

ERRORS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }

echo "Validating MAOS-Tips corpus..."

# (1) jq + valid JSON
if ! command -v jq >/dev/null 2>&1; then echo "  (skip: jq absent)"; exit 0; fi
if [ ! -f "$CATALOG" ]; then fail "tips/catalog.json missing"; echo "  Errors: $ERRORS"; exit 1; fi
if jq empty "$CATALOG" >/dev/null 2>&1; then pass "catalog.json is valid JSON"; else fail "catalog.json is invalid JSON"; echo "  Errors: $ERRORS"; exit 1; fi

# (2) unique ids
TOTAL="$(jq '.tips | length' "$CATALOG")"
UNIQ="$(jq '[.tips[].id] | unique | length' "$CATALOG")"
if [ "$TOTAL" = "$UNIQ" ]; then pass "$TOTAL tips, all ids unique"; else fail "duplicate tip id(s): $TOTAL tips but $UNIQ unique"; fi

# frontmatter family extractor (scan ONLY the YAML block, not body prose)
skill_family() {  # $1 = SKILL.md path → echoes metadata.family or empty
  awk 'NR==1&&/^---[[:space:]]*$/{f=1;next} f&&/^---[[:space:]]*$/{exit} f' "$1" 2>/dev/null \
    | grep -m1 -E '^[[:space:]]*family:[[:space:]]*' \
    | sed -E 's/^[[:space:]]*family:[[:space:]]*//; s/[[:space:]]*$//; s/^["'"'"']//; s/["'"'"']$//'
}

# (3)+(6) per-tip: tool_path exists, skill name: present, family-sync
while IFS=$'\t' read -r id tool ttype tpath fam; do
  [ -n "$id" ] || continue
  ABS="${ROOT}/${tpath}"
  if [ -f "$ABS" ]; then
    pass "tip '$id' → $tpath exists"
    if [ "$ttype" = "skill" ]; then
      if grep -qE "^name:[[:space:]]*${tool}[[:space:]]*$" "$ABS"; then
        pass "tip '$id' skill frontmatter name: $tool"
      else
        fail "tip '$id' → $tpath missing 'name: $tool' frontmatter"
      fi
      DECL="$(skill_family "$ABS" || true)"   # empty (no declared family) is expected, not an error
      if [ -n "$DECL" ]; then
        if [ "$DECL" = "$fam" ]; then
          pass "tip '$id' family-sync ($fam == declared)"
        else
          fail "tip '$id' family MISMATCH: catalog='$fam' but $tpath declares metadata.family='$DECL'"
        fi
      fi   # no declared family ⇒ authored family, sync-check skipped (by design)
    fi
  else
    fail "tip '$id' → $tpath does NOT exist (orphan)"
  fi
done < <(jq -r '.tips[] | [.id, .tool, .tool_type, .tool_path, .family] | @tsv' "$CATALOG")

# (4) every tip.family is defined in families{}
while IFS= read -r fam; do
  [ -n "$fam" ] || continue
  if jq -e --arg f "$fam" '.families[$f]' "$CATALOG" >/dev/null 2>&1; then
    pass "family '$fam' defined"
  else
    fail "family '$fam' used by a tip but not defined in families{}"
  fi
done < <(jq -r '[.tips[].family] | unique | .[]' "$CATALOG")

# (5) every family.route resolves to a real concierge skill
while IFS=$'\t' read -r fam route; do
  [ -n "$route" ] || continue
  if [ -f "${ROOT}/skills/${route}/SKILL.md" ]; then
    pass "family '$fam' route → skills/$route/SKILL.md exists"
  else
    fail "family '$fam' route '$route' → skills/$route/SKILL.md missing"
  fi
done < <(jq -r '.families | to_entries[] | [.key, .value.route] | @tsv' "$CATALOG")

# (7) smoke: the hook renders one tip
if [ -x "$HOOK" ]; then
  if OUT="$(CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOK" --print 2>/dev/null)" && printf '%s' "$OUT" | grep -q "MAOS Tip"; then
    pass "hook --print renders a tip"
  else
    fail "hook --print produced no tip"
  fi
else
  fail "plugin-scripts/session-tip.sh missing or not executable"
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "  MAOS-Tips: ✓ PASSED ($TOTAL tips, zero orphans)"
  exit 0
else
  echo "  MAOS-Tips: ✗ FAILED ($ERRORS error(s))"
  exit 1
fi
