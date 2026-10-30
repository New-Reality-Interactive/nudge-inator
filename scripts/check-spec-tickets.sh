#!/usr/bin/env bash
# Checks that a spec issue, its sub-issues and the tickets' cross-references agree. Run it after
# creating, splitting or merging tickets (docs/agents/issue-tracker.md, Features, specs and tickets).
#
#   scripts/check-spec-tickets.sh <spec-issue-number>
#
# It fails when:
#   - the spec's "## Tickets" list (numbered lines starting `N. [#<n>](url)`) and the spec's
#     sub-issues name different tickets;
#   - a listed ticket's "Blocked by #a, #b" text and its native blockers differ;
#   - a ticket isn't in the spec's milestone, or doesn't carry exactly one of ready-for-agent and
#     ready-for-human;
#   - a ticket's body mentions an issue number that is neither the spec nor one of its tickets.
# It can't tell that a mention of a real ticket is stale (a criterion that moved in a split), so
# read the mentions of any ticket that was split.
set -uo pipefail
cd "$(dirname "$0")/.."

spec="${1:?usage: scripts/check-spec-tickets.sh <spec-issue-number>}"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
failed=false
fail() { echo "FAIL: $*" >&2; failed=true; }

# Sorted unique numbers, one line, from lines of numbers on stdin.
numbers() { sort -un | tr '\n' ' ' | sed 's/ $//'; }

body="$(gh issue view "$spec" --json body --jq .body)"
section="$(printf '%s\n' "$body" | awk '/^## Tickets$/ {on=1; next} /^## / {on=0} on')"
if [ -z "$section" ]; then
  echo "FAIL: spec #$spec has no '## Tickets' section" >&2
  exit 1
fi
items="$(printf '%s\n' "$section" | grep -E '^[0-9]+\. \[#[0-9]+\]')"

listed="$(printf '%s\n' "$items" | sed -E 's/^[0-9]+\. \[#([0-9]+)\].*/\1/' | numbers)"
subs="$(gh issue view "$spec" --json subIssues --jq '.subIssues.nodes[].number' | numbers)"
if [ "$listed" != "$subs" ]; then
  fail "the spec lists tickets [$listed] but its sub-issues are [$subs]"
fi

milestone="$(gh issue view "$spec" --json milestone --jq '.milestone.title')"
known=" $spec $subs "

for n in $subs; do
  info="$(gh issue view "$n" --json milestone,labels --jq '[.milestone.title, ([.labels[].name | select(. == "ready-for-agent" or . == "ready-for-human")] | length | tostring)] | join("|")')"
  [ "${info%%|*}" = "$milestone" ] || fail "#$n is in milestone '${info%%|*}', not '$milestone'"
  [ "${info##*|}" = "1" ] || fail "#$n needs exactly one of ready-for-agent and ready-for-human"

  native="$(gh api "repos/$repo/issues/$n/dependencies/blocked_by" --jq '.[].number' | numbers)"
  item="$(printf '%s\n' "$items" | grep -E "^[0-9]+\. \[#$n\]" | head -n 1)"
  written="$(printf '%s\n' "$item" | sed -n -E 's/.*Blocked by (.*)$/\1/p' | grep -oE '#[0-9]+' | tr -d '#' | numbers)"
  if [ -n "$item" ] && [ "$written" != "$native" ]; then
    fail "#$n: the spec says blocked by [$written] but its native blockers are [$native]"
  fi

  mentioned="$(gh issue view "$n" --json body --jq .body | grep -oE '#[0-9]+' | tr -d '#' | numbers)"
  for m in $mentioned; do
    case "$known" in
      *" $m "*) ;;
      *) fail "#$n mentions #$m, which is neither the spec nor one of its tickets" ;;
    esac
  done
done

if $failed; then exit 1; fi
echo "Spec #$spec: ${subs// /, } agree with its Tickets list, blockers, milestone, labels and mentions."
