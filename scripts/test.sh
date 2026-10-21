#!/usr/bin/env bash
# Runs every test: the NudgeEngine package, then the app tests on EACH simulator in the test
# matrix (one per iOS version, named for it). Also builds the widget extension (it is a dependency
# of the app scheme).
# Env: SIMULATORS (simulator names separated by ";", default the iOS 26.5 and 27.0 ones below).
set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATORS="${SIMULATORS:-iPhone 15 Pro - iOS 26.5;iPhone 15 - iOS 27.0}"
IFS=';' read -r -a simulators <<< "$SIMULATORS"
failed=()

step() { echo; echo "==> $1"; }

# Each xcodebuild's full output goes to a log here; only its results are printed.
logs="$PWD/.build/test-logs"
mkdir -p "$logs"

# Runs xcodebuild with its whole output in the log $1, and prints only the results: each test
# run's count, failed tests, errors and the verdict. Not -quiet, which hides Swift Testing's lines
# and so the counts. Returns xcodebuild's status.
xcodebuild_logged() {
  local log="$1"; shift
  xcodebuild "$@" > "$log" 2>&1
  local status=$?
  grep -E '✘ Test|Test run with|error:|\*\* TEST (BUILD |EXECUTE )?(SUCCEEDED|FAILED)' "$log" || true
  [ $status -eq 0 ] || echo "Full output: $log" >&2
  return $status
}

# Prints every import of a module other than Foundation in the .swift files under $1. Matches the
# whole import grammar (attributes such as @preconcurrency, Swift 6 access levels such as
# `public import`, and kinds such as `import struct X.Y`), so none of those forms slips past.
non_foundation_imports() {
  perl -MFile::Find -e '
    my $import = qr/^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(\w+)/;
    find(sub {
      return unless /\.swift\z/;
      open(my $fh, "<", $_) or die "$File::Find::name: $!\n";
      while (<$fh>) { print "$File::Find::name:$.: $_" if /$import/ && $1 ne "Foundation" }
      close $fh;
    }, shift);
  ' "$1"
}

step "NudgeEngine imports no Apple framework (Foundation only)"
if non_foundation_imports Packages/NudgeEngine/Sources | grep .; then
  echo "FAIL: NudgeEngine sources may only import Foundation" >&2
  failed+=("engine-imports")
fi

# xcodebuild, not `swift test`: SwiftPM's command line copies the engine's String Catalog without
# compiling it, so every string would fall back to its key and plural variants would never apply.
step "xcodebuild test (NudgeEngine, macOS)"
(cd Packages/NudgeEngine && xcodebuild_logged "$logs/engine-macos.log" test -scheme NudgeEngine \
  -destination 'platform=macOS' -derivedDataPath .build/xcode) || failed+=("package-tests")

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Only the color sets: the catalog may hold other assets the script doesn't write.
step "The color sets match DESIGN.md"
colors="$scratch/Assets.xcassets"
colors_ok=true
scripts/generate-color-sets.sh "$colors" > /dev/null || colors_ok=false
for set in "$colors"/*.colorset App/Resources/Assets.xcassets/*.colorset; do
  name="$(basename "$set")"
  diff -r "$colors/$name" "App/Resources/Assets.xcassets/$name" || colors_ok=false
done
if ! $colors_ok; then
  echo "FAIL: run scripts/generate-color-sets.sh, then update ColorSetTests" >&2
  failed+=("color-sets")
fi

# The app build adds Info.plist keys it finds to InfoPlist.xcstrings. A change means a key (and
# its comment) wasn't committed.
cp App/Resources/InfoPlist.xcstrings "$scratch/InfoPlist.xcstrings"

step "xcodegen generate"
xcodegen generate --quiet || failed+=("xcodegen")

# The iOS 26.5 simulator's own mediaanalysisd (its Photos analysis daemon) ran away after every boot,
# 700-870% of a CPU for as long as the simulator was up, with no app or test involved; 26.1's did not.
# Nothing here uses Photos, Vision or Live Text, so it is switched off in each simulator, which
# persists across boots and is idempotent. Undo: `xcrun simctl spawn <udid> launchctl enable
# system/com.apple.mediaanalysisd`. Set KEEP_MEDIA_ANALYSIS=1 to leave it alone.
# Prints the UDID of the available simulator named exactly $1, or nothing.
simulator_udid() {
  xcrun simctl list devices available | awk -v name="$1" '
    { line = $0; sub(/^ +/, "", line) }
    index(line, name " (") == 1 {
      match(line, /[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr(line, RSTART, RLENGTH); exit }'
}

quiet_media_analysis() {
  [ "${KEEP_MEDIA_ANALYSIS:-0}" = 1 ] && return 0
  local name="$1" udid="$2"
  xcrun simctl boot "$udid" 2>/dev/null || true # already booted is fine
  xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
  xcrun simctl spawn "$udid" launchctl disable system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
  xcrun simctl spawn "$udid" launchctl bootout system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
  echo "mediaanalysisd switched off in the $name simulator, $udid"
}

udids=()
for name in "${simulators[@]}"; do
  step "Simulator \"$name\" exists"
  udid="$(simulator_udid "$name")"
  if [ -z "$udid" ]; then
    echo "FAIL: no simulator named \"$name\". Create it, for example:" \
      "xcrun simctl create \"$name\" \"iPhone 15 Pro\" com.apple.CoreSimulator.SimRuntime.iOS-26-5" >&2
    failed+=("simulator-$name")
    continue
  fi
  quiet_media_analysis "$name" "$udid"
  udids+=("$udid")
done

# One build for every simulator: they share the SDK and architecture, so a second build compiled
# nothing anyway. It also keeps the newest build log the one that compiled, which is the log
# xcode-build-server reads for VS Code's code completion (README).
if [ ${#udids[@]} -gt 0 ]; then
  step "xcodebuild build-for-testing (app + widget extension)"
  if xcodebuild_logged "$logs/app-build.log" build-for-testing -project NudgeInator.xcodeproj \
    -scheme NudgeInator -destination "platform=iOS Simulator,id=${udids[0]}" -derivedDataPath .build/derived; then
    for name in "${simulators[@]}"; do
      udid="$(simulator_udid "$name")"
      [ -n "$udid" ] || continue
      step "xcodebuild test-without-building on $name"
      xcodebuild_logged "$logs/app-$name.log" test-without-building -project NudgeInator.xcodeproj \
        -scheme NudgeInator -destination "platform=iOS Simulator,id=$udid" \
        -derivedDataPath .build/derived || failed+=("app-tests-$name")
    done
  else
    failed+=("app-build")
  fi
fi

# The app build also builds NudgeEngine, so its .stringsdata covers both catalogs.
step "The String Catalogs hold every string the code shows"
scripts/sync-strings.sh --check .build/derived || failed+=("string-catalogs")
if ! diff "$scratch/InfoPlist.xcstrings" App/Resources/InfoPlist.xcstrings; then
  echo "FAIL: the build added Info.plist keys to App/Resources/InfoPlist.xcstrings: give each a comment and commit it" >&2
  failed+=("infoplist-strings")
fi

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "PASS: all steps succeeded"
else
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
