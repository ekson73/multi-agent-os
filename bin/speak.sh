#!/usr/bin/env bash
# speak.sh — on-demand TTS for the eko-system family.
# DETERMINISTIC mechanism (the "actor"): renders text → audio via the official fallback chain
#   Gemini 3.1 Flash TTS (pt-BR native) → ElevenLabs v3 → Kokoro (local, free).
# The "Voice Director" (the agent — see skills/voice/SKILL.md) computes voice/gender/intonation/
# rhythm dynamically from context and passes them here as explicit overrides. Presets are TEMPLATES
# (sensible defaults), never the only path — every knob is overridable.
#
# Keys are read from 1Password via the SA-token subshell (op-service-account-tokens) and are
# NEVER echoed, logged, or committed. set -euo pipefail; boundary-safe per script-safety.
set -uo pipefail

# ---------- defaults ----------
ENGINE=auto              # auto | gemini | elevenlabs | kokoro
STYLE=narrador           # preset name OR free "director notes" string
VOICE=""                 # explicit voice override (engine-specific name)
GENDER=""                # m | f  (selects a gendered default voice per engine when --voice unset)
STABILITY=""             # ElevenLabs 0..1 (lower = more expressive); overrides preset
EXAGG=""                 # ElevenLabs style 0..1 (higher = more dramatic); overrides preset
TAGS=""                  # extra audio-tags / steering hint, e.g. "[warmly]" (v3) — woven in
SPEED=""                 # rhythm: Kokoro speed (e.g. 0.9) / ElevenLabs speed; overrides preset
LANG_=pt-BR
OUT=""
PLAY=1
TEXT=""

SA_ENV="${OP_SA_ENV:-$HOME/.config/op/service-accounts/eko-demerzel.env}"
GEMINI_ITEM="${SPEAK_GEMINI_ITEM:-op://eko/5kxjep3k3jsuzgltw4dbzvbgxe/credential}"
EL_ITEM="${SPEAK_ELEVEN_ITEM:-op://eko/qtc3ewhhxgnwcld5n2eji544km/credential}"
GEMINI_MODEL="${SPEAK_GEMINI_MODEL:-gemini-3.1-flash-tts-preview}"
EL_MODEL="${SPEAK_ELEVEN_MODEL:-eleven_v3}"

usage(){ cat <<'U'
speak.sh — on-demand TTS (Gemini 3.1 → ElevenLabs v3 → Kokoro)
Usage:
  speak.sh "text to speak" [options]
  echo "text" | speak.sh [options]
Options:
  --engine auto|gemini|elevenlabs|kokoro   (default auto = fallback chain)
  --style  narrador|executivo|caloroso|animado|"<free director notes>"
  --voice  <engine-specific voice name>    (advanced; best with --engine)
  --gender m|f                             (gendered default voice per engine)
  --stability N   --exaggeration N         (ElevenLabs 0..1 overrides)
  --tags "[warmly][excited]"               (extra audio-tags / steering hint)
  --speed N                                (rhythm; e.g. 0.9 slower / 1.1 faster)
  --lang pt-BR
  --out file.mp3                           (default: temp file, played then discarded)
  --no-play                                (do not afplay; keep/emit the file)
  --text "..."  --file path                (alternatives to positional text / stdin)
U
}

# ---------- arg parse ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) ENGINE="${2:-}"; shift 2;;
    --style) STYLE="${2:-}"; shift 2;;
    --voice) VOICE="${2:-}"; shift 2;;
    --gender) GENDER="${2:-}"; shift 2;;
    --stability) STABILITY="${2:-}"; shift 2;;
    --exaggeration|--style-exag) EXAGG="${2:-}"; shift 2;;
    --tags) TAGS="${2:-}"; shift 2;;
    --speed|--rhythm) SPEED="${2:-}"; shift 2;;
    --lang) LANG_="${2:-}"; shift 2;;
    --out) OUT="${2:-}"; shift 2;;
    --no-play) PLAY=0; shift;;
    --text) TEXT="${2:-}"; shift 2;;
    --file) TEXT="$(cat "${2:?--file needs a path}")"; shift 2;;
    -h|--help) usage; exit 0;;
    --*) echo "speak: unknown flag: $1" >&2; usage; exit 2;;
    *) TEXT="${TEXT:+$TEXT }$1"; shift;;
  esac
done
[ -z "$TEXT" ] && [ ! -t 0 ] && TEXT="$(cat)"        # stdin fallback
[ -z "${TEXT// /}" ] && { usage; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
[ -z "$OUT" ] && { OUT="$WORK/out.mp3"; OUT_IS_TEMP=1; } || OUT_IS_TEMP=0

# ---------- preset → per-engine base config (TEMPLATES; overridable) ----------
case "$STYLE" in
  narrador)  GVOICE=Charon; GHINT="locutor brasileiro profissional, entonação digna, natural e envolvente, NÃO teatral";
             EVOICE=EXAVITQu4vr4xnSDxMaL; ESTAB=0.4; ESTYLE=0.3; EPRE="[thoughtful] "; KVOICE=pm_santa; KSPEED=0.9;;
  executivo) GVOICE=Aoede;  GHINT="apresentadora clara, calorosa e profissional";
             EVOICE=EXAVITQu4vr4xnSDxMaL; ESTAB=0.5; ESTYLE=0.15; EPRE=""; KVOICE=pf_dora; KSPEED=1.0;;
  caloroso)  GVOICE=Aoede;  GHINT="voz calorosa, expressiva e natural, com entonação viva";
             EVOICE=IKne3meq5aSn9XLyUdCD; ESTAB=0.35; ESTYLE=0.45; EPRE="[warmly] "; KVOICE=pf_dora; KSPEED=1.1;;
  animado)   GVOICE=Puck;   GHINT="tom leve, animado e levemente bem-humorado, natural e espontâneo";
             EVOICE=FGY2WhTYpPnrIDTdsKH5; ESTAB=0.3; ESTYLE=0.55; EPRE="[excited] "; KVOICE=pm_alex; KSPEED=1.05;;
  *)         GVOICE=Charon; GHINT="$STYLE"; EVOICE=EXAVITQu4vr4xnSDxMaL; ESTAB=0.4; ESTYLE=0.4; EPRE=""; KVOICE=pm_santa; KSPEED=0.95;;
esac

# gendered default voice (when --voice not given)
case "$GENDER" in
  f|F|female) GVOICE=Aoede; EVOICE=EXAVITQu4vr4xnSDxMaL; KVOICE=pf_dora;;
  m|M|male)   GVOICE=Charon; EVOICE=JBFqnCBsd6RMkjVDRZzb; KVOICE=pm_santa;;
esac
# explicit per-engine overrides
[ -n "$VOICE" ]     && { GVOICE="$VOICE"; EVOICE="$VOICE"; KVOICE="$VOICE"; }
[ -n "$STABILITY" ] && ESTAB="$STABILITY"
[ -n "$EXAGG" ]     && ESTYLE="$EXAGG"
[ -n "$SPEED" ]     && KSPEED="$SPEED"
[ -n "$TAGS" ]      && EPRE="${TAGS} "
GPROMPT="Leia em português do Brasil. Estilo: ${GHINT}.${TAGS:+ Tom: ${TAGS}.} Texto: "

# ---------- key reader (subshell; value never printed) ----------
read_key(){ ( unset OP_DEVICE OP_SESSION_my OP_SESSION_emilson_moraes 2>/dev/null
              set -a; source "$SA_ENV" 2>/dev/null; set +a
              op read "$1" 2>/dev/null ); }

# ---------- engines: write $OUT, return 0/1, print nothing to stdout ----------
gen_gemini(){
  local K; K="$(read_key "$GEMINI_ITEM")"; [ -z "$K" ] && return 1
  python3 -c "import json,sys;print(json.dumps({'contents':[{'parts':[{'text':sys.argv[1]+sys.argv[2]}]}],'generationConfig':{'responseModalities':['AUDIO'],'speechConfig':{'voiceConfig':{'prebuiltVoiceConfig':{'voiceName':sys.argv[3]}}}}}))" "$GPROMPT" "$TEXT" "$GVOICE" > "$WORK/g.json" || return 1
  local h; h=$(curl -s -o "$WORK/g.resp" -w '%{http_code}' "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=$K" -H 'Content-Type: application/json' -d @"$WORK/g.json")
  [ "$h" = 200 ] || return 1
  python3 -c "import json,base64;d=json.load(open('$WORK/g.resp'));open('$WORK/g.pcm','wb').write(base64.b64decode(d['candidates'][0]['content']['parts'][0]['inlineData']['data']))" 2>/dev/null || return 1
  ffmpeg -nostdin -loglevel error -y -f s16le -ar 24000 -ac 1 -i "$WORK/g.pcm" "$OUT" 2>/dev/null || return 1
}
gen_elevenlabs(){
  local K; K="$(read_key "$EL_ITEM")"; [ -z "$K" ] && return 1
  python3 -c "import json,sys;print(json.dumps({'text':sys.argv[1]+sys.argv[2],'model_id':sys.argv[3],'voice_settings':{'stability':float(sys.argv[4]),'similarity_boost':0.9,'style':float(sys.argv[5]),'use_speaker_boost':True}}))" "$EPRE" "$TEXT" "$EL_MODEL" "$ESTAB" "$ESTYLE" > "$WORK/e.json" || return 1
  local c; c=$(curl -s -o "$OUT" -w '%{http_code}' -X POST "https://api.elevenlabs.io/v1/text-to-speech/${EVOICE}?output_format=mp3_44100_128" -H "xi-api-key: $K" -H "Content-Type: application/json" -d @"$WORK/e.json")
  [ "$c" = 200 ] || return 1
  head -c 1 "$OUT" | grep -q '{' && return 1   # JSON error body, not audio
  return 0
}
gen_kokoro(){
  command -v uv >/dev/null || return 1
  cat > "$WORK/k.py" <<'PY'
import sys, numpy as np, soundfile as sf
from kokoro import KPipeline
t, v, sp, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
pipe = KPipeline(lang_code='p')
a = [x for _, _, x in pipe(t, voice=v, speed=sp)]
full = np.concatenate(a) if len(a) > 1 else a[0]
sf.write(out, full, 24000)
PY
  uv run --python 3.12 --with kokoro --with soundfile --with numpy python "$WORK/k.py" "$TEXT" "$KVOICE" "$KSPEED" "$WORK/k.wav" >/dev/null 2>&1 || return 1
  ffmpeg -nostdin -loglevel error -y -i "$WORK/k.wav" "$OUT" 2>/dev/null || return 1
}

# ---------- chain ----------
USED=""
run_one(){ case "$1" in
  gemini)     gen_gemini     && USED=gemini;;
  elevenlabs) gen_elevenlabs && USED=elevenlabs;;
  kokoro)     gen_kokoro     && USED=kokoro;;
  *) return 1;; esac; }

if [ "$ENGINE" = auto ]; then
  run_one gemini || run_one elevenlabs || run_one kokoro || { echo "speak: all engines failed" >&2; exit 1; }
else
  run_one "$ENGINE" || { echo "speak: engine '$ENGINE' failed" >&2; exit 1; }
fi

TAG=""; [ "$OUT_IS_TEMP" = 1 ] && TAG="(temp) "
echo "speak: engine=$USED style=$STYLE voice=$GVOICE/$EVOICE/$KVOICE -> ${TAG}${OUT}" >&2
[ "$PLAY" = 1 ] && command -v afplay >/dev/null 2>&1 && afplay "$OUT"
[ "$OUT_IS_TEMP" = 0 ] && echo "$OUT"
exit 0
