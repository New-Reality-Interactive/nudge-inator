#!/usr/bin/env bash
# Tests scripts/screenshots-plan.sh: which simulator or clone runs which screenshot variants (#301).
# Pure shell; needs no simulator, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
source scripts/screenshots-plan.sh

pro="iPhone 15 Pro - iOS 26.5"
plain="iPhone 15 - iOS 27.0"
unused="a default no plan asks for" # the default variants, where a plan replaces them
failures=0

# expect <description> <expected output> <actual output>
expect() {
  if [ "$2" = "$3" ]; then
    echo "ok: $1"
  else
    echo "FAIL: $1" >&2
    printf '  expected:\n%s\n  got:\n%s\n' "$2" "$3" >&2
    failures=$((failures + 1))
  fi
}

# expect_failure <description> <message part> <args to shots_lanes...>
expect_failure() {
  local description="$1" part="$2" output
  shift 2
  if output="$(shots_lanes "$@" 2>&1)"; then
    echo "FAIL: $description (succeeded, printed: $output)" >&2
    failures=$((failures + 1))
  elif [[ "$output" == *"$part"* ]]; then
    echo "ok: $description"
  else
    echo "FAIL: $description (message lacks \"$part\": $output)" >&2
    failures=$((failures + 1))
  fi
}

matrix="$pro;$plain"

expect "no plan: every matrix simulator runs the default variants, none cloned" \
  "$pro|0|portrait landscape
$plain|0|portrait landscape" \
  "$(shots_lanes "$matrix" "portrait landscape" "")"

expect "a plan gives different simulators different variants" \
  "$pro|0|largest-text-landscape
$plain|0|portrait" \
  "$(shots_lanes "$matrix" "$unused" "$pro=largest-text-landscape;$plain=portrait")"

expect "a plan replaces the simulator list: only the simulators it names run" \
  "$plain|0|portrait" \
  "$(shots_lanes "$matrix" "portrait" "$plain=portrait")"

expect "a simulator named twice gets a clone for the second entry" \
  "$plain|0|portrait
$plain|1|landscape" \
  "$(shots_lanes "$matrix" "$unused" "$plain=portrait;$plain=landscape")"

expect "a simulator named three times gets two clones, the most it may have" \
  "$plain|0|portrait
$plain|1|landscape
$plain|2|largest-text" \
  "$(shots_lanes "$matrix" "$unused" "$plain=portrait;$plain=landscape;$plain=largest-text")"

expect "entries beyond the limit queue behind existing simulators, in turn" \
  "$plain|0|a d
$plain|1|b e
$plain|2|c" \
  "$(shots_lanes "$matrix" "$unused" "$plain=a;$plain=b;$plain=c;$plain=d;$plain=e")"

expect "clones are counted per simulator" \
  "$pro|0|portrait
$plain|0|portrait
$pro|1|landscape
$plain|1|landscape" \
  "$(shots_lanes "$matrix" "$unused" "$pro=portrait;$plain=portrait;$pro=landscape;$plain=landscape")"

expect "a variant list may hold several variants, and spaces around entries are ignored" \
  "$plain|0|portrait landscape
$plain|1|rtl" \
  "$(shots_lanes "$matrix" "$unused" " $plain = portrait landscape ; $plain=rtl ;")"

expect_failure "an entry without = is refused" "is not <simulator>=<variants>" \
  "$matrix" "$unused" "$plain"
expect_failure "an entry without variants is refused" "is not <simulator>=<variants>" \
  "$matrix" "$unused" "$plain="
expect_failure "the same variant twice on one simulator is refused" "twice" \
  "$matrix" "$unused" "$plain=portrait;$plain=portrait"

# A clone's name must never be a matrix simulator's, or scripts/test.sh could pick it up.
for name in "$pro" "$plain"; do
  for slot in 1 2; do
    clone="$(shots_lane_label "$name" "$slot")"
    case ";$matrix;" in
      *";$clone;"*) echo "FAIL: clone \"$clone\" is in the matrix" >&2; failures=$((failures + 1)) ;;
      *) echo "ok: \"$clone\" is not a matrix simulator" ;;
    esac
  done
done
expect "slot 0 is the simulator itself" "$plain" "$(shots_lane_label "$plain" 0)"

[ "$failures" -eq 0 ] || { echo "FAIL: $failures check(s)" >&2; exit 1; }
echo "PASS: the screenshot plan"
