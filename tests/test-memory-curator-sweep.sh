#!/usr/bin/env bash
# Test: bin/memory-curator-sweep.sh — deterministic READ-ONLY pre-scan (ADR-012).
# Portable (bash 3.2 + jq). Exit 0 = all pass; 1 = a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/bin/memory-curator-sweep.sh"
FIX="$(mktemp -d 2>/dev/null || mktemp -d -t 'mcsweep')"
trap 'rm -rf "$FIX"' EXIT
fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "test-memory-curator-sweep:"

# ── fixtures ────────────────────────────────────────────────────────────────
mkdir -p "$FIX/corpus/journal/sess-aaaa"
cat > "$FIX/corpus/MEMORY.md" <<'EOF'
# Memory Index
- [Topic A](topic_a.md) — a thing
- [Ghost](ghost_file.md) — referenced but absent
- [Dot-slash](./dotslash_ref.md) — referenced with ./ prefix (must NOT be a false orphan)
- [Evil](../outside_evil.md) — traversal ref pointing OUTSIDE the corpus
EOF
echo "# Outside Evil" > "$FIX/outside_evil.md"   # exists OUTSIDE the corpus boundary
cat > "$FIX/corpus/dotslash_ref.md" <<'EOF'
# Dot Slash Ref
Referenced as ./dotslash_ref.md in the index.
EOF
cat > "$FIX/corpus/topic_a.md" <<'EOF'
# Topic Alpha
Content. PR ekson73/example#TBD.
EOF
cat > "$FIX/corpus/orphan_note.md" <<'EOF'
# Orphan Note
Not in the index.
EOF
cat > "$FIX/corpus/stale_rule.md" <<'EOF'
# Stale Reference
Calendar re-validation 2020-01-01 (long past).
EOF
cat > "$FIX/corpus/dup_one.md" <<'EOF'
# Same Title Twice
first body
EOF
cat > "$FIX/corpus/dup_two.md" <<'EOF'
# Same Title Twice
second body
EOF
i=0; while [ $i -lt 12 ]; do echo "note $i" > "$FIX/corpus/journal/sess-aaaa/e$i.md"; i=$((i+1)); done

# ── 1. findings run: exit 2 + valid JSON envelope ──────────────────────────
set +e
out="$("$BIN" --corpus "$FIX/corpus" --cap-bytes 10 --journal-threshold 10 2>/dev/null)"
rc=$?
set -e
[ "$rc" = "2" ] && ok "exit 2 when findings present" || no "exit code ($rc != 2)"
echo "$out" | jq -e '.sweep=="memory-curator-sweep" and .verdict=="FINDINGS"' >/dev/null \
  && ok "JSON envelope valid + verdict FINDINGS" || no "envelope/verdict"

# ── 2. each check fires on its fixture ─────────────────────────────────────
has() { echo "$out" | jq -e --arg c "$1" '[.findings[]|select(.check==$c)]|length > 0' >/dev/null; }
has index-over-cap        && ok "index-over-cap fires (cap 10B)"        || no "index-over-cap"
has dangling-ref          && ok "dangling-ref fires (ghost_file.md)"    || no "dangling-ref"
has orphan-file           && ok "orphan-file fires (orphan_note.md)"    || no "orphan-file"
# ./-prefixed index ref must NOT produce a false orphan NOR a false dangling (qodo #268 bug)
echo "$out" | jq -e '[.findings[]|select(.check=="orphan-file" and (.path|endswith("dotslash_ref.md")))]|length == 0' >/dev/null \
  && ok "no false orphan for ./-prefixed ref (dotslash_ref.md)" || no "false orphan on ./ ref"
echo "$out" | jq -e '[.findings[]|select(.check=="dangling-ref" and (.detail|contains("dotslash")))]|length == 0' >/dev/null \
  && ok "no false dangling for ./-prefixed ref" || no "false dangling on ./ ref"
# Path-traversal guard: ../ ref flagged + NOT probed (file exists outside — must not be silently OK'd)
echo "$out" | jq -e '[.findings[]|select(.check=="dangling-ref" and (.detail|contains("outside the corpus")))]|length == 1' >/dev/null \
  && ok "traversal ref (../outside_evil.md) flagged, not probed" || no "path-traversal guard"
has stale-marker          && ok "stale-marker fires (2020-01-01)"       || no "stale-marker"
has journal-accumulation  && ok "journal-accumulation fires (12 > 10)"  || no "journal-accumulation"
has dup-title             && ok "dup-title fires (Same Title Twice)"    || no "dup-title"
has pending-artifact      && ok "pending-artifact fires (#TBD)"         || no "pending-artifact"

# ── 3. READ-ONLY guarantee: corpus byte-identical after the sweep ───────────
# Deterministic: sorted per-file checksum list (cksum includes path), then cksum
# the list — immune to find traversal-order differences across platforms.
corpus_sum() {
  find "$1" -type f | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done | cksum
}
sum_before="$(corpus_sum "$FIX/corpus")"
"$BIN" --corpus "$FIX/corpus" --cap-bytes 10 >/dev/null 2>&1 || true
sum_after="$(corpus_sum "$FIX/corpus")"
[ "$sum_before" = "$sum_after" ] && ok "read-only (corpus unchanged)" || no "read-only violated"

# ── 4. clean corpus: exit 0 + CLEAN ─────────────────────────────────────────
mkdir -p "$FIX/clean"
cat > "$FIX/clean/MEMORY.md" <<'EOF'
# Memory Index
- [Solo](solo.md) — the only topic
EOF
cat > "$FIX/clean/solo.md" <<'EOF'
# Solo Topic
Nothing wrong here.
EOF
set +e
cout="$("$BIN" --corpus "$FIX/clean" --cap-bytes 100000 2>/dev/null)"
crc=$?
set -e
[ "$crc" = "0" ] && ok "exit 0 on clean corpus" || no "clean exit code ($crc != 0)"
echo "$cout" | jq -e '.verdict=="CLEAN" and (.findings|length)==0' >/dev/null \
  && ok "verdict CLEAN + zero findings" || no "clean verdict"

# ── 5. no cap flag → index-over-cap skipped (opt-in check) ──────────────────
set +e
nout="$("$BIN" --corpus "$FIX/corpus" 2>/dev/null)"
set -e
echo "$nout" | jq -e '[.findings[]|select(.check=="index-over-cap")]|length == 0' >/dev/null \
  && ok "index-over-cap skipped without --cap-bytes" || no "cap opt-in"

# ── 6. usage errors: exit 1 ─────────────────────────────────────────────────
set +e
"$BIN" --corpus "$FIX/does-not-exist" >/dev/null 2>&1; e1=$?
"$BIN" --cap-bytes abc >/dev/null 2>&1; e2=$?
set -e
[ "$e1" = "1" ] && ok "exit 1 on missing corpus" || no "missing-corpus exit ($e1)"
[ "$e2" = "1" ] && ok "exit 1 on non-numeric cap" || no "bad-cap exit ($e2)"

echo
[ "$fail" = "0" ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
