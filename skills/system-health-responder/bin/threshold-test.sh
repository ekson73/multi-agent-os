#!/usr/bin/env bash
# threshold-test.sh — unit tests for the round-4 threshold decision cores (EKO-90-round4).
# Drives the collector's `--cpu-load-status` / `--xprotect-status` entrypoints with synthetic inputs (no
# awk/logic duplication — the test exercises the EXACT production cpu_load_status() / xprotect_status()).
#
# Two false-positive classes this session surfaced, and the assertions that pin their fixes:
#   • CPU: a transient 1-min burst (load1 high, load5 settled) must WARN, never CRIT — crit requires
#     SUSTAINED load5. (Empirical: load1=27.33/12cores tripped a false-crit that settled in ~4 min.)
#   • XProtect: age-alone conflates "genuinely stale" with "Apple hasn't shipped". With auto-update ON the
#     freshness self-heals → 47d-but-latest is honestly OK, never crit; with auto-update OFF (the real risk)
#     the full age escalation applies. (Empirical: 5347 IS Apple's latest for macOS 26.5.2, auto-update on.)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="${THRESHOLD_COLLECTOR:-$DIR/../collectors/system-health-guardian.sh}"
[ -f "$COLLECTOR" ] || { echo "FATAL: collector not found: $COLLECTOR" >&2; exit 2; }
RESPONDER="${THRESHOLD_RESPONDER:-$DIR/health-respond.sh}"
[ -f "$RESPONDER" ] || { echo "FATAL: responder not found: $RESPONDER" >&2; exit 2; }

PASS=0; FAIL=0
ck() { # ck "<label>" "<got>" "<want>"
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: $1 → got '$2' want '$3'"; fi
}
cpu() { "$COLLECTOR" --cpu-load-status "$@" 2>/dev/null; }   # load1 load5 ncpu warn_ratio crit_ratio
xp()  { "$COLLECTOR" --xprotect-status "$@" 2>/dev/null; }   # age autoupdate warn crit selfheal
tc()  { "$COLLECTOR" --top-consumer-status "$@" 2>/dev/null; } # pct(per-core) ncpu warn_pct crit_ratio(of total)
cm()  { "$RESPONDER" --comm-match "$1" "$2" 2>/dev/null; }     # live_raw want_raw → match|nomatch (#131 recycle guard)
dn()  { "$RESPONDER" --denied "$1" 2>/dev/null; }             # comm → denied|allowed (basename-normalized denylist, @145)
cst() { "$COLLECTOR" --counts-status "$@" 2>/dev/null; }      # zombie_ct thread_ct z_warn z_crit t_warn t_crit → status (round-6 F4)
mps() { "$COLLECTOR" --mem-pressure-status "$1" 2>/dev/null; } # dispatch-level → status (round-6 F5)
OFC="$DIR/offender-containment.sh"
hashf() { md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | awk '{print $1}'; }  # portable md5 (macOS md5 / Linux md5sum)
# responder integration: run against a SYNTHETIC contract, hermetically (temp contract + temp state, no notify),
# in the default dry-run — residue is still COMPUTED + printed even when seed-throttled, so grepping stdout is sound.
respond_out() { local tc ts; tc="$(mktemp)"; ts="$(mktemp -d)"; printf '%s' "$1" >"$tc"
  SHR_CONTRACT="$tc" SHR_STATE_DIR="$ts" SHR_NO_NOTIFY=1 bash "$RESPONDER" 2>/dev/null; rm -f "$tc"; rm -rf "$ts"; }
ck_has()    { case "$2" in *"$3"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "  FAIL: $1 → missing '$3'";; esac; }
ck_hasnot() { case "$2" in *"$3"*) FAIL=$((FAIL+1)); echo "  FAIL: $1 → unexpectedly present '$3'";; *) PASS=$((PASS+1));; esac; }

echo "── cpu_load_status (warn=load1 spiky · crit=load5 sustained) ──"
ck "burst load1=27 load5=6 12c → warn (NOT crit) [the false-crit fix]" "$(cpu 27.33 6.0 12 0.90 1.50)" "warn"
ck "sustained load5=20 12c → crit"                                     "$(cpu 20 20 12 0.90 1.50)"    "crit"
ck "calm load1=2 load5=2 12c → ok"                                     "$(cpu 2 2 12 0.90 1.50)"      "ok"
ck "warn-load1 + crit-load5 → crit"                                    "$(cpu 15 19 12 0.90 1.50)"    "crit"
ck "just-over-warn load1=11 load5=3 12c → warn"                        "$(cpu 11 3 12 0.90 1.50)"     "warn"
ck "load5 alone crit, load1 calm → crit (sustained detected)"          "$(cpu 3 19 12 0.90 1.50)"     "crit"
ck "at-warn-boundary load1=10.8 (0.90*12) → warn"                      "$(cpu 10.8 5 12 0.90 1.50)"   "warn"

echo "── xprotect_status (auto-update-gated freshness) ──"
ck "auto-ON 47d → ok (self-healing, <60 window) [the false-warn fix]"  "$(xp 47 on 30 60 60)"  "ok"
ck "auto-ON 65d → warn (unusually long)"                               "$(xp 65 on 30 60 60)"  "warn"
ck "auto-ON 9999d → warn (NEVER crit while self-healing)"              "$(xp 9999 on 30 60 60)" "warn"
ck "auto-OFF 47d → warn (the real risk surfaces)"                      "$(xp 47 off 30 60 60)" "warn"
ck "auto-OFF 65d → crit (real-risk escalation)"                        "$(xp 65 off 30 60 60)" "crit"
ck "auto-OFF 10d → ok"                                                 "$(xp 10 off 30 60 60)" "ok"

echo "── xprotect_status UNKNOWN (probe failed → fail-safe, warn-capable NEVER crit) [v1.4.1, CodeRabbit] ──"
ck "unknown 10d → ok (below warn)"                                     "$(xp 10 unknown 30 60 60)"   "ok"
ck "unknown 47d → warn (past warn horizon)"                            "$(xp 47 unknown 30 60 60)"   "warn"
ck "unknown 9999d → warn (NEVER crit — probe error ≠ false-crit)"      "$(xp 9999 unknown 30 60 60)" "warn"

echo "── top_consumer_status (ncpu-aware: warn=per-core actionable, crit=fraction of TOTAL) [v1.5.0, round-5 #1] ──"
ck "130.7% @12c → warn (1.3 cores ≠ system crit) [the live false-crit fix]" "$(tc 130.7 12 70 0.50)" "warn"
ck "700% @12c → crit (eats ~7 of 12 cores — genuine)"                       "$(tc 700 12 70 0.50)"   "crit"
ck "600% @12c → crit (0.50*12*100 boundary)"                                "$(tc 600 12 70 0.50)"   "crit"
ck "85% @12c → warn (>1 core, renice-actionable, not crit)"                 "$(tc 85 12 70 0.50)"    "warn"
ck "50% @12c → ok (below per-core warn)"                                    "$(tc 50 12 70 0.50)"    "ok"
ck "90% @1core → crit (ncpu=1 fail-safe: crit_pct=max(50,70)=70)"           "$(tc 90 1 70 0.50)"     "crit"
ck "60% @1core → ok (below warn on single core)"                            "$(tc 60 1 70 0.50)"     "ok"

echo "── comm_match (pid-recycle identity guard: EXACT normalized, no substring) [v1.5.1, round-5 #2, CodeRabbit #131] ──"
ck "recycled 'foo-helper' vs contract 'foo' → nomatch (the substring false-match bug)"  "$(cm foo-helper foo)"     "nomatch"
ck "reverse 'foo' vs 'foo-helper' → nomatch"                                             "$(cm foo foo-helper)"     "nomatch"
ck "empty live vs 'foo' → nomatch (proc gone)"                                           "$(cm '' foo)"             "nomatch"
ck "'foo' vs empty want → nomatch (empty-want_c authorize-anything hole)"                "$(cm foo '')"             "nomatch"
ck "exact 'foo' vs 'foo' → match"                                                        "$(cm foo foo)"            "match"
ck "case 'Superset' vs 'superset' → match (case-insensitive)"                            "$(cm Superset superset)"  "match"
ck "path '/A/MacOS/Node' vs 'Node' → match (basename normalize)"                         "$(cm /A/MacOS/Node Node)" "match"
ck "similar 'node' vs 'nodejs' → nomatch (not equal, no substring widening)"             "$(cm node nodejs)"        "nomatch"

echo "── denied() basename-normalized denylist (sensitive-proc protection on PATH comm) [v1.7.1, CodeRabbit @145] ──"
ck "'/usr/local/bin/op' → denied (op whole-word now matches basename, not just bare 'op')" "$(dn /usr/local/bin/op)"  "denied"
ck "bare 'op' → denied (whole-word preserved)"                                             "$(dn op)"                 "denied"
ck "'top' → allowed (op whole-word NOT over-matched — the exception still holds)"          "$(dn top)"                "allowed"
ck "'/Applications/1Password.app/Contents/MacOS/1Password' → denied (substring on basename)" "$(dn /Applications/1Password.app/Contents/MacOS/1Password)" "denied"
ck "'/opt/homebrew/bin/claude' → denied (path comm still protected)"                        "$(dn /opt/homebrew/bin/claude)" "denied"
ck "'Google Chrome Helper' → allowed (not on denylist)"                                     "$(dn 'Google Chrome Helper')" "allowed"

echo "── counts_status (F4: env-thresholded zombies ⊕ optional thread high-water) [round-6] ──"
ck "z=3 t=8000 zw=5 → ok (below zombie warn; threads disabled)"          "$(cst 3 8000 5 20 0 0)"       "ok"
ck "z=7 → warn (zombie env threshold, was hardcoded pre-round-6)"        "$(cst 7 8000 5 20 0 0)"       "warn"
ck "z=25 → crit (zombie crit)"                                           "$(cst 25 1 5 20 0 0)"         "crit"
ck "thread threshold 0 = DISABLED → ok even at 9000 threads (no false default)" "$(cst 0 9000 5 20 0 0)" "ok"
ck "thread high-water ENABLED (tw=8000) → warn at 9000"                  "$(cst 0 9000 5 20 8000 12000)" "warn"
ck "thread high-water crit (tc=8000) → crit at 9000"                     "$(cst 0 9000 5 20 4000 8000)" "crit"
ck "zombie env-override zw=1 → warn at 2 zombies"                        "$(cst 2 10 1 3 0 0)"          "warn"

echo "── mem_pressure_status (F5: kern dispatch level → status, never-fabricate-crit) [round-6] ──"
ck "level 1 → ok (normal)"                                    "$(mps 1)"   "ok"
ck "level 2 → warn (the false-ok fix: available% can read ok here)" "$(mps 2)" "warn"
ck "level 4 → crit (kernel critical)"                         "$(mps 4)"   "crit"
ck "level 99 → ok (unexpected → NEVER fabricate crit)"        "$(mps 99)"  "ok"
ck "empty → ok (sysctl unreadable → neutral, available% governs)" "$(mps '')" "ok"
ck "non-numeric 'xyz' → ok (fail-safe)"                       "$(mps xyz)" "ok"

echo "── F1 responder: cpu BRANCH load-driven crit must SURFACE (was silently dropped) [round-6] ──"
F1_LOAD='{"system":{"status":"crit","branches":{"cpu":{"status":"crit","root_fail":"load1","leaves":{"load1":{"value":20,"load5":19,"ncpu":12},"top_consumer":{"status":"ok"}}}}}}'
ck_has "load-driven crit (root_fail=load1, top_consumer ok) → HITL residue surfaces" "$(respond_out "$F1_LOAD")" "cpu=crit load-driven"
F1_TOP='{"system":{"status":"warn","branches":{"cpu":{"status":"warn","root_fail":"top_consumer","leaves":{"load1":{"value":5,"load5":5,"ncpu":12},"top_consumer":{"status":"warn","comm":"x","pct":80}}}}}}'
ck_hasnot "root_fail=top_consumer → NO load-driven line (already handled above, no double-report)" "$(respond_out "$F1_TOP")" "load-driven"

echo "── F3 responder: network 'informational' = no residue; a real fault still surfaces [round-6] ──"
F3_INFO='{"system":{"status":"ok","branches":{"network":{"status":"informational"}}}}'
ck_hasnot "network=informational → NO residue (honest not-thresholded label)" "$(respond_out "$F3_INFO")" "network="
F3_WARN='{"system":{"status":"warn","branches":{"network":{"status":"warn"}}}}'
ck_has "network=warn → residue still surfaces (real fault not suppressed)" "$(respond_out "$F3_WARN")" "network=warn"

echo "── H1 SSOT sensitive-app core (1password openclaw omniroute claude) in BOTH safelists [round-6] ──"
ck "SSOT core line intact in responder PROC_DENYLIST" "$(grep -cE '1password openclaw omniroute claude.*SSOT sensitive-app core' "$RESPONDER")" "1"
ck "SSOT core line intact in offender PROTECTED"      "$(grep -cE '1password openclaw omniroute claude.*SSOT sensitive-app core' "$OFC")"      "1"
ck "denied() openclaw (SSOT core, behavioral)"        "$(dn openclaw)"   "denied"
ck "denied() omniroute (SSOT core, behavioral)"       "$(dn omniroute)"  "denied"

echo "── memory_spine lag (EKO-106) — fresh fetch · @{u} · oldest-wins · deleted→dir mtime · clamp · fail-closed ──"
msl() { "$COLLECTOR" --memory-spine-lag "$1" 24 72 2>/dev/null; }
msf() { jq -r ".$2" <<<"$1"; }
setm() { touch -d "@$1" "$2" 2>/dev/null || touch -t "$(date -r "$1" +%Y%m%d%H%M.%S)" "$2"; }   # GNU / BSD
if command -v jq >/dev/null 2>&1; then
  MSD="$(mktemp -d)"; NOW="$(date +%s)"
  git init -q --bare "$MSD/remote.git"
  git clone -q "$MSD/remote.git" "$MSD/r" 2>/dev/null
  G() { git -C "$MSD/r" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
  mkdir -p "$MSD/r/projects/a/memory"; echo seed >"$MSD/r/projects/a/memory/m.md"; echo x >"$MSD/r/README"
  G add -A; G commit -qm seed; G push -q -u origin HEAD 2>/dev/null
  O="$(msl "$MSD/r")"
  ck "clean + pushed → ok"                 "$(msf "$O" status)" "ok"
  ck "clean + pushed → lag 0 (not unknown)" "$(msf "$O" lag_sec)" "0"
  ck "liveness canary alive"                "$(msf "$O" canary)" "alive"
  # two unpushed memory commits, 30h and 10h old — the OLDEST must win (sort -n, not log order)
  echo a >>"$MSD/r/projects/a/memory/m.md"; G add -A; GIT_COMMITTER_DATE="@$((NOW-30*3600)) +0000" G commit -qm old
  echo b >>"$MSD/r/projects/a/memory/m.md"; G add -A; GIT_COMMITTER_DATE="@$((NOW-10*3600)) +0000" G commit -qm new
  O="$(msl "$MSD/r")"
  ck "unpushed memory 30h old → warn (oldest wins)" "$(msf "$O" status)" "warn"
  ck "lag_h reflects the 30h commit"               "$(msf "$O" 'lag_h|floor')" "30"
  # an unpushed commit OUTSIDE projects/ is not memory lag (pathspec)
  G push -q 2>/dev/null; echo y >>"$MSD/r/README"; G add -A; GIT_COMMITTER_DATE="@$((NOW-100*3600)) +0000" G commit -qm other
  ck "unpushed non-memory commit → ok (pathspec projects/)" "$(msf "$(msl "$MSD/r")" status)" "ok"
  G push -q 2>/dev/null
  # dirty (uncommitted) memory file aged 80h → crit
  echo c >>"$MSD/r/projects/a/memory/m.md"; setm $((NOW-80*3600)) "$MSD/r/projects/a/memory/m.md"
  ck "dirty memory 80h old → crit" "$(msf "$(msl "$MSD/r")" status)" "crit"
  G checkout -q -- projects/
  # deleted tracked file → falls back to the parent dir mtime (30h)
  rm "$MSD/r/projects/a/memory/m.md"; setm $((NOW-30*3600)) "$MSD/r/projects/a/memory"
  ck "deleted memory file → parent-dir mtime → warn" "$(msf "$(msl "$MSD/r")" status)" "warn"
  G checkout -q -- projects/
  # future mtime (clock skew) clamps to 0, never negative
  echo d >"$MSD/r/projects/a/memory/new.md"; setm $((NOW+5*3600)) "$MSD/r/projects/a/memory/new.md"
  ck "future mtime → lag clamped to 0" "$(msf "$(msl "$MSD/r")" lag_sec)" "0"
  rm -f "$MSD/r/projects/a/memory/new.md"
  # FAIL-CLOSED: fetch failure / no upstream / missing repo → unknown, never 0
  G remote set-url origin "$MSD/nope.git"
  O="$(msl "$MSD/r")"
  ck "fetch failure → unknown (fail-closed)" "$(msf "$O" status)" "unknown"
  ck "fetch failure → canary dead"           "$(msf "$O" canary)" "dead"
  ck "fetch failure → no lag number"         "$(msf "$O" 'lag_sec // "none"')" "none"
  G remote set-url origin "$MSD/remote.git"; 
  # review round: malformed thresholds and a failing `git status` must stay fail-closed + valid JSON
  O="$("$COLLECTOR" --memory-spine-lag "$MSD/r" 24h 72 2>/dev/null)"
  ck "non-numeric threshold → valid JSON, unknown" "$(jq -r .status <<<"$O" 2>/dev/null || echo INVALID-JSON)" "unknown"
  ck "non-numeric threshold → reason bad-threshold" "$(msf "$O" reason)" "bad-threshold"
  mkdir -p "$MSD/gstub"; REAL_GIT="$(command -v git)"
  printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = status ] && exit 128; done\nexec "%s" "$@"\n' "$REAL_GIT" >"$MSD/gstub/git"; chmod +x "$MSD/gstub/git"
  ck "failing git status → unknown (status-failed), never ok" "$(msf "$(PATH="$MSD/gstub:$PATH" msl "$MSD/r")" reason)" "status-failed"
  ck "subdirectory repo path → unknown (repo-missing), never measured" "$(msf "$(msl "$MSD/r/projects")" reason)" "repo-missing"
  ck "trailing-slash root path → still measured" "$(msf "$(msl "$MSD/r/")" canary)" "alive"
  G branch -q --unset-upstream
  ck "no @{u} → unknown (no literal origin/main fallback)" "$(msf "$(msl "$MSD/r")" reason)" "no-upstream"
  ck "missing repo → unknown" "$(msf "$(msl "$MSD/absent")" status)" "unknown"
  rm -rf "$MSD"
else
  echo "  SKIP: jq absent — memory_spine fixture checks need jq"
fi
MS_OK='{"system":{"status":"ok","branches":{}},"burn_down":{"status":"ok"},"memory_spine":{"status":"ok","lag_h":0}}'
MS_WARN='{"system":{"status":"ok","branches":{}},"burn_down":{"status":"ok"},"memory_spine":{"status":"warn","lag_h":30.5}}'
MS_UNK='{"system":{"status":"ok","branches":{}},"burn_down":{"status":"ok"},"memory_spine":{"status":"unknown","reason":"fetch-failed"}}'
MS_ABS='{"system":{"status":"ok","branches":{}},"burn_down":{"status":"ok"}}'
ck_has    "memory_spine=warn while system ok → residue surfaces"         "$(respond_out "$MS_WARN")" "memory-spine=warn"
ck_has    "memory_spine=unknown → fail-closed residue (never silent ok)" "$(respond_out "$MS_UNK")"  "lag UNMEASURED"
ck_has    "memory_spine=ok → clean no-op"                                "$(respond_out "$MS_OK")"   "nothing to do"
ck_has    "memory_spine absent (pre-1.7.0 contract) → clean no-op"       "$(respond_out "$MS_ABS")"  "nothing to do"

echo "── machine-local ↔ skill-mirror collector byte-identity (the recon-relied-on invariant) [round-6] ──"
LOCAL="$HOME/.local/bin/system-health-guardian.sh"
if [ -f "$LOCAL" ]; then
  ck "collector machine-local == skill mirror (md5)" "$(hashf "$LOCAL")" "$(hashf "$COLLECTOR")"
else
  echo "  SKIP: machine-local collector absent (CI / non-deploy host) — byte-identity invariant N/A here"
fi

echo
echo "threshold-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
