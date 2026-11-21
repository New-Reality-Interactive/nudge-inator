#!/usr/bin/env bash
# The website screenshots for a release (docs/agents/release.md, Website screenshots): the app page's
# carousel slides, taken from one person's day by the screenshots harness's `testSiteShots`
# (scripts/screenshots/), on the iOS 27.2 simulator in portrait, at 8:20 AM with the status bar
# overridden, then resized to 600 x 1302 and copied to <site repo>/shots/<version>/ as
# carousel-<n>-<name>.png, and each tutorial page as tutorial-<slug>-<page>.png. It touches nothing else
# in the site repository.
# Usage: scripts/site-shots.sh <version>      Env: SITE_REPO (default: the website's checkout)
set -uo pipefail
cd "$(dirname "$0")/.."
version="${1:?usage: scripts/site-shots.sh <version>, such as 1.4.0}"
site="${SITE_REPO:-/Users/bpm/Work/repositories/new-reality-interactive/nudge-inator}"
simulator="iPhone 15 - iOS 27.2"
[ -d "$site/shots" ] || { echo "FAIL: no $site/shots"; exit 1; }
out="docs/screenshots/site-$version"
udid="$(xcrun simctl list devices available | awk -v name="$simulator" '{ l=$0; sub(/^ +/,"",l) } index(l, name " (")==1 { match(l,/[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr(l,RSTART,RLENGTH); exit }')"
[ -n "$udid" ] || { echo "FAIL: no simulator named $simulator"; exit 1; }

booted_here=0
xcrun simctl list devices | grep "$udid" | grep -q Booted || { xcrun simctl boot "$udid" && booted_here=1; }
xcrun simctl bootstatus "$udid" -b > /dev/null
cleanup() {
  xcrun simctl status_bar "$udid" clear 2> /dev/null
  [ "$booted_here" = 1 ] && xcrun simctl shutdown "$udid" 2> /dev/null
}
trap cleanup EXIT
xcrun simctl status_bar "$udid" override --time "8:20" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" --batteryState discharging --batteryLevel 100

rm -rf "$out"
SIMULATORS="$simulator" SHOTS_VARIANTS=portrait SHOTS_TESTS="testSiteShots" SHOTS_NOW=08:20 SHOTS_OUT="$out" scripts/screenshots.sh || exit 1

dest="$site/shots/$version"
mkdir -p "$dest"
for shot in "$out/$simulator/portrait"/site-*.png; do
  name="$(basename "$shot" .png)"
  case "$name" in
    # A tutorial page keeps a name with no version, so copying the folder over the site's shots/
    # replaces the old one (release.md, Website tutorials).
    site-tutorial-*) name="${name#site-}" ;;
    *) name="carousel-${name#site-}" ;;
  esac
  sips --resampleWidth 600 "$shot" --out "$dest/$name.png" > /dev/null || exit 1
done
echo "Website screenshots: $dest"
ls "$dest"
