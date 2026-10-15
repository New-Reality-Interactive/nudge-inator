Status: resolved

# Firm and Relentless ladders, urgency, Urgent from nudge 4

## What to build

Add Firm (start 30 min, factor 0.5, floor 5) and Relentless (start 10 min, factor 0.5, floor 2). Each nudge gets an urgency (Normal, High, Urgent) that rises along the ladder. Firm and Relentless reach Urgent from nudge 4; Gentle never reaches Urgent. Numbers are in the spec and the mockup (`docs/mockups/2026-10-04-first-version/index.html`) and should be single constants so they can be tuned.

## Acceptance criteria

- [x] Firm intervals run 30, 15, 7.5 (rule from ticket 03), then 5 floor; Relentless 10, 5, 2.5, then 2 floor.
- [x] Firm and Relentless nudge 1–3 are Normal/High as in the mockup, nudge 4 onward Urgent.
- [x] Gentle never produces an Urgent nudge at any nudge number.
- [x] Urgency appears in each plan item and in its text ("Nudge 3 of 20 · High").
- [x] Urgency values match the mockup's How It Nudges table for all three strengths (compare to `index.html`).

Blocked by: 03

## Comments

**Urgency ladders, from the mockup's How It Nudges table** (worked out by running the mockup's own `simulate`, `intervalAt` and `priorityAt`; the table's rows come from the same data). Gentle: nudges 1–4 Normal, 5–20 High. Firm: 1–2 Normal, 3 High, 4–20 Urgent. Relentless: 1–3 High (it never sends a Normal nudge), 4–20 Urgent. The tests write these out per nudge as literals.

**Waits.** Firm waits 1800 s, 900 s, 450 s, then 300 s. Relentless waits 600 s, 300 s, 150 s, then 120 s. Each lands on a whole second, so ticket 03's rounding rule (nearest whole second) changes nothing for them. Firm's nudge 20 is at +2 h 12 min 30 s and Relentless's at +49 min 30 s.

**The engine uses an explicit rule for each strength, not the mockup's formula.** `priorityAt` interpolates a min–max priority over `maxLevel`, the nudge where the waits reach the floor. That ties urgency to the interval numbers: tuning Firm's floor or factor would move "Urgent from nudge 4", and tuning Gentle's `max` would let it ring. The spec states those as rules of their own. So each ladder names its first High nudge and its first Urgent nudge (`nil` for Gentle, so "never Urgent" is part of the constant). The values match the formula's output for today's numbers.

**Tunable constants** are in `Packages/NudgeEngine/Sources/NudgeEngine/Ladder.swift`: one `Ladder` value per strength (`Ladder.gentle`, `.firm`, `.relentless`) with `initialWait`, `factor`, `floor`, `highFrom` and `urgentFrom`. `Strength.ladder` picks one. Gentle's tuple and its hard-coded urgency moved into `Ladder.gentle` without changing any Gentle test.

**Urgent is delivered as `DeliveryKind.alarm`**, the spec's Break-through-Focus-on mapping. Ticket 05 adds the switch and the denied-alarm and alarm-limit fallbacks. `gentleNeverReachesUrgent` checks nudges 1–20: none is Urgent and none is an alarm.
