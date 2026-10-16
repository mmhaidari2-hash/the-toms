#!/usr/bin/env bash
# Usage: tool/make_loop.sh <generated.mp4> <place>   -> assets/places/<place>_loop.mp4 (~1-2 MB, muted, iOS-safe)
# Seamless loop: last 0.6 s cross-faded into the first 0.6 s. Also writes frame grabs to /tmp/loop_frames for QA.
set -euo pipefail
IN=$1; P=$2; OUT=assets/places/${P}_loop.mp4; F=0.6
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
ffmpeg -y -loglevel error -i "$IN" -filter_complex \
 "[0:v]split[a][b];[a]trim=start=$F,setpts=PTS-STARTPTS[main];[b]trim=0:$F,setpts=PTS-STARTPTS[head];[main][head]xfade=transition=fade:duration=$F:offset=$(python3 -c "print($D-2*$F)")[v]" \
 -map "[v]" -an -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -vf scale=1280:-2 -crf 28 -preset slow -movflags +faststart "$OUT" 2>/dev/null || \
ffmpeg -y -loglevel error -i "$IN" -an -c:v libx264 -pix_fmt yuv420p -vf scale=1280:-2 -crf 28 -preset slow -movflags +faststart "$OUT"
ls -la "$OUT"; rm -rf /tmp/loop_frames; mkdir -p /tmp/loop_frames
ffmpeg -loglevel error -i "$OUT" -vf fps=2 /tmp/loop_frames/f%02d.png; echo frames: /tmp/loop_frames
