# Nudge-inator

An iPhone app that keeps nudging you about a reminder, the way an iOS Alarm keeps ringing, until you mark it done.

## Language

**Reminder**:
Something you want to be nudged about, with a due time, optional repeat, and any number of tags.
_Avoid_: Task, alarm

**Occurrence**:
One due instance of a reminder. A reminder has at most one open occurrence at a time.
_Avoid_: Instance, run

**Start**:
A reminder's first due time, as the form's Starts row sets it. A repeat's later due times are worked out from it.
_Avoid_: DTSTART (the RRULE term, never on screen)

**Repeat**:
How often a reminder comes due again: Never, one of six presets, or a custom rule in the RRULE format.
_Avoid_: Recurrence (RRULE is the stored format, not a word for the screen)

**Nudge**:
One alert sent while an occurrence is open: an alarm or a notification.
_Avoid_: Ping, alert

**Nudging**:
The state of an occurrence that has come due and is not yet done.

**Locked**:
The state of a Nudging reminder's due time, repeat, strength, pace and Break through Focus. They can't be edited until the occurrence closes. Title, notes and tags stay editable.
_Avoid_: Frozen, read-only

**Done**:
The explicit act that closes an occurrence. Stopping an alarm does not mean Done; it only silences that nudge.
_Avoid_: Complete, dismiss, stop

**Stop**:
The system alarm's button, which silences the current ring and moves the ladder along. The next nudge still comes on schedule. It is the only way to take a break from nudging.

**Open**:
The alarm's secondary button. It opens the app on the reminder, where the person can mark it Done.

**Break through Focus**:
A per-reminder setting. On: nudges are sent as alarms, which sound through silent mode and Focus. Off: nudges are ordinary notifications that a Focus can hold. A Relentless reminder always breaks through Focus; its switch stays on.

**Strength**:
How hard a reminder nudges: Gentle, Firm or Relentless. It sets the urgency ladder and the give-up limit, and with an Escalating pace the waits between nudges too. Relentless nudges only with alarms.
_Avoid_: Priority, level

**Pace**:
How the waits between a reminder's nudges are spaced: Escalating or Consistent. Each reminder has its own; a new reminder starts with the default pace from Settings.
_Avoid_: Ladder, spacing, schedule

**Escalating**:
The pace whose waits come from the strength and shrink as the nudging goes on.

**Consistent**:
The pace with one wait, chosen by the person from 2 min to 16 h, the same between every nudge.

**Urgency**:
A nudge's place on its strength's ladder: Normal, High or Urgent. Urgency decides how the nudge is delivered.

**Fallback**:
A weaker way of delivering a nudge when a permission is missing or the alarm limit is reached. Alarms denied, or past the alarm limit: Urgent nudges come as Time Sensitive notifications. Time Sensitive off: High nudges, and Urgent ones that fall back, are ordinary notifications. Notifications denied: only alarms can still arrive.

**Alarm limit**:
How many alarms can be pending at once: the system's, which AlarmKit reports only as the `maximumLimitReached` error, and the engine's own cap of 4,000 alarms yet to ring, what ticket 02 measured scheduling. An Urgent nudge past it falls back and is marked "too many alarms scheduled".

**Reach**:
What can still reach the person with the permissions they've given: how a nudge of each urgency arrives, or that it can't. The permission banners say it.

**Give-up limit**:
The number of nudges or span of time after which an open occurrence stops nudging and closes as Missed.

**Missed**:
How an occurrence closes when it hits its give-up limit, or when the next occurrence takes over while it is still nudging.

**Paused**:
The state of a reminder that has stopped nudging without being lost. Pause closes its Nudging occurrence as Skipped, and anything due while it is paused is Skipped too. Resume brings it back at its next future due time.
_Avoid_: Disabled, suspended

**Skipped**:
How an occurrence closes when its reminder is paused while it is Nudging, or when it falls due while the reminder is paused. It isn't counted as Missed.
_Avoid_: Cancelled

**Tag**:
A one-word label (`#home`) on a reminder, used only to filter. Never shown in alerts.

**My Day**:
Today's occurrences in time order, with Done, Nudging, Missed and Left counts.
