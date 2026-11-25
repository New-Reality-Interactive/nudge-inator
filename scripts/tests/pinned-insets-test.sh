#!/usr/bin/env bash
# Tests scripts/check-pinned-insets.sh (#516) over temporary Swift files. Needs no simulator or
# build, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
script="$PWD/scripts/check-pinned-insets.sh"

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

expect_fail "a pinned inset with no reason fails, naming file and line" "V.swift:2" \
  '    .safeAreaInset(edge: .top, spacing: 0) { Banner() }'
expect_pass "a reason on the line before passes" \
  '    // Pinned: one button, moved into the form at large text.' \
  '    .safeAreaInset(edge: .bottom) {'
expect_fail "a marker with no reason fails" "V.swift:3" \
  '    // Pinned:' \
  '    .safeAreaInset(edge: .bottom) {'
expect_fail "a reason two lines up fails" "V.swift:4" \
  '    // Pinned: one button.' \
  '    .padding()' \
  '    .safeAreaInset(edge: .bottom) {'
expect_fail "another comment on the line before fails" "V.swift:3" \
  '    // The button.' \
  '    .safeAreaInset(edge: .bottom) {'
expect_pass "a comment that names the modifier passes" \
  '    /// Pinned with .safeAreaInset(edge: .top), the banner pushed the control away.'
expect_pass "the safe area insets property passes" \
  '    let bottom = proxy.safeAreaInsets(for: .all)'

[ "$failures" -eq 0 ]
