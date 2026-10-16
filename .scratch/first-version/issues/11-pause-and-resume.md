Status: resolved

# Pause and Resume

## What to build

- **Pause**: the reminder stops nudging without being lost. A Nudging occurrence closes as **Skipped** (not Missed); the plan for the reminder is empty. A paused reminder creates no occurrences.
- **Resume**: the reminder returns at its **next future** due time (for a repeat, the next preset time after now; for Never whose due time is past, the engine rejects the Resume with "needs a new due time" and the reminder stays paused; the screen sends the person to the edit form, where the due time is editable because a paused reminder is not locked). Pause, edit, Resume is the supported way to change a locked field while nudging (ticket 13, ADR 0002), so this path must be solid.

## Acceptance criteria

- [x] Pausing a Nudging reminder: occurrence state Skipped, plan empty.
- [x] While paused, time passing creates no occurrences and no plan items.
- [x] Resuming a repeating reminder schedules its next future occurrence, not a past one.
- [x] Skipped does not count as Missed in the counts used by My Day (see ticket 16).
- [x] Pausing a reminder with no open occurrence just flips paused state.
- [x] Resuming a Never reminder whose due time is past is rejected with "needs a new due time" and leaves it paused; after the due time is edited to the future, Resume succeeds.

Blocked by: 07, 08

## Comments

**Decisions settled with the user before coding (2026-10-15).**
- **Paused state is an engine record, not a field on `Reminder`.** `pause(_:)` and `resume(_:)` are events on the engine, as the spec lists them, and `isPaused(_:)` tells the screen whether to offer Pause or Resume. The record is a list of pause spans per reminder (`start`, then `end` once resumed), oldest first. A `Bool` on `Reminder` couldn't say which past due times fell in a pause, so an old occurrence couldn't read back as Skipped. **For the store (ticket 17):** it must persist the spans next to the Done record and seed them into a new engine. Until then a relaunch forgets a pause, the same gap ticket 07 noted for Done.
- **Skipped is `OccurrenceState.skipped(reason: SkippedReason)`, with one case, `.paused`.** It is the mockup's `SKIPPED` with `closeReason: "paused"` ("Skipped: the reminder was paused"). The mockup's other reason, `"edited"`, isn't modelled. ADR 0002 locks the edits that caused it, and ticket 13 or 24 can add it if a need shows. Skipped is its own state, so nothing reads it as Missed. My Day's counts (ticket 16) should keep it out of Missed. The glossary gains **Paused** and **Skipped**.
- **The resume rejection is a typed throw:** `resume(_:) throws(ResumeError)`, with `ResumeError.needsNewDueTime`, like ticket 09's parser. Resume throws whenever the reminder has no due time after now. That is a Never whose due time has passed, and also, as the user chose, a repeat whose COUNT or UNTIL ran out (`resumingARepeatThatEndedWhilePausedNeedsANewDueTime`). The reminder stays paused. A paused reminder isn't locked, so after `update(reminders:)` with a future due time, Resume succeeds (`resumingANeverReminderPastItsDueTimeNeedsANewDueTime`).
- **Ignored, not reported,** in the same spirit as ticket 07's Done:
  - Pause on a paused reminder (`pausingTwiceNeedsOnlyOneResume`).
  - Resume on one that isn't paused, or on an ID the engine doesn't hold (`resumingAReminderThatIsNotPausedChangesNothing`).
  - Done while paused. Nothing is open, so `markDone` ignores it and Skipped stays Skipped (`doneWhilePausedIsIgnored`).
- **Pause with nothing open only marks the reminder paused.** An occurrence not yet due stays absent, and a Done one stays Done (`pausingBeforeTheDueTimeOnlyFlipsPausedState`, `pausingAfterDoneKeepsTheOccurrenceDone`). The plan is empty while paused.

**How the resume point keeps past due times from coming back.** The state stays computed from the clock. `occurrence(of:dueAt:takenOverAt:)` checks Done first. Then it finds the first pause that ends at or after the due time (a pause still open never ends). That is the first pause the occurrence could still be open in. If the occurrence hadn't closed by that pause's start, by give-up or by take-over, it is Skipped. Otherwise take-over and give-up follow as before. That one rule covers four cases:
- The occurrence Nudging at Pause.
- Every due time that comes while paused.
- One that an edit while paused moved to before the Pause (see the review).
- An occurrence that closed before the Pause keeps its reason, `.giveUpLimit` or `.nextTookOver` (`anOccurrenceMissedBeforeThePauseStaysMissed`, `anOccurrenceTakenOverBeforeThePauseStaysMissed`).

After Resume, `latestDueTime(atOrBefore: now)` can still land on a due time inside the pause, but it reads as Skipped, so nothing is open. The plan starts with the next due time after now, at nudge 1 (`resumingARepeatSchedulesItsNextFutureOccurrenceNotAPastOne`). A pause's end is inclusive, so Resume at the very instant a due time comes skips it, and "next future" means after now (`resumingExactlyAtADueTimeSkipsItAndStartsAtTheNext`). `occurrence(of:dueAt:)` returns Skipped for a due time inside a pause, as the mockup's PAUSE_NOTE says ("Anything due while it's paused is skipped, not missed"). It still returns `nil` for a time that isn't a past due time.

**Tests** are in `PauseAndResumeTests.swift` (17 tests).
- **Red first:**
  - Pause closing a Nudging occurrence as Skipped with an empty plan: there was no `pause` and no `.skipped`.
  - Time passing while paused: the 17th nudged.
  - Resume of a repeat: there was no `resume` or `isPaused`.
  - The Never rejection: there was no `ResumeError`.
  - Pausing twice: the second span was never closed, so the reminder stayed silent after Resume.
  - The edit to an earlier due time: found in review.
- **Passed on their first run, kept as acceptance coverage:** Pause with nothing open, Skipped never becoming Missed (while paused and after Resume), Done while paused, the ended repeat, and Resume when not paused.
- **Mutation-checked:**
  - Dropping the rejection fails both rejection tests.
  - Dropping the pause-span check fails the time-passing and resume tests.
  - Dropping the "closed before the pause" condition fails the give-up test.
  - Leaving take-over out of it fails the take-over test.
  - Making the pause's end exclusive fails the resume-at-a-due-time test.

**Code review (two axes, against main).**
- **Spec: one bug, fixed.** A paused reminder isn't locked, so its due time can move to before the Pause (a 9:00 reminder paused at 9:40, then edited to 8:00). The first version marked Skipped only the occurrence recorded at Pause and the due times inside a pause. The 8:00 occurrence was neither, so it came back as Nudging while paused. It stayed open after Resume with its ladder in the plan, and a Done closed it. This was the Pause, edit, Resume path ADR 0002 depends on. The fix is the "first pause it could be open in" rule above. It replaces the separate recorded Skipped set, so there's one rule, not two. Tested by `anEditToAnEarlierDueTimeWhilePausedOpensNoOccurrence` (Never and Every Day) and `afterAnEditToAnEarlierDueTimeResumeStartsAtTheNextFutureDueTime`. The reviewer also asked for a test of Resume at exactly a due time, which is added.
- **Standards: no hard violations.** Fixed:
  - `ResumeError` is `Sendable`, like its peers.
  - The private type is `PauseSpan` and the record `pauseSpans`, so the type no longer shares a name with the act Pause.
  - One private `reminder(_:)` lookup replaces three `reminders.first(where:)` calls.
  - Each conditional in a test is split out: the `doneFirst: Bool` case, the `if readAt > now` resume, and the `if repeatRule != nil` branch are now separate named tests.
- **Kept, as judgement calls:**
  - The glossary has a **Paused** entry that describes Pause and Resume, rather than separate entries for the two acts.
  - A reminder dropped from `update(reminders:)` keeps its pause spans, as it keeps its Done records. Delete (ticket 12) should clear both.
  - The engine accepts Pause on a finished Never (Done or Missed), and Resume then throws `needsNewDueTime`. The mockup's `pauseRow` offers no Pause on a completed reminder, so the Reminder details screen (ticket 27) should hide it.
  - Editing a paused reminder's due time to long before the Pause, far enough back that it would have given up or been taken over first, reads as Missed, not Skipped. It is computed as having closed before the Pause. The New Reminder and edit forms shouldn't offer a past due time anyway (ticket 24).

**Left alone:** Delete (12), the lock and its rejected edits (13), the fallbacks (14, 15), tags and My Day's counts (16), the store (17), the adapters (18–20), and every UI, including the "Choose a New Time" alert and the edit form.
