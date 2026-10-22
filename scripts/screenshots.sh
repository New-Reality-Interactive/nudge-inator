#!/usr/bin/env bash
# Takes a screenshot of every screen of the app on each simulator in the test matrix, in portrait,
# landscape and the largest text size, for checking the app against the mockup. Builds a throwaway
# harness (scripts/screenshots/) into .build/screenshots: the app's sources with a stand-in @main
# over the test fakes, seeded with the mockup's reminders, and a UI test that walks the screens.
# Nothing touches the app's own install or data. Each simulator's text size and appearance are put
# back afterwards, the harness app and its UI-test runner (bundle IDs from
# scripts/screenshots/project.yml) are uninstalled, and a simulator it booted is shut down.
# Env: SIMULATORS (as scripts/test.sh), SHOTS_OUT (default docs/screenshots/<today>, git-ignored),
# SHOTS_VARIANTS (default "portrait landscape largest-text").
# Writes <SHOTS_OUT>/<simulator>/<portrait|landscape|largest-text>/<screen>.png.
set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATORS="${SIMULATORS-iPhone 15 Pro - iOS 26.5;iPhone 15 - iOS 27.0}"
IFS=';' read -r -a simulators <<< "$SIMULATORS"
out="${SHOTS_OUT:-docs/screenshots/$(date +%F)}"
read -r -a variants <<< "${SHOTS_VARIANTS:-portrait landscape largest-text}"
out="$(mkdir -p "$out" && cd "$out" && pwd)"
build=.build/screenshots
logs="$PWD/.build/test-logs"
mkdir -p "$build/Generated" "$logs"

# The fakes, minus their `@testable import`: in the harness they compile into the app itself.
grep -v '^@testable import NudgeInator$' NudgeInatorTests/Fakes.swift > "$build/Generated/Fakes.swift"
xcodegen generate --quiet --spec scripts/screenshots/project.yml --project "$build" || exit 1

# As scripts/test.sh: the UDID of the available simulator named exactly $1, or nothing.
simulator_udid() {
  xcrun simctl list devices available | awk -v name="$1" '
    { line = $0; sub(/^ +/, "", line) }
    index(line, name " (") == 1 {
      match(line, /[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr(line, RSTART, RLENGTH); exit }'
}

restore=()
cleanup() {
  for entry in ${restore[@]+"${restore[@]}"}; do
    IFS='|' read -r udid size appearance was_booted <<< "$entry"
    xcrun simctl ui "$udid" content_size "$size" 2>/dev/null
    xcrun simctl ui "$udid" appearance "$appearance" 2>/dev/null
    xcrun simctl uninstall "$udid" com.newrealityinteractive.nudgeinator.shots 2>/dev/null
    xcrun simctl uninstall "$udid" com.newrealityinteractive.nudgeinator.shots.uitests.xctrunner 2>/dev/null
    $was_booted || xcrun simctl shutdown "$udid" 2>/dev/null
  done
}
trap cleanup EXIT

failed=()
built=false
for name in ${simulators[@]+"${simulators[@]}"}; do
  udid="$(simulator_udid "$name")"
  if [ -z "$udid" ]; then
    echo "FAIL: no simulator named \"$name\" (see scripts/test.sh)" >&2
    failed+=("$name")
    continue
  fi
  was_booted=false
  xcrun simctl list devices | grep -q "$udid) (Booted)" && was_booted=true
  xcrun simctl boot "$udid" 2>/dev/null || true # already booted is fine
  xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
  restore+=("$udid|$(xcrun simctl ui "$udid" content_size)|$(xcrun simctl ui "$udid" appearance)|$was_booted")
  xcrun simctl ui "$udid" appearance light

  if ! $built; then
    echo "==> Building the harness"
    xcodebuild build-for-testing -project "$build/NudgeShots.xcodeproj" -scheme NudgeShots \
      -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$build/derived" \
      > "$logs/screenshots-build.log" 2>&1 || { echo "FAIL: see $logs/screenshots-build.log" >&2; exit 1; }
    built=true
  fi

  for variant in "${variants[@]}"; do
    echo "==> $name, $variant"
    size=large orientation=portrait
    [ "$variant" = landscape ] && orientation=landscape
    [ "$variant" = largest-text ] && size=accessibility-extra-extra-extra-large
    xcrun simctl ui "$udid" content_size "$size"
    dir="$out/$name/$variant"
    rm -rf "$dir" && mkdir -p "$dir"
    log="$logs/screenshots-$name-$variant.log"
    TEST_RUNNER_SHOTS_DIR="$dir" TEST_RUNNER_SHOTS_ORIENTATION="$orientation" \
      xcodebuild test-without-building -project "$build/NudgeShots.xcodeproj" -scheme NudgeShots \
      -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$build/derived" > "$log" 2>&1 \
      || { echo "FAIL: see $log" >&2; failed+=("$name/$variant"); }
    echo "$(ls "$dir" | wc -l | tr -d ' ') screenshots in $dir"
  done
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
echo "Screenshots: $out"
