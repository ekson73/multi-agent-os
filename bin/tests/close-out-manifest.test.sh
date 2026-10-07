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

echo "── close-out-manifest: check"
full_manifest > "$TMP/m.md"
if bash "$CM" check --manifest "$TMP/m.md" >/dev/null 2>&1; then ok "complete manifest passes"; else bad "complete manifest should pass" "rc=$?"; fi

grep -v '^## Artifact index' "$TMP/m.md" > "$TMP/m-noidx.md"
OUT="$(bash "$CM" check --manifest "$TMP/m-noidx.md" 2>/dev/null)"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'Artifact index'; then ok "missing section ⇒ rc 2 and named"; else bad "missing section should fail rc 2" "rc=$RC out=$OUT"; fi

sed 's/^command: .*/command:/' "$TMP/m.md" > "$TMP/m-nocmd.md"
bash "$CM" check --manifest "$TMP/m-nocmd.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "empty recovery command ⇒ rc 2"; else bad "empty recovery command should fail" "rc=$RC"; fi

sed 's/^delegates_gate: PASS/delegates_gate: PENDING/' "$TMP/m.md" > "$TMP/m-gate.md"
bash "$CM" check --manifest "$TMP/m-gate.md" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then ok "delegates gate not PASS ⇒ fail closed"; else bad "non-PASS gate should fail" "rc=$RC"; fi

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
if [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'no-readback-tool'; then ok "copy without read-back tool ⇒ rc 4 no-readback-tool"; else bad "missing read-back tool should be rc 4 no-readback-tool" "rc=$RC out=$OUT"; fi

echo ""
echo "  pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
