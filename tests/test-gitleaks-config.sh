#!/usr/bin/env bash
# /**
#  * test-gitleaks-config.sh — TDD contract for .gitleaks.toml (secret-scan config)
#  * @context  The gitleaks config is the repo's ONLY secret gate. A silent
#  *           false-negative (a real weak credential the rules skip) or a
#  *           false-positive-fix that over-suppresses (an allowlist that hides
#  *           real secrets) are BOTH security regressions — #433 took 4 rounds
#  *           because an allowlist widened into a false-negative hole.
#  * @reason   Council-of-MoE "Approach C-hardened" decision (2026-09-24):
#  *           detection carries recall, allowlist carries precision, and a
#  *           CANARY proves the config is ARMED (0 findings on the armed
#  *           fixture = the test itself is broken, not the code clean).
#  * @impact   Pins, against the REAL gitleaks binary + the REAL committed
#  *           .gitleaks.toml: (1) weak real creds DETECTED; (2) documented
#  *           placeholders SUPPRESSED; (3) a real secret in an allowlist-shaped
#  *           line/path STILL fires (anti-over-suppression); (4) no entropy
#  *           floor silently drops low-entropy credentials; (5) canary — the
#  *           armed fixture MUST produce findings, or the whole gate is
#  *           decorative.
#  *
#  *           Entropy measures randomness, not intent: placeholders and weak
#  *           human passwords occupy the SAME entropy band (password123=3.278 >
#  *           Passw0rd=2.750), AND a non-repeat weak secret like `abababab` has
#  *           Shannon entropy 1.0 — so NO entropy threshold separates real from
#  *           placeholder without hiding real credentials. Recall lives in the
#  *           rule (value-captured secretGroup, NO entropy floor); precision
#  *           lives in the line-anchored, value-exact allowlist. Never add an
#  *           entropy floor to suppress a placeholder — add an anchored
#  *           allowlist line.
#  */
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/../.gitleaks.toml"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

command -v gitleaks >/dev/null || { echo "FAIL: gitleaks not installed — the secret gate cannot be verified"; exit 1; }
[ -f "$CONFIG" ] || { echo "FAIL: $CONFIG not found"; exit 1; }

# ── scan helper ──────────────────────────────────────────────────────────────
# Builds a throwaway git repo from a heredoc body, scans full-history with the
# REAL config, and echoes one "RULE\tLINE\tSECRET" row per finding.
#
# Exit-code discipline (CodeRabbit): gitleaks exits 1 for leaks AND for its own
# errors (bad config, parse failure). We must NOT conflate a scanner CRASH with
# "0 findings" — that is fail-open. So: exit 0 (clean) or 1 (leaks) is DATA;
# any OTHER exit, or a missing/unreadable report, is a hard FAIL that aborts the
# whole suite (set -e via the `return 1` surfacing) rather than passing silently.
scan() {
  local body="$1" sbx out rc
  sbx="$(mktemp -d)"
  # EXIT trap: remove the fixture dir on normal completion AND early failure.
  trap 'rm -rf "$sbx"' RETURN
  printf '%s' "$body" > "$sbx/creds.env"
  ( cd "$sbx" && git init -q && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm fixture ) >/dev/null 2>&1
  out="$sbx/report.json"
  gitleaks detect --source "$sbx" --config "$CONFIG" --no-banner \
    --report-format json --report-path "$out" >/dev/null 2>&1
  rc=$?
  # 0 = clean, 1 = leaks found; anything else is a scanner error.
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
    echo "SCANNER-ERROR: gitleaks exited $rc on a fixture scan" >&2
    return 2
  fi
  # The report must exist and be valid JSON, or the scan did not complete.
  if [ ! -r "$out" ]; then
    echo "SCANNER-ERROR: report $out missing/unreadable (exit $rc)" >&2
    return 2
  fi
  python3 - "$out" <<'PY'
import json,sys
try:
    data=json.load(open(sys.argv[1]))
except Exception as e:
    sys.stderr.write(f"SCANNER-ERROR: report not valid JSON: {e}\n")
    sys.exit(2)
for f in data:
    print(f"{f['RuleID']}\t{f['StartLine']}\t{f['Secret']}")
PY
}
# count findings for a given rule id in a scan result
count_rule() { grep -c "^$2" <<<"$1" || true; }
# has_secret: TRUE only when the COMPLETE Secret column (3rd tab field) equals
# $2 — a prefix like `changeme` must NOT match a row whose Secret is
# `changemechangeme`, or the recall check for one value free-rides on another.
has_secret() {
  local result="$1" want="$2" line secret
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    secret="${line#*$'\t'}"      # strip RULE\t
    secret="${secret#*$'\t'}"    # strip LINE\t  → leaves exact Secret
    [ "$secret" = "$want" ] && return 0
  done <<<"$result"
  return 1
}

# ══ 1. CANARY — the armed fixture MUST produce findings ══════════════════════
# If this fixture ever yields 0 findings, the rules are broken/disabled and
# every "clean" scan below is meaningless. This is the anti-theater guard.
armed=$'DB_PASSWORD=changeme\nJWT_SECRET=changemechangemeXY\n'
r_armed="$(scan "$armed")"
n_armed="$(grep -c . <<<"$r_armed" || true)"
if [ "${n_armed:-0}" -ge 2 ]; then ok "CANARY: armed fixture yields findings ($n_armed)"
else bad "CANARY: armed fixture produced $n_armed findings — GATE IS DECORATIVE"; fi

# ══ 2. RECALL — weak real credentials MUST be detected (the #433 follow-up) ═══
weak=$'DB_PASSWORD=changeme\npassword=Passw0rdX\nDB_PASSWORD=password123\nJWT_SECRET=changemechangeme\nsigning_key=aB3xK9mP2qL7wE4rT\n'
r_weak="$(scan "$weak")"
for v in changeme Passw0rdX password123 changemechangeme aB3xK9mP2qL7wE4rT; do
  if has_secret "$r_weak" "$v"; then ok "RECALL: weak credential detected — $v"
  else bad "RECALL: weak credential SILENTLY MISSED — $v"; fi
done

# ══ 3. NO ENTROPY FLOOR — low-entropy credentials are NOT silently dropped ═══
# A non-repeat weak secret (abababab, Shannon entropy 1.0) and a repeated one
# (xxxxxxxx, entropy 0.0) are both credential-shaped and MUST fire — an entropy
# floor would hide them. Placeholders are suppressed by the allowlist (§4), not
# by entropy. This asserts the floor removal (F2) stays removed.
lowent=$'DB_PASSWORD=abababab\nDB_PASSWORD=xxxxxxxx\n'
r_lowent="$(scan "$lowent")"
if has_secret "$r_lowent" "abababab" && has_secret "$r_lowent" "xxxxxxxx"; then
  ok "NO-FLOOR: low-entropy creds (abababab=1.0, xxxxxxxx=0.0) still detected"
else bad "NO-FLOOR: a low-entropy credential was silently dropped — entropy floor regressed"; fi

# ══ 4. PRECISION — documented placeholders MUST be suppressed ════════════════
# Exactly the forms the #433 allowlist covers: bare env, JSON, commented env.
ph=$'BITBUCKET_APP_PASSWORD=your_app_password\n        "BITBUCKET_APP_PASSWORD": "your_app_password",\n# BITBUCKET_ACCOUNT_JANE_APP_PASSWORD=your_app_password_here\n'
r_ph="$(scan "$ph")"
if [ -z "$r_ph" ]; then ok "PRECISION: documented placeholders suppressed (all 3 forms)"
else bad "PRECISION: a documented placeholder leaked a finding: $r_ph"; fi

# ══ 5. ANTI-OVER-SUPPRESSION — a REAL secret in allowlist shape STILL fires ══
# The red-team trap: a genuine secret that merely ends with / is glued after
# the placeholder token must NOT be swallowed by the exemption.
trap_cases=$'BITBUCKET_APP_PASSWORD=SuperSecret2026:your_app_password\nBITBUCKET_APP_PASSWORD=your_app_password'"'"'ActualSecret123'"'"'\n'
r_trap="$(scan "$trap_cases")"
n_trap="$(grep -c . <<<"$r_trap" || true)"
if [ "${n_trap:-0}" -ge 2 ]; then ok "ANTI-BYPASS: real secret glued to placeholder still fires ($n_trap)"
else bad "ANTI-BYPASS: a real secret near the placeholder was suppressed ($n_trap/2)"; fi

# ══ 6. AWS-URI anti-bypass (F1) — real secret ENDING in a reference URI fires ═
# The vek-db-password allowlist exempts a value that IS an aws:/// reference URI
# (anchored ^…$ on the extracted secret). A real password that merely ENDS in
# such a URI (CorrectHorse1!aws:///foo#BAR) must NOT be swallowed, while the
# pure reference URI stays suppressed.
awsmix=$'db_password=CorrectHorse1aws:///foo#BAR\n'
r_awsmix="$(scan "$awsmix")"
if has_secret "$r_awsmix" "CorrectHorse1aws:///foo#BAR"; then ok "AWS-URI: real secret ending in a reference URI still fires"
else bad "AWS-URI: a real secret ending in aws:/// was suppressed (substring bypass)"; fi
awspure=$'db_password=aws:///vek-sales/env/hml#VEK_DB_PASSWORD\n'
r_awspure="$(scan "$awspure")"
if [ -z "$r_awspure" ]; then ok "AWS-URI: pure reference URI correctly suppressed"
else bad "AWS-URI: a legitimate SM reference URI produced a finding"; fi

# ── summary ──────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
