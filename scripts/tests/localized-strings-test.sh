#!/usr/bin/env bash
# Tests scripts/check-localized-strings.sh (#500) over temporary Swift files. Needs no simulator or
# build, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
script="$PWD/scripts/check-localized-strings.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# write <line before> <line>: a Swift file whose lines 2 and 3 are the two given.
write() { printf '%s\n' "struct V {" "$1" "$2" "}" > "$work/V.swift"; }
# expect_fail <description> <line before> <line> <expected text in output>
expect_fail() {
  write "$2" "$3"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -ne 0 ] && grep -qF "$4" <<<"$out"; then echo "ok: $1"
  else echo "FAIL: $1 (status $status): $out" >&2; failures=$((failures + 1)); fi
}
# expect_pass <description> <line before> <line>
expect_pass() {
  write "$2" "$3"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -eq 0 ]; then echo "ok: $1"
  else echo "FAIL: $1 (status $status): $out" >&2; failures=$((failures + 1)); fi
}

lookup='    let body = String(localized: "Nudges will look like this.", comment: "Test nudge body.")'

expect_fail "a lookup with no marker fails, naming file and line" \
  '    let content = UNMutableNotificationContent()' "$lookup" "V.swift:3"
expect_pass "a marker naming an allowed reason passes" \
  '    // String needed: notification, which takes only a String' "$lookup"
expect_fail "a marker naming a reason not on the list fails" \
  '    // String needed: it was easier' "$lookup" "V.swift:3"
expect_fail "a marker with no reason fails" \
  '    // String needed:' "$lookup" "V.swift:3"
expect_fail "a marker on the line after doesn't count" \
  "$lookup" '    // String needed: notification' "V.swift:2"
expect_fail "an AttributedString lookup is a lookup too" \
  '    var text = AttributedString()' '    text = AttributedString(localized: counts)' "V.swift:3"
expect_pass "a marked AttributedString lookup passes" \
  '    // String needed: styled, bold on part of the sentence' '    var text = AttributedString(localized: counts)'
expect_pass "a LocalizedStringResource is no lookup" \
  '    let x = 1' '    let note = LocalizedStringResource("Off", comment: "Settings row.")'
expect_pass "the words in a comment are no lookup" \
  '    let x = 1' '    /// Uses String(localized:) when it leaves the app.'

[ "$failures" -eq 0 ]
