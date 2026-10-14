Status: ready-for-agent

# Repeat presets and next-due times

## What to build

Presets: Never, Every Day, Every Weekday, Every Week, Every 2 Weeks, Every Month, Every Year. Custom rules are ticket 09. Each preset is a value of the engine's repeat-rule type (the type ticket 09 parses a custom rule into), so presets and Custom share one next-due computation and the store holds one kind of value. The month-end and leap-day clamping below belongs to the presets only (ADR 0003). Given a due time and a repeat rule, the engine computes the next occurrence's due time and opens a new occurrence when it comes due. Calendar and time zone are injected (default current calendar) so tests are deterministic.

## Acceptance criteria

- [ ] Never: one occurrence only; after it closes there is no next.
- [ ] Every Weekday skips Saturday and Sunday (Friday → Monday).
- [ ] Every Month from the 31st lands on the last day of shorter months and returns to the 31st when possible (state the rule in the test).
- [ ] Every Year from 29 Feb lands on 28 Feb in non-leap years.
- [ ] Every 2 Weeks and Every Week keep the weekday and time of day.
- [ ] A time-of-day across a DST change keeps the local time of day.
- [ ] The next occurrence starts at nudge 1 when its due time arrives.
- [ ] Each preset is a repeat-rule value, and there is one next-due code path that ticket 09's custom rules reuse.

Blocked by: 03
