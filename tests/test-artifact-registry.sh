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

# 7. dry-run writes nothing
before=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
"$BIN" record --kind name --slug foo-bar --dry-run >/dev/null 2>&1
after=$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl")
[ "$before" = "$after" ] && ok "--dry-run no write" || no "--dry-run wrote a line"

# 8. bad kind rejected (exit 1)
if "$BIN" record --kind bogus --slug x >/dev/null 2>&1; then no "bad --kind accepted"; else ok "bad --kind rejected"; fi

[ "$fail" -eq 0 ] && { echo "test-artifact-registry: PASS"; exit 0; } || { echo "test-artifact-registry: FAIL"; exit 1; }
