---
name: voice
description: Speak text aloud ON-DEMAND via the official TTS fallback chain (Gemini 3.1 → ElevenLabs v3 → Kokoro). ⚠️ Audio is OPT-IN — text is the default everywhere; only speak when the operator explicitly wants sound (they may be somewhere sound is unwelcome). The agent "Voice Director" casts voice/gender/intonation/rhythm from context (hybrid deterministic × agentic). Thin wrapper over the `voice` skill + `bin/speak`.
argument-hint: "\"text to speak\" [--engine auto|gemini|elevenlabs|kokoro] [--style narrador|executivo|caloroso|animado|\"<director notes>\"] [--gender m|f] [--stability N] [--exaggeration N] [--tags \"[warmly]\"] [--speed N] [--out file.mp3] [--no-play]"
allowed-tools: [Read, Bash, Skill]
---

# /voice

Speak text aloud ON DEMAND. ⚠️ **Audio is opt-in** — invoke ONLY when the operator explicitly wants sound.

**Arguments**: `$ARGUMENTS`

## Parsing
- Bare text → `bin/speak.sh "$ARGUMENTS"` (the Voice-Director picks style/voice/rhythm from context).
- Flags pass through verbatim to `bin/speak.sh`.
- Empty `$ARGUMENTS` → print the skill's usage; do NOT guess.

## What it does (skill + producer)
Invoke the **`voice`** skill (Claude Code: `Skill` tool `skill: "voice"`; other hosts: equivalent): the
**Voice Director** computes voice/gender/intonation/personality/rhythm from `(text, context, session-mood)`
— hybrid deterministic templates × agentic judgment, bounded by the faithfulness/tone gate — then calls
**`bin/speak.sh`** (chain Gemini→ElevenLabs→Kokoro; keys read from 1Password, never echoed). Renders +
`afplay`s by default; `--out file.mp3` to save, `--no-play` to suppress.

## Family
content-lifecycle. The voice PRODUCER for `opera-debrief --media audio-voice` ·
`morning-briefing --media=audio-voice` · `content-recast --format voice`. See `skills/voice/SKILL.md`.
