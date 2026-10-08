#!/usr/bin/env bash
# Smoke de cobertura estatica (PR #476): o texto do Forge e do Anima ainda
# carrega a orientacao que cada caso de papel organizacional precisa?
# Instrumento fraco, declarado: grep de presenca de termo, nao uso real. Mede
# regressao de cobertura, nao utilidade. Base em origin/main antes do PR: 0/15.
set -uo pipefail
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
F="$R/agents/forge.md"; A="$R/skills/anima"
MISS=0
c(){ local id="$1" desc="$2" file="$3" pat="$4"
  if grep -rqiE -- "$pat" $file 2>/dev/null; then printf '  \033[32mPASS\033[0m %s %s\n' "$id" "$desc"
  else printf '  \033[31mMISS\033[0m %s %s\n' "$id" "$desc"; MISS=$((MISS+1)); fi; }
c FG1 "role spec has decide/out_of_domain fields"           "$F" 'out_of_domain'
c FG2 "knowledge gap -> research, authority gap -> human"    "$F" 'knowledge ≠ authority|knowledge (gap )?(!=|is not) authority'
c FG3 "verdict REUSE+binding for org roles"                 "$F" 'REUSE \+ binding|REUSE\+binding'
c FG4 "latent role"                                         "$F" 'latent role'
c FG5 "verifier independence via reporting line"            "$F" 'reporting line'
c FG6 "lane = queue + policy scope, no head"                "$F" 'lane'
c FG7 "propose != approve for spend; spend cap"             "$F" 'spend'
c FG8 "trait only with falsifiable metric"                  "$F" 'falsifiable'
c FG9 "reject executor+verifier 'cell'"                     "$F" '(^|[^[:alnum:]])cell([^[:alnum:]]|$)'
c FG10 "org-role request -> contract+binding"               "$F" 'organizational role'
c AN1 "route org roles/gates/tiers/edges to an adapter"     "$A/kb/_index.md" 'org-roles'
c AN2 "occupied letter+digit series sweep"                  "$A" 'letter\+digit|letter-plus-digit'
c AN3 "specialty as attribute, not role"                    "$A" 'specialty'
c AN4 "edge/tag names en-US, entity-as-graph"               "$A" 'reports_to|entity-as-graph|entity as a graph'
c AN5 "no soul-name for roles unless verifiable function"   "$A" 'soul-name.*role|roles.*soul-name'
if [ "$MISS" -eq 0 ]; then echo "  Status: PASSED (15/15)"; else echo "  Status: FAILED ($MISS miss)"; fi
exit "$MISS"
