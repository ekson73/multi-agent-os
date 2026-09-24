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
#  *           line/path STILL fires (anti-over-suppression); (4) entropy floor
#  *           kills only zero-entropy junk; (5) canary — the armed fixture MUST
#  *           produce findings, or the whole gate is decorative.
#  *
#  *           Entropy measures randomness, not intent: placeholders and weak
#  *           human passwords occupy the SAME entropy band (password123=3.278 >
#  *           Passw0rd=2.750), so NO entropy threshold separates them. Recall
#  *           lives in the rule (value-captured secretGroup + a low 2.0 floor
#  *           that only drops pure-repeat junk); precision lives in the
#  *           line-anchored, value-exact allowlist. Never raise the entropy
#  *           floor to suppress a placeholder — add an anchored allowlist line.
#  */
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/../.gitleaks.toml"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

command -v gitleaks >/dev/null || { echo "SKIP: gitleaks not installed"; exit 0; }
[ -f "$CONFIG" ] || { echo "FAIL: $CONFIG not found"; exit 1; }

# ── scan helper ──────────────────────────────────────────────────────────────
# Builds a throwaway git repo from a heredoc body, scans full-history with the
# REAL config, and echoes one "RULE\tLINE\tSECRET" row per finding.
scan() {
  local body="$1" sbx out
  sbx="$(mktemp -d)"
  printf '%s' "$body" > "$sbx/creds.env"
  ( cd "$sbx" && git init -q && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm fixture ) >/dev/null 2>&1
  out="$sbx/report.json"
  # gitleaks exits non-zero when leaks are found; that is data here, not an error.
  gitleaks detect --source "$sbx" --config "$CONFIG" --no-banner \
    --report-format json --report-path "$out" >/dev/null 2>&1 || true
  python3 - "$out" <<'PY'
import json,sys
try: data=json.load(open(sys.argv[1]))
except Exception: data=[]
for f in data:
    print(f"{f['RuleID']}\t{f['StartLine']}\t{f['Secret']}")
PY
  rm -rf "$sbx"
}
# count findings for a given rule id in a scan result
count_rule() { grep -c "^$2" <<<"$1" || true; }
has_secret() { grep -qF "	$2" <<<"$1"; }   # tab before value = Secret column

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

# ══ 3. ENTROPY FLOOR — only pure-repeat junk is dropped, nothing real ════════
# xxxxxxxx has entropy 0.0 → dropped. changeme has 2.750 → kept (proven in §2).
junk=$'DB_PASSWORD=xxxxxxxx\n'
r_junk="$(scan "$junk")"
if [ -z "$r_junk" ]; then ok "ENTROPY: zero-entropy junk (xxxxxxxx) correctly dropped"
else bad "ENTROPY: xxxxxxxx produced a finding — floor too low"; fi

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

# ── summary ──────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
