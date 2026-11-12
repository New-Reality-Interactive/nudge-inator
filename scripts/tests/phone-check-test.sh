#!/usr/bin/env bash
# Tests scripts/phone-check.sh (#352) with stand-ins for xcrun and gh. Needs no phone or network.
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

# xcrun writes $FAKE_DEVICES to the --json-output path; gh records its arguments.
cat > "$work/bin/xcrun" <<'SH'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = --json-output ] && cp "$FAKE_DEVICES" "$2"; shift; done
SH
cat > "$work/bin/gh" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$FAKE_GH_LOG"
SH
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" FAKE_GH_LOG="$work/gh.log"

phone='{"hardwareProperties":{"reality":"physical","marketingName":"iPhone 15"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"tunnelState":"connected"}}'
sim='{"hardwareProperties":{"reality":"simulated","marketingName":"iPhone 18 Pro"},"deviceProperties":{"osVersionNumber":"27.2"},"connectionProperties":{"tunnelState":"disconnected"}}'
away='{"hardwareProperties":{"reality":"physical","marketingName":"iPhone 15"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"tunnelState":"disconnected"}}'
devices() { echo "{\"result\":{\"devices\":[$1]}}" > "$work/devices.json"; export FAKE_DEVICES="$work/devices.json"; rm -f "$FAKE_GH_LOG"; }

devices "$sim,$phone"
scripts/phone-check.sh 352 installed
expect "install comment names the model and iOS version the device reports" \
  $'issue\ncomment\n352\n--body\nPhone check: installed, checklist sent (iPhone 15, iOS 27.2.1)' "$(cat "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
printf -- '- Found by: the phone; Kind: an app bug; Where: portrait\n\nFound by: the phone; Kind: a flake; Where: landscape\n' | scripts/phone-check.sh 352 report
expect "report takes findings one per line from stdin" \
  $'issue\ncomment\n352\n--body\nPhone check: report (iPhone 15, iOS 27.2.1)\n\n- Found by: the phone; Kind: an app bug; Where: portrait\n- Found by: the phone; Kind: a flake; Where: landscape' "$(cat "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
scripts/phone-check.sh 352 report "Found by: the phone; Kind: a flake; Where: portrait"
expect "report takes findings as arguments" "- Found by: the phone; Kind: a flake; Where: portrait" "$(sed -n '7p' "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
scripts/phone-check.sh 352 report < /dev/null
expect "a report with no findings says so" "- Nothing found." "$(sed -n '7p' "$FAKE_GH_LOG")"

for case in "$sim" "$away" ""; do
  devices "$case"
  out="$(scripts/phone-check.sh 352 installed 2>&1)"; code=$?
  expect "no connected iPhone: exit 1" "1" "$code"
  expect "no connected iPhone: says so" "1" "$(echo "$out" | grep -c 'No iPhone is connected')"
  expect "no connected iPhone: posts nothing" "no" "$([ -e "$FAKE_GH_LOG" ] && echo yes || echo no)"
done

rm -f "$work/devices.json"; export FAKE_DEVICES="$work/none.json"
scripts/phone-check.sh 352 installed > /dev/null 2>&1
expect "devicectl failing counts as no phone" "1" "$?"

[ $failures -eq 0 ]
