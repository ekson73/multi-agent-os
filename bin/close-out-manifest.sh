#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# close-out-manifest.sh — postflight P3.7 MANIFEST executor (v0.2.0)
#
# /** The deterministic half of the multi-agent close-out
#  *  (skills/postflight/references/close-out-manifest-protocol.md). The live agent
#  *  WRITES the manifest; this script only does what must not be left to judgment:
#  *    check   — the manifest carries every required section, a PASS delegates gate,
#  *              and a complete recovery triple [session_id, link, command]
#  *    persist — copy ephemeral reports (e.g. a scratchpad) to a durable dir, only
#  *              after a secret scan + a PII scan, each proven to SEE a positive
#  *              control assembled at runtime (a blind scanner never reports clean)
#  *    anchor  — read-only git anchor: branch@HEAD · UTC, dirty files named, worktrees
#  *    clip    — copy the manifest to the clipboard and VERIFY it by read-back cmp;
#  *              unverifiable ⇒ rc 4 + the paste-MCP fallback hint (never fake success)
#  *  @exit 0 ok · 1 usage/IO error · 2 check failed · 3 scanner blind/missing ·
#  *        4 clipboard unverified · 5 a source was refused (secret/PII/binary) ·
#  *        6 cleanup failed (temporary data may remain — reported, never hidden)
#  *  Dry-run is the default for persist (--apply to write). Idempotent. Bash 3.2-safe.
#  */
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

VERSION="0.2.0"

usage() {
  cat <<'EOF'
Usage:
  close-out-manifest.sh check   --manifest <file> [--strict]
  close-out-manifest.sh persist --dest <dir> --src <file> [--src <file> ...] [--apply]
  close-out-manifest.sh clip    --file <file>
  close-out-manifest.sh anchor  --repo <dir>
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
# Self-heal: documented log-only exception (docs/self-heal-relay.md) — this tool handles reports
# that may carry secrets/PII, so an unexpected fault is reported on stderr (line + rc only, never
# arguments or content) and is NEVER relayed to an agent. Intentional gate/refusal exits use
# `exit`/`die`, which do not raise ERR.
set -E
on_fault() {
  printf 'close-out-manifest: unexpected fault at line %s (rc %s) — log-only, no self-heal dispatch\n' "$1" "$2" >&2
}
trap 'on_fault "$LINENO" "$?"' ERR
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
# JSON string body: escapes backslash, quote and EVERY control character (a newline in a path
# must not end the record or forge a second one)
jstr() {
  printf '%s\n' "$1" | LC_ALL=C awk '
    BEGIN { ORS = ""; for (i = 1; i < 32; i++) ord[sprintf("%c", i)] = i
            ord[sprintf("%c", 127)] = 127; for (i = 128; i < 256; i++) hi[sprintf("%c", i)] = i }
    {
      if (NR > 1) printf "\\n"
      n = length($0)
      for (i = 1; i <= n; i++) {
        ch = substr($0, i, 1)
        if (ch == "\\") printf "\\\\"
        else if (ch == "\"") printf "\\\""
        else if (ch == "\t") printf "\\t"
        else if (ch == "\r") printf "\\r"
        else if (ch in ord) printf "\\u%04x", ord[ch]
        else if (!(ch in hi)) printf "%s", ch
        else { # a byte >= 0x80: emit a well-formed UTF-8 sequence verbatim, else U+FFFD
          b = hi[ch]; need = (b >= 194 && b <= 223) ? 1 : (b >= 224 && b <= 239) ? 2 : (b >= 240 && b <= 244) ? 3 : -1
          ok = (need > 0 && i + need <= n)
          for (k = 1; ok && k <= need; k++) { c = substr($0, i + k, 1); if (!(c in hi) || hi[c] > 191) ok = 0 }
          if (ok && b == 224 && hi[substr($0, i + 1, 1)] < 160) ok = 0   # overlong
          if (ok && b == 237 && hi[substr($0, i + 1, 1)] > 159) ok = 0   # surrogate
          if (ok && b == 240 && hi[substr($0, i + 1, 1)] < 144) ok = 0   # overlong
          if (ok && b == 244 && hi[substr($0, i + 1, 1)] > 143) ok = 0   # > U+10FFFF
          if (ok) { printf "%s", substr($0, i, need + 1); i += need } else printf "\\ufffd"
        }
      }
    }'
}

REQUIRED_SECTIONS="Delegates gate|Instruction tree|HITL decisions|Roadmap|Artifact index|Recovery|Self-location"
# opt-in (check --strict): after-action review (FEAT-4), resume check for the receiving session
# (FEAT-19/20) and an explicit not-done list (FEAT-32) — off by default so the default close-out
# is neither slower nor noisier
STRICT_SECTIONS="After-action review|Resume check|Not done"

field() { # field <file> <section> <key> → value after "key:" inside "## <section>" only
  awk -v sec="$2" -v key="$3" '
    /^##[[:space:]]/ { h = $0; sub(/^##[[:space:]]+/, "", h); sub(/[[:space:]]+$/, "", h)
                       insec = (tolower(h) == tolower(sec)); next }
    insec { l = $0; sub(/^[[:space:]]+/, "", l)
            if (index(l, key ":") == 1) { v = substr(l, length(key) + 2)
              sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); print v; exit } }' "$1"
}
section_body_empty() { # rc 0 when "## <section>" has no non-blank line before the next heading
  awk -v sec="$2" '
    /^##[[:space:]]/ { h = $0; sub(/^##[[:space:]]+/, "", h); sub(/[[:space:]]+$/, "", h)
                       insec = (tolower(h) == tolower(sec)); next }
    insec && $0 ~ /[^[:space:]]/ { found = 1; exit }
    END { exit found ? 1 : 0 }' "$1"
}

canon() { # physical path of an existing file (symlinks resolved), else empty
  local d f="$1" n=0
  while [ -L "$f" ] && [ "$n" -lt 40 ]; do
    d="$(cd "$(dirname -- "$f")" && pwd -P)" || return 0
    f="$(readlink -- "$f")"; case "$f" in /*) ;; *) f="$d/$f" ;; esac; n=$((n + 1))
  done
  [ -e "$f" ] || return 0
  d="$(cd "$(dirname -- "$f")" && pwd -P)" && printf '%s/%s' "$d" "${f##*/}"
}
is_ephemeral() { # temp/scratch roots, including the canonical session temp root
  local t="${TMPDIR:-/tmp}" tc; t="${t%/}"; tc="$(cd "$t" 2>/dev/null && pwd -P)"
  case "$1" in
    "") return 1 ;;
    /tmp|/tmp/*|/private/tmp|/private/tmp/*|/var/tmp|/var/tmp/*|/private/var/tmp|/private/var/tmp/*|*/scratchpad*) return 0 ;;
    "$t"|"$t"/*) return 0 ;;
  esac
  [ -n "$tc" ] && case "$1" in "$tc"|"$tc"/*) return 0 ;; esac
  return 1
}
cmd_check() {
  local manifest="" missing="" strict=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --manifest) [ $# -ge 2 ] || die "--manifest needs a value"; manifest="$2"; shift 2 ;;
      --strict)   strict=1; shift ;;
      *) die "check: unknown arg $1" ;;
    esac
  done
  [ -n "$manifest" ] && [ -f "$manifest" ] || die "check: manifest not found: ${manifest:-<none>}"
  mkwork; WORK_LINKS="$WORK/links"

  local IFS='|' s sections="$REQUIRED_SECTIONS"
  [ "$strict" -eq 0 ] || sections="$REQUIRED_SECTIONS|$STRICT_SECTIONS"
  for s in $sections; do
    grep -qiE "^##[[:space:]]+$s[[:space:]]*$" "$manifest" || missing="${missing}section:${s};"
  done
  unset IFS
  # FEAT-2: a pending delegate may only be closed over as an operator-authorised PARTIAL
  local gate partial=false
  gate="$(field "$manifest" "Delegates gate" delegates_gate)"
  if [ "$gate" = "PARTIAL" ] && [ -n "$(field "$manifest" "Delegates gate" partial_authorized_by)" ]; then
    partial=true
    grep -m1 -E '^#[[:space:]]' "$manifest" | grep -qE '^#[[:space:]]+PARTIAL' || missing="${missing}partial-title;"
  elif [ "$gate" != "PASS" ]; then missing="${missing}delegates_gate!=PASS;"
  fi
  local k
  for k in session_id link command; do
    [ -n "$(field "$manifest" Recovery "$k")" ] || missing="${missing}field:${k};"
  done
  local mp; mp="$(field "$manifest" Self-location manifest_path)"; mp="${mp/#\~/$HOME}"
  if [ -z "$mp" ]; then missing="${missing}field:manifest_path;"
  elif is_ephemeral "$mp" || is_ephemeral "$(canon "$mp")"; then
    missing="${missing}ephemeral-manifest-path;" # a close-out artifact must survive temp cleanup
  elif ! { [ -f "$mp" ] && { [ "$mp" -ef "$manifest" ] || cmp -s "$mp" "$manifest"; }; }; then
    missing="${missing}manifest-path-mismatch;" # must resolve to the manifest being checked
  fi
  local content="Instruction tree|HITL decisions|Roadmap|Artifact index"
  [ "$strict" -eq 0 ] || content="$content|$STRICT_SECTIONS"
  local IFS='|'
  for k in $content; do
    if grep -qiE "^##[[:space:]]+$k[[:space:]]*$" "$manifest" && section_body_empty "$manifest" "$k"; then
      missing="${missing}empty-section:${k};"
    fi
  done
  unset IFS
  # FEAT-16: the recovery triple must hold together, not just be present
  local sid link cmd tr
  sid="$(field "$manifest" Recovery session_id)"; link="$(field "$manifest" Recovery link)"
  cmd="$(field "$manifest" Recovery command)"
  case "$link" in ""|http://*|https://*) ;; *) missing="${missing}link-not-url;" ;; esac
  if [ -n "$sid" ] && [ -n "$cmd" ]; then
    case "$cmd" in *"$sid"*) ;; *) missing="${missing}command-lacks-session-id;" ;; esac
  fi
  tr="$(field "$manifest" Recovery transcript_path)"
  [ -z "$tr" ] || [ -f "${tr/#\~/$HOME}" ] || missing="${missing}transcript-missing;"
  # FEAT-17/22: every backticked absolute path must exist and be durable, unless its line
  # declares it "(ephemeral)"
  local line p
  EPH_T="${TMPDIR:-/tmp}"; EPH_T="${EPH_T%/}" # the session temp root is ephemeral too
  while IFS= read -r line; do
    { printf '%s\n' "$line" | grep -oE '`(/|~/)[^`]*`' || true; } | tr -d '`' | while IFS= read -r p; do
      case "$line" in *"(ephemeral)"*) continue ;; esac
      case "$p" in
        /tmp|/tmp/*|/private/tmp|/private/tmp/*|/var/tmp|/var/tmp/*|*/scratchpad*) printf 'ephemeral-link:%s;' "$p" ;;
        "$EPH_T"|"$EPH_T"/*) printf 'ephemeral-link:%s;' "$p" ;;
        *) [ -e "${p/#\~/$HOME}" ] || printf 'broken-link:%s;' "$p" ;;
      esac
    done
  done < "$manifest" > "$WORK_LINKS"
  missing="${missing}$(cat "$WORK_LINKS")"

  if [ -n "$missing" ]; then
    printf '{"status":"fail","missing":"%s"}\n' "$(jstr "$missing")"
    exit 2
  fi
  printf '{"status":"pass","partial":%s,"manifest":"%s"}\n' "$partial" "$(jstr "$manifest")"
}

# FEAT-34: git anchor — branch@HEAD + UTC, every uncommitted file named, worktrees listed.
# Read-only: it never stages, stashes or discards anything. rc 0 clean · 2 dirty · 1 not a repo.
cmd_anchor() {
  local repo=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) [ $# -ge 2 ] || die "--repo needs a value"; repo="$2"; shift 2 ;;
      *) die "anchor: unknown arg $1" ;;
    esac
  done
  [ -n "$repo" ] && git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "anchor: not a git work tree: ${repo:-<none>}" 1
  mkwork
  local branch head stamp dirty="" wts="" l sep=""
  branch="$(git -C "$repo" branch --show-current)"; [ -n "$branch" ] || branch="(detached)"
  head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '(no-commits)')"
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local st; st="$WORK/anchor.status"
  git -C "$repo" status --porcelain=v1 -z --untracked-files=all > "$st"
  while IFS= read -r -d '' l; do # -z: names never quoted (spaces, non-ASCII)
    [ -n "$l" ] || continue; dirty="${dirty}${sep}\"$(jstr "$l")\""; sep=","
  done < "$st"
  sep=""
  while IFS= read -r l; do
    case "$l" in "worktree "*) wts="${wts}${sep}\"$(jstr "${l#worktree }")\""; sep="," ;; esac
  done <<EOF
$(git -C "$repo" worktree list --porcelain)
EOF
  printf '{"anchor":"%s@%s · %s","dirty":[%s],"worktrees":[%s]}\n' \
    "$(jstr "$branch")" "$head" "$stamp" "$dirty" "$wts"
  [ -z "$dirty" ] || exit 2
}

# PII patterns (email · BR phone · CPF). Metadata-only manifests should match none.
# Phones: with the +55/55 prefix any spacing; without it, a formatted domestic number — DDD in
# parentheses, or separated from the subscriber number, or a separator before the last 4 digits.
# DDD digits are 1-9 (no Brazilian area code has a 0); mobile = 9 + 8 digits, landline 2-5 + 7.
# A bare 10-11 digit run with no formatting is not matched on purpose (timestamps, ids).
PHONE_SUB='(9[0-9]{4}|[2-5][0-9]{3})'
PII_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'\
'|(\+?55[ .-]*\(?[1-9][1-9]\)?[ .-]*'"$PHONE_SUB"'[ .-]?[0-9]{4})'\
'|((^|[^0-9])\([1-9][1-9]\) ?'"$PHONE_SUB"'[ .-]?[0-9]{4}([^0-9]|$))'\
'|((^|[^0-9])[1-9][1-9][ .-]'"$PHONE_SUB"'[ .-]?[0-9]{4}([^0-9]|$))'\
'|((^|[^0-9])[1-9][1-9][ .-]?'"$PHONE_SUB"'[ .-][0-9]{4}([^0-9]|$))'\
'|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}'

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
# Unformatted CPF: an isolated run of exactly 11 digits whose two check digits are valid
# (checksum keeps ids and timestamps out; all-equal digits are not a real CPF).
cpf_bare_hit() {
  awk '{
    line = $0
    while (match(line, /[0-9]+/)) {
      d = substr(line, RSTART, RLENGTH); line = substr(line, RSTART + RLENGTH)
      if (length(d) != 11) continue
      same = 1; for (i = 2; i <= 11; i++) if (substr(d, i, 1) != substr(d, 1, 1)) same = 0
      if (same) continue
      s = 0; for (i = 1; i <= 9; i++) s += substr(d, i, 1) * (11 - i)
      c1 = (s * 10) % 11; if (c1 == 10) c1 = 0
      s = 0; for (i = 1; i <= 9; i++) s += substr(d, i, 1) * (12 - i); s += c1 * 2
      c2 = (s * 10) % 11; if (c2 == 10) c2 = 0
      if (c1 == substr(d, 10, 1) && c2 == substr(d, 11, 1)) { hit = 1; exit }
    }
  } END { exit hit ? 0 : 1 }' "$1"
}
pii_hit() {
  grep -qE "$PII_RE" "$1.norm" || grep -qE "$PII_RE" "$1.flat" || cpf_bare_hit "$1.norm" || cpf_bare_hit "$1.flat"
}
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
  local rnd; rnd="$(head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')" # bounded read: no SIGPIPE
  printf 'k = "%s%s"\n' "$p" "${rnd:0:36}" > "$STAGE/ctl"
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

  local s base target status i=0 staged tmp bak seen=() x dup
  for s in "${srcs[@]}"; do
    i=$((i + 1))
    [ -f "$s" ] && [ ! -L "$s" ] || { refused=1; printf '{"src":"%s","status":"skipped-not-regular-file"}\n' "$(jstr "$s")"; continue; }
    base="${s##*/}"; target="$dest/$base" # no $(...): keeps a trailing newline byte
    dup=0; for x in ${seen[@]+"${seen[@]}"}; do [ "$x" = "$base" ] && dup=1; done # exact bytes, no delimiter
    if [ "$dup" -eq 1 ]; then # two sources, one destination name
      refused=1; printf '{"src":"%s","dest":"%s","status":"refused-basename-collision"}\n' "$(jstr "$s")" "$(jstr "$target")"; continue
    fi
    seen+=("$base")
    staged="$STAGE/f$i"
    cp -- "$s" "$staged" || die "persist: cannot stage $base" 1
    if [ ! -f "$s" ] || [ -L "$s" ]; then # source swapped during the copy
      rm -f -- "$staged"; refused=1
      printf '{"src":"%s","status":"skipped-not-regular-file"}\n' "$(jstr "$s")"; continue
    fi
    if is_binary "$staged"; then status="refused-binary"; refused=1
    else
      views "$staged"
      if secret_hit "$staged"; then status="refused-secret"; refused=1
      elif pii_hit "$staged"; then status="refused-pii"; refused=1
      elif [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
        status="refused-dest-not-regular"; refused=1 # symlink/dir: cmp would follow it, mv would descend
      elif [ -f "$target" ] && cmp -s "$staged" "$target"; then status="unchanged"
      elif [ "$apply" -eq 1 ]; then
        mkdir -p -- "$dest"
        # the rename temp sits next to the target (same filesystem ⇒ atomic mv) and holds only
        # already-scanned staged bytes; it is registered so any failure path removes it
        tmp="$(mktemp "$dest/.$base.cm-tmp.XXXXXX")" || die "persist: cannot create temp for $base" 1
        DEST_TMPS+=("$tmp") # created exclusively by mktemp: a planted name is never written through
        cp -- "$staged" "$tmp" || die "persist: cannot write $base" 1
        # never lose the previous version: a differing target is kept as a timestamped backup
        if [ -f "$target" ]; then
          bak="$(mktemp "$target.bak.$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")" || die "persist: cannot back up $base" 1
          cp -p -- "$target" "$bak" || die "persist: cannot back up $base" 1
        fi
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
  CLIP_INCOMPLETE=0
  if [ -n "${MAOS_CLIP_COPY:-}" ] && [ -n "${MAOS_CLIP_PASTE:-}" ]; then
    CLIP_COPY_CMD="$MAOS_CLIP_COPY"; CLIP_PASTE_CMD="$MAOS_CLIP_PASTE"; return
  elif [ -n "${MAOS_CLIP_COPY:-}" ] || [ -n "${MAOS_CLIP_PASTE:-}" ]; then
    CLIP_INCOMPLETE=1; CLIP_COPY_CMD=""; CLIP_PASTE_CMD=""; return # half an override is refused
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
  if [ "$CLIP_INCOMPLETE" -eq 1 ]; then
    printf '{"status":"unverified","reason":"incomplete-clip-override","detail":"set MAOS_CLIP_COPY and MAOS_CLIP_PASTE together, or neither","hint":"%s"}\n' "$hint"; exit 4
  fi
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
  anchor)  shift; cmd_anchor "$@" ;;
  clip)    shift; cmd_clip "$@" ;;
  --version) echo "close-out-manifest.sh $VERSION" ;;
  -h|--help|"") usage ;;
  *) usage >&2; exit 1 ;;
esac
