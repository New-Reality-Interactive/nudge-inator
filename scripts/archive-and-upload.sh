#!/usr/bin/env bash
# Takes the Release archive to App Store Connect as a TestFlight build (#99). The steps run apart:
#   scripts/archive-and-upload.sh                   archives main, checks the versions, and stops.
#   scripts/archive-and-upload.sh record-validated  records that the developer's Validate App in the
#                                                   Organizer passed for this archive. Run it only
#                                                   after they say it did.
#   scripts/archive-and-upload.sh upload            uploads that archive. Run it only on the
#                                                   developer's go: the upload publishes to App
#                                                   Store Connect.
# There is no xcodebuild validation step: its `validation` method is only accepted with
# `destination: upload`, and Apple's docs don't say whether that sends the build to App Store
# Connect. Upload refuses unless validation was recorded for this archive on this commit. Uses the
# Apple ID signed into Xcode; no API key or other secret. Env: ALLOW_DIRTY=1 archives a branch or
# uncommitted changes as a dry run, which can't be recorded as validated or uploaded.
set -uo pipefail
cd "$(dirname "$0")/.."

mode="${1:-archive}"
out="$PWD/.build/release"
archive="$out/NudgeInator.xcarchive"
logs="$out/logs"
options="$PWD/scripts/export-options.plist"
validated="$out/validated"
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
  [ ! -e "$dry_run" ] || fail "the archive is a dry run (ALLOW_DIRTY). Archive main, committed."
}

# Identifies the archive and the commit it was built from, so a validation can't be reused for
# another build.
fingerprint() { echo "$(git rev-parse HEAD) $(plist "$archive/Info.plist" CreationDate)"; }

case "$mode" in
  archive)
    rm -rf "$archive" "$validated" "$dry_run"
    if [ -n "$(git status --porcelain)" ] || [ "$(git branch --show-current)" != main ]; then
      [ -n "${ALLOW_DIRTY:-}" ] || fail "archive a committed, up-to-date main (ALLOW_DIRTY=1 for a dry run)."
      touch "$dry_run"
    fi
    step "Archive (Release, scheme NudgeInator) at $(git rev-parse --short HEAD)"
    xcodegen generate > "$logs/xcodegen.log" 2>&1 || fail "xcodegen generate (see $logs/xcodegen.log)"
    xcodebuild_logged "$logs/archive.log" archive -project NudgeInator.xcodeproj -scheme NudgeInator \
      -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" \
      -allowProvisioningUpdates || fail "archive"

    step "Versions"
    expected="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)"
    [ -n "$expected" ] || fail "no MARKETING_VERSION in project.yml"
    app="$archive/Products/Applications/NudgeInator.app"
    widget="$(echo "$app"/PlugIns/*.appex)"
    for bundle in "$app" "$widget"; do
      version="$(plist "$bundle/Info.plist" CFBundleShortVersionString)"
      build="$(plist "$bundle/Info.plist" CFBundleVersion)"
      echo "$(basename "$bundle"): $version ($build)"
      [ "$version" = "$expected" ] || fail "$(basename "$bundle") reports $version, project.yml says $expected"
    done

    echo
    echo "Archived $(fingerprint). Nothing is validated or uploaded."
    echo "Next: open $archive (it joins the Organizer), run Validate App, then"
    echo "scripts/archive-and-upload.sh record-validated"
    ;;
  record-validated)
    require_archive
    fingerprint > "$validated"
    echo "Recorded: Validate App passed for $(cat "$validated"). On the developer's go:"
    echo "scripts/archive-and-upload.sh upload"
    ;;
  upload)
    require_archive
    [ -f "$validated" ] && [ "$(cat "$validated")" = "$(fingerprint)" ] \
      || fail "validation isn't recorded for this archive on this commit (record-validated)."
    step "Upload to App Store Connect"
    xcodebuild_logged "$logs/upload.log" -exportArchive -archivePath "$archive" \
      -exportPath "$out/upload" -exportOptionsPlist "$options" \
      -allowProvisioningUpdates || fail "upload"
    echo
    echo "Uploaded. Confirm in App Store Connect that the build processed."
    ;;
  *) fail "unknown mode '$mode' (archive, record-validated, upload)" ;;
esac
