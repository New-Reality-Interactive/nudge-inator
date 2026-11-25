#!/usr/bin/env bash
# Tests scripts/check-localized-strings.sh (#500) over temporary Swift files. Needs no simulator or
# build, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
script="$PWD/scripts/check-localized-strings.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# expect_fail <description> <expected text in output> <swift line>...
expect_fail() {
  local description="$1" expected="$2"; shift 2
  printf '%s\n' "struct V {" "$@" "}" > "$work/V.swift"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -ne 0 ] && grep -qF "$expected" <<<"$out"; then echo "ok: $description"
  else echo "FAIL: $description (status $status): $out" >&2; failures=$((failures + 1)); fi
}
# expect_pass <description> <swift line>...
expect_pass() {
  local description="$1"; shift
  printf '%s\n' "struct V {" "$@" "}" > "$work/V.swift"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -eq 0 ]; then echo "ok: $description"
  else echo "FAIL: $description (status $status): $out" >&2; failures=$((failures + 1)); fi
}

lookup='    let body = String(localized: "Nudges will look like this.", comment: "Test nudge body.")'

expect_fail "a lookup with no marker fails, naming file and line" "V.swift:3" \
  '    let content = UNMutableNotificationContent()' "$lookup"
expect_pass "a marker naming an allowed reason passes" \
  '    // String needed: notification, which takes only a String' "$lookup"
expect_fail "a marker naming a reason not on the list fails" "V.swift:3" \
  '    // String needed: it was easier' "$lookup"
expect_fail "a marker with no reason fails" "V.swift:3" \
  '    // String needed:' "$lookup"
expect_fail "a marker on the line after doesn't count" "V.swift:2" \
  "$lookup" '    // String needed: notification'
expect_fail "an AttributedString lookup is a lookup too" "V.swift:3" \
  '    var text = AttributedString()' '    text = AttributedString(localized: counts)'
expect_pass "a marked AttributedString lookup passes" \
  '    // String needed: styled, bold on part of the sentence' '    var text = AttributedString(localized: counts)'
expect_pass "a LocalizedStringResource is no lookup" \
  '    let x = 1' '    let note = LocalizedStringResource("Off", comment: "Settings row.")'
expect_pass "the words in a comment are no lookup" \
  '    let x = 1' '    /// Uses String(localized:) when it leaves the app.'

expect_fail "a lookup split after String( fails, naming that line" "V.swift:3" \
  '    let content = UNMutableNotificationContent()' '    let body = String(' \
  '        localized: "Nudges will look like this.", comment: "Test nudge body.")'
expect_pass "a marker before the String( line passes a split lookup" \
  '    // String needed: notification' '    let body = String(' '        localized: "Nudges.")'
expect_fail "a split AttributedString lookup fails too" "V.swift:3" \
  '    var text = AttributedString()' '    text = AttributedString(' '        localized: counts)'
expect_pass "a marked split AttributedString lookup passes" \
  '    // String needed: styled' '    text = AttributedString(' '        localized: counts)'
expect_pass "a String( split before another argument is no lookup" \
  '    let x = 1' '    let body = String(' '        describing: x)'
expect_fail "whitespace after the bracket hides no lookup" "V.swift:3" \
  '    let x = 1' '    let body = String( localized: "Nudges.")'
expect_fail "a String.init lookup is a lookup too" "V.swift:3" \
  '    let x = 1' '    let body = String.init(localized: "Nudges.")'
expect_pass "a marked String.init lookup passes" \
  '    // String needed: notification' '    let body = String.init(localized: "Nudges.")'
expect_fail "a split String.init lookup fails too" "V.swift:3" \
  '    let x = 1' '    let body = String.init(' '        localized: "Nudges.")'
expect_fail "a blank line and a comment inside a split hide no lookup" "V.swift:3" \
  '    let x = 1' '    let body = String(' '' '        // The test nudge.' '        localized: "Nudges.")'
expect_fail "a lookup split before .init fails, naming the String line" "V.swift:3" \
  '    let x = 1' '    let body = String' '        .init(localized: "Nudges.")'
expect_pass "a marker before the String line passes a lookup split before .init" \
  '    // String needed: notification' '    let body = String' '        .init(localized: "Nudges.")'
expect_fail "a space before the bracket hides no lookup" "V.swift:3" \
  '    let x = 1' '    let body = String (localized: "Nudges.")'
expect_fail "a lookup split before the bracket fails too" "V.swift:3" \
  '    let x = 1' '    let body = String.init' '        (localized: "Nudges.")'
expect_fail "a lookup split over three lines fails too" "V.swift:3" \
  '    let x = 1' '    let body = String' '        .init(' '            localized: "Nudges.")'
expect_pass "a line ending in the type String is no lookup" \
  '    var name: String' '    var note = LocalizedStringResource("Off", comment: "Settings row.")'

[ "$failures" -eq 0 ]
