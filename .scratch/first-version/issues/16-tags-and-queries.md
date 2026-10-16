Status: resolved

# Tags, My Day counts and filters, Now sections, Tags-tab counts

## What to build

Pure queries and rules in the engine package:

- **Tag rules**: one word, shown as `#home`; names unique ignoring case (`Home` and `#home` are the same tag); create, rename (conflict → rejected), delete (reports how many reminders use it; reminders are kept and lose the tag).
- **My Day**: today's occurrences in time order; counts Done, Nudging, Missed, Left (Skipped not counted as Missed); filter by one count; filter by tags with Match All / Match Any; No Tags.
- **Now**: nudging occurrences, Coming Up (next 7 days), Last 24 Hours.
- **Tags tab**: for each tag, counts of reminders, due today and nudging; a tag's reminder list.

## Acceptance criteria

- [x] `Home`, `#home` and `HOME` resolve to one tag.
- [x] Deleting a tag reports the number of reminders using it and keeps all of them.
- [x] My Day counts match a fixed fixture (Done 2, Nudging 1, Missed 1, Left 3 or similar), and Skipped is in none of Done/Missed.
- [x] Match All returns only reminders with every selected tag; Match Any returns those with at least one; No Tags returns untagged ones.
- [x] Coming Up includes day 7 and excludes day 8; Last 24 Hours includes closed occurrences from the past 24 h only.
- [x] Tags-tab counts for reminders, due today, nudging are right for a multi-tag reminder (counted under each of its tags).

Blocked by: 07

## Comments

**Decisions settled with the user before coding (2026-10-16).**
- **Tags are values with IDs.** `Tag` has `id: UUID` and `name` (without the `#`). `Reminder.tags: [String]` is now `Reminder.tagIDs: [Tag.ID]`, as in the mockup's `tagIds`, so a rename reaches every reminder at once. The tag list lives on `Engine` beside `reminders`: `engine.tags`, loaded by `update(tags:)`. Like `update(reminders:)`, `update(tags:)` reports what's already true, so it isn't validated. **For the store (ticket 17):** persist each `Tag` (id, name) and each reminder's `tagIDs`.
- **Name rules follow the mockup's `cleanTag`.**
  - Trim whitespace, drop one leading `#`, turn each run of whitespace into one `-`, and trim hyphens at either end. Everything else is allowed: letters, digits, emoji, punctuation.
  - A name that ends up empty throws `TagNameError.empty`.
  - Names are the same tag if they match under `folding(options: .caseInsensitive, locale: nil)`. That is locale-independent, so the tests don't depend on the Mac.
  - The first casing wins. `#home` after `Home` throws `.taken(by: Home)`, so the form can reuse that tag (the mockup's `addDraftTag`) and the Tags tab can show its message.
  - `renameTag(_:to:)` can change a tag's own casing. Renaming a tag the engine doesn't hold is ignored, like the other events.
- **`deleteTag(_:) -> Int`** returns how many reminders used the tag. It removes the tag and drops its ID from the engine's reminders, which all stay. No plan is applied, since tags never reach a plan. The store makes the same change to what it saved (17's criterion). Ticket 12's leftover is covered too: deleting a reminder keeps its tags.
- **My Day.**
  - "Today" is the local day in the engine's calendar that holds now (`startOfDay` to the next one), so a 25-hour fall-back day is whole.
  - Each item is a reminder ID, a due time and a `MyDay.Status`:
    - `.due(OccurrenceState)` once due: Done, Nudging, Missed or Skipped.
    - `.left` when due later today.
    - `.paused` when due later today but the reminder is paused, as the mockup's `PAUSED` status shows.
  - The counts (`MyDayCount`: done, nudging, missed, left) leave Skipped and Paused out, so a pause isn't counted against the person. There are no quiet hours, so the mockup's "due but not yet nudged" can't happen: nudge 1 fires at the due time.
  - Order is by due time, then title (as in `todayItems`), then ID.
  - `myDay(tagFilter:)` takes `TagFilter`: `.off`, `.matchAll(Set)`, `.matchAny(Set)` or `.noTags`. An empty set filters nothing, as `inDayFilter` does. The counts cover the tag-filtered items, as in `viewDay`. `items(countedIn:)` filters the list to one count.
- **Close times.**
  - `History.closedOccurrences` now holds a `Closing`: the state, `closedAt` and `nudgesSent`.
  - Done records `clock.now` and the nudge it was on.
  - Missed by give-up closes at the give-up time, after all its nudges.
  - Missed by take-over closes at the next due time, after the nudges before it.
  - Skipped closes at the later of its due time and the pause's start. One that fell due while paused sent nothing, as the mockup's `o13` shows.
  - `Occurrence` is unchanged. **For the store (17):** persist `closedAt` and `nudgesSent` next to each Done record.
- **Now.**
  - `nudgingOccurrences()` lists the open occurrences, oldest due time first (`openOccs`).
  - `comingUp()` lists each unpaused reminder's next due time after now, up to and including the same local time 7 days later (`calendar.date(byAdding: .day, value: 7)`). This differs from the mockup's 7 × 24 h, which drops day 7's 9:00 across the 1 November fall-back.
  - `closedInLast24Hours()` lists occurrences with `now − 24 h ≤ closedAt ≤ now`, newest first. Those are real hours, so DST neither stretches nor shrinks the window. It looks back to due times one give-up span before the window, because nothing closes later than that after its due time.
- **Tags tab.**
  - `tagSummaries()` sorts by folded name, then ID, and gives each tag `reminderCount`, `dueTodayCount` (My Day items with the tag, any status) and `nudgingCount`.
  - **`nudgingCount` differs from the mockup.** It counts reminders with an open occurrence now, as the Now tab does. The mockup's `tagStats` counts only today's, which would miss a reminder due at 23:00 yesterday that is still nudging.
  - `taggedReminders(_:)` gives a tag's reminders in the store's order. Sections are the screen's job. It isn't `reminders(taggedWith:)` because the public `reminders` property hides a method with that base name at the call site. `reminders` is now `public private(set)`, the first public way to read reminders back.

**Tests**: `TagRulesTests` (10), `MyDayTests` (11), `NowQueriesTests` (11), `TagSummaryTests` (1). All use the fake clock, the fake scheduler and `NewYork`. `EngineTag.swift` aliases `Tag` to the engine's, since Swift Testing has its own `Tag`. Two existing tests (Gentle ladder privacy, lock-while-nudging tags edit) now use `tagIDs`.
- **Red first:**
  - same-name rejection, one-word names, empty names, rename;
  - delete tag;
  - My Day's list, counts, count filter and tag filters;
  - nudging, Coming Up, paused out of Coming Up;
  - Last 24 Hours, Tags-tab counts;
  - the review fixes below.
- **Passed on their first run, kept as acceptance coverage:**
  - deleting a reminder keeps its tags;
  - tag-filtered counts, an empty filter, the My Day and Coming Up DST tests;
  - the take-over, Skipped and Edit-fixed close times, which came in with the Last 24 Hours slice.
- **Mutation-checked:**
  - a fixed 24-hour day fails the My Day DST test, and 7 × 24 h fails the Coming Up one;
  - dropping the empty-set rule fails the empty filter;
  - each close-time rule fails its test, as do the give-up-span look-back and an exclusive window start;
  - recording only the latest closing at an Edit, and ignoring recorded closings in `latestOccurrence`, each fail.

**Code review (two axes, against main).**
- **Spec: three bugs and one gap, all fixed.**
  - An Edit that moved the schedule lost what had closed, and could make up closings. A daily 9:00 Done at 9:05, then moved to 18:00, dropped out of My Day's Done count and the Last 24 Hours, and yesterday's 18:00 appeared there as Missed. A strength change recomputed earlier close times. Now:
    - an Edit to the due time, repeat or strength fixes every closing Last 24 Hours could list, not just the latest;
    - it records the latest due time as `editAppliesAfter`. The edited fields' due times up to it never happened, so `occurrence(of:dueAt:)`, `latestOccurrence` and the queries ignore them;
    - fixed closings count even when their due time is no longer one of the reminder's, so My Day can show the 9:00 Done and the 18:00 Left on one day;
    - ticket 13's decision stands: a due time moved to after the latest occurrence, even an already past one, is the next occurrence and opens.

    Tested by `anEditThatMovesTheDueTimeKeepsWhatClosedAndMakesNothingUp`, `anEditThatChangesTheStrengthKeepsEarlierCloseTimes` and `anEditThatMovesTheDueTimeKeepsTodaysDoneOccurrence`.
  - A deleted tag's ID left on a reminder by the store counted as a tag, so No Tags missed it. The filters now see only tags the engine holds (`aDeletedTagsIDLeftOnAReminderCountsAsNoTag`).
  - Coming Up broke ties by ID, My Day by title. All three Now and My Day lists now share one time order: due time, title, ID (`comingUpBreaksTiesByTitle`).
  - Last 24 Hours couldn't say "Done after N nudges" (the mockup's `closedLabel`). `ClosedOccurrence` now carries `nudgesSent`, and `closedOccurrence(of:dueAt:)` lets a My Day Done row read "Done at 7:04 after 1 nudge".
- **Standards: no hard violations.** Fixed:
  - `UpcomingDueTime` is now `ComingUpItem`.
  - The `TagSummary` counts are `reminderCount`, `dueTodayCount` and `nudgingCount`.
  - `MyDay.Item.count` is `countedIn` and `items(in:)` is `items(countedIn:)`.
  - `Tag.sortKey` is `foldedName`.
  - Two what-comments are gone.
  - The typealias has its own file.
  - The four copies of the tie-break sort became one `inTimeOrder`.
  - The `nextDown` idiom became `Date.justBefore`, including its two older uses.
  - The `(Item, String)` sort tuple is gone.
  - The Edit's `case let` binding is gone.
  - The total-count check moved out of the parameterized test.
- **Kept, as judgement calls:**
  - `taggedReminders(_:)` keeps its name (see above).
  - The internal `(occurrence:, closing:)` tuple stays labelled rather than becoming a type.
  - The tag list sorts by its own key, not `inTimeOrder`.

**For later tickets.**
- **26:** read the three `Engine` queries.
- **28:** call `myDay(tagFilter:)`, then `count(of:)` and `items(countedIn:)`; a Done row's time and nudges come from `closedOccurrence(of:dueAt:)`.
- **29:** use `tagSummaries()`, `taggedReminders(_:)`, `createTag`, `renameTag` and `deleteTag`. The delete confirmation's count is the summary's `reminderCount`.
- **17:** besides tags and close times, persist `editAppliesAfter` with the other per-reminder records. It's in memory only, like Done (07) and the pause spans (11).

**Left alone:** the store (17), the adapters (18–20), and every UI: Now (26), My Day (28), Tags (29), the form's tag field (24) and the delete-tag confirmation copy.
