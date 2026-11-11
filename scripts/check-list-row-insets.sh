#!/usr/bin/env bash
# Fails when a list row's insets are zeroed on every edge without a reason (#351). A zeroed row
# lets its content touch the screen's edges (the Disconnect sheet's lead text was clipped, #197).
# Allowed: explicit insets, or a `// <reason>` comment on the same line.
# Usage: scripts/check-list-row-insets.sh <dir>...
# Limits: it reads one line at a time and knows two spellings (EdgeInsets() and four literal 0s), so a
# call split over lines, `.init()`, `0.0` or a constant slips through; any `// word` counts as a reason.
set -uo pipefail
status=0
zero='(EdgeInsets\(\)|EdgeInsets\(top: *0, *leading: *0, *bottom: *0, *trailing: *0\))'
while IFS=: read -r file line text; do
  # A reason is a // comment with at least one word after it.
  if grep -qE '//[[:space:]]*[^[:space:]]' <<<"$text"; then continue; fi
  echo "FAIL: $file:$line zeroes a list row's insets on every edge: give explicit insets or add a // reason on the line" >&2
  status=1
done < <(grep -rnE --include='*.swift' "listRowInsets\( *$zero *\)" "$@")
exit $status
