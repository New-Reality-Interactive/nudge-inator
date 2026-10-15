Status: resolved

# Give-up limit closes the occurrence as Missed

## What to build

Fixed give-up limit: 20 nudges or 24 hours after the due time, whichever comes first. The plan never contains nudges past the limit. When the limit is reached (the clock passes the last nudge or 24 hours), the occurrence closes as **Missed** and nothing remains pending. No editor and no per-strength minimum.

## Acceptance criteria

- [x] Relentless reaches 20 nudges well before 24 hours and closes as Missed after nudge 20.
- [x] Gentle: whichever of 20 nudges / 24 hours comes first ends the occurrence; test both a case where the count wins and, if the ladder allows, one where the time wins (state the result in the test name).
- [x] No plan item has nudge number > 20 or a fire time > 24 hours after the due time.
- [x] After closing as Missed the plan for that occurrence is empty.
- [x] A Missed occurrence is visible in occurrence state with a reason of "give-up limit".

Blocked by: 04

## Comments

**Which limit wins: the 20-nudge count, for every strength today.** Nudge 20 fires at +7 h 44 min 4 s (Gentle), +2 h 12 min 30 s (Firm) and +49 min 30 s (Relentless), and each occurrence gives up one floor wait later: +8 h 4 min 4 s, +2 h 17 min 30 s and +51 min 30 s. None comes near 24 hours, so with today's `Ladder` constants the time limit can't win. The engine still enforces it (`GiveUpLimit.span`, 24 h). Plan items must fire before the span ends, and the give-up time is capped at it, so a retuned ladder can't nudge past a day. To test the case where time wins without touching the `Ladder` constants, `Engine` has an internal `init(clock:scheduler:giveUpSpan:)`. The public init passes `GiveUpLimit.span`. It is internal because the spec fixes the limit and gives it no editor, and the test reaches it with `@testable import`. `gentleTimeWinsWithThreeHourSpanAfterNudgeFiveAndClosesAsMissedAtThreeHours` uses a 3-hour span: Gentle sends nudges 1–5, nudge 6 (+3 h 4 min 4 s) is never planned, and the occurrence is Missed at exactly +3 h. `countWinsAndOccurrenceClosesAsMissedOneWaitAfterNudgeTwenty` covers the real limit for all three strengths.

**When it becomes Missed: one wait after nudge 20,** at the moment nudge 21 would have fired, or at 24 hours if that comes sooner. That is the mockup's `simulate`: `giveUpAt` is `min(t + interval, maxDur)` after the last nudge is pushed. It gives the person a full wait to answer the last nudge, the same as every earlier nudge. Becoming Missed at nudge 20's own fire time would make the last nudge one that can't be answered. A nudge is planned only if it fires strictly before the 24-hour mark (the mockup's `t < maxDur`). The rule is `Strength.giveUpTime(from:within:)` in `Ladder.swift`.

**How the plan empties: calling `update(reminders:)` again.** No new entry point. The plan is still made only on `update`. It now leaves out every reminder whose latest occurrence is Missed at the clock's current time. The app gets no callback when a nudge fires (ticket 03), so moving time forward doesn't re-plan on its own. The app wiring (ticket 21) should call `update` on launch and on returning to the foreground. Nothing is lost while it doesn't: every planned nudge fires at or before nudge 20, before the occurrence becomes Missed, so by then nothing for that occurrence is still pending. The empty plan just matches the system to the state. While the occurrence is Nudging the plan still holds the whole ladder (ticket 03's rule is unchanged).

**How a Missed occurrence is read: `latestOccurrence(for:)`.** It is new and returns the reminder's latest occurrence, open or closed (nil before the first due time). `openOccurrence(for:)` keeps its meaning and is now `latestOccurrence` filtered to Nudging, so it returns nil once the occurrence is Missed. `OccurrenceState` gains `.missed(reason: MissedReason)`, and `MissedReason` has one case, `.giveUpLimit`. Ticket 10's take-over adds its own case ("the next one took over"; the mockup's `closedWhy` has the two reasons). My Day (ticket 28) will need today's occurrences, not just the latest. That is left to the repeat tickets, where a reminder first has more than one occurrence.

**Tests** are in `GiveUpLimitTests.swift`. Red first: the count-wins test (no `latestOccurrence` or Missed yet), the time-wins test (no span) and the empty-plan test. These passed on their first run and stay as acceptance coverage: the Gentle and Firm cases of count-wins (added after Relentless drove the code), the plan-bounds test, and `missedOccurrenceIsNoLongerOpen`.

**Left alone:** Done and Stop (07), repeats and take-over (08–10), Pause and Skipped (11), the fallbacks (14, 15), the 64-notification cap, and the adapters.
