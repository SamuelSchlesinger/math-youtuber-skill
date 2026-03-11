#!/bin/bash
# Record and prepare a voice reference for f5-tts-mlx.
#
# Usage:
#   ./record-reference.sh [output-dir]
#
# Records your voice, resamples to 24kHz mono, and prints the
# duration + path for use in generate_narration.py.
#
# Tips:
#   - Read a line from your script in the tone you want
#   - Aim for 8-12 seconds of clear speech
#   - Leave ~1 second of silence at the end
#   - Clean audio, no background noise

set -euo pipefail

OUT_DIR="${1:-.}"
RAW="$OUT_DIR/my_voice_ref.wav"
RESAMPLED="$OUT_DIR/my_voice_ref_24k.wav"

mkdir -p "$OUT_DIR"

echo ""
echo "  Voice reference recording"
echo "  ─────────────────────────"
echo ""
echo "  Read a line from your script (8-12 seconds)."
echo "  Speak in the tone and pace you want the AI to clone."
echo "  Leave ~1s of silence at the end."
echo ""

while true; do
    read -rp "  Press ENTER to start recording (q to quit)... " choice
    [ "$choice" = "q" ] && exit 0

    echo ""
    echo "  Recording... press ENTER when done"
    echo ""

    rec -q -r 24000 -c 1 -b 16 "$RAW" 2>/dev/null &
    REC_PID=$!

    read -r
    kill $REC_PID 2>/dev/null
    wait $REC_PID 2>/dev/null

    DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$RAW" 2>/dev/null)
    echo "  Recorded: ${DUR}s"

    # check if duration is in range
    IN_RANGE=$(python3 -c "d=float('${DUR}'); print('ok' if 6 <= d <= 15 else 'warn')")
    if [ "$IN_RANGE" = "warn" ]; then
        echo "  (aim for 8-12 seconds — this is ${DUR}s)"
    fi

    echo ""
    read -rp "  (p)lay back / (k)eep / (r)e-record? " choice

    case "$choice" in
        p)
            ffplay -autoexit -nodisp "$RAW" 2>/dev/null
            read -rp "  (k)eep / (r)e-record? " choice2
            [ "$choice2" = "r" ] && continue
            ;;
        r) continue ;;
        *) ;;
    esac
    break
done

# resample to 24kHz mono (what f5-tts-mlx requires)
ffmpeg -y -i "$RAW" -ac 1 -ar 24000 -sample_fmt s16 "$RESAMPLED" 2>/dev/null

DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$RESAMPLED" 2>/dev/null)

echo ""
echo "  Done!"
echo ""
echo "  Reference audio: $RESAMPLED"
echo "  Duration: ${DUR}s"
echo ""
echo "  For generate_narration.py:"
echo "    REF_AUDIO = \"$RESAMPLED\""
echo "    REF_DUR = $DUR"
echo ""
echo "  Don't forget to set REF_TEXT to the exact words you spoke."
