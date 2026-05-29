#!/usr/bin/env bash
# /**
#  * transcript-corrector — 4-pass pipeline orchestrator
#  * @context Driver for the transcript-corrector skill. Reads a transcript from
#  *          stdin / local file / Confluence / Notion / GDrive (capability-detected),
#  *          runs 4 passes (whitelist + typo dict + grammar + emit), and outputs
#  *          corrected text + side-by-side diff + audit JSON.
#  * @reason Closes ASR-error gap before downstream consumers ingest. Default-safe
#  *          (review-only mode; inline writes require HITL auth flag).
#  * @impact Empirically validated against Confluence page 303988750 (Nilson→Nelcael
#  *          golden test, PDCA cycle 0).
#  */
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# -------- defaults --------
MODE="review-only"          # review-only | inline | apply-confluence | apply-notion | apply-gdrive
LANGUAGE="auto"             # pt-br | en-us | auto
OUTPUT="stdout"             # stdout | <path>
SOURCE=""                   # path | stdin | confluence:<id> | notion:<id> | gdrive:<id>
PARTICIPANTS_OVERRIDE=""    # optional path to custom participants whitelist
# Per-destination write-auth tokens (mode-specific to prevent confluence-auth
# from unlocking a notion-write, breaking the HUMAN_DOMAIN per-destination contract)
CONFLUENCE_WRITE_AUTH=""
NOTION_WRITE_AUTH=""
GDRIVE_WRITE_AUTH=""
AUDIT_DIR="$SKILL_DIR/pdca"

# -------- helpers --------
log()  { printf '[transcript-corrector] %s\n' "$*" >&2; }
fail() { log "ERROR: $*"; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") --source <ref> [options]

Required:
  --source <ref>             Source: path | stdin | confluence:<id> | notion:<id> | gdrive:<id>

Options:
  --language <l>             pt-br | en-us | auto (default: auto)
  --mode <m>                 review-only | inline | apply-confluence | apply-notion | apply-gdrive
                             (default: review-only)
  --output <o>               stdout | <path> (default: stdout)
  --participants <path>      Override participants-canonical.yaml
  --confluence-write-auth <rationale>
  --notion-write-auth <rationale>
  --gdrive-write-auth <rationale>
                             HITL authorization tokens for non-review-only modes.
                             REQUIRED per [C07] v2.1.0 for any inline write.

  -h, --help                 Show this help

Examples:
  # Golden test (Nilson → Nelcael, page 303988750)
  $(basename "$0") --source confluence:303988750 --language pt-br --mode review-only

  # Inline replace (requires operator HITL auth)
  $(basename "$0") --source path/to/transcript.md --language pt-br \\
    --mode inline --confluence-write-auth "operator-approved-2026-05-28"
EOF
}

# -------- parse args --------
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --participants) PARTICIPANTS_OVERRIDE="$2"; shift 2 ;;
    --confluence-write-auth) CONFLUENCE_WRITE_AUTH="$2"; shift 2 ;;
    --notion-write-auth) NOTION_WRITE_AUTH="$2"; shift 2 ;;
    --gdrive-write-auth) GDRIVE_WRITE_AUTH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown arg: $1 (run --help)" ;;
  esac
done

[ -n "$SOURCE" ] || { usage >&2; fail "--source is required"; }

# -------- layer 1: defensive validation of --source format --------
# Accept only known patterns to defeat any injection-via-source attempt
# (defense-in-depth even though all uses of $SOURCE downstream are quoted).
case "$SOURCE" in
  stdin) ;;
  confluence:[0-9]*) ;;
  notion:[A-Za-z0-9_-]*) ;;
  gdrive:[A-Za-z0-9_-]*) ;;
  /*|./*|../*|*.md|*.txt|*.json|*.yaml|*.yml) ;;
  *) fail "Invalid --source format: '$SOURCE' (must be one of: stdin | confluence:<digits> | notion:<id> | gdrive:<id> | <local-file-path>)" ;;
esac

# -------- layer 2: CWE-22 path-traversal defense (canonicalize + cwd-confine) --------
# When SOURCE is a local file path, canonicalize via realpath and confine the
# resolved path to ALLOWED_ROOT (default $PWD). This defeats traversal attacks
# where an attacker-controlled SOURCE like "../../etc/passwd.md" passes layer 1
# but resolves outside the operator's working tree. Per amazon-q 2026-05-28
# CWE-22 finding (root-cause-fix; surface-fix of stripping /*|./*|../* from
# layer 1 was rejected because it would break legitimate `--source /tmp/x.md`).
case "$SOURCE" in
  stdin|confluence:*|notion:*|gdrive:*)
    : # remote / stream sources — no local path to canonicalize
    ;;
  *)
    ALLOWED_ROOT="${TRANSCRIPT_CORRECTOR_ALLOWED_ROOT:-$PWD}"
    # python3 os.path.realpath chosen over BSD/GNU `realpath` for cross-platform
    # determinism (macOS BSD differs from GNU in edge cases like non-existing tails).
    SOURCE_REAL="$(python3 -c 'import os.path,sys; print(os.path.realpath(sys.argv[1]))' "$SOURCE" 2>/dev/null)" \
      || fail "Cannot canonicalize --source path: $SOURCE"
    ROOT_REAL="$(python3 -c 'import os.path,sys; print(os.path.realpath(sys.argv[1]))' "$ALLOWED_ROOT" 2>/dev/null)" \
      || fail "Cannot canonicalize ALLOWED_ROOT: $ALLOWED_ROOT"
    # Defense-in-depth: explicit non-empty check before containment match.
    # Per amazon-q 2026-05-28 — guards edge case where python3 returncode=0
    # but stdout is empty (truncated output / interpreted-shebang oddities).
    # Without this, `case ""` would still fall through to `*) fail`, but the
    # explicit check fails faster with a clearer diagnostic.
    [ -n "$SOURCE_REAL" ] || fail "Empty canonicalization result for --source: $SOURCE"
    [ -n "$ROOT_REAL" ]   || fail "Empty canonicalization result for ALLOWED_ROOT: $ALLOWED_ROOT"
    case "$SOURCE_REAL" in
      "$ROOT_REAL"|"$ROOT_REAL"/*) SOURCE="$SOURCE_REAL" ;;
      *) fail "Path traversal rejected: '--source' resolves to '$SOURCE_REAL' which is outside ALLOWED_ROOT='$ROOT_REAL'. To widen, set TRANSCRIPT_CORRECTOR_ALLOWED_ROOT=<dir>." ;;
    esac
    ;;
esac

# -------- HUMAN_DOMAIN gate (per [C17] §2) --------
# Each --mode requires the MATCHING write-auth flag (per-destination contract).
# Generic any-auth was rejected to prevent confluence-auth unlocking notion-write.
WRITE_AUTH=""
case "$MODE" in
  review-only) ;;
  inline)
    # Generic inline mode accepts ANY write-auth (destination is the source itself).
    WRITE_AUTH="${CONFLUENCE_WRITE_AUTH:-${NOTION_WRITE_AUTH:-$GDRIVE_WRITE_AUTH}}"
    [ -n "$WRITE_AUTH" ] || fail \
      "Mode '$MODE' requires one of --{confluence|notion|gdrive}-write-auth (HITL auth per [C07] v2.1.0)"
    ;;
  apply-confluence)
    [ -n "$CONFLUENCE_WRITE_AUTH" ] || fail "Mode 'apply-confluence' requires --confluence-write-auth (per [C07] v2.1.0)"
    WRITE_AUTH="$CONFLUENCE_WRITE_AUTH"
    ;;
  apply-notion)
    [ -n "$NOTION_WRITE_AUTH" ] || fail "Mode 'apply-notion' requires --notion-write-auth (per [C07] v2.1.0)"
    WRITE_AUTH="$NOTION_WRITE_AUTH"
    ;;
  apply-gdrive)
    [ -n "$GDRIVE_WRITE_AUTH" ] || fail "Mode 'apply-gdrive' requires --gdrive-write-auth (per [C07] v2.1.0)"
    WRITE_AUTH="$GDRIVE_WRITE_AUTH"
    ;;
  *) fail "Unknown mode: $MODE" ;;
esac
# Redact auth value from log to defeat replay attacks via captured stderr
# (CWE-532; raised by amazon-q 2026-05-28). Currently the field carries a
# rationale string, not a bearer token, but defense-in-depth: aligns with
# user-scope ⛔ ABSOLUTE guardrail ("NUNCA expor secrets em logs"). The
# `WRITE_AUTH` value is still propagated downstream for audit recording.
if [ -n "$WRITE_AUTH" ]; then
  # Short fingerprint preserves audit traceability (operator can correlate
  # this run with the matching authorization record) without leaking the value.
  AUTH_FP="$(printf '%s' "$WRITE_AUTH" | shasum -a 256 2>/dev/null | cut -c1-12)"
  [ -n "$AUTH_FP" ] && log "HITL auth recorded (sha256:${AUTH_FP}…, value redacted)" \
                   || log "HITL auth recorded (value redacted)"
fi

# -------- fetch source transcript --------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
INPUT="$TMP_DIR/input.txt"

case "$SOURCE" in
  stdin)
    cat > "$INPUT"
    ;;
  confluence:*)
    PAGE_ID="${SOURCE#confluence:}"
    log "Fetching Confluence page $PAGE_ID (read-only)"
    if command -v twg >/dev/null 2>&1; then
      twg confluence page get --page "$PAGE_ID" > "$INPUT" 2>/dev/null \
        || fail "twg confluence page get failed; check 'twg login' or use --source <local-file>"
    else
      fail "twg CLI not found and no MCP fallback wired in v1.0.0; export the page manually first"
    fi
    ;;
  notion:*|gdrive:*)
    fail "$SOURCE source connector not wired in v1.0.0 (planned v1.1.0+; for now, export manually first)"
    ;;
  *)
    [ -f "$SOURCE" ] || fail "Source file not found: $SOURCE"
    cp -- "$SOURCE" "$INPUT"
    ;;
esac

# -------- language detection --------
if [ "$LANGUAGE" = "auto" ]; then
  # Heuristic: count pt-BR-only characters vs en-US-only words.
  PTBR_HITS=$(grep -ciE '[ãõçáéíóúâêîôûà]|reunião|equipe|próxima|também' "$INPUT" || true)
  ENUS_HITS=$(grep -ciE '\b(the|and|with|meeting|next)\b' "$INPUT" || true)
  if [ "$PTBR_HITS" -gt "$ENUS_HITS" ]; then
    LANGUAGE="pt-br"
  else
    LANGUAGE="en-us"
  fi
  log "Detected language: $LANGUAGE"
fi

# -------- pass-state files --------
PASS1_OUT="$TMP_DIR/after-pass1.txt"
PASS2_OUT="$TMP_DIR/after-pass2.txt"
PASS3_OUT="$TMP_DIR/after-pass3.txt"
FINAL_OUT="$TMP_DIR/final.txt"
AUDIT_JSON="$TMP_DIR/audit.json"
echo "[]" > "$AUDIT_JSON"

# -------- Pass 1: participants whitelist + phonetic substitution --------
log "Pass 1 — participants whitelist + phonetic check"
PARTICIPANTS_FILE="${PARTICIPANTS_OVERRIDE:-$SKILL_DIR/catalogs/participants-canonical.yaml}"
PHONETIC_FILE="$SKILL_DIR/catalogs/phonetic-substitutions.yaml"
python3 "$SCRIPT_DIR/pass1-whitelist.py" \
  --input "$INPUT" \
  --output "$PASS1_OUT" \
  --participants "$PARTICIPANTS_FILE" \
  --phonetic "$PHONETIC_FILE" \
  --audit-append "$AUDIT_JSON" \
  --language "$LANGUAGE" \
  || fail "Pass 1 failed"

# -------- Pass 2: common-typos dictionary --------
log "Pass 2 — common-typos dictionary ($LANGUAGE)"
TYPO_FILE="$SKILL_DIR/catalogs/common-typos-${LANGUAGE}.yaml"
if [ -f "$TYPO_FILE" ]; then
  bash "$SCRIPT_DIR/pass2-typo-dict.sh" \
    --input "$PASS1_OUT" \
    --output "$PASS2_OUT" \
    --catalog "$TYPO_FILE" \
    --audit-append "$AUDIT_JSON" \
    || fail "Pass 2 failed"
else
  log "Typo dictionary not found for $LANGUAGE; skipping Pass 2"
  cp -- "$PASS1_OUT" "$PASS2_OUT"
fi

# -------- Pass 3: grammar / punctuation --------
log "Pass 3 — grammar / punctuation"
bash "$SCRIPT_DIR/pass3-grammar.sh" \
  --input "$PASS2_OUT" \
  --output "$PASS3_OUT" \
  --language "$LANGUAGE" \
  --audit-append "$AUDIT_JSON" \
  || fail "Pass 3 failed"

cp -- "$PASS3_OUT" "$FINAL_OUT"

# -------- Pass 4: emit --------
log "Pass 4 — emit (diff + audit)"
mkdir -p "$AUDIT_DIR"
# Strict ISO 8601 (with colons) is the canonical timestamp; we sanitize for
# filesystem use (POSIX-portable: many filesystems forbid `:` in filenames).
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINAL_AUDIT="$AUDIT_DIR/run-${TIMESTAMP//:/-}.json"
cp -- "$AUDIT_JSON" "$FINAL_AUDIT"

bash "$SCRIPT_DIR/pass4-emit.sh" \
  --original "$INPUT" \
  --corrected "$FINAL_OUT" \
  --audit "$FINAL_AUDIT" \
  --output "$OUTPUT" \
  --mode "$MODE" \
  || fail "Pass 4 failed"

log "Done. Audit: $FINAL_AUDIT"
