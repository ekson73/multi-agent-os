#!/usr/bin/env bash
# speak.sh — on-demand TTS for the eko-system family.
# DETERMINISTIC mechanism (the "actor"): renders text → audio via the official fallback chain
#   Gemini 3.1 Flash TTS (pt-BR native) → ElevenLabs v3 → Kokoro (local, free).
# The "Voice Director" (the agent — see skills/voice/SKILL.md) computes voice/gender/intonation/
# rhythm dynamically from context and passes them here as explicit overrides. Presets are TEMPLATES
# (sensible defaults), never the only path — every knob is overridable.
#
# Keys are read from 1Password via the SA-token subshell (op-service-account-tokens) and are
# NEVER echoed, logged, committed, or placed in argv — secrets go in a chmod-600 curl --config
# file inside $WORK (trap-cleaned), never on the command line (no `ps`/argv leak).
#
# `set -uo pipefail` WITHOUT `-e` is intentional: the fallback chain `run_one a || run_one b`
# + each engine's `|| return 1` REQUIRES that a failed engine returns non-zero and falls through
# to the next — `set -e` would abort the whole script on the first engine failure, defeating the
# chain. Each engine function is self-guarding (explicit returns).
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
LANG_=pt-BR              # threaded: Gemini read-label + Kokoro lang_code (see maps below)
OUT=""
PLAY=0                   # OPT-IN audio: default = render-only, NEVER auto-play (operator may be
                         # somewhere sound is unwelcome). Pass --play to afplay immediately.
TEXT=""

SA_ENV="${OP_SA_ENV:-$HOME/.config/op/service-accounts/eko-demerzel.env}"

# Per-operator 1Password item refs live in a MACHINE-LOCAL config (outside the repo, gitignored
# by location) so this committed file carries NO operator-specific vault structure. It is
# allowlist-parsed (only SPEAK_* keys, regex-validated), NEVER blind-`source`d, per script-safety §2.
# Without it the API engines simply report "key unavailable → next engine" and fall through to
# Kokoro (local, no key) — the tool still works with zero config. Set the op:// refs there, e.g.:
#   SPEAK_GEMINI_ITEM="op://<vault>/<item>/credential"
#   SPEAK_ELEVEN_ITEM="op://<vault>/<item>/credential"
SPEAK_LOCAL_ENV="${SPEAK_LOCAL_ENV:-$HOME/.config/eko/speak.env}"
if [ -f "$SPEAK_LOCAL_ENV" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in SPEAK_*=*) ;; *) continue;; esac
    k="${line%%=*}"; v="${line#*=}"
    printf '%s' "$k" | grep -qE '^SPEAK_[A-Z0-9_]+$' || continue
    case "$v" in \"*\") v="${v#\"}"; v="${v%\"}";; \'*\') v="${v#\'}"; v="${v%\'}";; esac
    case "$k" in SPEAK_GEMINI_ITEM|SPEAK_ELEVEN_ITEM|SPEAK_GEMINI_MODEL|SPEAK_ELEVEN_MODEL) export "$k=$v";; esac
  done < "$SPEAK_LOCAL_ENV"
fi
GEMINI_ITEM="${SPEAK_GEMINI_ITEM:-}"   # empty default → no operator vault data committed
EL_ITEM="${SPEAK_ELEVEN_ITEM:-}"
GEMINI_MODEL="${SPEAK_GEMINI_MODEL:-gemini-3.1-flash-tts-preview}"
EL_MODEL="${SPEAK_ELEVEN_MODEL:-eleven_v3}"

usage(){ cat <<'U'
speak.sh — on-demand TTS (Gemini 3.1 → ElevenLabs v3 → Kokoro). Audio is OPT-IN: render-only by default.
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
  --lang pt-BR|en|es|...                   (Gemini read-label + Kokoro lang_code)
  --out file.mp3                           (where to write; default: temp file)
  --play                                   (OPT-IN: afplay the result now — default is render-only)
  --no-play                                (explicit no-op; render-only is already the default)
  --text "..."  --file path                (alternatives to positional text / stdin)
U
}

# ---------- arg parse (safe shift: never `shift 2` past end-of-args → no loop) ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) ENGINE="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --style) STYLE="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --voice) VOICE="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --gender) GENDER="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --stability) STABILITY="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --exaggeration|--style-exag) EXAGG="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --tags) TAGS="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --speed|--rhythm) SPEED="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --lang) LANG_="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --out) OUT="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --play) PLAY=1; shift;;
    --no-play) PLAY=0; shift;;
    --text) TEXT="${2:-}"; shift $(( $# >= 2 ? 2 : 1 ));;
    --file) TEXT="$(cat "${2:?--file needs a path}")"; shift $(( $# >= 2 ? 2 : 1 ));;
    -h|--help) usage; exit 0;;
    --*) echo "speak: unknown flag: $1" >&2; usage; exit 2;;
    *) TEXT="${TEXT:+$TEXT }$1"; shift;;
  esac
done
[ -z "$TEXT" ] && [ ! -t 0 ] && TEXT="$(cat)"        # stdin fallback
[ -z "${TEXT// /}" ] && { usage; exit 2; }

WORK="$(mktemp -d)"; chmod 700 "$WORK"; trap 'rm -rf "$WORK"' EXIT
[ -z "$OUT" ] && { OUT="$WORK/out.mp3"; OUT_IS_TEMP=1; } || OUT_IS_TEMP=0

# ---------- language maps (thread --lang) ----------
case "$LANG_" in
  pt-BR|pt-br|pt) GLANG="português do Brasil"; KCODE=p;;
  en|en-US|en-us) GLANG="English (US)";        KCODE=a;;
  en-GB|en-gb)    GLANG="English (UK)";        KCODE=b;;
  es|es-ES|es-419) GLANG="español";            KCODE=e;;
  fr|fr-FR)       GLANG="français";            KCODE=f;;
  it|it-IT)       GLANG="italiano";            KCODE=i;;
  ja|ja-JP)       GLANG="日本語";               KCODE=j;;
  zh|zh-CN)       GLANG="中文";                 KCODE=z;;
  *)              GLANG="$LANG_";              KCODE=p;;
esac

# ---------- preset → per-engine base config (TEMPLATES; overridable) ----------
case "$STYLE" in
  narrador)  GVOICE=Charon; GHINT="locutor profissional, entonação digna, natural e envolvente, NÃO teatral";
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
GPROMPT="Leia em ${GLANG}. Estilo: ${GHINT}.${TAGS:+ Tom: ${TAGS}.} Texto: "

# ---------- key reader (subshell; value never printed) ----------
read_key(){ ( unset OP_DEVICE OP_SESSION_my OP_SESSION_emilson_moraes 2>/dev/null
              set -a; source "$SA_ENV" 2>/dev/null; set +a
              op read "$1" 2>/dev/null ); }

# ---------- engines: write $OUT, return 0/1, print nothing to stdout ----------
# NOTE: $TEXT/$GPROMPT/$GVOICE/$EPRE are passed to python as sys.argv DATA (never interpolated
# into the -c source), so there is no shell/Python code-injection surface from the narration text.
gen_gemini(){
  local K; K="$(read_key "$GEMINI_ITEM")"; [ -z "$K" ] && { echo "speak: gemini key unavailable → next engine" >&2; return 1; }
  python3 -c "import json,sys;print(json.dumps({'contents':[{'parts':[{'text':sys.argv[1]+sys.argv[2]}]}],'generationConfig':{'responseModalities':['AUDIO'],'speechConfig':{'voiceConfig':{'prebuiltVoiceConfig':{'voiceName':sys.argv[3]}}}}}))" "$GPROMPT" "$TEXT" "$GVOICE" > "$WORK/g.json" || return 1
  # key kept OUT of argv/ps: header lives in a chmod-600 curl config inside $WORK
  ( umask 077; printf 'url = "%s"\nheader = "x-goog-api-key: %s"\nheader = "Content-Type: application/json"\n' \
      "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent" "$K" > "$WORK/g.curl" )
  local h; h=$(curl -s --config "$WORK/g.curl" -o "$WORK/g.resp" -w '%{http_code}' -d @"$WORK/g.json")
  [ "$h" = 200 ] || { echo "speak: gemini http $h → next engine" >&2; return 1; }
  # decode base64 PCM → file; paths passed as argv (no $WORK interpolation into -c source)
  python3 -c "import json,base64,sys;d=json.load(open(sys.argv[1]));open(sys.argv[2],'wb').write(base64.b64decode(d['candidates'][0]['content']['parts'][0]['inlineData']['data']))" "$WORK/g.resp" "$WORK/g.pcm" 2>/dev/null || return 1
  [ -s "$WORK/g.pcm" ] || return 1
  ffmpeg -nostdin -loglevel error -y -f s16le -ar 24000 -ac 1 -i "$WORK/g.pcm" "$OUT" 2>/dev/null || return 1
}
gen_elevenlabs(){
  local K; K="$(read_key "$EL_ITEM")"; [ -z "$K" ] && { echo "speak: elevenlabs key unavailable → next engine" >&2; return 1; }
  python3 -c "import json,sys;print(json.dumps({'text':sys.argv[1]+sys.argv[2],'model_id':sys.argv[3],'voice_settings':{'stability':float(sys.argv[4]),'similarity_boost':0.9,'style':float(sys.argv[5]),'use_speaker_boost':True}}))" "$EPRE" "$TEXT" "$EL_MODEL" "$ESTAB" "$ESTYLE" > "$WORK/e.json" || return 1
  ( umask 077; printf 'url = "%s"\nheader = "xi-api-key: %s"\nheader = "Content-Type: application/json"\nrequest = "POST"\n' \
      "https://api.elevenlabs.io/v1/text-to-speech/${EVOICE}?output_format=mp3_44100_128" "$K" > "$WORK/e.curl" )
  local c; c=$(curl -s --config "$WORK/e.curl" -o "$OUT" -w '%{http_code}' -d @"$WORK/e.json")
  [ "$c" = 200 ] || { echo "speak: elevenlabs http $c → next engine" >&2; return 1; }
  head -c 1 "$OUT" | grep -q '{' && return 1   # JSON error body, not audio
  return 0
}
gen_kokoro(){
  command -v uv >/dev/null || { echo "speak: uv (Kokoro) unavailable" >&2; return 1; }
  cat > "$WORK/k.py" <<'PY'
import sys, numpy as np, soundfile as sf
from kokoro import KPipeline
t, v, sp, code, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4], sys.argv[5]
pipe = KPipeline(lang_code=code)
a = [x for _, _, x in pipe(t, voice=v, speed=sp)]
full = np.concatenate(a) if len(a) > 1 else a[0]
sf.write(out, full, 24000)
PY
  uv run --python 3.12 --with kokoro --with soundfile --with numpy python "$WORK/k.py" "$TEXT" "$KVOICE" "$KSPEED" "$KCODE" "$WORK/k.wav" >/dev/null 2>&1 || return 1
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
echo "speak: engine=$USED style=$STYLE lang=$LANG_ voice=$GVOICE/$EVOICE/$KVOICE -> ${TAG}${OUT}" >&2
[ "$PLAY" = 1 ] && command -v afplay >/dev/null 2>&1 && afplay "$OUT"
[ "$OUT_IS_TEMP" = 0 ] && echo "$OUT"
exit 0
