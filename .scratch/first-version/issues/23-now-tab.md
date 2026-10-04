Status: ready-for-agent

# Now tab

## What to build

Nudging cards each with the title, nudge count and urgency, and a **Done** button; Coming Up (next 7 days); Last 24 Hours. Data comes from the app model (queries from ticket 15). Tapping a card opens the reminder details (ticket 24). Done ends the occurrence and removes the card.

## Acceptance criteria

- [ ] With fixtures, the three sections show the right items, in the mockup's order.
- [ ] Tapping Done on a card closes the occurrence as Done and cancels its pending items (assert via fake adapters).
- [ ] A Missed occurrence appears under Last 24 Hours with its reason ("the next one took over" distinct).
- [ ] Empty state when nothing is nudging.
- [ ] Matches the mockup's Now screen (screenshot comparison noted in Comments).

Blocked by: 20, 22
