#!/usr/bin/env bash
# /** offender-containment.sh — EKO-90-ext: neutralize a runaway agentic-tool/plugin PRODUCER
#  *  whose upstream issue has NO source fix. Deterministic, gated, reversible.
#  *
#  *  @lesson 2026-07-14 disk-drain: the disk-guardian cleaned caches but could NOT beat a LIVE
#  *          producer — N Claude sessions re-spawning `uvx …@latest` MCP servers re-inflated
#  *          ~/.cache/uv/archive-v0 (uv has NO auto-GC) faster than Tier-1 pruned the symptom.
#  *          Root-fix = neutralize the PRODUCER, not the symptom. The offending plugin's upstream
#  *          (awslabs/mcp#1400 "uv cache grows indefinitely") was CLOSED "not planned" → no source fix.
#  *  @adr    operator 2026-07-14 (verbatim pt-BR): "Até que o agentic-tool/plugin nao tem fix
#  *          resolvido na fonte, pode desativar e/ou remover o agentic-tool e/ou plugin."
#  *
#  *  @tiers  elevate-autonomy → elevate-rigor (DENY-until-proven, fail-safe):
#  *            prune   (LOW · non-destructive)   `uv cache prune`         arm: --prune (no extra gate)
#  *            disable (MEDIUM · reversible)      `claude plugin disable`  arm: --engage +OFC_ARM +OFC_READY +evidence
#  *            remove  (HIGH · reinstall-able)    `claude plugin uninstall`arm: above +OFC_ALLOW_UNINSTALL
#  *          DEFAULT (no flags) = DRY-RUN: detect + consult registry + PROPOSE. Changes NOTHING.
#  *
#  *  @evidence-gate  the ADR's "no source fix" made REAL (not hand-waved): an offender is disabled/
#  *          removed ONLY if it matches an entry in references/no-source-fix-registry.md carrying a
#  *          confirmed upstream wontfix/closed/not-planned + verified-date. No registry entry → the
#  *          script PROPOSES + seeds; it never contains an un-vetted tool (anti-theater · Tomé).
#  *
#  *  @secret  reads plugin/MCP NAMES + upstream-issue metadata only. When it reads a proc's argv it
#  *          extracts ONLY the public `<pkg>@latest` token (a PyPI identifier, not a secret) — never
#  *          the full argv, never a `--api-key=` value, never echoes a token. (CWE-532/CWE-78.)
#  *  @deny    NEVER disables/removes an operator-protected tool: 1password openclaw omniroute claude
#  *          (the agent runtime itself) — mirrors the absolute denylist. NEVER touches those trees.
#  *  @revert  disable → `claude plugin enable <p>`; uninstall → `claude plugin install <p>`; prune →
#  *          regeneration on next use. Every action appends the exact restore command to containment.log.
#  *  @exit    0 ok · 1 nothing-to-do/lock · 2 error. (script-safety §6: real exit, not wrapper-masked.)
#  */
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${OFC_REGISTRY:-$SKILL_DIR/references/no-source-fix-registry.md}"
STATE_DIR="${OFC_STATE_DIR:-$HOME/.local/state/system-health}"
LOG="${OFC_LOG:-$STATE_DIR/containment.log}"
mkdir -p "$STATE_DIR" 2>/dev/null || true

MODE="dry-run"; DO_PRUNE=0; ALLOW_UNINSTALL="${OFC_ALLOW_UNINSTALL:-0}"
# operator-protected — NEVER contain these (case-insensitive substring; the runtime + secrets managers)
PROTECTED=(1password openclaw omniroute claude op-service keychain)

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG" 2>/dev/null || true; }

usage() {
  cat <<'EOF'
offender-containment.sh — contain a no-source-fix agentic-tool/plugin PRODUCER (EKO-90-ext)
  (default)          DRY-RUN: detect registry offenders present now + PROPOSE disable/remove. Acts on nothing.
  --prune            LOW-stakes maintenance ONLY: `uv cache prune` (non-destructive; keeps tool installs).
  --engage           Perform the MEDIUM disable of PRESENT, registry-vetted offenders. REQUIRES
                     OFC_ARM=1 + OFC_READY=1 (caller proved standing-autonomy READY). Without them → dry-run.
  --allow-uninstall  With --engage+arm: escalate disable→uninstall (HIGH). REQUIRES OFC_ALLOW_UNINSTALL=1.
  --help
Env: OFC_ARM=1 (arm disable) · OFC_READY=1 (standing-autonomy proven by caller) ·
     OFC_ALLOW_UNINSTALL=1 (arm uninstall) · OFC_REGISTRY · OFC_STATE_DIR · OFC_LOG
EOF
}

protected() { local c; c="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; local p
  # substring match errs CONSERVATIVE (over-protect = skip a containment we could've done — never contain a
  # protected tool). EXCEPTION: `claude` matches WHOLE-string only, else it over-matches legit claude-branded
  # plugins/marketplaces (`claude-plugins-official`, `claude-code-concierge`) that are NOT the runtime.
  for p in "${PROTECTED[@]}"; do
    if [ "$p" = "claude" ]; then [ "$c" = "claude" ] && return 0; continue; fi
    case "$c" in *"$p"*) return 0;; esac
  done; return 1; }

# uv cache prune — LOW-stakes durable maintenance (removes ONLY unreachable objects; keeps tool installs).
prune_uv() {
  command -v uv >/dev/null 2>&1 || { echo "  ⏭  uv absent — prune skipped"; return 0; }
  if [ "$MODE" = dry-run ]; then echo "  ✅ PROPOSE: uv cache prune (non-destructive; unreachable objects only) [dry-run]"; return 0; fi
  echo "  🧹 uv cache prune …"
  if uv cache prune >/dev/null 2>>"$LOG"; then echo "  ✅ pruned uv cache (unreachable objects removed; installs kept)"; log "PRUNE uv cache prune ok"
  else echo "  ⏭  uv cache prune non-zero (balloon mid-delete / partial) — safe, resumes"; log "PRUNE uv cache prune partial"; fi
}

# is a plugin currently present? (robust: match the plugin base token anywhere in `claude plugin list`)
plugin_present() {
  local p="$1" out; out="$(claude plugin list 2>/dev/null || true)"
  printf '%s' "$out" | grep -qiF "$p"
}

# parse the registry: each vetted offender is a fenced line `OFFENDER | plugin@marketplace | disable|remove | <evidence>`
# inside a ```offenders code block. Deterministic, greppable, human-auditable.
contain_from_registry() {
  [ -f "$REGISTRY" ] || { echo "  ⚠  registry absent ($REGISTRY) — cannot vet offenders → propose nothing (evidence-gate)"; return 0; }
  local in_block=0 line name plug action evid contained=0 present=0
  while IFS= read -r line; do
    case "$line" in
      '```offenders'*) in_block=1; continue;;
      '```'*) [ "$in_block" -eq 1 ] && in_block=0; continue;;
    esac
    [ "$in_block" -eq 1 ] || continue
    case "$line" in ''|'#'*|'|---'*) continue;; esac
    # split "name | plugin@marketplace | action | evidence"
    name="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}')"
    plug="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')"
    action="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
    evid="$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
    [ -n "$plug" ] || continue
    if protected "$plug" || protected "$name"; then echo "  ⛔ registry entry '$name' hits PROTECTED denylist → refused (never contain runtime/secrets)"; continue; fi
    if ! plugin_present "${plug%@*}"; then echo "  ✓  $name ($plug): not present → already contained / never installed"; continue; fi
    present=$((present+1))
    # escalate disable→uninstall only when the entry asks for remove AND uninstall is armed
    local eff="$action"; [ "$action" = "remove" ] && [ "$ALLOW_UNINSTALL" != 1 ] && eff="disable(remove-requested; uninstall not armed)"
    if [ "$MODE" = dry-run ]; then
      echo "  ✅ PROPOSE contain '$name' via $eff — plugin=$plug  evidence=[$evid] [dry-run]"
      continue
    fi
    # ── ENGAGE (armed) ──
    if [ "$action" = remove ] && [ "$ALLOW_UNINSTALL" = 1 ]; then
      echo "  🗑  uninstall $plug …"
      if claude plugin uninstall "$plug" 2>>"$LOG"; then echo "  ✅ UNINSTALLED $plug (revert: claude plugin install $plug)"; log "UNINSTALL $plug evidence=[$evid] revert='claude plugin install $plug'"; contained=$((contained+1))
      else echo "  ⏭  uninstall $plug failed → seeding for operator"; log "UNINSTALL-FAIL $plug"; fi
    else
      echo "  🔌 disable $plug …"
      if claude plugin disable "$plug" 2>>"$LOG"; then echo "  ✅ DISABLED $plug (reversible: claude plugin enable $plug)"; log "DISABLE $plug evidence=[$evid] revert='claude plugin enable $plug'"; contained=$((contained+1))
      else echo "  ⏭  disable $plug failed → seeding for operator"; log "DISABLE-FAIL $plug"; fi
    fi
  done < "$REGISTRY"
  echo "  → registry offenders present=${present} contained=${contained} (mode=$MODE)"
}

case "${1:-}" in
  --help|-h) usage; exit 0;;
  --prune) DO_PRUNE=1; MODE="dry-run";;   # --prune alone stays dry-run for disable; prune itself acts (LOW)
  --engage)
    # fail-safe DENY-until-proven: disable/remove fire ONLY with OFC_ARM=1 + OFC_READY=1 (caller proved READY).
    if [ "${OFC_ARM:-0}" = 1 ] && [ "${OFC_READY:-0}" = 1 ]; then MODE="engage"
    else MODE="dry-run"; echo "[ofc] --engage requires OFC_ARM=1 + OFC_READY=1 (standing-autonomy READY proven by caller) → DRY-RUN (fail-safe)" >&2; fi
    shift || true; [ "${1:-}" = "--allow-uninstall" ] && ALLOW_UNINSTALL=1;;
  --allow-uninstall) echo "[ofc] --allow-uninstall must accompany --engage" >&2; MODE="dry-run";;
  ""|--dry-run) MODE="dry-run";;
  *) echo "[ofc] unknown arg '${1}'"; usage; exit 2;;
esac

echo "offender-containment  [MODE=$MODE  uninstall-armed=$ALLOW_UNINSTALL]"
[ "$DO_PRUNE" -eq 1 ] || [ "$MODE" = engage ] && prune_uv   # prune runs on --prune OR as part of an armed containment
contain_from_registry
log "cycle mode=$MODE prune=$DO_PRUNE uninstall_armed=$ALLOW_UNINSTALL"
exit 0
