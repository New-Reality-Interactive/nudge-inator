#!/usr/bin/env bash
# Runs every test: the NudgeEngine package, then the app tests on EACH simulator in the test
# matrix (one per iOS version, named for it). Also builds the widget extension (it is a dependency
# of the app scheme).
# Env: SIMULATORS (simulator names separated by ";", default the iOS 26.5 and 27.0 ones below).
# SIMULATORS= (set but empty) runs only the steps that need no simulator, as CI does.
set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATORS="${SIMULATORS-iPhone 15 Pro - iOS 26.5;iPhone 15 - iOS 27.0}"
IFS=';' read -r -a simulators <<< "$SIMULATORS"
failed=()

step() { echo; echo "==> $1"; }

# Each xcodebuild's full output goes to a log here; only its results are printed.
logs="$PWD/.build/test-logs"
mkdir -p "$logs"

# Runs xcodebuild with its whole output in the log $1, and prints only the results: each test
# run's count, failed tests, errors and the verdict. Not -quiet, which hides Swift Testing's lines
# and so the counts. Errors are the compiler's (`file:line:col: error:`) and xcodebuild's own, not
# any line with "error:": the app's tests log hundreds of "CoreData: error" lines on purpose.
# Returns xcodebuild's status.
xcodebuild_logged() {
  local log="$1"; shift
  xcodebuild "$@" > "$log" 2>&1
  local status=$?
  grep -E '✘ Test|Test run with|:[0-9]+:[0-9]+: error:|^(xcodebuild: )?error:|^Testing failed:|\*\* TEST (BUILD |EXECUTE )?(SUCCEEDED|FAILED)' "$log" || true
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
if non_foundation_imports Packages/NudgeEngine/Sources/NudgeEngine | grep .; then
  echo "FAIL: NudgeEngine sources may only import Foundation" >&2
  failed+=("engine-imports")
fi

# The device seed (#134), a second target of the engine's package, is pure Swift too: Foundation and
# the engine. Its tests run in the engine's xcodebuild test below.
step "NudgeDeviceSeed imports only Foundation and NudgeEngine"
if non_foundation_imports Packages/NudgeEngine/Sources/NudgeDeviceSeed | grep -v ' import NudgeEngine' | grep .; then
  echo "FAIL: NudgeDeviceSeed sources may only import Foundation and NudgeEngine" >&2
  failed+=("seed-imports")
fi

# AlarmKit's authorization read is a synchronous call that froze the iPhone for 69 s on the main
# thread (ticket 22). Only the system wrapper makes it, for AlarmAdapter to call off the main thread
# with a time limit (AGENTS.md, AlarmKit).
step "AlarmKit's authorization state is read only in AlarmManaging.swift"
if grep -rn --include='*.swift' 'AlarmManager\.shared\.authorizationState' App NudgeWidgets Packages/NudgeShared \
  | grep -v '^App/Alarms/AlarmManaging\.swift:'; then
  echo "FAIL: read it through AlarmAdapter (permissions(updating:)), not AlarmManager directly" >&2
  failed+=("alarm-authorization-read")
fi

# sync-strings.sh only marks a removed string with plural variants as stale, and its check passes, so
# one stays in the catalog unless someone sees it (#139).
step "String Catalogs hold no stale strings"
if grep -l '"extractionState" : "stale"' App/Resources/*.xcstrings Packages/NudgeEngine/Sources/NudgeEngine/*.xcstrings; then
  echo "FAIL: delete the stale entries from these catalogs" >&2
  failed+=("stale-strings")
fi

# chevron.right points the wrong way in right-to-left languages (#121).
step "Chevrons use chevron.forward"
if grep -rn --include='*.swift' 'chevron\.right' App NudgeWidgets Packages; then
  echo "FAIL: use chevron.forward" >&2
  failed+=("chevron-right")
fi

# App/Resources/PrivacyInfo.xcprivacy gives UserDefaults the reason CA92.1: the app reading its own
# standard defaults. A suite would be a different reason (1C8F.1 for the App Group's), and the widget
# has no manifest, so a UserDefaults there would be an undeclared required reason API. Shipped
# sources only: the tests make suites on purpose. NudgeShared counts as the widget's, which links it.
step "UserDefaults stays within the privacy manifest"
defaults_ok=true
if grep -rn --include='*.swift' 'UserDefaults(suiteName:' App NudgeWidgets Packages/NudgeShared Packages/NudgeEngine/Sources; then
  defaults_ok=false
fi
if grep -rn --include='*.swift' 'UserDefaults' NudgeWidgets Packages/NudgeShared; then
  defaults_ok=false
fi
if ! $defaults_ok; then
  echo "FAIL: App/Resources/PrivacyInfo.xcprivacy declares UserDefaults as CA92.1 (the app's own standard defaults) and the widget has no manifest: update the manifest first" >&2
  failed+=("userdefaults-manifest")
fi

# xcodebuild, not `swift test`: SwiftPM's command line copies the engine's String Catalog without
# compiling it, so every string would fall back to its key and plural variants would never apply.
step "xcodebuild test (NudgeEngine, macOS)"
(cd Packages/NudgeEngine && xcodebuild_logged "$logs/engine-macos.log" test -scheme NudgeEngine \
  -destination 'platform=macOS' -derivedDataPath .build/xcode) || failed+=("package-tests")

scratch="$(mktemp -d)"

# Leaves the Mac as the run found it: the simulators this run booted are shut down, pass or fail
# (an exit trap), and one that was already booted stays booted. Same rule as scripts/screenshots.sh.
shut_down_at_exit=() # UDIDs of simulators that were shut down when the run began
test_pids=()         # the side-by-side test runs, still going if the script is interrupted
cleanup() {
  # Stop an interrupted run's xcodebuilds (each a child of its subshell) before shutting down the
  # simulators under them and removing the files they write to.
  for pid in ${test_pids[@]+"${test_pids[@]}"}; do
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
  done
  [ ${#test_pids[@]} -eq 0 ] || wait 2>/dev/null
  rm -rf "$scratch"
  for udid in ${shut_down_at_exit[@]+"${shut_down_at_exit[@]}"}; do
    xcrun simctl shutdown "$udid" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

# Prints the UDID of the available simulator named exactly $1, or nothing.
simulator_udid() {
  xcrun simctl list devices available | awk -v name="$1" '
    { line = $0; sub(/^ +/, "", line) }
    index(line, name " (") == 1 {
      match(line, /[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr(line, RSTART, RLENGTH); exit }'
}

# The iOS 26.5 simulator's own mediaanalysisd (its Photos analysis daemon) ran away after every boot,
# 700-870% of a CPU for as long as the simulator was up, with no app or test involved; 26.1's did not.
# Nothing here uses Photos, Vision or Live Text, so it is switched off in each simulator, which
# persists across boots and is idempotent. Undo: `xcrun simctl spawn <udid> launchctl enable
# system/com.apple.mediaanalysisd`. Set KEEP_MEDIA_ANALYSIS=1 to leave it alone.
quiet_media_analysis() {
  [ "${KEEP_MEDIA_ANALYSIS:-0}" = 1 ] && return 0
  local name="$1" udid="$2"
  xcrun simctl boot "$udid" 2>/dev/null || true # already booted is fine
  xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
  xcrun simctl spawn "$udid" launchctl disable system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
  xcrun simctl spawn "$udid" launchctl bootout system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
  echo "mediaanalysisd switched off in the $name simulator, $udid"
}

found=() udids=()
# The +"..." form expands an empty list to nothing: bash 3.2 (macOS) calls it unbound under set -u.
for name in ${simulators[@]+"${simulators[@]}"}; do
  step "Simulator \"$name\" exists"
  udid="$(simulator_udid "$name")"
  if [ -z "$udid" ]; then
    if [[ "$name" == *" - iOS "* ]]; then
      # Names follow "<device type> - iOS <version>", so the hint can name both.
      os="${name##* - iOS }"
      echo "FAIL: no simulator named \"$name\". Create it:" \
        "xcrun simctl create \"$name\" \"${name% - iOS *}\" com.apple.CoreSimulator.SimRuntime.iOS-${os//./-}" >&2
    else
      echo "FAIL: no simulator named \"$name\". Create it with xcrun simctl create (README)." >&2
    fi
    failed+=("simulator-$name")
    continue
  fi
  # Recorded before anything boots it (quiet_media_analysis, or xcodebuild itself).
  xcrun simctl list devices | grep -q "$udid) (Booted)" || shut_down_at_exit+=("$udid")
  quiet_media_analysis "$name" "$udid"
  found+=("$name") udids+=("$udid")
done

# One build for every simulator: they share the SDK and architecture, so a second build compiled
# nothing anyway. It also keeps the newest build log the one that compiled, which is the log
# xcode-build-server reads for VS Code's code completion (README).
if [ ${#udids[@]} -gt 0 ]; then
  step "xcodebuild build-for-testing (app + widget extension)"
  if xcodebuild_logged "$logs/app-build.log" build-for-testing -project NudgeInator.xcodeproj \
    -scheme NudgeInator -destination "platform=iOS Simulator,id=${udids[0]}" -derivedDataPath .build/derived; then
    # The simulators test side by side from that one build. A background job can't add to `failed`,
    # so each writes its printed results to its own file in $scratch. They are shown one simulator
    # at a time, in order, as each finishes, so the results don't interleave (and show nothing live).
    for i in "${!udids[@]}"; do
      (xcodebuild_logged "$logs/app-${found[$i]}.log" test-without-building -project NudgeInator.xcodeproj \
        -scheme NudgeInator -destination "platform=iOS Simulator,id=${udids[$i]}" \
        -derivedDataPath .build/derived > "$scratch/results-${found[$i]}" 2>&1) &
      test_pids+=($!)
    done
    for i in "${!udids[@]}"; do
      wait "${test_pids[$i]}" || failed+=("app-tests-${found[$i]}")
      step "xcodebuild test-without-building on ${found[$i]}"
      cat "$scratch/results-${found[$i]}"
    done
  else
    failed+=("app-build")
  fi
fi

# The app build also builds NudgeEngine, so its .stringsdata covers both catalogs. With no
# simulator there was no app build to check.
if [ ${#udids[@]} -gt 0 ]; then
  step "The String Catalogs hold every string the code shows"
  scripts/sync-strings.sh --check .build/derived || failed+=("string-catalogs")
  if ! diff "$scratch/InfoPlist.xcstrings" App/Resources/InfoPlist.xcstrings; then
    echo "FAIL: the build added Info.plist keys to App/Resources/InfoPlist.xcstrings: give each a comment and commit it" >&2
    failed+=("infoplist-strings")
  fi
fi

# The device seed is Debug-only (#134). Builds Release for the simulator, which needs the SDK but
# no simulator to be booted; skipped with the simulator steps, as CI runs them.
if [ ${#udids[@]} -gt 0 ]; then
  step "A Release build holds no device-seed code"
  scripts/check-release-has-no-seed.sh || failed+=("release-has-seed")
fi

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "PASS: all steps succeeded"
else
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
