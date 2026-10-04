Status: ready-for-agent

# Fallbacks for denied alarms and denied notifications

## What to build

Permission states are inputs to the engine (notifications: allowed / denied; alarms: allowed / denied / not determined; Time Sensitive: on / off).

- **Alarms denied**: Urgent nudges become Time Sensitive notifications (spec story 51).
- **Time Sensitive off** (from the mockup README): High nudges become ordinary notifications.
- **Notifications denied**: nothing is deliverable by notification; alarms (if allowed and Break through Focus is on) still plan. The engine exposes a "what can still reach you" summary the banners (ticket 28) read.
- Permission changes re-plan the remaining nudges.

## Acceptance criteria

- [ ] Relentless, switch on, alarms denied: no alarm items; former Urgent items are Time Sensitive.
- [ ] Time Sensitive off: former High items are ordinary.
- [ ] Notifications denied and alarms allowed: only alarm items remain; summary says so.
- [ ] Everything denied: empty plan and a summary that says nothing can reach you.
- [ ] Switching a permission mid-occurrence changes only not-yet-delivered items.

Blocked by: 05
