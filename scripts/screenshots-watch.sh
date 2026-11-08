#!/usr/bin/env bash
# Sourced by scripts/screenshots.sh (and tested by scripts/tests/screenshots-failures-test.sh): finds
# the failed tests in xcodebuild's output while it runs (#302).

# Copies stdin (xcodebuild's output) to the file $1 and prints each failed test's name once, the
# moment it first fails. A failure is an " error: -[Class test]" line, which comes as the test fails
# (the walk has continueAfterFailure, so its end can be minutes later), or a "Test Case ... failed"
# line, which is all a test that crashes gets. The C locale keeps awk from stopping on a byte that
# isn't valid text.
shots_watch_output() {
  LC_ALL=C awk -v copy="$1" '
    {
      print > copy
      fflush(copy)
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
