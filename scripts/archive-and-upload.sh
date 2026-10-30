#!/usr/bin/env bash
# Takes the Release archive to App Store Connect as a TestFlight build (#99). The steps run apart:
#   scripts/archive-and-upload.sh         archives the release tag v<MARKETING_VERSION>, checks the
#                                         versions, and stops.
#   scripts/archive-and-upload.sh upload  uploads that archive. Run it only on the developer's go:
#                                         the upload publishes to App Store Connect.
# There is no separate validation step: xcodebuild accepts its `validation` method only with
# `destination: upload`, and run that way it sent the build to App Store Connect (1.2.0, #99).
# App Store Connect checks the build as it takes the upload. Uses the Apple ID signed into Xcode;
# no API key or other secret. Env: ALLOW_DIRTY=1 archives any commit or uncommitted changes as a
# trial (the release PR's), which can't be uploaded.
set -uo pipefail
cd "$(dirname "$0")/.."

mode="${1:-archive}"
out="$PWD/.build/release"
archive="$out/NudgeInator.xcarchive"
logs="$out/logs"
options="$PWD/scripts/export-options.plist"
archived="$out/archived"
dry_run="$out/dry-run"
mkdir -p "$logs"

fail() { echo "FAIL: $1" >&2; exit 1; }
step() { echo; echo "==> $1"; }
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }

# Runs xcodebuild with its whole output in the log $1; prints only errors, and where the log is.
xcodebuild_logged() {
  local log="$1"; shift
  xcodebuild "$@" > "$log" 2>&1
  local status=$?
  grep -E 'error: |\*\* (ARCHIVE|EXPORT) (SUCCEEDED|FAILED)' "$log" || true
  echo "Full output: $log"
  return $status
}

require_archive() {
  [ -d "$archive" ] || fail "no archive. Run scripts/archive-and-upload.sh first."
  [ ! -e "$dry_run" ] || fail "the archive is a trial (ALLOW_DIRTY). Archive the release tag, committed."
}

# Identifies the archive and the commit it was built from, so an upload can't send a build of
# another commit.
fingerprint() { echo "$(git rev-parse HEAD) $(plist "$archive/Info.plist" CreationDate)"; }

case "$mode" in
  archive)
    rm -rf "$archive" "$archived" "$dry_run"
    expected="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)"
    [ -n "$expected" ] || fail "no MARKETING_VERSION in project.yml"
    # The build is the release: taken from its pushed tag, never from a commit that may still move.
    if [ -n "$(git status --porcelain)" ] || ! git tag --points-at HEAD | grep -qx "v$expected"; then
      [ -n "${ALLOW_DIRTY:-}" ] || fail "check out the release tag v$expected, committed (ALLOW_DIRTY=1 for a trial)."
      touch "$dry_run"
    elif [ -z "$(git ls-remote --tags origin "refs/tags/v$expected")" ]; then
      fail "tag v$expected isn't pushed to origin. The release is tagged and pushed before its build."
    fi
    step "Archive (Release, scheme NudgeInator) at $(git rev-parse --short HEAD)"
    xcodegen generate > "$logs/xcodegen.log" 2>&1 || fail "xcodegen generate (see $logs/xcodegen.log)"
    xcodebuild_logged "$logs/archive.log" archive -project NudgeInator.xcodeproj -scheme NudgeInator \
      -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" \
      -allowProvisioningUpdates || fail "archive"

    step "Versions"
    app="$archive/Products/Applications/NudgeInator.app"
    widget="$(echo "$app"/PlugIns/*.appex)"
    for bundle in "$app" "$widget"; do
      version="$(plist "$bundle/Info.plist" CFBundleShortVersionString)"
      build="$(plist "$bundle/Info.plist" CFBundleVersion)"
      echo "$(basename "$bundle"): $version ($build)"
      [ "$version" = "$expected" ] || fail "$(basename "$bundle") reports $version, project.yml says $expected"
    done

    fingerprint > "$archived"
    echo
    if [ -e "$dry_run" ]; then
      echo "Trial archive of $(fingerprint). It can't be uploaded."
    else
      echo "Archived v$expected: $(fingerprint). Nothing is uploaded. On the developer's go:"
      echo "scripts/archive-and-upload.sh upload"
    fi
    ;;
  upload)
    require_archive
    [ -f "$archived" ] && [ "$(cat "$archived")" = "$(fingerprint)" ] \
      || fail "the archive wasn't made from this commit. Archive the release tag again."
    step "Upload to App Store Connect"
    xcodebuild_logged "$logs/upload.log" -exportArchive -archivePath "$archive" \
      -exportPath "$out/upload" -exportOptionsPlist "$options" \
      -allowProvisioningUpdates || fail "upload"
    echo
    echo "Uploaded. Confirm in App Store Connect that the build processed."
    ;;
  *) fail "unknown mode '$mode' (archive, upload)" ;;
esac
