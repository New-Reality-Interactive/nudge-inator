# 07: Choose a Consistent pace

**What to build:** A person can give a reminder a Consistent pace in the form and pick one wait from 2, 5, 10, 15 or 30 min, or 1, 2, 4, 8, 12 or 16 h. The reminder then nudges once at its due time and once every wait after, with its strength still deciding how each nudge arrives, until Done or the give-up limit (20 nudges or 24 h). How It Nudges and reminder details show it. New reminders still start Escalating until ticket 09. Spec stories 12–21, 23–29, 33–35, 44, 46 and 47.

**Blocked by:** 06 (it changes the same wait and urgency rules; run one at a time).

**Status:** ready-for-agent

- [ ] Engine: the 11 waits are one list the form and tests read. A Consistent reminder's first nudge is at its due time and each later one exactly one wait after.
- [ ] Engine: under Consistent each strength keeps its urgency steps (Gentle, Firm, and Relentless as alarms).
- [ ] Engine: a 2 min wait gives up after 40 min; a 16 h wait nudges twice and gives up at 24 h; a last nudge leaves one full wait before Missed unless the 24 h run out first.
- [ ] Engine: Stop, Done, a repeat's take-over and Pause and Resume behave for a Consistent reminder as for an Escalating one.
- [ ] Store: a Consistent reminder's pace and wait survive a save and reload.
- [ ] Form: a Pace segmented control under Strength; Consistent reveals the Every row and Escalating hides it; the chosen wait is kept while Escalating is selected and comes back on Consistent before saving.
- [ ] How It Nudges (form and details), the strength line and the summary sentence show the reminder's pace; details show the pace, and the wait when Consistent.
- [ ] Pace is not shown on Now or My Day rows, nor in alarm or notification text.
- [ ] Every wait is written by Foundation's duration formatting; new strings are in the String Catalogs with comments.
- [ ] The line under Strength says only how the strength arrives and the give-up limit; the waits move to a line under Pace: "Every 30 min at first, down to every 5 min." (Escalating) or "Every 10 min, from when it's due." (Consistent).
- [ ] How It Nudges folds a Consistent reminder's equal waits into one row per urgency, and its summary stays true for long waits: "Both nudges are notifications." for two nudges, and "During a Focus, every nudge waits, unless you allow Nudge-inator in that Focus." when no nudge reaches High.
- [ ] The Edit form's note for a reminder that isn't nudging reads "A new strength, pace or Break Through Focus setting applies from the next nudge.", and onboarding's first point (also on Settings' How It Nudges page) reads "Reminders keep coming back until you tap Done: at a steady pace, or more often and more insistently."
- [ ] The screenshot harness's seed (`scripts/screenshots/`) matches the proposed mockup's made-up reminders and their paces (Take the bins out Consistent · 30 min on nudge 2, and the rest as the mockup's seed), so the app's screenshots can be compared with it.
- [ ] Simulators (26.5 and 27.x): the form and details match the proposed mockup in portrait, landscape and large text, and the Pace control is a menu at accessibility sizes.
- [ ] VoiceOver reads the Pace control as a picker with its value, and the Every row with its wait.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a Consistent reminder's second nudge comes one wait after the first (phone and iOS version recorded).

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the split strength and pace lines, folded rows and long-wait wording, the edit note, onboarding's first point, and the harness seed. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 3, 6, 10, 17 and 18.
