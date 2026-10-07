#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Tests: bin/close-out-manifest.sh — the postflight P3.7 MANIFEST executor (v0.1.0)
# Scope (the safety contract):
#   check   — a manifest missing a required section or a recovery-triple field FAILS (rc 2);
#             a gate that is not PASS fails closed; a complete manifest passes (rc 0)
#   persist — dry-run is the DEFAULT (nothing copied without --apply); a clean file is
#             copied durably and a 2nd --apply is idempotent; a secret-shaped or PII-shaped
#             source is REFUSED; a scanner that cannot see the runtime positive control
#             fails closed (rc 3) — a blind scanner never reports "clean"
#   clip    — success ONLY when the read-back is byte-identical (cmp); a lossy clipboard
#             or no clipboard tool ⇒ rc 4 + the paste-MCP fallback hint, never fake success
# Bash 3.2-safe. Fake clipboard via MAOS_CLIP_COPY / MAOS_CLIP_PASTE. No key literal in
# this file: the secret fixture is assembled at runtime.
# Run: bash bin/tests/close-out-manifest.test.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail   # no -e on purpose: negative cases assert non-zero rc and must not abort the suite

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CM="$SCRIPT_DIR/../close-out-manifest.sh"

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "${2:-<empty>}"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -x "$CM" ] || { echo "  ❌ $CM missing or not executable"; exit 1; }

full_manifest() {
  cat <<'EOF'
# Close-out manifest
## Delegates gate
delegates_gate: PASS
## Instruction tree
- [done] root instruction
## HITL decisions
1. (recommended) option A
## Roadmap
- next: step one
## Artifact index
- report: docs/x.md
## Recovery
session_id: 00000000-0000-0000-0000-000000000000
link: https://example.invalid/session
command: claude --resume 00000000-0000-0000-0000-000000000000
## Self-location
manifest_path: /durable/close-out-manifest.md
EOF
}

# chk: point manifest_path at the file under test (self-location must resolve), then check it
chk() {
  local f="$1"; shift
  sed "s#^manifest_path: .*#manifest_path: $f#" "$f" > "$f.loc" && mv "$f.loc" "$f"
  bash "$CM" check --manifest "$f" "$@"
}

echo "── close-out-manifest: check"
full_manifest > "$TMP/m.md"
if chk "$TMP/m.md" >/dev/null 2>&1; then ok "complete manifest passes"; else bad "complete manifest should pass" "rc=$?"; fi

grep -v '^## Artifact index' "$TMP/m.md" > "$TMP/m-noidx.md"
OUT="$(chk "$TMP/m-noidx.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'Artifact index'; then ok "missing section ⇒ rc 2 and named"; else bad "missing section should fail rc 2" "rc=$RC out=$OUT"; fi

sed 's/^command: .*/command:/' "$TMP/m.md" > "$TMP/m-nocmd.md"
chk "$TMP/m-nocmd.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "empty recovery command ⇒ rc 2"; else bad "empty recovery command should fail" "rc=$RC"; fi

sed 's/^delegates_gate: PASS/delegates_gate: PENDING/' "$TMP/m.md" > "$TMP/m-gate.md"
chk "$TMP/m-gate.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "delegates gate not PASS ⇒ fail closed"; else bad "non-PASS gate should fail" "rc=$RC"; fi

echo "── close-out-manifest: check — fusion with session-handover (FEAT-2/16/17/22/34)"
# FEAT-2: closing with a pending delegate only as an operator-authorised PARTIAL
sed 's/^delegates_gate: PASS/delegates_gate: PARTIAL/' "$TMP/m.md" > "$TMP/m-part.md"
chk "$TMP/m-part.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "PARTIAL without operator authorisation ⇒ rc 2"; else bad "unauthorised PARTIAL should fail" "rc=$RC"; fi
sed -e 's/^# Close-out manifest/# PARTIAL Close-out manifest/' -e 's/^delegates_gate: PASS/delegates_gate: PARTIAL\
partial_authorized_by: operator in-session 2026-10-07/' "$TMP/m.md" > "$TMP/m-part.md"
OUT="$(chk "$TMP/m-part.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q '"partial":true'; then ok "authorised PARTIAL passes and is flagged partial"; else bad "authorised PARTIAL should pass flagged" "rc=$RC out=$OUT"; fi

# FEAT-16: the recovery triple must hold together
sed 's/^command: .*/command: claude --resume some-other-id/' "$TMP/m.md" > "$TMP/m-cmdid.md"
OUT="$(chk "$TMP/m-cmdid.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'command-lacks-session-id'; then ok "command without the session id ⇒ rc 2"; else bad "command must carry the session id" "rc=$RC out=$OUT"; fi
sed 's#^link: .*#link: not-a-url#' "$TMP/m.md" > "$TMP/m-link.md"
chk "$TMP/m-link.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "non-URL session link ⇒ rc 2"; else bad "session link must be a URL" "rc=$RC"; fi
sed "s#^command: \\(.*\\)#command: \\1\\
transcript_path: $TMP/nope.jsonl#" "$TMP/m.md" > "$TMP/m-tr.md"
OUT="$(chk "$TMP/m-tr.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'transcript-missing'; then ok "declared transcript path that does not exist ⇒ rc 2"; else bad "missing transcript should fail" "rc=$RC out=$OUT"; fi

# review: fields count only inside their own section (Recovery / Delegates gate / Self-location)
sed -e '/^command: /d' -e 's/^- next: step one/- next: step one\
command: npm test/' "$TMP/m.md" > "$TMP/m-scope.md"
OUT="$(chk "$TMP/m-scope.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'field:command'; then ok "recovery field outside ## Recovery does not count"; else bad "out-of-section field must not satisfy Recovery" "rc=$RC out=$OUT"; fi
# review: the four content sections must not be empty
awk '/^## Roadmap/{print; skip=1; next} /^## /{skip=0} !skip' "$TMP/m.md" > "$TMP/m-empty.md"
OUT="$(chk "$TMP/m-empty.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'empty-section:Roadmap'; then ok "empty Roadmap section ⇒ rc 2"; else bad "empty section must fail" "rc=$RC out=$OUT"; fi

# review: manifest_path must resolve to the checked manifest
full_manifest > "$TMP/m-stale.md"   # keeps the fixture's /durable/... path, which does not exist
OUT="$(bash "$CM" check --manifest "$TMP/m-stale.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'manifest-path-mismatch'; then ok "stale manifest_path ⇒ rc 2"; else bad "manifest_path must resolve to the checked file" "rc=$RC out=$OUT"; fi
# review: a PARTIAL close must say so in the title
sed -e 's/^delegates_gate: PASS/delegates_gate: PARTIAL\
partial_authorized_by: operator in-session 2026-10-07/' "$TMP/m.md" > "$TMP/m-pt.md"
OUT="$(chk "$TMP/m-pt.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'partial-title'; then ok "PARTIAL without PARTIAL title ⇒ rc 2"; else bad "PARTIAL must be in the title" "rc=$RC out=$OUT"; fi

# FEAT-17/22: indexed local paths must exist and must not be ephemeral unless declared so
# durable paths that need no write: this suite's own directory (a repo path, not a temp area)
{ cat "$TMP/m.md"; printf -- '- durable: `%s`\n' "$SCRIPT_DIR"; } > "$TMP/m-ok.md"
chk "$TMP/m-ok.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 0 ]; then ok "existing indexed path passes"; else bad "existing indexed path should pass" "rc=$RC"; fi
{ cat "$TMP/m.md"; printf -- '- gone: `%s/does-not-exist.md`\n' "$SCRIPT_DIR"; } > "$TMP/m-broken.md"
OUT="$(chk "$TMP/m-broken.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'broken-link'; then ok "broken indexed path ⇒ rc 2"; else bad "broken path should fail" "rc=$RC out=$OUT"; fi
{ cat "$TMP/m.md"; printf -- '- note: `/tmp`\n'; } > "$TMP/m-eph.md"
OUT="$(chk "$TMP/m-eph.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'ephemeral-link'; then ok "undeclared ephemeral path ⇒ rc 2"; else bad "ephemeral path should fail" "rc=$RC out=$OUT"; fi
{ cat "$TMP/m.md"; printf -- '- scratch (ephemeral): `/tmp`\n'; } > "$TMP/m-eph2.md"
chk "$TMP/m-eph2.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 0 ]; then ok "declared ephemeral path passes"; else bad "declared ephemeral path should pass" "rc=$RC"; fi

# opt-in --strict adds After-action review / Resume check / Not done; default unchanged
chk "$TMP/m.md" --strict >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "--strict requires the opt-in sections"; else bad "--strict should require extra sections" "rc=$RC"; fi
{ cat "$TMP/m.md"; printf '## After-action review\nplanned/happened/why\n## Resume check\ncompare anchor first\n## Not done\nnone (verified)\n'; } > "$TMP/m-strict.md"
chk "$TMP/m-strict.md" --strict >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 0 ]; then ok "--strict passes with the opt-in sections"; else bad "--strict with sections should pass" "rc=$RC"; fi
{ cat "$TMP/m.md"; printf '## After-action review\n\n## Resume check\n\n## Not done\n\n'; } > "$TMP/m-strict-empty.md"
OUT="$(chk "$TMP/m-strict-empty.md" --strict 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'empty-section:Not done'; then ok "--strict refuses empty opt-in sections"; else bad "--strict must refuse empty opt-in sections" "rc=$RC out=$OUT"; fi

if command -v git >/dev/null 2>&1; then
# FEAT-34: git anchor names branch@HEAD and every uncommitted file, never touches them
G="$TMP/g"; git init -q "$G" && git -C "$G" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf 'wip\n' > "$G/wip file.txt"
OUT="$(bash "$CM" anchor --repo "$G" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q '"dirty":\["?? wip file.txt"\]' && [ -f "$G/wip file.txt" ]; then ok "anchor names dirty files (rc 2) and keeps them"; else bad "anchor should report dirty files" "rc=$RC out=$OUT"; fi
rm -f "$G/wip file.txt"
OUT="$(bash "$CM" anchor --repo "$G" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -qE '"anchor":"[^"]+@[0-9a-f]{7,}'; then ok "clean anchor ⇒ rc 0 with branch@HEAD"; else bad "clean anchor should be rc 0" "rc=$RC out=$OUT"; fi
else
  echo "  ⏭  git absent — anchor cases skipped"
fi
bash "$CM" anchor --repo "$TMP/scratch" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 1 ]; then ok "anchor on a non-repo ⇒ rc 1"; else bad "non-repo anchor should be rc 1" "rc=$RC"; fi

echo "── close-out-manifest: persist"
mkdir -p "$TMP/scratch" "$TMP/dest"
printf 'plain report\n' > "$TMP/scratch/report.md"
bash "$CM" persist --dest "$TMP/dest" --src "$TMP/scratch/report.md" >/dev/null 2>&1
if [ ! -e "$TMP/dest/report.md" ]; then ok "dry-run default copies nothing"; else bad "dry-run copied a file"; fi

if command -v gitleaks >/dev/null 2>&1; then
  bash "$CM" persist --dest "$TMP/dest" --src "$TMP/scratch/report.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -eq 0 ] && cmp -s "$TMP/scratch/report.md" "$TMP/dest/report.md"; then ok "clean file persisted byte-identical"; else bad "clean file should persist" "rc=$RC"; fi
  OUT="$(bash "$CM" persist --dest "$TMP/dest" --src "$TMP/scratch/report.md" --apply 2>/dev/null)"
  if printf '%s' "$OUT" | grep -q '"unchanged"'; then ok "2nd --apply is idempotent (unchanged)"; else bad "2nd apply should report unchanged" "$OUT"; fi

  p="gh""p_"; printf 'k = "%s%s"\n' "$p" "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)" > "$TMP/scratch/leak.md"
  bash "$CM" persist --dest "$TMP/dest" --src "$TMP/scratch/leak.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/dest/leak.md" ]; then ok "secret-shaped source refused"; else bad "secret source should be refused" "rc=$RC"; fi

  at="@"; printf 'contact: someone%sexample.org\n' "$at" > "$TMP/scratch/pii.md"
  bash "$CM" persist --dest "$TMP/dest" --src "$TMP/scratch/pii.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/dest/pii.md" ]; then ok "PII-shaped source refused"; else bad "PII source should be refused" "rc=$RC"; fi
else
  echo "  ⏭  gitleaks absent — secret-scan cases skipped (script fails closed without it)"
fi

if command -v gitleaks >/dev/null 2>&1; then
  echo "── close-out-manifest: persist bypass regressions (scan the exact bytes promoted)"
  mk() { printf '%s%s' "gh""p_" "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"; }

  # B1 parser-differential: an in-content scanner directive must not exempt the file
  mkdir -p "$TMP/b1"; printf 'k = "%s" # gitleaks%sallow\n' "$(mk)" ":" > "$TMP/b1/allow.md"
  bash "$CM" persist --dest "$TMP/db1" --src "$TMP/b1/allow.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/db1/allow.md" ]; then ok "inline scanner-allow directive does not exempt the file"; else bad "inline allow directive bypassed the scan" "rc=$RC"; fi

  # B2 a config planted next to the source cannot disable the scan
  mkdir -p "$TMP/b2"; printf 'k = "%s"\n' "$(mk)" > "$TMP/b2/cfg.md"
  printf '[extend]\nuseDefault = false\n[[rules]]\nid = "x"\nregex = "zzzqqq"\n' > "$TMP/b2/.gitleaks.toml"
  bash "$CM" persist --dest "$TMP/db2" --src "$TMP/b2/cfg.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/db2/cfg.md" ]; then ok "planted target-dir config does not disable the scan"; else bad "planted config bypassed the scan" "rc=$RC"; fi

  # B3 an inherited scanner config is ignored (scan still sees the secret)
  printf '[extend]\nuseDefault = false\n[[rules]]\nid = "x"\nregex = "zzzqqq"\n' > "$TMP/blind.toml"
  OUT="$(GITLEAKS_CONFIG="$TMP/blind.toml" bash "$CM" persist --dest "$TMP/db3" --src "$TMP/b2/cfg.md" --apply 2>/dev/null)"; RC=$?
  if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-secret'; then ok "inherited GITLEAKS_CONFIG is ignored (secret still refused)"; else bad "inherited config should be ignored" "rc=$RC out=$OUT"; fi

  # B4 binary content (NUL bytes) is refused before any scan
  mkdir -p "$TMP/b4"; printf 'x\000y\n' > "$TMP/b4/bin.md"
  OUT="$(bash "$CM" persist --dest "$TMP/db4" --src "$TMP/b4/bin.md" --apply 2>/dev/null)"; RC=$?
  if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-binary'; then ok "binary source refused"; else bad "binary source should be refused" "rc=$RC out=$OUT"; fi

  # B7 a secret split across two lines is reassembled by the line-joined view
  mkdir -p "$TMP/b7"; T="$(mk)"; printf 'k = "%s\n%s"\n' "${T%????????????????????}" "${T#????????????????????}" > "$TMP/b7/split.md"
  bash "$CM" persist --dest "$TMP/db7" --src "$TMP/b7/split.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/db7/split.md" ]; then ok "secret split across lines is refused"; else bad "split-line secret bypassed the scan" "rc=$RC"; fi

  # B8 CRLF line endings do not hide a secret
  mkdir -p "$TMP/b8"; printf 'k = "%s"\r\n' "$(mk)" > "$TMP/b8/crlf.md"
  bash "$CM" persist --dest "$TMP/db8" --src "$TMP/b8/crlf.md" --apply >/dev/null 2>&1; RC=$?
  if [ "$RC" -ne 0 ] && [ ! -e "$TMP/db8/crlf.md" ]; then ok "CRLF secret refused"; else bad "CRLF secret bypassed the scan" "rc=$RC"; fi

  # B5 a clean file whose relative name starts with '-' is still scanned and persisted
  mkdir -p "$TMP/b5"; printf 'plain\n' > "$TMP/b5/-dash.md"
  ( cd "$TMP/b5" && bash "$CM" persist --dest "$TMP/db5" --src "-dash.md" --apply >/dev/null 2>&1 ); RC=$?
  if [ "$RC" -eq 0 ] && cmp -s "$TMP/b5/-dash.md" "$TMP/db5/-dash.md"; then ok "leading-dash name scanned and persisted"; else bad "leading-dash clean file should persist" "rc=$RC"; fi
fi

# B6 TOCTOU: the source changes during the scan — only the scanned bytes may be promoted
FS="$TMP/mutscan"; MARK="INJECTED_AFTER_SCAN"
cat > "$FS" <<EOF
#!/usr/bin/env bash
f=""; for a in "\$@"; do [ -f "\$a" ] && f="\$a"; done
if grep -q "gh""p_" "\$f" 2>/dev/null; then exit 1; fi
# mutate the origin only while the source's own (staged) bytes are being scanned
[ -n "\${MUTATE:-}" ] && grep -qx 'race-payload' "\$f" 2>/dev/null && printf '$MARK\n' >> "\$MUTATE"
exit 0
EOF
chmod +x "$FS"
mkdir -p "$TMP/b6"; printf 'race-payload\n' > "$TMP/b6/race.md"
MUTATE="$TMP/b6/race.md" MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/db6" --src "$TMP/b6/race.md" --apply >/dev/null 2>&1; RC=$?
if [ ! -e "$TMP/db6/race.md" ] || ! grep -q "$MARK" "$TMP/db6/race.md"; then ok "TOCTOU: bytes changed after the scan are never promoted"; else bad "TOCTOU: promoted bytes the scanner never saw" "rc=$RC"; fi

# FEAT-26: replacing a different existing target keeps the previous version as a backup
if command -v gitleaks >/dev/null 2>&1; then
  mkdir -p "$TMP/bk" "$TMP/dbk"; printf 'old\n' > "$TMP/dbk/r.md"; printf 'new\n' > "$TMP/bk/r.md"
  bash "$CM" persist --dest "$TMP/dbk" --src "$TMP/bk/r.md" --apply >/dev/null 2>&1; RC=$?
  B="$(ls "$TMP/dbk" | grep '^r\.md\.bak\.' | head -1)"
  if [ "$RC" -eq 0 ] && [ -n "$B" ] && [ "$(cat "$TMP/dbk/$B")" = "old" ] && [ "$(cat "$TMP/dbk/r.md")" = "new" ]; then ok "changed target backed up before replace"; else bad "previous target should be kept as .bak" "rc=$RC files=$(ls "$TMP/dbk" | tr '\n' ' ')"; fi
fi

# review: destination that is a symlink or a directory is refused, nothing hidden left behind
mkdir -p "$TMP/ds" "$TMP/dsrc" "$TMP/elsewhere"; printf 'same\n' > "$TMP/dsrc/r.md"; printf 'same\n' > "$TMP/elsewhere/r.md"
ln -s "$TMP/elsewhere/r.md" "$TMP/ds/r.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/ds" --src "$TMP/dsrc/r.md" --apply 2>/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-dest-not-regular' && [ -L "$TMP/ds/r.md" ]; then ok "symlink destination refused (not reported unchanged)"; else bad "symlink destination must be refused" "rc=$RC out=$OUT"; fi
mkdir -p "$TMP/dd/r.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dd" --src "$TMP/dsrc/r.md" --apply 2>/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-dest-not-regular' && [ -z "$(ls -A "$TMP/dd/r.md")" ] && [ -z "$(ls -A "$TMP/dd" | grep -v '^r.md$')" ]; then ok "directory destination refused, no hidden temp"; else bad "directory destination must be refused cleanly" "rc=$RC out=$OUT dd=$(ls -A "$TMP/dd" "$TMP/dd/r.md" | tr '\n' ' ')"; fi
# review: control characters in a path are escaped, one valid JSON line per source
NL="$TMP/nl"; mkdir -p "$NL"; printf 'clean\n' > "$NL/a
b.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dnl" --src "$NL/a
b.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = "1" ] && printf '%s' "$OUT" | grep -q 'a\\nb.md'; then ok "newline in a path escaped as \\n (one JSON line)"; else bad "control chars must be JSON-escaped" "rc=$RC out=$OUT"; fi

# review: a source that cannot be persisted fails the run (rc 5), it is never silently skipped
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dms" --src "$TMP/nope.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'skipped-not-regular-file'; then ok "missing source ⇒ rc 5"; else bad "missing source must not exit 0" "rc=$RC out=$OUT"; fi
# review: two sources with the same basename must not overwrite each other
mkdir -p "$TMP/ca" "$TMP/cb"; printf 'from a\n' > "$TMP/ca/report.md"; printf 'from b\n' > "$TMP/cb/report.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dcol" --src "$TMP/ca/report.md" --src "$TMP/cb/report.md" --apply 2>/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-basename-collision' && [ "$(cat "$TMP/dcol/report.md")" = "from a" ]; then ok "basename collision refused, first report kept"; else bad "basename collision must be refused" "rc=$RC out=$OUT"; fi
# review: domestic Brazilian phone formats are PII (synthetic numbers, built at runtime)
D1="1""1"; P9="9""1234"; P4="56""78"
cpf_digits() { # 9 base digits -> 11-digit CPF with valid check digits (synthetic, runtime)
  local b="$1" i s d1 d2
  s=0; for i in 0 1 2 3 4 5 6 7 8; do s=$((s + ${b:$i:1} * (10 - i))); done
  d1=$(( (s * 10) % 11 )); [ "$d1" -eq 10 ] && d1=0
  s=0; for i in 0 1 2 3 4 5 6 7 8; do s=$((s + ${b:$i:1} * (11 - i))); done; s=$((s + d1 * 2))
  d2=$(( (s * 10) % 11 )); [ "$d2" -eq 10 ] && d2=0
  printf '%s%s%s' "$b" "$d1" "$d2"
}
CPF="$(cpf_digits "$(printf '%s%s%s' 314 159 265)")"
mkdir -p "$TMP/cpf"; printf 'doc %s end\n' "$CPF" > "$TMP/cpf/a.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/cpfd" --src "$TMP/cpf/a.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q refused-pii; then ok "unformatted CPF with valid checksum refused"; else bad "unformatted CPF must be refused" "rc=$RC out=$OUT"; fi
BAD="${CPF:0:10}$(( (${CPF:10:1} + 1) % 10 ))"
printf 'id %s end\n' "$BAD" > "$TMP/cpf/b.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/cpfd" --src "$TMP/cpf/b.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 0 ]; then ok "11-digit id with invalid CPF checksum not flagged"; else bad "invalid-checksum 11-digit id must pass" "rc=$RC out=$OUT"; fi
for ph in "($D1) $P9-$P4" "$D1 $P9-$P4" "$D1 $P9 $P4" "($D1)$P9$P4" "+55 $D1 $P9-$P4" "($D1) 3""123-$P4"; do
  mkdir -p "$TMP/ph"; printf 'call %s\n' "$ph" > "$TMP/ph/p.md"
  OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dph" --src "$TMP/ph/p.md" 2>/dev/null)"; RC=$?
  if [ "$RC" -eq 5 ] && printf '%s' "$OUT" | grep -q 'refused-pii'; then ok "phone '$ph' refused as PII"; else bad "phone '$ph' must be PII" "rc=$RC out=$OUT"; fi
done
# ... while a bare 10-digit run (timestamp) is not
printf 'ts 1759842000\n' > "$TMP/ph/t.md"
OUT="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dph" --src "$TMP/ph/t.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 0 ]; then ok "bare epoch timestamp is not PII"; else bad "timestamp should not be PII" "rc=$RC out=$OUT"; fi
# review: two replacements in the same second keep both previous versions
mkdir -p "$TMP/bb" "$TMP/dbb"; printf 'v0\n' > "$TMP/dbb/r.md"
printf 'v1\n' > "$TMP/bb/r.md"; MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dbb" --src "$TMP/bb/r.md" --apply >/dev/null 2>&1
printf 'v2\n' > "$TMP/bb/r.md"; MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dbb" --src "$TMP/bb/r.md" --apply >/dev/null 2>&1
if cat "$TMP/dbb"/r.md.bak.* 2>/dev/null | sort | tr '\n' ' ' | grep -q 'v0 v1'; then ok "rapid double replace keeps both backups"; else bad "a backup was overwritten" "$(ls "$TMP/dbb" | tr '\n' ' ')"; fi
# a scanner that errors on everything ⇒ scanner failure rc 3, never mislabelled as refused-secret
mkdir -p "$TMP/b9"; printf 'clean\n' > "$TMP/b9/ok.md"
OUT="$(MAOS_SECRET_SCANNER=false bash "$CM" persist --dest "$TMP/db9" --src "$TMP/b9/ok.md" --apply 2>&1)"; RC=$?
if [ "$RC" -eq 3 ] && ! printf '%s' "$OUT" | grep -q 'refused-secret' && [ ! -e "$TMP/db9/ok.md" ]; then ok "always-failing scanner reported as scanner error (rc 3)"; else bad "always-failing scanner should be rc 3" "rc=$RC out=$OUT"; fi

# a scanner blind to the positive control ⇒ fail closed (rc 3), nothing copied
MAOS_SECRET_SCANNER=true bash "$CM" persist --dest "$TMP/dest2" --src "$TMP/scratch/report.md" --apply >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 3 ] && [ ! -e "$TMP/dest2/report.md" ]; then ok "blind scanner ⇒ rc 3, nothing copied"; else bad "blind scanner should fail closed" "rc=$RC"; fi

echo "── close-out-manifest: clip"
CLIPF="$TMP/clipboard"
printf '#!/usr/bin/env bash\ncat > "%s"\n' "$CLIPF" > "$TMP/fakecopy"
printf '#!/usr/bin/env bash\ncat "%s"\n' "$CLIPF" > "$TMP/fakepaste"
printf '#!/usr/bin/env bash\nhead -c 3 "%s"\n' "$CLIPF" > "$TMP/lossypaste"
chmod +x "$TMP/fakecopy" "$TMP/fakepaste" "$TMP/lossypaste"

MAOS_CLIP_COPY="$TMP/fakecopy" MAOS_CLIP_PASTE="$TMP/fakepaste" bash "$CM" clip --file "$TMP/m.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 0 ]; then ok "verified clipboard round-trip ⇒ rc 0"; else bad "round-trip should verify" "rc=$RC"; fi

OUT="$(MAOS_CLIP_COPY="$TMP/fakecopy" MAOS_CLIP_PASTE="$TMP/lossypaste" bash "$CM" clip --file "$TMP/m.md" 2>&1)"; RC=$?
if [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'paste-mcp'; then ok "lossy read-back ⇒ rc 4 + paste-MCP fallback"; else bad "lossy read-back should be rc 4" "rc=$RC out=$OUT"; fi

OUT="$(MAOS_CLIP_COPY=/nonexistent/copy MAOS_CLIP_PASTE=/nonexistent/paste bash "$CM" clip --file "$TMP/m.md" 2>&1)"; RC=$?
if [ "$RC" -eq 4 ]; then ok "no clipboard tool ⇒ rc 4 (no fake success)"; else bad "missing tool should be rc 4" "rc=$RC"; fi

OUT="$(MAOS_CLIP_COPY="$TMP/fakecopy" MAOS_CLIP_PASTE= bash "$CM" clip --file "$TMP/m.md" 2>&1)"; RC=$?
if [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'incomplete-clip-override'; then ok "copy override without paste override ⇒ rc 4 incomplete-clip-override"; else bad "half a clipboard override must be refused clearly" "rc=$RC out=$OUT"; fi
OUT="$(MAOS_CLIP_COPY= MAOS_CLIP_PASTE="$TMP/fakepaste" bash "$CM" clip --file "$TMP/m.md" 2>&1)"; RC=$?
if [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'incomplete-clip-override'; then ok "paste override without copy override ⇒ rc 4 incomplete-clip-override"; else bad "half a clipboard override must be refused clearly (paste only)" "rc=$RC out=$OUT"; fi

echo "── close-out-manifest: no residue on failure paths (temps, signals, cleanup)"
# each case gets its own TMPDIR so residue is attributable; a clean exit leaves it empty
clean_dir() { [ -d "$1" ] && [ -z "$(ls -A "$1")" ]; }
newtmp() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; printf '%s' "$TMP/$1"; }
# BSD mktemp ignores $TMPDIR without a template, so a script that forgets one writes to the
# system temp root instead: also look there, for files newer than a marker holding a needle
SYS_T="$(dirname "$(mktemp -u)")"
leaked() { # leaked <marker> <needle> → rc 0 if a newer file under the system temp root holds it
  find "$SYS_T" -maxdepth 3 -type f -newer "$1" 2>/dev/null | while IFS= read -r f; do
    grep -qF "$2" "$f" 2>/dev/null && { echo "$f"; break; }
  done | grep -q .
}

# R1 blind positive control (die path) leaves no staged control behind
T1="$(newtmp r1)"; mkdir -p "$TMP/r1src"; printf 'clean\n' > "$TMP/r1src/a.md"
touch "$TMP/r1.mark"; sleep 1
TMPDIR="$T1" MAOS_SECRET_SCANNER=true bash "$CM" persist --dest "$TMP/dr1" --src "$TMP/r1src/a.md" --apply >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 3 ] && clean_dir "$T1" && ! leaked "$TMP/r1.mark" "probe""@""example.org"; then ok "blind control: no residue in TMPDIR"; else bad "blind control left residue" "rc=$RC left=$(ls -A "$T1" 2>/dev/null | tr '\n' ' ')"; fi

# R2 failing rename leaves no temp in the destination nor in TMPDIR
T2="$(newtmp r2)"; mkdir -p "$TMP/r2bin" "$TMP/r2src"; printf 'clean\n' > "$TMP/r2src/a.md"
printf '#!/bin/sh\nexit 1\n' > "$TMP/r2bin/mv"; chmod +x "$TMP/r2bin/mv"
PATH="$TMP/r2bin:$PATH" TMPDIR="$T2" MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dr2" --src "$TMP/r2src/a.md" --apply >/dev/null 2>&1; RC=$?
if [ "$RC" -ne 0 ] && clean_dir "$T2" && { [ ! -d "$TMP/dr2" ] || clean_dir "$TMP/dr2"; }; then ok "failed rename: no residue in destination or TMPDIR"; else bad "failed rename left residue" "rc=$RC dest=$(ls -A "$TMP/dr2" 2>/dev/null | tr '\n' ' ') tmp=$(ls -A "$T2" 2>/dev/null | tr '\n' ' ')"; fi

# R3 SIGINT in the middle of a scan: rc 130 and nothing left behind
T3="$(newtmp r3)"; mkdir -p "$TMP/r3src"; printf 'clean\n' > "$TMP/r3src/a.md"
cat > "$TMP/intscan" <<'EOF'
#!/usr/bin/env bash
# interrupt the close-out-manifest process: walk up until we find it, never signal anything else
# (a scan subshell shares the script's command line: signal the TOPMOST matching ancestor)
p="$PPID"; top=""
for _ in 1 2 3 4; do
  case "$(ps -o command= -p "$p" 2>/dev/null)" in *"$CM_UNDER_TEST"*) top="$p" ;; *) [ -n "$top" ] && break ;; esac
  p="$(ps -o ppid= -p "$p" | tr -d ' ')"
done
[ -n "$top" ] && kill -INT "$top"
exit 1
EOF
chmod +x "$TMP/intscan"
CM_UNDER_TEST="$CM" TMPDIR="$T3" MAOS_SECRET_SCANNER="$TMP/intscan" bash "$CM" persist --dest "$TMP/dr3" --src "$TMP/r3src/a.md" --apply >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 130 ] && clean_dir "$T3" && [ ! -e "$TMP/dr3/a.md" ]; then ok "SIGINT mid-scan: rc 130, no residue"; else bad "SIGINT mid-scan left residue or wrong rc" "rc=$RC left=$(ls -A "$T3" 2>/dev/null | tr '\n' ' ')"; fi

# R4 clip read-back never writes the handoff content to a temp file, even when terminated
# (TERM, not INT: bash swallows an INT that arrives while a child exits normally)
T4="$(newtmp r4)"; N4="handoff-$$-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 12)"; printf '%s\n' "$N4" > "$TMP/r4.md"; touch "$TMP/r4.mark"; sleep 1
cat > "$TMP/intpaste" <<EOF
#!/usr/bin/env bash
cat "$TMP/r4.md"
case "\$(ps -o command= -p "\$PPID" 2>/dev/null)" in *"\$CM_UNDER_TEST"*) kill -TERM "\$PPID" ;; esac
EOF
chmod +x "$TMP/intpaste"
CM_UNDER_TEST="$CM" TMPDIR="$T4" MAOS_CLIP_COPY=true MAOS_CLIP_PASTE="$TMP/intpaste" bash "$CM" clip --file "$TMP/r4.md" >/dev/null 2>&1; RC=$?
if clean_dir "$T4" && ! leaked "$TMP/r4.mark" "$N4"; then ok "clip read-back leaves no temp (rc=$RC)"; else bad "clip read-back left handoff content in TMPDIR" "rc=$RC left=$(ls -A "$T4" | tr '\n' ' ')"; fi

# R5 a cleanup that cannot remove its temps is reported (stderr + rc 6), never hidden
T5="$(newtmp r5)"; mkdir -p "$TMP/r5bin" "$TMP/r5src"; printf 'clean\n' > "$TMP/r5src/a.md"
printf '#!/bin/sh\nexit 1\n' > "$TMP/r5bin/rm"; chmod +x "$TMP/r5bin/rm"
OUT="$(PATH="$TMP/r5bin:$PATH" TMPDIR="$T5" MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/dr5" --src "$TMP/r5src/a.md" 2>&1)"; RC=$?
if [ "$RC" -eq 6 ] && printf '%s' "$OUT" | grep -q 'cleanup failed'; then ok "failed cleanup reported as rc 6"; else bad "failed cleanup must be rc 6 + stderr" "rc=$RC out=$OUT"; fi
rm -rf "$T5"

# review: an unexpected fault is reported log-only (line + rc), with no report content
mkdir -p "$TMP/uf/src" "$TMP/uf/ro"; printf 'body-%s\n' "uniq7" > "$TMP/uf/src/a.md"; chmod 555 "$TMP/uf/ro"
if [ -w "$TMP/uf/ro" ]; then # root ignores the mode bits: no fault can be induced this way
  chmod 755 "$TMP/uf/ro"; echo "  ⏭  read-only dir is writable (root) — fault case skipped"
else
ERR="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/uf/ro/sub" --src "$TMP/uf/src/a.md" --apply 2>&1 >/dev/null)"; RC=$?
chmod 755 "$TMP/uf/ro"
if [ "$RC" -ne 0 ] && printf '%s' "$ERR" | grep -q 'unexpected fault at line' && ! printf '%s' "$ERR" | grep -q 'uniq7'; then ok "unexpected fault reported log-only, no content"; else bad "unexpected fault must be reported log-only" "rc=$RC err=$ERR"; fi
fi
# ... and a legitimate refusal is not reported as a fault
mkdir -p "$TMP/uf2"; printf 'call (%s) %s-%s\n' "$D1" "$P9" "$P4" > "$TMP/uf2/p.md"
ERR="$(MAOS_SECRET_SCANNER="$FS" bash "$CM" persist --dest "$TMP/uf2d" --src "$TMP/uf2/p.md" 2>&1 >/dev/null)"; RC=$?
if [ "$RC" -eq 5 ] && ! printf '%s' "$ERR" | grep -q 'unexpected fault'; then ok "refusal is not a fault"; else bad "refusal must not trip the fault report" "rc=$RC err=$ERR"; fi

echo ""
echo "  pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
