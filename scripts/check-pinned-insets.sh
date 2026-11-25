#!/usr/bin/env bash
# Fails on a .safeAreaInset( whose line before doesn't say why its content may be pinned (#516):
# `// Pinned: <reason>`. Pinned content doesn't scroll, so words pinned above a scroll view grew
# taller than the screen at the largest text size and pushed the Mine | Sent control over the
# title (CODING_STANDARDS.md, SwiftUI).
# Usage: scripts/check-pinned-insets.sh <dir>...
# Limits: it reads lines and knows .safeAreaInset( alone, so words pinned by a .safeAreaBar are the
# review's to catch; any words after the marker count as a reason.
set -uo pipefail

files=()
while IFS= read -r file; do files+=("$file"); done < <(find "$@" -name '*.swift' -type f | sort)
[ ${#files[@]} -eq 0 ] && exit 0

awk '
  FNR == 1 { previous = "" }
  {
    code = $0
    sub(/^[[:space:]]*\/\/.*/, "", code)
    if (code ~ /safeAreaInset\(/ && previous !~ /^[[:space:]]*\/\/ Pinned:[[:space:]]*[^[:space:]]/) {
      printf "FAIL: %s:%d pins content that never scrolls: move it into the scroll view, or put // Pinned: <reason> on the line before (CODING_STANDARDS.md, SwiftUI)\n", FILENAME, FNR > "/dev/stderr"
      failed = 1
    }
    previous = $0
  }
  END { exit failed }
' "${files[@]}"
