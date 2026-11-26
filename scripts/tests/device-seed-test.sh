#!/usr/bin/env bash
# Tests scripts/device-seed.sh with a stand-in for xcrun. Needs no phone.
set -uo pipefail
cd "$(dirname "$0")/../.."
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"

expect() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1" >&2; printf '  expected:\n%s\n  got:\n%s\n' "$2" "$3" >&2; failures=$((failures + 1)); fi
}

# xcrun writes $FAKE_DEVICES to the --json-output path. Asked to launch, it records its arguments,
# prints $FAKE_CONSOLE and then, as `--console` does while the app runs, stays until killed, unless
# $FAKE_ENDS is set.
cat > "$work/bin/xcrun" <<'SH'
#!/bin/sh
case " $* " in
  *" process launch "*)
    printf '%s\n' "$@" > "$FAKE_LAUNCH_LOG"
    printf '%s\n' "$FAKE_CONSOLE"
    [ -n "${FAKE_ENDS:-}" ] && exit 1
    exec sleep 30 ;;
  *" info details "*) exit 0 ;;
esac
while [ $# -gt 0 ]; do [ "$1" = --json-output ] && cp "$FAKE_DEVICES" "$2"; shift; done
SH
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" FAKE_LAUNCH_LOG="$work/launch.log" NUDGE_SEED_LOG="$work/seeds.log"

phone='{"identifier":"PHONE-1","hardwareProperties":{"reality":"physical","marketingName":"iPhone 15","productType":"iPhone15,4"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"tunnelState":"connected"}}'
devices() { echo "{\"result\":{\"devices\":[$1]}}" > "$work/devices.json"; export FAKE_DEVICES="$work/devices.json"; }
# run <console output> <arguments>...
run() {
  rm -f "$FAKE_LAUNCH_LOG" "$NUDGE_SEED_LOG"
  out="$(FAKE_CONSOLE="$1" scripts/device-seed.sh "${@:2}" 2>&1)"; code=$?
}
recorded() { [ -e "$NUDGE_SEED_LOG" ] && sed 's/^[0-9:-]* [0-9:]* //' "$NUDGE_SEED_LOG" || echo nothing; }
launched_with() { grep '^{' "$FAKE_LAUNCH_LOG"; }

devices "$phone"
began=$SECONDS
run '2026-11-25 NudgeInator[1:2] [DeviceSeed] Seed loaded("search")' search
expect "a loaded set: exit 0" 0 "$code"
expect "a loaded set: says so" 1 "$(grep -c 'Seed loaded("search")' <<<"$out")"
expect "it asks for the set and the app's log" '{"NUDGE_SEED":"search","OS_ACTIVITY_DT_MODE":"YES"}' "$(launched_with)"
expect "it launches on the connected iPhone" PHONE-1 "$(grep -A1 -x -- --device "$FAKE_LAUNCH_LOG" | tail -1)"
expect "it replaces a running app and reads its console" 2 "$(grep -c -x -e --console -e --terminate-existing "$FAKE_LAUNCH_LOG")"
expect "the launch is recorded" search "$(recorded)"
expect "it stops reading once the app has answered" yes "$([ $((SECONDS - began)) -lt 20 ] && echo yes || echo no)"

run '[DeviceSeed] Seed loaded("search")' search sent
expect "a stand-in is launched with the set" \
  '{"NUDGE_SEED":"search","OS_ACTIVITY_DT_MODE":"YES","NUDGE_SHARING_STANDIN":"sent"}' "$(launched_with)"
expect "the stand-in is recorded" "search (stand-in sent)" "$(recorded)"

run '[DeviceSeed] Seed cleaned' clean
expect "clean waits for the removal" "0 clean" "$code $(recorded)"

run '[DeviceSeed] Seed loaded("searching")' search
FAKE_ENDS=1 run '[DeviceSeed] Seed loaded("searching")' search
expect "another set's answer is not this one's" "1 nothing" "$code $(recorded)"

run '[DeviceSeed] Seed unknownSet("serch")' serch
expect "an unknown set fails, recording nothing" "1 nothing" "$code $(recorded)"

run "[DeviceSeed] Not seeding search: the store hasn't been read" search
expect "an unread store fails, recording nothing" "1 nothing" "$code $(recorded)"

FAKE_ENDS=1 run 'Unable to launch because the device was not, or could not be, unlocked.' search
expect "a launch that ends with no answer fails, recording nothing" "1 nothing" "$code $(recorded)"
expect "a launch that ends with no answer shows why" 1 "$(grep -c 'could not be, unlocked' <<<"$out")"

NUDGE_SEED_TIMEOUT=1 run 'Launched application.' search
expect "an app that never answers fails, recording nothing" "1 nothing" "$code $(recorded)"

run '[DeviceSeed] Seed loaded("search")'
expect "no set: usage" 2 "$code"
run '' 'search","X":"y'
expect "a name that isn't a set's: usage, no launch" "2 no" "$code $([ -e "$FAKE_LAUNCH_LOG" ] && echo yes || echo no)"

devices ""
run '' search
expect "no connected iPhone: fails, launching nothing" "1 no" "$code $([ -e "$FAKE_LAUNCH_LOG" ] && echo yes || echo no)"

[ $failures -eq 0 ]
