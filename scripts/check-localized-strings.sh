#!/usr/bin/env bash
# Fails on an immediate lookup, String(localized:) or AttributedString(localized:), whose line before
# doesn't carry the marker `// String needed: <reason>` with a reason from the list below (#500).
# Text the app holds for a screen is a LocalizedStringResource that SwiftUI resolves as it draws
# (CODING_STANDARDS.md, Localization); a lookup is only for text an API takes as a String.
# Usage: scripts/check-localized-strings.sh <dir>...
# Limits: it reads lines, so a lookup in a string literal counts, and one split as `String(` then
# `localized:` on the next line slips through.
set -uo pipefail

# The allowed reasons, which CODING_STANDARDS.md lists: each is the first word or words after the
# marker, and the rest of the comment says more.
reasons='notification|invite|VoiceOver announcement|styled'

files=()
while IFS= read -r file; do files+=("$file"); done < <(find "$@" -name '*.swift' -type f | sort)
[ ${#files[@]} -eq 0 ] && exit 0

awk -v reasons="^[[:space:]]*// String needed: ($reasons)([[:space:]]|,|$)" '
  FNR == 1 { previous = "" }
  {
    code = $0
    sub(/^[[:space:]]*\/\/.*/, "", code)
    if (code ~ /(^|[^A-Za-z_])(Attributed)?String\(localized:/ && previous !~ reasons) {
      printf "FAIL: %s:%d looks words up as a String: hold them as a LocalizedStringResource, or put // String needed: <reason> on the line before (CODING_STANDARDS.md, Localization)\n", FILENAME, FNR > "/dev/stderr"
      failed = 1
    }
    previous = $0
  }
  END { exit failed }
' "${files[@]}"
