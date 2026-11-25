#!/usr/bin/env bash
# Posts a ticket's phone-check comments (#352), docs/agents/ticket-workflow.md, "Recording findings".
#
#   scripts/phone-check.sh <ticket> installed
#       "Phone check: installed, checklist sent", for when the build is on the phone.
#   scripts/phone-check.sh <ticket> report [finding...]
#       The developer's report, one line per finding (arguments, or lines on stdin when there are
#       none). Each finding is the line the workflow defines: "Found by: …; Kind: …; Where: …".
#       No findings at all posts "Nothing found" so the ticket still shows its check. It lists the
#       seeds device-seed.sh launched since the last report (NUDGE_SEED_LOG), then clears them.
#
# Both comments name the connected iPhone's model and iOS version, read from `xcrun devicectl`, never
# typed. A paired iPhone with no tunnel (on Wi-Fi) is woken once first. With no iPhone connected the
# script says so and posts nothing. The phone time is the gap
# between the two comments' timestamps, so post each as soon as its moment arrives.
# NUDGE_PHONE_CHECK_DRY_RUN=1 prints the comment instead of posting it.
set -euo pipefail

usage() { echo "usage: scripts/phone-check.sh <ticket> installed | report [finding...]" >&2; exit 2; }
[ $# -ge 2 ] || usage
ticket="$1" action="$2"; shift 2
case "$ticket" in ''|*[!0-9]*) usage ;; esac
case "$action" in installed|report) ;; *) usage ;; esac

repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo/scripts/phone.sh"
seed_log="${NUDGE_SEED_LOG:-$repo/.build/phone-check-seeds.log}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

found="$(connected_phone "$work")"
phone="${found#*$'\t'}"
if [ -z "$found" ]; then
  echo "No iPhone is connected (xcrun devicectl list devices shows none connected): nothing posted." >&2
  exit 1
fi

if [ "$action" = installed ]; then
  body="Phone check: installed, checklist sent ($phone)"
else
  if [ $# -gt 0 ]; then printf '%s\n' "$@" > "$work/findings"; else cat > "$work/findings"; fi
  sed -i '' -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*[-*][[:space:]]*//' "$work/findings"
  body="Phone check: report ($phone)"$'\n'
  # What the check ran with, so a finding keeps the state it showed in.
  if [ -s "$seed_log" ]; then
    body+=$'\n'"Seeds launched: $(awk 'NR > 1 { printf "; " } { printf "%s", $0 }' "$seed_log")"$'\n'
  fi
  if [ -s "$work/findings" ]; then
    body+=$'\n'"$(sed 's/^/- /' "$work/findings")"
  else
    body+=$'\n'"- Nothing found."
  fi
fi

if [ "${NUDGE_PHONE_CHECK_DRY_RUN:-}" = 1 ]; then
  printf '%s\n' "$body"
else
  gh issue comment "$ticket" --body "$body"
  # Posted (set -e stops a failed post), so the next report starts its own record.
  [ "$action" != report ] || rm -f "$seed_log"
fi
