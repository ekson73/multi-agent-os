#!/usr/bin/env bash
# bb-pipeline-watch.sh — Watch a Bitbucket Cloud pipeline until it COMPLETES,
# then return the verdict AND (on failure) the redacted failure diagnosis
# (failed steps + the error-relevant log tail) — so the calling agent wakes
# up already holding what it needs to act, not just a green/red bit.
#
# WHY: an agent that schedules a fixed-interval poll burns context cache and
# still has to make 3 follow-up calls (get_steps -> diagnose -> fetch log) on a
# failure. Run THIS in the background instead: it blocks until the build ends
# and exits 0 — the Claude Code harness re-invokes the agent on that exit, with
# the diagnosis already in stdout. Event-driven on the REAL completion, no
# public webhook endpoint required.
#
# SECRET-SAFETY (anti-theater + ⛔ guardrail): the API token is sourced inside a
# subshell, used only in an Authorization header, and NEVER echoed. All log
# output is passed through redact() which masks AWS temp keys, long base64
# secrets, and token/password values before printing.
#
# USAGE:
#   bb-pipeline-watch.sh --build 1363 [--repo vks-jss-sales-api] [--workspace vek-servicos]
#   bb-pipeline-watch.sh --latest --branch feature/x --repo vks-jss-sales-api
# Options:
#   --build N            build_number to watch (or use --latest)
#   --latest             watch the most recent build (optionally filtered by --branch)
#   --branch B           branch filter for --latest
#   --workspace WS       Bitbucket workspace (default: vek-servicos or $BITBUCKET_WORKSPACE)
#   --repo REPO          repo slug (default: $BITBUCKET_REPO_SLUG)
#   --interval SECS      poll interval (default: 45)
#   --max-polls N        safety cap (default: 80  -> ~60min @45s)
#   --env-file PATH      creds .env (default: maos-mcp-hub .env)
#   --once               single status check, no loop (sanity/CI use)
# Exit: always 0 on a reached verdict or timeout (clean background completion);
#       non-zero only on a setup error (no token / bad args).
set -euo pipefail

WS="${BITBUCKET_WORKSPACE:-vek-servicos}"; REPO="${BITBUCKET_REPO_SLUG:-}"
BUILD=""; LATEST=0; BRANCH=""; INTERVAL=45; MAXPOLLS=80; ONCE=0
ENV_FILE="${BB_WATCH_ENV_FILE:-$HOME/Projects/multi-agent-os/mcp-tools/maos-mcp-hub/.env}"
while [ $# -gt 0 ]; do case "$1" in
  --build) BUILD="$2"; shift 2;;
  --latest) LATEST=1; shift;;
  --branch) BRANCH="$2"; shift 2;;
  --workspace) WS="$2"; shift 2;;
  --repo) REPO="$2"; shift 2;;
  --interval) INTERVAL="$2"; shift 2;;
  --max-polls) MAXPOLLS="$2"; shift 2;;
  --env-file) ENV_FILE="$2"; shift 2;;
  --once) ONCE=1; shift;;
  *) echo "unknown arg: $1" >&2; exit 2;;
esac; done
[ -n "$REPO" ] || { echo "ERROR: --repo required (or set BITBUCKET_REPO_SLUG)" >&2; exit 2; }
[ -n "$BUILD" ] || [ "$LATEST" = 1 ] || { echo "ERROR: --build N or --latest required" >&2; exit 2; }
[ -f "$ENV_FILE" ] || { echo "ERROR: env-file not found: $ENV_FILE" >&2; exit 2; }

# redact(): mask anything secret-shaped before it reaches stdout.
redact() {
  sed -E \
    -e 's/(ASIA|AKIA)[A-Z0-9]{8,}/\1[REDACTED-KEY]/g' \
    -e 's#[A-Za-z0-9/+=]{60,}#[REDACTED-LONG]#g' \
    -e 's/((aws_)?(secret|session)[_-]?(access[_-]?key|token)[^A-Za-z0-9]+)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/(password[^A-Za-z0-9]+)[^[:space:]]+/\1[REDACTED]/Ig'
}

API="https://api.bitbucket.org/2.0/repositories/${WS}/${REPO}"

# Everything that touches the token runs in this subshell.
(
  set -a; . "$ENV_FILE" 2>/dev/null || true; set +a
  T="${BITBUCKET_API_TOKEN:-}"; [ -z "$T" ] && { echo "ERROR: BITBUCKET_API_TOKEN absent in env-file" >&2; exit 3; }
  AUTH=(-H "Authorization: Bearer ${T}")

  # Resolve build_number + pipeline uuid (single list call, filter client-side).
  resolve() {
    curl -s "${AUTH[@]}" \
      "${API}/pipelines/?sort=-created_on&pagelen=25&fields=values.uuid,values.build_number,values.state.name,values.state.result.name,values.target.ref_name" \
    | BUILD="$BUILD" LATEST="$LATEST" BRANCH="$BRANCH" python3 -c '
import json,sys,os
d=json.load(sys.stdin); vals=d.get("values",[])
b=os.environ.get("BUILD",""); latest=os.environ.get("LATEST")=="1"; br=os.environ.get("BRANCH","")
pick=None
if b:
    pick=next((v for v in vals if str(v.get("build_number"))==str(b)),None)
elif latest:
    cand=[v for v in vals if (not br or (v.get("target",{}).get("ref_name")==br))]
    pick=cand[0] if cand else None
if not pick: print("NOTFOUND||||"); sys.exit(0)
st=pick.get("state",{})
print("|".join([str(pick.get("build_number","")), pick.get("uuid",""),
    st.get("name",""), str(st.get("result",{}).get("name")), pick.get("target",{}).get("ref_name","")]))'
  }

  emit_failure_diag() {
    local puuid="$1"
    echo "----- FAILURE DIAGNOSIS (redacted) -----"
    # list steps, find failed ones
    local steps; steps="$(curl -s "${AUTH[@]}" \
      "${API}/pipelines/${puuid}/steps/?fields=values.uuid,values.name,values.state.result.name")"
    echo "$steps" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for v in d.get("values",[]):
    r=(v.get("state",{}) or {}).get("result",{}) or {}
    print((v.get("uuid","")+"\t"+(v.get("name","?"))+"\t"+str(r.get("name"))))' \
    | while IFS=$'\t' read -r suuid sname sresult; do
        echo "  step: ${sname} -> ${sresult}"
        if [ "$sresult" = "FAILED" ]; then
          local se; se="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$suuid")"
          curl -s "${AUTH[@]}" "${API}/pipelines/${puuid}/steps/${se}/log" -o /tmp/_bbw_log.$$ || true
          echo "  --- '${sname}' error-relevant lines ---"
          grep -niE 'error|denied|invalid|unrecogniz|credential|assume|unable|exception|fail|forbidden|expired|not authorized|AccessDenied|UnrecognizedClient|InvalidIdentityToken|no such|cannot|timeout' /tmp/_bbw_log.$$ 2>/dev/null \
            | tail -25 | redact || echo "    (no matching lines)"
          echo "  --- last 8 lines ---"
          tail -8 /tmp/_bbw_log.$$ 2>/dev/null | redact || true
          rm -f /tmp/_bbw_log.$$
        fi
      done
    echo "----------------------------------------"
  }

  i=0
  while :; do
    i=$((i+1))
    line="$(resolve)"; IFS='|' read -r bn puuid sname sresult ref <<<"$line"
    ts="$(date +%H:%M:%S)"
    if [ "$bn" = "NOTFOUND" ] || [ -z "$bn" ]; then
      echo "[poll $i $ts] build not found yet (repo=$REPO build=${BUILD:-latest} branch=${BRANCH:-any})"
    else
      echo "[poll $i $ts] build $bn ($ref) state=$sname result=$sresult"
      if [ "$sname" = "COMPLETED" ]; then
        echo "=== BUILD $bn COMPLETED: $sresult ==="
        if [ "$sresult" = "FAILED" ]; then emit_failure_diag "$puuid"; fi
        exit 0
      fi
    fi
    [ "$ONCE" = 1 ] && exit 0
    [ "$i" -ge "$MAXPOLLS" ] && { echo "=== WATCH TIMEOUT after $i polls — build still running ==="; exit 0; }
    sleep "$INTERVAL"
  done
)
