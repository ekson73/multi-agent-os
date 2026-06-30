#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance lib: agentshield-scan.sh
# Purpose: C6 content-security detection (RULE-012). Pure + deterministic +
#   testable. Scans a CHANNEL's payload (a Bash tool_input command, or a Task
#   model_output prompt) for (a) a leaked secret and (b) egress to a non-
#   allowlisted host, returning a single RULE-012 c6_egress_check JSON line.
#
# The verdict is BLOCKING by design (sibling of the advisory C1 conductor scan):
#   secret_match≠null               => decision=block   (classification=secret)
#   egress host ∉ allowlist (set)   => decision=block   (classification=egress)
#   git verification bypass         => decision=block   (classification=hook_bypass)
#   otherwise                       => decision=allow    (classification=clean)
# Egress enforcement is OPT-IN: with an EMPTY allowlist (the default) only secrets
# block — the availability-safe posture (a matched SECRET always blocks; an
# unconfigured egress policy never blocks real work). When an allowlist IS passed,
# any extracted egress host outside it blocks.
#
# SECURITY INVARIANT (leak-safe by construction): the raw payload is NEVER
# serialized into the JSON. Every emitted field value is drawn from a FIXED
# vocabulary — channel ∈ {tool_input, model_output}, classification ∈
# {clean, secret, egress, hook_bypass}, secret_match ∈ the signature-id corpus
# below (all `[a-z_]`), decision ∈ {allow, block}. So `secret_match` reports the
# KIND of secret (e.g. "anthropic_key"), never the secret VALUE, and no field can
# carry attacker-controlled bytes ⇒ the logged field is both leak-safe and
# JSON-injection-safe with zero escaping.
#
# bash 3.2 compatible (no associative arrays; no `\b` — BSD grep lacks it). No
# side effects: echoes JSON only.
# Version: 1.0.0
# Protocol: ADR-006 §4 content-security · moe-hub-architecture · maos-hub spec RULE-012
# ═══════════════════════════════════════════════════════════════════════════════

# as_scan_secret <text> -> the signature-id of the FIRST high-precision secret
#   match, or empty. Corpus is precision-over-recall: this is a BLOCKING gate, so
#   a false positive blocks real work — every signature is a tight, well-known
#   credential shape (gitleaks-grade), not a heuristic. Signature ids are `[a-z_]`
#   only (guaranteed JSON-safe). NEVER echoes the matched value.
as_scan_secret() {
    local text="$1"
    [ -n "$text" ] || return 0
    # Most-specific first. `grep -E` (ERE) is portable to BSD/macOS + GNU; the
    # `{n,}` interval quantifiers and POSIX classes work on both.
    if printf '%s' "$text" | grep -Eq 'sk-ant-[A-Za-z0-9_-]{8,}'; then
        echo "anthropic_key"; return 0
    fi
    if printf '%s' "$text" | grep -Eq 'gh[opsu]_[A-Za-z0-9]{36,}'; then
        echo "github_token"; return 0
    fi
    if printf '%s' "$text" | grep -Eq 'AKIA[0-9A-Z]{16}'; then
        echo "aws_access_key"; return 0
    fi
    if printf '%s' "$text" | grep -Eq 'xox[baprs]-[A-Za-z0-9-]{10,}'; then
        echo "slack_token"; return 0
    fi
    if printf '%s' "$text" | grep -Eq '[-]{5}BEGIN [A-Z ]*PRIVATE KEY[-]{5}'; then
        echo "private_key"; return 0
    fi
    if printf '%s' "$text" | grep -Eq 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'; then
        echo "jwt"; return 0
    fi
    return 0
}

# as_bash_bypass <command> -> "hook_bypass" if the command bypasses the
#   verification hooks that enforce the secret-at-rest floor (git --no-verify),
#   else empty. Precision-over-recall: must contain BOTH `git` and `--no-verify`
#   (git before the flag). Bash-channel only (a Task prompt merely MENTIONING the
#   flag must not block — the hook calls this only on the Bash branch).
as_bash_bypass() {
    local cmd="$1"
    case "$cmd" in
        *git*--no-verify*) echo "hook_bypass" ;;
    esac
}

# as_egress_targets <command> -> newline-list of egress hosts referenced in the
#   command (scheme://host URLs + user@host ssh/scp forms), de-duplicated. Empty
#   when none. Pure extraction (no `\b`; BSD-safe). Heuristic by design — it only
#   gates when an allowlist is configured, where blocking-on-extracted-host is the
#   conservative (precision) choice.
as_egress_targets() {
    local cmd="$1"
    [ -n "$cmd" ] || return 0
    {
        # scheme://[user@]host[:port][/path]  -> host
        printf '%s\n' "$cmd" \
            | grep -Eo '[a-zA-Z][a-zA-Z0-9+.-]*://[^/[:space:]"'"'"'`]+' \
            | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@]*@##; s#[:/].*$##'
        # user@host (ssh/scp/rsync)           -> host
        printf '%s\n' "$cmd" \
            | grep -Eo '[A-Za-z0-9._-]+@[A-Za-z0-9.-]+' \
            | sed -E 's#^[^@]*@##; s#:.*$##'
    } | sed '/^$/d' | sort -u
}

# _as_host_allowed <host> <allowlist> -> 0 if host matches an allowlist entry
#   (exact, or a subdomain of `.<entry>`), else 1. Allowlist entries are
#   whitespace/comma-separated host suffixes.
_as_host_allowed() {
    local host="$1" allowlist="$2" entry
    for entry in $(printf '%s' "$allowlist" | tr ',' ' '); do
        [ -n "$entry" ] || continue
        case "$host" in
            "$entry") return 0 ;;
            *".$entry") return 0 ;;
        esac
    done
    return 1
}

# as_json <channel> <classification> <secret_match-or-empty> <decision>
#   -> the single RULE-012 c6_egress_check JSON line. All inputs come from the
#   fixed vocabulary documented in the header (no raw payload) ⇒ no escaping.
as_json() {
    local channel="$1" classification="$2" secret="$3" decision="$4"
    local sm
    if [ -n "$secret" ]; then sm="\"$secret\""; else sm="null"; fi
    printf '{"rule":"RULE-012","event":"c6_egress_check","channel":"%s","classification":"%s","secret_match":%s,"decision":"%s"}\n' \
        "$channel" "$classification" "$sm" "$decision"
}

# as_check <channel> <payload> [allowlist] -> single RULE-012 JSON line.
#   decision=block when secret_match≠null (always) OR an egress host ∉ a non-empty
#   allowlist; else allow. (git --no-verify is a Bash-only concern handled by the
#   hook via as_bash_bypass; it is not folded here so a model_output prompt that
#   merely mentions the flag does not block.)
as_check() {
    local channel="${1:-}" payload="${2:-}" allowlist="${3:-}"
    local secret hosts h
    secret="$(as_scan_secret "$payload")"

    if [ -n "$secret" ]; then
        as_json "$channel" "secret" "$secret" "block"
        return 0
    fi

    if [ -n "$allowlist" ]; then
        # `|| true`: an empty grep match makes the extraction pipeline exit non-
        # zero (pipefail); that must NOT abort a `set -e` caller (the test suite
        # and the hook both run under `set -euo pipefail`).
        hosts="$(as_egress_targets "$payload" 2>/dev/null || true)"
        if [ -n "$hosts" ]; then
            while IFS= read -r h; do
                [ -n "$h" ] || continue
                if ! _as_host_allowed "$h" "$allowlist"; then
                    as_json "$channel" "egress" "" "block"
                    return 0
                fi
            done <<EOF
$hosts
EOF
        fi
    fi

    as_json "$channel" "clean" "" "allow"
}

# Allow `bash agentshield-scan.sh <channel> <payload> [allowlist]` for ad-hoc use.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    as_check "${1:-}" "${2:-}" "${3:-}"
fi
