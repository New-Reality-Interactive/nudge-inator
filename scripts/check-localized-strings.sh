#!/usr/bin/env bash
# Fails on an immediate lookup, String(localized:) or AttributedString(localized:), also written
# String.init(localized:), whose line before doesn't carry the marker `// String needed: <reason>`
# with a reason from the list below (#500). For a lookup over several lines (#518), the marker goes
# before the line with `String`, which the failure names.
# Text the app holds for a screen is a LocalizedStringResource that SwiftUI resolves as it draws
# (CODING_STANDARDS.md, Localization); a lookup is only for text an API takes as a String.
# Usage: scripts/check-localized-strings.sh <dir>...
# Limits: it reads code as text, so a lookup in a string literal counts. A split lookup is caught with
# spaces, line breaks, blank lines and `//` comment lines between `String` and `localized:`. One slips
# through with a comment at the end of a line between those two, with a /* */ comment between them,
# or written `.init(localized:)` with the type left to inference.
set -uo pipefail

# The allowed reasons, which CODING_STANDARDS.md lists: each is the first word or words after the
# marker, and the rest of the comment says more.
reasons='notification|invite|VoiceOver announcement|styled'

files=()
while IFS= read -r file; do files+=("$file"); done < <(find "$@" -name '*.swift' -type f | sort)
[ ${#files[@]} -eq 0 ] && exit 0

awk -v reasons="^[[:space:]]*// String needed: ($reasons)([[:space:]]|,|$)" '
  function fail(line) {
    printf "FAIL: %s:%d looks words up as a String: hold them as a LocalizedStringResource, or put // String needed: <reason> on the line before (CODING_STANDARDS.md, Localization)\n", FILENAME, line > "/dev/stderr"
    failed = 1
  }
  # lookup: an immediate lookup, from the type name to its argument. started: as much of one as a line
  # can end with.
  BEGIN {
    lookup = "(Attributed)?String[[:space:]]*(\\.[[:space:]]*init[[:space:]]*)?\\([[:space:]]*localized:"
    started = "(Attributed)?String[[:space:]]*(\\.[[:space:]]*(init[[:space:]]*)?)?(\\([[:space:]]*)?$"
  }
  # pending: an unmarked lookup the lines so far stop partway through, from its type name on, or empty.
  # pending_line: the line that name is on.
  FNR == 1 { previous = ""; pending = "" }
  {
    code = $0
    sub(/^[[:space:]]*\/\/.*/, "", code)
    if (pending != "" && code ~ /[^[:space:]]/) {
      pending = pending " " code
      if (pending ~ "^" lookup) fail(pending_line)
      if (pending !~ "^" started) pending = ""
    }
    if (previous !~ reasons) {
      if (code ~ "(^|[^A-Za-z_])" lookup) fail(FNR)
      if (match(code, "(^|[^A-Za-z_])" started)) {
        pending = substr(code, RSTART)
        sub(/^[^A-Za-z_]/, "", pending)
        pending_line = FNR
      }
    }
    previous = $0
  }
  END { exit failed }
' "${files[@]}"
