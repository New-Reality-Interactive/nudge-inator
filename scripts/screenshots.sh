#!/usr/bin/env bash
# Takes a screenshot of every screen of the app on each simulator in the test matrix, in portrait,
# landscape and the largest text size, for checking the app against the mockup. Builds a throwaway
# harness (scripts/screenshots/) into .build/screenshots: the app's sources with a stand-in @main
# over the test fakes, seeded with the mockup's reminders, and a UI test that walks the screens.
# The harness is built once, then the simulators are shot at the same time, each one's variants one
# after the other. Nothing touches the app's own install or data. Each simulator's text size and
# appearance are put back afterwards, the harness app and its UI-test runner (bundle IDs from
# scripts/screenshots/project.yml) are uninstalled, and a simulator it booted is shut down, even
# after a failure or an interrupt (Ctrl-C stops every simulator's run first).
# Env: SIMULATORS (as scripts/test.sh), SHOTS_OUT (default docs/screenshots/<today>, git-ignored),
# SHOTS_PLAN (a list of variants for each simulator, run at the same time, on clones of a simulator
# named more than once: scripts/screenshots-plan.sh and docs/agents/device-testing.md),
# SHOTS_VARIANTS (default "portrait landscape largest-text"; "largest-text-landscape" on request;
# any of them with an "rtl-" prefix runs under Xcode's Right-to-Left Pseudolanguage, and "rtl" alone
# means "rtl-portrait rtl-landscape rtl-largest-text", the once-per-release pass, docs/agents/release.md),
# SHOTS_TESTS (ShotsUITests methods separated by spaces, such as "testSettings testForm"; default
# every one). Each variant's folder is emptied first, unless SHOTS_TESTS names the tests: then the
# images from other tests stay, and the run lists the ones it wrote, since those kept may be older
# than the code. SHOTS_KEEP_GOING=1 runs every test and lists every failure at the end; without it,
# the first failed test on any simulator stops every simulator's run (#302).
# Each variant's run adds a record to the test metrics (scripts/metrics.sh, #303): pass, fail, or
# stopped for a run that was cut short because another failed or the script was interrupted.
# Writes <SHOTS_OUT>/<simulator>/<variant>/<screen>.png, a clone's under the simulator it clones.
# Each simulator's progress lines start with "[<simulator>]" (a clone's with its own name), since
# they are interleaved.
set -uo pipefail
set -m # each simulator's run gets its own process group, so an interrupt can stop all of it
cd "$(dirname "$0")/.."

SIMULATORS="${SIMULATORS-iPhone 15 Pro - iOS 26.5;iPhone 15 - iOS 27.0}"
source scripts/screenshots-plan.sh
source scripts/screenshots-watch.sh
source scripts/metrics.sh
out="${SHOTS_OUT:-docs/screenshots/$(date +%F)}"
defaults=(portrait landscape largest-text)

# Prints the variants in $1 (separated by spaces), with "rtl" expanded to its three.
expand_variants() {
  local variant base
  for variant in $1; do
    case "$variant" in
      rtl) for base in "${defaults[@]}"; do echo "rtl-$base"; done ;;
      *) echo "$variant" ;;
    esac
  done
}

lanes="$(shots_lanes "$SIMULATORS" "${SHOTS_VARIANTS:-${defaults[*]}}" "${SHOTS_PLAN:-}")" || exit 1
only=()
for test in ${SHOTS_TESTS:-}; do only+=("-only-testing:NudgeShotsUITests/ShotsUITests/$test"); done
out="$(mkdir -p "$out" && cd "$out" && pwd)"
build=.build/screenshots
logs="$PWD/.build/test-logs"
mkdir -p "$build/Generated" "$logs"

# The fakes, minus their `@testable import`: in the harness they compile into the app itself.
grep -v '^@testable import NudgeInator$' NudgeInatorTests/Fakes.swift > "$build/Generated/Fakes.swift"
xcodegen generate --quiet --spec scripts/screenshots/project.yml --project "$build" || exit 1

# As scripts/test.sh: the UDID of the available simulator named exactly $1, or nothing.
simulator_udid() {
  xcrun simctl list devices available | awk -v name="$1" '
    { line = $0; sub(/^ +/, "", line) }
    index(line, name " (") == 1 {
      match(line, /[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr(line, RSTART, RLENGTH); exit }'
}

restore=()          # per simulator: UDID|text size|appearance, put back at the end
shut_down_at_exit=() # UDIDs of the simulators that were shut down when the run began
pids=()
failures="$(mktemp -d)" # one file per simulator and variant, a line per failure
metrics_scratch="$(mktemp -d)" # one file per variant run: where it began and ended (record_metrics)
cleanup() {
  trap '' USR1 # a lane that fails now must not cut this short
  # Stop the simulators' runs (and the xcodebuild under each) before undoing what they changed.
  for pid in ${pids[@]+"${pids[@]}"}; do kill -TERM -- "-$pid" 2>/dev/null; done
  wait 2>/dev/null
  for entry in ${restore[@]+"${restore[@]}"}; do
    IFS='|' read -r udid size appearance <<< "$entry"
    xcrun simctl ui "$udid" content_size "$size" 2>/dev/null
    xcrun simctl ui "$udid" appearance "$appearance" 2>/dev/null
    xcrun simctl uninstall "$udid" com.newrealityinteractive.nudgeinator.shots 2>/dev/null
    xcrun simctl uninstall "$udid" com.newrealityinteractive.nudgeinator.shots.uitests.xctrunner 2>/dev/null
  done
  for udid in ${shut_down_at_exit[@]+"${shut_down_at_exit[@]}"}; do
    xcrun simctl shutdown "$udid" 2>/dev/null
  done
  # After the simulators are put back, so a slow write can't hold that up. Here, not in each lane: a
  # lane that was just stopped can't record itself.
  record_metrics
  rm -rf "$failures" "$metrics_scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Adds a record for every variant run that began, from the files shoot() left in $metrics_scratch
# (name|variant|log|failure file|began|ended, the last empty for a run that didn't finish): fail if
# it named a failed test, else pass if it finished, else stopped. Never fails, and this runs in the
# exit trap, so a file cut short by a kill is skipped rather than allowed to stop the clean-up.
record_metrics() {
  local file name variant log failed_file began ended result failed line now
  now="$(date +%s)"
  for file in "$metrics_scratch"/*; do
    [ -f "$file" ] || continue
    IFS='|' read -r name variant log failed_file began ended < "$file"
    [[ "$began" =~ ^[0-9]+$ ]] || continue
    result=pass failed=""
    if [ -s "$failed_file" ]; then
      result=fail
      while IFS= read -r line; do
        failed="${failed:+$failed; }${line%" on $name, $variant"}"
      done < "$failed_file"
    elif [ -z "$ended" ]; then
      result=stopped
    fi
    metrics_record screenshots "$name" "$variant" "$(metrics_count_tests "$log")" "$(( ${ended:-$now} - began ))" "$result" "$failed"
  done
}

# Notes that $1 failed on the simulator $2 in the variant $3 (log $4), in the file $5, and, unless the
# run keeps going, asks the main script to stop every simulator's run.
record_failure() {
  echo "[$2] FAIL: $1 in $3, see $4" >&2
  echo "$1 on $2, $3" >> "$5"
  [ "${SHOTS_KEEP_GOING:-0}" = 1 ] || kill -USR1 $$ 2>/dev/null
}

# One simulator's run: its variants, one after the other. $1 is its name (a clone's has " clone <n>"
# on the end), $2 the matrix simulator whose folder the images go in, $3 its UDID, $4 the start of
# its failure files' paths, $5 its variants separated by spaces. Reads only, out, logs and build.
shoot() {
  local name="$1" folder="$2" udid="$3" failed_prefix="$4" lane_variants="$5"
  local variant base size orientation direction dir log started failed_file metrics_file began test
  for variant in $lane_variants; do
    echo "[$name] ==> $variant"
    # The rtl- prefix is a launch argument of the harness app's (ShotsUITests), so the simulator's
    # settings stay as they are; the rest of the name sets them as for any variant.
    base="${variant#rtl-}" direction=ltr
    [ "$base" = "$variant" ] || direction=rtl
    size=large orientation=portrait
    case "$base" in *landscape) orientation=landscape ;; esac
    case "$base" in largest-text*) size=accessibility-extra-extra-extra-large ;; esac
    xcrun simctl ui "$udid" content_size "$size"
    dir="$out/$folder/$variant"
    [ -n "${SHOTS_TESTS:-}" ] || rm -rf "$dir"
    mkdir -p "$dir"
    log="$logs/screenshots-$name-$variant.log"
    started="$log.started"
    failed_file="$failed_prefix-$variant"
    metrics_file="$metrics_scratch/${failed_prefix##*/}-$variant"
    began="$(date +%s)"
    echo "$name|$variant|$log|$failed_file|$began|" > "$metrics_file"
    touch "$started"
    TEST_RUNNER_SHOTS_DIR="$dir" TEST_RUNNER_SHOTS_ORIENTATION="$orientation" TEST_RUNNER_SHOTS_DIRECTION="$direction" \
      xcodebuild test-without-building -project "$build/NudgeShots.xcodeproj" -scheme NudgeShots \
      -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$build/derived" ${only[@]+"${only[@]}"} \
      2>&1 < /dev/null \
      | shots_watch_output "$log" \
      | while IFS= read -r test; do record_failure "$test" "$name" "$variant" "$log" "$failed_file"; done \
      || [ -s "$failed_file" ] \
      || record_failure "the run itself (no test named)" "$name" "$variant" "$log" "$failed_file"
    echo "[$name] $(ls "$dir" | wc -l | tr -d ' ') screenshots in $dir"
    if [ -n "${SHOTS_TESTS:-}" ]; then
      echo "[$name] wrote: $(find "$dir" -name '*.png' -newer "$started" -exec basename {} .png \; | sort | tr '\n' ' ')"
    fi
    rm -f "$started"
    echo "$name|$variant|$log|$failed_file|$began|$(date +%s)" > "$metrics_file"
  done
}

# Succeeds if the simulator $1 (a UDID) is booted.
is_booted() {
  local devices
  devices="$(xcrun simctl list devices)" # not piped into grep -q, which can end xcrun early (pipefail)
  [[ "$devices" == *"$1) (Booted)"* ]]
}

# Same as scripts/test.sh: the iOS 26.5 simulator's mediaanalysisd runs away after every boot. A
# clone is booted for the first time here, and scripts/test.sh may never have switched it off in
# the simulator it was cloned from.
quiet_media_analysis() {
  [ "${KEEP_MEDIA_ANALYSIS:-0}" = 1 ] && return 0
  xcrun simctl spawn "$1" launchctl disable system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
  xcrun simctl spawn "$1" launchctl bootout system/com.apple.mediaanalysisd > /dev/null 2>&1 || true
}

failed=()
# One entry per lane, by the same index: its simulator's name, the matrix simulator it is or clones,
# its UDID, its variants, and whether it was booted before this run.
names=() folders=() udids=() laneVariants=() wasBooted=()

# First every simulator is found, and a missing clone is made. Nothing is booted yet: a simulator
# must be shut down to be cloned, and one that was already booted is shut down for it (it is booted
# again below, and stays so, as scripts/test.sh leaves it).
while IFS='|' read -r matrix slot list; do
  [ -n "$matrix" ] || continue
  name="$(shots_lane_label "$matrix" "$slot")"
  udid="$(simulator_udid "$name")"
  if [ -z "$udid" ] && [ "$slot" -gt 0 ]; then
    source_udid="$(simulator_udid "$matrix")"
    if [ -n "$source_udid" ]; then
      if is_booted "$source_udid"; then xcrun simctl shutdown "$source_udid"; fi
      echo "==> Making the clone \"$name\""
      udid="$(xcrun simctl clone "$source_udid" "$name")"
      if [ -z "$udid" ]; then
        echo "FAIL: could not clone \"$matrix\" as \"$name\"" >&2
        failed+=("$name")
        continue
      fi
    fi
  fi
  if [ -z "$udid" ]; then
    echo "FAIL: no simulator named \"$matrix\" (see scripts/test.sh)" >&2
    failed+=("$name")
    continue
  fi
  names+=("$name") folders+=("$matrix") udids+=("$udid")
  laneVariants+=("$(expand_variants "$list" | tr '\n' ' ')")
  # A simulator shut down for its clone was booted before this run: its slot 0 lane came first.
  if is_booted "$udid"; then wasBooted+=(true); else wasBooted+=(false); fi
done <<< "$lanes"
# Registered before booting, so an interrupt while they boot still shuts them down.
for i in ${!udids[@]}; do
  ${wasBooted[$i]} || shut_down_at_exit+=("${udids[$i]}")
done
for i in ${!udids[@]}; do
  xcrun simctl boot "${udids[$i]}" 2>/dev/null || true # already booted is fine
done
for i in ${!udids[@]}; do
  xcrun simctl bootstatus "${udids[$i]}" -b > /dev/null 2>&1 || true
  restore+=("${udids[$i]}|$(xcrun simctl ui "${udids[$i]}" content_size)|$(xcrun simctl ui "${udids[$i]}" appearance)")
  xcrun simctl ui "${udids[$i]}" appearance light
  [ "${folders[$i]}" = "${names[$i]}" ] || quiet_media_analysis "${udids[$i]}"
done

if [ ${#udids[@]} -gt 0 ]; then
  echo "==> Building the harness"
  # In the background, so an interrupt stops it at once instead of after the build.
  build_began="$(date +%s)"
  xcodebuild build-for-testing -project "$build/NudgeShots.xcodeproj" -scheme NudgeShots \
    -destination "platform=iOS Simulator,id=${udids[0]}" -derivedDataPath "$build/derived" \
    > "$logs/screenshots-build.log" 2>&1 < /dev/null &
  pids+=($!)
  if ! wait "${pids[0]}"; then
    metrics_record screenshots-build "${names[0]}" "" "" "$(( $(date +%s) - build_began ))" fail ""
    echo "FAIL: see $logs/screenshots-build.log" >&2
    exit 1
  fi
  metrics_record screenshots-build "${names[0]}" "" "" "$(( $(date +%s) - build_began ))" pass ""
  pids=()
fi

# Adds the lanes' failures to the list "failed", prints it and exits 1, or returns if it is empty.
exit_if_anything_failed() {
  local file line
  for file in "$failures"/*; do
    [ -f "$file" ] || continue # the pattern matched nothing
    while IFS= read -r line; do failed+=("$line"); done < "$file"
  done
  [ ${#failed[@]} -gt 0 ] || return 0
  echo "FAIL:" >&2
  printf '  %s\n' "${failed[@]}" >&2
  exit 1
}

# record_failure's signal, ignored from here on so that two failures at once report once. Reported
# before anything is stopped, so a run this stops can't appear as a failure; exiting then stops the
# rest and cleans up, as an interrupt does.
trap 'trap "" USR1; echo "Stopping every simulator: a test failed (SHOTS_KEEP_GOING=1 runs on past failures)." >&2; exit_if_anything_failed' USR1

for i in ${!names[@]}; do
  shoot "${names[$i]}" "${folders[$i]}" "${udids[$i]}" "$failures/$i" "${laneVariants[$i]}" &
  pids+=($!)
done
for i in ${!pids[@]}; do
  wait "${pids[$i]}" || failed+=("${names[$i]}: its run stopped before it finished")
done
pids=()

exit_if_anything_failed
echo "Screenshots: $out"
