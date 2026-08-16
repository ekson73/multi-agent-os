#!/usr/bin/env bash
# /**
#  * CHANGELOG gate — does this changed-file set alter the consumable contract without an entry?
#  * @context Run by .github/workflows/changelog-required.yml from a TRUSTED checkout of main;
#  *          the PR head is never checked out or executed. Reads the changed paths on stdin,
#  *          one per line (the workflow gets them from the API).
#  * @reason  Classification needs filesystem state, not a path regex — see scripts/entry-classifier.sh.
#  *          #348 measured what a regex costs here: 30 nested entries missed, 4 ALL-CAPS docs
#  *          wrongly flagged. This script reuses the validator's own predicate instead.
#  * @impact  Exit 0 = nothing to say (no entry touched, or entry + CHANGELOG). Exit 2 = finding.
#  *          The caller decides whether a finding warns or fails (WARN-before-BLOCK).
#  *
#  * Usage:  git diff --name-only base head | scripts/changelog-required-check.sh
#  * Exit:   0 ok · 2 finding (contract changed, no CHANGELOG entry) · 1 usage/internal error
#  */

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export PLUGIN_ROOT
# shellcheck source=entry-classifier.sh
. "$SCRIPT_DIR/entry-classifier.sh"

CHANGELOG_PATH="${CHANGELOG_PATH:-CHANGELOG.md}"

# Read the changed paths. Empty input is a legitimate "nothing to gate", not an error:
# the caller may have failed to reach the API and chosen to degrade rather than abort.
changed=()
while IFS= read -r line; do
    [ -n "$line" ] || continue
    changed+=("$line")
done

if [ "${#changed[@]}" -eq 0 ]; then
    echo "no changed paths on stdin — nothing to gate"
    exit 0
fi

# Which of them are entries a consumer actually loads?
#
# Caveat, stated rather than hidden: the ancestor walk in is_entry() inspects the TRUSTED
# checkout (main), so a brand-new skill's auxiliary file cannot yet see its sibling SKILL.md
# and is classified as an entry. That over-triggers on new skills only, and in the safe
# direction — a brand-new skill should carry a CHANGELOG entry anyway.
#
# is_entry() is REUSED, not copied — but reuse is only valid where the two consumers ask
# the same question, and here they diverge in exactly one place, found by a discriminating
# control rather than by reading:
#
#   is_entry() answers  "should the structural validator check this file for frontmatter?"
#   this gate asks      "would a CONSUMER notice this change?"
#
# They agree on 7 of 8 probed classes. They disagree on `skills/<name>/profiles/*`: those are
# a skill's parameterisation, loaded by whoever runs it, so a consumer notices — yet they sit
# under a directory holding SKILL.md, so is_entry() correctly (for ITS question) calls them
# sub-documents. Extending here rather than widening is_entry() keeps the validator's reach
# assertion byte-identical (proved file-by-file over 336 tracked paths).
is_consumer_surface() {
    local path="$1"
    case "$path" in
        skills/*/profiles/*) return 0 ;;   # parameterisation IS contract
    esac
    is_entry "$path"
}

entries=()
for path in "${changed[@]}"; do
    case "$path" in
        skills/*|commands/*|agents/*) ;;
        *) continue ;;
    esac
    if is_consumer_surface "$path"; then
        entries+=("$path")
    fi
done

if [ "${#entries[@]}" -eq 0 ]; then
    echo "no contract entry changed — gate not applicable"
    exit 0
fi

for path in "${changed[@]}"; do
    if [ "$path" = "$CHANGELOG_PATH" ]; then
        echo "contract changed (${#entries[@]} entr$( [ "${#entries[@]}" -eq 1 ] && echo y || echo ies )) and $CHANGELOG_PATH updated — ok"
        exit 0
    fi
done

echo "contract changed without a $CHANGELOG_PATH entry:"
printf '%s\n' "${entries[@]}"
exit 2
