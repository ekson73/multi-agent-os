#!/usr/bin/env bash
# /**
#  * Plugin Structure Validation Script
#  * @context Validates multi-agent-os plugin structure for Claude Code compatibility
#  * @reason Ensure all required files exist and have correct format
#  * @impact Prevents plugin installation failures
#  */

set -euo pipefail

PLUGIN_ROOT="${1:-$(pwd)}"
ERRORS=0
WARNINGS=0

echo "========================================"
echo "  Multi-Agent OS Plugin Validation"
echo "========================================"
echo ""
echo "Plugin Root: $PLUGIN_ROOT"
echo ""

# Helper functions
pass() {
    echo "  ✓ $1"
}

fail() {
    echo "  ✗ $1"
    ((ERRORS++)) || true
}

warn() {
    echo "  ⚠ $1"
    ((WARNINGS++)) || true
}

# Check required directories
echo "Checking required directories..."

for dir in ".claude-plugin" "hooks" "plugin-scripts" "commands" "agents" "skills"; do
    if [ -d "$PLUGIN_ROOT/$dir" ]; then
        pass "$dir/ exists"
    else
        fail "$dir/ missing"
    fi
done
echo ""

# Check plugin.json
echo "Checking plugin.json..."

if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    pass "plugin.json exists"

    # Validate JSON
    if python3 -c "import json; json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))" 2>/dev/null; then
        pass "plugin.json is valid JSON"
    else
        fail "plugin.json is invalid JSON"
    fi

    # Check required fields
    if grep -q '"name"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
        pass "plugin.json has 'name' field"
    else
        fail "plugin.json missing 'name' field"
    fi

    if grep -q '"hooks"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
        pass "plugin.json has 'hooks' field"
    else
        fail "plugin.json missing 'hooks' field (required for hooks)"
    fi
else
    fail "plugin.json missing"
fi
echo ""

# Check hooks.json
echo "Checking hooks.json..."

if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
    pass "hooks/hooks.json exists"

    # Validate JSON
    if python3 -c "import json; json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))" 2>/dev/null; then
        pass "hooks.json is valid JSON"
    else
        fail "hooks.json is invalid JSON"
    fi
else
    fail "hooks/hooks.json missing"
fi
echo ""

# Check hook scripts
echo "Checking hook scripts..."

for script in "session-start.sh" "pre-delegate.sh" "post-delegate.sh" "session-end.sh"; do
    if [ -f "$PLUGIN_ROOT/plugin-scripts/$script" ]; then
        pass "$script exists"
        if [ -x "$PLUGIN_ROOT/plugin-scripts/$script" ]; then
            pass "$script is executable"
        else
            fail "$script is not executable"
        fi
    else
        warn "$script missing (optional but recommended)"
    fi
done
echo ""

# Every artifact the loops below actually visit is recorded here (repo-relative) so the
# reach assertion at the end can PROVE the walk did not under-reach. #337 fixed the
# reach; this makes a future regression impossible to land silently. See #336.
VISITED_LIST="$(mktemp -t mao-visited.XXXXXX)"
: > "$VISITED_LIST"

# `sort -z` is GNU/newer-BSD only and exists purely to stabilize output order — no
# check depends on it. Probe rather than assume: absent -> `cat`, so the NUL stream is
# passed through instead of lost.
if printf '' | sort -z >/dev/null 2>&1; then SORT_NUL="sort -z"; else SORT_NUL="cat"; fi

# ONE predicate for "is this a command/agent ENTRY, or a doc / sub-document that merely lives
# under those directories?" — consumed by the discovery loops AND by the reach assertion's
# expectation below. A second copy would drift, and two instruments disagreeing about the same
# set is precisely the defect class this file exists to catch (#327 / #336 / #338).
#
# Context: once the loops became recursive (#333/#337), they started reaching files that were
# never commands — the recursion is right, the CLASSIFICATION was wrong, and a validator that
# warns about non-defects trains people to ignore it (#339). Takes a REPO-RELATIVE path.
is_entry() {
    local path="$1"
    # `skills/<name>/SKILL.md` IS a skill's entry point — all-caps by design, allow before (a).
    case "$path" in
        skills/*/SKILL.md) return 0 ;;
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

# Check skills (subdirectory format)
echo "Checking skills (subdirectory format)..."

SKILL_COUNT=0
for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        if [ -f "${skill_dir}SKILL.md" ]; then
            pass "skills/$skill_name/SKILL.md exists"
            printf '%s\n' "skills/$skill_name/SKILL.md" >> "$VISITED_LIST"
            ((SKILL_COUNT++)) || true
        else
            fail "skills/$skill_name/ missing SKILL.md"
        fi
    fi
done

if [ $SKILL_COUNT -eq 0 ]; then
    warn "No skills found in subdirectory format"
else
    pass "$SKILL_COUNT skills found"
fi
echo ""

# Check commands
echo "Checking commands..."

COMMAND_COUNT=0
# find, not a glob: bash's `*` does NOT cross `/` (and globstar needs bash 4+,
# absent on macOS's stock 3.2) — the old loop silently never saw commands/*/*.md.
# Sibling of issue #327 / PR #333; measured hole: #336. `while read` (not a
# `for` over $(...)) so paths with spaces survive.
# Messages use the RELATIVE path (not basename): with recursion, homonymous files
# in different subdirs would print identically (Qodo #337). The dir-existence
# guard keeps a missing dir on the old code path's behavior (count=0 -> warn),
# without find's stderr noise — the earlier structure gate is the loud reporter.
if [ -d "$PLUGIN_ROOT/commands" ]; then
# `-print0` + `read -d ''` rather than line-based: a NEWLINE is a legal POSIX filename
# character, and a line-based read turns one such path into two bogus entries. Same
# residual `-z` closed on the Python side in #335. `head -n 1` is the POSIX spelling.
#
# Discovery runs in the PARENT (into a file) instead of `done < <(find ...)`: a process
# substitution runs the producer in a SEPARATE process, so a `find` that dies reaches the
# loop as plain end-of-input — indistinguishable from "the dir was empty". Neither `set -e`
# nor `pipefail` sees it, and the run reports GREEN having validated nothing (CodeRabbit
# #338, Major). As a parent statement, `pipefail` makes `$?` reflect ANY stage and
# `|| RC=$?` captures it without aborting; the loop then reads a plain file, so the
# process-substitution class is gone rather than patched.
CMD_LIST="$(mktemp -t mao-cmdlist.XXXXXX)"
CMD_DISCOVER_RC=0
find "$PLUGIN_ROOT/commands" -type f -name '*.md' -print0 | $SORT_NUL > "$CMD_LIST" || CMD_DISCOVER_RC=$?
if [ "$CMD_DISCOVER_RC" -ne 0 ]; then
    fail "command discovery FAILED (rc=$CMD_DISCOVER_RC) — coverage is UNVERIFIED, not clean"
fi
while IFS= read -r -d '' cmd; do
    if [ -f "$cmd" ]; then
        cmd_rel="${cmd#"$PLUGIN_ROOT"/}"
        if is_entry "$cmd_rel"; then
            printf '%s\n' "$cmd_rel" >> "$VISITED_LIST"
            # Check for frontmatter
            if head -n 1 "$cmd" | grep -q "^---"; then
                pass "$cmd_rel has frontmatter"
            else
                warn "$cmd_rel missing frontmatter"
            fi
            ((COMMAND_COUNT++)) || true
        fi
    fi
done < "$CMD_LIST"
rm -f "$CMD_LIST"
fi

if [ $COMMAND_COUNT -eq 0 ]; then
    warn "No commands found"
else
    pass "$COMMAND_COUNT commands found"
fi
echo ""

# Check agents
echo "Checking agents..."

AGENT_COUNT=0
# Same reach fix as the commands loop above (#336): `find` recurses where
# `agents/*.md` could not — 21 consultants were invisible to this presence check.
# Relative-path messages + dir guard, same rationale as the commands loop.
if [ -d "$PLUGIN_ROOT/agents" ]; then
# Same `-print0` / `head -n 1` rationale as the commands loop above, and the same
# parent-statement discovery so a failing `find` cannot masquerade as an empty dir.
AGENT_LIST="$(mktemp -t mao-agentlist.XXXXXX)"
AGENT_DISCOVER_RC=0
find "$PLUGIN_ROOT/agents" -type f -name '*.md' -print0 | $SORT_NUL > "$AGENT_LIST" || AGENT_DISCOVER_RC=$?
if [ "$AGENT_DISCOVER_RC" -ne 0 ]; then
    fail "agent discovery FAILED (rc=$AGENT_DISCOVER_RC) — coverage is UNVERIFIED, not clean"
fi
while IFS= read -r -d '' agent; do
    if [ -f "$agent" ]; then
        agent_rel="${agent#"$PLUGIN_ROOT"/}"
        if is_entry "$agent_rel"; then
            printf '%s\n' "$agent_rel" >> "$VISITED_LIST"
            # Check for frontmatter
            if head -n 1 "$agent" | grep -q "^---"; then
                pass "$agent_rel has frontmatter"
            else
                warn "$agent_rel missing frontmatter"
            fi
            ((AGENT_COUNT++)) || true
        fi
    fi
done < "$AGENT_LIST"
rm -f "$AGENT_LIST"
fi

if [ $AGENT_COUNT -eq 0 ]; then
    warn "No agents found"
else
    pass "$AGENT_COUNT agents found"
fi
echo ""

# ── Shell-loop reach assertion — sibling of the Python gate's (#327/#333) ─────
# #337 fixed the reach. This proves it STAYS fixed: the loops walk the FILESYSTEM on
# purpose (a new artifact not yet `git add`ed must still be validated), and git is used
# only as an INDEPENDENT source of truth to show the walk missed nothing. Without it a
# green run can state a coverage number smaller than reality, and nobody audits a ✓.
#
# `-e`, not `-d`: in a linked worktree `.git` is a FILE (`gitdir: …`), so a directory
# test is false there and this whole block would skip SILENTLY — that was the first
# draft's bug, caught only because the negative control printed nothing instead of
# firing. `-e` also separates "not a repo" (silent, legitimate) from "git broke"
# (reported below); gating on `git rev-parse` would collapse both into one non-zero
# exit and skip either way — error-as-absence.
#
# READMEs are excluded via git pathspec `:!*README.md`, NOT `grep -v`: under
# `set -euo pipefail` a grep that filters every line exits 1 and would abort the run.
#
# Limitation stated rather than papered over: this comparison is line-based, so a path
# containing a NEWLINE evades the ASSERTION (the loops themselves handle it via -print0).
echo "Checking shell-loop reach..."
if [ -e "$PLUGIN_ROOT/.git" ]; then
    REACH_RC=0
    TRACKED_LIST="$(mktemp -t mao-tracked.XXXXXX)"
    TRACKED_RAW="$(mktemp -t mao-trackedraw.XXXXXX)"
    git -C "$PLUGIN_ROOT" ls-files \
        'agents/*.md' 'commands/*.md' 'skills/*/SKILL.md' \
        > "$TRACKED_RAW" 2>/dev/null || REACH_RC=$?
    # Filter the EXPECTATION through the very same `is_entry` the loops used. Two separate
    # notions of "what counts" (a pathspec here, a literal there) is how the sets drift apart
    # and the assertion starts reporting phantom gaps — the #336 class, one level up.
    : > "$TRACKED_LIST"
    while IFS= read -r tracked_path; do
        is_entry "$tracked_path" && printf '%s\n' "$tracked_path" >> "$TRACKED_LIST"
    done < "$TRACKED_RAW"
    TRACKED_RAW_N=$(wc -l < "$TRACKED_RAW" | tr -d ' ')
    # TRACKED_RAW stays alive past the comparison: EXTRA must be able to ask "is this path
    # git-tracked at all?" to tell real drift from a not-yet-committed file (qodo #341).
    if [ "$REACH_RC" -ne 0 ]; then
        fail "reach assertion DID NOT RUN (git ls-files rc=$REACH_RC) — coverage is UNVERIFIED, not clean"
    else
        # BIDIRECTIONAL on purpose. Filtering both sides through the same `is_entry` kills
        # drift, but it also makes a one-directional check VACUOUS: a predicate that skips
        # everything shrinks BOTH sets to empty and they agree trivially — measured, the
        # assertion went green on a deliberately-broken predicate. So compare both ways:
        #   MISSED (tracked \ visited) -> the LOOPS under-reach   (the #336 defect)
        #   EXTRA  (visited \ tracked) -> the expectation shrank below what was visited
        #
        # HONEST BOUND, measured — do not read EXTRA as "over-skipping is now impossible":
        # `is_entry` filters BOTH sides, so a predicate that over-skips COMMANDS/AGENTS shrinks
        # both sets symmetrically and they still agree. EXTRA only fires where a loop records
        # into VISITED WITHOUT consulting the predicate — today just the skills loop. The
        # residual (a predicate that silently drops commands/agents) is covered by REPORTING
        # the skip count in the pass line, not by a gate: if it jumps from 10 to 170 a reader
        # sees it. A third-order guard-for-the-guard is where this stops being proportionate.
        MISSED=$(comm -23 <(sort "$TRACKED_LIST") <(sort "$VISITED_LIST"))
        EXTRA=$(comm -13 <(sort "$TRACKED_LIST") <(sort "$VISITED_LIST"))
        # EXTRA has TWO causes and only one is a defect (qodo #341, reproduced: an uncommitted
        # `commands/foo.md` failed the run with the wrong diagnosis). The loops walk the
        # FILESYSTEM — validating a file before `git add` is the normal dev loop, and is exactly
        # why the walk is not driven by git. Split by tracked-ness BEFORE the verdict chain:
        #   in TRACKED_RAW -> git knows it, yet the expectation dropped it => is_entry DRIFT (fail)
        #   not in git     -> simply not committed yet                     => report, never fail
        EXTRA_DRIFT=""
        EXTRA_NEW_N=0
        if [ -n "$EXTRA" ]; then
            while IFS= read -r extra_path; do
                [ -n "$extra_path" ] || continue
                if grep -qxF "$extra_path" "$TRACKED_RAW"; then
                    EXTRA_DRIFT="${EXTRA_DRIFT}${extra_path}
"
                else
                    EXTRA_NEW_N=$((EXTRA_NEW_N + 1))
                fi
            done <<EOF
$EXTRA
EOF
        fi
        if [ -n "$MISSED" ]; then
            MISSED_N=$(printf '%s\n' "$MISSED" | wc -l | tr -d ' ')
            fail "REACH GAP :: $MISSED_N tracked artifact(s) the shell loops never visited, e.g. $(printf '%s\n' "$MISSED" | head -n 1) — the loops under-reach (see #336)"
        elif [ -n "$EXTRA_DRIFT" ]; then
            EXTRA_N=$(printf '%s' "$EXTRA_DRIFT" | grep -c .)
            fail "EXPECTATION GAP :: $EXTRA_N git-tracked artifact(s) were visited but dropped from the expectation, e.g. $(printf '%s' "$EXTRA_DRIFT" | head -n 1) — is_entry over-skips (see #339)"
        else
            SKIPPED_N=$(( TRACKED_RAW_N - $(wc -l < "$TRACKED_LIST") ))
            UNTRACKED_NOTE=""
            [ "$EXTRA_NEW_N" -gt 0 ] && UNTRACKED_NOTE="; $EXTRA_NEW_N not yet committed"
            pass "shell loops reached every tracked artifact ($(wc -l < "$TRACKED_LIST" | tr -d ' ') entries; $SKIPPED_N classified as docs/sub-documents$UNTRACKED_NOTE)"
        fi
    fi
    rm -f "$TRACKED_LIST" "$TRACKED_RAW"
fi
rm -f "$VISITED_LIST"
echo ""


# Delegation Framework (GaaS/GaaC) — protocols + skill + CLI
echo "Validating delegation framework..."

DELEGATION_DIR="$PLUGIN_ROOT/protocols/delegation"
for f in provider-matrix.md delegation-init-prompt.md delegation-dna-prompt.md delegation-finalize-prompt.md; do
    if [ -f "$DELEGATION_DIR/$f" ]; then
        pass "protocols/delegation/$f exists"
    else
        fail "protocols/delegation/$f missing"
    fi
done

# Token budget check: word-count × 1.3 ≤ 1500 per prompt
for f in delegation-init-prompt.md delegation-dna-prompt.md delegation-finalize-prompt.md; do
    if [ -f "$DELEGATION_DIR/$f" ]; then
        WC=$(wc -w < "$DELEGATION_DIR/$f" | tr -d ' ')
        EST=$(( WC * 13 / 10 ))
        if [ "$EST" -le 1500 ]; then
            pass "$f token budget OK (${WC}w ~${EST}tok ≤ 1500)"
        else
            fail "$f exceeds token budget (${WC}w ~${EST}tok > 1500)"
        fi
    fi
done

# CLI exists + executable + correct exit codes
DELEGATE_CLI="$PLUGIN_ROOT/plugin-scripts/gaac/delegate.sh"
if [ -x "$DELEGATE_CLI" ]; then
    pass "plugin-scripts/gaac/delegate.sh exists and is executable"

    for phase in init dna finalize; do
        if OUT=$(bash "$DELEGATE_CLI" "$phase" 2>/dev/null) && [ -n "$OUT" ]; then
            pass "delegate.sh $phase exits 0 with non-empty stdout"
        else
            fail "delegate.sh $phase failed or empty"
        fi
    done

    # Unknown phase must exit != 0
    if bash "$DELEGATE_CLI" bogus >/dev/null 2>&1; then
        fail "delegate.sh bogus should exit non-zero"
    else
        pass "delegate.sh unknown phase exits non-zero"
    fi

    # Simulated cross-provider contexts (env-isolated so ambient $TICKET can't skew)
    H1=$(env -u TICKET bash "$DELEGATE_CLI" init --ticket=VKS-1706 --provider=bitbucket 2>/dev/null)
    if echo "$H1" | grep -q "^TICKET_PROVIDER=jira$" && echo "$H1" | grep -q "^VCS_PROVIDER=bitbucket$"; then
        pass "delegate.sh detects jira+bitbucket context"
    else
        fail "delegate.sh should detect jira+bitbucket"
    fi

    H2=$(env -u TICKET bash "$DELEGATE_CLI" init --ticket=VKO-88 --provider=github 2>/dev/null)
    if echo "$H2" | grep -q "^TICKET_PROVIDER=linear$" && echo "$H2" | grep -q "^VCS_PROVIDER=github$"; then
        pass "delegate.sh detects linear+github context"
    else
        fail "delegate.sh should detect linear+github"
    fi

    H3=$(env -u TICKET bash "$DELEGATE_CLI" init --provider=none 2>/dev/null)
    if echo "$H3" | grep -q "^TICKET_PROVIDER=none$" && echo "$H3" | grep -q "^VCS_PROVIDER=none$"; then
        pass "delegate.sh handles no-ticket/no-remote fallback"
    else
        fail "delegate.sh should handle no-ticket fallback"
    fi

    # Invalid --provider must be rejected (exit 2)
    if env -u TICKET bash "$DELEGATE_CLI" init --provider=invalidprov >/dev/null 2>&1; then
        fail "delegate.sh should reject unknown --provider value"
    else
        pass "delegate.sh rejects unknown --provider value"
    fi
else
    fail "plugin-scripts/gaac/delegate.sh missing or not executable"
fi

# ─── Frontmatter must actually PARSE as YAML ─────────────────────────────────
# Root-cause fix (2026-08-14): every frontmatter check above greps for a LINE
# (`^name: x$`) and therefore reports PASS on a file whose YAML the loader
# rejects. A skill shipped with an unquoted plain scalar containing ': ' —
# structurally unloadable — while this script printed "✓ PASSED". A grep answers
# "does the text contain?", never "does the parser accept?"; the second question
# is the one that decides whether the artifact loads at all.
# Capability-detected: PyYAML absent → WARN, never a red build for a missing dep.
echo "Validating frontmatter parses as YAML..."
if python3 -c "import yaml" 2>/dev/null; then
    # Initialize IN THIS SCOPE before the capture below. `YAML_RC` is a generic-enough
    # name that an outer wrapper may already export it; without this reset a SUCCESSFUL
    # python run never executes `|| YAML_RC=$?`, so the inherited value survives and the
    # gate reports a crash that never happened. `${VAR:-0}` does NOT cover this: it
    # substitutes only when unset/null, not when set to garbage. Never read a variable
    # you did not initialize in your own scope.
    YAML_RC=0
    YAML_BAD=$(python3 - "$PLUGIN_ROOT" <<'PYEOF'
import glob, io, os, sys, yaml
root = sys.argv[1]
bad = []
seen = set()
# `**` + recursive=True: Python's `*` does NOT cross `/`, unlike git's pathspec of the
# same shape. With the non-recursive patterns this gate never saw agents/consultants/*.md
# nor commands/*/*.md — 30 artifacts that were reported as covered. See issue #327.
# NOTE both halves are load-bearing: `**` without recursive=True behaves as plain `*`.
for pat in ("skills/**/SKILL.md", "agents/**/*.md", "commands/**/*.md"):
    for p in sorted(glob.glob(os.path.join(root, pat), recursive=True)):
        # REACHED — must precede every `continue` below (see note under the except).
        # `.replace(os.sep, "/")`: on Windows os.path.relpath returns `agents\foo.md`
        # while `git ls-files` ALWAYS emits `/`, so without this every artifact lands in
        # `tracked - seen` and the assertion reports a false total reach gap on every run.
        # os.sep (not a literal "\\"): on POSIX os.sep == "/" so this is a no-op, which
        # matters because `\` is a legal filename character there and a literal replace
        # would corrupt it.
        seen.add(os.path.relpath(p, root).replace(os.sep, "/"))
                                             # below, or `seen` records "parsed" while the
                                             # assertion claims "reached" (they differ for
                                             # files with no frontmatter, which are skipped
                                             # on purpose and are NOT a reach gap).
        if os.path.basename(p) == "README.md":
            continue                      # docs, not artifacts (same rule as above)
        try:
            t = io.open(p, encoding="utf-8").read()
            if not t.startswith("---\n"):
                continue                  # 'missing frontmatter' is already warned above
            yaml.safe_load(t.split("---\n", 2)[1])
        except yaml.YAMLError as e:
            bad.append(f"{os.path.relpath(p, root)} :: {str(e).splitlines()[0]}")
        except Exception as e:
            bad.append(f"{os.path.relpath(p, root)} :: {type(e).__name__}: {e}")

# REACH ASSERTION — the gate must not silently under-reach again (issue #327).
# git's pathspec `*` crosses `/`, so these patterns are the ground truth for what
# SHOULD have been parsed. Degrade-safe: no git / not a repo -> skip, never fail,
# because this validator also runs from an installed plugin dir with no .git.
# `.git` absent is the ONE legitimate skip (installed plugin dir) — silent by design.
# Anything else is reported: a control that disables itself on any error is not a control,
# it is an invisible bypass. Narrow excepts only, so a real bug in this block propagates
# and is caught by the rc check in the shell above rather than swallowed here.
if os.path.exists(os.path.join(root, ".git")):
    import subprocess
    try:
        tracked = set()
        for pat in ("skills/*/SKILL.md", "agents/*.md", "commands/*.md"):
            out = subprocess.run(["git", "-C", root, "ls-files", "-z", pat],
                                 capture_output=True, timeout=10)
            if out.returncode != 0:
                raise OSError(f"git ls-files rc={out.returncode}")
            # `-z` + byte-split on NUL + os.fsdecode: paths are preserved EXACTLY
            # (spaces, backslashes, non-UTF-8 bytes — and newlines, which are legal in
            # POSIX filenames and would break any line-based split). No separator munging:
            # git always emits `/`, and `\` is a legal POSIX filename character — replacing
            # it would corrupt such a path. (CodeRabbit round 6. Note: the intermediate
            # splitlines() step DID handle spaces correctly; what it could not survive is a
            # newline-in-path — that residual is what `-z` closes.)
            tracked.update(f for f in (os.fsdecode(b) for b in out.stdout.split(b"\0") if b)
                           if os.path.basename(f) != "README.md")
        missed = sorted(tracked - seen)
        if missed:
            bad.append(f"REACH GAP :: {len(missed)} tracked artifact(s) the glob never parsed, "
                       f"e.g. {missed[0]} — the gate under-reaches (see #327)")
    except (OSError, subprocess.SubprocessError) as e:
        # .git IS here, so git failing is an anomaly, not the expected no-repo case.
        bad.append(f"REACH ASSERTION DID NOT RUN :: {type(e).__name__}: {e} — "
                   f"the under-reach guard was skipped; treat coverage as UNVERIFIED")

print("\n".join(bad))
PYEOF
) || YAML_RC=$?
    # `|| YAML_RC=$?` on the assignment above is load-bearing: this script runs under
    # `set -euo pipefail` (line 9), so a bare `X=$(python3 ...)` that exits non-zero
    # ABORTS the whole script right there — the run does fail (safe), but with no
    # message saying why, and any check written after it is unreachable. The `||`
    # keeps the failure local so it can be reported instead of just ending the script.
    # Emptiness alone is NOT the test: a python crash exits non-zero with EMPTY stdout,
    # which reads as "nothing bad found". Per script-safety §6 the authority is the
    # captured exit code.
    if [ "$YAML_RC" -ne 0 ]; then
        fail "frontmatter YAML check crashed (python rc=$YAML_RC) — result is UNKNOWN, not clean"
    elif [ -z "$YAML_BAD" ]; then
        pass "all artifact frontmatter parses as YAML"
    else
        while IFS= read -r line; do [ -n "$line" ] && fail "unparseable frontmatter: $line"; done <<< "$YAML_BAD"
    fi
else
    warn "PyYAML absent — frontmatter parse check SKIPPED (grep-only checks cannot catch a broken loader)"
fi
echo ""

# Skill frontmatter
SKILL_FILE="$PLUGIN_ROOT/skills/delegate-governance/SKILL.md"
if [ -f "$SKILL_FILE" ] && grep -q "^name: delegate-governance$" "$SKILL_FILE"; then
    pass "skills/delegate-governance/SKILL.md has correct frontmatter"
else
    fail "skills/delegate-governance/SKILL.md missing or frontmatter wrong"
fi
echo ""

# auto-pilot skill + command (v0.1.0)
echo "Validating auto-pilot..."

AP_SKILL="$PLUGIN_ROOT/skills/auto-pilot/SKILL.md"
if [ -f "$AP_SKILL" ]; then
    pass "skills/auto-pilot/SKILL.md exists"
    if grep -q "^name: auto-pilot$" "$AP_SKILL"; then
        pass "skills/auto-pilot/SKILL.md has correct frontmatter"
    else
        fail "skills/auto-pilot/SKILL.md missing 'name: auto-pilot' frontmatter"
    fi
    AP_SIZE=$(wc -c <"$AP_SKILL" | tr -d ' ')
    if [ "$AP_SIZE" -lt 12288 ]; then
        pass "skills/auto-pilot/SKILL.md size OK (${AP_SIZE}B < 12288B)"
    else
        fail "skills/auto-pilot/SKILL.md exceeds 12288B ceiling (${AP_SIZE}B)"
    fi
else
    fail "skills/auto-pilot/SKILL.md missing"
fi

AP_CMD="$PLUGIN_ROOT/commands/auto-pilot.md"
if [ -f "$AP_CMD" ]; then
    pass "commands/auto-pilot.md exists"
    if grep -q "^name: auto-pilot$" "$AP_CMD"; then
        pass "commands/auto-pilot.md has correct frontmatter"
    else
        fail "commands/auto-pilot.md missing 'name: auto-pilot' frontmatter"
    fi
else
    fail "commands/auto-pilot.md missing"
fi

# Reciprocity link from delegate-governance back to auto-pilot
if [ -f "$SKILL_FILE" ] && grep -q "skills/auto-pilot/SKILL.md" "$SKILL_FILE"; then
    pass "delegate-governance Related section links auto-pilot"
else
    fail "delegate-governance missing reciprocal link"
fi
echo ""

# signoff + continuation-broadcast (postflight P3.6 — ADR-010)
echo "Validating signoff + continuation-broadcast..."

BC_SCRIPT="$PLUGIN_ROOT/bin/continuation-broadcast.sh"
if [ -x "$BC_SCRIPT" ]; then
    pass "bin/continuation-broadcast.sh exists and is executable"
    if bash "$BC_SCRIPT" --help >/dev/null 2>&1; then
        pass "continuation-broadcast.sh --help exits 0"
    else
        fail "continuation-broadcast.sh --help should exit 0"
    fi
    # dry-run is the DEFAULT: a --scope all --file target is NOT mutated without --apply
    BC_TMP="$(mktemp)"; BC_JOBS="$(mktemp -d)"; printf 'x\n' > "$BC_TMP"
    CLAUDE_JOBS_DIR="$BC_JOBS" bash "$BC_SCRIPT" --ticket VKS-1 --seed s.json --scope all --file "$BC_TMP" >/dev/null 2>&1
    if [ "$(cat "$BC_TMP")" = "x" ]; then
        pass "continuation-broadcast dry-run default (no --apply ⇒ no mutation)"
    else
        fail "continuation-broadcast dry-run mutated a file without --apply"
    fi
    rm -f "$BC_TMP"; rm -rf "$BC_JOBS"
    # kill-switch ⇒ noop
    if MAOS_BROADCAST=0 bash "$BC_SCRIPT" --ticket VKS-1 2>/dev/null | grep -q '"status":"noop"'; then
        pass "continuation-broadcast MAOS_BROADCAST=0 kill-switch ⇒ noop"
    else
        fail "continuation-broadcast kill-switch should noop"
    fi
else
    fail "bin/continuation-broadcast.sh missing or not executable"
fi

BC_TESTS="$PLUGIN_ROOT/bin/tests/continuation-broadcast.test.sh"
if [ -f "$BC_TESTS" ]; then
    if bash "$BC_TESTS" >/dev/null 2>&1; then
        pass "bin/tests/continuation-broadcast.test.sh passes"
    else
        fail "bin/tests/continuation-broadcast.test.sh FAILED (run 'bash bin/tests/continuation-broadcast.test.sh')"
    fi
else
    fail "bin/tests/continuation-broadcast.test.sh missing"
fi

# research-dossier: the two f=0 gates, proven in BOTH directions (valid passes,
# each negative fixture fails for its OWN reason). Skips cleanly without node.
RD_TESTS="$PLUGIN_ROOT/bin/tests/research-dossier.test.sh"
if [ -f "$RD_TESTS" ]; then
    if bash "$RD_TESTS" >/dev/null 2>&1; then
        pass "bin/tests/research-dossier.test.sh passes"
    else
        fail "bin/tests/research-dossier.test.sh FAILED (run 'bash bin/tests/research-dossier.test.sh')"
    fi
else
    fail "bin/tests/research-dossier.test.sh missing"
fi

# signoff skill + command frontmatter
if [ -f "$PLUGIN_ROOT/skills/signoff/SKILL.md" ] && grep -q "^name: signoff$" "$PLUGIN_ROOT/skills/signoff/SKILL.md"; then
    pass "skills/signoff/SKILL.md has correct frontmatter"
else
    fail "skills/signoff/SKILL.md missing or frontmatter wrong"
fi
if [ -f "$PLUGIN_ROOT/commands/signoff.md" ] && grep -q "^name: signoff$" "$PLUGIN_ROOT/commands/signoff.md"; then
    pass "commands/signoff.md has correct frontmatter"
else
    fail "commands/signoff.md missing or frontmatter wrong"
fi

# supporting SSOT docs
for d in skills/postflight/references/continuation-broadcast-protocol.md \
         skills/postflight/references/close-out-hunt-checklist.md \
         docs/adrs/ADR-010-continuation-broadcast.md; do
    if [ -f "$PLUGIN_ROOT/$d" ]; then pass "$d exists"; else fail "$d missing"; fi
done
echo ""

# MAOS-Tips corpus (ADR-008) — integrity + anti-orphan gate
echo "Validating MAOS-Tips..."

TIPS_VALIDATOR="$PLUGIN_ROOT/tips/validate-tips.sh"
TIPS_HOOK="$PLUGIN_ROOT/plugin-scripts/session-tip.sh"
if [ -f "$TIPS_VALIDATOR" ]; then
    if [ -x "$TIPS_HOOK" ]; then
        pass "plugin-scripts/session-tip.sh is executable"
    else
        fail "plugin-scripts/session-tip.sh is not executable"
    fi
    if bash "$TIPS_VALIDATOR" "$PLUGIN_ROOT" >/dev/null 2>&1; then
        pass "tips/validate-tips.sh passes (zero orphan tips)"
    else
        fail "tips/validate-tips.sh FAILED (run 'bash tips/validate-tips.sh' for details)"
    fi
else
    warn "tips/validate-tips.sh missing (MAOS-Tips not installed)"
fi
echo ""

# OODA operator-profile: portable context must not become an authority bypass.
OODA_PROFILE_TESTS="$PLUGIN_ROOT/skills/ooda-loop/tests/operator-profile-contract.test.mjs"
if [ -f "$OODA_PROFILE_TESTS" ]; then
    if node --test "$OODA_PROFILE_TESTS" >/dev/null 2>&1; then
        pass "skills/ooda-loop/tests/operator-profile-contract.test.mjs passes"
    else
        fail "skills/ooda-loop/tests/operator-profile-contract.test.mjs FAILED (run 'node --test skills/ooda-loop/tests/operator-profile-contract.test.mjs')"
    fi
else
    fail "skills/ooda-loop/tests/operator-profile-contract.test.mjs missing"
fi
echo ""

# Agent Skills frontmatter (skills.sh / multi-harness portable path)
echo "Checking Agent Skills frontmatter..."
if [ -x "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh" ] || [ -f "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh" ]; then
    if bash "$PLUGIN_ROOT/scripts/validate-skill-frontmatter.sh"; then
        pass "scripts/validate-skill-frontmatter.sh passes"
    else
        fail "scripts/validate-skill-frontmatter.sh FAILED (SKILL.md needs name+description YAML frontmatter)"
    fi
else
    fail "scripts/validate-skill-frontmatter.sh missing"
fi
echo ""

# Summary
echo "========================================"
echo "  Validation Summary"
echo "========================================"
echo ""
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "  Status: ✓ PASSED"
    echo ""
    echo "  Plugin is ready for use!"
    exit 0
else
    echo "  Status: ✗ FAILED"
    echo ""
    echo "  Please fix the errors above before using the plugin."
    exit 1
fi
