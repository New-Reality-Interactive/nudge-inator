# Pace is separate from strength, and Relentless only rings

A reminder's pace (Escalating or Consistent) decides the waits between its nudges. Its strength decides only how each nudge arrives and the give-up limit, except under Escalating, where the strength's own shrinking waits are the pace. A Consistent pace uses one wait the person picks, from 2 min to 16 h. New reminders take the default pace, and its wait, from Settings, which ships as Consistent every 10 min.

Relentless now nudges with alarms from nudge 1, under either pace, so a Relentless reminder always breaks through Focus: its switch is shown on and can't be turned off. Gentle and Firm keep sending notifications before, or instead of, alarms.

Strength used to mean both "how fast" and "how loud". Splitting them lets a steady rhythm come at any loudness. Relentless had been reserved for the reminder that must get through, yet its first three nudges were Time Sensitive notifications that a Focus could hold.

## Considered Options

- **A fourth strength with a steady rhythm.** Rejected: it would only offer one loudness at a steady rhythm, and Strength would still mix speed with loudness.
- **Consistent ignores strength entirely.** Rejected: the person would lose the choice of how loud a steady reminder is.
- **Relentless with Break through Focus off sends ordinary notifications.** Rejected: then Relentless could be quieter than Firm with the switch on.

## Consequences

- When alarms are denied or past the alarm limit, Relentless still falls back to Time Sensitive and then ordinary notifications. "Only alarms" describes what is sent while alarms can ring. A weaker nudge beats none.
- The give-up limit stays 20 nudges or 24 hours for every pace, so a 2 min wait gives up after 40 min and a 16 h one after 2 nudges.
- Each reminder stores its own pace. Changing the default in Settings never moves an existing reminder.
- The stored reminder changed with no migration: this shipped to beta testers who reinstalled.
