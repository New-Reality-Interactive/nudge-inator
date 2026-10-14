Status: ready-for-agent

# Tags, My Day counts and filters, Now sections, Tags-tab counts

## What to build

Pure queries and rules in the engine package:

- **Tag rules**: one word, shown as `#home`; names unique ignoring case (`Home` and `#home` are the same tag); create, rename (conflict → rejected), delete (reports how many reminders use it; reminders are kept and lose the tag).
- **My Day**: today's occurrences in time order; counts Done, Nudging, Missed, Left (Skipped not counted as Missed); filter by one count; filter by tags with Match All / Match Any; No Tags.
- **Now**: nudging occurrences, Coming Up (next 7 days), Last 24 Hours.
- **Tags tab**: for each tag, counts of reminders, due today and nudging; a tag's reminder list.

## Acceptance criteria

- [ ] `Home`, `#home` and `HOME` resolve to one tag.
- [ ] Deleting a tag reports the number of reminders using it and keeps all of them.
- [ ] My Day counts match a fixed fixture (Done 2, Nudging 1, Missed 1, Left 3 or similar), and Skipped is in none of Done/Missed.
- [ ] Match All returns only reminders with every selected tag; Match Any returns those with at least one; No Tags returns untagged ones.
- [ ] Coming Up includes day 7 and excludes day 8; Last 24 Hours includes closed occurrences from the past 24 h only.
- [ ] Tags-tab counts for reminders, due today, nudging are right for a multi-tag reminder (counted under each of its tags).

Blocked by: 07
