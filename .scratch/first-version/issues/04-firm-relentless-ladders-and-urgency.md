Status: ready-for-agent

# Firm and Relentless ladders, urgency, Urgent from nudge 4

## What to build

Add Firm (start 30 min, factor 0.5, floor 5) and Relentless (start 10 min, factor 0.5, floor 2). Each nudge gets an urgency (Normal, High, Urgent) that rises along the ladder. Firm and Relentless reach Urgent from nudge 4; Gentle never reaches Urgent. Numbers are in the spec and the mockup (`docs/mockups/2026-10-04-first-version/index.html`) and should be single constants so they can be tuned.

## Acceptance criteria

- [ ] Firm intervals run 30, 15, 7.5 (rule from ticket 03), then 5 floor; Relentless 10, 5, 2.5, then 2 floor.
- [ ] Firm and Relentless nudge 1–3 are Normal/High as in the mockup, nudge 4 onward Urgent.
- [ ] Gentle never produces an Urgent nudge at any nudge number.
- [ ] Urgency appears in each plan item and in its text ("Nudge 3 of 20 · High").
- [ ] Urgency values match the mockup's How It Nudges table for all three strengths (compare to `index.html`).

Blocked by: 03
