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
#  *        4 clipboard unverified · 5 a source was refused (secret/PII/binary) ·
#  *        6 cleanup failed (temporary data may remain — reported, never hidden)
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

# Temporary data: every temp lives in ONE private dir (umask 077 + mktemp -d), plus the
# registered same-filesystem rename temps in the destination. A single EXIT trap removes all
# of them on success, die/exit and INT/TERM/HUP alike, then verifies they are gone; a failed
# cleanup is reported on stderr with rc 6, never hidden.
umask 077
WORK=""
DEST_TMPS=()
cleanup() {
  local rc=$? ok=1 f
  trap - EXIT INT TERM HUP
  for f in ${DEST_TMPS[@]+"${DEST_TMPS[@]}"}; do
    rm -f -- "$f" 2>/dev/null || ok=0
    [ ! -e "$f" ] || ok=0
  done
  if [ -n "$WORK" ]; then
    rm -rf -- "$WORK" 2>/dev/null || ok=0
    [ ! -e "$WORK" ] || ok=0
  fi
  if [ "$ok" -eq 0 ]; then
    printf 'cleanup failed: temporary data may remain under %s\n' "${WORK:-<dest>}" >&2
    rc=6
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
mkwork() {
  [ -z "$WORK" ] || return 0
  # explicit template: BSD/macOS mktemp ignores $TMPDIR without one, GNU honours it — the
  # template makes the location deterministic (and observable by the residue tests)
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/close-out-manifest.XXXXXX")" || die "cannot create private work dir" 1
  chmod 700 "$WORK"
}
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

# Scanning model (parser-differential hardening): every source is first copied into a private
# staging dir, and ONLY the staged bytes are scanned and then promoted — the origin is never read
# twice, so a change made during the scan (TOCTOU) cannot reach the destination. Three views of
# the staged bytes are scanned: raw, CRLF-normalised, and line-joined (catches a secret split
# across lines). The scanner runs isolated: inherited config env vars dropped, cwd = staging,
# in-content allow directives ignored, ignore-file pointed at an empty dir — no input can opt
# itself out. gitleaks rc 0 = clean; ANY other rc = leak OR scan error, both treated as a hit
# (fail-closed).
scan_one() {
  ( cd "$STAGE" && env -u GITLEAKS_CONFIG -u GITLEAKS_CONFIG_TOML \
      "$SCANNER" dir "$1" --no-banner --ignore-gitleaks-allow --gitleaks-ignore-path "$NOIGN" ) >/dev/null 2>&1
}
views() { # $1 = staged file; writes $1.norm and $1.flat
  tr -d '\r' < "$1" > "$1.norm"
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$1.norm" | tr -d '\n' > "$1.flat"
}
secret_hit() { # rc 0 = hit on any view
  local v
  for v in "$1" "$1.norm" "$1.flat"; do scan_one "$v" || return 0; done
  return 1
}
pii_hit() { grep -qE "$PII_RE" "$1.norm" || grep -qE "$PII_RE" "$1.flat"; }
is_binary() { ! tr -d '\000' < "$1" | cmp -s - "$1"; }

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

  mkwork
  STAGE="$WORK/stage"; NOIGN="$WORK/noignore"
  mkdir -m 700 "$STAGE" "$NOIGN" || die "persist: cannot create staging dir" 1

  # positive controls, assembled at runtime (no key/PII literal in this file), scanned through
  # the exact same staging + invocation path as the sources
  local p="gh""p_" at="@"
  printf 'k = "%s%s"\n' "$p" "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)" > "$STAGE/ctl"
  views "$STAGE/ctl"
  secret_hit "$STAGE/ctl" || die "persist: secret scanner is blind to the positive control — refusing (fail-closed)" 3
  printf 'c: probe%sexample.org\n' "$at" > "$STAGE/ctl"
  views "$STAGE/ctl"
  pii_hit "$STAGE/ctl" || die "persist: PII scan is blind to the positive control — refusing (fail-closed)" 3
  # negative control: a known-clean staged file must scan clean, otherwise the scanner is
  # erroring on everything (crash, bad args, bad config) — report that as rc 3, not as a leak
  printf 'plain text\n' > "$STAGE/ctl"
  views "$STAGE/ctl"
  ! secret_hit "$STAGE/ctl" || die "persist: secret scanner fails on a clean control — scanner error, refusing (fail-closed)" 3
  rm -f "$STAGE/ctl" "$STAGE/ctl.norm" "$STAGE/ctl.flat"

  local s base target status i=0 staged tmp
  for s in "${srcs[@]}"; do
    i=$((i + 1))
    [ -f "$s" ] && [ ! -L "$s" ] || { printf '{"src":"%s","status":"skipped-not-regular-file"}\n' "$(jstr "$s")"; continue; }
    base="$(basename -- "$s")"; target="$dest/$base"
    staged="$STAGE/f$i"
    cp -- "$s" "$staged" || die "persist: cannot stage $base" 1
    if [ ! -f "$s" ] || [ -L "$s" ]; then # source swapped during the copy
      rm -f -- "$staged"
      printf '{"src":"%s","status":"skipped-not-regular-file"}\n' "$(jstr "$s")"; continue
    fi
    if is_binary "$staged"; then status="refused-binary"; refused=1
    else
      views "$staged"
      if secret_hit "$staged"; then status="refused-secret"; refused=1
      elif pii_hit "$staged"; then status="refused-pii"; refused=1
      elif [ -f "$target" ] && cmp -s "$staged" "$target"; then status="unchanged"
      elif [ "$apply" -eq 1 ]; then
        mkdir -p -- "$dest"
        # the rename temp sits next to the target (same filesystem ⇒ atomic mv) and holds only
        # already-scanned staged bytes; it is registered so any failure path removes it
        tmp="$dest/.$base.cm-tmp.$$"; DEST_TMPS+=("$tmp")
        cp -- "$staged" "$tmp" || die "persist: cannot write $base" 1
        mv -f -- "$tmp" "$target" || die "persist: cannot promote $base" 1
        cmp -s "$staged" "$target" || die "persist: post-copy verify failed for $base" 1
        status="copied"
      else status="would-copy"
      fi
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
  # read-back streams straight into cmp: the handoff content never touches a temp file
  # shellcheck disable=SC2086
  if $CLIP_COPY_CMD < "$file" 2>/dev/null && $CLIP_PASTE_CMD 2>/dev/null | cmp -s "$file" -; then
    printf '{"status":"verified","bytes":%s}\n' "$(wc -c < "$file" | tr -d ' ')"
    return 0
  fi
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
