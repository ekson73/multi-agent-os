#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# close-out-manifest.sh — postflight P3.7 MANIFEST executor (v0.1.0)
#
# /** The deterministic half of the multi-agent close-out
#  *  (skills/postflight/references/close-out-manifest-protocol.md). The live agent
#  *  WRITES the manifest; this script only does what must not be left to judgment:
#  *    check   — the manifest carries every required section, a PASS delegates gate,
#  *              and a complete recovery triple [session_id, link, command]
#  *    persist — copy ephemeral reports (e.g. a scratchpad) to a durable dir, only
#  *              after a secret scan + a PII scan, each proven to SEE a positive
#  *              control assembled at runtime (a blind scanner never reports clean)
#  *    clip    — copy the manifest to the clipboard and VERIFY it by read-back cmp;
#  *              unverifiable ⇒ rc 4 + the paste-MCP fallback hint (never fake success)
#  *  @exit 0 ok · 1 usage/IO error · 2 check failed · 3 scanner blind/missing ·
#  *        4 clipboard unverified · 5 a source was refused (secret/PII)
#  *  Dry-run is the default for persist (--apply to write). Idempotent. Bash 3.2-safe.
#  */
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage:
  close-out-manifest.sh check   --manifest <file>
  close-out-manifest.sh persist --dest <dir> --src <file> [--src <file> ...] [--apply]
  close-out-manifest.sh clip    --file <file>
  close-out-manifest.sh --help | --version

Env:
  MAOS_SECRET_SCANNER  secret scanner run as '<scanner> dir <file> --no-banner' (default: gitleaks)
  MAOS_CLIP_COPY       clipboard copy command (default: auto-detect pbcopy/wl-copy/xclip/xsel)
  MAOS_CLIP_PASTE      clipboard read-back command (default: matching paste tool)
EOF
}

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }
jstr() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

REQUIRED_SECTIONS="Delegates gate|Instruction tree|HITL decisions|Roadmap|Artifact index|Recovery|Self-location"

field() { # field <file> <key> → value after "key:" (trimmed), first match
  sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" "$1" | head -1 | sed 's/[[:space:]]*$//'
}

cmd_check() {
  local manifest="" missing=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --manifest) [ $# -ge 2 ] || die "--manifest needs a value"; manifest="$2"; shift 2 ;;
      *) die "check: unknown arg $1" ;;
    esac
  done
  [ -n "$manifest" ] && [ -f "$manifest" ] || die "check: manifest not found: ${manifest:-<none>}"

  local IFS='|' s
  for s in $REQUIRED_SECTIONS; do
    grep -qiE "^##[[:space:]]+$s[[:space:]]*$" "$manifest" || missing="${missing}section:${s};"
  done
  unset IFS
  [ "$(field "$manifest" delegates_gate)" = "PASS" ] || missing="${missing}delegates_gate!=PASS;"
  local k
  for k in session_id link command manifest_path; do
    [ -n "$(field "$manifest" "$k")" ] || missing="${missing}field:${k};"
  done

  if [ -n "$missing" ]; then
    printf '{"status":"fail","missing":"%s"}\n' "$(jstr "$missing")"
    exit 2
  fi
  printf '{"status":"pass","manifest":"%s"}\n' "$(jstr "$manifest")"
}

# PII patterns (email · BR phone · CPF). Metadata-only manifests should match none.
PII_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\+?55[ (]*[0-9]{2}[) ]*9?[0-9]{4}-?[0-9]{4}|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}'

# gitleaks semantics: rc 0 = clean (no hit); any other rc = leak OR scan error. Both are treated
# as a hit on purpose (fail-closed): a file the scanner could not clear is never persisted.
secret_hit() { "$SCANNER" dir "$1" --no-banner >/dev/null 2>&1 && return 1 || return 0; }
pii_hit()    { grep -qE "$PII_RE" "$1"; }

cmd_persist() {
  local dest="" apply=0 srcs=() refused=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dest)  [ $# -ge 2 ] || die "--dest needs a value"; dest="$2"; shift 2 ;;
      --src)   [ $# -ge 2 ] || die "--src needs a value"; srcs+=("$2"); shift 2 ;;
      --apply) apply=1; shift ;;
      *) die "persist: unknown arg $1" ;;
    esac
  done
  [ -n "$dest" ] || die "persist: --dest required"
  [ "${#srcs[@]}" -gt 0 ] || die "persist: at least one --src required"

  SCANNER="${MAOS_SECRET_SCANNER:-gitleaks}"
  command -v "$SCANNER" >/dev/null 2>&1 || die "persist: secret scanner '$SCANNER' not found — refusing (fail-closed)" 3

  # positive controls, assembled at runtime (no key/PII literal in this file)
  local ctl; ctl="$(mktemp -d)"
  trap 'rm -rf "$ctl"' RETURN
  local p="gh""p_" at="@"
  printf 'k = "%s%s"\n' "$p" "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)" > "$ctl/secret.txt"
  printf 'c: probe%sexample.org\n' "$at" > "$ctl/pii.txt"
  secret_hit "$ctl/secret.txt" || die "persist: secret scanner is blind to the positive control — refusing (fail-closed)" 3
  pii_hit "$ctl/pii.txt" || die "persist: PII scan is blind to the positive control — refusing (fail-closed)" 3

  local s base target status
  for s in "${srcs[@]}"; do
    [ -f "$s" ] && [ ! -L "$s" ] || { printf '{"src":"%s","status":"skipped-not-regular-file"}\n' "$(jstr "$s")"; continue; }
    base="$(basename "$s")"; target="$dest/$base"
    if secret_hit "$s"; then status="refused-secret"; refused=1
    elif pii_hit "$s"; then status="refused-pii"; refused=1
    elif [ -f "$target" ] && cmp -s "$s" "$target"; then status="unchanged"
    elif [ "$apply" -eq 1 ]; then
      mkdir -p "$dest"
      cp "$s" "$target.tmp.$$" && mv -f "$target.tmp.$$" "$target"
      cmp -s "$s" "$target" || die "persist: post-copy verify failed for $base" 1
      status="copied"
    else status="would-copy"
    fi
    printf '{"src":"%s","dest":"%s","status":"%s"}\n' "$(jstr "$s")" "$(jstr "$target")" "$status"
  done
  [ "$refused" -eq 0 ] || exit 5
}

detect_clip() { # sets CLIP_COPY_CMD / CLIP_PASTE_CMD as space-joined commands
  if [ -n "${MAOS_CLIP_COPY:-}" ] || [ -n "${MAOS_CLIP_PASTE:-}" ]; then
    CLIP_COPY_CMD="${MAOS_CLIP_COPY:-}"; CLIP_PASTE_CMD="${MAOS_CLIP_PASTE:-}"; return
  fi
  if   command -v pbcopy  >/dev/null 2>&1; then CLIP_COPY_CMD="pbcopy";                    CLIP_PASTE_CMD="pbpaste"
  elif command -v wl-copy >/dev/null 2>&1; then CLIP_COPY_CMD="wl-copy";                   CLIP_PASTE_CMD="wl-paste -n"
  elif command -v xclip   >/dev/null 2>&1; then CLIP_COPY_CMD="xclip -selection clipboard"; CLIP_PASTE_CMD="xclip -selection clipboard -o"
  elif command -v xsel    >/dev/null 2>&1; then CLIP_COPY_CMD="xsel -b -i";                CLIP_PASTE_CMD="xsel -b -o"
  else CLIP_COPY_CMD=""; CLIP_PASTE_CMD=""
  fi
}

cmd_clip() {
  local file=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --file) [ $# -ge 2 ] || die "--file needs a value"; file="$2"; shift 2 ;;
      *) die "clip: unknown arg $1" ;;
    esac
  done
  [ -n "$file" ] && [ -f "$file" ] || die "clip: file not found: ${file:-<none>}"
  local hint="fallback: paste-mcp (create_item with the file content), then confirm by read_item"
  detect_clip
  # shellcheck disable=SC2086  # commands are intentionally word-split (fixed, non-user tokens)
  set -- $CLIP_COPY_CMD
  if [ -z "$CLIP_COPY_CMD" ] || ! command -v "$1" >/dev/null 2>&1; then
    printf '{"status":"unverified","reason":"no-clipboard-tool","hint":"%s"}\n' "$hint"; exit 4
  fi
  if [ -z "$CLIP_PASTE_CMD" ]; then
    printf '{"status":"unverified","reason":"no-readback-tool","hint":"%s"}\n' "$hint"; exit 4
  fi
  local back; back="$(mktemp)"
  # shellcheck disable=SC2086
  if $CLIP_COPY_CMD < "$file" 2>/dev/null && $CLIP_PASTE_CMD > "$back" 2>/dev/null \
     && cmp -s "$file" "$back"; then
    rm -f "$back"
    printf '{"status":"verified","bytes":%s}\n' "$(wc -c < "$file" | tr -d ' ')"
    return 0
  fi
  rm -f "$back"
  printf '{"status":"unverified","reason":"read-back-mismatch","hint":"%s"}\n' "$hint"; exit 4
}

case "${1:-}" in
  check)   shift; cmd_check "$@" ;;
  persist) shift; cmd_persist "$@" ;;
  clip)    shift; cmd_clip "$@" ;;
  --version) echo "close-out-manifest.sh $VERSION" ;;
  -h|--help|"") usage ;;
  *) usage >&2; exit 1 ;;
esac
