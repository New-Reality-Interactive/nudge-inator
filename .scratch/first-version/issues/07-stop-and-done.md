Status: ready-for-agent

# Stop moves the ladder along; Done ends it and cancels everything pending

See `docs/adr/0001-stop-silences-done-is-deliberate.md`.

## What to build

- **Stop** event (the alarm's system Stop): the occurrence stays Nudging; the next nudge still comes on schedule; the plan keeps all later nudges. Stop is **not** Done.
- **Done** event (from card, notification action, swipe, My Day, Open destination): the occurrence closes as Done and the plan removes every pending alarm and notification for it. Done after the occurrence already closed (Missed) is ignored or reported, document which.
- **App opened** event: the engine reconciles with the clock (nudges whose time has passed count as delivered, give-up limit applied).

## Acceptance criteria

- [ ] After Stop at nudge 4, state is Nudging and the plan still has nudges 5…N at their original times.
- [ ] After Done, occurrence state is Done and the plan has zero items for it.
- [ ] Stop twice, or Stop after the last nudge, does not crash or change the close reason.
- [ ] App opened after a long gap closes an over-limit occurrence as Missed and leaves a within-limit one Nudging at the right nudge number.
- [ ] No event other than Done closes an occurrence as Done.

Blocked by: 06
