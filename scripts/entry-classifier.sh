#!/usr/bin/env bash
# /**
#  * Entry-vs-document classifier — the single definition of "is this path a plugin entry?"
#  * @context Sourced by tests/validate-plugin.sh (structural validation) and by
#  *          scripts/changelog-required-check.sh (the CI CHANGELOG gate). Two consumers,
#  *          one predicate: a second copy would drift, and the drift is exactly the class
#  *          of bug #339/#341 fixed here.
#  * @reason  The rule needs filesystem state (does an ancestor hold a SKILL.md?), so it
#  *          cannot be expressed as a path regex. Every regex attempt either misses nested
#  *          entries or swallows ALL-CAPS documents — both measured, see #348.
#  * @impact  A wrong verdict either lets a contract change ship unannounced (false negative)
#  *          or trains contributors to reach for the escape label (false positive).
#  *
#  * Contract: the caller sets PLUGIN_ROOT before sourcing (or exports it); is_entry takes a
#  * repo-relative path and returns 0 for an entry, 1 for a document/sub-document.
#  */

# PLUGIN_ROOT must be set by the sourcing script. Default to cwd so the file stays
# runnable/sourceable stand-alone for probing.
: "${PLUGIN_ROOT:=$(pwd)}"

is_entry() {
    local path="$1"
    # `skills/<name>/SKILL.md` IS a skill's entry point — all-caps by design, allow before (a).
    #
    # Depth must be guarded explicitly: a `case` glob is NOT pathname expansion, so `*` DOES
    # cross `/` (measured: `skills/a/b/SKILL.md` matches `skills/*/SKILL.md` under bash). Without
    # the guard a nested SKILL.md would be promoted to a root skill entry. No such file exists
    # today (83 SKILL.md, all at depth 1), so this is latent — which is exactly when it is cheap
    # to close. A nested one falls through to the rules below and is classified as a document by
    # its ALL-CAPS stem, which is the correct answer for something that is not a skill root.
    case "$path" in
        skills/*/SKILL.md)
            case "${path%/SKILL.md}" in
                skills/*/*) ;;            # deeper than skills/<name> -> not a root entry
                skills/*) return 0 ;;     # exactly skills/<name>/SKILL.md
            esac
            ;;
    esac
    # (a) An ALL-CAPS basename is a document by repo convention (README.md, SKILL.md,
    #     COWORK-AUTONOMY-POLICY.md), not an entry. Generalizes the former literal
    #     `!= README.md`, which only knew about one of them.
    #     Two traps here, both measured:
    #     (i) test the STEM, not the basename — `.md` is lowercase by definition, so a test
    #         against `README.md` always matches on the extension and never fires.
    #     (ii) `[[:lower:]]`, NOT `[a-z]`: the bracket RANGE is resolved by locale COLLATION,
    #          which in any UTF-8 locale interleaves aAbBcC..., so `[a-z]` matches `README`
    #          under bash. (It does not under zsh — so a probe run in the wrong shell reports
    #          the opposite verdict. Measured: bash+UTF-8 MATCH, zsh nomatch, bash+C nomatch.)
    #          `[[:lower:]]` is the POSIX class that actually means "a lowercase letter" and
    #          agrees across bash/zsh × C/en_US/pt_BR.
    local base="${path##*/}"
    local stem="${base%.*}"
    case "$stem" in
        *[[:lower:]]*) ;;   # contains a lowercase letter -> ordinary entry name
        *) return 1 ;;      # no lowercase at all -> shouty doc
    esac
    # (b) Anything inside a directory holding a SKILL.md is that SKILL's territory:
    #     `commands/auto-shard/operations/*.md` are the skill's sub-documents and were never
    #     meant to carry command frontmatter. Walk ancestors, so depth does not matter.
    #     Deliberately NOT "skip anything nested": `commands/code/analyze/dependencies.md` is a
    #     genuinely nested COMMAND (it has frontmatter) and must keep being validated.
    local d="${path%/*}"
    while [ -n "$d" ] && [ "$d" != "$path" ]; do
        [ -f "$PLUGIN_ROOT/$d/SKILL.md" ] && return 1
        case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac
    done
    return 0
}
