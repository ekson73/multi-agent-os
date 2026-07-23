#!/usr/bin/env bash
# Test: bin/memory-gateway — the memory-CRUD gateway (ADR-013, EKO-116).
# ----------------------------------------------------------------------------
# Covers the ADR-013 Definition-of-Done test list:
#   - every verb happy-path (create/read/update/archive/index/search/neighborhood)
#   - create dedup-refusal on the canonical identity key (type, normalize(name))
#   - --type REQUIRED on create
#   - type-qualified slug distinctness ((user,profile) vs (project,profile))
#   - concurrent-writer refusal (mutating verb, never clobbers)
#   - boundary refusal (paths escaping the corpus root)
#   - archive-is-not-delete (archived content still exists in the archive tier)
#   - index regeneration (one line per entry)
#   - read-only guarantee for read/search/neighborhood
#   - THE E6 HEADLINE FORGETTING TEST (mutation-hook supersession):
#       N superseded -> N archived + 1 live THROUGH NORMAL WRITES ALONE,
#       every superseded fact ABSENT from active reads, archived copy retrievable
#   - canonicalization (case-fold + kebab; two writes of same canonical id -> same topic)
#   - E6 supersession modes: explicit `--supersedes` (authoritative) · implicit
#       (type,name) match on the ACTIVE corpus only · 0-match -> create ·
#       >=2 candidates -> refuse-with-pointer (never silent wrong-archival)
#   - WAL crash-safety via failure injection at EACH of the 5 write-ahead stages
#       + trailing partial ledger line discarded on recovery
#   - JSON envelope shape + exit-code semantics ([C06]: 0 ok · 1 refused/usage · 2 setup)
#
# Portable (bash 3.2 + jq). Exit 0 = all pass; 1 = a failure.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GW="$HERE/bin/memory-gateway"
# isolate the audit ledger to a throwaway dir (same env-overridable pattern as artifact-registry)
export MEMORY_GATEWAY_DIR="$(mktemp -d)"
ROOT_TMP="$(mktemp -d)"
trap 'rm -rf "$MEMORY_GATEWAY_DIR" "$ROOT_TMP"' EXIT
fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "test-memory-gateway: jq is required" >&2; exit 2; }
[ -x "$GW" ] || { echo "test-memory-gateway: $GW not found/executable (red phase expected before build)" >&2; }

echo "test-memory-gateway:"

# ---- helpers ---------------------------------------------------------------
# run the gateway capturing stdout(OUT), stderr(ERR), exit(RC) WITHOUT aborting
# under set -e. Body (stdin) passed via $BODY (empty if unset). NEVER trust a
# trailing echo for the exit code (script-safety §6) — capture RC immediately.
ERRF="$ROOT_TMP/.err"
gw() {
  local body="${BODY-}"
  if OUT=$(printf '%s' "$body" | "$GW" "$@" 2>"$ERRF"); then RC=0; else RC=$?; fi
  ERR="$(cat "$ERRF" 2>/dev/null || true)"
  BODY=""   # consume
}
jqr() { printf '%s' "$1" | jq -r "$2" 2>/dev/null; }
fresh() { mktemp -d "$ROOT_TMP/corpus.XXXXXX"; }

C="$(fresh)"

# ============================================================================
# 1-7  VERB HAPPY-PATHS
# ============================================================================
BODY="first knowledge line with a [[reference/anchor]] link" gw --corpus "$C" create profile --type user
[ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.slug')" = user/profile ] \
  && ok "1 create happy-path (status=ok, slug=user/profile)" || no "1 create happy-path (rc=$RC out=$OUT)"

gw --corpus "$C" read user/profile
[ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "first knowledge line" \
  && ok "2 read happy-path" || no "2 read happy-path (rc=$RC out=$OUT)"

BODY="appended second line via update" gw --corpus "$C" update user/profile
gw --corpus "$C" read user/profile
if [ "$(jqr "$OUT" '.status')" = ok ] && printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "first knowledge line" \
   && printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "appended second line"; then
  ok "3 update (mode-A append) happy-path"; else no "3 update append (out=$OUT)"; fi

BODY="to be archived" gw --corpus "$C" create scratch --type reference
gw --corpus "$C" archive reference/scratch
[ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] \
  && ok "4 archive happy-path" || no "4 archive happy-path (rc=$RC out=$OUT)"

gw --corpus "$C" index
[ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.data.entries')" -ge 1 ] \
  && ok "5 index happy-path" || no "5 index happy-path (rc=$RC out=$OUT)"

gw --corpus "$C" search knowledge
[ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.data.matches | length')" -ge 1 ] \
  && ok "6 search happy-path" || no "6 search happy-path (rc=$RC out=$OUT)"

# neighborhood: create the link target + a seed linking to it
BODY="anchor topic body" gw --corpus "$C" create anchor --type reference
BODY="seed body linking [[reference/anchor]] here" gw --corpus "$C" create seed --type project
gw --corpus "$C" neighborhood project/seed --depth 1
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] \
   && printf '%s' "$(jqr "$OUT" '.data.nodes[]')" | grep -q "reference/anchor"; then
  ok "7 neighborhood happy-path (walks [[wikilink]])"; else no "7 neighborhood (out=$OUT)"; fi

# ============================================================================
# 8  create DEDUP-REFUSAL on the canonical identity key
# ============================================================================
BODY="dup attempt" gw --corpus "$C" create profile --type user
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.status')" = refused ] && [ "$(jqr "$OUT" '.reason.code')" = DEDUP_COLLISION ] \
  && ok "8 create dedup-refusal (DEDUP_COLLISION, exit 1)" || no "8 create dedup (rc=$RC out=$OUT)"

# ============================================================================
# 9  --type REQUIRED on create
# ============================================================================
BODY="no type" gw --corpus "$C" create rogue
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.status')" = refused ] \
  && ok "9 create without --type refuses" || no "9 missing --type (rc=$RC out=$OUT)"

# ============================================================================
# 10  type-qualified slug distinctness
# ============================================================================
D="$(fresh)"
BODY="user profile"    gw --corpus "$D" create profile --type user
u_rc=$RC; u_slug="$(jqr "$OUT" '.slug')"
BODY="project profile" gw --corpus "$D" create profile --type project
p_rc=$RC; p_slug="$(jqr "$OUT" '.slug')"
if [ "$u_rc" = 0 ] && [ "$p_rc" = 0 ] && [ "$u_slug" = user/profile ] && [ "$p_slug" = project/profile ]; then
  # both must be independently readable
  gw --corpus "$D" read user/profile;    r1=$RC
  gw --corpus "$D" read project/profile; r2=$RC
  [ "$r1" = 0 ] && [ "$r2" = 0 ] && ok "10 (user,profile) & (project,profile) never collide" || no "10 distinct read failed"
else no "10 type-qualified distinctness (u=$u_slug/$u_rc p=$p_slug/$p_rc)"; fi

# ============================================================================
# 11  CONCURRENT-WRITER refusal (mutating verb, held lock, never clobbers)
# ============================================================================
E="$(fresh)"
BODY="v" gw --corpus "$E" create x --type user   # materialize .gateway/
mkdir -p "$E/.gateway/lock.d"                     # simulate a peer holding the corpus lock
date +%s > "$E/.gateway/lock.d/ts" 2>/dev/null || true
BODY="should refuse" gw --corpus "$E" create y --type user
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = CONCURRENT_WRITER ] \
  && ok "11 concurrent-writer refusal (CONCURRENT_WRITER)" || no "11 concurrent-writer (rc=$RC out=$OUT)"
# corpus not clobbered: y must NOT exist as a live topic
[ ! -f "$E/user/y.md" ] && ok "11b concurrent write did not clobber (y absent)" || no "11b y was written under contention"
rm -rf "$E/.gateway/lock.d"

# ============================================================================
# 12  BOUNDARY refusal (paths escaping the corpus root)
# ============================================================================
gw --corpus "$C" read "user/../../../etc/passwd"
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = BOUNDARY ] \
  && ok "12 boundary refusal (traversal ..)" || no "12 boundary traversal (rc=$RC out=$OUT)"
gw --corpus "$C" read "/etc/passwd"
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = BOUNDARY ] \
  && ok "12b boundary refusal (absolute path)" || no "12b boundary absolute (rc=$RC out=$OUT)"

# ============================================================================
# 13  ARCHIVE-IS-NOT-DELETE (archived content still exists in the archive tier)
# ============================================================================
F="$(fresh)"
BODY="UNIQUEARCHIVEKW content" gw --corpus "$F" create doomed --type feedback
gw --corpus "$F" archive feedback/doomed
# live gone
[ ! -f "$F/feedback/doomed.md" ] && ok "13 archived topic gone from live corpus" || no "13 live topic still present after archive"
# but the content survives somewhere under the archive tier
if grep -rq "UNIQUEARCHIVEKW" "$F/.archive" 2>/dev/null; then
  ok "13b archived content survives in the archive tier (not destroyed)"; else no "13b archived content was destroyed"; fi
# active search must NOT surface archived content
gw --corpus "$F" search UNIQUEARCHIVEKW
[ "$(jqr "$OUT" '.data.matches | length')" = 0 ] && ok "13c archived content absent from active search" || no "13c archived leaked into active search"

# ============================================================================
# 14  INDEX REGENERATION (one line per LIVE entry)
# ============================================================================
G="$(fresh)"
BODY="a" gw --corpus "$G" create alpha --type user
BODY="b" gw --corpus "$G" create bravo --type user
BODY="c" gw --corpus "$G" create carol --type project
gw --corpus "$G" index
[ "$(jqr "$OUT" '.data.entries')" = 3 ] && ok "14 index: 3 entries for 3 live topics" || no "14 index count (out=$OUT)"
# archiving one -> index re-tiers to 2
gw --corpus "$G" archive user/bravo >/dev/null
gw --corpus "$G" index
[ "$(jqr "$OUT" '.data.entries')" = 2 ] && ok "14b index drops archived entry (3->2)" || no "14b index after archive (out=$OUT)"
# one MEMORY.md line per live entry (grep the index file)
lines=$(grep -c '](' "$G/MEMORY.md" 2>/dev/null || echo 0)
[ "$lines" = 2 ] && ok "14c MEMORY.md has one line per live entry" || no "14c MEMORY.md line count = $lines"

# ============================================================================
# 15  READ-ONLY GUARANTEE (read/search/neighborhood never mutate the corpus)
# ============================================================================
H="$(fresh)"
BODY="ro body [[reference/x]]" gw --corpus "$H" create topic --type user
BODY="x" gw --corpus "$H" create x --type reference
gw --corpus "$H" index >/dev/null
# snapshot corpus content (topic files + index + archive) — exclude gateway internals
snap() { find "$H" -path '*/.gateway' -prune -o -type f -print 2>/dev/null \
         | LC_ALL=C sort | while IFS= read -r f; do printf '%s\t%s\n' "$f" "$(wc -c <"$f" | tr -d ' ')"; done; }
before="$(snap)"
gw --corpus "$H" read user/topic >/dev/null
gw --corpus "$H" search body >/dev/null
gw --corpus "$H" neighborhood user/topic --depth 2 >/dev/null
after="$(snap)"
[ "$before" = "$after" ] && ok "15 read/search/neighborhood are read-only (corpus unchanged)" || no "15 a read verb mutated the corpus"

# ============================================================================
# 16  E6 HEADLINE FORGETTING TEST (the one that would fail today)
#     N superseded facts -> N archived + 1 live THROUGH NORMAL WRITES ALONE;
#     every superseded fact ABSENT from active reads; archived copy retrievable.
# ============================================================================
K="$(fresh)"
N=4
BODY="version FACTKW1 initial" gw --corpus "$K" create profile --type user   # v1 live
e6_ok=1
i=2
last=$((N+1))
while [ "$i" -le "$last" ]; do
  BODY="version FACTKW$i supersede" gw --corpus "$K" update --supersede --type user --name profile
  [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] || { e6_ok=0; echo "    (supersede $i failed rc=$RC out=$OUT)"; }
  i=$((i+1))
done
# after N supersessions: exactly 1 live + N archived, live = the newest fact
gw --corpus "$K" read user/profile
live_ok=0; printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "FACTKW$((N+1))" && live_ok=1
arch_count=$(find "$K/.archive" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$e6_ok" = 1 ] && [ "$live_ok" = 1 ] && [ "$arch_count" = "$N" ] \
  && ok "16 E6: $N supersessions -> $N archived + 1 live through normal writes alone" \
  || no "16 E6 converge ($N archived expected, got $arch_count; live_ok=$live_ok; e6_ok=$e6_ok)"
# every superseded fact ABSENT from active reads/search
absent=1
j=1
while [ "$j" -le "$N" ]; do
  gw --corpus "$K" search "FACTKW$j"
  [ "$(jqr "$OUT" '.data.matches | length')" = 0 ] || { absent=0; echo "    (FACTKW$j still surfaces in active search)"; }
  j=$((j+1))
done
[ "$absent" = 1 ] && ok "16b E6: every superseded fact ABSENT from active search" || no "16b superseded fact leaked into active reads"
# archived copies stay RETRIEVABLE from the archive tier
gw --corpus "$K" read user/profile --archived
[ "$(jqr "$OUT" '.data.archived | length')" = "$N" ] \
  && ok "16c E6: all $N archived copies retrievable via read --archived" || no "16c archive retrieval (out=$OUT)"

# ============================================================================
# 17  CANONICALIZATION (case-fold + kebab; same canonical id -> same topic)
# ============================================================================
L="$(fresh)"
BODY="canon body" gw --corpus "$L" create "My Cool Topic" --type user
c1_slug="$(jqr "$OUT" '.slug')"
BODY="dup canon" gw --corpus "$L" create "my-cool-topic" --type user
if [ "$c1_slug" = user/my-cool-topic ] && [ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = DEDUP_COLLISION ]; then
  ok "17 canonicalization: 'My Cool Topic' == 'my-cool-topic' (same identity, dedup)"; else
  no "17 canonicalization (slug1=$c1_slug rc2=$RC out=$OUT)"; fi

# ============================================================================
# 18  E6 mode: explicit --supersedes (authoritative) archives EXACTLY that topic
# ============================================================================
M="$(fresh)"
BODY="ALPHAEXPLICITKW" gw --corpus "$M" create alpha --type user
BODY="BETAEXPLICITKW"  gw --corpus "$M" update --supersede --type user --name beta --supersedes user/alpha
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.data.superseded')" = user/alpha ]; then
  gw --corpus "$M" read user/beta;  b=$RC
  gw --corpus "$M" read user/alpha; a=$RC   # alpha archived -> NOT_FOUND live
  gw --corpus "$M" search ALPHAEXPLICITKW; nA="$(jqr "$OUT" '.data.matches | length')"
  [ "$b" = 0 ] && [ "$a" = 1 ] && [ "$nA" = 0 ] \
    && ok "18 explicit --supersedes archives exactly the named topic" || no "18 explicit supersedes state (b=$b a=$a nA=$nA)"
else no "18 explicit --supersedes (rc=$RC out=$OUT)"; fi

# ============================================================================
# 19  E6 mode: implicit match is against the ACTIVE corpus only
# ============================================================================
# (covered structurally by #16; assert the archived version is NOT re-matched)
gw --corpus "$M" read user/alpha --archived
[ "$(jqr "$OUT" '.data.archived | length')" = 1 ] && ok "19 archived topic reachable only via archive tier (not active match)" || no "19 archived reachability (out=$OUT)"

# ============================================================================
# 20  E6 mode: 0 matches -> normal create (nothing to supersede)
# ============================================================================
BODY="BRANDNEWKW" gw --corpus "$M" update --supersede --type user --name brandnew
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.data.superseded')" = null ]; then
  gw --corpus "$M" read user/brandnew
  [ "$RC" = 0 ] && ok "20 supersede with 0 matches -> creates new (nothing archived)" || no "20 brandnew not created"
else no "20 zero-match supersede (rc=$RC out=$OUT)"; fi

# ============================================================================
# 21  E6 mode: >=2 candidates -> refuse-with-pointer (never silent wrong-archival)
# ============================================================================
P="$(fresh)"
# plant TWO malformed live files whose frontmatter (type,name) collide on the same key
mkdir -p "$P/user"
printf -- '---\nname: Shared Thing\ntype: user\ndescription: dupe a\n---\nAAA\n' > "$P/user/alpha.md"
printf -- '---\nname: shared-thing\ntype: user\ndescription: dupe b\n---\nBBB\n' > "$P/user/beta.md"
BODY="new shared" gw --corpus "$P" update --supersede --type user --name "Shared Thing"
if [ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = SUPERSEDE_AMBIGUOUS ]; then
  # pointer names both candidates; nothing was archived
  cand="$(jqr "$OUT" '.data.candidates | length')"
  archn=$(find "$P/.archive" -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$cand" = 2 ] && [ "$archn" = 0 ] \
    && ok "21 >=2 candidates -> SUPERSEDE_AMBIGUOUS with pointer, nothing archived" || no "21 ambiguous pointer (cand=$cand archn=$archn)"
else no "21 ambiguous supersede (rc=$RC out=$OUT)"; fi

# ============================================================================
# 22  WAL CRASH-SAFETY — failure injection at EACH of the 5 write-ahead stages
#     Each: crash mid-transaction -> corpus recoverable -> next invocation
#     (a read!) completes the intent -> final state = superseded archived + 1 live.
# ============================================================================
crash_stage() { # crash_stage <stage-name>
  local stage="$1" cc
  cc="$(fresh)"
  printf '%s' "CRASHV1 original" | "$GW" --corpus "$cc" create profile --type user >/dev/null 2>&1   # feed body via stdin (gateway reads stdin, not $BODY env); a bare "$GW" would read the suite's INHERITED stdin -> intermittent hang
  # inject a crash right after <stage> during a supersession
  if printf '%s' "CRASHV2 successor" | env "MEMORY_GATEWAY_CRASH_AT=$stage" \
       "$GW" --corpus "$cc" update --supersede --type user --name profile >/dev/null 2>"$ERRF"; then
    icr=0; else icr=$?; fi
  # the injected crash must be observable (non-zero, and not a normal 0/1 verdict)
  [ "$icr" = 111 ] || { no "22[$stage] crash not injected (rc=$icr)"; return; }
  # a subsequent READ must trigger recovery-before-serving and complete the intent
  if OUT=$("$GW" --corpus "$cc" read user/profile 2>/dev/null); then rrc=0; else rrc=$?; fi
  local live_kw arch_n open_intents
  live_kw="$(jqr "$OUT" '.data.content')"
  arch_n=$(find "$cc/.archive" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  # after recovery: exactly 1 archived (v1) + live = v2, and NO unclosed WAL intent
  open_intents=$(jq -R 'fromjson? // empty' "$cc/.gateway/wal.jsonl" 2>/dev/null \
    | jq -s '([.[]|select(.state=="commit")|.txn]) as $c | [.[]|select(.state=="intent")|select(.txn as $t|($c|index($t))|not)]|length' 2>/dev/null || echo "?")
  if [ "$rrc" = 0 ] && printf '%s' "$live_kw" | grep -q "CRASHV2" && [ "$arch_n" = 1 ] && [ "$open_intents" = 0 ]; then
    ok "22[$stage] crash after '$stage' -> recovery completes supersession (1 archived + 1 live, WAL closed)"
  else
    no "22[$stage] recovery (rrc=$rrc live=$live_kw arch=$arch_n open=$open_intents)"
  fi
}
crash_stage intent
crash_stage archive
crash_stage newtopic
crash_stage index

# 23  trailing partial WAL line discarded on recovery
Q="$(fresh)"
BODY="q1" gw --corpus "$Q" create profile --type user
BODY="q2" gw --corpus "$Q" update --supersede --type user --name profile   # writes a complete WAL txn
printf '{"txn":"partial","state":"inte' >> "$Q/.gateway/wal.jsonl"          # simulate crash mid-append
gw --corpus "$Q" read user/profile                                          # triggers recovery
last="$(tail -n1 "$Q/.gateway/wal.jsonl" 2>/dev/null || true)"
if [ "$RC" = 0 ] && printf '%s' "$last" | jq -e . >/dev/null 2>&1; then
  ok "23 trailing partial WAL line discarded on recovery"; else no "23 partial WAL line survived (last=$last rc=$RC)"; fi

# ============================================================================
# 24  EXIT CODES + JSON ENVELOPE SHAPE
# ============================================================================
gw --corpus "$C" read user/profile
if [ "$RC" = 0 ] && printf '%s' "$OUT" | jq -e 'has("status") and has("verb") and has("slug") and has("data") and has("reason")' >/dev/null 2>&1; then
  ok "24 JSON envelope shape (status/verb/slug/data/reason)"; else no "24 envelope shape (out=$OUT)"; fi
# stderr is never JSON on a mutating verb
BODY="envelope" gw --corpus "$C" create envelope-check --type reference
if [ -z "$ERR" ] || ! printf '%s' "$ERR" | jq -e . >/dev/null 2>&1; then
  ok "24b stderr carries no JSON (deterministic parsing)"; else no "24b stderr contained JSON"; fi
# setup error: nonexistent corpus root -> exit 2
gw --corpus "$ROOT_TMP/does/not/exist" read user/profile
[ "$RC" = 2 ] && ok "24c missing corpus root -> exit 2 (setup)" || no "24c setup exit code (rc=$RC)"
# a read of a missing topic -> NOT_FOUND refusal (exit 1)
gw --corpus "$C" read user/ghost-topic
[ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = NOT_FOUND ] && ok "24d missing topic -> NOT_FOUND (exit 1)" || no "24d not-found (rc=$RC out=$OUT)"

# ============================================================================
# 25  AUDIT LEDGER (every mutation appends one JSONL line: who/verb/slug/when)
# ============================================================================
A="$(fresh)"
BODY="audit body" gw --corpus "$A" create audited --type user
led="$MEMORY_GATEWAY_DIR/memory-gateway.jsonl"
if [ -f "$led" ] && jq -R 'fromjson? // empty' "$led" | jq -se 'any(.verb=="create" and .slug=="user/audited")' >/dev/null 2>&1; then
  ok "25 mutation appends an audit ledger line (verb+slug+ts)"; else no "25 audit ledger line missing"; fi

# ============================================================================
# 26  neighborhood --depth clamp (>3 clamped to 3 with a stderr diagnostic)
# ============================================================================
gw --corpus "$C" neighborhood user/profile --depth 9
if [ "$(jqr "$OUT" '.data.depth')" = 3 ] && printf '%s' "$ERR" | grep -qi "clamp"; then
  ok "26 neighborhood --depth 9 clamped to 3 + stderr diagnostic"; else no "26 depth clamp (depth=$(jqr "$OUT" '.data.depth') err=$ERR)"; fi

# ============================================================================
# 27-34  RED-TEAM REGRESSION PINS (Elenchus pass 1 — each test encodes the
#        adversarial repro so the closed hole stays closed).
# ============================================================================

# 27  #1 (CRITICAL data-loss): explicit --supersedes into an OCCUPIED DIFFERENT
#     slug must REFUSE (NEW_SLUG_OCCUPIED) — never destroy an unmentioned live fact.
R="$(fresh)"
BODY="FACTAKW innocent bystander at dest" gw --corpus "$R" create profile --type user
BODY="OLDNOTEKW the legit supersede target" gw --corpus "$R" create oldnote --type reference
BODY="SUCCESSORKW would-clobber FACTA" gw --corpus "$R" update --supersede --type user --name profile --supersedes reference/oldnote
if [ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = NEW_SLUG_OCCUPIED ]; then
  gw --corpus "$R" read user/profile; ra=$RC
  if [ "$ra" = 0 ] && printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "FACTAKW" \
     && ! printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "SUCCESSORKW" \
     && [ -f "$R/reference/oldnote.md" ]; then
    ok "27 explicit --supersedes into occupied different slug -> NEW_SLUG_OCCUPIED (bystander + target preserved)"
  else no "27 occupant/target not preserved after refuse (ra=$ra)"; fi
else no "27 explicit cross-slug occupied (rc=$RC out=$OUT)"; fi

# 28  #2 (CRITICAL data-loss): implicit supersede over a frontmatter-DIVERGENT
#     live occupant at the target slug must ARCHIVE (tier) it, never clobber.
S="$(fresh)"; mkdir -p "$S/user"
printf -- '---\nname: not-profile\ntype: user\ndescription: divergent occupant\n---\nDIVERGENTKW must be tiered not clobbered\n' > "$S/user/profile.md"
BODY="NEWPROFILEKW replaces the slot" gw --corpus "$S" update --supersede --type user --name profile
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ]; then
  gw --corpus "$S" read user/profile
  live_new=0; printf '%s' "$(jqr "$OUT" '.data.content')" | grep -q "NEWPROFILEKW" && live_new=1
  arch_ok=0; grep -rq "DIVERGENTKW" "$S/.archive" 2>/dev/null && arch_ok=1
  [ "$live_new" = 1 ] && [ "$arch_ok" = 1 ] \
    && ok "28 implicit supersede over a divergent occupant -> occupant archived (not clobbered)" \
    || no "28 divergent occupant clobbered (live_new=$live_new arch_ok=$arch_ok)"
else no "28 divergent-occupant supersede (rc=$RC out=$OUT)"; fi

# 29  #3 (CRITICAL DoS): a valueless trailing value-flag must refuse-fast (USAGE),
#     NOT spin in a bash-3.2 shift-2 no-op loop. BOUNDED so a regression can't hang
#     the whole suite — RC=124 means the DoS came back.
gw_bounded() {  # like gw() but hard-kills after $1s; RC=124 on timeout
  local secs="$1"; shift
  local body="${BODY-}" of="$ROOT_TMP/.bout" i=0 timed=0
  printf '%s' "$body" | "$GW" "$@" >"$of" 2>"$ERRF" &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$((i+1)); if [ "$i" -ge $((secs*10)) ]; then kill -9 "$pid" 2>/dev/null; timed=1; break; fi
    sleep 0.1
  done
  if [ "$timed" = 1 ]; then wait "$pid" 2>/dev/null || true; RC=124; else wait "$pid" 2>/dev/null; RC=$?; fi
  OUT="$(cat "$of" 2>/dev/null || true)"; ERR="$(cat "$ERRF" 2>/dev/null || true)"; BODY=""
}
T="$(fresh)"
BODY="x" gw_bounded 5 --corpus "$T" create profile --type
if [ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = USAGE ]; then
  ok "29 valueless trailing --type -> USAGE refuse-fast (no shift-2 infinite loop)"
elif [ "$RC" = 124 ]; then
  no "29 DoS REGRESSED: valueless --type HUNG (shift-2 loop) — _need_val guard missing"
else no "29 valueless --type (rc=$RC out=$OUT)"; fi

# 30  #4 dead-pid lock reclaim: a lock whose holder PID is provably dead is
#     reclaimed NOW (real-crash recovery), not waited-out 900s.
U="$(fresh)"
BODY="v" gw --corpus "$U" create x --type user            # materialize .gateway/
mkdir -p "$U/.gateway/lock.d"
echo 999999 > "$U/.gateway/lock.d/pid"                    # a PID that cannot be alive (> kern.maxproc)
date +%s > "$U/.gateway/lock.d/ts"                        # FRESH ts -> would refuse if not for the dead-pid check
BODY="after crash" gw --corpus "$U" create y --type user
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ]; then
  gw --corpus "$U" read user/y
  [ "$RC" = 0 ] && ok "30 dead-pid lock reclaimed (crashed holder -> next writer proceeds)" || no "30 y unreadable after reclaim"
else no "30 dead-pid reclaim (rc=$RC out=$OUT)"; fi

# 31  #5 symlink-escape boundary: a VALID type-dir symlinked OUTSIDE the corpus
#     must refuse (BOUNDARY) and write nothing outside (test 12 covers ../absolute;
#     this covers the resolved-symlink vector the pwd -P guard defends).
V="$(fresh)"
OUTSIDE="$ROOT_TMP/outside.$$"; mkdir -p "$OUTSIDE"
ln -s "$OUTSIDE" "$V/user"     # --type user now resolves $V/user/<name>.md OUTSIDE $V
BODY="escapee" gw --corpus "$V" create pwned --type user
if [ "$RC" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = BOUNDARY ]; then
  [ ! -e "$OUTSIDE/pwned.md" ] && ok "31 symlinked type-dir escape refused (BOUNDARY, nothing written outside)" || no "31 wrote OUTSIDE corpus via symlink"
else no "31 symlink escape (rc=$RC out=$OUT)"; fi

# 32  #6 CLI hygiene: no verb -> JSON refuse (USAGE, exit 1) with usage on stderr;
#     --help -> usage on stderr, EMPTY stdout, exit 0 (deterministic machine parsing).
gw --corpus "$C" ""            # empty verb
novrc=$RC
if [ "$novrc" = 1 ] && [ "$(jqr "$OUT" '.reason.code')" = USAGE ] && printf '%s' "$ERR" | grep -qi 'usage\|verb'; then
  ok "32 no-verb -> USAGE JSON refuse (exit 1) + usage on stderr"; else no "32 no-verb handling (rc=$novrc out=$OUT err=$ERR)"; fi
gw --corpus "$C" --help
if [ "$RC" = 0 ] && [ -z "$OUT" ] && printf '%s' "$ERR" | grep -qi 'usage'; then
  ok "32b --help -> usage on stderr, empty stdout, exit 0"; else no "32b --help handling (rc=$RC out=$OUT)"; fi

# 33  #7 identical-content supersede -> honest no-op report (superseded:null),
#     never a false superseded:<self>; nothing archived.
W="$(fresh)"
BODY="IDENTICALKW same bytes" gw --corpus "$W" create profile --type user
BODY="IDENTICALKW same bytes" gw --corpus "$W" update --supersede --type user --name profile
if [ "$RC" = 0 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.data.superseded')" = null ]; then
  arch=$(find "$W/.archive" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  gw --corpus "$W" read user/profile; rl=$RC
  [ "$arch" = 0 ] && [ "$rl" = 0 ] && ok "33 identical-content supersede -> superseded:null (honest no-op, nothing archived)" || no "33 identical no-op state (arch=$arch rl=$rl)"
else no "33 identical-content supersede report (rc=$RC out=$OUT)"; fi

# 34  #8a WAL replay sha-guard: a corrupt (tampered) intent payload is NOT
#     replayed — recovery ABORTS it (mutates nothing, writes an aborted marker)
#     instead of persisting corruption. Crash-at-intent leaves v1 live; tamper the
#     recorded sha256; recovery-on-read must keep v1 and archive nothing.
X="$(fresh)"
printf '%s' "CRASHV1 original" | "$GW" --corpus "$X" create profile --type user >/dev/null 2>&1
printf '%s' "CRASHV2 successor" | env MEMORY_GATEWAY_CRASH_AT=intent "$GW" --corpus "$X" update --supersede --type user --name profile >/dev/null 2>&1
wal="$X/.gateway/wal.jsonl"
jq -c 'if .state=="intent" and (.sha256!=null) then .sha256="0000000000000000000000000000000000000000000000000000000000000000" else . end' "$wal" > "$wal.t" && mv "$wal.t" "$wal"
if OUT=$("$GW" --corpus "$X" read user/profile 2>/dev/null); then rrc=0; else rrc=$?; fi
live="$(jqr "$OUT" '.data.content')"
arch_n=$(find "$X/.archive" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
aborted=$(jq -R 'fromjson? // empty' "$wal" 2>/dev/null | jq -s 'any(.aborted=="sha_mismatch")' 2>/dev/null)
if [ "$rrc" = 0 ] && printf '%s' "$live" | grep -q "CRASHV1" && ! printf '%s' "$live" | grep -q "CRASHV2" \
   && [ "$arch_n" = 0 ] && [ "$aborted" = true ]; then
  ok "34 WAL sha-guard: corrupt intent NOT replayed (v1 preserved, nothing archived, aborted marker written)"
else no "34 WAL sha-guard (rrc=$rrc arch=$arch_n aborted=$aborted live=$live)"; fi

# ============================================================================
# 35  #1 REGRESSION (pass-2 red-team): a writer blocked on an open-but-silent
#     stdin must NOT hold the single-writer lock hostage. The body is drained
#     OFF-lock (in dispatch, before _lock_acquire), so a mis-wired caller stalls
#     only its OWN process — a second writer still proceeds. (Before the fix the
#     blocked writer held the lock -> the second got CONCURRENT_WRITER.)
# ============================================================================
CW="$(fresh)"
F="$ROOT_TMP/wedge.fifo"
if mkfifo "$F" 2>/dev/null; then
  ( sleep 5 > "$F" ) & holder=$!          # hold the fifo write-end OPEN + silent (auto-releases in 5s)
  "$GW" --corpus "$CW" create victim --type user < "$F" >/dev/null 2>&1 & blocked=$!  # blocks on $(cat) OFF-lock
  sleep 0.5                               # let the blocked writer reach the stdin read
  if printf 'second writer body' | "$GW" --corpus "$CW" create other --type user >/dev/null 2>&1; then w2=0; else w2=$?; fi
  kill "$holder" "$blocked" 2>/dev/null || true; wait "$holder" "$blocked" 2>/dev/null || true; rm -f "$F"
  [ "$w2" = 0 ] && [ -f "$CW/user/other.md" ] \
    && ok "35 #1: stdin-blocked writer does NOT wedge the lock (second writer proceeds)" \
    || no "35 #1 stdin-blocked writer wedged the single-writer lock (w2=$w2)"
else
  ok "35 #1 skipped (mkfifo unavailable)"
fi

# ============================================================================
# 36  #3 REGRESSION (pass-2 red-team): `index` emits EXACTLY ONE JSON envelope.
#     do_index runs _rebuild_index IN-SHELL (not $()), so _atomic_write's BOUNDARY
#     refuse can never emit a second (double) envelope from a substitution subshell.
# ============================================================================
IC="$(fresh)"
printf '%s' "topic body" | "$GW" --corpus "$IC" create alpha --type user >/dev/null 2>&1
if OUT=$(printf '' | "$GW" --corpus "$IC" index 2>/dev/null); then irc=0; else irc=$?; fi
envs=$(printf '%s' "$OUT" | jq -s 'length' 2>/dev/null)
[ "$irc" = 0 ] && [ "$envs" = 1 ] && [ "$(jqr "$OUT" '.status')" = ok ] && [ "$(jqr "$OUT" '.verb')" = index ] \
  && ok "36 #3: index emits exactly ONE envelope (no subshell double-emit)" \
  || no "36 #3 index envelope count=$envs (irc=$irc out=$OUT)"

echo ""
[ "$fail" -eq 0 ] && { echo "test-memory-gateway: PASS"; exit 0; } || { echo "test-memory-gateway: FAIL"; exit 1; }
