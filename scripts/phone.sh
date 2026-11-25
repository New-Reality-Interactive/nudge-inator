# Sourced by the scripts that drive the test iPhone (phone-check.sh, device-seed.sh).

# connected_phone <work dir>: prints, for the first connected physical iPhone (an iPad or Watch is
# skipped), "<device id><TAB><model>, iOS <version>", both as `xcrun devicectl` reports them. Prints
# nothing when none is connected.
#
# A phone paired over Wi-Fi shows "available (paired)" with no tunnel until a command reaches it
# (#328's phone check), so asking for its details once wakes it; the list is then read again.
connected_phone() {
  local found
  found="$(_find_phone "$1")"
  if [ "${found%%$'\t'*}" = paired ]; then
    xcrun devicectl device info details --device "${found#*$'\t'}" > /dev/null 2>&1 || true
    found="$(_find_phone "$1")"
  fi
  if [ "${found%%$'\t'*}" = connected ]; then printf '%s\n' "${found#*$'\t'}"; fi
}

# Prints "connected<TAB><id><TAB><model>, iOS <version>" for a phone whose tunnel is up, or else
# "paired<TAB><id>" for one paired with no tunnel. Prints nothing when there is neither.
_find_phone() {
  xcrun devicectl list devices --json-output "$1/devices.json" > /dev/null 2>&1 || true
  python3 -I - "$1/devices.json" 2> /dev/null <<'PY' || true
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
        print(f"connected\t{d.get('identifier', '')}\t{model}, iOS {version}")
        sys.exit(0)
for d in phones:
    if d.get("connectionProperties", {}).get("pairingState") == "paired" and d.get("identifier"):
        print(f"paired\t{d['identifier']}")
        sys.exit(0)
PY
}
