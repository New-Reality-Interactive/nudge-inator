# A sender's edit passes the lock on a received reminder

A sender's change to a received reminder's due time, repeat, strength, pace or Break through Focus applies even while the recipient's copy is Nudging: its open occurrence closes as Skipped, and nudging re-plans from the new values. That is the same outcome as Pause, edit and Resume. The recipient's own lock is unchanged, and the recipient can't edit those fields at all.

ADR 0002 locks these fields so that a person can't escape their own nudging by editing the reminder. That reason doesn't apply here: the sender owns the reminder and isn't escaping anything, and a wrong time has to be correctable while it's nudging someone else. The copy says what changed, on its details page and in a notification, so a moved time doesn't catch the recipient out.

## Considered Options

- **Hold the sender's change until the occurrence closes.** Rejected: the recipient keeps being nudged at a time the sender knows is wrong, and a change could wait up to the give-up limit.
- **Apply it without closing the occurrence.** Rejected: it needs the strength and pace re-plan rules that ADR 0002 removed.

## Consequences

- A Skipped occurrence on a received reminder can come from the sender, not only from the recipient's Pause.
