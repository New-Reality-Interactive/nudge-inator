Status: ready-for-agent

# Break through Focus on and off decides the delivery kind

## What to build

Each reminder has a Break through Focus setting. **On**: Normal is an ordinary notification, High is a Time Sensitive notification, Urgent is an alarm. **Off**: every nudge is an ordinary notification, regardless of urgency or strength. The plan item's delivery kind (ordinary notification, Time Sensitive notification, alarm) is what adapters act on.

## Acceptance criteria

- [ ] With the switch on, Firm and Relentless plans contain ordinary, then Time Sensitive, then alarm items by urgency.
- [ ] With the switch on, Gentle plans contain only ordinary and Time Sensitive items (no alarm items).
- [ ] With the switch off, every plan item for every strength is an ordinary notification.
- [ ] Changing nothing else, flipping the switch changes only delivery kinds, not times or counts.

Blocked by: 04
