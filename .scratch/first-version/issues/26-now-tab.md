Status: ready-for-agent

# Now tab

Design spec: `docs/design/DESIGN.md` (Components: Nudge card, Nudge meter, Status label). Where it and the mockup disagree, see its Precedence note.

## What to build

Nudging cards each with the title, nudge count and urgency, and a **Done** button; Coming Up (next 7 days); Last 24 Hours. Data comes from the app model (queries from ticket 16). Tapping a card opens the reminder details (ticket 27). Done ends the occurrence and removes the card.

## Acceptance criteria

- [ ] With fixtures, the three sections show the right items, in the mockup's order.
- [ ] Tapping Done on a card closes the occurrence as Done and cancels its pending items (assert via fake adapters).
- [ ] A Missed occurrence appears under Last 24 Hours with its reason ("the next one took over" distinct).
- [ ] Empty state when nothing is nudging.
- [ ] Matches the mockup's Now screen (screenshot comparison noted in Comments).

Blocked by: 21, 24
