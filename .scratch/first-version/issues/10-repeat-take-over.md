Status: ready-for-agent

# Take-over: the next occurrence closes the open one as Missed

## What to build

If the next occurrence of a repeating reminder falls due while the previous one is still Nudging, the previous closes as **Missed** with reason "the next one took over", the new one starts at nudge 1, and the plan contains only the new occurrence's nudges. A reminder has at most one open occurrence. No carry-over.

## Acceptance criteria

- [ ] An every-day Relentless reminder left Nudging past 24 hours cannot hold two open occurrences at any moment (test at the take-over instant).
- [ ] The taken-over occurrence has state Missed and reason "the next one took over" (distinct from the give-up limit reason).
- [ ] The new occurrence's first plan item is nudge 1 at its due time, at the lowest urgency, regardless of where the old one was.
- [ ] The old occurrence's pending items are gone from the plan.
- [ ] When the previous is already Done or Missed, no take-over reason is recorded.
- [ ] Take-over uses the next due time of any repeat rule, preset or custom (test an every-2-days custom rule as well as Every Day).
- [ ] The last occurrence of a custom rule that ends (COUNT or UNTIL) has nothing to take it over: it closes by Done or the give-up limit only.

Blocked by: 06, 08, 09
