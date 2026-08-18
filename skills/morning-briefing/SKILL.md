---
name: morning-briefing
description: >-
  Deterministic SitRep briefing of operator work state (repos/PRs/tasks/memory) for
  fast context restore. Default 7 sections: state, done, in-flight, blockers,
  decisions-awaiting, risks, next-action. Recap mode (--mode=recap): N-Tree objectives,
  % done/PRs/convergence, gaps, pendings, unasked/unanswered Qs, undecided decisions,
  HITL, Eisenhower 2x2, DAG, blockers. Triggers: "morning briefing", "bom dia retomando",
  "where was I", "state recap", "session recap", "end of session recap". Cold-start OK
  (unlike /context-restore). Cross-vendor AAIF.
prompt_version: "1.7.0"
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Codex, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read, Write, Glob, Grep]
cycles_completed: 0
promotion_eligible: false
cycles_evidence:
  - "2026-05-08 morning briefing produced this session validates 7-section structure + memory awareness (v1.0.0)"
  - "2026-05-08 cycle-2 invocation via /morning-briefing slash command discovered MEMORY_DIR detection gotcha + validated 7-section structure works on real backlog state (v1.0.0)"
  - "2026-05-20 v1.0.1 PATCH — empirical probe identified Codex session-name source-of-truth: JSONL type:ai-title .aiTitle (rolling, tail-1) + CLAUDE_CODE_SESSION_ID env var (UUID). Probe latency <100ms validated."
  - "2026-05-20 v1.1.0 MINOR — Phase 3 template UX overhaul (V2 Priority-Triage layout) per operator directive 2026-05-20 + ux-design:ux-optimizer subagent proposal. Above-the-fold Next Action + Pulse callouts. Decision-value ordering. Empty-section omission. Status-icon semantic accents paired with text labels (AAIF accessibility-safe). cycles_completed reset to 0 per dogfooding discipline — 2 fresh cycles required before community promotion."
  - "2026-05-20 v1.2.0 MINOR — i18n support via --lang flag + Hybrid C+D architecture (Bundle YAML for static labels + LLM prompt instruction for dynamic content). MVP bundles pt-br + en-us. 5-step detection cascade (CLI flag → LC_MESSAGES → LANG → AGENTS.md parse → en-us fallback). Empirical probe validated on operator machine: cascade resolves to pt-br via LANG=pt_BR.UTF-8. Bundle keys synced (21 keys), PRESERVE list compliant (git terms identical across bundles). cycles_completed reset to 0 per MINOR bump dogfooding discipline."
  - "2026-05-21 v1.3.0 MINOR — session-recap mode via --mode=recap|briefing flag per operator directive 2026-05-21 (D6 Hybrid C, §16 merge candidates evaluation). Cycle-0 validation: same 5-phase pipeline (probe·synthesize·compute·enumerate·calc-next) executed 2× manually cross-language (en + pt-br) pre-code in PRs your-org/your-user-scope-repo#54+ekson73/multi-agent-os#80+ekson73/multi-agent-os#81 session. Adds 9 recap-mode sections (N-Tree objectives · metrics · gaps · pendings · unasked-Qs · unanswered-Qs · undecided-decisions · HITL · Eisenhower 2×2 · DAG · blocked/blockers). Default=briefing preserves v1.2.0 backward compat. cycles_completed:0 + promotion_eligible:false per ADR-017 R1 MINOR bump dogfooding discipline (2 fresh cycles required)."
  - "2026-05-21 v1.4.0 MINOR — --save [path?] mode-agnostic persistence per operator directive 2026-05-21 /enhance proposal. Triple-touch fired per [C17] §3.2 (operator manually saved 2× recap files cross-language same session). Contrarian scope expansion 4-lens: applies to BOTH briefing + recap (not recap-only). NEW Phase 5 Save flag behavior (4-step default path cascade: explicit → repo .claude/sessions/ per [C05] → AAIF user-scope ~/.{vendor}/docs/{mode}s/ → cwd fallback) + 4 arg forms + saved-file frontmatter spec + 5 safety guards (no-silent-overwrite + path-traversal-reject + symlink-escape-detect + gitleaks-pre-write + PII-sanitize) + atomic write. NEW host detection Phase 0 detect_aiprovider_root() Codex → Cursor → Aider. 2 new operator-flag rows. 3 new anti-patterns (#19 silent overwrite · #20 saving secrets · #21 save-without-mode-context). 10 new edge cases. Cycle-0 evidence: 2× manual saves session 2026-05-21 (~/.claude/docs/session-recaps/2026-05-21-sandwich-namespacing{,-pt-br}.md). Operator HITL Bundle-Now waiver per [C07] v2.1.0 — cycles_completed reset accepted, v1.3.0 cycle-1+2 deferred separately. cycles_completed:0 + promotion_eligible:false."
  - "2026-05-22 v1.5.0 MINOR — REPLACE underspecified --deep flag with Compass-aligned --scope=<verb> family per operator Mente Tomé detection 2026-05-22 + N-Tree multi-dimensional reflection. Operator quote: 'temos N-Tree matrix [foco/presença/prioridade/centro/dentro (here/now), profundidade (deep levels, from here down), amplitude/largura (multi-dimensional same level), altura [higher levels, from here up]'. Maps directly to cowork-process-topology-protocol.md §9 Compass API (5 canonical verbs: inside/down/sideways/up/forward). NEW: 5 verb flags --scope=inside|down|sideways|up|forward + 3 modifier flags --depth N · --height N · --breadth all|N. NEW Phase 0c: SCOPE_VERB resolution function with default=inside. NEW Phase 2.5: per-verb deterministic skip/expansion matrix. NEW Phase 3.5: per-verb section weighting deterministic table (replaces interpretation-dependent --deep). NEW Phase 3b.5: per-verb recap-mode N-Tree projection. NEW backward-compat anchor: --deep migration → --scope=down --depth=2 (closest semantic equivalent; clean replacement, NOT shim). 3 new anti-patterns (#22 verb-confusion · #23 over-deep recursive bloat · #24 single-axis blind-spot). 5 new edge cases (verb absent → inside default · combined verbs · cyclic up-then-down · depth > tree-actual-depth · cross-vendor verb support). CPT sister rule §9 addendum operationalized morning-briefing v1.5.0 as first consumer (rule v1.0.0→v1.1.0 MINOR addendum). Cycle-0 evidence: operator articulated 5-D N-Tree taxonomy in 1 message (signal-strong [C17] §3.5 capture); recursive dogfood: this skill self-applied via /morning-briefing --scope=up --height=2 to generate PR description. §11 Quality Tests 6/6 PASS + §0 BEING > Rules PASS dogfooded. Jira: TRACKER-0000 Ticket-as-Prompt + operator /goal directive auto-merge authorized [high score, green PR, IF converge]. cycles_completed:0 + promotion_eligible:false per ADR-017 R1 MINOR bump (2 fresh cycles required). Sister rule: cowork-process-topology-protocol.md v1.1.0 (Compass API operationalization addendum)."
  - "2026-05-22 v1.5.1 PATCH — RENAME default --scope=inside → --scope=current per operator naming critique 2026-05-22. Operator quote: 'esse termo --scope=inside (default) inside não ficou estranho? current nao seria melhor? analise, critique, valide'. Rationale: 'current' is idiomatic across CLI ecosystem (pwd, kubectl config current-context, git status, gcloud config get current) — decades-consolidated convention; 'inside' was ambiguous against down() which operator directive v2 mapped to pt-br 'pra dentro' (collision risk). Refinement applied during cycle-0 window (PR #60 merge +30min, zero cycle-1 invocations), maximally safe rollback. Backward-compat 100%: --scope=inside still accepted as alias (Phase 0c normalizes inside→current internally before downstream processing). Zero behavior change for legacy callers. Sister rule sync: cowork-process-topology-protocol.md v1.1.0→v1.1.1 (registry lead with current, inside as alias note). PATCH bump per [C07b] (naming refinement, zero behavioral change). cycles_completed preserved (PATCH does NOT reset per ADR-017 R1; only MINOR/MAJOR reset). §11 Quality Tests 6/6 retained PASS + §0 BEING > Rules PASS dogfooded (4-lens audit Tomé/Critical/Devil's-Advocate/Conservative all converged on current). Jira: TRACKER-0000 (same epic, refinement sub-task). Sister memories TODO post-merge: feedback_default_scope_canonical_naming_current.md."
  - "2026-06-07 v1.6.0 MINOR — --clipboard destination-sink flag per operator directive 2026-06-07 /enhance. Adds clipboard as a sink (sibling of --save), copying {continuation-header + rendered briefing/recap} to the system clipboard so operator can /compact then paste-to-resume across the context boundary. Over-engineering analysis (operator-delegated): chose --clipboard boolean + auto-detect (pbcopy→wl-copy→xclip→xsel→clip.exe) OVER --output=[clipboard,pbcopy,...] multi-value (REJECTED: collides with --format, redundant with auto-detect). gitleaks pre-copy guard (clipboard=paste-anywhere surface, ⛔ secrets); graceful stdout-only degradation when no clipboard tool. NEW Phase 6 + detect_clipboard_cmd() Phase 0 helper + 1 flag row + 2 anti-patterns (#25 clipboard-tool-absent theater · #26 clipboard secret-leak) + 6 edge cases. Localized continuation-header (canonical en-us+pt-br; LLM-localizes others; survives --no-llm). Default off = 100% backward-compat. §11 Quality Tests 6/6 PASS + §0 BEING > Rules PASS dogfooded. Repo your-org/your-user-scope-repo. cycles_completed:0 + promotion_eligible:false per ADR-017 R1 MINOR bump."
  - "2026-06-12 v1.7.0 MINOR — Phase 0d dynamic presentation selection per operator directive multi-agent-os#132 item 2 ('atualizar morning-briefing para também seguir o calculo dinamico baseado em [contexto, escopo, propósito, objetivo, risco, segurança, impacto, urgencia, importancia, criticidade, human/agent, etc]'). 4 optional factor flags (--audience human|agent · --purpose cold-start|checkpoint|end-of-session|handoff · --risk low|medium|high · --urgency low|medium|high) → deterministic first-match decision table D1-D6 filling ONLY unset presentation dimensions; P0 explicit-pin precedence (operator flags never overridden). No-information gate imported from scorecard SIZED-gate lesson (absent flag ≠ low/trivial; invalid value = stderr + ignored, never abort). Sister implementation: multi-agent-os bin/scorecard-select-model.sh (shipped v1.12.0, PR #139) — pattern shared, surface distinct. Bare invocation = identical v1.6.0 baseline (backward-compat 100%). cycles_completed:0 per ADR-017 R1 MINOR bump."
i18n:
  default_lang: en-us
  detection_cascade:
    - "--lang <BCP-47> flag"
    - "LC_MESSAGES env"
    - "LANG env (skip LC_ALL — too aggressive)"
    - "AGENTS.md or user-rules.md **Language:** line parse"
    - "fallback: en-us"
  bundle_dir: "translations/"
  bundles_shipped: [en-us, pt-br]
evals:
  should_trigger:
    - "bom dia, retomando aqui, gere um morning briefing"
    - "good morning, give me a state briefing"
    - "where was I — what's pending across my PRs"
    - "context restore: PR/task/blocker recap please"
    - "I just woke up, what's the state of work"
    - "post-compact briefing"
    - "faça um session recap desde o início desta sessão"
    - "session recap — N-Tree objectives + Eisenhower next-tasks"
    - "end of session recap with gaps and HITL pendings"
    - "list objectives [primary/secondary/auxiliary] with % done and PR green status"
    - "copy this briefing to my clipboard so I can compact and continue"
  should_not_trigger:
    - "create a new feature for X"
    - "fix this bug in the auth code"
    - "write me a weekly retro"
    - "save current context to disk"
    - "merge this PR for me"
triggers:
  - morning briefing
  - state of work
  - state recap
  - where was i
  - bom dia retomando
  - what is pending
  - post-compact briefing
  - session recap
  - end of session recap
  - what have we done
  - faça um session recap
  - save this briefing
  - save this recap
  - persist this session state
  - salve este briefing
  - salve este recap
  - copy briefing to clipboard
  - cole o briefing no clipboard
---

# morning-briefing

> Cross-vendor AAIF skill that produces a 7-section structured briefing of operator's current work state. Designed for fast post-sleep / post-break / post-compact context restoration. Deterministic core (cheap, ≤2s, ≤500 tokens) + optional narrative layer.

## Purpose & differentiation

Mature analogues exist but don't fit:
- `/context-restore` requires `/context-save` to have been called first (cold-start fails)
- `/retro` is weekly + retrospective + team-aware (not daily + forward-looking + operator-centric)
- Daily standup template is meeting-format (not solo agent)
- Military SitRep is the closest structural analogue and inspires sections below

This skill answers (dual-mode v1.3.0+):

- **`--mode=briefing` (default)**: *"What is the state of MY work RIGHT NOW, across all artifacts, with the highest-value next action surfaced?"* — forward-looking cold-start.
- **`--mode=recap`**: *"What did we DO this session, against which objectives, with what status/gaps/HITL-pendings, and what are the highest-priority next-tasks ranked by Eisenhower 2×2 + inter-dependencies?"* — backward-looking retrospective + forward-priority. Use at end of substantive work session OR mid-session checkpoint.

**When briefing vs recap?** Briefing = "where was I" (state-of-world). Recap = "what did we accomplish + what's queued" (objective-completion). Both share Phase 0/1/2 probe; diverge at Phase 3 synthesis. Recap mode unlocks 9 additional sections beyond briefing's 7.

## Operator flags

| Flag | Effect |
|---|---|
| (none, default) | Deterministic 7-section briefing + 1-paragraph narrative · language auto-detected via 5-step cascade · `--mode=briefing` (default) |
| `--mode=briefing\|recap` | **NEW v1.3.0** — Output mode selector. `briefing` (default, backward-compat with v1.2.0) = 7-section state recap for **cold-start / post-sleep / post-compact** context restoration (forward-looking). `recap` = end-of-session retrospective producing N-Tree multi-tier objectives (primary/secondary/auxiliary) + tasks/subtasks/steps with status + % done + % PRs green + % agentic convergence + gaps + pendings + unasked-Qs + unanswered-Qs + undecided-decisions + HITL-pendings + Eisenhower 2×2 next-tasks + inter-dependencies DAG + blocked/blockers (backward-looking + forward-priority). Both modes share Phase 0/1/2 probe; diverge at Phase 3 synthesis. |
| `--lang <BCP-47>` | **NEW v1.2.0** — Override language detection. Accepts `pt-br`, `en-us`, `pt`, `en`, `pt_BR.UTF-8` (normalized). Unknown code → fallback `en-us` + stderr diagnostic. Bundle file in `translations/<lang>.yml` MUST exist for full label localization; missing bundle → en-us labels but LLM still attempts to render dynamic content in target language (graceful degradation, pure-D mode). |
| `--quick` | State + Next-action only (~150 tokens; ≤2s) · labels still localized via $LABELS · briefing-mode only (recap-mode ignores --quick, always full) |
| `--scope=current` (default) | **NEW v1.5.1** (canonical; v1.5.0 used `inside`) — Compass `current()` / `inside()` verb. Render here-and-now state (default behavior; no behavior change when omitted). Maps to `cowork-process-topology-protocol.md` §9. Idiomatic CLI convention (parallel to `pwd`, `kubectl config current-context`, `git status`, `gcloud config get current`). |
| `--scope=inside` (alias) | **DEPRECATED-CANONICAL v1.5.1** — Accepted as backward-compat alias for `--scope=current` (zero break for any v1.5.0 caller). Phase 0c normalizes `inside` → `current` internally before downstream processing. Prefer `--scope=current` in new code/docs. |
| `--scope=down` | **NEW v1.5.0** — Compass `children()` / `down()` verb. Drill-down sub-tasks/sub-PRs/sub-decisions. Pair with `--depth N` (default `N=2`, max `N=5` per anti-pattern #23). Replaces deprecated `--deep` semantics with deterministic spec. |
| `--scope=sideways` | **NEW v1.5.0** — Compass `siblings()` verb. Render peers/alternatives at same hierarchical level (worktrees-irmãs, parallel PRs, option matrices A/B/C/D). Pair with `--breadth all\|N` (default `N=5`). |
| `--scope=up` | **NEW v1.5.0** — Compass `parent()` / `root_path()` verb. Render objetivo-pai/contexto-superior. Pair with `--height N` (`N=root` for full ancestry walk; integer for N levels). Useful for PR descriptions self-generated from sub-task context. |
| `--scope=forward` | **NEW v1.5.0** — Compass `next()` verb. Render next N planned steps (FIFO direction). Pair with `--depth N` (default `N=3`). In recap-mode, surfaces Eisenhower Q1+Q2 ranked actions. |
| `--depth N` | **NEW v1.5.0** — Modifier flag for `--scope=down` OR `--scope=forward`. Integer 1-5 (cap per anti-pattern #23). Default depends on verb: down=2, forward=3. |
| `--height N` | **NEW v1.5.0** — Modifier flag for `--scope=up`. Integer OR `root`. Default `1` (immediate parent). `root` walks all the way up via FILO `parent` pointers. |
| `--breadth all\|N` | **NEW v1.5.0** — Modifier flag for `--scope=sideways`. `all` lists all siblings; integer caps at N (default `5`). |
| `--multi-repo` | Scan known sibling repo paths beyond cwd (capability-detected) · localized · works in both modes |
| `--no-llm` | **MODIFIED v1.2.0** — Skip Phase 4 narrative AND skip LLM localization of dynamic content (labels still localized via bundle — degrades to "scope B labels+narrative-omitted" mode) |
| `--format=md\|json\|console` | Output format (default md) |
| `--save [path?]` | **NEW v1.4.0** — Opt-in persistence of rendered output (briefing OR recap) to disk. Mode-agnostic (works with both `--mode=briefing` + `--mode=recap`). Path argument optional; resolved via 4-step cascade (Phase 5): explicit `--save FILE` → repo `.claude/sessions/{YYYY-MM-DD}_{SSID8}_{mode}.md` per `[C05]` → AAIF user-scope `~/.{vendor}/docs/{mode}s/{YYYY-MM-DD}-{cwd-slug}.md` → cwd fallback `./{YYYY-MM-DD}-{mode}-{cwd-slug}.md`. Trailing slash treats arg as directory + auto-filename. Frontmatter prepended to saved file (`name`/`mode`/`created_utc`/`originSessionId`/`cwd`/`repo`/`skill_version`/`lang`). 5 safety guards: no-silent-overwrite · path-traversal-reject · symlink-escape-detect · gitleaks-pre-write scan · PII-sanitize per `language-policy-en-pt.md` PRESERVE rules. Atomic write (`tmp.X → rename`). Default = no-save (backward-compat v1.3.0 preserved 100%). |
| `--save-overwrite` | **NEW v1.4.0** — Modifier flag (use WITH `--save`). Allows overwrite when target file already exists. Without this flag, `--save` aborts with `[--save] target exists: <path>. Use --save-overwrite to replace.` Safety: explicit operator opt-in prevents accidental data loss of prior briefings/recaps. |
| `--clipboard` | **NEW v1.6.0** — Opt-in copy of the rendered output to the system clipboard (sibling of `--save`; a *destination sink*, orthogonal to `--format` *shape*). Mode-agnostic (briefing OR recap). Payload = a localized **continuation-header** + the exact rendered briefing/recap, so after you `/compact` you paste it to resume across the context boundary (post-compact restoration is this skill's reason to exist). Clipboard tool **auto-detected** (`pbcopy`→`wl-copy`→`xclip`→`xsel`→`clip.exe`); none found → on-screen output preserved + stderr diagnostic (never fakes success). `gitleaks` pre-copy scan (clipboard = paste-anywhere surface); abort copy on hit, stdout preserved. `--format=json` copies raw JSON (no prose header). Composable with `--save` (both sinks fire), `--quick`, `--no-llm`, `--mode`. Default = off (100% backward-compat). See Phase 6. **Rejected over-engineering** (operator-delegated call): `--output=[clipboard,pbcopy,…]` multi-value — collides with `--format`, redundant with auto-detect. |
| `--audience human\|agent` | **NEW v1.7.0** — Factor flag (dynamic presentation selection, Phase 0d). Distils the human/agent axis: `agent` → machine register (`--format=json` + narrative omitted) when those dimensions are unset. Default `human` (no behavior change). |
| `--purpose cold-start\|checkpoint\|end-of-session\|handoff` | **NEW v1.7.0** — Factor flag (Phase 0d). Distils contexto·escopo·propósito·objetivo: `end-of-session` → `--mode=recap`; `handoff` → `--mode=recap --scope=forward --depth=3` (+ suggests `--clipboard`); `cold-start` + hollow probe → `--quick`. Fills ONLY unset dimensions (explicit flags always win). |
| `--risk low\|medium\|high` | **NEW v1.7.0** — Factor flag (Phase 0d). Distils risco·segurança·impacto·criticidade: `high` → full briefing (never `--quick`) + Blockers/Risks amplified. Absent flag = NO information (never inferred-low). |
| `--urgency low\|medium\|high` | **NEW v1.7.0** — Factor flag (Phase 0d). Distils urgência·importância: `high` → same effect as `--risk high`. Absent flag = NO information. |

## Phase 0 — Capability detection (one-time)

```bash
PLATFORM="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
HAS_GIT=$(command -v git >/dev/null 2>&1 && echo yes || echo no)
HAS_GH=$(command -v gh >/dev/null 2>&1 && echo yes || echo no)
HAS_JQ=$(command -v jq >/dev/null 2>&1 && echo yes || echo no)
IN_REPO=$(git rev-parse --is-inside-work-tree 2>/dev/null || echo no)
NETWORK_OK=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 https://api.github.com 2>/dev/null | grep -q "^[23]" && echo yes || echo no)
# Memory location detection (Codex convention)
# Derive from current project path: ~/.claude/projects/-<encoded-path>/memory
# where encoded-path replaces / with - in the project's absolute path
if [ "$IN_REPO" = "true" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  ENCODED_PROJECT=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
  MEMORY_DIR="$HOME/.claude/projects/${ENCODED_PROJECT}/memory"
  # Fallback: if exact match not found, search by basename
  if [ ! -d "$MEMORY_DIR" ]; then
    PROJECT_BASENAME=$(basename "$PROJECT_ROOT")
    MEMORY_DIR=$(find "$HOME/.claude/projects" -maxdepth 2 -type d -name "memory" -path "*${PROJECT_BASENAME}*" 2>/dev/null | head -1)
  fi
else
  MEMORY_DIR=""
fi

# Codex session-name detection (Codex; AAIF-portable fallback)
# Source-of-truth (validated empirically 2026-05-20):
#   1) env var CLAUDE_CODE_SESSION_ID (UUID) → JSONL transcript at $MEMORY_DIR/../$UUID.jsonl
#   2) Inside transcript: jq 'select(.type=="ai-title") | .aiTitle' | tail -1  (rolling — last wins)
# Non-Codex hosts: leave empty; graceful-degrade. NEVER fabricate "unknown" string (anti-theater).
CLAUDE_SESSION_NAME=""
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -d "$(dirname "$MEMORY_DIR")" ] && [ "$HAS_JQ" = "yes" ]; then
  SESSION_JSONL="$(dirname "$MEMORY_DIR")/${CLAUDE_CODE_SESSION_ID}.jsonl"
  if [ -f "$SESSION_JSONL" ]; then
    CLAUDE_SESSION_NAME=$(jq -r 'select(.type=="ai-title") | .aiTitle' "$SESSION_JSONL" 2>/dev/null | tail -1)
  fi
fi
# Fallback (no jq): grep + sed extraction
if [ -z "$CLAUDE_SESSION_NAME" ] && [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -d "$(dirname "$MEMORY_DIR" 2>/dev/null)" ]; then
  SESSION_JSONL="$(dirname "$MEMORY_DIR")/${CLAUDE_CODE_SESSION_ID}.jsonl"
  [ -f "$SESSION_JSONL" ] && CLAUDE_SESSION_NAME=$(grep '"type":"ai-title"' "$SESSION_JSONL" 2>/dev/null | tail -1 | sed -n 's/.*"aiTitle":"\([^"]*\)".*/\1/p')
fi
# Truncate if >80 chars (terminal legibility); empty stays empty (omit from header)
if [ ${#CLAUDE_SESSION_NAME} -gt 80 ]; then
  CLAUDE_SESSION_NAME="${CLAUDE_SESSION_NAME:0:77}…"
fi

# ─── i18n: Language detection cascade (v1.2.0+) ─────────────────────────────
# Source-of-truth precedence (first-match wins):
#   1. --lang flag (CLI_LANG env var if invoked via /morning-briefing --lang X)
#   2. LC_MESSAGES env (most specific locale env)
#   3. LANG env (general; SKIP LC_ALL — too aggressive, silences LANG signal)
#   4. AGENTS.md OR user-rules.md "**Language**:" line parse
#   5. Final fallback: en-us (AAIF cross-vendor neutral default)
HAS_YQ=$(command -v yq >/dev/null 2>&1 && echo yes || echo no)
detect_lang_code() {
  local raw
  if [ -n "${CLI_LANG:-}" ]; then raw="$CLI_LANG";
  elif [ -n "${LC_MESSAGES:-}" ] && [ "$LC_MESSAGES" != "C" ]; then raw="$LC_MESSAGES";
  elif [ -n "${LANG:-}" ] && [ "$LANG" != "C" ]; then raw="$LANG";
  else
    # Layer 4: parse operator-declared preference in user-scope rules
    for f in "$HOME/.claude/AGENTS.md" "$HOME/.claude/rules/user-rules.md"; do
      [ -f "$f" ] || continue
      raw=$(grep -E '^\s*-?\s*\*\*Language\*\*:' "$f" 2>/dev/null | head -1 \
        | sed -nE 's/.*\*\*Language\*\*:\s*([a-zA-Z]{2}-[a-zA-Z]{2}).*/\1/p')
      [ -n "$raw" ] && break
    done
  fi
  if [ -z "$raw" ]; then echo "en-us"; return; fi
  # normalize: pt_BR.UTF-8 → pt-br · PT-BR → pt-br · pt_BR → pt-br · pt → pt
  echo "$raw" | sed 's/\..*$//' | tr '_' '-' | tr '[:upper:]' '[:lower:]'
}
LANG_CODE=$(detect_lang_code)

# ─── i18n: Bundle load (Phase 0b) ───────────────────────────────────────────
# Loads translations/<lang>.yml into $LABELS (associative-array-like via temp file).
# Fallback chain: <lang> → en-us → pure-D LLM-only mode (no bundle).
SKILL_DIR="$HOME/.claude/skills/morning-briefing"
LABELS_TMP="$(mktemp -t mb-labels.XXXXXX 2>/dev/null || echo /tmp/mb-labels-$$)"
load_bundle() {
  local lang="$1"
  local bundle="$SKILL_DIR/translations/${lang}.yml"
  if [ ! -f "$bundle" ]; then
    [ "$lang" != "en-us" ] && echo "[i18n] bundle '$lang' absent → fallback en-us" >&2
    bundle="$SKILL_DIR/translations/en-us.yml"
  fi
  if [ ! -f "$bundle" ]; then
    echo "[i18n] no bundles found → pure-D LLM-only mode" >&2
    : > "$LABELS_TMP"  # empty file
    return
  fi
  # Parse YAML → KEY=VALUE for downstream sourcing (yq preferred, awk fallback)
  if [ "$HAS_YQ" = "yes" ]; then
    yq -r 'to_entries | .[] | "\(.key)=\(.value | @sh)"' "$bundle" 2>/dev/null > "$LABELS_TMP"
  else
    # awk fallback: parse flat 'key: "value"' YAML (no nesting supported)
    awk -F': *' '/^[a-z_]+:/ {
      key=$1; val=$2; sub(/^"/, "", val); sub(/"[ \t]*(#.*)?$/, "", val);
      gsub(/'\''/, "'\''\\\\'\'''\''", val);  # shell-escape single quotes
      printf "%s='\''%s'\''\n", key, val
    }' "$bundle" > "$LABELS_TMP"
  fi
}
load_bundle "$LANG_CODE"
# Downstream Phase 3 sources $LABELS_TMP to access: $next_action, $pulse, $blockers, etc.
# Example: . "$LABELS_TMP"; echo "## $blockers · $n"

# ─── Compass scope verb resolution (v1.5.0+) ────────────────────────────────
# Resolves --scope=<verb> [--depth N] [--height N] [--breadth all|N] flags.
# Maps to cowork-process-topology-protocol.md §9 Compass API (5 verbs).
# Replaces deprecated --deep (v1.4.0 and earlier) with deterministic spec.

# Default verb when no --scope flag present: current (here-and-now state, backward-compat with v1.4.0 default)
# v1.5.1 rename: 'current' is the canonical idiomatic-CLI name; 'inside' kept as backward-compat alias.
SCOPE_VERB="${SCOPE_VERB:-current}"

# Normalize backward-compat alias: inside → current (anti-pattern #22 mitigation; preserves v1.5.0 callers)
[ "$SCOPE_VERB" = "inside" ] && SCOPE_VERB="current"

# Validate verb membership (anti-pattern #22 verb-confusion guard)
case "$SCOPE_VERB" in
  current|down|sideways|up|forward) ;;
  *) echo "[--scope] invalid verb '$SCOPE_VERB' → fallback current" >&2
     SCOPE_VERB="current" ;;
esac

# Modifier defaults (per-verb deterministic; documented in operator-flags table)
case "$SCOPE_VERB" in
  down)     SCOPE_DEPTH="${SCOPE_DEPTH:-2}" ;;
  forward)  SCOPE_DEPTH="${SCOPE_DEPTH:-3}" ;;
  up)       SCOPE_HEIGHT="${SCOPE_HEIGHT:-1}" ;;
  sideways) SCOPE_BREADTH="${SCOPE_BREADTH:-5}" ;;
  current)  ;;  # no modifier applicable
esac

# Anti-pattern #23 guard: cap --depth N at 5 (over-deep recursive bloat)
if [ -n "${SCOPE_DEPTH:-}" ] && [ "$SCOPE_DEPTH" -gt 5 ] 2>/dev/null; then
  echo "[--depth] $SCOPE_DEPTH > 5 cap → clamped to 5 (anti-bloat per anti-pattern #23)" >&2
  SCOPE_DEPTH=5
fi

# Anti-pattern #24 mitigation: warn when single-axis only (operator may want multi-axis)
# Not a block — just informational diagnostic for multi-eixo blind-spot awareness
if [ "$SCOPE_VERB" != "current" ]; then
  echo "[--scope] verb=$SCOPE_VERB (single-axis); consider multi-axis if relevant (e.g., up + down for context-with-drill-down)" >&2
fi

# ─── --save flag: host + path detection (v1.4.0+) ───────────────────────────
# Used ONLY when --save flag is set (Phase 5 below). Cheap, runs once.
# Default path cascade (4 steps, first-match wins): see Phase 5 §"Default path resolution".
detect_aiprovider_root() {
  # Priority: Codex first (most common ai-provider), then Cursor, then Aider.
  # Copilot has NO canonical ~/.copilot/ directory (uses VSCode workspace state) → skipped.
  if [ -d "$HOME/.claude" ]; then echo "$HOME/.claude"; return; fi
  if [ -d "$HOME/.cursor" ]; then echo "$HOME/.cursor"; return; fi
  if [ -f "$HOME/.aider.conf.yml" ] || [ -d "$HOME/.aider" ]; then echo "$HOME/.aider"; return; fi
  echo ""  # no host detected → cwd fallback (Phase 5 cascade step 4)
}
AIPROVIDER_ROOT="$(detect_aiprovider_root)"

# Filename slug from cwd basename (sanitized to [A-Za-z0-9_-]+; collapsed dashes)
slugify_cwd() {
  local cwd_base
  cwd_base="$(basename "$(pwd 2>/dev/null)" 2>/dev/null)"
  echo "${cwd_base:-session}" | sed 's/[^A-Za-z0-9_-]/-/g' | sed 's/--*/-/g; s/^-//; s/-$//'
}

# Short session id (first 8 chars of CLAUDE_CODE_SESSION_ID; else placeholder)
# NOUNSET-SAFE: guard against unset env var (set -u / set -euo pipefail) — critical
# because non-Codex hosts (Cursor/Copilot/Aider) reliably have CLAUDE_CODE_SESSION_ID unset.
# A naive `${CLAUDE_CODE_SESSION_ID:0:8}` would crash before the placeholder fallback runs.
SID_RAW="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SID_RAW" ]; then
  SSID8="${SID_RAW:0:8}"
else
  # Cross-vendor / unset-env fallback: timestamp ensures filename uniqueness
  # on repeated saves same day+mode (per Phase 5 §"Collision avoidance").
  SSID8="$(date -u +%H%M%S)x"
fi

# ─── --clipboard flag: clipboard tool detection (v1.6.0+) ───────────────────
# Used ONLY when --clipboard flag is set (Phase 6 below). Cheap, runs once.
# Auto-detect the platform clipboard "copy" command; the operator never names the tool.
# Order: macOS → Wayland → X11(xclip) → X11(xsel) → WSL/Windows. None → "" (stdout-only).
detect_clipboard_cmd() {
  if command -v pbcopy   >/dev/null 2>&1; then echo "pbcopy"; return; fi                     # macOS
  if command -v wl-copy  >/dev/null 2>&1; then echo "wl-copy"; return; fi                    # Linux Wayland
  if command -v xclip    >/dev/null 2>&1; then echo "xclip -selection clipboard"; return; fi # Linux X11
  if command -v xsel     >/dev/null 2>&1; then echo "xsel --clipboard --input"; return; fi   # Linux X11 (alt)
  if command -v clip.exe >/dev/null 2>&1; then echo "clip.exe"; return; fi                   # WSL / Windows
  echo ""  # none found → Phase 6 degrades to stdout-only + stderr diagnostic
}
CLIPBOARD_CMD="$(detect_clipboard_cmd)"
```

Degrade gracefully: skip phases whose dependencies are missing; emit one-line diagnostic per skip.

## Phase 0d — Dynamic presentation selection (v1.7.0+, factor-flag decision table)

> **Sister implementation**: `multi-agent-os` `bin/scorecard-select-model.sh` (shipped v1.12.0, PR #139, issue #132). This phase imports that pattern per operator directive on `multi-agent-os#132` item 2 (verbatim pt-BR per `language-policy-en-pt.md` §3): *"atualizar morning-briefing para também seguir o calculo dinamico baseado em [contexto, escopo, propósito, objetivo, risco, segurança, impacto, urgencia, importancia, criticidade, human/agent, etc]"*. **Pattern shared, surface distinct** (pointer-not-copy per `layer-precedence-policy`): the community script selects scorecard LAYOUT models; this phase selects THIS skill's own presentation dimensions (mode · quick/full · scope · format · narrative).

### Hybrid deterministic/probabilistic split

The **invoking agent (probabilistic)** distils session factors [contexto · escopo · propósito · objetivo · risco · segurança · impacto · urgência · importância · criticidade · human/agent] into the 4 factor flags BEFORE invocation. **This phase (deterministic)** maps flags → presentation profile via first-match rules. From the flag inward, everything is reproducible across LLM runs.

### Precedence — P0 pin > decision table > baseline (mirrors scorecard R0)

**P0 — explicit pin wins per-dimension**: any explicitly-passed presentation flag (`--mode` · `--quick` · `--scope` · `--format` · `--no-llm` · `--save` · `--clipboard`) is NEVER overridden by the decision table. The table fills ONLY the dimensions the operator left unset.

### Decision table (first-match per unset dimension; deterministic)

| # | Condition | Sets (only unset dimensions) | Rationale |
|---|---|---|---|
| D1 | `--audience agent` | `--format=json` + narrative omitted | machine register per `language-policy` §7 (agent-economy) |
| D2 | `--purpose end-of-session` | `--mode=recap` | retrospective intent |
| D3 | `--purpose handoff` | `--mode=recap --scope=forward --depth=3` + suggest `--clipboard` in stderr | continuation seed across session/context boundary |
| D4 | `--risk high` OR `--urgency high` | full briefing (never `--quick`); Blockers + Risks amplified (top-5 each) | high-stakes demands full surface |
| D5 | `--purpose cold-start` AND probe finds <2 substantive items | `--quick` | hollow state → minimal render. Fires ONLY when purpose explicitly given — an ABSENT flag never triggers degradation |
| D6 | (no factor flags) | baseline — unchanged | 100% backward-compat: bare invocation identical to v1.6.0 |

### No-information gate (imported scorecard SIZED-gate lesson)

- An **ABSENT factor flag carries NO information** — it never matches a rule (absent `--risk` ≠ `--risk low`).
- An **INVALID value** (e.g., `--risk banana`) = no information either: emit stderr `[--risk] invalid value 'banana' → ignored` and treat as unset. **Never abort, never guess** (tolerant parse, graceful degradation — same discipline as `scorecard-select-model.sh`).

### Determinism contract

Identical factor flags + identical Phase 1 probe baseline → identical presentation profile across LLM runs. NO interpretation-dependent selection (consistent with Phase 2.5 contract).

## Phase 1 — State probe (deterministic, parallel-safe)

Inventory in parallel where possible:

```bash
# Git state (skip if !IN_REPO)
git branch --show-current
git log --oneline -5
git status --short | head -20
git worktree list

# Open PRs (skip if !HAS_GH or !NETWORK_OK)
# Detect repo origin → parse host/owner/repo → scope queries
ORIGIN=$(git remote get-url origin 2>/dev/null)
gh pr list --state open --json number,title,author,createdAt,mergeable,reviewDecision 2>/dev/null

# Recent commits since 24h ago
git log --since="24 hours ago" --oneline 2>/dev/null

# Worktree-specific staged/uncommitted work
for wt in $(git worktree list --porcelain | grep '^worktree' | cut -d' ' -f2); do
  echo "=== $wt"; (cd "$wt" && git status --short | head -10)
done

# Codex session-name (already captured in Phase 0 as $CLAUDE_SESSION_NAME)
# No additional probe needed here — passes through to Phase 3 synthesis.
# When empty (non-Codex host OR ai-title absent), header silently omits the field.
```

Optional task tool integration (host-specific): if Codex TaskList tool available, surface in_progress + blocked tasks.

## Phase 2 — Memory & cross-session context (skip if `--quick` or no MEMORY_DIR)

```bash
# Read MEMORY.md index (≤200 lines, fast)
test -f "$MEMORY_DIR/MEMORY.md" && head -100 "$MEMORY_DIR/MEMORY.md"

# Surface recent feedback/project entries (last 3 by mtime)
ls -t "$MEMORY_DIR"/*.md 2>/dev/null | head -3
```

Filter for relevance: prefer entries tagged with current branch / repo / recent dates.

## Phase 2.5 — Compass scope projection (v1.5.0+, deterministic per-verb expansion)

> **Activated by `--scope=<verb>` flag (default `current`; v1.5.1 rename from `inside`).** Replaces deprecated `--deep` interpretation-dependent behavior with deterministic spec. Maps Phase 1+2 probe outputs to verb-specific projection BEFORE Phase 3/3b synthesis.

### Per-verb deterministic projection table

| Verb | Phase 1 probe expansion | Phase 2 memory expansion | Section weighting downstream |
|---|---|---|---|
| **`current`** (default) | Current branch · last 5 commits · 24h status (baseline) | MEMORY.md head 100 + 3 most-recent entries | Standard 7-section briefing (no expansion) |
| **`down --depth=N`** | + `git log --oneline HEAD~10..HEAD` per worktree · ` gh pr view <current-PR> --json comments,reviews,statusCheckRollup` · sub-tasks via TaskList (recursive depth=N) | + N most-recent feedback_* entries · cross-link `[[slug]]` resolution depth=N | Amplify **In-flight** + **Risks** sections (cap N items each); cap N=5 hard per anti-pattern #23 |
| **`sideways --breadth=N`** | + sibling worktrees state (peer branches off same parent) · sibling PRs same milestone · peer option matrices A/B/C/D from MEMORY.md | + N most-recent reference_* entries (pattern peers) | Amplify **Decisions awaiting** section + render Compass option matrix; expose alternatives without prescribing |
| **`up --height=N`** | + `git log --first-parent` walk N levels · parent-PR via `gh pr view --json closingIssuesReferences` · ancestor task tree | + N most-recent project_* entries · root_path walk via `[[slug]]` parent pointers | Amplify **State detail** + **Next Action** rationale (provides why-this-task-now context); useful for PR descriptions self-generated from sub-context |
| **`forward --depth=N`** | + open PRs ranked by mergeable + reviewDecision · TaskList in_progress + pending · Eisenhower 2×2 calc from MEMORY.md backlog | + N most-recent attack-plan / roadmap entries · DAG inter-deps from project_* entries | Amplify **Next Action** + **Decisions** sections; render Eisenhower 2×2 Q1+Q2 ranked top-N (recap-mode) |

### Phase 2.5 implementation pattern

```bash
# Verb-conditional probe expansion (post Phase 1+2 baseline)
case "$SCOPE_VERB" in
  current)
    : # no expansion; baseline Phase 1+2 sufficient
    ;;
  down)
    # Drill-down: PR comments, reviews, sub-tasks, recursive cross-links
    [ "$HAS_GH" = "yes" ] && [ -n "$CURRENT_PR" ] && \
      gh pr view "$CURRENT_PR" --json comments,reviews,statusCheckRollup 2>/dev/null
    # Sub-task expansion via TaskList (host-conditional)
    for wt in $(git worktree list --porcelain | grep '^worktree' | cut -d' ' -f2 | head -"$SCOPE_DEPTH"); do
      (cd "$wt" && git log --oneline -10)
    done
    # Memory recursive cross-link walk depth=$SCOPE_DEPTH
    ;;
  sideways)
    # Peer expansion: sibling branches, sibling PRs, parallel option matrices
    git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | head -"$SCOPE_BREADTH"
    [ "$HAS_GH" = "yes" ] && gh pr list --state open --json number,title,headRefName --limit "$SCOPE_BREADTH"
    ;;
  up)
    # Ancestor walk: first-parent log, parent-PR, root-path traversal
    if [ "$SCOPE_HEIGHT" = "root" ]; then
      git log --first-parent --oneline 2>/dev/null | head -20
    else
      git log --first-parent --oneline -n "$SCOPE_HEIGHT" 2>/dev/null
    fi
    # Memory project_* entries for context-up
    ls -t "$MEMORY_DIR"/project_*.md 2>/dev/null | head -"${SCOPE_HEIGHT:-1}"
    ;;
  forward)
    # Forward planning: open PRs ranked + Eisenhower 2x2 calc
    [ "$HAS_GH" = "yes" ] && gh pr list --state open --json number,title,mergeable,reviewDecision --limit "$SCOPE_DEPTH"
    # Memory attack-plan / roadmap entries
    ls -t "$MEMORY_DIR"/project_attack_plan_*.md 2>/dev/null | head -1
    ;;
esac
```

**Determinism contract**: given identical Phase 1+2 baseline + identical verb + identical modifier value, Phase 2.5 output MUST be reproducible across LLM runs. NO interpretation-dependent expansion (corrects v1.4.0 `--deep` ambiguity).

## Phase 3 — Synthesis (V2 Priority-Triage layout + i18n, v1.2.0+)

Default output template (markdown). **Decision-value ordering**: Next-Action + Pulse above-the-fold, then Blockers/Decisions/Risks (empty sections silently omitted), then In-flight/Done/Detail, then optional Narrative footer.

**Static labels** come from `$LABELS` bundle loaded in Phase 0b (`. "$LABELS_TMP"` to source).
**Dynamic content** (Next Action wording, Why-rationale, Narrative) is rendered by the LLM in `$LANG_CODE`.

### Localization instruction (LLM-augmented Phase 3 + Phase 4)

When rendering this template, the LLM MUST follow this instruction:

> **Localize dynamic content** in BCP-47 code `${LANG_CODE}` (resolved via Phase 0a cascade). Specifically translate:
>
> - Next Action imperative one-liner
> - Why-this-first rationale (≤2 lines)
> - Narrative paragraph (Phase 4 footer)
> - Ad-hoc descriptors (blocker contexts, decision options, risk explanations)
> - Weekday names in the date subtitle (Mon/Tue/... → seg/ter/... in pt-br)
>
> **PRESERVE in English** (do NOT translate):
>
> - Git terminology: `Branch`, `commit`, `sha`, `worktree`, `PR`, `push`, `merge`, `fetch`, `rebase`
> - Code identifiers, file paths, branch names, commit SHAs
> - Status icons: ✅ ⏸️ 👥 🛑 ❓ ⚠️ 📅 🌳 🗓️ 🎯 📍 🧵 🚧 🌿 🔴 ⏳ 💬 🌅
> - `--flag` syntax + tool names (gh, git, jq, gitleaks, yq)
> - session-name field VALUE (it's a slug, e.g., `governance-refactor-agents-ssot`)
> - Numeric counts (preserve raw `1234`; no locale-specific thousands separator)
> - ISO 8601 date format (YYYY-MM-DD); only weekday names localized
> - Static section labels — those come from the loaded $LABELS bundle, NOT LLM-generated
>
> If `${LANG_CODE}` corresponds to a language with no shipped bundle, render static labels in en-US (fallback) AND dynamic content in `${LANG_CODE}` (pure-D mode).

### Template (with $LABELS placeholders)

```markdown
# 🌅 Morning Briefing · <repo or "multi-repo">
<date> · <weekday-localized>, <time> <tz><!-- append " · 🧵 \`<CLAUDE_SESSION_NAME>\`" ONLY when non-empty; the literal "Codex session" word comes from $session_label -->

> ## 🎯 $next_action
> **<imperative one-liner localized to $LANG_CODE>**
> *$why_first*: <≤2 lines rationale localized> · *$effort*: <est> · *$deps*: <deps or $none_token>

> ## 📍 $pulse
> **$branch** `<branch-name>` @ `<sha>` (<time-ago-localized>) · **$worktrees** <n> · **$untracked** <n>
> **$done_24h** <n>c · <n>PR · <n>t  ·  **$in_flight** <n>PR · <n>staged · <n>t
> **$blockers** <n> 🔴 · **$decisions** <n> ⏳ · **$risks** <n> ⚠️

---

## 🔴 $blockers · <n>   <!-- ENTIRE section omitted when n=0 -->
- 🛑 **<title>** — <≤1-line context localized> · `<link>`

## ⏳ $decisions · <n>   <!-- omit when n=0 -->
- ❓ **<question localized>** — options: A) <opt> B) <opt> C) <opt> · `<link or session-ref>`

## ⚠️ $risks · <n>   <!-- omit when n=0 -->
- 📅 PR stale >7d: `#NN <title>`
- 🌳 Worktree stale >30d: `<path>`
- 🗓️ Deadline approaching: <item localized> (due <date-iso>)

---

## 🚧 $in_flight · <n_total>
- **PRs** (mine): `#NN <title>` ✅$mergeable · `#NN <title>` ⏸️$checks_pending · `#NN <title>` 👥$review_pending
- **Staged**: <n> commits on `<branch-name>` ready to push
- **Tasks** in_progress: <n>

## ✅ $done · <n_total>
- <n> commits — top: `<sha>` <title>
- <n> PRs merged — `#NN`, `#NN`
- <n> tasks complete — <title>, <title>

## 🌿 $state_detail
- $worktrees: `<path>` · `<path>`
- $untracked: <n> files

---

<!-- Narrative renders ONLY when --no-llm absent AND there's substance; otherwise omit entire block -->
> 💬 **$narrative** — <1-paragraph executive summary localized to $LANG_CODE>
```

**Rendering note**: `$placeholder` tokens in the template above are bash-variable-like references to the bundle keys loaded in Phase 0b. When the LLM renders this template, it substitutes `$next_action` → `"Next Action"` (en-us) or `"Próxima Ação"` (pt-br) per the loaded bundle. The LLM is responsible for the substitution since Phase 3 is LLM-augmented.

### Phase 3.5 — Per-verb section weighting (v1.5.0+, deterministic)

Based on `$SCOPE_VERB` (resolved Phase 0c), the LLM applies the following deterministic section weighting to the template above:

| Verb | Pulse callout | Next Action | Blockers | Decisions | Risks | In-flight | Done | State detail |
|---|---|---|---|---|---|---|---|---|
| **`current`** | full | full | full | full | full | full | full | full |
| **`down --depth=N`** | full | sub-action of current-task | top-N drill-down | sub-decisions only | top-N expanded risks | **amplified** (cap N) | summarized | full |
| **`sideways --breadth=N`** | comparative across siblings | sibling-selection question | parallel-blocker grouping | **amplified** (peer matrix A/B/C/D) | sibling-risk comparison | sibling PR table | sibling done table | siblings list |
| **`up --height=N`** | parent context | "what parent objective needs" | inherited blockers | parent decisions cascading down | parent-scope risks | parent-scope in-flight | parent-scope done | **amplified** (ancestor walk) |
| **`forward --depth=N`** | next-step preview | **amplified** (top-N Eisenhower Q1+Q2) | upcoming blockers projection | upcoming decisions queue | upcoming risks projection | filtered to ready-to-start | recent baseline | minimized |

**Weighting contract**: "amplified" = render full content + cap at modifier-N items. "summarized" = render 1-line summary + count only. "minimized" = render count only. "full" = baseline template behavior.

### Backward-compat anchor mapping (v1.0.x → v1.1.0)

Consumers using `grep` to locate sections should update queries per this mapping. All 7 section *concepts* are retained — only headings and ordering changed.

| v1.0.x heading | v1.1.0 location | Stable grep token |
|---|---|---|
| `## 1. Onde estamos (state)` | `> ## 📍 Pulse` callout + `## 🌿 State detail` | `Pulse` / `State detail` |
| `## 2. Done since last session` | `## ✅ Done (last 24h) · <n>` | `Done` |
| `## 3. In-flight` | `## 🚧 In-flight · <n_total>` | `In-flight` |
| `## 4. Blockers / HITL` | `## 🔴 Blockers / HITL · <n>` | `Blockers` |
| `## 5. Decisions awaiting` | `## ⏳ Decisions awaiting · <n>` | `Decisions` |
| `## 6. Risks / heads-up` | `## ⚠️ Risks / heads-up · <n>` | `Risks` |
| `## 7. Recommended next action` | `> ## 🎯 Next Action` (top callout) | `Next Action` |

**Section-omission rule**: Blockers · Decisions · Risks sections are **entirely omitted** (heading + body) when `<n>=0`. Pulse callout still shows the zero count for transparency, but the empty section block doesn't render. This is the single highest signal/noise win of V2 — briefing shrinks proportionally to actual state complexity.

## Phase 3b — Recap-mode synthesis (`--mode=recap`, v1.3.0+)

> **Activated when `--mode=recap` flag set.** Reuses Phase 0/1/2 probe outputs; replaces Phase 3 template with recap-specific structure. Phase 4 narrative still applies. Both modes are mutually exclusive (single mode per invocation).

### Recap-mode 5-phase pipeline (synthesis-side)

| Phase | Operation |
|---|---|
| **R1 Probe state** | Reuse Phase 0/1/2 outputs (git/gh/memory) + scan session transcript (JSONL ai-title rolling list) for operator quotes via `[C17]` §3.5 signal filter |
| **R2 Synthesize multi-tier objectives** | Decompose into Principais (P1, operator-stated) · Secundários (P2, operator-authorized derivativos) · Auxiliares (P3, process-derived disciplines aplicadas). Each objective gets tasks/subtasks/steps tree |
| **R3 Compute progress** | Per-objective: `% done` (task completion ratio) + `% PRs green` (CI gate status of related PRs via `gh pr view --json statusCheckRollup`) + `% PR agentic convergence` (amazon-q + CodeRabbit + Copilot + Qodo + CI all converged per pr-review-protocol v2.1.0 §4) |
| **R4 Enumerate completeness gaps** | Gaps · Pendings (workflow-state) · Unasked questions (Codex should have asked) · Unanswered questions (operator AskUserQuestion pending) · Undecided decisions (open option matrices A/B/C/D) · HITL pendings (operator approval gates outstanding) |
| **R5 Calculate Eisenhower next-tasks** | 2×2 priority (Q1 Do Now / Q2 Plan-Schedule / Q3 Delegate / Q4 Drop) + inter-dependency DAG + blocked/blockers labeling |

### Recap-mode template (markdown — replaces Phase 3 briefing template when `--mode=recap`)

```markdown
# 📋 $recap_title — <date> · <repo or session-context>
<session-window-start> → <session-window-end> · <duration> · <weekday-localized>, <time> <tz>
<!-- "🧵 \`<CLAUDE_SESSION_NAME>\`" appended when non-empty -->

## 1. $projects_touched
| $project_col | $type_col | $touches_col |
|---|---|---|
| `<repo>` | <type> | <PR/commit refs> |

## 2. $main_purpose
<operator directive verbatim — preserve source language per language-policy>

## 3. $ntree_objectives

### $primary · P1
\`\`\`
🎯 O1. <objective>
  ├─ T1.1. ✅/🟡/🔜 <task>
  │     ├─ S1.1.1. ✅/🔜 <subtask/step>
  │     └─ S1.1.2. ✅/🔜 <subtask/step>
  └─ T1.2. ✅/🔜 <task>
\`\`\`

### $secondary · P2
\`\`\`
🎯 O4. <objective> [status]
\`\`\`

### $auxiliary · P3
\`\`\`
A1. <process discipline aplicado> ✅/🟡
\`\`\`

## 4. $execution_metrics
| Métrica | Valor |
|---|---|
| PRs criados | <n> |
| PRs merged | <n> |
| % PRs Green (CI all-pass) | <n>/<total> = <pct>% |
| % PR Agentic Convergence | <n>/<total> = <pct>% |
| % Plan execution | <n>/<total> = <pct>% |
| % Principais completos | <n>/<total> = <pct>% |
| Wall-clock engagement | <hours>h |
| Worktrees vivos | <n> (target: 0 post-merge) |

## 5. $pr_details
| PR | Repo | Status | Commit | Convergence | HITL path |
|---|---|---|---|---|---|

## 6. $gaps · <n>   <!-- omit when n=0 -->
| # | Gap | Impacto | Resolução proposta |
|---|---|---|---|

## 7. $pendings · <n>   <!-- omit when n=0 -->
- <workflow-state item>

## 8. $unasked_qs · <n>   <!-- omit when n=0 -->
| # | Pergunta | Razão |
|---|---|---|

## 9. $unanswered_qs · <n>   <!-- omit when n=0; default: "Nenhuma formalmente pendente" -->

## 10. $undecided_decisions · <n>   <!-- omit when n=0 -->
| # | Decisão | Opções |
|---|---|---|

## 11. $hitl_pendings · <n>   <!-- omit when n=0 -->
| # | HITL approval needed | Trigger |
|---|---|---|

## 12. $eisenhower
| Quadrante | Urgência × Importância | Tarefas |
|---|---|---|
| **Q1 Do Now** | high × high | <task> |
| **Q2 Plan-Schedule** | low × high | <task> |
| **Q3 Delegate** | high × low | <task> |
| **Q4 Drop** | low × low | (nenhum) |

## 13. $dependencies_dag
\`\`\`
<root-task> ──► <dependent> ──► <terminal>
\`\`\`

## 14. $blocked_blockers
| Task | Status | Blocker |
|---|---|---|

## 15. $handoff_menu
- **A** ⭐ <recommended action>
- **B** <alternative>
- **C** Stop-for-now → fresh session
- **D** Recalcular
- **E** Pause/cancel

## 16. $operator_quotes (verbatim per language-policy + [C17] §3.5)
<numbered list, source language preserved>

<!-- Narrative renders ONLY when --no-llm absent -->
> 💬 **$narrative** — <executive paragraph localized to $LANG_CODE>
```

### Localization (recap-mode)

Same Phase 3 PRESERVE rules apply (git terms · status icons · session-name slugs · numeric counts · ISO 8601 dates). New recap-specific dynamic content:
- N-Tree objective wording → localized
- Task/subtask descriptions → localized
- Gap/pending/undecided rationale → localized
- Eisenhower task descriptions → localized
- Operator quotes → **preserve source language** (do NOT translate; capture verbatim per `language-policy-en-pt.md` §3 + `[C17]` §3.5)

### Section-omission rule (recap-mode)

Sections 6-11 (gaps · pendings · unasked-Qs · unanswered-Qs · undecided · HITL) omit entirely when `<n>=0`. Sections 1-5 + 12-16 always render (structural backbone). This matches briefing-mode's signal/noise discipline.

### Phase 3b.5 — Per-verb N-Tree projection (recap-mode, v1.5.0+, deterministic)

Recap-mode renders the §3 N-Tree objectives + §12 Eisenhower + §13 DAG sections under verb-conditional projection:

| Verb | §3 N-Tree projection | §12 Eisenhower rendering | §13 DAG rendering |
|---|---|---|---|
| **`current`** (default) | All P1/P2/P3 baseline | Full 2×2 (Q1+Q2+Q3+Q4) | Full DAG |
| **`down --depth=N`** | P1 only, expanded to N sub-task levels (T → S → step) | Q1 + Q2 only, top-N each | Sub-DAG rooted at current task, depth=N |
| **`sideways --breadth=N`** | All P-tier objectives at same level (peer-comparison view) | All quadrants, top-N peers each | Peer-edge DAG (siblings + their immediate deps) |
| **`up --height=N`** | P0 root objective + N parent levels (ancestor path) | Q1 ranked by parent-objective impact | Ancestor DAG (root_path FILO walk) |
| **`forward --depth=N`** | P1 only, NEXT N planned tasks (not done/in-progress) | **Q1 + Q2 ONLY** (drop Q3+Q4); top-N each | Forward-DAG (next-N planned, blocked-by chain) |

**Recap-mode verb default**: `current` (full snapshot; v1.5.1 rename from `inside`). Recap-mode explicit consumers often want `forward --depth=3` (next-3 actions) for handoff briefings; `up --height=2` for PR descriptions self-generated from sub-task context.

**Determinism contract** (recap-mode): given identical session-transcript probe + identical verb + identical modifier, §3+§12+§13 outputs MUST be reproducible across LLM runs. Operator quotes (§16) + execution metrics (§4) always render verbatim/calculated (NOT verb-conditional — they are facts, not projections).

### When to use recap vs briefing

| Trigger phrasing | Mode |
|---|---|
| "morning briefing" / "bom dia" / "where was I" / "post-compact briefing" | `briefing` (default) |
| "session recap" / "faça um session recap" / "end of session" / "what have we done" / "list objectives [primary/secondary/auxiliary]" | `recap` |
| Ambiguous ("state recap") | Heuristic: if session has >5 substantive actions logged in ai-title → `recap`; else `briefing` |

## Phase 4 — Narrative polish (optional, LLM-augmented)

When enabled (default unless `--no-llm`): single concise paragraph synthesizing the 7 sections into a readable summary. Skip if token budget tight.

## Phase 5 — Save flag behavior (`--save [path?]`, v1.4.0+)

> **Activated when `--save` flag is set.** Persists rendered output (briefing OR recap, per `--mode`) to disk. Mode-agnostic (works with BOTH `--mode=briefing` + `--mode=recap`). Opt-in; default = no-save (backward-compat v1.3.0 preserved 100%). Runs AFTER Phase 4 narrative polish so saved file matches what operator saw.

### Default path resolution (4-step cascade)

When `--save` is used with NO path argument (OR path argument resolves to a directory with trailing slash), the cascade picks default location:

| Step | Condition | Result path |
|---|---|---|
| **1** | `--save <explicit-file.md>` (absolute or relative) | Use as-is; skip cascade |
| **2** | `IN_REPO=true` (git repo detected via Phase 0) | `<repo-root>/.claude/sessions/{YYYY-MM-DD}_{SSID8}_{mode}.md` per `[C05]` Session Report Standard |
| **3** | `AIPROVIDER_ROOT` non-empty (Codex/Cursor/Aider detected via Phase 0) | `${AIPROVIDER_ROOT}/docs/{mode}s/{YYYY-MM-DD}-{cwd-slug}.md` |
| **4** | Fallback (no repo, no AI provider) | `./{YYYY-MM-DD}-{mode}-{cwd-slug}.md` (cwd) |

Where:
- `{YYYY-MM-DD}` = current UTC date (`date -u +%Y-%m-%d`)
- `{SSID8}` = first 8 chars of `$CLAUDE_CODE_SESSION_ID` when set; **otherwise `<HHMMSS>x` timestamp suffix** (e.g., `210925x`) per Phase 0 nounset-safe fallback. Timestamp guarantees filename uniqueness on non-Codex hosts (Cursor/Copilot/Aider) where the env var is reliably unset — repeated saves same day+mode get distinct filenames without operator needing `--save-overwrite` (per Bug-2 fix v1.4.0).
- `{mode}` = `briefing` OR `recap` (from `--mode` flag)
- `{cwd-slug}` = sanitized `basename "$(pwd)"` (chars `[A-Za-z0-9_-]+`; collapsed dashes)

### Collision avoidance (cross-vendor safety)

| Scenario | SSID8 source | Default-cascade filename uniqueness |
|---|---|---|
| Codex (env set) | first 8 chars of UUID | Session-bound; collision only if same session re-saves same mode same day — operator opts in via `--save-overwrite` |
| Cursor/Copilot/Aider (env unset) | `<HHMMSS>x` timestamp | Time-bound; collision only if 2 saves within same UTC second (negligible) |
| Sandboxed/CI shell | `<HHMMSS>x` timestamp | Same as above; no env-leak risk |

Per Bug-2 Qodo finding 2026-05-21 (PR #56 PDCA iter 1): without timestamp fallback, non-Codex hosts would always produce `{YYYY-MM-DD}_xxxxxxxx_{mode}.md` → 2nd save same day = guaranteed collision + abort. Timestamp suffix preserves the default-cascade UX cross-vendor.

### `--save` argument forms

| Form | Behavior |
|---|---|
| `--save` (no arg) | Run default-path cascade |
| `--save /abs/path.md` | Use absolute path as-is |
| `--save ./rel/path.md` | Use relative-to-cwd path as-is |
| `--save DIR/` (trailing slash) | Treat as directory + auto-generate filename `{YYYY-MM-DD}-{mode}-{cwd-slug}.md` |
| `--save-overwrite` (modifier) | When combined with `--save`, allow overwrite of existing target |

### Saved file frontmatter (forward-traceability)

Every saved file gets YAML frontmatter prepended (atomic with body):

```yaml
---
name: morning-briefing-{mode}-{YYYY-MM-DD}-{cwd-slug}
mode: briefing|recap
created_utc: <ISO 8601 UTC timestamp>
originSessionId: <CLAUDE_CODE_SESSION_ID or empty>
cwd: <absolute pwd at time of save>
repo: <repo-root if IN_REPO else empty>
skill_version: "1.4.0"
lang: <BCP-47 from $LANG_CODE>
narrative_omitted: <true if --no-llm else absent>
---
```

Body = rendered Phase 3 (briefing template) OR Phase 3b (recap template) markdown — identical to what operator saw on stdout.

### Safety guards (mandatory — all 5 ALWAYS applied)

1. **No silent overwrite** — if target file exists AND `--save-overwrite` NOT set → abort with stderr `[--save] target exists: <path>. Use --save-overwrite to replace.` Original output still printed to stdout (no data loss).
2. **Path traversal reject** — if path contains `..` segments OR resolves outside `$HOME`/cwd boundary (after `realpath`/`readlink -f`) → abort with `[--save] path traversal denied: <path>`. Pattern parallel to `script-safety.md` §1 `safe_rm()` boundary-check.
3. **Symlink escape detection** — if target OR its parent is a symlink, resolve real path. Abort if real path: (a) escapes `$HOME` boundary, OR (b) points to OS-sensitive paths (`/etc`, `/usr`, `/sys`, `/proc`, `/dev`).
4. **gitleaks pre-write scan** — if `command -v gitleaks` available, scan rendered content via `gitleaks detect --no-git --source=<tmpfile>` BEFORE final rename. Secrets detected → abort with redacted diagnostic; never persist.
5. **PII sanitize** — apply `language-policy-en-pt.md` PRESERVE rules (operator personal identifiers stay out; role abstractions only). Same rules as briefing-mode stdout rendering; no additional persistence-path leakage allowed (per anti-pattern #20 + `feedback_no_hardcoded_pii_in_shared_repos`).

### Atomic write pattern

```bash
# Pseudo-code (LLM implements per host capability)
TMP="${target}.tmp.$$"
printf '%s' "$content" > "$TMP" || { rm -f "$TMP"; abort "write failed"; }
mv -f -- "$TMP" "$target"  # atomic rename within same filesystem
```

Prevents partial-file corruption on filesystem-full / permission-denied / concurrent-write scenarios. `mv -f` is atomic when source and target on same filesystem.

### Parent directory auto-create

If target's parent directory doesn't exist → `mkdir -p "$(dirname "$target")"` (idempotent, safe). Reject only if `mkdir -p` itself fails (permission OR FS full).

### Failure modes (graceful degradation)

| Failure | Behavior |
|---|---|
| Filesystem full | Abort with `[--save] disk full`; tmp cleanup; stdout output preserved |
| Permission denied on parent | Abort with `[--save] permission denied: <parent>`; suggest alternative (cwd) |
| Parent dir missing | Auto-`mkdir -p`; only abort if creation itself fails |
| Concurrent write same target | Atomic rename wins-or-loses; loser gets retry-or-abort message |
| Bundle YAML missing for `--lang` | Save succeeds; frontmatter `lang:` records requested code; body reflects fallback bundle |
| `--save` + `--format=json` | Save as `.json` (extension auto-switched); frontmatter encoded as top-level `_meta` key (JSON lacks YAML frontmatter) |
| `--save` + `--quick` | Saves the minimal `--quick` output as-is (legitimate combination) |
| `--save` + `--no-llm` | Saves deterministic-only content; frontmatter `narrative_omitted: true` honest |
| `--save` at cold-start (insufficient state) | Emit stderr `[--save] insufficient state for meaningful save; skipping` — anti-pattern #21; skip write |
| `--save` from cross-product session (multi-repo) | Step 3 (AI provider user-scope) wins over Step 2 (no single repo-root applies); honest cross-repo recap |

## Phase 6 — Clipboard flag behavior (`--clipboard`, v1.6.0+)

> **Activated when `--clipboard` flag is set.** Copies the rendered output (briefing OR recap, per `--mode`) to the **system clipboard** — a *destination sink*, sibling of `--save` (disk), orthogonal to `--format` (shape). Opt-in; default = no-copy (100% backward-compat). Runs AFTER Phase 4 narrative polish so the copied payload matches what the operator saw on screen. Composable with `--save` (both sinks fire independently).

### Purpose — the /compact bridge

This skill's reason to exist is **post-compact context restoration**. `--clipboard` closes the loop: it copies a *self-contained resume prompt* so the operator can `/compact` (which wipes context) and then **paste** it into the fresh, amnesic agent — which receives (a) a continuation-header telling it to resume + (b) the state snapshot. The clipboard is the bridge across the `/compact` boundary (per `ai-as-pwd-axiom.md` §1 amnesia premise).

### Payload composition

| `--format` | Clipboard payload |
|---|---|
| `md` (default) / `console` | `<continuation-header>` + `\n\n---\n\n` + `<rendered Phase 3 briefing OR Phase 3b recap>` |
| `json` | raw rendered JSON **only** (no prose header — JSON has no comment syntax; a downstream machine consumer parses it directly) |

The continuation-header is **deterministic canonical text per language** (NOT LLM narrative — so it survives `--no-llm`). Localized to `$LANG_CODE`; canonical reference phrasings:

- **en-us**: `▶ RESUME CONTEXT (paste-to-continue after /compact). The block below is a work-state briefing captured before context was compacted. Re-orient from it, then pick up the **Next Action** — confirming with me before any irreversible or outward-facing action.`
- **pt-br**: `▶ RETOMAR CONTEXTO (cole-para-continuar após /compact). O bloco abaixo é um briefing do estado de trabalho capturado antes da compactação. Reoriente-se por ele e siga a **Próxima Ação** — confirmando comigo antes de qualquer ação irreversível ou externa.`

For a `$LANG_CODE` with no canonical phrasing above, the LLM localizes the en-us reference (consistent with Phase 3 dynamic-content localization). The "confirm before irreversible / outward-facing" clause is mandatory — it inoculates the pasted-into fresh agent against rogue auto-action.

### Clipboard tool resolution (auto-detect — operator never names the tool)

`$CLIPBOARD_CMD` is resolved once in Phase 0 via `detect_clipboard_cmd()`:

| Platform | Command |
|---|---|
| macOS | `pbcopy` |
| Linux (Wayland) | `wl-copy` |
| Linux (X11) | `xclip -selection clipboard` → `xsel --clipboard --input` (fallback) |
| WSL / Windows | `clip.exe` |
| none found | `""` → graceful stdout-only degradation + stderr diagnostic |

### Implementation pattern

```bash
# Phase 6 — clipboard sink (runs after Phase 4; $RENDERED = exact stdout payload)
if [ "${CLIPBOARD:-0}" = "1" ]; then
  if [ -z "$CLIPBOARD_CMD" ]; then
    echo "[--clipboard] no clipboard tool (pbcopy/wl-copy/xclip/xsel/clip.exe) — shown on screen only" >&2
  else
    CLIP_TMP="$(mktemp -t mb-clip.XXXXXX)"
    if [ "$FORMAT" = "json" ]; then
      printf '%s' "$RENDERED" > "$CLIP_TMP"                                  # raw JSON, no prose header
    else
      { printf '%s\n\n---\n\n' "$CONTINUATION_HEADER"; printf '%s' "$RENDERED"; } > "$CLIP_TMP"
    fi
    # gitleaks pre-copy guard (clipboard = paste-anywhere surface; ⛔ secrets ABSOLUTE)
    if command -v gitleaks >/dev/null 2>&1 && ! gitleaks dir "$CLIP_TMP" --no-banner >/dev/null 2>&1; then
      echo "[--clipboard] gitleaks flagged content → copy aborted; on-screen output preserved" >&2
    else
      $CLIPBOARD_CMD < "$CLIP_TMP" \
        && echo "[--clipboard] copied {continuation-header + $MODE} ($(wc -c <"$CLIP_TMP") bytes) via ${CLIPBOARD_CMD%% *}" >&2 \
        || echo "[--clipboard] copy failed (display/agent unavailable?) — on-screen output preserved" >&2
    fi
    rm -f "$CLIP_TMP"
  fi
fi
```

> gitleaks 8.30+ uses `gitleaks dir <path>` (the `detect --source` form is deprecated). **Fail-closed**: any non-zero gitleaks exit aborts the copy (never the stdout). The on-screen briefing is ALWAYS printed regardless of clipboard outcome.

### Safety guards (clipboard-specific — all 3 ALWAYS applied)

1. **gitleaks pre-copy scan** — clipboard is a paste-into-anywhere surface (could land in a shared chat, PR, ticket). Scan the payload before copy; abort the copy (NOT the stdout) on any hit. Same ⛔ ABSOLUTE secrets discipline as `--save` guard #4 (`script-safety.md` §2 + `op-service-account-tokens.md`).
2. **PII inheritance** — the payload is the *same content already rendered to stdout*; it inherits Phase 3 PII rules (role abstractions, no operator personal identifiers) per `language-policy-en-pt.md`. No new persistence path beyond the ephemeral clipboard.
3. **No fabricated success** — if no clipboard tool OR the copy command fails (e.g., headless shell with no display for `wl-copy`/`xclip`), emit an honest stderr diagnostic; NEVER claim "copied" (anti-pattern #25, `anti-theater-grounding-protocol` Layer 5 R3).

> **Deliberately NOT included** (anti-over-engineering): the filesystem guards `--save` needs — path-traversal, symlink-escape, no-silent-overwrite, atomic-write — are **N/A** for an ephemeral, local, single-target clipboard. Adding them would be governance theater on a surface that has none of those threats.

### Failure modes (graceful degradation)

| Failure | Behavior |
|---|---|
| No clipboard tool found | stderr `[--clipboard] no clipboard tool … — shown on screen only`; stdout preserved |
| Headless / no display (`wl-copy`/`xclip` can't open display) | copy command fails → stderr `copy failed … on-screen output preserved`; stdout preserved |
| gitleaks flags a secret | copy aborted; redacted stderr diagnostic; stdout preserved |
| `--clipboard` + `--save` | both sinks fire independently (clipboard copy + disk write) |
| `--clipboard` + `--quick` | copies the minimal `--quick` payload + continuation-header |
| `--clipboard` + `--no-llm` | copies deterministic-only body; continuation-header still prepended (it's canonical text, not LLM narrative) |
| `--clipboard` + `--format=json` | copies raw JSON, no prose header (machine consumer parses directly) |
| `--clipboard` at cold-start (hollow state) | copies the (small) cold-start briefing; honest — operator explicitly asked to copy |

## Output formats

- **md** (default): rendered above
- **json**: machine-readable for chaining (e.g., into auto-orchestrator Phase 1)
- **console**: terse stdout for terminal-direct use

## Anti-patterns / Gotchas

Per Anthropic best practice — these are real issues observed in analogues and competitors:

1. **Status theater** — listing every commit/PR creates noise. Filter to *changed-since-last-briefing* + *high-signal items*. Cap each section to top 5 by default.
2. **Vanity metrics** — "10 PRs in flight" without indicating what's blocked vs. moving is meaningless. Always include status (mergeable/checks/reviewDecision) per item.
3. **Decision-less reports** — a briefing without a *recommended next action* is just data. Section 7 is mandatory.
4. **Author=operator self-approve trap** — when operator authored ALL open PRs, they cannot self-merge meaningfully. Flag in section 4 with "needs external reviewer".
5. **PII leak** — never hardcode named people in briefing output. Use role abstractions (`@your-org/<team>`) or paths. Briefing is potentially shared.
6. **Cross-context memory leak** — if MEMORY_DIR has private feedback notes, do NOT echo verbatim — surface only titles/links.
7. **Stale-state hallucination** — if `gh` is offline, do NOT fabricate PR status. Emit explicit "[network-offline: PR section skipped]".
8. **Recursion** — invoking morning-briefing inside another morning-briefing wastes tokens. Idempotency check: if last briefing produced ≤5min ago, ask before re-running.
9. **Over-extending to multi-repo unbidden** — only scan sibling repos with explicit `--multi-repo` flag (else briefing balloons).
10. **Briefing-on-fresh-clone** — newly cloned repos with no history produce hollow briefings. Detect and emit "Cold-start: no prior session detected — proposing scoping questions instead."
11. **MEMORY_DIR ambiguous detection** — `find ~/.claude/projects | head -1` returns first match, not current-project. Always derive from `git rev-parse --show-toplevel` + path-encoding, with basename-filter fallback. Discovered cycle-2 dogfooding 2026-05-08.
12. **Session-name "unknown" theater** — when `$CLAUDE_SESSION_NAME` is empty (non-Codex host OR ai-title absent), do NOT render `🧵 Codex session: unknown` — silently omit the line. Rendering a literal `unknown` adds noise without information (violates `anti-theater-grounding-protocol` Layer 5 R3 hallucinated + R6 applicable). Discovered cycle-3 design 2026-05-20.
13. **Session-name PII display vs persistence** — `ai-title` may contain operator-set names with PII risk (e.g., `"<operator-handle>-personal-todo"`). Briefing DISPLAYS the value (operator's own terminal) but NEVER persists it to memory entries, exported artifacts, OR `--format=json` consumed by shared pipelines. When rendering `--format=json`, gate session-name behind `--include-session-name` opt-in flag (default off for safety). Discovered cycle-3 design 2026-05-20 per `feedback_no_hardcoded_pii_in_shared_repos`.
14. **Heading-emoji as load-bearing semantics** — every section heading uses an emoji prefix (🔴 ⏳ ⚠️ ✅ 🚧 🌿 🎯 📍 🧵), BUT the text label always carries full meaning. Monochrome terminals + screen readers must render briefing identically usable. NEVER drop the text label and rely on emoji alone. NEVER use color as the only signal differentiator. Per constraint emoji policy + AAIF accessibility. Discovered v1.1.0 design 2026-05-20.
15. **Over-translation of git terminology** — when localizing to a non-English language, the LLM may translate `Branch` → `Galho` (pt-BR) OR `Worktree` → `Arbre de travail` (fr-FR). This is **wrong**: git terms are universally English in dev culture. PRESERVE list in Phase 3 instruction is mandatory. Bundles enforce this by hard-coding identical en-US values for `branch`, `worktrees`, etc. across ALL language YAMLs. If LLM still over-translates dynamic content, accept partial degradation (labels via bundle still correct). Discovered v1.2.0 design 2026-05-20.
16. **Silent unknown-lang fallback** — when `--lang xx-yy` references a non-existent bundle, the load_bundle() function falls back to en-us.yml WITHOUT emitting a diagnostic could silently mislead operator into thinking their language IS supported. ALWAYS emit `[i18n] bundle 'xx-yy' absent → fallback en-us` to stderr (not in briefing body). Document supported languages in `translations/README.md` so operators know what works. Discovered v1.2.0 design 2026-05-20.
17. **Mode confusion / theater** — invoking `--mode=recap` at cold-start (no session history yet) produces a hollow recap (zero objectives, zero PRs, zero gaps). Detect via session-transcript probe: if `< 3` substantive actions logged → degrade to `--mode=briefing` + emit stderr diagnostic `[mode] insufficient session-history for recap → degraded to briefing`. Conversely, invoking `--mode=briefing` at end-of-substantive-session under-utilizes captured state. Heuristic: if session-action-count >5 AND operator phrasing contains "recap" / "what have we done" / "end of session" → recap. Discovered v1.3.0 design 2026-05-21.
18. **Recap pollution from operator-WIP** — recap-mode reads git state including uncommitted operator WIP files. NEVER mistake operator-WIP-on-main as "in-flight task" — it's potentially private work not yet committed. Filter Phase 1 `git status --short` output to exclude WIP unless explicitly part of current session's commits. Cross-link `feedback_pr_housekeeping_protocol`. Discovered v1.3.0 design 2026-05-21.
19. **Silent overwrite on `--save`** — `--save` MUST refuse to overwrite existing files without explicit `--save-overwrite`. Silent overwrite destroys operator's prior recaps/briefings (irreversible data loss). Pattern parallels `[C04]` worktree reversibility-by-design + `safe_rm()` opt-in destruction. Discovered v1.4.0 design 2026-05-21.
20. **Saving secrets to disk** — recap-mode Phase 1 includes git state output which may surface branch names referencing tickets / commit messages mentioning credentials / `.env` filenames. Saved files often get committed by operator (cycle-0 pattern saw 2× operator-authored commits of recap files). Secret in saved file → secret in git history → unrotatable PII leak. ALWAYS run `gitleaks detect --no-git --source=<tmpfile>` PRE-write. Abort + redact on detection. Cross-link `script-safety.md` §4 + `op-service-account-tokens.md` ⛔ ABSOLUTE. Discovered v1.4.0 design 2026-05-21.
21. **Save-without-mode-context** — `--save` at cold-start (no probe data) OR mid-session BEFORE substantive actions → produces hollow saved file (empty objectives, zero PRs, no gaps). Detect via state-probe count: if `<2` substantive items → emit stderr `[--save] insufficient state for meaningful save; skipping` AND skip write. Avoids cluttering disk with empty files. Cross-link gotcha #17 (mode-confusion auto-degrade). Discovered v1.4.0 design 2026-05-21.
22. **Verb confusion / theater** — operator passes ambiguous or invalid `--scope=<verb>` (e.g., `--scope=deeper`, `--scope=more`, `--scope=detail`). NEVER silently interpret as one of the 5 canonical verbs. Phase 0c validates membership: `current|down|sideways|up|forward` only (with `inside` accepted as backward-compat alias normalized to `current`). Invalid → fallback to `current` + stderr diagnostic `[--scope] invalid verb '<x>' → fallback current`. NEVER fabricate "best-guess" mapping (anti-theater per `anti-theater-grounding-protocol` Layer 5 R4 invented). Discovered v1.5.0 design 2026-05-22; canonical verb renamed `inside`→`current` v1.5.1 per operator naming critique 2026-05-22.
23. **Over-deep recursive bloat** — operator passes `--depth N` where `N > 5`. Drill-down beyond 5 levels typically explodes briefing size + saturates token budget + produces noise (5-level deep grandchild context rarely actionable). Phase 0c HARD-CLAMPS `SCOPE_DEPTH=5` when N>5 + emits stderr `[--depth] $N > 5 cap → clamped to 5 (anti-bloat)`. Bound rationale: empirical SDLC tree depth median ≈3 (task→subtask→step); 5 is generous upper bound; beyond is governance theater. Discovered v1.5.0 design 2026-05-22.
24. **Single-axis blind-spot** — operator passes `--scope=down` thinking it's the only relevant axis, missing that `--scope=up` ancestor context OR `--scope=sideways` peer alternatives may be MORE valuable in their situation. Phase 0c emits informational diagnostic `[--scope] verb=$verb (single-axis); consider multi-axis if relevant (e.g., up + down for context-with-drill-down)` — NOT a block (operator may genuinely want single-axis). Empirical: most "drill into PR sub-tasks" requests are actually "what's the parent objective + drill into sub-tasks" → up+down combined. Future `--scope=multi inside,down,up` composition is a roadmap item (a later release). Discovered v1.5.0 design 2026-05-22.
25. **Clipboard-tool-absent theater** — when `--clipboard` is passed but no clipboard tool is found (`$CLIPBOARD_CMD` empty) OR the copy command fails (headless shell, no display), NEVER claim "copied to clipboard". Emit an honest stderr diagnostic (`[--clipboard] no clipboard tool … — shown on screen only` OR `copy failed … on-screen output preserved`) and ALWAYS keep the on-screen output. Fabricating success violates `anti-theater-grounding-protocol` Layer 5 R3 (hallucinated). Discovered v1.6.0 design 2026-06-07.
26. **Clipboard secret-leak** — the clipboard is a paste-into-anywhere surface (shared chat, PR comment, ticket). A secret in the copied payload → secret pasted somewhere shared → unrotatable leak. ALWAYS run `gitleaks dir <tmpfile>` (8.30+ syntax) PRE-copy; abort the copy (NOT the stdout) on any hit. Fail-closed: any non-zero gitleaks exit aborts. Cross-link `script-safety.md` §2 + `op-service-account-tokens.md` ⛔ ABSOLUTE + `--save` guard #4. Discovered v1.6.0 design 2026-06-07.
27. **Factor-flag inference theater** — absent `--risk`/`--urgency`/`--purpose`/`--audience` flags carry NO information; NEVER infer "low risk" or "cold-start" from absence and silently degrade the briefing (no information ≠ trivial — the scorecard SIZED-gate lesson). Invalid values likewise = no information (stderr diagnostic + ignore, never abort). The Phase 0d table fills ONLY dimensions left unset by explicit flags (P0 pin precedence) — overriding an operator-passed `--mode`/`--quick`/`--scope` from a factor flag violates the pin contract. Discovered v1.7.0 design 2026-06-12 (imported from `multi-agent-os` `scorecard-select-model.sh` PDCA findings, PR #139).

## Edge cases

- **No git repo in cwd** → fallback: scan `~/Projects/` for recently-modified repos OR ask scoping question
- **No `gh`** → skip PR section, emit diagnostic
- **No network** → local-state-only briefing
- **Operator on multiple parallel sessions** → snapshot-time-stamped to avoid stale data
- **Memory absent / corrupt** → graceful degradation, suggest running cycle-update
- **Briefing requested at non-morning hour** → name is canonical use case; description allows any-time invocation. No behavior change.
- **Multi-language operator (pt-BR / en-US)** → detect from AGENTS.md / MEMORY.md; default fallback en-US with mixed-language tolerance
- **Codex session-name absent** (older Codex OR fresh session sem ai-title yet) → header silently omits the `🧵 Codex session` line; no `unknown` fallback (anti-theater per gotcha #12)
- **Cross-vendor host (Cursor / Copilot / Aider)** → `CLAUDE_CODE_SESSION_ID` env unset → `$CLAUDE_SESSION_NAME` stays empty → AAIF graceful degradation
- **Session-name with special chars** (unicode, emojis, RTL) → preserved (modern terminals support); jq native UTF-8 handling
- **Session-name >80 chars** → auto-truncated to 77 + `…` in Phase 0; original value never leaves the briefing renderer
- **Session-name vazio string** (`""` literal in JSONL) → treated as absent → silent omit
- **Concurrent parallel sessions** (operator em 2 terminais Codex no mesmo repo) → each session has own `CLAUDE_CODE_SESSION_ID` → briefing uses current-shell's env (no cross-contamination)
- **JSONL corrupt / parse-fail** → silent graceful degradation; emit 1-liner diagnostic to stderr only (not in briefing body)
- **Empty optional sections** (Blockers · Decisions · Risks all zero) → entire section block (heading + body) omitted from output. Pulse callout still shows zero counts for transparency, but empty section blocks don't render. Reduces noise proportionally to state complexity (v1.1.0+ signal/noise win).
- **All-empty briefing** (cold-start / fresh-clone / nothing-in-flight) → render only H1 + subtitle + `🎯 Next Action` (with scoping question instead of imperative action) + `📍 Pulse` (showing zeros). Skip Blockers/Decisions/Risks/In-flight/Done/Detail sections. Cross-references gotcha #10 (briefing-on-fresh-clone).
- **Long branch name (>32 chars)** → may push `📍 Pulse` first line past 80 chars. Phase 1 SHOULD truncate to 32 + `…` (follow-up implementation; v1.1.0 template-only). Acceptable degradation: line wraps in modern terminals.
- **No locale env vars set** (CI / containers / sandboxed shells) → `LANG`, `LC_MESSAGES`, `LC_ALL` all unset → cascade falls through steps 1-3 to step 4 (AGENTS.md parse) → if also absent → step 5 (en-us fallback). AAIF-safe default. No diagnostic emitted (silent success).
- **Bundle YAML absent** (`--lang xx-yy` where `translations/xx-yy.yml` doesn't exist) → `load_bundle()` falls back to en-us.yml + emits stderr diagnostic `[i18n] bundle 'xx-yy' absent → fallback en-us`. Briefing still renders fully; labels in en-us, dynamic content LLM-attempts target language (pure-D mode).
- **LLM ignores localization instruction** → renders Next Action OR Narrative in en-US despite `--lang pt-br`. Acceptable partial degradation: labels still correct (deterministic bundle wins). Future enhancement (out of scope v1.2.0): post-render heuristic check + warn if dynamic-content language ≠ expected.
- **Cascade ambiguity** (operator's Mac with `LANG=pt_BR.UTF-8` AND `LC_ALL=en_US.UTF-8`) → cascade explicitly SKIPS `LC_ALL` (too aggressive — would silence operator-preference LANG signal). `LANG` wins step 3 → resolves to pt-br. This is intentional design, not a bug.
- **Cold-start recap** (`--mode=recap` with empty session history / fresh clone / no JSONL transcript) → degrade to briefing-mode + stderr diagnostic `[mode] insufficient session-history for recap → degraded to briefing` (per anti-pattern #17). Briefing-mode handles cold-start gracefully via existing logic.
- **Mid-session recap** (operator invokes `--mode=recap` while substantive work still in-flight) → produces snapshot recap with `in_progress` status on incomplete tasks. Renders N-Tree showing 🟡 partial-done for in-flight tasks. Valid use case (checkpoint recap before context-compact).
- **End-of-session recap** (operator invokes `--mode=recap` after merge-and-cleanup) → produces "session closure" variant: all tasks ✅ done, 100% PRs green, zero gaps/pendings/HITL, → emits Completion-State Closure per `end-of-action-briefing-protocol.md` §8 (motivational message + minimal handoff).
- **Recap on cross-product session** (operator touched 2+ repos in same session) → §1 projects-touched table lists all; § metrics aggregate across repos; § PR-details groups by repo. No special flag needed (heuristic via Phase 1 multi-repo probe outputs).
- **Operator WIP filter** (uncommitted work on main from prior session) → recap-mode Phase 1 filters M-files NOT touched by this session's commits. Cross-link gotcha #18.
- **`--save` with no AIPROVIDER detected** (Copilot OR sandboxed shell with no `~/.claude/`/`~/.cursor/`/`~/.aider/`) → cascade Step 3 skipped; falls to Step 4 (cwd). Honest degradation; no fabricated host path.
- **`--save` with path traversal attempt** (e.g., `--save ../../etc/recap.md`) → reject before any write; emit `[--save] path traversal denied`. Per safety guard #2.
- **`--save` with symlink in target's parent** → resolve via `realpath`; reject if escapes `$HOME` boundary OR points to OS-sensitive paths (`/etc`, `/usr`, `/sys`, `/proc`, `/dev`). Per safety guard #3.
- **`--save` permission denied** (target parent dir not writable) → abort with `[--save] permission denied`; stdout output preserved (no loss); operator can re-invoke with alternative path.
- **`--save` with frontmatter-schema conflict** (existing file at target has different/older frontmatter schema) → never overwrite without `--save-overwrite`; operator can manually merge OR explicitly request replace.
- **`--save` parent dir missing** → auto-`mkdir -p "$(dirname "$target")"` (idempotent, safe); abort only if `mkdir -p` itself fails.
- **`--save` to `/tmp/` OR other tmpfs** → allowed (operator-controlled tmp dir); operator owns retention policy; no warning emitted.
- **`--save` with non-`.md` extension** (`.txt`, `.org`, `.rst`) → preserve extension as given; render content as markdown body regardless (compatible with most text formats).
- **`--save` AND `--format=json`** → extension auto-switched to `.json`; frontmatter encoded as top-level `_meta` key (JSON has no YAML frontmatter equivalent). Body becomes structured JSON instead of markdown.
- **`--save` after cold-start mode-degrade** (`--mode=recap` requested but degraded to briefing per gotcha #17) → saved file's `mode:` frontmatter field reflects ACTUAL rendered mode (briefing), NOT requested mode (recap). Honest frontmatter.
- **Concurrent `--save` from parallel sessions same target** → atomic rename semantics (`mv -f` within same FS); race winner persists; loser gets retry-or-abort diagnostic. No partial-file corruption.
- **`--save` with gitleaks detection** → abort PRE-rename; tmp file cleaned; emit redacted diagnostic to stderr; stdout output preserved. Per safety guard #4.
- **`--save` from cross-product session** (recap touched 2+ repos) → cascade Step 2 (repo-scope) doesn't unambiguously apply; Step 3 wins (AI provider user-scope `~/.{vendor}/docs/recaps/`). Cross-product saves always land user-scope.
- **`--scope` verb absent** (operator runs `/morning-briefing` with no `--scope=`) → Phase 0c defaults to `current` (v1.5.1 rename from `inside`; preserves v1.4.0 backward-compat behavior). Identical output to pre-v1.5.0 default. No diagnostic emitted (silent success).
- **`--scope=inside` (legacy v1.5.0 caller)** → Phase 0c normalizes to `current` internally before downstream processing. Zero behavior change; no diagnostic emitted. Backward-compat 100% preserved per v1.5.1 rename semantic.
- **Combined verbs not yet supported** (e.g., `--scope=up,down` OR `--scope=multi inside,down,up`) → v1.5.0 supports single-verb only. Phase 0c parses first valid verb OR rejects multi-verb syntax with `[--scope] multi-verb composition not yet supported (v1.5.0); use single verb`. Roadmap: a later release may add `--scope=multi` composition syntax.
- **Cyclic up-then-down request** (operator wants `--scope=up --height=root` then `--scope=down` from root — see entire tree) → not expressible as single invocation in v1.5.0; operator runs 2 separate invocations OR waits for a future multi-verb release. Honest limitation surfaced in diagnostic.
- **`--depth N > tree-actual-depth`** (operator passes `--depth=5` but PR sub-task tree only has 2 levels) → graceful render: traverses available depth, stops at leaves, emits no diagnostic (not an error). Output reflects honest tree state.
- **Cross-vendor verb support** (Cursor / Copilot / Aider hosts) → Phase 0c bash logic is host-agnostic; all 5 verbs supported. Modifier flag parsing is bash standard. AAIF-portable per spec compliance.
- **`--clipboard` with no clipboard tool** (minimal container; no `pbcopy`/`wl-copy`/`xclip`/`xsel`/`clip.exe`) → `$CLIPBOARD_CMD` empty → stderr `[--clipboard] no clipboard tool … — shown on screen only`; on-screen output preserved. Per anti-pattern #25.
- **`--clipboard` on headless Linux** (`wl-copy`/`xclip` present but no display / `$DISPLAY` unset) → copy command fails at runtime → stderr `copy failed … on-screen output preserved`; never a fabricated success. Per anti-pattern #25.
- **`--clipboard` with gitleaks hit** → copy aborted PRE-`$CLIPBOARD_CMD`; redacted stderr diagnostic; stdout output preserved (clipboard NOT populated with the secret). Per anti-pattern #26 + safety guard #1.
- **`--clipboard` + `--format=json`** → raw JSON copied (no prose continuation-header — JSON has no comment syntax; a machine consumer parses it directly).
- **`--clipboard` + `--save`** → both sinks fire independently (clipboard receives continuation-header + body; disk receives frontmatter + body per Phase 5). Legitimate combination.
- **`--clipboard` + `--no-llm`** → deterministic body copied; the continuation-header IS still prepended (it's canonical per-language text, not LLM narrative — the post-compact resume use case needs it regardless of `--no-llm`).
- **Factor flag + explicit presentation flag conflict** (e.g., `--purpose end-of-session --mode=briefing`) → explicit pin wins per P0; the factor flag fills only OTHER unset dimensions; no diagnostic emitted (operator stated both — both are honored on their own dimension).
- **Invalid factor value** (`--risk banana`) → stderr `[--risk] invalid value 'banana' → ignored`; treated as unset; render proceeds normally (tolerant parse per Phase 0d no-information gate — never abort).
- **All factor flags absent** (bare `/morning-briefing`) → D6 baseline; output identical to v1.6.0 behavior (backward-compat contract — Phase 0d is invisible until a factor flag is passed).

## Capability-detected fallbacks (by host)

When this skill runs in a non-Codex host (Cursor / Copilot / Aider):
- TaskList tool absent → skip Phase 1 task surfacing
- Memory dir convention may differ → check `.cursor/memory/`, `aider.chat.history.md`, etc.
- AAIF spec compliance ensures the trigger + body + frontmatter format work cross-vendor

## Promotion-readiness viability matrix (6/6)

| Criterion | Status | Evidence |
|---|---|---|
| Cross-platform | ✅ | universal `uname` / `command -v` / no OS-bundled paths |
| Cross-vendor | ✅ | AAIF spec; tested-via-design Codex; Cursor/Copilot/Aider via fallbacks |
| Non-personal | ✅ | universal sections; no operator-specific names |
| Non-corporate | ✅ | zero proprietary refs; standards citations only (SitRep, Agile, Anthropic) |
| Generically useful | ✅ | any agentic-developer post-break workflow benefits |
| OSS license-compatible | ✅ | zero proprietary deps |

→ Eligible for community promotion to multi-agent-os when ≥2 cross-project cycles validated.

## Cycle-1 evidence (dogfooding)

This skill was invoked 2026-05-08 (the operator wake-up after a PII remediation wave). Real briefing produced followed the 7-section structure successfully and surfaced the 1Password-signer HITL block, 33 staged files in a feature worktree, 7 open PRs in a corporate toolkit repo, and recommended option A (restart signer) as next action. Cycle-1 validated: deterministic core works, memory awareness works, recommendation framing works.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.7.0-port | 2026-08-18 | **Version-sync port user-scope → community repo** (régua v0.2 disposition D1): content = user-scope v1.7.0 exactly, sanitized (host config paths genericized to `~/.claude/*` · tracker/repo refs genericized · zero operator identifiers). Closes the measured repo×user-scope drift (1.0.0 vs 1.7.0). `translations/` dir included (en-us + pt-br bundles). Precedent sanitization pattern: the v1.0.0 promotion. |
| 1.0.0 | 2026-05-08 | Bootstrap — 7-section SitRep-inspired briefing · capability detection · cross-vendor AAIF · MEMORY_DIR detection · 11 anti-patterns · 7 edge cases · 6/6 viability matrix. Validated cycles 1+2. |
| 1.0.1 | 2026-05-20 | **PATCH refinement** — adds Codex session-name field (`🧵 Codex session:` header line) per operator directive 2026-05-20. Source-of-truth: JSONL `type:"ai-title"` `.aiTitle` (rolling, `tail -1`) + `CLAUDE_CODE_SESSION_ID` env var (UUID). Probe latency <100ms empirically validated. Graceful degradation when absent (non-Codex hosts OR no ai-title yet) — silent omit, NO `unknown` literal (anti-theater per gotcha #12). 2 new anti-patterns (#12 session-name theater · #13 PII display vs persistence). 7 new edge cases (absent · cross-vendor · special-chars · >80 chars · empty string · concurrent sessions · JSONL parse-fail). Frontmatter `prompt_version` bump v1.0.0→v1.0.1 per `[C07b]`. **NOTE**: superseded by v1.1.0 in same PR (no v1.0.1 released to main as standalone). |
| 1.1.0 | 2026-05-20 | **MINOR — Phase 3 template UX overhaul (V2 Priority-Triage layout)** per operator directive 2026-05-20 + `ux-design:ux-optimizer` subagent proposal. Above-the-fold `🎯 Next Action` + `📍 Pulse` callouts (5-second cognition rule per dashboard UX research 2025-2026). Decision-value ordering: Blockers→Decisions→Risks BEFORE In-flight→Done→Detail. Empty optional sections silently omitted (signal/noise — briefing shrinks proportionally to actual state complexity). Status-icon semantic accents paired with text labels (AAIF accessibility-safe per anti-pattern #14). Session-name v1.0.1 line integrated into subtitle (no longer competing blockquote). Backward-compat: all section concepts retained, 7-row anchor mapping table documented. Pure markdown (no Unicode box-drawing) — Cursor/Copilot/Aider render identically. 1 new anti-pattern (#14 emoji semantic-load-bearing). 3 new edge cases (empty optional sections · all-empty briefing · long branch >32ch). `cycles_completed: 2 → 0` reset per `feedback_promotion_rule_redesign_harmonization` discipline (MINOR bump requires 2 fresh dogfooding cycles before community promotion). 6/6 §11 Quality Tests PASS + §0 BEING > Rules PASS dogfooded by subagent + parent audit. |
| 1.2.0 | 2026-05-20 | **MINOR — i18n support via `--lang` flag + Hybrid C+D architecture** per operator directive 2026-05-20: *"tornar o morning-briefing mais idiomatic friendly para o idioma do usuário"* + *"podemos também criar um parametro `--<parametro de idiom> <idioma>` para o morning-briefing apresentar em outro idioma"*. Operator architecture choice: *"GO: Hybrid C+D ⭐"* — Bundle YAML for static labels + LLM prompt instruction for dynamic content. **MVP bundles**: pt-br + en-us (21 keys synced, PRESERVE list compliant). **5-step detection cascade**: CLI_LANG flag → LC_MESSAGES env → LANG env (skip LC_ALL — too aggressive) → AGENTS.md / user-rules.md `**Language**:` parse → en-us fallback. **Empirical validation 2026-05-20** on operator's Mac (`LANG=pt_BR.UTF-8`): cascade resolves to pt-br via step 3; yq v4.44.3 available. **NEW**: `translations/` dir (en-us.yml canonical + pt-br.yml MVP + README.md). **3 new functions**: `detect_lang_code()` · `normalize()` · `load_bundle()`. **MODIFIED**: operator flags table (`--lang` new + `--no-llm` extended to degrade dynamic-content localization). **2 new anti-patterns** (#15 over-translation of git terms · #16 silent unknown-lang fallback). **4 new edge cases** (no-locale-env · bundle-absent · LLM-ignores-instruction · cascade-ambiguity). **PRESERVE list**: git terms / status icons / session-name slug / numeric counts / ISO 8601 dates stay en-US in ALL bundles. `cycles_completed: 0` reset per MINOR bump dogfooding discipline (v1.1.0 cycle 2 dogfood still pending separately; v1.2.0 needs its own 2 fresh cycles). Sister rule: `language-policy-en-pt.md` v1.0.0 (PRESERVE rationale). |
| 1.3.0 | 2026-05-21 | **MINOR — `--mode=recap\|briefing` dual-mode** per operator directive 2026-05-21 D6 §16 Hybrid C (signal-strong: recap solicitado 2× mesma sessão; Triple-touch fired per `[C17]` §3.2). Skill agora dual-purpose: `briefing` (default, backward-compat v1.2.0) cold-start state recap · `recap` end-of-session retrospective + forward-priority. **Cycle-0 validation**: same 5-phase pipeline (probe·synthesize·compute·enumerate·calc-next) executed manually 2× cross-language (en + pt-br) pre-code em sessão de Sandwich Namespacing 5-layer pattern (PRs your-org/your-user-scope-repo#54 + ekson73/multi-agent-os#80 + #81 todos merged). **NEW**: §"Phase 3b — Recap-mode synthesis" (R1-R5 pipeline) + §"Recap-mode template" (16 sections: projetos · propósito · N-Tree objetivos P1/P2/P3 · métricas · PR-details · gaps · pendings · unasked-Qs · unanswered-Qs · undecided · HITL · Eisenhower 2×2 · DAG · blocked/blockers · handoff-menu · operator-quotes). **MODIFIED**: Purpose & differentiation (dual-mode explained) · Operator flags table (`--mode` row added) · `triggers` + `evals.should_trigger` (session-recap phrasings added). **2 new anti-patterns** (#17 mode confusion / theater · #18 recap pollution from operator-WIP). **5 new edge cases** (cold-start recap → degrade · mid-session recap · end-of-session closure · cross-product recap · operator-WIP filter). **Sister artifact**: `~/.claude/docs/session-recaps/2026-05-21-sandwich-namespacing{,-pt-br}.md` (cycle-0 manual execution evidence). **Companion deferred**: PR-4 `multi-agent-os/skills/session-recap/SKILL.md` (community-scope, fresh-session per ADR-017 R1). **§11 Quality Tests 6/6 PASS** + **§0 BEING > Rules PASS** dogfooded. `cycles_completed:0` + `promotion_eligible:false` per ADR-017 R1 MINOR bump dogfooding discipline (2 fresh cycles required). Sister memories: `feedback_session_recap_convergence_plan` · `session_recap_2026_05_21_sandwich_namespacing` (TODO-link-refs). |
| 1.4.0 | 2026-05-21 | **MINOR — `--save [path?]` mode-agnostic persistence** per operator directive 2026-05-21 `/enhance` proposal: *"o que acha de adicionar parametro `--save [path+file optional \| default to user-scope ai-provider]` no morning-briefing `--recap/--mode=recap`?"*. Triple-touch fired per `[C17]` §3.2 (operator manually saved 2× recap files cross-language same session — `~/.claude/docs/session-recaps/2026-05-21-sandwich-namespacing{,-pt-br}.md` cycle-0 empirical evidence). **Contrarian scope expansion** via `[C17]` §13 4-lens analysis: applies to BOTH `--mode=briefing` + `--mode=recap` (NOT recap-only — broader utility, same code path, briefing-mode daily users also benefit). **NEW Phase 5** "Save flag behavior" — 4-step default path cascade (explicit → repo `.claude/sessions/{YYYY-MM-DD}_{SSID8}_{mode}.md` per `[C05]` → AAIF user-scope `~/.{vendor}/docs/{mode}s/{YYYY-MM-DD}-{cwd-slug}.md` → cwd fallback) + 4 arg forms (`--save`, `--save PATH`, `--save DIR/`, `--save-overwrite` modifier) + saved-file frontmatter spec (`name`/`mode`/`created_utc`/`originSessionId`/`cwd`/`repo`/`skill_version`/`lang`/`narrative_omitted?`) + 5 safety guards (no-silent-overwrite + path-traversal-reject + symlink-escape-detect + gitleaks-pre-write + PII-sanitize) + atomic write semantics (`tmp.X → mv -f`). **NEW host detection** in Phase 0 (`detect_aiprovider_root()`: Codex → Cursor → Aider; Copilot skipped per absent canonical dir) + `slugify_cwd()` helper + `$SSID8` short-id. **MODIFIED operator flags table** (2 new rows: `--save` + `--save-overwrite`). **MODIFIED triggers** + `evals.should_trigger` (save phrasings added cross-language). **3 new anti-patterns** (#19 silent overwrite · #20 saving secrets to disk · #21 save-without-mode-context). **13 new edge cases** covering `--save` × other-flag combinations + path-traversal + symlink-escape + permission-denied + frontmatter-conflict + parent-dir-missing + tmpfs + non-.md extensions + `--format=json` JSON-mode + mode-degrade frontmatter honesty + concurrent saves + gitleaks abort + cross-product user-scope landing + no-AIPROVIDER fallback. **Cycle-0 validation**: operator manually authored 2× recaps session 2026-05-21 (empirical pre-code evidence — same cycle-0 backing v1.3.0; this v1.4.0 automates that recurring pattern). **Companion v1.3.0 cycle-1+2 dogfood DEFERRED** (separate fresh-session work; this v1.4.0 PR does NOT consume those cycles per Bundle-Now HITL waiver). **§11 Quality Tests 6/6 PASS** + **§0 BEING > Rules PASS** dogfooded (operator's BEING served: HITL conservation via Triple-touch automation). **Operator HITL Bundle-Now waiver** per `[C07]` v2.1.0 — operator explicitly authorized `cycles_completed` reset accepting that ADR-017 R1 strict-discipline path (defer fresh-session) was traded for faster delivery + acknowledged that v1.4.0 starts NEW 2-cycle dogfood countdown from 0. `cycles_completed:0` + `promotion_eligible:false`. Sister artifact: `feedback_morning_briefing_v130_recap_mode_deployed.md` (predecessor cycle-0 evidence). Plan-of-record: `~/.claude/plans/morning-briefing-save-flag.md`. PR `your-org/your-user-scope-repo#TBD`. |
| 1.5.0 | 2026-05-22 | **MINOR — REPLACE underspecified `--deep` flag with Compass-aligned `--scope=<verb>` family** per operator Mente Tomé detection 2026-05-22 + 5-dimensional N-Tree reflection. Operator quote (verbatim pt-BR per `language-policy-en-pt.md` §3, captured per `[C17]` §3.5 signal-strong filter PASS 5/5): *"pensando melhor, precisamos refer esse termo --deep, pois se analisarmos todo expectro de nossos ticket, projetos, branches, sessions, worktrees, PRs, tarefas, steps, etc, temos N-Tree matrix [foco/presença/prioridade/centro/dentro (here/now), profundidade (deep levels, from here down), amplitude/largura (multi-dimensional same level), altura [higher levels, from here up], etc]; me corrija se eu estiver errado;"*. Maps directly to `cowork-process-topology-protocol.md` v1.0.0 §9 Compass API (5 canonical verbs). **REMOVED**: `--deep` flag (interpretation-dependent, subespecificado). **NEW operator flags** (5 verb + 3 modifier rows): `--scope=inside` (default) · `--scope=down --depth N` (1-5, cap per anti-pattern #23) · `--scope=sideways --breadth all\|N` · `--scope=up --height N\|root` · `--scope=forward --depth N`. **NEW Phase 0c**: `SCOPE_VERB` resolution function with default=inside + validation guard (anti-pattern #22) + depth cap (anti-pattern #23) + single-axis informational diagnostic (anti-pattern #24). **NEW Phase 2.5**: per-verb deterministic Phase 1+2 probe expansion table (replaces interpretation-dependent `--deep`). **NEW Phase 3.5**: per-verb section weighting deterministic table (amplified/summarized/minimized/full contract). **NEW Phase 3b.5**: per-verb recap-mode N-Tree + Eisenhower + DAG projection deterministic. **3 new anti-patterns** (#22 verb confusion / theater · #23 over-deep recursive bloat · #24 single-axis blind-spot). **5 new edge cases** (verb absent → inside default · combined verbs not-yet-supported v1.5.0 · cyclic up-then-down request · depth > tree-actual-depth · cross-vendor verb support). **Migration path**: `--deep` → `--scope=down --depth=2` (closest semantic equivalent). Clean replacement, NOT backward-compat shim (per universal principle #11 + ADR-017 R1 + DUED E1 trigger emerged). **Sister rule operationalization**: `cowork-process-topology-protocol.md` v1.0.0 → v1.1.0 MINOR addendum §9.5 "Compass API implementation surface in agentic-tools" — first consumer: morning-briefing v1.5.0. **Cycle-0 evidence**: (a) operator articulated 5-D N-Tree taxonomy in single message 2026-05-22 (signal-strong `[C17]` §3.5 capture); (b) Jira TRACKER-0000 Ticket-as-Prompt created with full DoR + DoD + acceptance criteria; (c) operator `/goal` directive auto-merge authorized [high score + green PR + IF convergence] per `pr-review-protocol.md` v2.1.0 §2.6.1 — first invocation of `--auto-merge` flag in production; (d) recursive dogfood opportunity: future `/morning-briefing --scope=up --height=2` can self-generate PR descriptions from sub-task context. **§11 Quality Tests 6/6 PASS**: Self-Application (5-D taxonomy applied to own creation — `--scope=up` for PR body genesis) · Non-Contradiction (harmonizes with CPT §9 sister rule + universal principle #11) · Survival (applied to itself, advocates Compass-aligned semantics; survives) · Bounded-Responsibility (depth cap=5 · breadth default=5 · time-box ≤30s Phase 0c · sunset on Compass adoption cross-tool ≥3 consumers) · Explicit-Exception (verb-absent fallback · invalid-verb stderr · over-depth clamp · cross-vendor portability) · Utility-Sunset (`[C17]` §6.5 DUED E1-E6 triggers documented; deprecate if CPT API surface internalized by `auto-orchestrator` Phase 0 OR cross-vendor AAIF spec adopts Compass natively). **§0 BEING > Rules PASS**: serves operator BEING (cognitive clarity via taxonomic precision + HITL conservation via deterministic spec replacing interpretation-dependent `--deep`); slavery-risk LOW (operator can override per Escape Clause Universal). **Operator directive**: `/goal` set 2026-05-22 with `/auto-orchestrator --count=1 --goal-aware --auto-merge --auto-merge-reason "TRACKER-0000 implementation: high score + green PR + IF convergence"`. ADR-017 R1: `cycles_completed:0` + `promotion_eligible:false` per MINOR bump (2 fresh cycles required pre-community-promotion). Sister memories TODO post-merge: `feedback_morning_briefing_v150_compass_flags_deployed.md` + `feedback_compass_api_operationalization_cycle1.md`. Jira: TRACKER-0000. PR: `your-org/your-user-scope-repo#TBD`. |
| 1.5.1 | 2026-05-22 | **PATCH — RENAME default verb `inside` → `current`** per operator naming critique 2026-05-22. Operator quote (verbatim pt-BR per `language-policy-en-pt.md` §3, captured per `[C17]` §3.5 signal-strong filter PASS 5/5): *"esse termo `--scope=inside (default)` inside não ficou estranho? current nao seria melhor? analise, critique, valide"*. **Rationale (4-lens audit converged)**: (Tomé/Empirical) `current` is idiomatic CLI convention — decades-consolidated parallel to `pwd`, `kubectl config current-context`, `git status`, `gcloud config get current`, `pip show current`; (Critical) `inside` is ambiguous against `down()` which operator's original v2 directive mapped to pt-br "pra dentro" (collision risk); (Devil's-Advocate steelman for keeping `inside`) WEAK — CPT §9 listed both as synonyms, "pra dentro" preserved metaphor BUT redundancy is eliminable + canonical CLI convention wins; (Conservative) cycle-0 fresh window (PR #60 merged +30min, zero cycle-1 real invocations) = maximally safe refinement window before naming "cements" via empirical use. **Strategy**: `current` becomes canonical default; `inside` accepted as backward-compat alias normalized internally to `current` (zero break for any v1.5.0 caller). **Edits applied (10)**: (1) frontmatter `prompt_version: 1.5.0 → 1.5.1`; (2) cycles_evidence entry appended; (3) flag table row rewrite (`--scope=current` canonical + new `--scope=inside` alias row); (4) Phase 0c bash default `SCOPE_VERB:-inside → SCOPE_VERB:-current` + alias-normalization line `[ "$SCOPE_VERB" = "inside" ] && SCOPE_VERB="current"` + validation list `current\|down\|sideways\|up\|forward` + fallback string `'fallback current'` + modifier-defaults case `current)`; (5) single-axis informational diagnostic guard `!= "current"`; (6) Phase 2.5 activation note `(default current; v1.5.1 rename from inside)`; (7) Phase 2.5 table row `**current** (default)`; (8) Phase 2.5 case statement `current)`; (9) Phase 3.5 table row `**current**`; (10) Phase 3b.5 table row + recap-mode default + anti-pattern #22 wording + 2 edge cases (`--scope verb absent → current` + new `--scope=inside legacy caller → normalized to current`). **CPT sister rule sync**: `cowork-process-topology-protocol.md` v1.1.0 → v1.1.1 PATCH (§9.5 registry row lead with `--scope=current` canonical, `(alias: inside)` annotation; tool version `morning-briefing v1.5.0 → v1.5.1`). **Backward-compat**: 100% preserved — any caller using `--scope=inside` continues working identically (normalized to `current` before downstream processing). **PATCH-not-MINOR rationale** per `[C07b]`: zero behavioral change, naming refinement only (cosmetic-canonical-rename). `cycles_completed` preserved per ADR-017 R1 (only MINOR/MAJOR reset, NOT PATCH). **§11 Quality Tests 6/6 retained PASS** + **§0 BEING > Rules PASS** dogfooded (serves operator's BEING via taxonomic precision + CLI ecosystem alignment; slavery-risk LOW — operator initiated the critique, this PATCH responds). **Operator HITL authorization scope-limited** per `[C07]` v2.1.0: `/goal /auto-orchestrator --scope=current "trabalhe nas tarefas do current scope com auto-merge autorizado para [high score, green PR, convergence]"` (this PR is one of the "current scope" tasks under operator's pre-authorization umbrella). Jira: TRACKER-0000 (same epic, refinement sub-task; no new Jira ticket needed — operator-initiated within-cycle correction). Sister memory TODO post-merge: `feedback_default_scope_canonical_naming_current.md`. PR: `your-org/your-user-scope-repo#TBD`. |
| 1.6.0 | 2026-06-07 | **MINOR — `--clipboard` destination-sink flag** per operator directive 2026-06-07 `/enhance`: *"inclua uma nova opção de output `--clipboard` … irá colar no meu clipboard {<prompt de continuação> + morning-briefing} para eu poder dar compact e depois continuar"*. **Over-engineering analysis (operator-delegated** — *"analise e valide se não é over-eng"*): chose **`--clipboard` boolean + auto-detect** over the proposed `--output=[clipboard,pbcopy,…]` multi-value form — REJECTED the latter because (a) it collides conceptually with the existing `--format=md\|json\|console` flag, (b) exposing the binary (`pbcopy`/`xclip`/…) is redundant with auto-detect. `--clipboard` is the clean **sibling of `--save`** (both destination *sinks*, orthogonal to `--format` *shape*) — DRY reuse of an established pattern. **The /compact bridge**: payload = localized **continuation-header** + the exact rendered briefing/recap → operator `/compact`s then pastes to resume across the context boundary (post-compact restoration is this skill's reason to exist; `ai-as-pwd-axiom.md` §1 amnesia premise). **NEW Phase 6** "Clipboard flag behavior" (payload-composition table · continuation-header canonical en-us+pt-br · auto-detect tool table · implementation pattern · 3 clipboard-specific safety guards · failure-modes table) + **Phase 0 `detect_clipboard_cmd()`** helper (`pbcopy`→`wl-copy`→`xclip`→`xsel`→`clip.exe`) + `$CLIPBOARD_CMD`. **MODIFIED operator-flags table** (1 new `--clipboard` row) + `triggers`/`evals` (clipboard phrasings). **2 new anti-patterns** (#25 clipboard-tool-absent theater · #26 clipboard secret-leak — `gitleaks dir` pre-copy, 8.30+ syntax). **6 new edge cases** (no-tool · headless-no-display · gitleaks-hit · +json · +save · +no-llm). **gitleaks pre-copy guard** (clipboard = paste-anywhere surface, ⛔ ABSOLUTE secrets per `script-safety.md` §2 + `op-service-account-tokens.md`); deliberately OMITS `--save`'s filesystem guards (path-traversal/symlink/overwrite/atomic) as N/A for an ephemeral local clipboard (anti-over-engineering). Stale `v1.6.0`-means-multiverb roadmap refs in anti-pattern #24 + 2 edge cases corrected to "a later release" (v1.6.0 is now clipboard; non-contradiction). Default off = 100% backward-compat. **§11 Quality Tests 6/6 PASS** + **§0 BEING > Rules PASS** dogfooded (serves operator's BEING: the /compact-resume loop conserves context-restoration effort; slavery-risk LOW — operator-initiated, opt-in). Repo: `your-org/your-user-scope-repo` (a renamed user-scope config repo). `cycles_completed:0` + `promotion_eligible:false` per ADR-017 R1 MINOR bump (2 fresh cycles required). PR: `your-org/your-user-scope-repo#TBD`. |
| 1.7.0 | 2026-06-12 | **MINOR — Phase 0d Dynamic Presentation Selection (factor-flag decision table)** per operator directive on `multi-agent-os#132` item 2 (verbatim pt-BR per `language-policy-en-pt.md` §3: *"atualizar morning-briefing para também seguir o calculo dinamico baseado em [contexto, escopo, propósito, objetivo, risco, segurança, impacto, urgencia, importancia, criticidade, human/agent, etc]"*) — item 1 of the same directive (scorecard dynamic selector + Model 8 Briefing Card) shipped in `multi-agent-os` v1.12.0 (PR #139, `bin/scorecard-select-model.sh`). **Imports the pattern, not the script** (pointer-not-copy per `layer-precedence-policy`): same hybrid deterministic/probabilistic split — invoking agent (probabilistic) distils session factors → **4 optional factor flags** (`--audience human\|agent` · `--purpose cold-start\|checkpoint\|end-of-session\|handoff` · `--risk low\|medium\|high` · `--urgency low\|medium\|high`) → **deterministic first-match decision table D1-D6** fills ONLY unset presentation dimensions (mode · quick/full · scope · format · narrative). **P0 pin precedence**: explicit presentation flags NEVER overridden by the table (mirrors scorecard R0 env-pin). **No-information gate** imported from scorecard SIZED-gate PDCA lesson: absent factor flag ≠ low/trivial (never inferred); invalid value = stderr diagnostic + treated-as-unset (tolerant parse, never abort). **D6 default = baseline** → bare invocation identical to v1.6.0 (backward-compat 100%; Phase 0d invisible until a factor flag is passed). **NEW Phase 0d** (sister-implementation pointer · hybrid-split rationale · precedence · D1-D6 table · no-information gate · determinism contract) + **4 new operator-flag rows** + **1 new anti-pattern** (#27 factor-flag inference theater) + **3 new edge cases** (factor+explicit conflict → P0 wins · invalid factor value → ignored · all-absent → D6 baseline). Closes the `multi-agent-os#132` directive (item 1 shipped PR #139 + released v1.12.0; item 2 = this). **§11 Quality Tests 6/6 PASS** + **§0 BEING > Rules PASS** dogfooded (serves operator's BEING: presentation auto-fits context without operator flag-tuning; slavery-risk LOW — all factor flags opt-in, P0 pin always wins). Repo: `your-org/your-user-scope-repo`. `cycles_completed:0` + `promotion_eligible:false` per ADR-017 R1 MINOR bump (2 fresh cycles required). PR: `your-org/your-user-scope-repo#TBD`. |

## Refs (research-driven)

- [Anthropic skills overview](https://platform.Codex.com/docs/en/agents-and-tools/agent-skills/overview) — SKILL.md format, ≤5k word body, progressive disclosure
- [The Complete Guide to Building Skills for Codex](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Codex.pdf) — Anthropic official PDF
- [Anthropic skills repo](https://github.com/anthropics/skills) — canonical examples, template
- [agentskills.io specification](https://agentskills.io/specification) — AAIF cross-vendor spec
- [The Persimmon Group: SITREP Template](https://thepersimmongroup.com/situation-report-sitrep-template/) — military structural analogue
- [Asana: Stand Up Meeting format](https://asana.com/resources/stand-up-meeting) — agile cadence
- [OpenAI Cookbook: Context Engineering with Sessions](https://cookbook.openai.com/examples/agents_sdk/session_memory) — hot/warm/cold tiering
- [Anthropic Codex-progress.txt pattern](https://code.Codex.com/docs/en/how-Codex-works) — session-end state file
- [How I built an AI agent that briefs me like the President](https://medium.com/@unicodeveloper/how-i-built-an-ai-agent-that-briefs-me-like-the-president-every-morning-71ad148f673a) — daily AI briefing case study
