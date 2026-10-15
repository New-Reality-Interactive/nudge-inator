Status: resolved

# Stop moves the ladder along; Done ends it and cancels everything pending

See `docs/adr/0001-stop-silences-done-is-deliberate.md`.

## What to build

- **Stop** event (the alarm's system Stop): the occurrence stays Nudging; the next nudge still comes on schedule; the plan keeps all later nudges. Stop is **not** Done.
- **Done** event (from card, notification action, swipe, My Day, Open destination): the occurrence closes as Done and the plan removes every pending alarm and notification for it. Done after the occurrence already closed (Missed) is ignored or reported, document which.
- **App opened** event: the engine reconciles with the clock (nudges whose time has passed count as delivered, give-up limit applied).

## Acceptance criteria

- [x] After Stop at nudge 4, state is Nudging and the plan still has nudges 5…N at their original times.
- [x] After Done, occurrence state is Done and the plan has zero items for it.
- [x] Stop twice, or Stop after the last nudge, does not crash or change the close reason.
- [x] App opened after a long gap closes an over-limit occurrence as Missed and leaves a within-limit one Nudging at the right nudge number.
- [x] No event other than Done closes an occurrence as Done.

Blocked by: 06

## Comments

**Stop is not an engine event.** The spec says Stop needs no app code ("Alarm presentation"): the system silences the ring and the pre-scheduled chain carries on. Occurrence state is computed from the clock, so Stop would change nothing in the engine. A no-op `stop` would only invite app code to call it. So the engine has no Stop entry point, and Stop can't close anything as Done by construction. The tests model Stop as what it is to the engine: a nudge's time passing with no Done, with the app calling `update(reminders:)` when it next comes to the foreground. `afterStopAtNudgeFourTheLaterNudgesStayAtTheirOriginalTimes` checks nudges 5–20 keep their original items for every strength. `stoppingEveryRingIncludingTheLastNeverClosesAsDone` walks Relentless through every nudge (a `for` loop, because it is one scenario in sequence, not separate cases) and ends Missed with reason `.giveUpLimit`. If a device check (ADR 0001) ever shows the app gets a Stop callback it needs to act on, add the event then.

**Done is an event on the engine: `markDone(_ reminderID:)`.** It closes the reminder's open occurrence as `OccurrenceState.done` and re-applies the plan without that occurrence's items. Done is the one occurrence fact the clock can't work out, so the engine records it, keyed by the occurrence (reminder ID plus due time), not by the reminder. It isn't carried on `Reminder`: the mockup keeps Done on its occurrence records, not on the reminder, and a reminder with repeats (tickets 08–10) will have many occurrences. Keying by due time already gives the right answer when the due time moves after Done (the lock has lifted, ADR 0002): the new occurrence nudges (`doneClosesTheOccurrenceNotTheReminder`). Done survives later `update(reminders:)` calls and the give-up time passing (`doneSurvivesAFreshUpdatePastTheGiveUpTime`).

**Left for the store (ticket 17).** The Done record lives in the `Engine` value only, so it is lost on relaunch until the store persists occurrence state and hands it back. Ticket 17 needs a way to read the recorded Done occurrences out and seed them into a new engine (for example an occurrence-record input next to `update(reminders:)`). Until then, a relaunched engine would re-plan a Done occurrence's remaining nudges. Nothing ships before ticket 21 wires the store, so nothing is lost today.

**Done with no open occurrence is ignored, not reported.** That covers Done after Missed, Done twice, and Done before the due time. The mockup's `ack` returns early unless the occurrence is NUDGING. Done can race the give-up limit (a notification action tapped just after give-up), or arrive from two surfaces at once, and neither is an error to show the person. Missed keeps its reason (`doneAfterTheOccurrenceIsMissedIsIgnored`). Before the due time there's no occurrence for Done to close, so the occurrence still nudges from nudge 1 when it comes due (`doneBeforeTheDueTimeIsIgnored`). The spec offers Done only on a nudging occurrence.

**App opened is `update(reminders:)`.** No new entry point, as ticket 06 decided. It reads the clock, counts every nudge whose time has passed as sent, applies the give-up limit and rebuilds the plan. `appOpenedAfterALongGapClosesOverLimitAsMissedAndKeepsWithinLimitNudging`: three hours after both fall due, Firm is Missed (gave up at +2 h 17 min 30 s), Gentle is Nudging at nudge 5 (+2 h 44 min 4 s), and the plan holds only Gentle's items.

**TDD note.** Red first: Done at nudge 4 (no `markDone` or `.done`), Done after Missed (Done was recorded unconditionally), and Done closing the occurrence, not the reminder (Done was keyed by reminder). These passed on their first run and stay as acceptance coverage: Done surviving a fresh update, Done closing only its own occurrence, Done before the due time, and the three Stop and app-opened tests. They follow from computed state plus the occurrence-keyed Done record.

**Left alone:** repeats and take-over (08–10), Pause/Skipped (11), Delete (12), the lock (13), the fallbacks (14, 15), the store (17), and the adapters and the Open intent (18–20). Notification actions call `markDone` once ticket 18 adds them.
