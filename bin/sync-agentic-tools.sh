#!/usr/bin/env bash
# sync-agentic-tools.sh — sync agentic-tools from source repos into agent-harness
# discovery surfaces (omp + Claude Code), idempotently.
#
# Default: DRY-RUN (report only). Pass --apply to write.
#
# Surfaces (verified against omp discovery contracts, 2026-08-27):
#   skills   -> ~/.agents/skills/<name>          (symlink to repo skill dir)
#   agents   -> ~/.omp/agent/agents/<name>.md    (symlink; source file MUST carry
#               `name`+`description` frontmatter, else omp skips it — we warn)
#   rules    -> ~/.agents/rules/<name>.md        (symlink; source should carry
#               `description` frontmatter, else it loads-but-lurks — we warn)
#   commands -> ~/.agents/commands/ + ~/.claude/commands/ (symlinks)
#
# Never touches: files that are not symlinks into the source repos, the
# .skill-lock.json (marketplace provenance ledger, harness-owned), hooks
# (different contract per harness — manual translation only).
set -euo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

MAOS="${MAOS_DIR:-$HOME/Projects/multi-agent-os}"
VEK="${VEK_DIR:-$HOME/Projects/vek-ai-toolkit}"
REPOS=("$MAOS" "$VEK")

SKILLS_DIR="$HOME/.agents/skills"
AGENTS_DIR="$HOME/.omp/agent/agents"
RULES_DIR="$HOME/.agents/rules"
COMMANDS_DIRS=("$HOME/.agents/commands" "$HOME/.claude/commands")

say() { printf '%s\n' "$*"; }
link() { # link <target> <linkpath>
  local target="$1" linkpath="$2"
  if [ -L "$linkpath" ] && [ "$(readlink "$linkpath")" = "$target" ]; then return 0; fi
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    say "SKIP (real file, not ours): $linkpath"; return 0
  fi
  say "LINK  $linkpath -> $target"
  if [ "$APPLY" = 1 ]; then ln -sfn "$target" "$linkpath"; fi
  return 0
}
has_fm() { grep -qE "^$2:" "$1" 2>/dev/null; }

mkdir -p "$AGENTS_DIR" "$RULES_DIR" "${COMMANDS_DIRS[@]}"

say "=== skills"
for repo in "${REPOS[@]}"; do
  [ -d "$repo/skills" ] || continue
  for d in "$repo"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    link "${d%/}" "$SKILLS_DIR/$(basename "$d")"
  done
done

say "=== agents (frontmatter name+description required by omp)"
[ -d "$VEK/agents" ] && for f in "$VEK"/agents/*.md; do
  case "$(basename "$f")" in README.md|AGENTS.md|COWORK-*) continue;; esac
  if has_fm "$f" name && has_fm "$f" description; then
    name="$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//')"
    link "$f" "$AGENTS_DIR/$name.md"
  else
    say "WARN (no omp frontmatter, skipped): $f"
  fi
done

say "=== rules (description recommended for rulebook visibility)"
for repo in "${REPOS[@]}"; do
  [ -d "$repo/rules" ] || continue
  for f in "$repo"/rules/*.md; do
    has_fm "$f" description || say "WARN (no description, loads-but-lurks): $f"
    link "$f" "$RULES_DIR/$(basename "$f")"
  done
done

say "=== commands"
for repo in "${REPOS[@]}"; do
  [ -d "$repo/commands" ] || continue
  for f in "$repo"/commands/*.md; do
    case "$(basename "$f")" in README.md) continue;; esac
    for dir in "${COMMANDS_DIRS[@]}"; do link "$f" "$dir/$(basename "$f")"; done
  done
done

say "=== prune stale links pointing into the source repos"
for dir in "$SKILLS_DIR" "$AGENTS_DIR" "$RULES_DIR" "${COMMANDS_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 1 -type l | while read -r l; do
    target="$(readlink "$l")"
    case "$target" in
      "$MAOS"/*|"$VEK"/*) [ -e "$target" ] || { say "PRUNE (target gone): $l"; if [ "$APPLY" = 1 ]; then rm "$l"; fi; } ;;
    esac
  done
done

if [ "$APPLY" = 0 ]; then say ""; say "DRY-RUN — re-run with --apply to write."; fi
exit 0
