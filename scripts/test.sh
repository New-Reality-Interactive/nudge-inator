#!/usr/bin/env bash
# Runs every test: the NudgeEngine package, then the app tests on an iOS 26 simulator for EACH
# iOS version in the test matrix (the oldest and the newest we support).
# Also builds the widget extension (it is a dependency of the app scheme).
# Env: SIMULATOR_NAME (default "iPhone 17"), SIMULATOR_OSES (space-separated, default "26.1 26.5").
set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_OSES="${SIMULATOR_OSES:-26.1 26.5}"
failed=()

step() { echo; echo "==> $1"; }

step "NudgeEngine imports no Apple framework (Foundation only)"
if grep -rnE '^\s*(@testable\s+)?import\s+' Packages/NudgeEngine/Sources | grep -vE 'import\s+Foundation\s*$'; then
  echo "FAIL: NudgeEngine sources may only import Foundation" >&2
  failed+=("engine-imports")
fi

step "swift test (NudgeEngine)"
(cd Packages/NudgeEngine && swift test) || failed+=("package-tests")

step "xcodegen generate"
xcodegen generate --quiet || failed+=("xcodegen")

for os in $SIMULATOR_OSES; do
  step "iOS $os simulator runtime is installed"
  if ! xcrun simctl list runtimes | grep -q "iOS $os "; then
    echo "FAIL: no iOS $os simulator runtime. Install it: xcodebuild -downloadPlatform iOS -buildVersion $os" >&2
    failed+=("runtime-$os")
    continue
  fi
  step "xcodebuild test (app + widget extension) on $SIMULATOR_NAME, iOS $os"
  xcodebuild test -project NudgeInator.xcodeproj -scheme NudgeInator \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$os" \
    -quiet || failed+=("app-tests-$os")
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "PASS: all steps succeeded"
else
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
