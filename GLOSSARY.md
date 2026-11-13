# Nudge-inator

An iPhone app that keeps nudging you about a reminder, the way an iOS Alarm keeps ringing, until you mark it done.

## Language

**Reminder**:
Something you want to be nudged about, with a due time, optional repeat, and any number of tags.
_Avoid_: Task, alarm

**Creation date**:
The moment a reminder was added. It never changes: editing, Done, Pause and Resume leave it as it was. "Created" on screen.
_Avoid_: Date added, start (a reminder's Start is its first due time)

**Occurrence**:
One due instance of a reminder. A reminder has at most one open occurrence at a time.
_Avoid_: Instance, run

**Start**:
A reminder's first due time, as the form's Starts row sets it. A repeat's later due times are worked out from it.
_Avoid_: DTSTART (the RRULE term, never on screen)

**Repeat**:
How often a reminder comes due again: Never, one of six presets, or a custom rule in the RRULE format.
_Avoid_: Recurrence (RRULE is the stored format, not a word for the screen)

**End Repeat**:
When a repeat stops: Never, After a number of times, or On a date. Its own row in the reminder form, under Repeat, for any repeat but Never. The repeat without its end is its pattern, which the Repeat menu names.
_Avoid_: Ends (the old Custom page section), COUNT and UNTIL (the RRULE terms, never on screen)

**Nudge**:
One alert sent while an occurrence is open: an alarm or a notification.
_Avoid_: Ping, alert

**Nudging**:
The state of an occurrence that has come due and is not yet done.

**Coming up**:
The status of a reminder that isn't Nudging or Paused and has a due time ahead. Now's Coming Up section lists those due in the next 7 days.
_Avoid_: Upcoming, scheduled, pending

**Status label**:
The word, with its color, that says a reminder's or occurrence's status: Nudging, Coming up, Paused, Done, Missed or Skipped, and for a sent or received reminder also Waiting, Canceled or Removed.
_Avoid_: Status badge (a badge is a count)

**Locked**:
The state of a Nudging reminder's due time, repeat, strength, pace and Break through Focus. They can't be edited until the occurrence closes. Title, notes and tags stay editable. A sender's change to a received reminder passes the lock (ADR 0005).
_Avoid_: Frozen, read-only

**Done**:
The explicit act that closes an occurrence. It also silences that occurrence's ringing alarm. Stopping an alarm does not mean Done; it only silences that nudge.
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

**Default pace**:
The pace set in Settings that every new reminder starts with: Consistent · 10 min until the person changes it, and again after Delete All Data. Changing it never changes a reminder already made.
_Avoid_: Global pace, pace setting

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
The state of a reminder that has stopped nudging without being lost. Pause closes its Nudging occurrence as Skipped and silences its ringing alarm, and anything due while it is paused is Skipped too. Resume brings it back at its next future due time.
_Avoid_: Disabled, suspended

**Skipped**:
How an occurrence closes when its reminder is paused while it is Nudging, or when it falls due while the reminder is paused or waiting to be accepted, or when a sender's change reaches a copy that is Nudging. It isn't counted as Missed.
_Avoid_: Cancelled

**Tag**:
A one-word label (`#home`) on a reminder, used only to filter. Never shown in alerts.

**My Day**:
Today's occurrences in time order, with Done, Nudging, Missed and Left counts.

**Due Today**:
The reminders My Day lists for today, whatever their status, Done and Missed included.
_Avoid_: Today (alone), due now

**Reminders tab**:
The tab that lists every reminder once, in any status, by creation date, with search and filters.
_Avoid_: All Reminders, list, library

**Kept order**:
The order the Reminders tab's rows had when it last sorted them, which the rows keep so that Done or going Missed doesn't move a row sorted by Due Date. The tab sorts again when it is chosen, when the sort or filter changes, or when the store is read; opening a reminder's details and coming Back keeps it. A reminder added since goes where the sort puts it, and a deleted or filtered-out one drops out.
_Avoid_: Frozen order, sticky sort, cached order

**Due Date filter**:
The part of the Reminders tab's filter sheet that narrows the list to reminders due from one day to another, both days included. Either day may be left off. A reminder is tested by the due time its row shows.
_Avoid_: Date range (on screen), start and end (a reminder's Start is its first due time)

**Has no reminders**:
The Tags tab filter sheet's one condition: only tags that no reminder uses, whatever that reminder's status. It is about the tag itself, not the state of its reminders.
_Avoid_: Unused tags (on screen), empty tags

**Icon badge**:
The number on the app's home-screen icon: how many reminders have an occurrence that is Nudging. It is the same count as the Now badge. It is not a Nudge.

**Now badge**:
The number on the Now tab: how many reminders have an occurrence that is Nudging. The Icon badge shows the same count.

**Connection**:
Two people who have agreed to send each other reminders, set up by one accepted Invite. It works both ways, and either person can end it.
_Avoid_: Friend, contact, share, follower

**Invite**:
A personal request to connect, sent to the Apple Account of one person. Until they accept it, the sender sees that person as Invited.
_Avoid_: Share (for a connection), request

**Disconnect**:
Ending a Connection. Whoever ends it chooses what happens to the reminders they received from the other person: **Remove** (the default) deletes them, and **Keep as My Own Reminders** makes each accepted one their own, no longer from anyone. One still waiting to be accepted, or Canceled, goes either way. Neither can send to the other again until a new Invite is accepted.
_Avoid_: Unshare, unfriend, block

**Connection Ended**:
What a person sees once the other person has disconnected: a note that the connection ended, with the same Remove or Keep as My Own Reminders choice for what they received, which they have to make.
_Avoid_: Disconnected (for the other person's side)

**Sender**:
The person who sent a reminder. The sender owns what it says and when it's due.

**Recipient**:
A person a reminder was sent to. Each recipient has their own copy, with its own occurrences and status.

**Sent reminder**:
A reminder as its sender sees it, listed under Sent by person. It nudges only its recipients and has no tags.
_Avoid_: Shared reminder, outgoing reminder

**Received reminder**:
A recipient's copy of a reminder someone sent them, shown among their own as "From <name>". The recipient can mark it Done, pause it, remove it and tag it, and can't change what it says or when it's due.
_Avoid_: Shared reminder, incoming reminder

**Original due time**:
The sender's due time of a one-off that its recipient accepted after it had come (Ask me first). The copy's own due time is then the moment of acceptance, and its origin keeps the original, so a later sender's revision can tell the sender's own move from the original. A copy accepted in time, or a repeating one, has none.
_Avoid_: Initial due time

**Sender's revision**:
The sender's edit of a reminder they sent, as it reaches a recipient's copy. It replaces what the copy says and when it's due, even while the copy is Nudging, and comes with a change note.
_Avoid_: Update, sync

**Change note**:
What a received reminder shows after a sender's revision: each field that changed, with its old and new value, such as "Due time changed from 8:00 AM to 9:00 AM" (a change to the notes says only that they changed).
_Avoid_: Changelog, edit history

**Status report**:
What the engine says about a received reminder for its sender: its Status label now, and the label of each occurrence due today or in the 7 days before. A Missed in it is the engine's reading when it works out the occurrence's close, which may be later than the give-up limit. Removed is never in it: the engine no longer holds a removed copy. Nor are Waiting and Canceled, which the sender's side works out from the receipt and the sender's own deletion.
_Avoid_: Sync status, history

**Sent read-out**:
What the sender's side shows for each reminder it sent, grouped by person, with one row for each recipient's copy. A row says whether the copy was Delivered, is waiting for them to accept, or hasn't been delivered, then its reported status with the 7 days, or "Not sharing status" (status sharing off) or "Not sharing this one", and Waiting to sync. It is worked out from what the sender's app knows, never from the recipient's engine, and its days are the recipient's. A person with nothing sent has no group.
_Avoid_: Sent status, outbox

**7-day history**:
What the sender sees of one recipient's copy of a repeating reminder: today and each of the 7 days before, oldest first, each with the Status label of the occurrence due that day, or nothing due. Its days are the recipient's. It shows only where the copy's status does: never with Status sharing off, "Not sharing this one", Waiting to sync or waiting for them to accept. A one-off has none.
_Avoid_: Streak, week view, history (alone)

**Sender notice**:
The notification the sender's app posts when a status report it just received shows a copy newly marked Done, removed, or Missed, set against the report it held; Pause, Resume and Skipped are never one. With nothing held (before the first report, after status sharing was turned back on, or while "Don't share this one" held it back) the report is the baseline and is no notice, except Removed. A Missed may come long after the give-up limit, and a notice is best effort: the Sent read-out is always right once fetched.
_Avoid_: Sent status, sender alert

**Status sharing**:
A recipient's choice, per connection, whether the sender sees how their reminders are going. "Don't share this one" turns it off for one received reminder.
_Avoid_: Visibility, privacy setting

**Delivery mode**:
A recipient's choice, per connection, of how a received reminder starts: Start right away, or Ask me first, where it waits for them to accept it and sends no nudge until they do.
_Avoid_: Approval, acceptance mode

**Delivered**:
That a sent reminder's copy has reached the recipient's iPhone and started. The sender sees it whatever the status sharing. A copy that has reached the iPhone but waits for them to accept it reads "Waiting for them to accept" instead.
_Avoid_: Received, sent

**Waiting to sync**:
What hasn't reached the other person yet because it hasn't gone through iCloud: a sent reminder, a change or a status.
_Avoid_: Pending, offline

**Sharing store**:
The second store on the iPhone, beside the one holding the person's reminders, for what sharing needs: connections, sent reminders, how each recipient's copy is going, what each received reminder has yet to sync, the sync engine's saved state, and the changes not yet sent to iCloud. It is new and empty in 1.4.0, never synced by the system, and the reminders' own store never holds any of it.
_Avoid_: Shared store

**Outbox**:
The sharing store's queue of changes not yet sent to iCloud, oldest first: a send, a revision, a cancel, a receipt, a status, a settings change or a disconnect. What a person sees of it is Waiting to sync.
_Avoid_: Pending, sync queue

**Sharing adapter**:
The one door to sharing in the app: it takes the changes to send (a send, a revision, a cancel, a receipt, a status, a settings change, a disconnect), reports the changes that arrive, and reports the iCloud account. The app model talks only to it, as it does to the alarm and notification adapters; the code behind it is the only place that talks to iCloud.
_Avoid_: Sync layer, CloudKit manager

**Sharing reach**:
What sharing can do with the person's iCloud account: working, or paused because there is no account, it is restricted, or iCloud is temporarily unavailable. The messages on Connections, Send To and Sent say it, as the permission banners say Reach.
_Avoid_: Sync status

**Canceled**:
The state of a received reminder its sender deleted. It no longer nudges and stays, with a note, until the recipient removes it.
_Avoid_: Deleted, Skipped (an occurrence's close)
