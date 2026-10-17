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
  grep -E '✘ Test|Test run with|error:|\*\* TEST (SUCCEEDED|FAILED)' "$log" || true
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

for os in $SIMULATOR_OSES; do
  step "iOS $os simulator runtime is installed"
  if ! xcrun simctl list runtimes | grep -q "iOS $os "; then
    echo "FAIL: no iOS $os simulator runtime. Install it: xcodebuild -downloadPlatform iOS -buildVersion $os" >&2
    failed+=("runtime-$os")
    continue
  fi
  step "xcodebuild test (app + widget extension) on $SIMULATOR_NAME, iOS $os"
  xcodebuild_logged "$logs/app-ios-$os.log" test -project NudgeInator.xcodeproj -scheme NudgeInator \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$os" \
    -derivedDataPath .build/derived || failed+=("app-tests-$os")
done

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
