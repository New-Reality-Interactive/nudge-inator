#!/usr/bin/env bash
# Loads a seed set on the connected iPhone, or removes what was loaded, and waits until the app says
# it did (docs/agents/device-testing.md, Seeding test data). The app must be a Debug build.
#
#   scripts/device-seed.sh <set|clean> [stand-in]
#
# <stand-in> is a NUDGE_SHARING_STANDIN value, such as `sent`. The app is left running.
# Exits 0 only once the app logs the set loaded, or the removal done. It fails when no iPhone is
# connected, the launch ends first (a locked phone), the app refuses, or nothing answers within
# NUDGE_SEED_TIMEOUT seconds (60). Each success is added to NUDGE_SEED_LOG
# (.build/phone-check-seeds.log), which the next phone-check report lists.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/scripts/phone.sh"

usage() { echo "usage: scripts/device-seed.sh <set|clean> [stand-in]" >&2; exit 2; }
[ $# -ge 1 ] && [ $# -le 2 ] || usage
set_name="$1" stand_in="${2:-}"
# Both go into the launch's JSON, so only a name's characters pass.
name='^[a-z0-9-]+$'
[[ "$set_name" =~ $name ]] || usage
[ -z "$stand_in" ] || [[ "$stand_in" =~ $name ]] || usage

work="$(mktemp -d)"
console_pid=""
# SIGKILL, which the console can't pass on to the app, so the app keeps running.
cleanup() {
  if [ -n "$console_pid" ]; then kill -9 "$console_pid" 2> /dev/null || true; wait "$console_pid" 2> /dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

phone="$(connected_phone "$work")"
[ -n "$phone" ] || { echo "No iPhone is connected (xcrun devicectl list devices shows none connected)." >&2; exit 1; }

# OS_ACTIVITY_DT_MODE puts the app's Logger messages on the console.
environment="{\"NUDGE_SEED\":\"$set_name\",\"OS_ACTIVITY_DT_MODE\":\"YES\""
[ -z "$stand_in" ] || environment+=",\"NUDGE_SHARING_STANDIN\":\"$stand_in\""
environment+="}"
if [ "$set_name" = clean ]; then answer='Seed cleaned'; else answer="Seed loaded(\"$set_name\")"; fi

fail() {
  echo "FAIL: $1. The launch's last output:" >&2
  tail -5 "$work/console" >&2
  exit 1
}

xcrun devicectl device process launch --console --terminate-existing --device "${phone%%$'\t'*}" \
  -e "$environment" com.newrealityinteractive.nudgeinator > "$work/console" 2>&1 &
console_pid=$!
deadline=$((SECONDS + ${NUDGE_SEED_TIMEOUT:-60}))
while :; do
  # Whether it still runs is read before its output, so an answer printed as it ended isn't missed.
  running=true
  kill -0 "$console_pid" 2> /dev/null || running=false
  if grep -qF "$answer" "$work/console"; then break; fi
  if grep -qE 'Seed unknownSet\(|Not seeding ' "$work/console"; then fail "the app refused $set_name"; fi
  $running || fail "the launch ended before the app answered (is the iPhone unlocked?)"
  [ "$SECONDS" -lt "$deadline" ] || fail "the app didn't answer in time (is it a Debug build?)"
  sleep 0.2
done

log="${NUDGE_SEED_LOG:-$repo/.build/phone-check-seeds.log}"
mkdir -p "$(dirname "$log")"
echo "$(date '+%F %T') $set_name${stand_in:+ (stand-in $stand_in)}" >> "$log"
grep -F "$answer" "$work/console" | tail -1
