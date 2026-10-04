Status: ready-for-agent

# Delete a reminder

## What to build

A Delete event removes the reminder and cancels everything pending for it: the plan has no items for it, and any open occurrence is removed (not left as Missed). Tags it used are kept (tag rules in ticket 15). The confirmation dialog is a screen concern (ticket 24).

## Acceptance criteria

- [ ] After Delete of a Nudging reminder the plan has zero items for it.
- [ ] Other reminders' plans are unchanged.
- [ ] Delete of an unknown or already-deleted reminder is a no-op, not a crash.
- [ ] Tags the reminder used still exist.

Blocked by: 07
