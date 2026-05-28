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
WRITE_AUTH=""               # required when MODE = inline | apply-*
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
    --confluence-write-auth|--notion-write-auth|--gdrive-write-auth)
      WRITE_AUTH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown arg: $1 (run --help)" ;;
  esac
done

[ -n "$SOURCE" ] || { usage >&2; fail "--source is required"; }

# -------- defensive validation of --source format --------
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

# -------- HUMAN_DOMAIN gate (per [C17] §2) --------
case "$MODE" in
  review-only) ;;
  inline|apply-*)
    [ -n "$WRITE_AUTH" ] || fail \
      "Mode '$MODE' requires --{confluence|notion|gdrive}-write-auth <rationale> (HITL auth per [C07] v2.1.0)"
    log "HITL auth recorded: $WRITE_AUTH"
    ;;
  *) fail "Unknown mode: $MODE" ;;
esac

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
    cp "$SOURCE" "$INPUT"
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
  cp "$PASS1_OUT" "$PASS2_OUT"
fi

# -------- Pass 3: grammar / punctuation --------
log "Pass 3 — grammar / punctuation"
bash "$SCRIPT_DIR/pass3-grammar.sh" \
  --input "$PASS2_OUT" \
  --output "$PASS3_OUT" \
  --language "$LANGUAGE" \
  --audit-append "$AUDIT_JSON" \
  || fail "Pass 3 failed"

cp "$PASS3_OUT" "$FINAL_OUT"

# -------- Pass 4: emit --------
log "Pass 4 — emit (diff + audit)"
mkdir -p "$AUDIT_DIR"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
FINAL_AUDIT="$AUDIT_DIR/run-$TIMESTAMP.json"
cp "$AUDIT_JSON" "$FINAL_AUDIT"

bash "$SCRIPT_DIR/pass4-emit.sh" \
  --original "$INPUT" \
  --corrected "$FINAL_OUT" \
  --audit "$FINAL_AUDIT" \
  --output "$OUTPUT" \
  --mode "$MODE" \
  || fail "Pass 4 failed"

log "Done. Audit: $FINAL_AUDIT"
