#!/usr/bin/env bash
# Test: bin/artifact-registry — record + lookup dedup-memory (isolated ledger).
# Portable (bash 3.2 + jq). Exit 0 = all pass; 1 = a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/bin/artifact-registry"
export ARTIFACT_REGISTRY_DIR="$(mktemp -d)"
trap 'rm -rf "$ARTIFACT_REGISTRY_DIR"' EXIT
fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "test-artifact-registry:"

# 1. record name + create
"$BIN" record --kind name --slug praxis-audit --type skill \
  --purpose "audit the session's own enacted methods for theater and gaps" \
  --alias session-method-audit --ref github:ekson73/multi-agent-os/pull/248 >/dev/null 2>&1 \
  && ok "record --kind name" || no "record --kind name"
"$BIN" record --kind create --slug praxis-audit --type skill \
  --purpose "self-referential session-method audit preset" >/dev/null 2>&1 \
  && ok "record --kind create" || no "record --kind create"

# 2. idempotency: re-record identical -> no new line
before=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
"$BIN" record --kind name --slug praxis-audit --type skill \
  --purpose "audit the session's own enacted methods for theater and gaps" >/dev/null 2>&1
after=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
[ "$before" = "$after" ] && ok "idempotent no-op" || no "idempotent no-op ($before->$after)"

# 3. THE KEY: synonym purpose (no shared slug/words) flags DUP-RISK
v=$("$BIN" lookup --purpose "review the methods this session actually used for theater" --json | jq -r '.verdict')
[ "$v" = "DUP-RISK" ] && ok "synonym lookup -> DUP-RISK" || no "synonym lookup ($v)"

# 4. exact slug -> DUP-RISK
v=$("$BIN" lookup --slug praxis-audit --json | jq -r '.verdict')
[ "$v" = "DUP-RISK" ] && ok "exact-slug lookup -> DUP-RISK" || no "exact-slug lookup ($v)"

# 5. unrelated -> CLEAR
v=$("$BIN" lookup --purpose "generate a kubernetes helm chart for postgres" --json | jq -r '.verdict')
[ "$v" = "CLEAR" ] && ok "unrelated lookup -> CLEAR" || no "unrelated lookup ($v)"

# 6. empty registry -> CLEAR (fresh dir)
EMPTY="$(mktemp -d)"; v=$(ARTIFACT_REGISTRY_DIR="$EMPTY" "$BIN" lookup --purpose "anything" --json | jq -r '.verdict'); rm -rf "$EMPTY"
[ "$v" = "CLEAR" ] && ok "empty registry -> CLEAR" || no "empty registry ($v)"

# 6b. REGRESSION GUARD: lookup --type must FILTER, not crash (jq `|` vs `or` precedence).
# Pre-fix, `$hastype | not or (.type == $qtype)` parsed as `$hastype | (not or (...))`,
# piping a boolean into the disjunction -> "Cannot index boolean with string \"type\"".
# Record a same-purpose sibling under a DIFFERENT type so the filter has to discriminate.
"$BIN" record --kind create --slug praxis-audit-bin --type bin \
  --purpose "self-referential session-method audit preset" >/dev/null 2>&1
# control: no --type sees BOTH types
n_all=$("$BIN" lookup --purpose "self-referential session-method audit preset" --json | jq -r '.matches | length')
# --type skill admits only skill rows; --type bin only the bin row
n_skill=$("$BIN" lookup --purpose "self-referential session-method audit preset" --type skill --json | jq -r '[.matches[] | select(.type=="skill")] | length')
x_skill=$("$BIN" lookup --purpose "self-referential session-method audit preset" --type skill --json | jq -r '[.matches[] | select(.type!="skill")] | length')
n_bin=$("$BIN" lookup --purpose "self-referential session-method audit preset" --type bin --json | jq -r '.matches | length')
# a) it must not crash and must still find matches unfiltered
[ "$n_all" -ge 2 ] && ok "lookup --type control: unfiltered sees >=2 ($n_all)" || no "lookup --type control ($n_all)"
# b) --type skill must EXCLUDE every non-skill row (this is what the bug broke)
[ "$x_skill" -eq 0 ] && ok "lookup --type skill excludes other types" || no "lookup --type skill leaked $x_skill non-skill row(s)"
[ "$n_skill" -ge 1 ] && ok "lookup --type skill admits skill rows ($n_skill)" || no "lookup --type skill admitted none"
# c) --type bin must admit exactly the bin sibling
[ "$n_bin" -eq 1 ] && ok "lookup --type bin admits only the bin row" || no "lookup --type bin ($n_bin, want 1)"
# d) a type present in NO row must yield CLEAR/0 (not a crash, not everything)
v=$("$BIN" lookup --purpose "self-referential session-method audit preset" --type zzz-nonexistent --json | jq -r '.verdict')
[ "$v" = "CLEAR" ] && ok "lookup --type <absent> -> CLEAR" || no "lookup --type <absent> ($v)"

# 7. dry-run writes nothing
before=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
"$BIN" record --kind name --slug foo-bar --dry-run >/dev/null 2>&1
after=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
[ "$before" = "$after" ] && ok "--dry-run no write" || no "--dry-run wrote a line"

# 8. bad kind rejected (exit 1)
if "$BIN" record --kind bogus --slug x >/dev/null 2>&1; then no "bad --kind accepted"; else ok "bad --kind rejected"; fi

[ "$fail" -eq 0 ] && { echo "test-artifact-registry: PASS"; exit 0; } || { echo "test-artifact-registry: FAIL"; exit 1; }
