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
# typed. With no iPhone connected the script says so and posts nothing. The phone time is the gap
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

# The model and iOS version of the first connected physical iPhone (an iPad or Watch is skipped), as "<model>, iOS <version>".
xcrun devicectl list devices --json-output "$work/devices.json" > /dev/null 2>&1 || true
phone="$(python3 -I - "$work/devices.json" 2> /dev/null <<'PY' || true
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devices:
    hw, dev, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    model, version = hw.get("marketingName"), dev.get("osVersionNumber")
    if hw.get("reality") == "physical" and str(hw.get("productType", "")).startswith("iPhone") and conn.get("tunnelState") == "connected" and model and version:
        print(f"{model}, iOS {version}")
        break
PY
)"
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
