#!/usr/bin/env bash
# Posts a ticket's phone-check comments (#352), docs/agents/ticket-workflow.md, "Recording findings".
#
#   scripts/phone-check.sh <ticket> installed
#       "Phone check: installed, checklist sent", for when the build is on the phone.
#   scripts/phone-check.sh <ticket> report [finding...]
#       The developer's report, one line per finding (arguments, or lines on stdin when there are
#       none). Each finding is the line the workflow defines: "Found by: …; Kind: …; Where: …".
#       No findings at all posts "Nothing found" so the ticket still shows its check.
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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Reads the device list into $work/devices.json, then prints, for the first physical iPhone (an iPad or
# Watch is skipped), "connected<TAB><model>, iOS <version>" when its tunnel is up, or else "paired<TAB><id>"
# for one paired with no tunnel. Prints nothing when there is neither.
find_phone() {
  xcrun devicectl list devices --json-output "$work/devices.json" > /dev/null 2>&1 || true
  python3 -I - "$work/devices.json" 2> /dev/null <<'PY' || true
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
phones = [d for d in devices if d.get("hardwareProperties", {}).get("reality") == "physical"
          and str(d.get("hardwareProperties", {}).get("productType", "")).startswith("iPhone")]
for d in phones:
    model, version = d["hardwareProperties"].get("marketingName"), d.get("deviceProperties", {}).get("osVersionNumber")
    if d.get("connectionProperties", {}).get("tunnelState") == "connected" and model and version:
        print(f"connected\t{model}, iOS {version}")
        sys.exit(0)
for d in phones:
    if d.get("connectionProperties", {}).get("pairingState") == "paired" and d.get("identifier"):
        print(f"paired\t{d['identifier']}")
        sys.exit(0)
PY
}

# A phone paired over Wi-Fi shows "available (paired)" with no tunnel until a command reaches it (#328's
# phone check), so asking for its details once wakes it; the list is then read again.
found="$(find_phone)"
if [ "${found%%$'\t'*}" = paired ]; then
  xcrun devicectl device info details --device "${found#*$'\t'}" > /dev/null 2>&1 || true
  found="$(find_phone)"
fi
phone=""
[ "${found%%$'\t'*}" = connected ] && phone="${found#*$'\t'}"
if [ -z "$phone" ]; then
  echo "No iPhone is connected (xcrun devicectl list devices shows none connected): nothing posted." >&2
  exit 1
fi

if [ "$action" = installed ]; then
  body="Phone check: installed, checklist sent ($phone)"
else
  if [ $# -gt 0 ]; then printf '%s\n' "$@" > "$work/findings"; else cat > "$work/findings"; fi
  sed -i '' -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*[-*][[:space:]]*//' "$work/findings"
  body="Phone check: report ($phone)"$'\n'
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
fi
