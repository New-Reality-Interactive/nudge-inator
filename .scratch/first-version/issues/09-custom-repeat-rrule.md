Status: resolved

# Custom repeat from an RRULE subset

## What to build

Add **Custom** to the repeat options: a recurrence rule in the iCalendar RRULE format (RFC 5545), limited to a subset. The engine parses a rule, validates it, and computes the next due time. It is pure Swift with Foundation only, so the parser is hand-written (no Apple framework, no third-party library). Presets (ticket 08) are values of the same rule type, so there is one next-due code path. Decision and trade-offs: ADR 0003.

**Supported subset (confirm in review):**

- `FREQ` of `DAILY`, `WEEKLY`, `MONTHLY` or `YEARLY`.
- `INTERVAL`.
- `BYDAY`, with an optional ordinal for monthly and yearly rules (`1MO`, `-1FR`).
- `BYMONTHDAY`, including negative values (`-1` is the last day of the month).
- `BYMONTH`.
- `COUNT` or `UNTIL`, not both (RFC 5545).

**Rejected with a typed reason:** `HOURLY`, `MINUTELY` and `SECONDLY` (nudging is the sub-daily mechanism, and the give-up limit is 24 hours), `BYSETPOS`, `BYWEEKNO`, `BYYEARDAY`, `BYHOUR`, `BYMINUTE`, `BYSECOND`, `WKST` other than the default, `EXDATE`, `RDATE`, and any malformed or contradictory rule. The reminder's due time plays the part of `DTSTART`, so the rule carries none.

**Differences from the presets, on purpose:** a custom rule follows RFC 5545, so `FREQ=MONTHLY;BYMONTHDAY=31` skips months without a 31st and a 29 February rule skips non-leap years. The presets clamp instead (ticket 08). Use `BYMONTHDAY=-1` for "last day of the month".

Calendar and time zone are injected, as in ticket 08. A rule that never produces a date (for example 30 February) must stop after a bounded search and report "no next occurrence" rather than loop. Name the search horizon as a constant.

The engine also exposes a plain-language summary of any repeat, preset or custom, with the time of day and how it ends: "Every 2 weeks on Monday and Wednesday at 9:00 AM, 5 times", "Every month on the last day at 9:00 AM", "Every 3 days at 6:00 PM, until Sat 10 Oct". A day some months lack says what happens: "(skipped in months without one)" for a custom rule, "(the last day in months without one)" for the Every Month preset. The form, the Repeat page, the Custom page (ticket 25) and the details screen (ticket 27) all show this one string, as the mockup does.

## Acceptance criteria

- [x] Valid rules in the supported subset parse and read back as an equal rule value.
- [x] Every unsupported or malformed rule above is rejected with a distinct reason (table-driven test).
- [x] Every 3 days, every 2 weeks on Monday and Wednesday, the first Monday of each month (`BYDAY=1MO`), the last Friday (`BYDAY=-1FR`) and the last day of the month (`BYMONTHDAY=-1`) each produce the expected next three due times.
- [x] `FREQ=MONTHLY;BYMONTHDAY=31` skips short months (state in the test that this differs from the Every Month preset).
- [x] `COUNT=3` yields exactly three occurrences and then no next. `UNTIL` is inclusive of its date. After the last one there is no next, as with Never.
- [x] Each preset expressed as a rule gives the same next due times as ticket 08's tests.
- [x] A time of day across a DST change keeps its local time of day.
- [x] A rule with no valid date (30 February) returns "no next occurrence" within the search horizon.
- [x] The summary text for a representative set of rules matches the mockup's wording, including the time, the ending and the month-end note, and has no raw RRULE syntax.
- [x] No Apple framework types in `NudgeEngine` (`scripts/test.sh` enforces it).

Blocked by: 08

## Comments

**Decisions settled with the user before coding (2026-10-15).**
- **Calendar: Gregorian, fixed, as ticket 08 left it.** Only the time zone is injected. This departs from "Calendar and time zone are injected (default current calendar)" on purpose: RRULE is Gregorian.
- **Standards first.** The user chose RFC 5545 behaviour wherever the mockup and the RFC differ:
  - **The first due time always counts as an occurrence**, for presets as well as custom rules, and COUNT includes it. RFC 5545 §3.3.10 says "The DTSTART property value always counts as the first occurrence". This reverses ticket 08's untested mockup behaviour: Every Weekday from a Saturday now nudges that Saturday, then on Monday (`theFirstDueTimeIsAnOccurrenceEvenOffTheRule`). When the due time is on a day the rule allows, which is all the editors build, nothing changes.
  - **The parser accepts every RFC 5545 combination of the supported parts**, not just what the Custom page builds. BYDAY, BYMONTHDAY and BYMONTH are lists. BYDAY limits a monthly rule that has BYMONTHDAY (Friday the 13th). BYMONTH limits daily, weekly and monthly rules. A yearly ordinal without BYMONTH counts within the year (`1MO` is the year's first Monday). A yearly `BYMONTHDAY` without BYMONTH falls in every month.
- **UNTIL comes in two forms, each written back as it came.** A DATE (`UNTIL=20261010`) is inclusive of the whole day in the engine's time zone, as the mockup writes it. A UTC DATE-TIME (`…T035959Z`) is inclusive of that instant, the form RFC 5545 requires next to a DTSTART with a time zone. A floating local DATE-TIME is rejected.
- **The summary takes an injected `Locale`**, not a fixed format. The sentence is English. Times and dates go through `Date.FormatStyle` in that locale:
  - en_GB gives "18:00" and "Sat 10 Oct".
  - en_US gives "6:00 PM" and "Sat, Oct 10". Foundation puts a U+202F narrow no-break space before AM/PM; the tests spell it out.
  - The ticket's "6:00 PM … Sat 10 Oct" mixes the two, so no single locale gives it. The tests check both halves.
- **Test seams:** `RepeatRule(rrule:)` and `rule.rrule`, a new `Engine.upcomingDueTimes(of:count:)` (the mockup's `upcoming`, which ticket 25's next-three-dates preview needs), and `Engine.repeatSummary(of:)`.

**How the rule is modelled** (`RepeatRule.swift`). The fields carry over from ticket 08, widened:
- **`weekdays`** is `Set<WeekdayNumber>?`. A `WeekdayNumber` is a `Weekday` plus an optional ordinal (`1MO`, `-1FR`). It is `Comparable`, sorting Monday first and then by ordinal.
- **`monthDays: Set<Int>?`** (BYMONTHDAY, ±1–31). A negative day counts back from the month's last day and never clamps: under `.skip`, `-31` skips 30-day months.
- **`months: Set<Int>?`** (BYMONTH).
- **`end: End?`**, one of `.count(Int)`, `.untilDate(year:month:day:)` or `.untilTime(Date)`. COUNT and UNTIL can't both be set, by construction.
- `missingDay` is unchanged. Presets clamp and custom rules skip. A parsed rule is always `.skip`.

Defaults come from the first due time only when the rule has no BYDAY and no BYMONTHDAY, as RFC 5545 (and python-dateutil) do. The walk applies every part as a filter on the day, so RFC 5545's "expand" and "limit" both come to "the day matches".

**The parser** (`RepeatRuleText.swift`).
- **Interface:** `RepeatRule(rrule:) throws(RepeatRule.ParseError)`, with typed throws. Names and codes are case-insensitive, as RFC 5545 says. `WKST=MO` is accepted and does nothing.
- **Reasons, one per rejected case:**
  - `malformed`: a part that isn't NAME=VALUE, including an empty part from `;;` or a trailing `;`.
  - `missingFrequency`.
  - `duplicatePart`.
  - `unknownPart`: for example the mockup's BYTIME.
  - `notARulePart`: DTSTART, EXDATE, RDATE.
  - `unsupportedPart`: BYSETPOS, BYWEEKNO, BYYEARDAY, BYHOUR, BYMINUTE, BYSECOND.
  - `subDailyFrequency`: HOURLY, MINUTELY, SECONDLY.
  - `invalidValue(part:value:)`: out-of-range, non-numeric or empty values, an impossible UNTIL date such as 30 February.
  - `unsupportedWeekStart`.
  - `floatingUntil`.
  - `countWithUntil`.
  - `ordinalNotAllowed(frequency)`: an ordinal in a daily or weekly rule, which RFC 5545 forbids.
  - `monthDayInWeeklyRule`: also forbidden by RFC 5545.
- **Tests:** `aRuleOutsideTheSubsetIsRejectedWithItsReason` is the table, and `everyRejectedRuleHasADistinctReason` checks that no two rows share a reason.
- **Serializer:** `rule.rrule` writes canonical text in the mockup's order. The round-trip test checks text → rule → text, and that the text reads back as an equal rule. `missingDay` isn't part of RRULE, so the store (ticket 17) must keep it next to the text, as the mockup keeps `repeatCustom`.

**One next-due path, still.**
- **The walk:** presets and custom rules share `DayWalk`. The walk jumps straight past periods the interval rules out and months the rule can't fall in. Every 10 years, 30 times, is a few thousand steps, not 110,000 days.
- **The search horizon** is the named constant `searchSteps` (366 × 11). It counts steps examined, and starts again after each due time found. So a rule with no date (30 February) stops after a bounded search (`aRuleWithNoValidDateHasNoNextOccurrence`), while rare rules decades apart are still found (`aRareRuleFindsANextDateDecadesAway`).
- **COUNT** is the first n due times of one forward walk, read only as far as the date asked about.
- **UNTIL** clips both the forward and the backward search.
- **After the last occurrence** there is no next, and the last stays the latest, as with Never. Ticket 10 needs nothing more to know an occurrence is the last: `nextDueTime` is `nil`.

**The summary** (`RepeatSummary.swift`, `Engine.repeatSummary(of:)`).
- **Wording** follows the mockup's `scheduleText`. Never reads "Once, Today at 9:00" (Today, Tomorrow, Yesterday, or the short date), relative to the engine's clock.
- **Month-end notes:**
  - A custom rule gets "(skipped in months/years without one)".
  - Every Month gets "(the last day in months without one)", and Every Year from 29 February gets "(28 February in years without one)".
  - The note appears only when a month the rule falls in can lack the day: positive or negative days past the shortest month's length, and ordinals of 5 or more.
- **Combinations beyond the Custom page** read as "Every month on the 13th when it's a Friday", "Every Thursday in June, July and August", and "Every year on the first Monday of the year".
- **Device check (ticket 21):** whether `Locale.autoupdatingCurrent` reflects the iPhone's 24-Hour Time switch. Apple's `Date.FormatStyle` docs confirm only that the locale sets the hour style. A `@hours=h23` locale does give "09:00" on the Mac.

**TDD notes.**
- **Red first:** the parser slices, rejection reasons, the serializer, `upcomingDueTimes`, the first due time off the rule, COUNT, the backward jump that skipped an off-rule first due day (found while writing the jumps), the summary slices, and each review fix.
- **Passed on their first run, kept as acceptance coverage:** the next-three table, the month-end skips, UNTIL, preset equivalence, DST, 30 February, and the lowercase/WKST case. The RFC filter semantics went into `isDue` with the field rename, ahead of their tests.
- **Performance fixed mid-ticket:** the first day-by-day COUNT walk took 14 s for every 10 years, 30 times. Period jumps took it to 0.18 s.

**Code review (two axes, against main).** Fixed, each with a test:
- COUNT re-walked every occurrence on each call. `FREQ=DAILY;COUNT=10000` took 11.9 s for three dates, and a huge COUNT hung. Fixed so the COUNT is walked only up to the date asked about (`aHugeCountStillAnswersPromptly`, COUNT=100000000).
- The 366 × 11-day horizon cut off valid rare rules: yearly INTERVAL=3 from 29 February 2028 (next 2040), INTERVAL=20, and 29 February on a Monday (2016 → 2044). The horizon now counts steps, and jumps go straight to the next period the interval allows.
- The monthly note ignored BYMONTH. `BYMONTH=1,3;BYMONTHDAY=31` claimed months were skipped.
- `BYDAY=6MO` in a monthly rule (it parses, since RFC allows ordinals up to 53, but it never matches) had no note. It now gets "(skipped in months without one)".
- Standards cleanups:
  - RRULE codes are exhaustive properties on `Frequency` and `Weekday`, replacing dictionaries that fell back to `""`.
  - `WeekdayNumber` is `Comparable`, so there is one Monday-first sort.
  - There is one `(weekday + 5) % 7`.
  - The internal init is `init(_:checkedInterval:…)`, renamed from `init(validFrequency:)`, whose label was misleading.
  - The parser's helpers are private.
  - Shared `NewYork` test dates (`NewYork.swift`), with a summary helper in the tests.
  - Two summary test names now describe their cases, and the syntax check is a single expectation, not a loop.

Kept, as judgement calls:
- A trailing `;` is rejected as `malformed`. RFC 5545's grammar doesn't allow it, and the app's own text never has one.
- `untilDate(year:month:day:)` and `Set<Int>` months mirror RRULE's parts. No small date type was added.
- `RepeatPresetTests.swift` keeps its own `local(...)` helper, unchanged from ticket 08.

**Left alone:** take-over and its Missed reason (10), Pause/Resume/Skipped (11), Delete (12), the lock (13), the fallbacks (14, 15), the store (17), the adapters (18–20), and every UI, including the Custom editor (25). Sub-daily repeats and BYHOUR/BYMINUTE/BYTIME stay rejected.
