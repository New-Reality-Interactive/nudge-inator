#!/usr/bin/env bash
# Sourced by scripts/screenshots.sh (and tested by scripts/tests/screenshots-plan-test.sh): which
# simulator runs which screenshot variants (#301).
#
# A lane is one simulator running its variants one after the other; lanes run at the same time. A
# lane's slot is 0 for the matrix simulator itself, 1 or 2 for its clones, which are named
# "<simulator> clone <slot>". A simulator never has more than SHOTS_MAX_CLONES clones, so it never
# has more than SHOTS_MAX_CLONES + 1 lanes.

SHOTS_MAX_CLONES=2

# The name of the simulator that runs slot $2 of the matrix simulator named $1.
shots_lane_label() {
  if [ "$2" -eq 0 ]; then echo "$1"; else echo "$1 clone $2"; fi
}

# Prints one "<simulator>|<slot>|<variants>" line per lane, in the order the plan first names them,
# so a simulator's slot 0 always comes before its clones (scripts/screenshots.sh relies on it).
#   $1  the matrix simulators, names separated by ";"
#   $2  the variants every one of them runs when there is no plan, separated by spaces
#   $3  the plan, or empty: entries "<simulator>=<variants>" separated by ";", which replace $1 and $2.
# The nth entry for a simulator is its slot (n-1) mod (SHOTS_MAX_CLONES + 1): the first runs on the
# simulator, the next two on clones, and any after that join the end of those lanes, in turn, so they
# run one after another on a simulator that exists. Fails (status 1, message on stderr, nothing
# printed) on an entry that is not "<simulator>=<variants>", or a variant named twice for a simulator.
shots_lanes() {
  local simulators="$1" variants="$2" plan="$3" entries
  if [ -n "$plan" ]; then
    entries="$(printf '%s' "$plan" | tr ';' '\n')"
  else
    entries=""
    local names name
    IFS=';' read -r -a names <<< "$simulators"
    for name in ${names[@]+"${names[@]}"}; do
      entries+="$name=$variants"$'\n'
    done
  fi
  printf '%s\n' "$entries" | awk -v slots="$((SHOTS_MAX_CLONES + 1))" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function fail(message) { print "FAIL: " message > "/dev/stderr"; failed = 1; exit 1 }
    {
      entry = trim($0)
      if (entry == "") next
      eq = index(entry, "=")
      name = (eq > 0) ? trim(substr(entry, 1, eq - 1)) : ""
      list = (eq > 0) ? trim(substr(entry, eq + 1)) : ""
      if (name == "" || list == "") fail("\"" entry "\" is not <simulator>=<variants>")
      count = split(list, words, /[ \t]+/)
      for (i = 1; i <= count; i++) {
        if ((name SUBSEP words[i]) in seen) fail("variant " words[i] " is named twice for " name)
        seen[name SUBSEP words[i]] = 1
      }
      slot = entries_for[name]++ % slots
      key = name SUBSEP slot
      if (key in lane_variants) {
        lane_variants[key] = lane_variants[key] " " list
      } else {
        order[++lanes] = key
        lane_name[key] = name
        lane_slot[key] = slot
        lane_variants[key] = list
      }
    }
    END {
      if (failed) exit 1
      for (i = 1; i <= lanes; i++) {
        key = order[i]
        print lane_name[key] "|" lane_slot[key] "|" lane_variants[key]
      }
    }
  '
}
