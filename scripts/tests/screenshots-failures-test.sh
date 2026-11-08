#!/usr/bin/env bash
# Tests how a screenshot run finds and acts on a failed test (#302): scripts/screenshots-watch.sh
# against lines from real runs, then scripts/screenshots.sh over stand-ins for xcrun, xcodebuild and
# xcodegen. Needs no simulator, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
source scripts/screenshots-watch.sh

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f .build/test-logs/screenshots-Stub*' EXIT

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

# The failed tests the watcher names for the output $1.
named() { printf '%s\n' "$1" | shots_watch_output "$work/watched.log"; }

error_line="/Users/x/ShotsUITests.swift:143: error: -[NudgeShotsUITests.ShotsUITests testSettings] : failed - No 30 min:"
failed_line="Test Case '-[NudgeShotsUITests.ShotsUITests testSettings]' failed (357.718 seconds)."
passed_line="Test Case '-[NudgeShotsUITests.ShotsUITests testForm]' passed (12.000 seconds)."
started_line="Test Case '-[NudgeShotsUITests.ShotsUITests testForm]' started."

expect "a test is named at its first error line, before it ends" "testSettings" "$(named "$error_line")"
expect "a test is named by its failed line" "testSettings" "$(named "$failed_line")"
expect "a test with several failure lines is named once" "testSettings" \
  "$(named "$error_line
$error_line
$failed_line")"
expect "tests that pass or start are not named" "" "$(named "$started_line
$passed_line")"
expect "each failed test is named, in the order they fail" "testSettings
testForm" \
  "$(named "$error_line
/Users/x/ShotsUITests.swift:9: error: -[NudgeShotsUITests.ShotsUITests testForm] : XCTAssertTrue failed")"
expect "a selector inside the failure message is not the test" "testSettings" \
  "$(named "/Users/x/ShotsUITests.swift:143: error: -[NudgeShotsUITests.ShotsUITests testSettings] : failed - -[Other testOther]")"
expect "text that only mentions an error is not a failure" "" \
  "$(named "xcodebuild: error: something else
    Button, label: 'error: -[A testB]'")"

named "$started_line
$error_line" > /dev/null
expect "every line reaches the log" "$started_line
$error_line" "$(cat "$work/watched.log")"

printf 'caf\351 %s\n' "$error_line" | shots_watch_output "$work/bytes.log" > "$work/bytes.out"
expect "bytes that are not valid text don't stop the watcher" "testSettings" "$(cat "$work/bytes.out")"

# ---- scripts/screenshots.sh over stand-ins ----

a=AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA
b=BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB
stub="$work/stub"
mkdir -p "$stub/bin"

cat > "$stub/bin/xcodegen" <<'EOF'
#!/bin/bash
EOF

# simctl records its arguments. Both simulators start shut down, at a text size and appearance the
# run never sets, so a restore shows.
cat > "$stub/bin/xcrun" <<EOF
#!/bin/bash
echo "\$*" >> "\$STUB_DIR/simctl.log"
case "\$*" in
  "simctl list devices"*)
    echo "    Stub A ($a) (Shutdown)"
    echo "    Stub B ($b) (Shutdown)" ;;
  "simctl ui "*" content_size") echo extra-small ;;
  "simctl ui "*" appearance") echo dark ;;
esac
exit 0
EOF

# xcodebuild runs the file "<a or b>-<variant>" in $STUB_DIR, if there is one, and notes that it ran.
cat > "$stub/bin/xcodebuild" <<EOF
#!/bin/bash
case "\$*" in *build-for-testing*) exit 0 ;; esac
case "\$*" in *id=$a*) lane=a ;; *) lane=b ;; esac
variant="\$(basename "\$TEST_RUNNER_SHOTS_DIR")"
echo "\$lane-\$variant" >> "\$STUB_DIR/ran"
[ ! -f "\$STUB_DIR/\$lane-\$variant" ] || source "\$STUB_DIR/\$lane-\$variant"
EOF
chmod +x "$stub/bin/"*

# Clears the stand-ins' records and scenario files.
reset_stub() { rm -f "$stub"/simctl.log "$stub"/ran "$stub"/[ab]-* "$stub"/finished-*; }

# Runs the real script over the stand-ins, with any VAR=value arguments. Sets $status.
run_shots() {
  env PATH="$stub/bin:$PATH" STUB_DIR="$stub" SIMULATORS="Stub A;Stub B" SHOTS_OUT="$work/out" \
    SHOTS_VARIANTS="portrait landscape" "$@" scripts/screenshots.sh > "$work/output" 2>&1
  status=$?
}

fail_line() { echo "/Users/x/ShotsUITests.swift:1: error: -[NudgeShotsUITests.ShotsUITests $1] : failed - No button"; }

# expect_cleanup <description>: text size and appearance restored, harness uninstalled, simulators shut down.
expect_cleanup() {
  local udid
  for udid in "$a" "$b"; do
    expect "$1: text size restored on $udid" "simctl ui $udid content_size extra-small" \
      "$(grep "ui $udid content_size " "$stub/simctl.log" | tail -1)"
    expect "$1: appearance restored on $udid" "simctl ui $udid appearance dark" \
      "$(grep "ui $udid appearance " "$stub/simctl.log" | tail -1)"
    expect "$1: harness and runner uninstalled on $udid" "2" \
      "$(grep -c "uninstall $udid com.newrealityinteractive.nudgeinator.shots" "$stub/simctl.log")"
    expect "$1: shut down $udid" "1" "$(grep -c "shutdown $udid" "$stub/simctl.log")"
  done
}

reset_stub
{ echo 'sleep 1'; echo "echo '$(fail_line testBad)'"; echo 'sleep 20; touch "$STUB_DIR/finished-a"'; } > "$stub/a-portrait"
echo 'sleep 20; touch "$STUB_DIR/finished-b"' > "$stub/b-portrait"
run_shots
expect "a failed test fails the run" "1" "$status"
expect "the failure names the test, simulator and variant" "  testBad on Stub A, portrait" \
  "$(grep '^  ' "$work/output")"
expect "the lane that was stopped is not reported as a failure" "0" "$(grep -c 'FAIL.*Stub B\|Stub B: its run' "$work/output")"
expect "the failing test's own run stops" "no" "$([ -e "$stub/finished-a" ] && echo yes || echo no)"
expect "the other simulator's run stops" "no" "$([ -e "$stub/finished-b" ] && echo yes || echo no)"
expect "the failing simulator's next variant never starts" "0" "$(grep -c 'a-landscape' "$stub/ran")"
expect_cleanup "after a stop"

reset_stub
echo 'sleep 1; exit 65' > "$stub/a-portrait"
echo 'sleep 20; touch "$STUB_DIR/finished-b"' > "$stub/b-portrait"
run_shots
expect "a run that dies naming no test fails the run" "1" "$status"
expect "it says so, with the simulator and variant" "  the run itself (no test named) on Stub A, portrait" \
  "$(grep '^  ' "$work/output")"
expect "it stops the other simulator's run too" "no" "$([ -e "$stub/finished-b" ] && echo yes || echo no)"
expect_cleanup "after a run that named no test"

reset_stub
for lane in a b; do
  { echo 'sleep 1'; echo "echo '$(fail_line "test_$lane")'"; echo 'sleep 20'; } > "$stub/$lane-portrait"
done
run_shots
expect "two simulators failing together still fail the run" "1" "$status"
expect "and are reported once" "1" "$(grep -c '^Stopping' "$work/output")"
expect "with no failure listed twice" "" "$(grep '^  ' "$work/output" | sort | uniq -d)"
expect_cleanup "after two failures at once"

reset_stub
{ echo "echo '$(fail_line testBad)'"; echo 'exit 65'; } > "$stub/a-portrait"
{ echo "echo '$(fail_line testWorse)'"; echo 'exit 65'; } > "$stub/b-landscape"
run_shots SHOTS_KEEP_GOING=1
expect "keep-going still fails the run" "1" "$status"
expect "keep-going lists every failure at the end" "  testBad on Stub A, portrait
  testWorse on Stub B, landscape" "$(grep '^  ' "$work/output")"
expect "keep-going runs everything" "a-landscape
a-portrait
b-landscape
b-portrait" "$(sort "$stub/ran")"
expect_cleanup "after keep-going"

reset_stub
run_shots
expect "a run with no failures succeeds" "0" "$status"
expect "and reports none" "0" "$(grep -c 'FAIL' "$work/output")"
expect_cleanup "after a clean run"

[ "$failures" -eq 0 ] || { echo "FAIL: $failures check(s)" >&2; exit 1; }
echo "PASS: finding and acting on a failed screenshot test"
