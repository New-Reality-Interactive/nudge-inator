Status: ready-for-agent

# Tags tab

## What to build

Tags only. A list of tags, each with counts of reminders, due today and nudging. **+** adds a tag. Edit mode renames or deletes a tag; deleting warns how many reminders use it and never deletes those reminders. Tapping a tag pushes a screen of that tag's reminders; its **+** opens the New Reminder form (ticket 22) with that tag already chosen. No multi-tag filtering here.

## Acceptance criteria

- [ ] Counts match ticket 15's fixtures.
- [ ] Adding `Home` when `#home` exists is rejected with a message.
- [ ] Delete of a tag used by 3 reminders shows "3 reminders use this tag" and, after confirming, the reminders still exist without the tag.
- [ ] Rename to an existing tag (ignoring case) is rejected.
- [ ] + on a tag's screen opens the form with that tag preselected.
- [ ] Empty state when there are no tags.

Blocked by: 15, 22
