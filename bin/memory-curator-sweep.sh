#!/usr/bin/env bash
# MAOS — memory-curator-sweep · deterministic READ-ONLY pre-scan (ADR-012)
# ----------------------------------------------------------------------------
# WHY: the memory-curator agent (Mnemosyne) is on-demand only — someone must
#   remember to run it, and in an amnesic-agent ecosystem "someone must
#   remember" is the failure mode itself. This script is the deterministic
#   skeleton of the sleep-time extension: a no-LLM pre-scan that emits a
#   WORK-QUEUE JSON of curation findings. The agent (probabilistic muscle)
#   consumes the queue and applies judgment ONLY where the scan flagged work.
#
# GUARANTEES (the ADR-012 safety bounds):
#   READ-ONLY — this script NEVER mutates the corpus. Its only output is the
#   JSON envelope on stdout (+ a 1-line human summary on stderr). Mutations
#   happen later, in-session, under the normal gates.
#
# Checks (each finding: {check, severity, path, detail}):
#   index-over-cap        index file size vs --cap-bytes (skipped if no cap)
#   dangling-ref          index links pointing at files that do not exist
#   orphan-file           corpus .md files not referenced by the index
#   stale-marker          re-validation dates in the past
#   journal-accumulation  journal session-dirs with more than --journal-threshold files
#   dup-title             identical H1 titles across different files
#   pending-artifact      "#TBD" placeholders (pointer-freshness detector v1)
#
# Portability: AAIF cross-vendor — POSIX Bash 3.2 + jq only. stat is probed
#   (BSD -f%z vs GNU -c%s), never assumed. Dates compare lexicographically
#   (ISO YYYY-MM-DD), no date-math dependency.
# Exit codes ([C06]): 0 clean · 1 usage/validation error · 2 findings present
#   (non-fatal signal: there is curation work in the queue).
set -euo pipefail

# Resolve jq ONCE to an absolute path (PATH could mutate mid-run under a hook/scheduler)
JQ="$(command -v jq)" || { echo "memory-curator-sweep: jq is required" >&2; exit 1; }

usage() {
  cat <<EOF
MAOS memory-curator-sweep — deterministic READ-ONLY pre-scan for Mnemosyne (ADR-012).

USAGE
  $(basename "$0") [--corpus <dir>] [--index <file>] [--cap-bytes N] [--journal-threshold N]

  --corpus <dir>          corpus root to scan (default: current directory)
  --index <file>          index file (default: <corpus>/MEMORY.md when present)
  --cap-bytes <N>         index byte-cap; enables the index-over-cap check
  --journal-threshold <N> flag journal session-dirs with more than N files (default 10)

OUTPUT
  Work-queue JSON envelope on stdout; 1-line summary on stderr.
  Exit 0 = clean · 1 = error · 2 = findings present.
EOF
}

CORPUS="$PWD"
INDEX=""
CAP_BYTES=""
JOURNAL_THRESHOLD=10

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus) CORPUS="${2:?--corpus needs a value}"; shift 2 ;;
    --index) INDEX="${2:?--index needs a value}"; shift 2 ;;
    --cap-bytes) CAP_BYTES="${2:?--cap-bytes needs a value}"; shift 2 ;;
    --journal-threshold) JOURNAL_THRESHOLD="${2:?--journal-threshold needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "memory-curator-sweep: unknown option '$1'" >&2; usage >&2; exit 1 ;;
  esac
done

[ -d "$CORPUS" ] || { echo "memory-curator-sweep: corpus dir not found: $CORPUS" >&2; exit 1; }
CORPUS="$(cd "$CORPUS" && pwd)"
[ -n "$INDEX" ] || { [ -f "$CORPUS/MEMORY.md" ] && INDEX="$CORPUS/MEMORY.md" || INDEX=""; }
case "$JOURNAL_THRESHOLD" in (*[!0-9]*|'') echo "memory-curator-sweep: --journal-threshold must be a positive integer" >&2; exit 1 ;; esac
if [ -n "$CAP_BYTES" ]; then
  case "$CAP_BYTES" in (*[!0-9]*|'') echo "memory-curator-sweep: --cap-bytes must be a positive integer" >&2; exit 1 ;; esac
fi

# stat portability probe (never assume the platform flavor)
file_size() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || wc -c < "$1" | tr -d ' '
}

TODAY="$(date +%Y-%m-%d)"
QUEUE="$(mktemp -t mem-sweep.XXXXXX)"
trap 'rm -f "$QUEUE"' EXIT

emit() { # emit <check> <severity> <path> <detail>
  "$JQ" -cn --arg c "$1" --arg s "$2" --arg p "$3" --arg d "$4" \
    '{check:$c, severity:$s, path:$p, detail:$d}' >> "$QUEUE"
}

# Corpus .md inventory: top-level only (journal/archive handled separately).
# NUL-safe iteration is overkill here (memory slugs are [word.-]), but names
# with spaces must not silently skip — use find -print0 where iteration matters.

# --- Check 1: index-over-cap ---------------------------------------------------
if [ -n "$INDEX" ] && [ -f "$INDEX" ] && [ -n "$CAP_BYTES" ]; then
  sz="$(file_size "$INDEX")"
  if [ "$sz" -gt "$CAP_BYTES" ]; then
    emit index-over-cap high "$INDEX" "index is ${sz}B > cap ${CAP_BYTES}B — respond by TIERING (move detail to topic files), never by deleting content"
  fi
fi

# --- Check 2 + 3: dangling-ref / orphan-file (need an index) -------------------
if [ -n "$INDEX" ] && [ -f "$INDEX" ]; then
  index_dir="$(cd "$(dirname "$INDEX")" && pwd)"
  refs="$(grep -o ']([A-Za-z0-9._/-]*\.md)' "$INDEX" 2>/dev/null | sed 's/^](//; s/)$//' | sort -u || true)"

  # dangling: referenced but absent.
  # Path-traversal guard (amazon-q #268): NEVER probe outside the corpus —
  # a ref with a `..` component, or an absolute ref outside $CORPUS, is itself
  # the finding (severity high) and is never stat'ed. Keeps the existence-probe
  # oracle inside the corpus boundary (same class as script-safety safe_rm).
  if [ -n "$refs" ]; then
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      out_of_corpus=0
      case "/$ref/" in */../*) out_of_corpus=1 ;; esac
      case "$ref" in
        /*) case "$ref" in "$CORPUS"/*) ;; *) out_of_corpus=1 ;; esac; tgt="$ref" ;;
        *) tgt="$index_dir/$ref" ;;
      esac
      if [ "$out_of_corpus" = 1 ]; then
        emit dangling-ref medium "$INDEX" "index references '$ref' which resolves outside the corpus — not probed (path-traversal guard); the agent must verify the ref is intentional"
        continue
      fi
      [ -f "$tgt" ] || emit dangling-ref medium "$INDEX" "index references '$ref' which does not exist"
    done <<EOF
$refs
EOF
  fi

  # orphan: present but unreferenced (top-level .md next to the index;
  # journal/ + archives are excluded — they are lazily-loaded by design).
  # Compare BASENAMES on both sides — an index ref written as `./file.md` or
  # `sub/file.md` must not turn an existing file into a false orphan (qodo #268).
  ref_basenames="$(printf '%s\n' "$refs" | sed 's|.*/||' | sort -u)"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    [ "$f" = "$INDEX" ] && continue
    case "$base" in MEMORY*|*archive*|*Archive*) continue ;; esac
    printf '%s\n' "$ref_basenames" | grep -qx "$base" || \
      emit orphan-file low "$f" "not referenced by the index — candidate for an index line or explicit archive"
  done < <(find "$index_dir" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
fi

# --- Check 4: stale-marker (re-validation dates in the past) -------------------
while IFS= read -r -d '' f; do
  # matches "re-validation: 2026-09-16" · "Calendar re-validation 2026-12-22" (case-insensitive)
  hits="$(grep -in 're-validation:\{0,1\} *[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$f" 2>/dev/null || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r line; do
    d="$(printf '%s\n' "$line" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' | head -1)"
    [ -n "$d" ] || continue
    if [ "$d" \< "$TODAY" ]; then
      ln="${line%%:*}"
      emit stale-marker medium "$f" "re-validation date $d is past (line $ln) — re-validate, do NOT auto-delete"
    fi
  done <<EOF
$hits
EOF
done < <(find "$CORPUS" -maxdepth 1 -name '*.md' -print0 2>/dev/null)

# --- Check 5: journal-accumulation ---------------------------------------------
if [ -d "$CORPUS/journal" ]; then
  while IFS= read -r -d '' d; do
    n="$(find "$d" -maxdepth 1 -type f | wc -l | tr -d ' ')"
    if [ "$n" -gt "$JOURNAL_THRESHOLD" ]; then
      emit journal-accumulation low "$d" "$n files (> $JOURNAL_THRESHOLD) — promotion candidates: journal → topic files"
    fi
  done < <(find "$CORPUS/journal" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
fi

# --- Check 6: dup-title (identical H1 across different files) -------------------
TITLES="$(mktemp -t mem-sweep-titles.XXXXXX)"
while IFS= read -r -d '' f; do
  t="$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# *//' || true)"
  [ -n "$t" ] && printf '%s\t%s\n' "$t" "$f" >> "$TITLES"
done < <(find "$CORPUS" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
if [ -s "$TITLES" ]; then
  cut -f1 "$TITLES" | sort | uniq -d | while IFS= read -r dup; do
    [ -n "$dup" ] || continue
    files="$(grep -F "$dup	" "$TITLES" | cut -f2 | tr '\n' ' ')"
    emit dup-title medium "$CORPUS" "H1 '$dup' appears in multiple files: ${files}— dedup/merge candidates"
  done
fi
rm -f "$TITLES"

# --- Check 7: pending-artifact (#TBD pointer-freshness detector) ----------------
while IFS= read -r -d '' f; do
  n="$(grep -c '#TBD' "$f" 2>/dev/null || true)"
  [ -n "$n" ] && [ "$n" -gt 0 ] && \
    emit pending-artifact low "$f" "$n '#TBD' placeholder(s) — deliverable may exist; backfill the pointer (never-backfilled placeholders are the pointer-freshness scar)"
done < <(find "$CORPUS" -maxdepth 1 -name '*.md' -print0 2>/dev/null)

# --- Envelope -------------------------------------------------------------------
count="$(wc -l < "$QUEUE" | tr -d ' ')"
verdict="CLEAN"; [ "$count" -gt 0 ] && verdict="FINDINGS"
"$JQ" -s --arg corpus "$CORPUS" --arg index "${INDEX:-}" --arg v "$verdict" \
   --arg today "$TODAY" \
  '{sweep:"memory-curator-sweep", version:"0.1.0", date:$today, corpus:$corpus,
    index:(if $index=="" then null else $index end), verdict:$v,
    counts:(group_by(.check) | map({key:.[0].check, value:length}) | from_entries),
    findings:.}' "$QUEUE"
echo "memory-curator-sweep: $verdict — $count finding(s) in $CORPUS (read-only; queue on stdout)" >&2

[ "$count" -eq 0 ] && exit 0 || exit 2
