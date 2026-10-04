Status: ready-for-agent

# Give-up limit closes the occurrence as Missed

## What to build

Fixed give-up limit: 20 nudges or 24 hours after the due time, whichever comes first. The plan never contains nudges past the limit. When the limit is reached (the clock passes the last nudge or 24 hours), the occurrence closes as **Missed** and nothing remains pending. No editor and no per-strength minimum.

## Acceptance criteria

- [ ] Relentless reaches 20 nudges well before 24 hours and closes as Missed after nudge 20.
- [ ] Gentle: whichever of 20 nudges / 24 hours comes first ends the occurrence; test both a case where the count wins and, if the ladder allows, one where the time wins (state the result in the test name).
- [ ] No plan item has nudge number > 20 or a fire time > 24 hours after the due time.
- [ ] After closing as Missed the plan for that occurrence is empty.
- [ ] A Missed occurrence is visible in occurrence state with a reason of "give-up limit".

Blocked by: 04
