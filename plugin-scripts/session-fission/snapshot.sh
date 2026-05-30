#!/usr/bin/env bash
# /**
#  * session-fission · snapshot.sh
#  * @context MAOS plugin script — the rollback anchor for the session-fission skill.
#  * @reason Copy the source transcript to a backup dir + write a manifest + run gitleaks,
#  *         BEFORE any archive/reseed op. The source is read-only; this only copies OUT.
#  * @impact Writes a snapshot + manifest under the backup dir. Never touches the source.
#  * @version 0.1.0
#  */

set -euo pipefail

# JSON-escape a string for safe interpolation into the stdout envelopes
# (paths can legally contain quotes, backslashes, spaces, or newlines).
json_escape() {
  local s="$1"
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# YAML single-quoted scalar escape for the manifest: wrap in single quotes and
# double any internal single quote, so paths with quotes/colons/backslashes/spaces
# stay valid YAML (parallel guarantee to json_escape for the stdout envelopes).
yaml_sq() { local s="$1"; s=${s//\'/\'\'}; printf "'%s'" "$s"; }

TRANSCRIPT="${1:?usage: snapshot.sh <transcript.jsonl> [backup_dir]}"
if [ ! -f "$TRANSCRIPT" ]; then
  printf '{"status":"error","error":"transcript not found: %s"}\n' "$(json_escape "$TRANSCRIPT")"
  exit 1
fi

BACKUP_DIR="${2:-${SESSION_FISSION_SNAPSHOT_DIR:-$HOME/.claude/session-fission/snapshots}}"
mkdir -p "$BACKUP_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SANITIZED_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BASE="$(basename "$TRANSCRIPT" .jsonl)"

# Portable SHA-256 (macOS shasum / Linux sha256sum / python3 hashlib fallback).
# The python3 fallback keeps SHA-based idempotency working on minimal systems that
# ship neither shasum nor sha256sum — without it, idempotency silently breaks and
# snapshots grow unbounded.
if command -v shasum >/dev/null 2>&1; then
  SHA="$(shasum -a 256 "$TRANSCRIPT" | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA="$(sha256sum "$TRANSCRIPT" | cut -d' ' -f1)"
elif command -v python3 >/dev/null 2>&1; then
  SHA="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$TRANSCRIPT")"
else
  SHA="unavailable"
fi

# Idempotent: if a manifest already records this SHA, reuse it (skip duplicate copy).
# Guard: only use SHA in the grep pattern when it is a clean 64-char hex digest
# (defense against any non-digest value reaching the pattern).
EXISTING=""
shopt -s nullglob
_manifests=( "$BACKUP_DIR"/*.manifest.yaml )
shopt -u nullglob
if [ "${#_manifests[@]}" -gt 0 ] && printf '%s' "$SHA" | grep -qE '^[0-9a-f]{64}$'; then
  EXISTING="$(grep -l "source_sha256: \"$SHA\"" "${_manifests[@]}" 2>/dev/null | head -1 || true)"
fi
if [ -n "$EXISTING" ]; then
  SNAP="${EXISTING%.manifest.yaml}"
  printf '{"status":"ok","idempotent":true,"snapshot_path":"%s","manifest_path":"%s","source_sha256":"%s","note":"identical SHA already snapshotted — reused"}\n' \
    "$(json_escape "$SNAP")" "$(json_escape "$EXISTING")" "$SHA"
  exit 0
fi

SNAP="$BACKUP_DIR/${BASE}-${TS}.jsonl"
MANIFEST="$SNAP.manifest.yaml"

# Read-only copy of the source OUT to the backup dir (-p preserves mtime/perms).
cp -p "$TRANSCRIPT" "$SNAP"

# gitleaks scrub (best-effort; reported, not enforced here).
GL="skipped"
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --no-git --source "$SNAP" >/dev/null 2>&1; then
    GL="clean"
  else
    GL="findings"
  fi
fi

SOURCE_Y="$(yaml_sq "$TRANSCRIPT")"
SNAP_Y="$(yaml_sq "$SNAP")"
cat > "$MANIFEST" <<YAML
# session-fission snapshot manifest
schema: "session-fission/manifest/0.1.0"
source_path: $SOURCE_Y
source_sha256: "$SHA"
snapshot_path: $SNAP_Y
snapshot_utc: "$SANITIZED_UTC"
sanitized_utc: "$SANITIZED_UTC"
gitleaks: "$GL"
lifecycle_state: "snapshotted"
rollback: "source never mutated; resume original via /resume; this copy is the backup anchor"
YAML

printf '{"status":"ok","idempotent":false,"snapshot_path":"%s","manifest_path":"%s","source_sha256":"%s","gitleaks":"%s","sanitized_utc":"%s"}\n' \
  "$(json_escape "$SNAP")" "$(json_escape "$MANIFEST")" "$SHA" "$GL" "$SANITIZED_UTC"
