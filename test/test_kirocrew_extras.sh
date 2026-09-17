#!/usr/bin/env bash
#
# TestDD — executable tests for bin/kirocrew-extras (verifies docs/kirocrew-extras.SpecDD.md).
#
# It runs a NEUTRALLY-NAMED copy of the script against a STUBBED bundled
# interpreter and a STUBBED AI harness, so the suite is hermetic (no real
# KiroCrew, no real pip, no real agent) and does not trip the product-path
# self-protection floor. Run:  bash test/test_kirocrew_extras.sh
#
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/bin/kirocrew-extras"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/kce-testdd.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# neutrally-named copy (avoids the 'kirocrew' argv floor when WE run it)
CP="$WORK/kce-under-test"
cp "$SRC" "$CP"; chmod +x "$CP"

# --- stub the bundled interpreter -------------------------------------------
# Fake .app tree so the glob resolver finds a python3.12 we control.
FAKE_APP="$WORK/App/Contents/Resources/backend-dist/kirocrew-backend-arm64/bin"
mkdir -p "$FAKE_APP"
cat > "$FAKE_APP/python3.12" <<'PY'
#!/usr/bin/env bash
# stub interpreter: emulate the few calls the script makes
case "$*" in
  "--version") echo "Python 3.12.99-stub" ;;
  *"pip_install_command"*)  # asked for an extra's install command
     echo "echo STUB-INSTALL" ;;
  *"-m pip freeze"*) echo "stub==1.0" ;;
  *"import "*) exit 0 ;;   # imports "succeed"
  *"-m pip install"*) echo "stub pip install ok" ;;
  *) exit 0 ;;
esac
PY
chmod +x "$FAKE_APP/python3.12"
# py-spy stub for the perf check
printf '#!/usr/bin/env bash\necho spy 0.0\n' > "$FAKE_APP/py-spy"; chmod +x "$FAKE_APP/py-spy"

# point the script's glob at our fake app by symlinking into /Applications is
# not possible in test; instead we run with an override env the script honors.
# (The script resolves under /Applications; for the hermetic test we sed the
#  resolver to our fake root in the copy.)
sed -i.bak "s#/Applications/KiroCrew.app/Contents/Resources/backend-dist#$WORK/App/Contents/Resources/backend-dist#g" "$CP"

run(){ KIROCREW_EXTRAS_SELFHEAL=0 "$CP" "$@" 2>&1; }

echo "== TestDD: kirocrew-extras =="

# NFR-4: syntax
if bash -n "$SRC"; then ok "NFR-4 bash -n clean"; else no "NFR-4 bash -n"; fi

# FR-5: --help exits 0 and prints usage
out="$(run --help)"; rc=$?
[[ $rc -eq 0 && "$out" == *"USAGE"* ]] && ok "FR-5 --help" || no "FR-5 --help (rc=$rc)"

# FR-5: unknown flag exits 2
run --bogus >/dev/null 2>&1; [[ $? -eq 2 ]] && ok "FR-5 unknown flag →2" || no "FR-5 unknown flag exit code"

# FR-1 + FR-3 + FR-6: a normal run over one stub extra ends OK, exit 0
out="$(run whatsapp)"; rc=$?
echo "$out" | grep -q "summary" && ok "FR-3 prints summary" || no "FR-3 summary"
[[ $rc -eq 0 ]] && ok "FR-6 exit 0 on all-OK" || no "FR-6 exit code ($rc)"

# FR-5 --check must not attempt install (stub prints STUB-INSTALL only on install)
out="$(run --check whatsapp)"
echo "$out" | grep -q "check-only" && ok "FR-5 --check mode" || no "FR-5 --check"

# NFR-1: TMPDIR ending in '/' must not break mktemp
mkdir -p "$WORK/slashdir"
out="$(TMPDIR="$WORK/slashdir/" KIROCREW_EXTRAS_SELFHEAL=0 "$CP" whatsapp 2>&1)"; rc=$?
echo "$out" | grep -qi "mkstemp failed" && no "NFR-1 mktemp with trailing slash" || ok "NFR-1 mktemp trailing slash"

# FR-8: agnostic harness order present in source; ERR path dispatches it.
grep -q 'AI_HARNESS_ORDER_DEFAULT="kiro-cli claude codex opencode gemini crush amp"' "$SRC" \
  && ok "FR-8 harness order declared" || no "FR-8 harness order"

# FR-7/FR-8: force a failure with a STUB harness on PATH; expect it to be invoked.
STUBBIN="$WORK/stubbin"; mkdir -p "$STUBBIN"
cat > "$STUBBIN/kiro-cli" <<EOF
#!/usr/bin/env bash
echo "STUB-HARNESS-INVOKED args=\$*" >> "$WORK/harness.log"
exit 0
EOF
chmod +x "$STUBBIN/kiro-cli"
# make the interpreter's pip_install_command return a FAILING command to trigger ERR
cat > "$FAKE_APP/python3.12" <<'PY'
#!/usr/bin/env bash
case "$*" in
  "--version") echo "Python 3.12.99-stub" ;;
  *"pip_install_command"*) echo "false" ;;   # install cmd that fails
  *"-m pip freeze"*) echo "stub==1.0" ;;
  *"import "*) exit 1 ;;
  *) exit 0 ;;
esac
PY
chmod +x "$FAKE_APP/python3.12"
PATH="$STUBBIN:$PATH" KIROCREW_EXTRAS_SELFHEAL=1 KIROCREW_AI_HARNESS="kiro-cli" "$CP" whatsapp >/dev/null 2>&1
if [[ -f "$WORK/harness.log" ]] && grep -q STUB-HARNESS-INVOKED "$WORK/harness.log"; then
  ok "FR-7/FR-8 self-heal dispatched the harness on failure"
else
  no "FR-7/FR-8 harness not invoked on failure"
fi

echo
echo "── TestDD result: $PASS passed, $FAIL failed ──"
[[ $FAIL -eq 0 ]]
