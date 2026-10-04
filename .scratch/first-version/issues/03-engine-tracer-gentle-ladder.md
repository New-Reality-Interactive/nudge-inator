Status: ready-for-agent

# Engine tracer: a Gentle reminder comes due and nudges on its ladder

Build the engine's one test seam end to end with the thinnest slice. Use `/tdd`: one failing test, then the minimum code, repeat.

## What to build

In the `NudgeEngine` package (no Apple imports):

- The engine interface: reminders, the current time (a clock), permission states and events in; occurrence state and a **schedule plan** out. The plan is the list of alarms and notifications that should be pending, each with fire time, nudge number, urgency and delivery kind.
- A **fake clock** and a **fake scheduler adapter** (records the plan it is given) for tests.
- First behaviour: a Gentle reminder with a due time. Before it is due there is no open occurrence and the plan is empty or only holds the first nudge as designed. When it comes due, the occurrence is Nudging and the plan holds the Gentle ladder: first nudge at the due time, then every 60 minutes, easing by factor 0.75 down to a floor of 20 minutes.
- Notification text for each planned nudge: title and "Nudge N of 20 · Urgency". No notes or tags in any plan item.

Tests assert only on occurrence state and the plan, through the engine's interface.

## Acceptance criteria

- [ ] A reminder that is not yet due has no open occurrence.
- [ ] At the due time the occurrence is Nudging, starting at nudge 1.
- [ ] Gentle intervals start at 60 minutes, shrink by factor 0.75 each nudge and never go below 20 minutes. Write the rounding rule (for example to the whole minute) in the code's doc comment and a test, and check it against the mockup's How It Nudges table in `docs/mockups/2026-10-04-first-version/index.html`.
- [ ] Every plan item carries title and "Nudge N of 20 · Urgency" text and nothing from notes or tags.
- [ ] The test suite uses only the fake clock and fake scheduler; no real time, no Apple frameworks. `scripts/test.sh` passes.

Blocked by: 01
