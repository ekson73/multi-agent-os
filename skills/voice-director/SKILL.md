---
name: voice-director
description: |
  Use when the operator EXPLICITLY asks to SPEAK/narrate something aloud — "fala isso", "narra o
  resumo", "speak this", "voz de aplauso", "--media audio-voice", "read this aloud" — to turn text
  into real, human-like, ON-DEMAND audio. Holds the install/config/use knowledge of the 3 TTS
  engines (Gemini 3.1 Flash TTS → ElevenLabs v3 → Kokoro) behind the `bin/speak.sh` producer, and the
  "Voice Director" rubric that computes voice/gender/intonation/personality/rhythm DYNAMICALLY from
  context (hybrid: deterministic templates × the agent's contextual judgment). ⚠️ AUDIO IS NEVER A
  DEFAULT — text is the default; speak ONLY when the operator opts in (they may be where sound is
  unwelcome). Named `voice-director` (NOT `voice`) so it never collides with the host's native
  `/voice` push-to-talk INPUT mode; the operator-facing command is `/speak`. Not for: real-time voice
  INPUT/dictation (that is the host's `/voice`); generating a downloadable podcast (that is NotebookLM,
  async batch). Cross-vendor AAIF.
triggers:
  - fala isso / narra isso / lê isso em voz alta
  - speak this / read this aloud / narrate the recap
  - voz / áudio / opera falada / --media audio-voice / --speak
  - which TTS voice/engine should I use
version: 0.1.0
license: MIT
allowed-tools: Read, Bash, Skill
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: content-lifecycle
  cross_link_slug: voice-director
  dogfood_status: pending-first-cycle
---

# Voice Director — on-demand TTS for the eko-system family
<!-- skill slug: `voice-director` · operator command: `/speak` · producer: `bin/speak.sh` -->


## Overview
Turn text into **real, human-like, on-demand voice**. Single responsibility = the **voice layer**:
a deterministic producer (`bin/speak.sh`) that renders text → audio via the official fallback chain,
plus a **Voice Director** rubric that lets the agent cast the voice/tone/rhythm to the moment. The
quality bar was set by an operator-eared bake-off (see Refs): **Gemini 3.1 Flash TTS** wins (pt-BR
native, 9–10), **ElevenLabs v3** is the expressive fallback (9–10, free-tier voices carry a light
accent), **Kokoro** is the always-free local fallback (7–8). `say`/NotebookLM are out (robotic /
async-batch-podcast respectively).

## ⚠️ Audio is OPT-IN — never a default
**The default output of every family skill is TEXT.** The operator may be in a meeting, a quiet
room, a shared space — somewhere sound is unwelcome. **Speak ONLY when the operator explicitly opts
in** (a `--media audio-voice` / `--speak` flag, or a direct "fala/narra isso"). **Never auto-play.**
When unsure whether sound is welcome, render to a file and ASK before playing. (This is a HUMAN_DOMAIN
courtesy, non-negotiable.)

## When to use / not use
- **Use**: operator explicitly wants something spoken (a recap, a briefing, an alert, an opera-debrief
  "de aplauso"); or another skill's opt-in `--media audio-voice` path fires.
- **Not use**: default text output (no opt-in) → just print text. Real-time voice INPUT/dictation →
  host `/voice`. A downloadable generative PODCAST → NotebookLM (async). Re-targeting content for an
  audience → `content-recast`/`opera-debrief` (they may THEN opt into voice via this skill).

## §0 — BEING > Rules (foundational)
Serves the operator's intent. If a phase obstructs delivering value NOW, skip it + log. ⛔ API keys
are read from 1Password via the SA-token subshell and are NEVER echoed/logged/committed. ⛔ Never
auto-play audio (opt-in only). **Faithfulness/tone gate** (inherited from `opera-debrief`): voice the
emotion the CONTENT actually carries — never fabricate drama, never alarm; wit/persona never targets a
person. A vivid-but-false delivery is worse than a plain one.

## Architecture — HYBRID (deterministic mechanism × the agent as Director)
| Layer | Who | What |
|---|---|---|
| **Deterministic (the actor)** | `bin/speak.sh` (script) + presets (templates) + param ranges + the fallback chain | repeatable, scriptable, amnesia-proof; takes explicit config; first-success-wins chain |
| **Non-deterministic (the director)** | the AGENT, via the §Voice-Director rubric | reads context · scope · session-mood · the text's emotional tone → COMPUTES voice/gender/intonation/tags/rhythm → calls `bin/speak.sh` |

This mirrors the Convergence-Engine doctrine (deterministic harness × probabilistic cognition): the
*mechanism* is fixed and safe; the *casting/direction* is the agent's judgment, bounded by the gates.

## `bin/speak.sh` — the producer (deterministic surface)
`bin/speak.sh "text" [options]` (or pipe text on stdin). Renders **render-only by default (NEVER auto-plays)** — pass `--play` to afplay now (opt-in); `--out
file.mp3` to save, `--no-play` to suppress audio.

| Option | Meaning |
|---|---|
| `--engine auto\|gemini\|elevenlabs\|kokoro` | `auto` = chain Gemini→ElevenLabs→Kokoro (first that works) |
| `--style narrador\|executivo\|caloroso\|animado\|"<free director notes>"` | preset TEMPLATE or free natural-language direction |
| `--voice <name>` | engine-specific voice override (advanced; best with `--engine`) |
| `--gender m\|f` | gendered default voice per engine (when `--voice` unset) |
| `--stability N` `--exaggeration N` | ElevenLabs 0..1 (stability↓ = more expressive; exagg↑ = more dramatic) |
| `--tags "[warmly][excited]"` | extra audio-tags (v3) / steering hint (woven into the prompt) |
| `--speed N` | rhythm (e.g. 0.9 slower, 1.1 faster) |
| `--out file.mp3` / `--no-play` | save / suppress playback |

**Presets are templates, not a cage** — every knob overrides; `--style "<free notes>"` lets the
Director write bespoke direction (Gemini reads it as Director's-Notes; ElevenLabs/Kokoro fall back to
their defaults + the explicit knobs).

### Style presets (the bake-off winners, per engine)
| preset | Gemini voice + direction | ElevenLabs voice · stab/style · tag | Kokoro voice · speed |
|---|---|---|---|
| `narrador` | Charon · "locutor BR digno, natural, não-teatral" | Sarah · .4/.3 · `[thoughtful]` | pm_santa · 0.9 |
| `executivo` | Aoede · "apresentadora clara e calorosa" | Sarah · .5/.15 | pf_dora · 1.0 |
| `caloroso` | Aoede · "expressivo, natural, vivo" | Charlie · .35/.45 · `[warmly]` | pf_dora · 1.1 |
| `animado` | Puck · "leve, animado, bem-humorado" | Laura · .3/.55 · `[excited]` | pm_alex · 1.05 |

## §Voice-Director rubric (the non-deterministic layer — how the agent casts on-demand)
Given a `(text, context)` and an OPT-IN to speak, compute the `bin/speak.sh` call in two passes:

**1. Deterministic base (template) — content-type → preset + gender default:**
| Content-type / context | base preset | default gender |
|---|---|---|
| opera-debrief / recap "de aplauso" / story | `narrador` | m (gravitas) |
| morning-briefing / status / report | `executivo` | f |
| co-work chat / friendly note | `caloroso` | (either) |
| notification / quick ping / celebration | `animado` | (either) |
| alert / incident / serious | `narrador` + `--exaggeration 0.15` `--tags "[serious]"` | m |

**2. Non-deterministic overlay (the agent's judgment) — read the MOMENT, adjust within the gates:**
- **Session mood / scope**: a hard-won bugfix recap → measured, relieved, warm (lower exaggeration,
  `[relieved]`/`[warmly]`); a feature shipped / clean win → confident, upbeat; a security/prod topic →
  calm, serious (no levity). The opera-debrief dosed-intensity dials apply.
- **Text's emotional tone**: voice ONLY the emotion the content carries (faithfulness gate) — never
  inflate. Big turning-point sentence → a touch more intonation/pause; routine status → even.
- **Variety/persona**: vary voice/gender across calls for personality (don't always pick the same),
  but keep it apt — the cast should fit the piece, not distract.
- **Rhythm**: slower for weighty/narrator, brisker for animated/notification.
- Then emit: `bin/speak.sh "<text>" --style <preset or free-notes> [--gender] [--exaggeration] [--tags] [--speed] [--play]`.

The base map makes it repeatable; the overlay makes it alive. **Both are bounded by**: opt-in only,
the faithfulness/tone gate, and the deterministic param ranges.

## Engine config knowledge (for the Director + for tuning)
### Gemini 3.1 Flash TTS (primary — pt-BR native)
- Model `gemini-3.1-flash-tts-preview` (also `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`).
  REST `…:generateContent` with `generationConfig.responseModalities:["AUDIO"]` +
  `speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName`. Output = base64 **PCM L16 24kHz mono** →
  `ffmpeg -f s16le -ar 24000 -ac 1`.
- **Tone/intonation control = "Director's Notes"**: natural-language style instructions PREPENDED to the
  text ("Narre como um locutor BR digno, não-teatral. Texto: …"). This is the main expressivity lever.
  Multi-speaker (up to 2) supported. 70+ languages; pt-BR is native (no accent drift).
- **~30 prebuilt voices** (character): Zephyr=Bright · Puck=Upbeat · Charon=Informative/deep ·
  Kore=Firm · Fenrir=Excitable · Aoede=Breezy/warm · Leda=Youthful · Orus=Firm · Callirrhoe=Easy ·
  Autonoe=Bright · Enceladus=Breathy · Iapetus=Clear · Umbriel=Easy · Algieba=Smooth · Despina=Smooth ·
  Erinome=Clear · Algenib=Gravelly · Rasalgethi=Informative · Laomedeia=Upbeat · Achernar=Soft ·
  Alnilam=Firm · Schedar=Even · Gacrux=Mature · Pulcherrima=Forward · Achird=Friendly ·
  Zubenelgenubi=Casual · Vindemiatrix=Gentle · Sadachbia=Lively · Sadaltager=Knowledgeable · Sulafat=Warm.
  *(verify against the live API on a major model release — Mente Tomé)*.
- Free-tier reachable via Google AI Studio key; paid ~ $/1M tokens (2.5 cheaper than 3.1).
### ElevenLabs v3 (fallback — most expressive)
- `voice_settings`: `stability` 0..1 (↓ = more expressive/variable; v3 also discrete Creative/Natural/
  Robust) · `style` 0..1 (↑ = more exaggerated) · `similarity_boost` 0..1 · `use_speaker_boost` · `speed`.
- **Audio-tags (v3)** woven inline: emotions `[excited][sad][angry][nervous][curious][happy]` · delivery
  `[whispers][shouts][dramatic][rushed]` · reactions `[laughs][sighs][clears throat][crying]` · vibe
  `[warmly][thoughtful][hopeful][serious][confident][encouraging]` · multi-char `[interrupting]` · accents.
- Models: `eleven_v3` (expressive, use this) · `eleven_multilingual_v2` (solid pt-BR, GA) · `flash/turbo_v2_5`
  (low-latency). REST `POST /v1/text-to-speech/{voice_id}` + `xi-api-key`. ⚠️ **native pt-BR library voice
  = PAID-plan-gated** (free tier → EN voices carry a light pt-PT/EN accent). Free tier ~10k chars/mo.
  Official MCP: `uvx elevenlabs-mcp` (env `ELEVENLABS_API_KEY`).
### Kokoro (free local fallback)
- Local neural, **no key, no cost**. `lang_code='p'` (pt-BR); voices `pf_dora` (F), `pm_alex`/`pm_santa` (M).
  Levers = voice + `speed` only (NO audio-tags/acting) → best for plain narration. Run via `uv run --python
  3.12 --with kokoro --with soundfile --with numpy`. Needs `espeak-ng` (g2p).

## Install / setup
- `brew install espeak-ng` (Kokoro pt-BR g2p) · `uv` (provisions Kokoro+torch on first run) · `ffmpeg` + `afplay`.
- Keys live in 1Password; read at runtime via the `op` SA-token subshell (`op-service-account-tokens`) — the
  actual secret is **never** echoed/logged/committed/placed in argv (it goes in a chmod-600 `curl --config`).
- **Per-operator item refs are machine-local, NOT committed** (so the repo carries zero operator vault structure).
  Put your op:// refs in `~/.config/eko/speak.env` (`chmod 600`), which `bin/speak.sh` allowlist-parses
  (`SPEAK_*` keys only — never blind-sourced, per `script-safety §2`):
  ```sh
  SPEAK_GEMINI_ITEM="op://<vault>/<item>/credential"
  SPEAK_ELEVEN_ITEM="op://<vault>/<item>/credential"
  ```
  Or export the same vars in your shell. **Without any config** the API engines report
  `key unavailable → next engine` and fall through to **Kokoro** (local, no key) — the tool still works with
  zero setup. The committed defaults are empty; gitleaks-clean.

## Anti-patterns (do NOT)
- ❌ Auto-play / make voice a default → operator may be where sound is unwelcome (opt-in only).
- ❌ Echo/log/commit an API key → ⛔ absolute.
- ❌ Voice an emotion the content doesn't carry / alarm for effect → faithfulness+tone gate.
- ❌ Rebuild a TTS engine or hardcode a single voice → use `bin/speak.sh` + the Director (presets+overrides).
- ❌ Use NotebookLM for on-demand voice (it's async batch podcast) / `say` for quality (robotic).
- ❌ Ignore the fallback chain (always degrade gracefully Gemini→ElevenLabs→Kokoro).

## §Quality Tests (self-dogfood — 6/6)
1. **Self-Application** — forged via the operator-eared bake-off (dogfood cycle 002 of `agentic-tool-pipeline`); the chain + presets ARE the verified winners. ✅
2. **Non-Contradiction** — composes (not duplicates) `content-recast`/`opera-debrief` (it's their voice *producer*); consistent with the Convergence-Engine + faithfulness lineage. ✅
3. **Survival** — applied to itself it advocates opt-in, graceful-fallback, faithful voice; survives. ✅
4. **Bounded-Responsibility** — opt-in only · fallback chain · param ranges · `--no-play` · DUED. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN (sound-context, keys) + Director cognitive-freedom. ✅
6. **Utility-Sunset** — §DUED below. ✅

## §DUED Sunset (qualitative)
Deprecate when ANY: the host ships a native on-demand TTS primitive (E1) · a content-lifecycle tool absorbs the voice layer (E6) · operator retraction (E4) · ≥3 false-plays where opt-in is misjudged (E5 → tighten the gate). Dormant-by-design otherwise.

## Related Multi-Agent OS Artifacts
- `bin/speak.sh` — the deterministic producer this skill documents + directs.
- `skills/opera-debrief/SKILL.md` · `skills/morning-briefing/SKILL.md` · `skills/content-recast/SKILL.md` — consumers; their `--media audio-voice` opt-in routes here. content-recast's Composition map gains a `voice` row.
- `skills/agentic-tool-pipeline` — the conductor; this skill is the output of its dogfood cycle 002.

## §Refs
- Genesis: operator-eared TTS bake-off 2026-06-25 (Gemini 10 > ElevenLabs 9 > Kokoro 7–8; `say` 3/3/5; NotebookLM excluded). Scorecard + samples: session scratchpad `tts-bakeoff/`.
- Engines: Google Gemini TTS (ai.google.dev/gemini-api) · ElevenLabs v3 (elevenlabs.io/docs) · Kokoro (`hexgrad/Kokoro-82M`).
- Gates: anti-theater grounding (faithfulness) · `opera-debrief` dosed-intensity + no-terror · `op-service-account-tokens` (keys) · `script-safety`.
- Cross-link slug: `[[voice-director]]`.

## License
MIT (matches the repo `LICENSE`).

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-06-25 | Bootstrap. `bin/speak.sh` producer (Gemini 3.1 → ElevenLabs v3 → Kokoro fallback chain, 1P keys via SA subshell, full override surface). HYBRID Voice-Director rubric (deterministic content-type→preset templates × non-deterministic mood/tone overlay). **Audio strictly opt-in (never default)** + faithfulness/tone gate. Engine config knowledge (Gemini ~30 voices + Director's-Notes; ElevenLabs voice_settings + v3 audio-tags + paid-pt-BR caveat; Kokoro voices+speed). Forged from the operator-eared bake-off (dogfood cycle 002 of `agentic-tool-pipeline`). 6/6 self-validity. |
