#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance lib: conductor-scan.sh
# Purpose: C1 single-conductor detection (RULE-011). Pure + deterministic +
#   testable. Scans a PROJECT scope and a USER scope for the footprint of a
#   competing always-on instruction-layer / orchestration manager (the ones in
#   lib/conductors.txt: bmad-method · superpowers · gstack · ECC · base · ruflo)
#   and returns a single RULE-011 JSON line.
#
# The verdict honours the operator's real environment (they MAY run superpowers/
# gstack globally): a manager found only in USER scope is `taint` (advisory);
# one co-resident in the PROJECT scope (a real second always-on manager in THIS
# repo) is `refuse`. None => `clean`. The hook NEVER aborts the session — the
# enforcement is the LOGGED decision + a loud warning (warn -> correct -> block).
#
# bash 3.2 compatible (no associative arrays). No side effects: echoes JSON only.
# Version: 1.0.0
# Protocol: ADR-006 §4 single-conductor · moe-hub-architecture Invariant 1
# ═══════════════════════════════════════════════════════════════════════════════

# Default registry path = sibling conductors.txt.
_CSC_DEFAULT_REGISTRY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/conductors.txt"

# _csc_managers_in_scope <scope_dir> <registry> -> prints matched manager ids
# (one per line, de-duplicated, sorted). Empty scope_dir or missing dir => none.
_csc_managers_in_scope() {
    local scope_dir="$1" registry="$2"
    [ -n "$scope_dir" ] && [ -d "$scope_dir" ] || return 0
    [ -f "$registry" ] || return 0
    local line manager relpath
    while IFS= read -r line || [ -n "$line" ]; do
        # strip comments / blanks
        case "$line" in ''|'#'*) continue ;; esac
        case "$line" in *'|'*) ;; *) continue ;; esac
        manager="${line%%|*}"
        relpath="${line#*|}"
        # trim surrounding whitespace (bash 3.2-safe)
        manager="${manager#"${manager%%[![:space:]]*}"}"; manager="${manager%"${manager##*[![:space:]]}"}"
        relpath="${relpath#"${relpath%%[![:space:]]*}"}"; relpath="${relpath%"${relpath##*[![:space:]]}"}"
        [ -n "$manager" ] && [ -n "$relpath" ] || continue
        # Reject path-traversal / absolute signatures from a malicious or typo'd
        # registry (CWE-22): a signature must resolve INSIDE the scanned scope.
        # Non-overlapping segment cases: leading ../, embedded /../, trailing
        # /.., bare .., or any absolute path.
        case "$relpath" in ../*|*/../*|*/..|..|/*) continue ;; esac
        if [ -e "$scope_dir/$relpath" ]; then
            echo "$manager"
        fi
    done < "$registry" | sort -u
}

# _csc_json_array <newline-list> -> compact JSON array of quoted strings.
_csc_json_array() {
    local item first=1 out="["
    while IFS= read -r item; do
        [ -n "$item" ] || continue
        # Escape backslashes then quotes so a future registry id containing them
        # can't emit invalid JSON (the registry is data-driven, bash 3.2-safe).
        item="${item//\\/\\\\}"
        item="${item//\"/\\\"}"
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out\"$item\""
    done
    echo "$out]"
}

# csc_scan <project_dir> <user_dir> [registry] -> single RULE-011 JSON line.
#   Fields: rule, event, detected_conductors[], scope, decision.
#   decision: refuse (project-scope match) | taint (user-only match) | clean.
csc_scan() {
    local project_dir="${1:-}" user_dir="${2:-}" registry="${3:-$_CSC_DEFAULT_REGISTRY}"

    local proj_hits user_hits
    proj_hits="$(_csc_managers_in_scope "$project_dir" "$registry")"
    # Project-local installs live under the checkout's own .claude/ (e.g.
    # .claude/skills/<competitor>, .claude/plugins/...). Union those into the
    # PROJECT hits so a project-scoped competitor is caught (refuse), not missed.
    if [ -n "$project_dir" ] && [ -d "$project_dir/.claude" ]; then
        proj_hits="$(printf '%s\n%s\n' "$proj_hits" \
            "$(_csc_managers_in_scope "$project_dir/.claude" "$registry")" \
            | sed '/^$/d' | sort -u)"
    fi
    user_hits="$(_csc_managers_in_scope "$user_dir" "$registry")"

    # union for the detected_conductors list
    local all_hits
    all_hits="$(printf '%s\n%s\n' "$proj_hits" "$user_hits" | sed '/^$/d' | sort -u)"

    local decision scope
    if [ -n "$proj_hits" ]; then
        decision="refuse"; scope="project"
    elif [ -n "$user_hits" ]; then
        decision="taint"; scope="user"
    else
        decision="clean"; scope="none"
    fi

    local arr
    arr="$(printf '%s\n' "$all_hits" | _csc_json_array)"
    printf '{"rule":"RULE-011","event":"c1_conductor_scan","detected_conductors":%s,"scope":"%s","decision":"%s"}\n' \
        "$arr" "$scope" "$decision"
}

# Allow `bash conductor-scan.sh <project_dir> <user_dir> [registry]` for ad-hoc use.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    csc_scan "${1:-}" "${2:-}" "${3:-}"
fi
