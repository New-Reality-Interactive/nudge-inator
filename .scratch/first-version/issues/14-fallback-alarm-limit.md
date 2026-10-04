Status: ready-for-agent

# Fallback for the alarm limit, and the chain length the spike chose

## What to build

When the scheduler reports `maximumLimitReached` for an Urgent nudge, the engine re-plans that nudge as a **Time Sensitive notification** marked "Notification: too many alarms scheduled" and keeps the rest of the ladder. Use the spike's measured limit (ticket 02) to set how many alarms are kept pending at once (the chain length), and which later nudges are scheduled lazily when the app opens, if the limit is below what a full ladder needs.

Events in: "scheduling failed with alarm limit for item X" from the adapter. The fake scheduler can be told to fail after N alarms.

## Acceptance criteria

- [ ] With a fake scheduler whose limit is N, a plan that needs more than N alarms is delivered with the overflow nudges as Time Sensitive notifications carrying the "too many alarms scheduled" marker.
- [ ] The marker text appears only on the overflow nudges.
- [ ] Chain length constant equals the value recorded in ticket 02's answer; the test names the number and cites the ticket.
- [ ] When a slot frees (an alarm fired or was stopped) a later reconcile promotes a notification back to an alarm only if the spike showed slots are reusable; otherwise the behaviour is documented.
- [ ] Alarms-denied fallback (ticket 13) and limit fallback combine without duplicating items.

Blocked by: 13, 02
