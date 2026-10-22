Status: resolved

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

- [x] A reminder that is not yet due has no open occurrence.
- [x] At the due time the occurrence is Nudging, starting at nudge 1.
- [x] Gentle intervals start at 60 minutes, shrink by factor 0.75 each nudge and never go below 20 minutes. Write the rounding rule (for example to the whole minute) in the code's doc comment and a test, and check it against the mockup's How It Nudges table in `docs/mockups/archive/2026-10-04-first-version/index.html`.
- [x] Every plan item carries title and "Nudge N of 20 · Urgency" text and nothing from notes or tags.
- [x] The test suite uses only the fake clock and fake scheduler; no real time, no Apple frameworks. `scripts/test.sh` passes.

Blocked by: 01

## Comments

**Before the due time the plan already holds the whole ladder** (nudges 1–20), and the occurrence isn't open until the due time. The app gets no callback when a notification or alarm fires, so if the plan held only nudge 1, or nothing, someone who never opens the app would get one nudge or none. Decided with the user on 2026-10-14. Planning ahead for later occurrences of a repeat is left to tickets 08 and 10. The 64-notification cap is left to tickets 15 and 18.

**Rounding rule: each wait is rounded to the nearest whole second**, which is what the mockup's `intervalAt` does (`Math.round(minutes * 60) / 60`). Gentle waits are 3600 s, 2700 s, 2025 s (33 min 45 s, shown in the table as "33.8 min"), 1519 s (from 1518.75 s, shown as "25.3 min"), then the 1200 s floor. So nudges fire at +0, +1 h, +1 h 45 min, +2 h 18 min 45 s, +2 h 44 min 4 s, then every 20 min, and nudge 20 is at +7 h 44 min 4 s. That matches the table's rows. Rounding to the whole minute would make the third wait 34 min, which doesn't match. The rule is in the doc comment on `Strength.interval(afterNudge:)` and is tested in `gentleWaitEasesToTwentyMinuteFloorRoundedToWholeSecond`.

**Gentle urgency follows the mockup's How It Nudges table:** nudges 1–4 are Normal and nudges 5–20 are High. Delivery kind is the Break-through-Focus-on mapping: Normal is an ordinary notification and High is Time Sensitive. Ticket 04 adds the other strengths, and ticket 05 adds the switch.

**Give-up limit:** `GiveUpLimit.nudgeCount = 20` bounds the plan and supplies the "of 20". The 24-hour span and closing as Missed are left to ticket 06.

**Interface:** `Engine(clock:scheduler:)`, `update(reminders:)` (hands the plan to the `SchedulerAdapter`) and `openOccurrence(for:)`. The type is `Engine`, not `NudgeEngine`, so it doesn't shadow the module name. `FakeClock` and `FakeScheduler` live in the test target.
