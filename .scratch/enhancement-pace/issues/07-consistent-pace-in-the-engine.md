# 07: Consistent pace in the engine and store

**What to build:** A reminder can have a Consistent pace with one wait from 2, 5, 10, 15 or 30 min, or 1, 2, 4, 8, 12 or 16 h. The engine then nudges it once at its due time and once every wait after, with its strength still deciding how each nudge arrives, until Done or the give-up limit (20 nudges or 24 h). The store keeps its pace and wait. Nothing on screen changes: choosing the pace is ticket 07b. Spec stories 12–21, and 26 for the list of waits.

**Blocked by:** 06 (it changes the same wait and urgency rules; run one at a time).

**Status:** ready-for-agent

- [x] Engine: the 11 waits are one list the form and tests read. A Consistent reminder's first nudge is at its due time and each later one exactly one wait after.
- [x] Engine: under Consistent each strength keeps its urgency steps (Gentle, Firm, and Relentless as alarms).
- [x] Engine: a 2 min wait gives up after 40 min; a 16 h wait nudges twice and gives up at 24 h; a last nudge leaves one full wait before Missed unless the 24 h run out first.
- [x] Engine: Stop, Done, a repeat's take-over and Pause and Resume behave for a Consistent reminder as for an Escalating one.
- [x] Store: a Consistent reminder's pace and wait survive a save and reload.
- [x] Engine: How It Nudges folds a Consistent reminder's equal waits into one row per urgency, so Relentless at Consistent is one row, "Nudges 1–20 when due", Urgent, Alarm (proposed mockup items 10 and 11).

## Before you start

- Builds on: ticket 04 put `Pace` on `Reminder` with only `.escalating` (`Pace.swift`: `interval(afterNudge:strength:)`, `nudgeTimes(from:strength:within:)`, `giveUpTime`), and the store's `paceKind`/`paceWait` columns with `Pace.storedValue` and `init(storedKind:wait:)` (`ReminderStore.swift`), so Consistent adds a case and a stored wait, not a new column. Ticket 05 made every Relentless nudge Urgent (`urgentFrom: 1`). Its Comments: How It Nudges shows Relentless as four rows only because its Escalating waits differ, and the mockup's one row "Nudges 1–20 when due" (item 11) is Relentless at Consistent. `HowItNudgesTests` says so in a doc comment that this ticket can now make true. Ticket 06 made Break Through Focus act through `Reminder.breaksThroughFocus` / `Strength.breaksThroughFocus(switchedOn:)`. Leave those as they are: pace doesn't touch them.
- Watch for: `howItNudges(_:pace:breakThroughFocus:)` already takes a pace and folds rows that share an urgency, wait and delivery, so the folding criterion may need only a test. The stored reminder changes with no migration (ADR 0004: beta testers delete all data and reinstall). Prior art for the engine tests, through the scheduler's last plan with hand-worked expected values: `EscalatingPaceTests`, `GiveUpLimitTests`, `StopAndDoneTests`, `RepeatTakeOverTests`, `PauseAndResumeTests`, `AlarmLimitFallbackTests`. Nothing here shows on screen, so there's no simulator or device check; leave the form, details and strings to 07b.
- Developer stops: agree the `tdd` seams (engine through the plan for Consistent waits, give-up and urgency per strength, and Stop, Done, take-over and Pause; How It Nudges' rows; store round-trip).

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the split strength and pace lines, folded rows and long-wait wording, the edit note, onboarding's first point, and the harness seed. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 3, 6, 10, 17 and 18.

**2026-10-22, split into 07 and 07b, agreed with Brian.** Ticket 07, "Choose a Consistent pace", had 16 criteria across the engine, store, form and details, with a simulator walk and device checks. This ticket keeps the engine and store: criteria 1–5, and the engine half of the folding criterion. Everything on screen moved to 07b, "Choose a Consistent pace in the form and details", with its simulator, VoiceOver and iPhone checks. The mockup criteria above went with it except the folding. Earlier tickets' Comments that say "until ticket 07" about the strength line, the edit note or the form (04 and 05) now mean 07b.

**2026-10-22, built.** `Pace.consistent(wait:)` and `Pace.consistentWaits` (the 11 waits, in seconds) in `Pace.swift`. `interval(afterNudge:strength:)` returns the wait, so nudge times, give-up time, urgency steps, Stop, Done, take-over, Pause and Resume and How It Nudges' folding needed no other engine change; tests are `ConsistentPaceTests` (both suites) and three in `HowItNudgesTests`. The store maps `consistent` with its wait (`StoreError.Field.paceWait` is new). Beyond the criteria: the store reads a Consistent pace with no wait, or a wait not in `consistentWaits`, as unreadable rather than nudging at a rhythm nobody chose. If the wait list ever changes, saved reminders with a dropped wait won't load (no migration, ADR 0004). The engine itself does not guard a wait of 0; the form (07b) only offers the list. Stop never reaches the engine, so its test checks that the next nudge stays planned one wait later, as `StopAndDoneTests` does.
