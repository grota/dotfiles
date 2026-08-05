#!/usr/bin/env bash
#
# shrink_video.sh — re-encode a video to fit a target file size.
#
#   Usage: shrink_video.sh <input.mp4> [target_size_mb]
#
#   target_size_mb defaults to 25.
#
# Strategy: file size ≈ (video_bitrate + audio_bitrate) × duration.
# We probe the duration and the existing audio bitrate, subtract that from the
# target, then run a two-pass H.264 encode at the computed video bitrate so the
# output lands very close to the requested size.
#
# Output is written next to the input as "<name>_shrink.mp4".

set -euo pipefail

TARGET_MB="${2:-25}"
INPUT="$1"

if [[ $# -lt 1 || ! -f "$INPUT" ]]; then
    echo "Usage: $0 <input.mp4> [target_size_mb]" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    echo "Error: ffmpeg and ffprobe are required." >&2
    exit 1
fi

# 25 MB in bytes. MB here is treated as 1024*1024 bytes.
TARGET_BYTES=$((TARGET_MB * 1024 * 1024))

# --- Probe input -----------------------------------------------------------
DURATION=$(ffprobe -v error -show_entries format=duration \
           -of default=noprint_wrappers=1:nokey=1 "$INPUT")

# Current audio bitrate (fall back to 128 kbps if unknown, e.g. variable).
AUDIO_BR=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate \
           -of default=noprint_wrappers=1:nokey=1 "$INPUT")
if [[ -z "$AUDIO_BR" || "$AUDIO_BR" == "N/A" || "$AUDIO_BR" == "0" ]]; then
    AUDIO_BR=128000
fi

# --- Compute video bitrate -------------------------------------------------
# total_bitrate = target_bytes * 8 / duration
TOTAL_BR=$(awk -v b="$TARGET_BYTES" -v d="$DURATION" 'BEGIN{printf "%d", b*8/d}')
VIDEO_BR=$((TOTAL_BR - AUDIO_BR))
if (( VIDEO_BR < 100000 )); then
    echo "Warning: computed video bitrate is very low ($((VIDEO_BR/1000)) kbps)." >&2
    echo "The video may be heavily compressed or the file is very long." >&2
fi

BASE="${INPUT%.mp4}"
OUT="${BASE}_shrink.mp4"
QUALITY="${QUALITY:-medium}"   # veryfast..slower tradeoff; default medium
AUDIO_BR_ENC=$((AUDIO_BR / 1000))  # ffmpeg wants kbps here

echo "Input       : $INPUT"
echo "Duration    : ${DURATION}s"
echo "Target size : ${TARGET_MB} MB ($TARGET_BYTES bytes)"
echo "Audio bitrate kept: ${AUDIO_BR_ENC} kbps"
echo "Video bitrate set : $((VIDEO_BR/1000)) kbps"
echo "Output      : $OUT"
echo

# --- Two-pass encode ---------------------------------------------------------
TMPDIR_TMP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TMP"' EXIT
LOG="$TMPDIR_TMP/passlog"

echo "Pass 1/2 ..."
ffmpeg -hide_banner -loglevel error -y -i "$INPUT" \
       -c:v libx264 -preset "$QUALITY" -b:v "${VIDEO_BR}" -pass 1 -passlogfile "$LOG" \
       -an -f null /dev/null

echo "Pass 2/2 ..."
ffmpeg -hide_banner -loglevel error -y -i "$INPUT" \
       -c:v libx264 -preset "$QUALITY" -b:v "${VIDEO_BR}" -pass 2 -passlogfile "$LOG" \
       -c:a aac -b:a "${AUDIO_BR_ENC}k" \
       -movflags +faststart \
       "$OUT"

# --- Report ----------------------------------------------------------------
ACTUAL=$(stat -c%s "$OUT")
echo
echo "Done: $(du -h "$OUT" | cut -f1)  ($((ACTUAL/1024)) KB / target $((TARGET_BYTES/1024)) KB)"
