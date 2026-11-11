# A sender's edit passes the lock on a received reminder

A sender's change to a received reminder's due time, repeat, strength, pace or Break through Focus applies even while the recipient's copy is Nudging: its open occurrence closes as Skipped, and nudging re-plans from the new values. That is the same outcome as Pause, edit and Resume. The recipient's own lock is unchanged, and the recipient can't edit those fields at all.

ADR 0002 locks these fields so that a person can't escape their own nudging by editing the reminder. That reason doesn't apply here: the sender owns the reminder and isn't escaping anything, and a wrong time has to be correctable while it's nudging someone else. The copy says what changed, on its details page and in a notification, so a moved time doesn't catch the recipient out.

## Considered Options

- **Hold the sender's change until the occurrence closes.** Rejected: the recipient keeps being nudged at a time the sender knows is wrong, and a change could wait up to the give-up limit.
- **Apply it without closing the occurrence.** Rejected: it needs the strength and pace re-plan rules that ADR 0002 removed.

## Consequences

- A Skipped occurrence on a received reminder can come from the sender, not only from the recipient's Pause.
- Break through Focus counts with the rest: a sender's change to it also closes the open occurrence, as Pause, edit and Resume would. Title and notes alone close nothing.
- A one-off that is Nudging or already closed has no due time after now to re-plan from, so after the sender changes its strength, pace or Break through Focus it nudges no more until the sender gives it a new due time. That is Resume's `needsNewDueTime` case.
- A late-accepted one-off has its due time set to the moment of acceptance (Ask me first), and its origin keeps the sender's original due time, saved with it. The sender's revision carries that original, which the engine doesn't count as a change, so the note stays quiet and the copy doesn't become a long-overdue Missed. Any other due time in the revision is the sender's own and applies, a move to an earlier time included; it replaces the original on the origin. A one-off never accepted late has no original, so a sender's move of it to an earlier time applies too.
- A revision's number must be higher than the copy's, or the engine ignores it: a late, out-of-order or repeated delivery changes nothing, and a newer revision is never undone by an older one.
