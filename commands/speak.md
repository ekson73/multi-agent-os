---
name: speak
description: Speak text aloud ON-DEMAND via the official TTS fallback chain (Gemini 3.1 → ElevenLabs v3 → Kokoro). ⚠️ Audio is OPT-IN — text is the default everywhere; only speak when the operator explicitly wants sound (they may be somewhere sound is unwelcome). Named `/speak` (NOT `/voice`) to avoid colliding with the host's native `/voice` push-to-talk INPUT mode. The agent "Voice Director" casts voice/gender/intonation/rhythm from context (hybrid deterministic × agentic). Thin wrapper over the `voice-director` skill + `bin/speak.sh`.
argument-hint: "\"text to speak\" [--engine auto|gemini|elevenlabs|kokoro] [--style narrador|executivo|caloroso|animado|\"<director notes>\"] [--gender m|f] [--lang pt-BR|en|es] [--stability N] [--exaggeration N] [--tags \"[warmly]\"] [--speed N] [--out file.mp3] [--play]"
allowed-tools: [Read, Bash, Skill]
---

# /speak

Speak text aloud ON DEMAND. ⚠️ **Audio is opt-in** — invoke ONLY when the operator explicitly wants sound. (`/speak`, not `/voice` — the latter is the host's native push-to-talk input mode.)

**Arguments**: `$ARGUMENTS`

## Parsing
- Bare text → `bin/speak.sh "$ARGUMENTS" --play` (the Voice-Director picks style/voice/rhythm from context; `--play` because typing `/speak` is an explicit request to hear it).
- Flags pass through verbatim to `bin/speak.sh`.
- Empty `$ARGUMENTS` → print the skill's usage; do NOT guess.

## What it does (skill + producer)
Invoke the **`voice-director`** skill (Claude Code: `Skill` tool `skill: "voice-director"`; other hosts: equivalent): the
**Voice Director** computes voice/gender/intonation/personality/rhythm from `(text, context, session-mood)`
— hybrid deterministic templates × agentic judgment, bounded by the faithfulness/tone gate — then calls
**`bin/speak.sh`** (chain Gemini→ElevenLabs→Kokoro; keys read from 1Password, never echoed/argv-leaked).
`bin/speak.sh` is **render-only by default**; this command adds `--play` to afplay it now. Use
`--out file.mp3` to also save; drop `--play` (or pass `--no-play`) to render silently.

## Family
content-lifecycle. The voice PRODUCER for `opera-debrief --media audio-voice` ·
`morning-briefing --media=audio-voice` · `content-recast --format voice`. See `skills/voice-director/SKILL.md`.
