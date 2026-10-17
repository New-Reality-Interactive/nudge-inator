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
(cd Packages/NudgeEngine && xcodebuild test -scheme NudgeEngine -destination 'platform=macOS' \
  -derivedDataPath .build/xcode -quiet) || failed+=("package-tests")

step "The color sets match DESIGN.md"
colors="$(mktemp -d)/Assets.xcassets"
if ! { scripts/generate-color-sets.sh "$colors" > /dev/null && diff -r "$colors" App/Resources/Assets.xcassets; }; then
  echo "FAIL: run scripts/generate-color-sets.sh, then update ColorSetTests" >&2
  failed+=("color-sets")
fi

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
    -derivedDataPath .build/derived -quiet || failed+=("app-tests-$os")
done

# The app build also builds NudgeEngine, so its .stringsdata covers both catalogs.
step "The String Catalogs hold every string the code shows"
scripts/sync-strings.sh --check .build/derived || failed+=("string-catalogs")

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "PASS: all steps succeeded"
else
  echo "FAIL: ${failed[*]}" >&2
  exit 1
fi
