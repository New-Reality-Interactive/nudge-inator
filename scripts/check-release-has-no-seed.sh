#!/usr/bin/env bash
# Checks that a Release build of the app holds no device-seed code (#134): the seed loads test data
# on a phone for manual checks and exists in Debug builds only.
#   scripts/check-release-has-no-seed.sh                 builds Release for the simulator, then checks it
#   scripts/check-release-has-no-seed.sh <path>.app      checks that app (the archive script's)
# Looks for the seed's own names in the app's executables: its module, launch variable, record key,
# types and a set's reminder title. Any one found fails.
set -uo pipefail
cd "$(dirname "$0")/.."

app="${1:-}"
if [ -z "$app" ]; then
  xcodegen generate --quiet || { echo "FAIL: xcodegen generate" >&2; exit 1; }
  derived=".build/derived-release"
  log=".build/test-logs/release-build.log"
  mkdir -p "$(dirname "$log")"
  xcodebuild build -project NudgeInator.xcodeproj -scheme NudgeInator -configuration Release \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
    CODE_SIGNING_ALLOWED=NO > "$log" 2>&1 || { echo "FAIL: the Release build (see $log)" >&2; exit 1; }
  app="$derived/Build/Products/Release-iphonesimulator/NudgeInator.app"
fi

[ -f "$app/NudgeInator" ] || { echo "FAIL: no executable at $app/NudgeInator" >&2; exit 1; }

# Every executable file in the bundle: the app, and any framework or extension a library might be
# linked into instead.
binaries=()
while IFS= read -r file; do
  binaries+=("$file")
done < <(find "$app" -type f \( -perm +111 -o -name "*.dylib" \))

found=0
text="$(mktemp)"
trap 'rm -f "$text"' EXIT
for binary in "${binaries[@]}"; do
  # To a file first: with pipefail, `grep -q` ending the pipe early makes `strings` fail, and a
  # match would read as no match.
  strings -a "$binary" > "$text"
  for name in NudgeDeviceSeed NUDGE_SEED DeviceSeedLaunch ModelSeedTarget deviceSeedRecord SeedRecordStore "Café meeting with Sam"; do
    if grep -q -- "$name" "$text"; then
      echo "FAIL: $name is in the Release build, in $binary" >&2
      found=1
    fi
  done
done
# The debug dylib Xcode splits Debug builds into must not be there either.
if ls "$app"/*.debug.dylib > /dev/null 2>&1; then
  echo "FAIL: $app is a Debug build" >&2
  found=1
fi
[ $found -eq 0 ] && echo "OK: no device-seed code in $app"
exit $found
