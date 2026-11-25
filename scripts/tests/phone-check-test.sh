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

# xcrun writes $FAKE_DEVICES to the --json-output path; asked for a device's details, it records the
# device and, when $FAKE_WOKEN names a file, the listing becomes that file's (the phone woke). gh
# records its arguments.
cat > "$work/bin/xcrun" <<'SH'
#!/bin/sh
case " $* " in
  *" info details "*)
    while [ $# -gt 0 ]; do [ "$1" = --device ] && echo "$2" >> "$FAKE_WAKE_LOG"; shift; done
    [ -n "${FAKE_WOKEN:-}" ] && cp "$FAKE_WOKEN" "$FAKE_DEVICES"
    exit 0 ;;
esac
while [ $# -gt 0 ]; do [ "$1" = --json-output ] && cp "$FAKE_DEVICES" "$2"; shift; done
SH
cat > "$work/bin/gh" <<'SH'
#!/bin/sh
[ -n "${FAKE_GH_FAILS:-}" ] && exit 1
printf '%s\n' "$@" > "$FAKE_GH_LOG"
SH
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" FAKE_GH_LOG="$work/gh.log" FAKE_WAKE_LOG="$work/wake.log"
# The seeds device-seed.sh recorded; never the checkout's own record.
export NUDGE_SEED_LOG="$work/seeds.log"

phone='{"hardwareProperties":{"reality":"physical","marketingName":"iPhone 15","productType":"iPhone15,4"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"tunnelState":"connected"}}'
ipad='{"hardwareProperties":{"reality":"physical","marketingName":"iPad Pro","productType":"iPad16,3"},"deviceProperties":{"osVersionNumber":"27.2"},"connectionProperties":{"tunnelState":"connected"}}'
sim='{"hardwareProperties":{"reality":"simulated","marketingName":"iPhone 18 Pro","productType":"iPhone19,2"},"deviceProperties":{"osVersionNumber":"27.2"},"connectionProperties":{"tunnelState":"disconnected"}}'
# Paired over Wi-Fi with no tunnel until a command reaches it (#328's phone check).
asleep='{"identifier":"PHONE-1","hardwareProperties":{"reality":"physical","marketingName":"iPhone 15","productType":"iPhone15,4"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"pairingState":"paired","tunnelState":"disconnected"}}'
away='{"hardwareProperties":{"reality":"physical","marketingName":"iPhone 15","productType":"iPhone15,4"},"deviceProperties":{"osVersionNumber":"27.2.1"},"connectionProperties":{"tunnelState":"disconnected"}}'
devices() { echo "{\"result\":{\"devices\":[$1]}}" > "$work/devices.json"; export FAKE_DEVICES="$work/devices.json"; rm -f "$FAKE_GH_LOG"; }

devices "$ipad,$sim,$phone"
scripts/phone-check.sh 352 installed
expect "install comment names the model and iOS version the device reports" \
  $'issue\ncomment\n352\n--body\nPhone check: installed, checklist sent (iPhone 15, iOS 27.2.1)' "$(cat "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
printf -- '- Found by: the phone; Kind: an app bug; Where: portrait\n\nFound by: the phone; Kind: a flake; Where: landscape\n' | scripts/phone-check.sh 352 report
expect "report takes findings one per line from stdin" \
  $'issue\ncomment\n352\n--body\nPhone check: report (iPhone 15, iOS 27.2.1)\n\n- Found by: the phone; Kind: an app bug; Where: portrait\n- Found by: the phone; Kind: a flake; Where: landscape' "$(cat "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
scripts/phone-check.sh 352 report "Found by: the phone; Kind: a flake; Where: portrait"
expect "report takes findings as arguments" "- Found by: the phone; Kind: a flake; Where: portrait" "$(tail -1 "$FAKE_GH_LOG")"

rm -f "$FAKE_GH_LOG"
scripts/phone-check.sh 352 report < /dev/null
expect "a report with no findings says so" "- Nothing found." "$(tail -1 "$FAKE_GH_LOG")"

devices "$phone"
printf '%s\n' "2026-11-25 07:32:54 quiet-hours-banner-empty (stand-in seeded)" "2026-11-25 07:40:48 clean" > "$NUDGE_SEED_LOG"
scripts/phone-check.sh 352 installed
expect "the install comment leaves the seed record for the report" 2 "$(wc -l < "$NUDGE_SEED_LOG" | tr -d ' ')"
NUDGE_PHONE_CHECK_DRY_RUN=1 scripts/phone-check.sh 352 report < /dev/null > /dev/null
expect "a dry run leaves the seed record" 2 "$(wc -l < "$NUDGE_SEED_LOG" | tr -d ' ')"
FAKE_GH_FAILS=1 scripts/phone-check.sh 352 report < /dev/null > /dev/null 2>&1
expect "a report that isn't posted keeps the seed record" 2 "$(wc -l < "$NUDGE_SEED_LOG" | tr -d ' ')"
scripts/phone-check.sh 352 report < /dev/null
expect "the report lists the seeds launched" \
  $'issue\ncomment\n352\n--body\nPhone check: report (iPhone 15, iOS 27.2.1)\n\nSeeds launched: 2026-11-25 07:32:54 quiet-hours-banner-empty (stand-in seeded); 2026-11-25 07:40:48 clean\n\n- Nothing found.' "$(cat "$FAKE_GH_LOG")"
expect "a posted report clears the seed record" no "$([ -e "$NUDGE_SEED_LOG" ] && echo yes || echo no)"

for scenario in "$sim" "$away" "$ipad" ""; do
  devices "$scenario"
  out="$(scripts/phone-check.sh 352 installed 2>&1)"; code=$?
  expect "no connected iPhone: exit 1" "1" "$code"
  expect "no connected iPhone: says so" "1" "$(echo "$out" | grep -c 'No iPhone is connected')"
  expect "no connected iPhone: posts nothing" "no" "$([ -e "$FAKE_GH_LOG" ] && echo yes || echo no)"
done

devices "$ipad,$asleep"; rm -f "$FAKE_WAKE_LOG"
echo "{\"result\":{\"devices\":[$ipad,$phone]}}" > "$work/woken.json"
FAKE_WOKEN="$work/woken.json" scripts/phone-check.sh 352 installed
expect "a paired iPhone with no tunnel is woken once" "PHONE-1" "$(cat "$FAKE_WAKE_LOG")"
expect "once woken, its comment is posted" "Phone check: installed, checklist sent (iPhone 15, iOS 27.2.1)" "$(tail -1 "$FAKE_GH_LOG")"

devices "$asleep"; rm -f "$FAKE_WAKE_LOG"
out="$(scripts/phone-check.sh 352 installed 2>&1)"; code=$?
expect "a paired iPhone that doesn't wake: exit 1" "1" "$code"
expect "a paired iPhone that doesn't wake: posts nothing" "no" "$([ -e "$FAKE_GH_LOG" ] && echo yes || echo no)"

rm -f "$work/devices.json"; export FAKE_DEVICES="$work/none.json"
scripts/phone-check.sh 352 installed > /dev/null 2>&1
expect "devicectl failing counts as no phone" "1" "$?"

[ $failures -eq 0 ]
