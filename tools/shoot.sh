#!/bin/sh
# Take review screenshots: tools/shoot.sh <level> <shots.json> <out dir>
cd "$(dirname "$0")/.." && mkdir -p "$3" && \
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
  --resolution 1920x1080 res://tests/shots.tscn -- --level="$1" --shots="$2" --out="$3" 2>&1 \
  | grep -E "shot |ERROR|SCRIPT|error" 
