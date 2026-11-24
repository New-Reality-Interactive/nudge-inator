#!/usr/bin/env bash
# Sourced by scripts/screenshots.sh (and tested by scripts/tests/screenshots-failures-test.sh): finds
# the failed tests in xcodebuild's output while it runs (#302).

# Copies stdin (xcodebuild's output) to the file $1 and prints each failed test's name once, the
# moment it first fails. A failure is an " error: -[Class test]" line, which comes as the test fails
# (the walk has continueAfterFailure, so its end can be minutes later), or a "Test Case ... failed"
# line, which is all a test that crashes gets. The C locale keeps awk from stopping on a byte that
# isn't valid text. With a second argument, a file, it also appends each test that passes to it, one
# name a line, the moment it passes (the resume ledger, #488).
shots_watch_output() {
  LC_ALL=C awk -v copy="$1" -v passed_file="${2:-}" '
    {
      print > copy
      fflush(copy)
      if (passed_file != "" && $0 ~ /^Test Case \047.*\047 passed \(/ && match($0, /-\[[^] ]+ [^]]+\]/)) {
        passed = substr($0, RSTART, RLENGTH)
        sub(/^-\[[^ ]+ /, "", passed)
        sub(/\]$/, "", passed)
        print passed >> passed_file
        fflush(passed_file)
        next
      }
      if ($0 ~ /^Test Case \047/ && $0 !~ /\047 failed \(/) next
      if (!match($0, /(^Test Case \047| error: )-\[[^] ]+ [^]]+\]/)) next
      test = substr($0, RSTART, RLENGTH)
      sub(/^.*-\[[^ ]+ /, "", test)
      sub(/\]$/, "", test)
      if (test in seen) next
      seen[test] = 1
      print test
      fflush()
    }
  '
}
