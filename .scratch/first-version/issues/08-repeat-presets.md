Status: ready-for-agent

# Repeat presets and next-due times

## What to build

Presets: Never, Every Day, Every Weekday, Every Week, Every 2 Weeks, Every Month, Every Year (no Custom). Given a due time and a preset, the engine computes the next occurrence's due time and opens a new occurrence when it comes due. Calendar and time zone are injected (default current calendar) so tests are deterministic.

## Acceptance criteria

- [ ] Never: one occurrence only; after it closes there is no next.
- [ ] Every Weekday skips Saturday and Sunday (Friday → Monday).
- [ ] Every Month from the 31st lands on the last day of shorter months and returns to the 31st when possible (state the rule in the test).
- [ ] Every Year from 29 Feb lands on 28 Feb in non-leap years.
- [ ] Every 2 Weeks and Every Week keep the weekday and time of day.
- [ ] A time-of-day across a DST change keeps the local time of day.
- [ ] The next occurrence starts at nudge 1 when its due time arrives.

Blocked by: 03
