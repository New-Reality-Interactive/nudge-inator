# Custom repeats are a subset of RRULE, and presets are rules too

A reminder's repeat is one engine value: a preset or a custom rule written in the iCalendar RRULE format (RFC 5545), restricted to `FREQ` of daily, weekly, monthly or yearly, `INTERVAL`, `BYDAY`, `BYMONTHDAY`, `BYMONTH`, and `COUNT` or `UNTIL`. The engine parses and evaluates it itself. The presets are values of the same type, so there is one next-due code path and the store holds one kind of value.

RRULE is a standard people already know from calendars, and it covers the cases presets can't (every 3 days, first Monday of the month, the last day of the month) without the app inventing its own schedule model.

## Considered Options

- **Presets only (the earlier plan).** Rejected: every uncovered schedule is a new preset.
- **Full RRULE.** Rejected: `BYSETPOS`, `EXDATE` and the rest add test surface and UI the first version doesn't need.
- **EventKit's `EKRecurrenceRule`.** Rejected: `NudgeEngine` takes no Apple framework imports, and the rule has to be testable on macOS without a simulator.
- **A third-party RRULE library.** Not chosen: keeping the engine's dependencies at Foundation, and the supported subset small enough to own.

## Consequences

- We maintain a small parser and evaluator, with tests for month ends, leap days and DST.
- Presets clamp month ends and 29 February, but a custom rule follows RFC 5545 and skips a month without that day. `BYMONTHDAY=-1` is the last day. The editor's summary and next-three-dates preview make this visible.
- Sub-daily frequencies are rejected: nudging is the sub-daily mechanism, and the give-up limit is 24 hours.
- A rule with no valid date reports "no next occurrence" after a bounded search.
- The store keeps the rule value, not a preset enum.
