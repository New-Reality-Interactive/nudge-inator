#!/usr/bin/env bash
# Tests scripts/check-list-row-insets.sh (#351) over temporary Swift files. Needs no simulator or
# build, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
script="$PWD/scripts/check-list-row-insets.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# expect_fail <description> <swift line> <expected text in output>
expect_fail() {
  printf '%s\n' "struct V {" "$2" "}" > "$work/V.swift"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -ne 0 ] && grep -qF "$3" <<<"$out"; then echo "ok: $1"
  else echo "FAIL: $1 (status $status): $out" >&2; failures=$((failures + 1)); fi
}
# expect_pass <description> <swift line>
expect_pass() {
  printf '%s\n' "struct V {" "$2" "}" > "$work/V.swift"
  out="$("$script" "$work" 2>&1)"; status=$?
  if [ "$status" -eq 0 ]; then echo "ok: $1"
  else echo "FAIL: $1 (status $status): $out" >&2; failures=$((failures + 1)); fi
}

expect_fail "empty EdgeInsets fails, naming file and line" \
  '    .listRowInsets(EdgeInsets())' "V.swift:2"
expect_fail "all four edges zero fails" \
  '    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))' "V.swift:2"
expect_pass "zero insets with a reason comment pass" \
  '    .listRowInsets(EdgeInsets()) // the card draws its own margins'
expect_pass "explicit design-system insets pass" \
  '    .listRowInsets(EdgeInsets(top: Design.Spacing.s1, leading: Design.Spacing.margin, bottom: Design.Spacing.s1, trailing: Design.Spacing.margin))'
expect_pass "zero on some edges only passes" \
  '    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))'
expect_fail "a bare // with no reason fails" \
  '    .listRowInsets(EdgeInsets()) //' "V.swift:2"

[ "$failures" -eq 0 ]
