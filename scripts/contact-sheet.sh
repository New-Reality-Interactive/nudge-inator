#!/usr/bin/env bash
# One image of several screenshots side by side, each captioned with its folder and name, for
# comparing a mockup's screens (scripts/mockup-shots.py) with the app's (scripts/screenshots.sh).
# Pass them in pairs, mockup then app, to put each pair together. Needs Google Chrome.
# Usage: scripts/contact-sheet.sh <out.png> <width per image> <columns> <image> [image ...]
set -euo pipefail
out="$1" width="$2" columns="$3"
shift 3
html="${out%.png}.html"
{
  echo "<html><body style='margin:0;background:#888;font:12px sans-serif'>"
  echo "<div style='display:grid;grid-template-columns:repeat($columns,${width}px);gap:6px;padding:6px'>"
  for image in "$@"; do
    echo "<figure style='margin:0'><img src='file://$image' style='width:${width}px;display:block'>"
    echo "<figcaption>$(basename "$(dirname "$image")")/$(basename "$image")</figcaption></figure>"
  done
  echo "</div></body></html>"
} > "$html"
ratio=$(sips -g pixelHeight -g pixelWidth "$1" | awk '/pixelHeight/{h=$2}/pixelWidth/{w=$2}END{print h/w}')
rows=$(( ($# + columns - 1) / columns ))
height=$(python3 -c "print(int($rows * ($width * $ratio + 26) + 20))")
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --allow-file-access-from-files --screenshot="$out" --window-size=$(( columns * (width + 6) + 12 )),"$height" \
  "file://$html" > /dev/null 2>&1
echo "$out"
