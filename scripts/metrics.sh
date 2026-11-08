#!/usr/bin/env bash
# Sourced by scripts/test.sh and scripts/screenshots.sh (and tested by scripts/tests/metrics-test.sh):
# each run appends a record of itself to a file in a visible folder, outside the repository (#303).
# This Mac has no Time Machine backup, so the folder is in iCloud Drive, the only local place with a
# copy off the Mac.
#
# The location is set here and nowhere else. Env: NUDGE_METRICS_DIR (the folder; a run that sets it
# writes there and never to iCloud Drive, as the scripts' own tests do), NUDGE_METRICS_TICKET (the
# ticket, when the branch name doesn't carry it), NUDGE_METRICS_COMMIT (as the ticket, for the commit).
#
# Writing never fails or stops a run: a record that can't be written is a warning. Where there is no
# iCloud Drive (CI) the default location is skipped, with one warning per run.
#
# The records are in <folder>/runs.jsonl, a line of JSON each. A line is appended in one write, so
# runs going at the same time don't tear each other's lines (and there is no header to race for).

metrics_icloud_drive() {
  echo "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
}

metrics_default_dir() {
  echo "$(metrics_icloud_drive)/Nudge-inator Test Metrics"
}

# Prints the folder the records go in.
metrics_dir() {
  echo "${NUDGE_METRICS_DIR:-$(metrics_default_dir)}"
}

metrics_warned=false
# Warns once per run (a warning for every record would bury the run's own output).
metrics_warn() {
  [ "$metrics_warned" = true ] || echo "warning: $*" >&2
  metrics_warned=true
}

# Prints the ticket the branch is for: the number after the feature's slug in `<feature>-<n>-<slug>`
# (docs/agents/ticket-workflow.md), or nothing on any other branch.
metrics_ticket() {
  if [ -n "${NUDGE_METRICS_TICKET:-}" ]; then echo "$NUDGE_METRICS_TICKET"; return; fi
  git rev-parse --abbrev-ref HEAD 2>/dev/null | sed -n 's/^[a-z][a-z-]*-\([0-9][0-9]*\)-.*/\1/p'
}

# Prints the short hash of the commit the run is on.
metrics_commit() {
  echo "${NUDGE_METRICS_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null)}"
}

# Appends a record: metrics_record <step> <simulator> <variant> <tests> <duration in seconds>
# <result: pass, fail or stopped> <failed test>. Any of them may be empty, which is null. Always
# succeeds.
metrics_record() {
  local dir line
  if [ -z "${NUDGE_METRICS_DIR:-}" ] && [ ! -d "$(metrics_icloud_drive)" ]; then
    metrics_warn "iCloud Drive not found, so this run's metrics are not recorded" \
      "(NUDGE_METRICS_DIR sets another folder)"
    return 0
  fi
  dir="$(metrics_dir)"
  line="$(perl -e '
    sub text { my $s = shift; return "null" if $s eq ""; $s =~ s/(["\\])/\\$1/g; $s =~ s/\n/\\n/g;
      $s =~ s/([\x00-\x1f])/sprintf("\\u%04x", ord $1)/ge; return "\"$s\"" }
    sub number { my $s = shift; return $s =~ /^[0-9]+$/ ? $s : "null" }
    my ($ticket, $commit, $step, $simulator, $variant, $tests, $duration, $result, $failed) = @ARGV;
    my @t = gmtime;
    my $time = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
    print "{\"time\":\"$time\",\"ticket\":" . number($ticket) . ",\"commit\":" . text($commit)
      . ",\"step\":" . text($step) . ",\"simulator\":" . text($simulator) . ",\"variant\":" . text($variant)
      . ",\"tests\":" . number($tests) . ",\"duration\":" . number($duration) . ",\"result\":" . text($result)
      . ",\"failed\":" . text($failed) . "}\n";
  ' -- "$(metrics_ticket)" "$(metrics_commit)" "$1" "$2" "$3" "$4" "$5" "$6" "$7")" || line=""
  if [ -z "$line" ]; then
    metrics_warn "could not format this run's metrics record"
    return 0
  fi
  { mkdir -p "$dir" && printf '%s\n' "$line" >> "$dir/runs.jsonl"; } 2> /dev/null \
    || metrics_warn "could not write the metrics to $dir"
  return 0
}

# Prints how many tests the xcodebuild log $1 ran: Swift Testing's "Test run with N tests" lines
# added up, and each XCTest case that finished (a case can finish more than once in a log), or
# nothing when it ran none (a build that failed, a log that isn't there).
metrics_count_tests() {
  [ -f "$1" ] || return 0
  LC_ALL=C perl -ne '
    $n += $1 if /Test run with ([0-9]+) tests?\b/;
    $seen{$1} = 1 if /^Test Case \x27(-\[[^\]]+\])\x27 (?:passed|failed)\b/;
    END { $n += keys %seen; print "$n\n" if $n }
  ' "$1"
}

# Prints the tests that failed in the xcodebuild log $1, each once, in the order they failed,
# separated by "; ": Swift Testing's "✘ Test <name> failed after" lines and XCTest's "Test Case
# '-[Class name]' failed" lines.
metrics_failed_tests() {
  [ -f "$1" ] || return 0
  LC_ALL=C perl -ne '
    my $name;
    if (/^\xe2\x9c\x98 Test (?!run with [0-9])(.+?) failed after /) { $name = $1; $name =~ s/^"(.*)"$/$1/ }
    elsif (/^Test Case \x27-\[[^ \]]+ ([^\]]+)\]\x27 failed\b/) { $name = $1 }
    next unless defined $name && !$seen{$name}++;
    push @names, $name;
    END { print join("; ", @names) . "\n" if @names }
  ' "$1"
}
