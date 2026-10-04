# Stop silences an alarm; Done is a separate, deliberate act

The alarm's system **Stop** button only silences the current ring and moves the nudge ladder along, so the next nudge still comes on schedule. The alarm's secondary button is a custom **Open** button that opens the app on the reminder, where **Done** is the only way to end nudging. The earlier mockup treated Stop as Done because AlarmKit's stop button can't be relabelled, but a half-asleep Stop would then end a reminder meant to keep nudging "until I finally mark it done."

## Considered Options

- **Stop = Done (the mockup).** Rejected: an accidental Stop ends the nudging, and it needs Not Done, Undo and a Done follow-up notification to recover.
- **Native Snooze as the secondary button.** Rejected: Done would then be reachable only by opening the app on your own. Snooze is dropped from the first version, and Stop is the only break.

## Consequences

- AlarmKit has one secondary button, so Snooze can't also sit on the alert.
- The first version has no Not Done, Undo or Snooze.
- To be checked on a device: whether tapping Open silences the ring, and how Open behaves on a locked phone.
