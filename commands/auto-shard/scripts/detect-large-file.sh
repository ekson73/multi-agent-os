#!/usr/bin/env bash
# /**
#  * detect-large-file.sh - PreToolUse hook for auto-shard skill
#  *
#  * Detects when Claude Code reads or writes files exceeding size thresholds.
#  * Emits JSON-RPC suggestion to stderr when large file detected.
#  *
#  * @context PreToolUse hook for Read/Write operations
#  * @author Claude-Code
#  * @version 1.0.0
#  * @created 2026-01-25
#  */

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Size thresholds (in bytes)
THRESHOLD_SUGGEST=20480    # 20KB - Optional sharding
THRESHOLD_WARN=40960       # 40KB - Recommended sharding
THRESHOLD_BLOCK=81920      # 80KB - Mandatory sharding

# File patterns to check
PATTERNS_TO_CHECK=(
    "CLAUDE.md"
    "*.md"
)

# Directories to monitor
DIRS_TO_MONITOR=(
    "$HOME/.claude"
    ".claude"
)

# ═══════════════════════════════════════════════════════════════════════════════
# JSON-RPC OUTPUT FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# /**
#  * Emit JSON-RPC suggestion to stderr
#  * @param level: suggest|warn|block
#  * @param file_path: Path to the large file
#  * @param file_size: Size in bytes
#  * @param threshold: Which threshold was exceeded
#  */
emit_suggestion() {
    local level="$1"
    local file_path="$2"
    local file_size="$3"
    local threshold="$4"
    local human_size

    # Convert bytes to human readable
    if (( file_size >= 1048576 )); then
        human_size="$(( file_size / 1048576 ))MB"
    elif (( file_size >= 1024 )); then
        human_size="$(( file_size / 1024 ))KB"
    else
        human_size="${file_size}B"
    fi

    local message
    local instructions
    local code

    case "$level" in
        suggest)
            code=-32010
            message="Large file detected (${human_size}). Consider sharding for better context management."
            instructions="Optional: Run /auto-shard analyze ${file_path}"
            ;;
        warn)
            code=-32011
            message="File exceeds recommended size (${human_size}). Sharding recommended."
            instructions="Recommended: Run /auto-shard full ${file_path} --dry-run"
            ;;
        block)
            code=-32012
            message="File exceeds maximum size (${human_size}). Sharding required before editing."
            instructions="Required: Run /auto-shard full ${file_path}"
            ;;
    esac

    # Emit JSON-RPC to stderr
    cat >&2 <<EOF
{"jsonrpc":"2.0","error":{"code":${code},"message":"${message}","data":{"level":"${level}","file":"${file_path}","size_bytes":${file_size},"size_human":"${human_size}","threshold":"${threshold}","instructions":"${instructions}"}}}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# DETECTION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# /**
#  * Check if file matches monitored patterns
#  * @param file_path: Path to check
#  * @return 0 if matches, 1 if not
#  */
matches_pattern() {
    local file_path="$1"
    local filename
    filename=$(basename "$file_path")

    for pattern in "${PATTERNS_TO_CHECK[@]}"; do
        # shellcheck disable=SC2053
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# /**
#  * Check if file is in monitored directory
#  * @param file_path: Path to check
#  * @return 0 if in monitored dir, 1 if not
#  */
in_monitored_dir() {
    local file_path="$1"
    local abs_path

    # Get absolute path
    if [[ "$file_path" == /* ]]; then
        abs_path="$file_path"
    else
        abs_path="$(pwd)/$file_path"
    fi

    for dir in "${DIRS_TO_MONITOR[@]}"; do
        local expanded_dir
        expanded_dir=$(eval echo "$dir")
        if [[ "$abs_path" == "$expanded_dir"* ]]; then
            return 0
        fi
    done
    return 1
}

# /**
#  * Get file size in bytes
#  * @param file_path: Path to file
#  * @return Size in bytes (or 0 if file doesn't exist)
#  */
get_file_size() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            stat -f%z "$file_path" 2>/dev/null || echo 0
        else
            stat -c%s "$file_path" 2>/dev/null || echo 0
        fi
    else
        echo 0
    fi
}

# /**
#  * Check file and emit suggestion if needed
#  * @param file_path: Path to check
#  * @return 0 if OK, 1 if blocked
#  */
check_file() {
    local file_path="$1"
    local size

    # Skip if file doesn't exist (new file being written)
    if [[ ! -f "$file_path" ]]; then
        return 0
    fi

    # Skip if not a monitored pattern
    if ! matches_pattern "$file_path"; then
        return 0
    fi

    # Skip if not in monitored directory
    if ! in_monitored_dir "$file_path"; then
        return 0
    fi

    size=$(get_file_size "$file_path")

    if (( size >= THRESHOLD_BLOCK )); then
        emit_suggestion "block" "$file_path" "$size" "80KB"
        return 1
    elif (( size >= THRESHOLD_WARN )); then
        emit_suggestion "warn" "$file_path" "$size" "40KB"
        return 0
    elif (( size >= THRESHOLD_SUGGEST )); then
        emit_suggestion "suggest" "$file_path" "$size" "20KB"
        return 0
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # This script is called as a PreToolUse hook
    # Arguments: $1 = tool_name, $2 = file_path (for Read/Write)

    local tool_name="${1:-}"
    local file_path="${2:-}"

    # Only check on Read or Write operations
    case "$tool_name" in
        Read|Write|Edit)
            if [[ -n "$file_path" ]]; then
                check_file "$file_path"
                exit $?
            fi
            ;;
        *)
            # Not a file operation, pass through
            exit 0
            ;;
    esac

    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI INTERFACE (for manual testing)
# ═══════════════════════════════════════════════════════════════════════════════

if [[ "${1:-}" == "--test" ]]; then
    # Manual test mode
    shift
    file_path="${1:-}"

    if [[ -z "$file_path" ]]; then
        echo "Usage: $0 --test <file_path>"
        exit 1
    fi

    echo "Testing file: $file_path"
    echo "Size: $(get_file_size "$file_path") bytes"
    echo "Matches pattern: $(matches_pattern "$file_path" && echo "yes" || echo "no")"
    echo "In monitored dir: $(in_monitored_dir "$file_path" && echo "yes" || echo "no")"
    echo ""
    echo "Checking..."
    check_file "$file_path"
    echo "Exit code: $?"
    exit 0
fi

if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
detect-large-file.sh - PreToolUse hook for auto-shard skill

Usage as hook:
  Called automatically by Claude Code before Read/Write/Edit operations.

Usage for testing:
  $0 --test <file_path>   Test detection on a specific file

Thresholds:
  20KB - Suggest sharding (informational)
  40KB - Warn about sharding (recommended)
  80KB - Block and require sharding

Monitored patterns:
  CLAUDE.md, *.md

Monitored directories:
  ~/.claude/, .claude/

Exit codes:
  0 - OK (or suggestion/warning emitted)
  1 - Blocked (file too large)
EOF
    exit 0
fi

# Run as hook
main "$@"
