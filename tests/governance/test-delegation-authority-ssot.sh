#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# test-delegation-authority-ssot.sh — governance consistency for agent delegation
#
# /** The delegation rules live in ONE place: skills/agentic-delegation/SKILL.md.
#  *  This test keeps the rest of the repo from drifting away from it:
#  *    1. the SSOT §4.1 states the authority-inheritance rule, the closed root
#  *       exception list, fail-closed handling and the never-delegable list;
#  *    2. the SSOT body has no back-reference to a host/personal layer;
#  *    3. no file states a delegation depth cap other than the SSOT's §8 value,
#  *       including Sentinel's config and docs;
#  *    4. the files that used to restate the rules now link the SSOT;
#  *    5. mutation fixtures: each known contradiction, injected into a copy,
#  *       must make checks 1-3 fail (proves the checks can see what they guard).
#  *  Limits: checks 3-4 are a phrase lint over Markdown, not a proof. They catch
#  *  the phrasings listed here; a contradiction worded another way can pass.
#  *  @usage  bash tests/governance/test-delegation-authority-ssot.sh [repo-root]
#  *  @exit   0 pass · 1 one or more checks failed
#  */
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
QUIET="${DAS_QUIET:-0}"           # 1 = fixture run: no per-check output
FAILS=0
ok()  { [ "$QUIET" = 1 ] || printf '  ✓ %s\n' "$1"; }
bad() { [ "$QUIET" = 1 ] || printf '  ✗ %s\n' "$1"; FAILS=$((FAILS + 1)); }

SSOT="$ROOT/skills/agentic-delegation/SKILL.md"
[ "$QUIET" = 1 ] || echo "delegation-authority SSOT consistency"
if [ ! -f "$SSOT" ]; then
    bad "SSOT missing: skills/agentic-delegation/SKILL.md"
    exit 1
fi

# ── 1. §4.1 normative content (checked inside §4.1 only) ─────────────────────
S41="$(sed -n '/^## 4\.1 /,/^## 5\./p' "$SSOT")"
if [ -z "$S41" ]; then
    bad "SSOT lacks a '## 4.1' section (authority inheritance)"
fi
for needle in 'depth_remaining' 'subset' 'never widens' 'fail-closed' \
              'no authorization grant' 'The list is closed' \
              '| E1 |' '| E2 |' '| E3 |' '| E4 |' \
              'HUMAN_DOMAIN' 'absolute guardrail' 'independent red-team' \
              'Final accountability' 'Audit judgment' 'Escalation choice' \
              'Memory judgment' 'World boundary' 'Enforcement today'; do
    printf '%s\n' "$S41" | grep -qiF -- "$needle" && ok "§4.1 states: $needle" || bad "§4.1 does not state: $needle"
done

# ── 2. layer purity (body only; Changelog history rows are left as written) ──
BODY="$(sed '/^## [0-9]*\.* *Changelog/,$d' "$SSOT")"
PURITY="host-local|auto-self-harness|~/\\.claude|operator-host|operator's own|when present at the host"
if printf '%s\n' "$BODY" | grep -nEi "$PURITY" >/dev/null; then
    bad "SSOT body references a host/personal layer:"
    [ "$QUIET" = 1 ] || printf '%s\n' "$BODY" | grep -nEi "$PURITY" | sed 's/^/      /'
else
    ok "SSOT has no back-reference to a personal layer"
fi

# ── 3. one depth cap ─────────────────────────────────────────────────────────
CAP="$(sed -nE 's/^- Max recursion depth: \*\*([0-9]+)\*\*.*/\1/p' "$SSOT" | head -1)"
if [ -z "$CAP" ]; then
    bad "SSOT §8 has no 'Max recursion depth: **N**' line"
else
    ok "SSOT depth cap = $CAP"
    # Agent delegation/recursion depth statements, several phrasings. Navigation
    # depth (--depth / --max-depth of a file or graph walk) is out of scope.
    RE='(delegation|recursion) depth[^0-9]{0,25}(≤|<=|>|hard-?cap(ped)?( at)?)[[:space:]]*[0-9]+'
    RE="$RE|max(imum)? (recursion |delegation )?depth[^0-9a-z]{0,6}[0-9]+"
    RE="$RE|depth[^.|]{0,40}allows[[:space:]]*(≤|<=)[[:space:]]*[0-9]+"
    RE="$RE|depth[^\`]{0,15}hard-?cap(ped)?( at)?[[:space:]]*[0-9]+"
    RE="$RE|(^|[^-a-z_])depth[[:space:]]*(≤|<=)[[:space:]]*[0-9]+"
    RE="$RE|depth[^.]{0,30}(must not|may not|cannot|should not|never) exceed[[:space:]]*[0-9]+"
    RE="$RE|depth (of )?(up to|at most)[[:space:]]*[0-9]+"
    # Normative surfaces: tool dirs, rules/, agent-loaded instruction dirs and
    # the root guidance files.
    # CHANGELOG.md and docs/ are history/research, not rules.
    SCAN=()
    for d in agents skills commands protocols sentinel statusmap rules .claude .agents .codex; do
        [ -d "$ROOT/$d" ] && SCAN+=("$ROOT/$d")
    done
    for f in AGENTS.md CLAUDE.md CONTRIBUTING.md GEMINI.md README.md SECURITY.md \
             .github/copilot-instructions.md .github/instructions; do
        [ -e "$ROOT/$f" ] && SCAN+=("$ROOT/$f")
    done
    hits="$(grep -rnoiE "$RE" "${SCAN[@]}" --include='*.md' --include='*.toml' 2>/dev/null || true)"
    drift=0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        n="$(printf '%s' "$line" | grep -oE '[0-9]+$')"
        if [ "$n" != "$CAP" ]; then
            bad "depth cap $n ≠ SSOT $CAP: ${line#"$ROOT"/}"
            drift=1
        fi
    done <<EOF
$hits
EOF
    [ "$drift" -eq 0 ] && ok "no Markdown file states a delegation depth cap other than $CAP"

    # rendered values (config tables, "current/max" status displays): value
    # check only — examples need not link the SSOT, but must show the cap.
    REND='max_delegation_depth[^0-9a-z]{0,8}[0-9]+|depth( reached)?[^0-9a-z]{0,16}[0-9]+ ?/ ?[0-9]+'
    REND="$REND|[0-9]+ ?/ ?[0-9]+ depth|depth[^.|]{0,30}within limit[[:space:]]*[0-9]+"
    # "N/M depth" ends in "depth": normalize each hit to its max value first
    rend_bad="$(grep -rnoiE "$REND" "${SCAN[@]}" --include='*.md' --include='*.toml' 2>/dev/null \
        | sed -E 's#([0-9]+) ?/ ?([0-9]+) depth$#\1/\2#' | grep -vE "[^0-9]$CAP\$" || true)"
    if [ -n "$rend_bad" ]; then
        bad "a rendered depth value shows a max other than $CAP:"
        [ "$QUIET" = 1 ] || printf '%s\n' "$rend_bad" | sed "s|$ROOT/|      |"
    else
        ok "rendered depth values (tables, current/max) show max $CAP"
    fi

    SCFG="$ROOT/sentinel/config.json"
    if [ -f "$SCFG" ]; then
        sval="$(sed -nE 's/.*"max_delegation_depth":[[:space:]]*([0-9]+).*/\1/p' "$SCFG" | head -1)"
        [ "$sval" = "$CAP" ] && ok "sentinel/config.json max_delegation_depth = $CAP" \
            || bad "sentinel/config.json max_delegation_depth = ${sval:-?} ≠ SSOT $CAP"
        # the allowed range must be present and must not reach above the SSOT:
        # integer bounds with 1 <= min <= max <= CAP; missing or unparsable fails.
        rcheck="$(python3 - "$SCFG" "$CAP" <<'PYEOF' 2>&1
import json, sys
cap = int(sys.argv[2])
def find(o):
    if isinstance(o, dict):
        if "max_delegation_depth" in o:
            return o
        for v in o.values():
            r = find(v)
            if r is not None:
                return r
    return None
try:
    blk = find(json.load(open(sys.argv[1])))
    val = blk["max_delegation_depth"]
    if type(val) is not int or val != cap:
        print("max_delegation_depth=%r is not the integer %d" % (val, cap)); sys.exit()
    vr = blk["valid_range"]
    lo, hi = vr["min"], vr["max"]
    ok = all(type(x) is int for x in (lo, hi)) and 1 <= lo <= hi <= cap
    print("ok" if ok else "bad range min=%r max=%r" % (lo, hi))
except Exception as e:
    print("unreadable: %s" % type(e).__name__)
PYEOF
)"
        if [ "$rcheck" = "ok" ]; then
            ok "sentinel/config.json cap is the integer $CAP and valid_range within 1..$CAP"
        else
            bad "sentinel/config.json valid_range: $rcheck (need 1 <= min <= max <= $CAP)"
        fi
    else
        bad "sentinel/config.json missing (the depth cap must be machine-readable)"
    fi
    sch_bad="$(grep -rnoE '"max_allowed"[[:space:]]*:[[:space:]]*[0-9.eE+-]+' "$ROOT/sentinel/schema" 2>/dev/null \
        | grep -vE ":[[:space:]]*$CAP\$" || true)"
    [ -z "$sch_bad" ] && ok "sentinel/schema examples show max_allowed $CAP" \
        || bad "sentinel/schema example differs from cap $CAP: $sch_bad"
    for f in sentinel/detection_rules.md sentinel/README.md \
             statusmap/templates/DELEGATION_PRE.md statusmap/templates/statusmap_templates.md; do
        [ -f "$ROOT/$f" ] || continue
        other="$(grep -noE '(max_depth=|max_delegation_depth`?:? *\|? *|delegation_depth > |default: )[0-9]+|usually [0-9]+' "$ROOT/$f" | grep -vE "[^0-9]$CAP\$" || true)"
        if [ -n "$other" ]; then
            bad "$f states a depth value other than $CAP: $(printf '%s' "$other" | tr '\n' ' ')"
        else
            ok "$f agrees with depth cap $CAP"
        fi
    done
fi

# ── 4. former restaters now link the SSOT ────────────────────────────────────
for f in agents/orchestrator.md commands/delegate.md protocols/agent-delegation.md \
         agents/COWORK-AUTONOMY-POLICY.md skills/delegate-governance/SKILL.md \
         skills/auto-pilot/SKILL.md commands/auto-pilot.md skills/quiesce/SKILL.md \
         skills/council-gate/SKILL.md agents/persona-pipeline.md \
         agents/perspective-trio.md agents/cascade-resolver.md agents/README.md; do
    if [ ! -f "$ROOT/$f" ]; then
        bad "expected file missing: $f"
    elif grep -q 'agentic-delegation' "$ROOT/$f"; then
        ok "$f links agentic-delegation"
    else
        bad "$f does not link skills/agentic-delegation"
    fi
done
# inverted: any file that states a depth cap must point at the SSOT
if [ -n "${CAP:-}" ]; then
    unlinked=""
    for f in $(printf '%s\n' "$hits" | cut -d: -f1 | sort -u); do
        [ "$f" = "$SSOT" ] && continue
        grep -q 'agentic-delegation' "$f" || unlinked="$unlinked ${f#"$ROOT"/}"
    done
    [ -z "$unlinked" ] && ok "every file stating a depth cap links the SSOT" \
        || bad "states a depth cap without linking skills/agentic-delegation:$unlinked"
fi

# ── 4b. exact normative clauses (SSOT) and forbidden widening phrases (all) ──
for clause in 'means \*\*no authorization grant\*\*' \
              'A scope counts only if the parent issued it' \
              'An invalid value [^.]*makes the child a leaf' \
              'A criterion-5 FAIL \(HUMAN_DOMAIN\) always escalates' \
              'out-of-scope results are advice only' \
              'A child that receives none is a leaf' \
              'cannot confirm its grant is a subset' \
              'does not take that action and returns it to its parent' \
              'comes from the immediate parent' \
              'when the child cannot confirm that, the task is returned to the parent' \
              'The child treats any value it cannot confirm as invalid' \
              'The escape clause never relaxes §4.1' \
              'covers only \*\*reversible\*\* actions the parent could itself execute' \
              'records where the grant came from' \
              'the lower one applies'; do
    printf '%s\n' "$BODY" | tr '\n' ' ' | grep -qE -- "$clause" && ok "SSOT clause: $clause" \
        || bad "SSOT lost clause: $clause"
done
CG="$ROOT/skills/council-gate/SKILL.md"
for clause in 'that task itself is shown to be within its parent.s authority' \
              'operator.s grant stands in for the parent.s authority' \
              'HITL_OUT_OF_SCOPE'; do
    tr '\n' ' ' < "$CG" 2>/dev/null | grep -qE -- "$clause" && ok "council-gate clause: $clause" \
        || bad "council-gate lost clause: $clause"
done
WIDEN="(do not (read|parse)|ignores?) the block[^.]{0,40}(exactly as|as before|as in v1)|(adopt|take|accept|assume)s? any (authority|scope)|any (authority|scope) (requested|asked|claimed)|inherits? (the |its )?parent'?s? (full|whole|entire) (scope|authority)|may widen (the |its )?(scope|authority)|authority (can|may) (grow|expand|widen)"
# whitespace-normalized per file, so a phrase broken across lines still matches
widen_hits="$(WIDEN="$WIDEN" python3 - "${SCAN[@]:-$ROOT/skills}" <<'PYEOF'
import os, re, sys
rx = re.compile(os.environ["WIDEN"], re.I)
files = []
for a in sys.argv[1:]:
    if os.path.isdir(a):
        for d, _, fs in os.walk(a):
            files += [os.path.join(d, f) for f in fs if f.endswith((".md", ".toml"))]
    elif a.endswith((".md", ".toml")):
        files.append(a)
for f in sorted(files):
    try:
        t = re.sub(r"\s+", " ", open(f, encoding="utf-8", errors="replace").read())
    except OSError:
        continue
    m = rx.search(t)
    if m:
        print("%s: %s" % (f, m.group(0)))
PYEOF
)"
if [ -n "$widen_hits" ]; then
    bad "a file allows authority to widen:"
    [ "$QUIET" = 1 ] || printf '%s\n' "$widen_hits" | sed "s|$ROOT/|      |"
else
    ok "no file lets delegated authority widen"
fi

# ── 5. mutation fixtures (only on the real tree, never recursively) ──────────
if [ "$QUIET" != 1 ]; then
    FIX="$(mktemp -d)"
    COPY=""
    for p in agents skills commands protocols sentinel statusmap rules .claude .agents .codex \
             AGENTS.md CLAUDE.md CONTRIBUTING.md GEMINI.md README.md SECURITY.md \
             .github/copilot-instructions.md .github/instructions; do
        [ -e "$ROOT/$p" ] && COPY="$COPY $p"
    done
    trap 'rm -rf "$FIX"' EXIT
    # Fixtures run in parallel (bounded), each in its own copy; results are
    # collected in declaration order afterwards.
    NFIX=0
    MAXJ="${DAS_JOBS:-8}"
    mutate() {  # mutate <label> <file> <sed-expression|append:TEXT|delete>
        NFIX=$((NFIX + 1))
        local n="$NFIX" label="$1" rel="$2" expr="$3"
        while [ "$(jobs -rp | wc -l)" -ge "$MAXJ" ]; do sleep 0.2; done
        (
            t="$FIX/t$n"; mkdir -p "$t"
            (cd "$ROOT" && tar -cf - $COPY) | tar -xf - -C "$t"
            case "$expr" in
                append:*) printf '\n%s\n' "${expr#append:}" >> "$t/$rel" ;;
                delete) rm -f "$t/$rel" ;;
                *) sed -i.bak "$expr" "$t/$rel" && rm -f "$t/$rel.bak" ;;
            esac
            if DAS_QUIET=1 bash "$SELF" "$t" >/dev/null 2>&1; then r=pass; else r=fail; fi
            printf '%s\t%s\n' "$r" "$label" > "$FIX/r$n"
            rm -rf "$t"
        ) &
    }
    # control: an unmodified copy must pass, else the fixtures prove nothing
    rm -rf "$FIX/c"; mkdir -p "$FIX/c"
    (cd "$ROOT" && tar -cf - $COPY) | tar -xf - -C "$FIX/c"
    if DAS_QUIET=1 bash "$SELF" "$FIX/c" >/dev/null 2>&1; then
        ok "fixture control: unmodified copy passes"
    else
        bad "fixture control failed: an unmodified copy does not pass"
    fi
    mutate "depth > 3 in orchestrator"       agents/orchestrator.md 'append:- Delegation depth > 3? → STOP'
    mutate "'max depth 3' in a diagram"      agents/README.md 'append:└── Sub-Sub-Agent (max depth 3)'
    mutate "'manual mode allows ≤ 3'"        skills/auto-pilot/SKILL.md "append:depth for manual mode allows ≤ 3"
    mutate "Sentinel config cap 3"           sentinel/config.json 's/"max_delegation_depth": [0-9]*/"max_delegation_depth": 3/'
    mutate "SSOT loses 'never widens'"       skills/agentic-delegation/SKILL.md 's/never widens/may widen/g'
    mutate "SSOT loses fail-closed"          skills/agentic-delegation/SKILL.md 's/fail-closed/best-effort/g'
    mutate "SSOT exception list reopened"    skills/agentic-delegation/SKILL.md 's/The list is closed[.;]/Other exceptions may apply./'
    mutate "'Max recursion depth: **3**' elsewhere" skills/quiesce/SKILL.md 'append:- Max recursion depth: **3**'
    mutate "'depth: <int, hard-cap 3>'"      protocols/delegation/delegation-dna-prompt.md 's/depth: <int, hard-cap 2>/depth: <int, hard-cap 3>/'
    mutate "bare 'depth ≤ 3' in a skill"     skills/work-drain/SKILL.md 's/depth ≤ 2 (/depth ≤ 3 (/'
    mutate "Sentinel valid_range max 5"      sentinel/config.json 's/"max": 2/"max": 5/'
    mutate "cap restated without SSOT link"  skills/agentic-tool-forge/SKILL.md 's/ (`skills\/agentic-delegation` §8)//'
    mutate "child inherits parent's full scope" agents/orchestrator.md "append:A child inherits the parent's full scope."
    mutate "SSOT loses scope-issuer clause"  skills/agentic-delegation/SKILL.md 's/A scope counts only if the parent issued it/A scope counts if anyone states it/'
    mutate "SSOT loses criterion-5 escalate" skills/agentic-delegation/SKILL.md 's/always escalates/may run inline/'
    mutate "depth cap in rules/"             rules/core-directive.md 'append:Delegation depth ≤ 3.'
    mutate "audit config table shows 3"      skills/audit/SKILL.md 's/| depth.max_delegation_depth | 2 | 2 |/| depth.max_delegation_depth | 3 | 3 |/'
    mutate "statusmap shows depth 2/3"       statusmap/templates/statusmap_templates.md 's#reached:  2/2#reached:  2/3#'
    mutate "'depth must not exceed 3'"       agents/orchestrator.md 'append:Delegation depth must not exceed 3.'
    mutate "child adopts task-requested authority" agents/orchestrator.md 'append:A child may adopt any authority requested by its task.'
    mutate "Sentinel valid_range max unreadable" sentinel/config.json 's/"max": 2/"max": "unknown"/'
    mutate "SSOT re-adds depth derivation"   skills/agentic-delegation/SKILL.md 's/A child that receives none is a leaf/A child that receives none derives it/'
    mutate "Sentinel cap written as 2e1"     sentinel/config.json 's/"max_delegation_depth": 2,/"max_delegation_depth": 2e1,/'
    mutate "Sentinel cap written as 2.5"     sentinel/config.json 's/"max_delegation_depth": 2,/"max_delegation_depth": 2.5,/'
    mutate "auto-pilot bypass sentence back" skills/auto-pilot/SKILL.md 'append:Agents that do not read the block behave exactly as before.'
    mutate "statusmap '(2/3 depth)' order"   statusmap/templates/statusmap_templates.md 's#LOW (2/2 depth)#LOW (2/3 depth)#'
    mutate "statusmap 'within limit 3'"      statusmap/templates/statusmap_templates.md 's#(within limit 2)#(within limit 3)#'
    mutate "DNA prompt v1.0 bypass (2 lines)" protocols/delegation/delegation-dna-prompt.md 's#agents that ignore the block still apply#agents that ignore the block\
behave exactly as in v1.0; they need not apply#'
    mutate "Sentinel config deleted"         sentinel/config.json delete
    mutate "depth cap in .codex/AGENTS.md"   .codex/AGENTS.md 'append:Delegation depth ≤ 3.'
    mutate "depth cap in Codex agent TOML"   .codex/agents/explorer.toml 's#^Stay in exploration mode\.#Stay in exploration mode. Delegation depth ≤ 3.#'
    mutate "depth cap in Copilot instructions" .github/copilot-instructions.md 'append:Delegation depth ≤ 3.'
    mutate "SSOT loses task-bound return"    skills/agentic-delegation/SKILL.md 's#; when the child cannot confirm that, the task is returned to the parent##'
    mutate "SSOT loses escape-clause limit"  skills/agentic-delegation/SKILL.md 's#The escape clause never relaxes §4.1#The escape clause may relax §4.1#'
    mutate "council-gate P0 loses parent bound" skills/council-gate/SKILL.md 's#, and that task itself is shown to be within its parent.s authority##'
    mutate "Sentinel schema example max 3"   sentinel/schema/alert_schema.json 's/"max_allowed": 2/"max_allowed": 3/'
    mutate "SSOT loses reversible-only grant" skills/agentic-delegation/SKILL.md 's#covers only \*\*reversible\*\* actions#covers any actions#'
    mutate "SSOT loses lower-cap rule"       skills/agentic-delegation/SKILL.md 's#, the lower one applies#, the higher one applies#'
    mutate "personal-layer back-reference"   skills/agentic-delegation/SKILL.md "s/^> \*\*Scope\*\*:/> See the operator-host framework. **Scope**:/"
    wait
    i=1
    while [ "$i" -le "$NFIX" ]; do
        if [ ! -f "$FIX/r$i" ]; then
            bad "fixture $i produced no result"
        else
            IFS="$(printf '\t')" read -r r label < "$FIX/r$i"
            if [ "$r" = pass ]; then bad "fixture not detected: $label"; else ok "fixture detected: $label"; fi
        fi
        i=$((i + 1))
    done
fi

[ "$QUIET" = 1 ] || echo ""
if [ "$FAILS" -eq 0 ]; then
    [ "$QUIET" = 1 ] || echo "PASS"
    exit 0
fi
[ "$QUIET" = 1 ] || echo "FAIL ($FAILS)"
exit 1
