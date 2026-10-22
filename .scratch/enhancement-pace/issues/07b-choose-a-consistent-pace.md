# 07b: Choose a Consistent pace in the form and details

**What to build:** A person can give a reminder a Consistent pace in the form and pick its wait from the engine's list (ticket 07). How It Nudges, the strength and pace lines and reminder details show it. New reminders still start Escalating until ticket 09. Spec stories 23–29, 33–35, 44, 46 and 47.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] Form: a Pace segmented control under Strength; Consistent reveals the Every row and Escalating hides it; the chosen wait is kept while Escalating is selected and comes back on Consistent before saving.
- [ ] Form: saving, from New or Edit, keeps the draft's pace and wait (ticket 04 found the draft drops the pace).
- [ ] How It Nudges (form and details), the strength line and the summary sentence show the reminder's pace; details show the pace, and the wait when Consistent.
- [ ] Pace is not shown on Now or My Day rows, nor in alarm or notification text.
- [ ] Every wait is written by Foundation's duration formatting; new strings are in the String Catalogs with comments.
- [ ] The line under Strength says only how the strength arrives and the give-up limit; the waits move to a line under Pace: "Every 30 min at first, down to every 5 min." (Escalating) or "Every 10 min, from when it's due." (Consistent).
- [ ] How It Nudges shows a Consistent reminder's folded rows, and its summary stays true for long waits: "Both nudges are notifications." for two nudges, and "During a Focus, every nudge waits, unless you allow Nudge-inator in that Focus." when no nudge reaches High.
- [ ] The Edit form's note for a reminder that isn't nudging reads "A new strength, pace or Break Through Focus setting applies from the next nudge.", and onboarding's first point (also on Settings' How It Nudges page) reads "Reminders keep coming back until you tap Done: at a steady pace, or more often and more insistently."
- [ ] The screenshot harness's seed (`scripts/screenshots/`) matches the proposed mockup's made-up reminders and their paces (Take the bins out Consistent · 30 min on nudge 2, and the rest as the mockup's seed), so the app's screenshots can be compared with it.
- [ ] Simulators (26.5 and 27.x): the form and details match the proposed mockup in portrait, landscape and large text, and the Pace control is a menu at accessibility sizes.
- [ ] VoiceOver reads the Pace control as a picker with its value, and the Every row with its wait.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a Consistent reminder's second nudge comes one wait after the first (phone and iOS version recorded).

## Comments

**2026-10-22, split from ticket 07, agreed with Brian.** Ticket 07 kept the engine and store. This ticket has the rest of its criteria, everything on screen, with the mockup criteria added after ticket 03 (`docs/mockups/2026-10-21-proposed-pace/README.md`, items 3, 6, 10, 17 and 18). The criterion that saving keeps the draft's pace is new here, from ticket 04's Comments. It was part of the old ticket's Before you start rather than a criterion. Ticket 07's Comments have the detail of the split.
