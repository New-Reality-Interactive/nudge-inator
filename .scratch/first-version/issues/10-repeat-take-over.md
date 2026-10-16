Status: resolved

# Take-over: the next occurrence closes the open one as Missed

## What to build

If the next occurrence of a repeating reminder falls due while the previous one is still Nudging, the previous closes as **Missed** with reason "the next one took over", the new one starts at nudge 1, and the plan contains only the new occurrence's nudges. A reminder has at most one open occurrence. No carry-over.

## Acceptance criteria

- [x] An every-day Relentless reminder left Nudging past 24 hours cannot hold two open occurrences at any moment (test at the take-over instant).
- [x] The taken-over occurrence has state Missed and reason "the next one took over" (distinct from the give-up limit reason).
- [x] The new occurrence's first plan item is nudge 1 at its due time, at the lowest urgency, regardless of where the old one was.
- [x] The old occurrence's pending items are gone from the plan.
- [x] When the previous is already Done or Missed, no take-over reason is recorded.
- [x] Take-over uses the next due time of any repeat rule, preset or custom (test an every-2-days custom rule as well as Every Day).
- [x] The last occurrence of a custom rule that ends (COUNT or UNTIL) has nothing to take it over: it closes by Done or the give-up limit only.

Blocked by: 06, 08, 09

## Comments

**Decisions settled with the user before coding (2026-10-15).**
- **How the overlap is made testable: a widened give-up limit in the test.** With the shipped limits the overlap can't happen. Every strength gives up within 8 h 4 min 4 s and the shortest repeat gap is a day. Widening the span alone isn't enough either: the 20-nudge count stops Relentless at +51 min 30 s. So the give-up limit is now a value, `GiveUpLimit(nudgeCount:span:)`, with `.shipped` (20 nudges or 24 hours). `Engine`'s internal init takes `giveUpLimit:` in place of ticket 06's `giveUpSpan:`. The tests use 10,000 nudges or 72 hours, so an every-day or every-2-days Relentless reminder is still Nudging when the next falls due. The `Ladder` constants are untouched. The first criterion is tested with that widened limit.
- **Where take-over is decided: computed from the clock, not recorded.** It works like the give-up limit:
  - An occurrence is `.missed(reason: .nextTookOver)` when the next due time has arrived and comes at or before its give-up time, and it isn't Done.
  - Done is checked first, and give-up next.
  - `MissedReason` gains `.nextTookOver`, the mockup's `superseded` ("Missed: the next one took over").
  - The engine gets no callback when time passes, so a recorded event would have to be noticed, and nothing could notice it.
- **How the taken-over occurrence is read: `occurrence(of:dueAt:)`, new and public.**
  - It returns any past occurrence's state as of now. It returns `nil` for a time that isn't one of the reminder's due times, or hasn't come yet.
  - `latestOccurrence(for:)` uses the same computation. The latest can't have been taken over: its next due time is after now by definition, so it skips that search.
  - My Day (ticket 28) can build today's occurrences from this, plus the due times for the day.
- **A tie goes to take-over.** When the give-up time is exactly the next due time, the occurrence was taken over. The mockup's `simulate` says the same: `takeover: t >= until`. With a 24-hour span and no count limit, an every-day reminder hits this tie on ordinary days (`whenTheGiveUpTimeIsTheNextDueTimeTheNextTakesOver`). Across DST the two times part (`acrossADSTChangeTheReasonFollowsWhichComesFirst`):
  - The 23-hour March day takes over an hour early.
  - The 25-hour November day gives up an hour first.
- **Done after take-over closes the new occurrence.** `markDone(_:)` keeps ticket 07's meaning: it closes whatever is open. The taken-over occurrence can't become Done, and it keeps its reason (`doneAfterTakeOverClosesTheNewOccurrence`). **For ticket 18:** a Done tapped on a stale notification of the old occurrence, still sitting in Notification Center, would close the new one. If that matters, the notification action should carry the occurrence's due time, and Done should be ignored when it isn't the open one.
- **"No take-over reason is recorded"** means a previous occurrence already closed keeps its own state. Done stays Done (`aPreviousOccurrenceThatIsDoneStaysDone`). One Missed by the give-up limit keeps `.giveUpLimit`, with the shipped limit and with a widened 12-hour one (`aPreviousOccurrenceMissedByTheGiveUpLimitKeepsThatReason`).

**How the old ladder is cut.**
- **The rule:** each ladder in the plan stops before the due time of the occurrence after it (`prefix { $0 < takeOverTime }`), as the mockup's `simulate` stops at `until`.
- **The open occurrence's ladder** stops at the next due time.
- **The next occurrence's ladder** stops at the one after it.
- **The result:** the plan never holds two occurrences' items that overlap in time. Before take-over, every item from the next due time on belongs to the new occurrence, from nudge 1 at the strength's lowest urgency (`theOldLadderStopsWhereTheNewOccurrenceStartsAtNudgeOne`, all three strengths). At the take-over instant the plan holds nothing from the old one (`atTheTakeOverInstantThePlanHoldsOnlyTheNewOccurrenceAndTheOneAfter`).
- **The last occurrence of a COUNT or UNTIL rule** has no next due time, so its ladder isn't cut. It closes by Done or the give-up limit only (`theLastOccurrenceOfAnEndingRuleIsNeverTakenOver`).
- **With the shipped limits the cut never trims anything.** The longest ladder ends at +8 h 4 min 4 s, and the shortest gap is a 23-hour DST day.

**Tests** are in `RepeatTakeOverTests.swift`.
- **Red first:**
  - Take-over at the instant: there was no reason, no lookup and no count override.
  - The old ladder stopping at the next due time: items were interleaved.
  - A time that isn't a past due time having no occurrence: the lookup made up a Nudging occurrence.
- **Passed on their first run, kept as acceptance coverage:**
  - The tie: `<=` went in with the first slice, ahead of its test.
  - The plan at the instant: the cut already applied to the next ladder.
  - Done and give-up keeping their state.
  - Every Day and every 2 days.
  - COUNT and UNTIL.
  - Done after take-over.
- **Mutation-checked after review:**
  - Making the tie `<` fails the tie test.
  - Dropping the take-over search from `occurrence(of:dueAt:)` fails six tests (seven expectations), DST included.

**Code review (two axes, against main).**
- **Standards:** no hard violations. Fixed:
  - Data Clumps: count and span travelled together through `Ladder` and `Engine`. They are now one `GiveUpLimit` value. It replaces the old enum of statics, and the public init passes `.shipped`.
  - Duplicated work: `occurrence` built the ladder twice, once inside `giveUpTime` and once to count nudges. `giveUpTime(from:after:within:)` now takes the nudge times the caller already has.
  - Overload confusion: there were two `occurrence(of:dueAt:)` methods with different argument types. The private one is now `occurrence(of:dueAt:takenOverAt:)`.
  - Test cleanups: a suite reminder (`pills`) and one `engine(for:giveUpLimit:)` helper, a redundant `!= .giveUpLimit` assertion removed, and `throws` dropped where nothing throws.
- **Spec:** nothing missing and no scope creep. Fixed:
  - Extra due-time searches on every plan: about five per reminder, up from two. Now there are three: latest, next, and the one after next. The latest occurrence skips the take-over search, and the open ladder's cut reuses the plan's next due time.
  - No test read an older occurrence after take-over while its limit would still run: `theTakenOverOccurrenceStaysMissedWhileItsLimitWouldStillRun`.
  - No DST take-over test: `acrossADSTChangeTheReasonFollowsWhichComesFirst`.
  - No test of a widened limit that still gives up before the next due time: the 12-hour row of `aPreviousOccurrenceMissedByTheGiveUpLimitKeepsThatReason`.
- **Kept, as a judgement call:** `SchedulePlan.Item.body` still reads "Nudge N of 20" from `GiveUpLimit.shipped`, not from the engine's limit. The spec fixes that text, and only tests use another limit. Carrying the count on every plan item would add a public field for tests alone.

**Left alone:** Pause, Resume and Skipped (11), Delete (12), the lock (13), the fallbacks (14, 15), tags (16), the store (17), which must persist nothing new for take-over since it's computed, the adapters (18–20), and every UI, including My Day's list of today's occurrences (28).
