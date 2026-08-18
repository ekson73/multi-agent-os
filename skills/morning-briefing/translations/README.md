# morning-briefing translations

Per-language bundle files for static labels used in Phase 3 V2 Priority-Triage layout (v1.2.0+).

## How it works

The `morning-briefing` skill loads `translations/<lang>.yml` at Phase 0 based on:

1. `--lang <BCP-47>` flag (explicit override)
2. `LC_MESSAGES` env var
3. `LANG` env var (note: `LC_ALL` is intentionally skipped — too aggressive)
4. `~/.claude/AGENTS.md` OR `~/.claude/rules/user-rules.md` `**Language**:` line parse
5. Fallback `en-us.yml`

Static labels come from the bundle (deterministic, QA-gated). Dynamic content
(Next Action wording, Why-rationale, Narrative) is LLM-rendered via Phase 3
prompt instruction in the same target language.

## How to add a new language

1. **Copy** `en-us.yml` (the canonical source-of-truth) to `<your-lang-code>.yml`
   using BCP-47 lowercase with hyphen (e.g., `es-es.yml`, `fr-fr.yml`, `ja-jp.yml`).
2. **Translate** all values. **Preserve** strings marked `# PRESERVE` in
   comments (git terminology must stay English across all bundles).
3. **Submit PR** with both `en-us.yml` (if you added new keys) AND your new
   bundle file in the **same commit**. Bundle drift = anti-pattern.

## Key requirements

- **Flat key-value structure** — no nesting (yq + awk-fallback compatibility).
- **All bundles must have the SAME KEY SET** as `en-us.yml`. Missing keys
  cause fallback to en-us per-key (graceful degradation).
- **PRESERVE strings** (currently `branch`, `worktrees`, `pulse`) keep the en-US
  value in ALL bundles. They appear here for grep-stability, not translation.
- **Encoding**: UTF-8. Special characters (acentos, ç, ñ, kanji, etc.) OK.
- **Quotes**: Double-quote all string values for yq robustness.

## Adding new label keys (skill maintainer task)

When a Phase 3 layout change introduces a new label:

1. Add `new_key: "Default English value"` to `en-us.yml`.
2. Add `new_key: "<translated value>"` to ALL other bundles in same commit.
3. Reference `$LABELS[new_key]` in SKILL.md Phase 3 template.
4. Bump skill MINOR version.

## Available bundles

| Code | File | Maintainer | Status |
|---|---|---|---|
| `en-us` | `en-us.yml` | skill-canonical | ✅ Active (SoT) |
| `pt-br` | `pt-br.yml` | operator-validated | ✅ Active (MVP) |

Community PRs adding new bundles are welcomed. Required review: native speaker
validation + PRESERVE list compliance + bundle key-set sync verification.

## Anti-patterns

- ❌ **Missing keys in a bundle** — causes per-key fallback to en-us (silent partial localization). Add ALL keys.
- ❌ **Translating PRESERVE strings** — "Branch" stays "Branch" in pt-br.yml, not "Galho". Git terms are universal.
- ❌ **Adding nested YAML structures** — breaks awk fallback. Keep flat.
- ❌ **Not syncing en-us.yml when adding new keys** — canonical bundle is the gate.
- ❌ **Locale-specific number formats** — `1234` stays `1234`. No `1.234` (de-DE) or `1,234` (en-US thousands). Numbers are universal.

## Refs

- `~/.claude/skills/morning-briefing/SKILL.md` v1.2.0+ (Phase 0b bundle-load logic)
- `~/.claude/rules/language-policy-en-pt.md` v1.0.0 (PRESERVE list rationale)
- BCP-47 spec: https://tools.ietf.org/html/bcp47
