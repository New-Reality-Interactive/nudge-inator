#!/usr/bin/env bash
# Tests scripts/metrics.sh (#303): the record writer and the readers of xcodebuild's logs. Needs no
# simulator and never writes to the real metrics folder, so CI runs it too (scripts/test.sh).
set -uo pipefail
cd "$(dirname "$0")/../.."
source scripts/metrics.sh

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

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

# ---- the record writer ----

export NUDGE_METRICS_DIR="$work/metrics"
export NUDGE_METRICS_TICKET=303 NUDGE_METRICS_COMMIT=abc1234

# Prints the records' fields after "time", which changes with every run.
records() { sed 's/"time":"[^"]*",//' "$NUDGE_METRICS_DIR/runs.jsonl"; }

metrics_record app-tests "iPhone 15 - iOS 27.2" "" 505 14 pass ""
expect "a record holds ticket, commit, step, simulator, variant, tests, duration, result and failed test" \
  '{"ticket":303,"commit":"abc1234","step":"app-tests","simulator":"iPhone 15 - iOS 27.2","variant":null,"tests":505,"duration":14,"result":"pass","failed":null}' \
  "$(records)"
expect "a record has a time" "1" "$(grep -c '"time":"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]*Z"' "$NUDGE_METRICS_DIR/runs.jsonl")"

metrics_record screenshots "Sim \"A\"" landscape "" 61 fail 'testA on Sim "A", landscape\nback\slash'
expect "records are appended, one line each" "2" "$(wc -l < "$NUDGE_METRICS_DIR/runs.jsonl" | tr -d ' ')"
expect "quotes, backslashes and newlines are escaped" \
  '{"ticket":303,"commit":"abc1234","step":"screenshots","simulator":"Sim \"A\"","variant":"landscape","tests":null,"duration":61,"result":"fail","failed":"testA on Sim \"A\", landscape\\nback\\slash"}' \
  "$(records | tail -1)"

metrics_record x s "" 1 1 stopped ""
expect "a result of stopped is recorded as it is" "stopped" "$(records | tail -1 | sed 's/.*"result":"\([a-z]*\)".*/\1/')"

# Concurrent writers: no line is lost or torn.
rm -rf "$NUDGE_METRICS_DIR"
for i in $(seq 1 40); do metrics_record concurrent "Sim $i" "" 1 1 pass "" & done
wait
expect "forty writers at once leave forty whole records" "40" \
  "$(grep -c '^{.*"step":"concurrent".*}$' "$NUDGE_METRICS_DIR/runs.jsonl")"

# A failure to write warns and never fails the caller.
mkdir -p "$work/blocked" && touch "$work/blocked/file"
NUDGE_METRICS_DIR="$work/blocked/file/inside" metrics_record x s "" 1 1 pass "" 2> "$work/warning"
expect "a folder that can't be made doesn't fail the caller" "0" "$?"
expect "it warns instead" "1" "$(grep -c '^warning: ' "$work/warning")"

# No iCloud Drive (as on CI): the default location is skipped with a warning.
(
  unset NUDGE_METRICS_DIR; metrics_warned=false
  HOME="$work/no-icloud" metrics_record x s "" 1 1 pass "" 2> "$work/warning"
  echo "status $?" >> "$work/warning"
)
expect "with no iCloud Drive the caller still succeeds" "status 0" "$(tail -1 "$work/warning")"
expect "with no iCloud Drive it warns" "1" "$(grep -c '^warning: .*iCloud Drive' "$work/warning")"
expect "with no iCloud Drive nothing is created" "no" "$([ -e "$work/no-icloud" ] && echo yes || echo no)"

# The default is the visible iCloud Drive folder, and the override is the only other place.
expect "the default location is in iCloud Drive, in a visible folder" \
  "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Nudge-inator Test Metrics" \
  "$(unset NUDGE_METRICS_DIR; metrics_dir)"
expect "the override replaces it" "$work/metrics" "$(NUDGE_METRICS_DIR="$work/metrics" metrics_dir)"

# ---- the log readers ----

log="$work/xcodebuild.log"
cat > "$log" <<'LOG'
Test Case '-[NudgeShotsUITests.ShotsUITests testForm]' passed (12.000 seconds).
Test Case '-[NudgeShotsUITests.ShotsUITests testSettings]' failed (357.718 seconds).
Test Case '-[NudgeShotsUITests.ShotsUITests testSettings]' failed (357.718 seconds).
Test Case '-[NudgeShotsUITests.ShotsUITests testRows]' started.
✔ Test fine() passed after 0.001 seconds.
✘ Test aSaveAfterTheFormLocks() recorded an issue at ReminderFormTests.swift:418:9: Expectation failed
✘ Test aSaveAfterTheFormLocks() failed after 0.008 seconds with 1 issue.
✘ Test "a named test" failed after 0.028 seconds with 1 issue.
✘ Test run with 136 tests in 4 suites failed after 2.247 seconds with 2 issues.
􀢄 Test run with 27 tests in 1 suite failed after 0.014 seconds with 2 issues.
	 Executed 2 tests, with 1 failure (0 unexpected) in 369.718 (369.720) seconds
LOG
expect "the count adds Swift Testing's runs and XCTest's finished tests" "165" "$(metrics_count_tests "$log")"
expect "each failed test is named once, from either framework" \
  "testSettings; aSaveAfterTheFormLocks(); a named test" "$(metrics_failed_tests "$log")"
printf '✔ Test run with 1 test in 1 suite passed after 0.1 seconds.\n' > "$log"
expect "a run of one test is counted" "1" "$(metrics_count_tests "$log")"
expect "a log with no failure names none" "" "$(metrics_failed_tests "$log")"
expect "a log that isn't there counts and names nothing" "" "$(metrics_count_tests "$work/missing.log")$(metrics_failed_tests "$work/missing.log")"

[ "$failures" -eq 0 ] || { echo "FAIL: $failures check(s)" >&2; exit 1; }
echo "PASS: recording test metrics"
