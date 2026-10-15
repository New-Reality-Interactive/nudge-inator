Status: ready-for-agent

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

- [ ] Valid rules in the supported subset parse and read back as an equal rule value.
- [ ] Every unsupported or malformed rule above is rejected with a distinct reason (table-driven test).
- [ ] Every 3 days, every 2 weeks on Monday and Wednesday, the first Monday of each month (`BYDAY=1MO`), the last Friday (`BYDAY=-1FR`) and the last day of the month (`BYMONTHDAY=-1`) each produce the expected next three due times.
- [ ] `FREQ=MONTHLY;BYMONTHDAY=31` skips short months (state in the test that this differs from the Every Month preset).
- [ ] `COUNT=3` yields exactly three occurrences and then no next. `UNTIL` is inclusive of its date. After the last one there is no next, as with Never.
- [ ] Each preset expressed as a rule gives the same next due times as ticket 08's tests.
- [ ] A time of day across a DST change keeps its local time of day.
- [ ] A rule with no valid date (30 February) returns "no next occurrence" within the search horizon.
- [ ] The summary text for a representative set of rules matches the mockup's wording, including the time, the ending and the month-end note, and has no raw RRULE syntax.
- [ ] No Apple framework types in `NudgeEngine` (`scripts/test.sh` enforces it).

Blocked by: 08
