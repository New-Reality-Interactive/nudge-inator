# Nudge-inator

An iPhone app that keeps nudging you about a reminder, the way an iOS Alarm keeps ringing, until you mark it done.

## Language

**Reminder**:
Something you want to be nudged about, with a due time, optional repeat, and any number of tags.
_Avoid_: Task, alarm

**Occurrence**:
One due instance of a reminder. A reminder has at most one open occurrence at a time.
_Avoid_: Instance, run

**Nudge**:
One alert sent while an occurrence is open: an alarm or a notification.
_Avoid_: Ping, alert

**Nudging**:
The state of an occurrence that has come due and is not yet done.

**Done**:
The explicit act that closes an occurrence. Stopping an alarm does not mean Done; it only silences that nudge.
_Avoid_: Complete, dismiss, stop

**Stop**:
The system alarm's button, which silences the current ring and moves the ladder along. The next nudge still comes on schedule. It is the only way to take a break from nudging.

**Open**:
The alarm's secondary button. It opens the app on the reminder, where the person can mark it Done.

**Break through Focus**:
A per-reminder setting. On: nudges are sent as alarms, which sound through silent mode and Focus. Off: nudges are ordinary notifications that a Focus can hold.

**Strength**:
How hard a reminder nudges: Gentle, Firm or Relentless. It sets the nudge intervals, the urgency ladder and the give-up limit.
_Avoid_: Priority, level

**Urgency**:
A nudge's place on its strength's ladder: Normal, High or Urgent. Urgency decides how the nudge is delivered.

**Give-up limit**:
The number of nudges or span of time after which an open occurrence stops nudging and closes as Missed.

**Missed**:
How an occurrence closes when it hits its give-up limit, or when the next occurrence takes over while it is still nudging.

**Tag**:
A one-word label (`#home`) on a reminder, used only to filter. Never shown in alerts.

**My Day**:
Today's occurrences in time order, with Done, Nudging, Missed and Left counts.
