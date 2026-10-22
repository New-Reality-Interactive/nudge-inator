# 04: Prefactor: reminders carry a pace

**What to build:** Make the change easy before making it. A reminder gets a pace, saved and reloaded with it, and the engine works out a reminder's nudge times, waits and give-up time from its pace and strength together instead of from the strength alone. Only Escalating exists for now, so every reminder nudges exactly as before and nothing changes on screen. Spec stories 5 and 6, and the Implementation Decisions on the engine, storage and How It Nudges read-out.

**Blocked by:** 03 (no implementation starts before the proposed mockup is approved).

**Status:** ready-for-agent

- [x] A reminder has a pace, Escalating, using the GLOSSARY's terms; the engine stays free of Apple frameworks.
- [x] The stored reminder record holds the pace, and a saved reminder reloads with it. No migration (the spec's beta install note).
- [x] The engine's nudge times, waits and give-up time come from pace and strength together; urgency still comes from the strength.
- [x] The How It Nudges read-out takes the pace.
- [ ] Every existing engine and app test passes unchanged on both simulators, showing Gentle, Firm and Relentless nudge as before.
- [x] New tests: a reminder's pace survives a save and reload; an Escalating reminder of each strength plans the same nudges as before.

## Before you start

- Builds on: ticket 03: the approved proposed mockup, `docs/mockups/2026-10-21-proposed-pace/` (its README's "How nudging works here" is the target model). Nothing in this ticket shows on screen. Ticket 03's Comments record Brian's approval, and the criteria it added to tickets 05–10.
- Watch for: the waits, nudge times and give-up time live on `Strength` through `Ladder` (`Packages/NudgeEngine/Sources/NudgeEngine/Ladder.swift`: `interval(afterNudge:)`, `nudgeTimes(from:within:)`, `giveUpTime(from:after:within:)`). The engine calls them at `Engine.swift` (around lines 411 and 561) and `HowItNudges.swift` (around lines 40 and 63). The spec splits `Ladder`: its waits (`initialWait`, `factor`, `floor`) go with the pace, and its urgency steps (`highFrom`, `urgentFrom`) stay with the strength. The existing suites must pass unchanged: `GentleLadderTests`, `FirmAndRelentlessLadderTests`, `GiveUpLimitTests` and `HowItNudgesTests`. They are also prior art for the new tests. The pace goes in `ReminderRecord` (`App/Store/StoredRecords.swift`) as kind and wait. "No migration" means no data conversion. Give the new stored properties default values, so SwiftData can still open the iPhone's existing store before the beta reinstall (ticket 09).
- Developer stops: agree the `tdd` seams (engine through the plan and How It Nudges; app through the reminder store). No simulator or device check: nothing changes on screen.

## Comments

**Open criterion: "Every existing engine and app test passes unchanged on both simulators."** `scripts/test.sh` passes on both (301 app tests each, the engine package's 241), but one existing test line changed: `AlarmLimitFallbackTests.swift` called `bins.strength.nudgeTimes(from:within:)`, and the waits moved off `Strength`, so it now calls `bins.nudgeTimes(from:within:)`. Same call, same assertions. Left unticked and Status unchanged until Brian agrees: accept the one-line change and reword the criterion to "pass, with one call site updated", or keep a `Strength.nudgeTimes` for the old call (which keeps a strength-only path this ticket removes).

Found in review: `ReminderForm.draft(tagIDs:repeatRule:)` builds a `Reminder` without a `pace`, so an edit saved from the form resets it to Escalating. Harmless while only Escalating exists. Ticket 07, which adds Consistent and the form's pace, must carry the reminder's pace through the draft.
