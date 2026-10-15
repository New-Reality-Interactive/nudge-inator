Status: resolved

# Break through Focus on and off decides the delivery kind

## What to build

Each reminder has a Break through Focus setting. **On**: Normal is an ordinary notification, High is a Time Sensitive notification, Urgent is an alarm. **Off**: every nudge is an ordinary notification, regardless of urgency or strength. The plan item's delivery kind (ordinary notification, Time Sensitive notification, alarm) is what adapters act on.

## Acceptance criteria

- [x] With the switch on, Firm and Relentless plans contain ordinary, then Time Sensitive, then alarm items by urgency.
- [x] With the switch on, Gentle plans contain only ordinary and Time Sensitive items (no alarm items).
- [x] With the switch off, every plan item for every strength is an ordinary notification.
- [x] Changing nothing else, flipping the switch changes only delivery kinds, not times or counts.

Blocked by: 04

## Comments

**The switch is on by default.** The spec doesn't give a default; the mockup does. `btOf` reads `r.breakThrough !== false`, and the New Reminder form starts with `breakThrough: true`. So `Reminder.breakThroughFocus` defaults to `true`. That also keeps every delivery-kind assertion from tickets 03 and 04 passing unchanged.

**The engine works out the delivery kind, and the plan item stores it.** `SchedulePlan.Item.deliveryKind` is now a stored property, set in `Engine.deliveryKind(of:for:)`. Before, it was computed from urgency. Keeping it computed would mean putting the reminder's setting on every item now, and in tickets 14 and 15 also whether alarms are denied and whether the alarm limit was hit. Those are system state the engine knows and an item doesn't. With the rule in one engine function, those tickets add a case there, and adapters just read a value.

**Off changes only the delivery kind.** The spec says "With it off: every nudge is an ordinary notification," and nothing about urgency or timing. The mockup's `viaFor(urg, bt)` changes only the delivery route too. So with the switch off, the fire times, the count, the urgency and the notification text ("Nudge 4 of 20 · Urgent") stay as they are. `flippingSwitchChangesOnlyDeliveryKinds` checks this for every strength. The mockup's "Notification: Break through Focus is off" label is UI, not engine work.

**Delivery kinds, nudges 1–20.** On: Gentle 1–4 notification, 5–20 Time Sensitive (never an alarm). Firm 1–2 notification, 3 Time Sensitive, 4–20 alarm. Relentless 1–3 Time Sensitive, 4–20 alarm. Off: every nudge for every strength is an ordinary notification. The tests are in `BreakThroughFocusTests.swift`.

**TDD note.** Only the switch-off test went red. The switch-on and flip tests passed on their first run, because the first green slice already delivered that behavior. They stay as acceptance coverage.

**Left alone:** the denied-alarm and alarm-limit fallbacks (tickets 14 and 15), the lock while nudging (ticket 13, ADR 0002), and the adapters (tickets 18 and 19). The comment on `nudgeRingsAsAlarmFromNudgeFour` in `FirmAndRelentlessLadderTests.swift` still says "the only mapping until ticket 05". Test files from earlier tickets were kept unchanged, so it is out of date but correct for the default.
