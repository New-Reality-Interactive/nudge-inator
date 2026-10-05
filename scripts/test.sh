#!/usr/bin/env bash
# Runs every test: the NudgeEngine package, then the app tests on an iOS 26 simulator.
# Also builds the widget extension (it is a dependency of the app scheme).
# Env: SIMULATOR_NAME (default "iPhone 17"), SIMULATOR_OS (default "26.5").
set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_OS="${SIMULATOR_OS:-26.5}"
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

step "xcodebuild test (app + widget extension) on $SIMULATOR_NAME, iOS $SIMULATOR_OS"
xcodebuild test -project NudgeInator.xcodeproj -scheme NudgeInator \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
  -quiet || failed+=("app-tests")

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "PASS: all steps succeeded"
else
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
