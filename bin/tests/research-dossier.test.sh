#!/usr/bin/env bash
# Tests for bin/research-dossier-render.mjs — the renderer and its two f=0 gates.
#
# The point of this file: a gate is only real if it is proven in BOTH directions.
# Every negative fixture is therefore asserted on its SPECIFIC failure code, not
# merely on "exit 1" — a fixture that failed for an unintended reason would pass a
# naive check while proving nothing about the check it was written to exercise.
#
# Exit codes are captured DIRECTLY, never through a pipe: a pipe reports the exit
# of its LAST command, so `node render.mjs | grep x` silently reports grep's status
# and a failing build reads as green.
#
# Spec:        skills/research-dossier/SKILL.md (§Verify) — the gates under test.
# Requires:    bash 3.2+, node >= 18. python3 is OPTIONAL: the blocks that need it
#              build IR mutations on the fly and self-skip with a logged SKIP when it
#              is absent, so the suite still runs (narrower) on a minimal host.
# Idempotent:  yes — all writes go to a mktemp dir removed on EXIT; nothing outside
#              it is touched, so repeated runs on the same tree are identical.
# Network:     none. Offline by construction.
# Portability: POSIX-spelled utilities (`head -n 1`, not `head -1`); no GNU-only flags.
# Layer:       no organization-specific content — Layer-Purity clean.
#
# Run: bash bin/tests/research-dossier.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$DIR/.."
REND="$ROOT/research-dossier-render.mjs"
EX="$ROOT/../skills/research-dossier/examples"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
eq() { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'research-dossier.test.sh\n'

if ! command -v node >/dev/null 2>&1; then
  printf '  SKIP: node not available\n\n0 passed, 0 failed\n'; exit 0
fi

TMP="$(mktemp -d 2>/dev/null || echo /tmp/rdt.$$)"; mkdir -p "$TMP"
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# gates <fixture> [extra-args...] → sets RC and OUT (exit code captured directly)
gates() {
  local f="$1"; shift
  OUT="$(node "$REND" --ir "$EX/$f" --gates-only "$@" 2>&1)"; RC=$?
}

# ── fixtures exist ────────────────────────────────────────────────────────────
for f in valid missing-source truncated-axis dangling-refs bad-palette wish-not-decision; do
  [ -f "$EX/ir-$f.json" ] && ok "fixture ir-$f.json present" || no "fixture ir-$f.json present" "missing"
done

# ── the positive: the valid IR must actually pass ─────────────────────────────
# A gate that rejects everything is not a gate, it is a wall.
gates ir-valid.json
eq '0' "$RC" 'ir-valid passes both gates (exit 0)'

# ── the negatives: each must fail, and fail for ITS OWN reason ────────────────
gates ir-missing-source.json
eq '1' "$RC" 'ir-missing-source fails (exit 1)'
case "$OUT" in *CLAIM_NO_SOURCE*)     ok 'missing-source → CLAIM_NO_SOURCE' ;;     *) no 'missing-source → CLAIM_NO_SOURCE' "$OUT" ;; esac
case "$OUT" in *CLAIM_NO_CONFIDENCE*) ok 'missing-source → CLAIM_NO_CONFIDENCE' ;; *) no 'missing-source → CLAIM_NO_CONFIDENCE' "$OUT" ;; esac
case "$OUT" in *CLAIM_NO_AS_OF*)      ok 'missing-source → CLAIM_NO_AS_OF' ;;      *) no 'missing-source → CLAIM_NO_AS_OF' "$OUT" ;; esac

# The load-bearing one: this is what carries the text-level faithfulness
# discipline into the visual layer. A bar chart starting at 60 exaggerates a small
# difference into a landslide whether or not anyone intended it.
gates ir-truncated-axis.json
eq '1' "$RC" 'ir-truncated-axis fails (exit 1)'
case "$OUT" in *UNDECLARED_TRUNCATION*) ok 'truncated-axis → UNDECLARED_TRUNCATION' ;; *) no 'truncated-axis → UNDECLARED_TRUNCATION' "$OUT" ;; esac

gates ir-dangling-refs.json
eq '1' "$RC" 'ir-dangling-refs fails (exit 1)'
case "$OUT" in *DANGLING_CLAIM_REF*) ok 'dangling-refs → DANGLING_CLAIM_REF' ;; *) no 'dangling-refs → DANGLING_CLAIM_REF' "$OUT" ;; esac
case "$OUT" in *EMPTY_NOT_CHECKED*)  ok 'dangling-refs → EMPTY_NOT_CHECKED' ;;  *) no 'dangling-refs → EMPTY_NOT_CHECKED' "$OUT" ;; esac

gates ir-wish-not-decision.json
eq '1' "$RC" 'ir-wish-not-decision fails (exit 1)'
case "$OUT" in *REC_NO_OWNER*) ok 'wish-not-decision → REC_NO_OWNER' ;; *) no 'wish-not-decision → REC_NO_OWNER' "$OUT" ;; esac
case "$OUT" in *REC_NO_ETA*)   ok 'wish-not-decision → REC_NO_ETA' ;;   *) no 'wish-not-decision → REC_NO_ETA' "$OUT" ;; esac

# ── gate 2: colour is computable, so it is computed ───────────────────────────
gates ir-bad-palette.json
eq '1' "$RC" 'ir-bad-palette fails (exit 1)'
case "$OUT" in *PALETTE_FAIL*) ok 'bad-palette → PALETTE_FAIL' ;; *) no 'bad-palette → PALETTE_FAIL' "$OUT" ;; esac
# Both modes are validated: dark is SELECTED, not flipped, so it can fail alone.
case "$OUT" in *light*) ok 'palette gate validates light mode' ;; *) no 'palette gate validates light mode' "$OUT" ;; esac
case "$OUT" in *dark*)  ok 'palette gate validates dark mode'  ;; *) no 'palette gate validates dark mode'  "$OUT" ;; esac

# ── degradation: the bundled validator lives in a version-and-hash-keyed temp
# dir that MOVES on every CLI upgrade. Absent → loud WARN, never a silent pass.
OUT="$(DATAVIZ_VALIDATOR=/nonexistent node "$REND" --ir "$EX/ir-valid.json" --gates-only 2>&1)"; RC=$?
eq '0' "$RC" 'missing validator degrades to WARN (still exit 0)'
case "$OUT" in *WARN*) ok 'missing validator emits a visible WARN' ;; *) no 'missing validator emits a visible WARN' "$OUT" ;; esac

# ...and --strict turns that warning into a failure, so CI cannot drift green.
OUT="$(DATAVIZ_VALIDATOR=/nonexistent node "$REND" --ir "$EX/ir-valid.json" --gates-only --strict 2>&1)"; RC=$?
eq '1' "$RC" '--strict makes a missing validator a FAILURE'
case "$OUT" in *PALETTE_VALIDATOR_MISSING*) ok '--strict → PALETTE_VALIDATOR_MISSING' ;; *) no '--strict → PALETTE_VALIDATOR_MISSING' "$OUT" ;; esac

# ── gates run BEFORE anything is written ──────────────────────────────────────
# A failed dossier must produce NO output at all, rather than a plausible-looking
# one. Half a dossier is more dangerous than none: it looks finished.
OUTDIR="$TMP/nowrite"
node "$REND" --ir "$EX/ir-missing-source.json" --formats html,md,json --out "$OUTDIR" >/dev/null 2>&1; RC=$?
eq '1' "$RC" 'failing IR exits 1 on a full render'
if [ ! -d "$OUTDIR" ] || [ -z "$(ls -A "$OUTDIR" 2>/dev/null)" ]; then
  ok 'failing IR wrote NOTHING (gates precede all writes)'
else
  no 'failing IR wrote NOTHING (gates precede all writes)' "$(ls -A "$OUTDIR" 2>/dev/null | tr '\n' ' ')"
fi

# ── fan-out: one IR → three formats ───────────────────────────────────────────
OUTDIR="$TMP/out"
node "$REND" --ir "$EX/ir-valid.json" --formats html,md,json --out "$OUTDIR" >/dev/null 2>&1; RC=$?
eq '0' "$RC" 'valid IR renders (exit 0)'
for f in dossier.html dossier.md dossier.json; do
  [ -s "$OUTDIR/$f" ] && ok "emits $f (non-empty)" || no "emits $f (non-empty)" "missing or empty"
done

HTML="$OUTDIR/dossier.html"
if [ -s "$HTML" ]; then
  # ── offline: opens over file://, no network ────────────────────────────────
  # The invariant is no remote SUBRESOURCE — source citation URLs are provenance
  # and MUST stay. Grepping for "https" would flag the evidence as the defect.
  n=$(grep -cE '<(script|link|img)[^>]+(src|href)="https?://' "$HTML" 2>/dev/null || true)
  eq '0' "${n:-0}" 'zero remote subresources (script/link/img) — opens offline'

  # ── JS off → the dossier still renders completely ──────────────────────────
  # An archival decision artifact that needs a script to show its evidence is not
  # archival. The body is server-side; JS only reveals the theme toggle.
  n=$(grep -c '<table' "$HTML" 2>/dev/null || true)
  [ "${n:-0}" -ge 1 ] && ok "evidence tables are server-rendered (${n} <table>)" \
                      || no 'evidence tables are server-rendered' "found ${n:-0}"
  n=$(grep -c '__[A-Z_]*__' "$HTML" 2>/dev/null || true)
  eq '0' "${n:-0}" 'no unfilled template placeholders survived substitution'

  # ── accessibility + print (per dataviz: the table IS the accessible rendering)
  n=$(grep -c 'role="img"' "$HTML" 2>/dev/null || true)
  [ "${n:-0}" -ge 1 ] && ok "charts carry role=\"img\" (${n})" || no 'charts carry role="img"' "found ${n:-0}"
  n=$(grep -c 'aria-label' "$HTML" 2>/dev/null || true)
  [ "${n:-0}" -ge 1 ] && ok "charts carry aria-label (${n})" || no 'charts carry aria-label' "found ${n:-0}"
  for pat in '@media print' 'prefers-reduced-motion' 'prefers-color-scheme'; do
    grep -q "$pat" "$HTML" 2>/dev/null && ok "honors $pat" || no "honors $pat" 'absent'
  done

  # ── the blind spots are what make the rest credible ────────────────────────
  grep -qi 'not checked\|not_checked' "$HTML" 2>/dev/null \
    && ok 'not_checked[] is surfaced in the output' || no 'not_checked[] is surfaced in the output' 'absent'
fi

# ── declared truncation: passes, AND the rationale is printed on the chart ────
# The declaration is a cost, not a bypass — it survives into what the reader sees.
python3 - "$EX/ir-valid.json" "$TMP/ir-declared.json" <<'PY' 2>/dev/null
import json,sys
ir=json.load(open(sys.argv[1]))
ch=(ir.get('charts') or [])
if ch:
    ax=ch[0].setdefault('axis',{})
    ax['y_min']=60; ax['axis_truncated']=True
    ax['truncation_rationale']='Baseline is 60 KB; below that no library is viable.'
json.dump(ir,open(sys.argv[2],'w'))
PY
if [ -s "$TMP/ir-declared.json" ]; then
  node "$REND" --ir "$TMP/ir-declared.json" --gates-only >/dev/null 2>&1; RC=$?
  eq '0' "$RC" 'DECLARED truncation passes the gate'
  node "$REND" --ir "$TMP/ir-declared.json" --formats html --out "$TMP/decl" >/dev/null 2>&1
  if [ -s "$TMP/decl/dossier.html" ]; then
    grep -qi 'truncat' "$TMP/decl/dossier.html" \
      && ok 'declared truncation is disclosed in the rendered chart' \
      || no 'declared truncation is disclosed in the rendered chart' 'no notice in output'
  fi
else
  ok 'SKIP declared-truncation (python3 unavailable)'
fi

# ── red-team hardening: the semantic checks (2026-07-29) ──────────────────────
# An independent adversary produced a board-grade dossier that inverted a
# $1.18M-vs-$0.34M comparison at exit 0. Referential integrity held throughout —
# every pointer resolved. What was missing was any check that a citation AGREED
# with what it cited. Each assertion below pins one of those bypasses shut.
if command -v python3 >/dev/null 2>&1; then
  mk() { python3 - "$EX/ir-valid.json" "$TMP/$1" "$2" <<'PY' 2>/dev/null
import json,sys
ir=json.load(open(sys.argv[1])); out=sys.argv[2]; which=sys.argv[3]
sc=ir.get('scorecard') or {}
if which=='point-mismatch':          # chart plots a number its cited claim contradicts
    ir['charts'][0]['series'][0]['data'][0]['y']=41
elif which=='display-lie':           # display overrides value with an inverted magnitude
    for c in sc.get('cells',[]):
        if c.get('criterion')=='size' and isinstance(c.get('value'),(int,float)):
            c['display']='18 KB'; break
elif which=='form-dodge':            # non-magnitude form + truncated axis
    ir['charts'][0]['form']='line'; ir['charts'][0]['axis']['y_min']=60
elif which=='compression':           # inflated y_max flattens every mark
    ir['charts'][0]['axis']['y_max']=100000
elif which=='vacuous-nc':
    ir['not_checked']=[{'text':'Everything material was checked.','reason':'Comprehensive review.','impact':'none'}]
elif which=='all-none-nc':
    for n in ir['not_checked']: n['impact']='none'
elif which=='stale':                 # every claim years older than the dossier
    ir['stakes']='high'
    for c in ir['claims']: c['as_of']='2019-01-01'
json.dump(ir,open(out,'w'))
PY
  }
  gt() { node "$REND" --ir "$TMP/$1" --gates-only 2>&1; }

  mk ir-point.json point-mismatch
  node "$REND" --ir "$TMP/ir-point.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'chart data contradicting its cited claim FAILS'
  case "$(gt ir-point.json)" in *CHART_POINT_VALUE_MISMATCH*) ok '→ CHART_POINT_VALUE_MISMATCH' ;; *) no '→ CHART_POINT_VALUE_MISMATCH' 'not raised' ;; esac

  mk ir-display.json display-lie
  node "$REND" --ir "$TMP/ir-display.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'cell display contradicting its own value FAILS'
  case "$(gt ir-display.json)" in *CELL_DISPLAY_DIVERGES*) ok '→ CELL_DISPLAY_DIVERGES' ;; *) no '→ CELL_DISPLAY_DIVERGES' 'not raised' ;; esac

  # The renderer draws every chart as proportional bars, so a declared form that
  # the renderer ignores must not exempt a chart from the truncation check.
  mk ir-form.json form-dodge
  node "$REND" --ir "$TMP/ir-form.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'truncation is caught regardless of declared form'
  case "$(gt ir-form.json)" in *UNDECLARED_TRUNCATION*) ok '→ UNDECLARED_TRUNCATION on a non-bar form' ;; *) no '→ UNDECLARED_TRUNCATION on a non-bar form' 'not raised' ;; esac

  mk ir-compress.json compression
  node "$REND" --ir "$TMP/ir-compress.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'inflated y_max (difference-hiding) FAILS'
  case "$(gt ir-compress.json)" in *UNDECLARED_COMPRESSION*) ok '→ UNDECLARED_COMPRESSION' ;; *) no '→ UNDECLARED_COMPRESSION' 'not raised' ;; esac

  # The empty-array check was evaded by writing the omniscience claim longhand.
  mk ir-vacuous.json vacuous-nc
  node "$REND" --ir "$TMP/ir-vacuous.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'boilerplate not_checked[] FAILS'
  case "$(gt ir-vacuous.json)" in *NOT_CHECKED_VACUOUS*|*NOT_CHECKED_ALL_INCONSEQUENTIAL*) ok '→ NOT_CHECKED_VACUOUS / ALL_INCONSEQUENTIAL' ;; *) no '→ NOT_CHECKED_VACUOUS / ALL_INCONSEQUENTIAL' 'not raised' ;; esac

  mk ir-allnone.json all-none-nc
  node "$REND" --ir "$TMP/ir-allnone.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'every blind spot marked impact:none FAILS'

  mk ir-stale.json stale
  node "$REND" --ir "$TMP/ir-stale.json" --gates-only >/dev/null 2>&1
  eq '1' "$?" 'years-stale evidence FAILS at stakes:high'
  case "$(gt ir-stale.json)" in *CLAIM_STALE*) ok '→ CLAIM_STALE' ;; *) no '→ CLAIM_STALE' 'not raised' ;; esac

  # A malformed IR must produce a GATE VERDICT, never a stack trace. A crash is
  # strictly worse than a failure: it tells the author nothing about which
  # invariant broke, and an exit code from an uncaught throw is indistinguishable
  # from a legitimate rejection. Empty options + retained cells slipped past the
  # sparse-row guard (`[].some()` is vacuously false) into an empty-object reduce.
  python3 - "$EX/ir-valid.json" "$TMP/ir-nooptions.json" <<'PY' 2>/dev/null
import json,sys
ir=json.load(open(sys.argv[1]))
(ir.get('scorecard') or {})['options']=[]        # cells deliberately RETAINED
json.dump(ir,open(sys.argv[2],'w'))
PY
  if [ -s "$TMP/ir-nooptions.json" ]; then
    OUT="$(node "$REND" --ir "$TMP/ir-nooptions.json" --gates-only 2>&1)"; RC=$?
    eq '1' "$RC" 'options:[] with cells retained fails the GATE (exit 1, not a crash)'
    case "$OUT" in
      *TypeError*|*RangeError*|*"at gateProvenance"*) no 'malformed IR never throws — a crash is not a verdict' "$OUT" ;;
      *) ok 'malformed IR never throws — a crash is not a verdict' ;;
    esac
    case "$OUT" in *BUILD\ FAILED*) ok 'crash-path still reports a readable gate verdict' ;; *) no 'crash-path still reports a readable gate verdict' "$OUT" ;; esac
  fi
else
  ok 'SKIP red-team hardening tests (python3 unavailable)'
fi

# ── density: audience reaches the RENDER, not just the prose ──────────────────
# Gap #5. Density changes presentation only — never claims, cells, or not_checked[].
if command -v python3 >/dev/null 2>&1; then
  python3 - "$EX/ir-valid.json" "$TMP" <<'PY' 2>/dev/null
import json,copy,sys,os
ir=json.load(open(sys.argv[1])); t=sys.argv[2]
for aud in ('exec','engineer'):
    v=copy.deepcopy(ir); v['audience']=aud
    json.dump(v,open(os.path.join(t,f'ir-{aud}.json'),'w'))
v=copy.deepcopy(ir); v['audience']='exec'; v['stakes']='high'
json.dump(v,open(os.path.join(t,'ir-exec-high.json'),'w'))
# 4 charts: over the public cap (2), under the engineer cap (Infinity)
v=copy.deepcopy(ir); base=v['charts'][0]; v['charts']=[]
for i in range(4):
    c=copy.deepcopy(base); c['id']=f"{base['id']}-{i}"; v['charts'].append(c)
v['audience']='public'; json.dump(v,open(os.path.join(t,'ir-many-public.json'),'w'))
v['audience']='engineer'; json.dump(v,open(os.path.join(t,'ir-many-eng.json'),'w'))
PY

  rd() { node "$REND" --ir "$TMP/$1" --formats html --out "$TMP/den-$2" >/dev/null 2>&1; }
  # grep -c prints 0 AND exits 1 on no-match, so a `|| echo 0` would emit TWO
  # lines and every numeric compare downstream would silently fail. Take head -n 1
  # (the POSIX spelling; `head -1` is an obsolescent form).
  cnt() { grep -c "$2" "$TMP/den-$1/dossier.html" 2>/dev/null | head -n 1; }

  rd ir-exec.json exec
  eq '0' "$(cnt exec 'details class="tableview" open')" 'exec density collapses the evidence table'
  rd ir-engineer.json eng
  [ "$(cnt eng 'details class="tableview" open')" -ge 1 ] \
    && ok 'engineer density expands the evidence table' \
    || no 'engineer density expands the evidence table' 'not open'
  # High stakes re-expands regardless of audience: the reader with the least
  # context must not receive the least-qualified version of the truth.
  rd ir-exec-high.json exechigh
  [ "$(cnt exechigh 'details class="tableview" open')" -ge 1 ] \
    && ok 'stakes:high re-expands evidence even at exec density' \
    || no 'stakes:high re-expands evidence even at exec density' 'stayed collapsed'

  rd ir-many-public.json manypub
  eq '2' "$(cnt manypub '<svg')" 'public density caps charts at 2'
  # A dropped chart is disclosed — an omission the reader cannot see is an edit.
  [ "$(cnt manypub 'omitted at')" -ge 1 ] \
    && ok 'omitted charts are DISCLOSED, not silently swallowed' \
    || no 'omitted charts are DISCLOSED, not silently swallowed' 'no notice'
  rd ir-many-eng.json manyeng
  eq '4' "$(cnt manyeng '<svg')" 'engineer density renders all 4 charts'
  eq '0' "$(cnt manyeng 'omitted at')" 'no omission notice when nothing is omitted'

  # Density is PRESENTATION. The evidence must be byte-identical across audiences.
  node "$REND" --ir "$TMP/ir-exec.json"     --formats json --out "$TMP/j-exec" >/dev/null 2>&1
  node "$REND" --ir "$TMP/ir-engineer.json" --formats json --out "$TMP/j-eng"  >/dev/null 2>&1
  a="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps([d.get('claims'),d.get('not_checked'),(d.get('scorecard') or {}).get('cells')],sort_keys=True))" "$TMP/j-exec/dossier.json" 2>/dev/null)"
  b="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps([d.get('claims'),d.get('not_checked'),(d.get('scorecard') or {}).get('cells')],sort_keys=True))" "$TMP/j-eng/dossier.json" 2>/dev/null)"
  if [ -n "$a" ] && [ "$a" = "$b" ]; then
    ok 'audience changes presentation ONLY — claims/cells/not_checked identical'
  else
    no 'audience changes presentation ONLY — claims/cells/not_checked identical' 'evidence differs across audiences'
  fi
else
  ok 'SKIP density tests (python3 unavailable)'
fi

# ── stacked composition is PER BUCKET (2026-07-29 review) ─────────────────────
# A stack composes per x-bucket: two quarters against a one-quarter total is not a
# discrepancy. Both directions matter — a false positive here would train authors
# to treat the gate as noise, which is how a gate stops being a gate.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$EX/ir-valid.json" "$TMP/ir-stack-ok.json" "$TMP/ir-stack-bad.json" <<'PY' 2>/dev/null
import json,sys
base=json.load(open(sys.argv[1]))
def build(dst, per_bucket, buckets, total):
    ir=json.loads(json.dumps(base))
    ir['claims']=[c for c in ir['claims'] if c['id']!='c-stack-total'] + [{
        "id":"c-stack-total","text":f"Total spend was {total}.","source":{"label":"finance"},
        "as_of":"2026-07-01","confidence":"high",
        "metric":{"name":"total spend","value":total,"unit":"USD"}}]
    ir['charts']=[{"id":"ch-stack","form":"stacked-bar","title":"Spend composition",
        "source_claims":["c-stack-total"],
        "series":[{"label":f"part{p}","data":[{"x":f"Q{b+1}","y":per_bucket/2} for b in range(buckets)]}
                  for p in range(2)]}]
    json.dump(ir,open(dst,'w'))
# honest: 2 buckets, each composing to the cited 1-bucket total
build(sys.argv[2], 1000, 2, 1000)
# dishonest: no bucket reaches the cited total
build(sys.argv[3],  100, 2, 1000)
PY
  if [ -s "$TMP/ir-stack-ok.json" ]; then
    OUT="$(node "$REND" --ir "$TMP/ir-stack-ok.json" --gates-only 2>&1)"
    case "$OUT" in
      *STACKED_PARTS_MISMATCH*) no 'multi-bucket stack is NOT a false positive' "$OUT" ;;
      *) ok 'multi-bucket stack is NOT a false positive (per-bucket, not flat sum)' ;;
    esac
    node "$REND" --ir "$TMP/ir-stack-bad.json" --gates-only >/dev/null 2>&1
    eq '1' "$?" 'a stack where NO bucket reaches its cited total still FAILS'
    case "$(node "$REND" --ir "$TMP/ir-stack-bad.json" --gates-only 2>&1)" in
      *STACKED_PARTS_MISMATCH*) ok '→ STACKED_PARTS_MISMATCH (real omission still caught)' ;;
      *) no '→ STACKED_PARTS_MISMATCH (real omission still caught)' 'not raised' ;;
    esac
  fi
fi

# ── every artifact carries its emitter + evidence horizon ─────────────────────
# CLAUDE.md MUST: "Sign documents with agent ID and timestamp". Dated from the IR's
# own as_of, NOT wall-clock: re-rendering an unchanged IR must be byte-identical, or
# every diff becomes noise and the signature stops being auditable.
if [ -s "$HTML" ]; then
  grep -q 'research-dossier v' "$HTML" && ok 'rendered dossier is signed with the emitter id' \
                                       || no 'rendered dossier is signed with the emitter id' 'absent'
  grep -q 'evidence as of' "$HTML" && ok 'rendered dossier states its evidence horizon' \
                                   || no 'rendered dossier states its evidence horizon' 'absent'
  node "$REND" --ir "$EX/ir-valid.json" --formats html --out "$TMP/idem" >/dev/null 2>&1
  if cmp -s "$HTML" "$TMP/idem/dossier.html"; then ok 'render is idempotent (no wall-clock in the artifact)'
  else no 'render is idempotent (no wall-clock in the artifact)' 'byte-differs across runs'; fi
fi

# ── the rendered HTML is untrusted-input-safe (2026-07-29 review) ─────────────
# This artifact exists to be opened in a browser and passed around, so an IR field
# is attack surface, not decoration. Both holes below were live and demonstrated
# before the fix; each assertion checks the EXPLOIT is dead AND the legitimate
# behaviour it rode on still works — a "safe" renderer that drops the evidence or
# the colour would pass a naive check while breaking the dossier.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$EX/ir-valid.json" "$TMP/ir-xss.json" "$TMP/ir-cssinj.json" <<'PY' 2>/dev/null
import json,sys
base=json.load(open(sys.argv[1]))
a=json.loads(json.dumps(base))
a['claims'][0]['source']['url']='javascript:alert(document.domain)'
json.dump(a,open(sys.argv[2],'w'))
b=json.loads(json.dumps(base))
# The key must be the one resolvePalette() actually reads. An earlier draft of this
# fixture used theme.palette=[...] — the payload then only ever appeared inside the
# inert JSON island, so the assertion passed with the guard REMOVED. A security test
# that cannot fail is worse than none: it certifies a hole it never touched.
t=b.setdefault('theme',{}).setdefault('palette',{})
t['categorical_light']=['#1f77b4;} body{display:none} .x{color:red','#ff7f0e']
t['categorical_dark'] =['#1f77b4;} body{display:none} .y{color:red','#ff7f0e']
json.dump(b,open(sys.argv[3],'w'))
PY
  if [ -s "$TMP/ir-xss.json" ]; then
    node "$REND" --ir "$TMP/ir-xss.json" --formats html --out "$TMP/sec-xss" >/dev/null 2>&1
    X="$TMP/sec-xss/dossier.html"
    n=$(grep -c 'href="javascript:' "$X" 2>/dev/null || true)
    eq '0' "${n:-0}" 'a javascript: source URL never becomes a clickable href'
    # Withdrawing clickability must not withdraw the PROVENANCE — hiding the URL
    # would trade an XSS for an evidence gap, which is the worse defect here.
    n=$(grep -c 'javascript:alert' "$X" 2>/dev/null || true)
    [ "${n:-0}" -ge 1 ] && ok 'the rejected URL is still shown as text (evidence preserved)' \
                        || no 'the rejected URL is still shown as text (evidence preserved)' 'URL vanished'
    n=$(grep -cE 'href="https?://' "$X" 2>/dev/null || true)
    [ "${n:-0}" -ge 1 ] && ok 'legitimate http(s) citations remain clickable' \
                        || no 'legitimate http(s) citations remain clickable' 'allowlist too strict'
  fi
  if [ -s "$TMP/ir-cssinj.json" ]; then
    # WITHOUT the bundled validator: the supported degrade-to-WARN path is exactly
    # where an unvalidated palette token would reach the stylesheet.
    DATAVIZ_VALIDATOR=/nonexistent node "$REND" --ir "$TMP/ir-cssinj.json" --formats html --out "$TMP/sec-css" >/dev/null 2>&1
    C="$TMP/sec-css/dossier.html"
    n=$(grep -cE -- '--series-[0-9]+:[^;]*[{}]' "$C" 2>/dev/null || true)
    eq '0' "${n:-0}" 'a palette token cannot close its declaration and inject CSS rules'
    # ...and the payload must not reach the stylesheet by ANY route. Checking only
    # the declaration shape would miss a token that escaped the <style> block whole.
    n=$(sed -n '/<style/,/<\/style>/p' "$C" 2>/dev/null | grep -c 'display:none' || true)
    eq '0' "${n:-0}" 'the injected rule never lands inside <style> (inert JSON island is fine)'
    # A rejected token must be neutralised, not silently dropped: the inert fallback
    # is what keeps the chart legible instead of colourless.
    n=$(grep -c -- '--series-1: currentColor;' "$C" 2>/dev/null || true)
    [ "${n:-0}" -ge 1 ] && ok 'a rejected palette token degrades to an inert fallback' \
                        || no 'a rejected palette token degrades to an inert fallback' 'no fallback emitted'
    n=$(grep -cE -- '--series-2: *#[0-9a-fA-F]{3,8};' "$C" 2>/dev/null || true)
    [ "${n:-0}" -ge 1 ] && ok 'valid palette hexes alongside it still reach the stylesheet' \
                        || no 'valid palette hexes alongside it still reach the stylesheet' 'colour lost'
  fi
fi

# ── CLI contract: 2 is usage/IO, distinct from 1 (gate failure) ───────────────
node "$REND" --ir /nonexistent/nope.json --gates-only >/dev/null 2>&1
eq '2' "$?" 'missing IR file exits 2 (usage/IO, not a gate failure)'
node "$REND" >/dev/null 2>&1
eq '2' "$?" 'no --ir exits 2 (usage)'
node "$REND" --help >/dev/null 2>&1
eq '0' "$?" '--help exits 0'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
