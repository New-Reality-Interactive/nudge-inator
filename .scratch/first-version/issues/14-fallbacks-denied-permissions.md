Status: resolved

# Fallbacks for denied alarms and denied notifications

## What to build

Permission states are inputs to the engine (notifications: allowed / denied; alarms: allowed / denied / not determined; Time Sensitive: on / off).

- **Alarms denied**: Urgent nudges become Time Sensitive notifications (spec story 52).
- **Time Sensitive off** (from the mockup README): High nudges become ordinary notifications.
- **Notifications denied**: nothing is deliverable by notification; alarms (if allowed and Break through Focus is on) still plan. The engine exposes a "what can still reach you" summary the banners (ticket 31) read.
- Permission changes re-plan the remaining nudges.

## Acceptance criteria

- [x] Relentless, switch on, alarms denied: no alarm items; former Urgent items are Time Sensitive.
- [x] Time Sensitive off: former High items are ordinary.
- [x] Notifications denied and alarms allowed: only alarm items remain; summary says so.
- [x] Everything denied: empty plan and a summary that says nothing can reach you.
- [x] Switching a permission mid-occurrence changes only not-yet-delivered items.

Blocked by: 05

## Comments

**Decisions settled with the user before coding (2026-10-16).**
- **The permission input is a `PermissionStates` value** with three fields: `notifications` (`allowed`, `denied`), `alarms` (`allowed`, `denied`, `notDetermined`) and `timeSensitive` (`TimeSensitiveSetting`: `on`, `off`). It comes in two ways:
  - As an init parameter, so the app can start the engine with the real states and not apply a throwaway plan first. The default is notifications allowed, alarms not determined and Time Sensitive on. That is a fresh install before anything is denied, as in the mockup's `perm`.
  - As the event `update(permissions:)`, which re-plans. States equal to the current ones are ignored and apply no plan, like the other events with nothing to act on.
  - **For the adapters (ticket 18):** report the states at launch and on every foreground. Repeats cost nothing.
- **Alarms not determined plan as allowed.** The prompt may not have been shown yet (ticket 31). If the person then denies, `update(permissions:)` re-plans.
- **Alarms denied: one Time Sensitive notification per ladder nudge, not the mockup's chain.** The ticket and spec say so. It keeps "Nudge N of 20" and the give-up limit as they are, and ten notifications a minute per Urgent nudge would blow the 64-pending-notification cap (ticket 15). The `permBanner` text "a chain of Time Sensitive notifications" is a copy question for ticket 31.
- **Notifications denied: a nudge that can't be delivered drops out of the plan.** There is no "none" delivery kind, because an adapter has nothing to do with such an item. The summary is `Engine.reach`, a `Reach` value: how a nudge of each urgency (`normal`, `high`, `urgent`) arrives with Break through Focus on, or `nil` if it can't arrive at all. It depends only on the permissions, not on the reminders held. The mockup's "Gentle reminders can't reach you at all" is a fixed sentence. **For the banners (ticket 31),** each `permBanner` case reads:
  - notifications off: `normal == nil`
  - "Only Urgent nudges can reach you, as alarms": `urgent == .alarm`
  - "Nudges can't reach you": `urgent == nil`
  - alarms off: `urgent` is `.timeSensitiveNotification` (Time Sensitive chain) or `.notification` (ordinary chain)
  - Time Sensitive off: `high == .notification`
  - With alarms not determined and notifications denied, `reach` says Urgent nudges ring as alarms. That follows the rule above.
- **The combined cases are all in `Engine.deliveryKind`, which now returns `DeliveryKind?`:**
  - Switch on, Urgent, alarms not denied: alarm.
  - Otherwise, notifications denied: nothing. This includes the switch off with alarms allowed, as in the mockup's `viaFor`.
  - Switch off: ordinary.
  - Normal: ordinary.
  - High, and Urgent with alarms denied: Time Sensitive, or ordinary if Time Sensitive is off. So alarms denied with Time Sensitive off is ordinary, as in the mockup.
- **Already-delivered items keep the delivery in force when they fired.** This mirrors ticket 13's title rule. The engine keeps an app-wide record of replaced permission states with the time each was replaced. It is not in the per-reminder `History`, so Delete leaves it. A nudge firing exactly at a change counts as delivered (`fireTime <= replacedAt`). So a nudge that passed while notifications were denied stays out of the plan after they are allowed again, because it fired into nothing. Titles and permissions now share one `Replaced<Value>` record and one lookup.

**Tests** are in `PermissionFallbackTests.swift` (13 tests, 26 cases).
- **Red first:**
  - Alarms denied: there was no `PermissionStates`.
  - Time Sensitive off.
  - Notifications denied leaving only alarms.
  - `reach`.
  - Denying alarms mid-occurrence: there was no `update(permissions:)`, and plain re-planning would also have changed the two alarms already rung.
  - Unchanged states applying no plan.
- **Passed on their first run, kept as acceptance coverage:**
  - Everything denied (empty plan, and `reach` all `nil`).
  - Every `permBanner` case of `reach`, not determined included.
  - The switch off under each permission state.
  - The change at the exact moment a nudge fires.
  - Nudges that passed while notifications were denied staying out of the plan.
  - Deny, then allow alarms again.
  - The nudge count when nothing can be delivered.
- **Mutation-checked:**
  - `<` for `<=` in the fire-time lookup fails the exact-moment case.
  - Dropping the notifications guard fails eight tests.
  - Looking up the last replaced value instead of the first fails the deny-then-allow test and ticket 13's two-title test.
  - Pruning every record, or the wrong ones, fails the deny-then-allow test.

**Code review (two axes, against main).**
- **Spec: no missing requirements and no scope creep.**
  - Fixed: `update(permissions:)` now documents that a change counts from when the app hears of it, not when the person made it in Settings, which the app can't know.
  - Fixed: the record of replaced states grew forever. It is now pruned past the give-up span, since no plan item fires earlier than that.
  - Fixed: the new terms were not in GLOSSARY.md. Fallback and Reach are added.
  - Pinned with a test: nudges that can't be delivered still count along the ladder (`nudgesThatCantBeDeliveredStillCountAlongTheLadder`). The occurrence reads "nudge 5" and gives up on time. The banner says why nothing arrives.
  - Recorded, not changed: the record is in memory only. After a relaunch, passed items take the current states, which matters only for items the adapter skips anyway (ticket 13's note to 18). The store doesn't need to persist it (17).
  - **For ticket 15:** the alarm-limit fallback should go through `deliveryKind`, for example as a flag for the overflow nudge. Hard-coding `.timeSensitiveNotification` would skip notifications denied and Time Sensitive off. With alarms denied the plan has no alarm items, so the limit can't be hit and the two fallbacks can't duplicate an item. The note is also on `deliveryKind`.
- **Standards: no hard violations.** Fixed:
  - Time Sensitive was a `Bool` beside two enums. It is now `TimeSensitiveSetting` (`on`, `off`), as the ticket words it. `NotificationPermission` documents why it has no not-determined case.
  - `ReplacedPermissions` duplicated `ReplacedTitle` and its lookup. Both are now one `Replaced<Value>` with one `value(firingAt:)`.
  - A 175-character line is wrapped.
  - The test setup was repeated eight times. It is now an `engine(permissions:holding:)` helper, as `LockWhileNudgingTests` has.
  - A test checking both the plan and `reach` is split in two.
- **Kept, as judgement calls:**
  - The name `reach`, which is the ticket's "what can still reach you". Its doc comment says it assumes Break through Focus on.
  - `reach` and `update(permissions:)` have no app caller yet. That comes in tickets 18 and 31.

**Left alone:** the alarm-limit fallback and chain length (15), tags and My Day (16), the store (17), the adapters and reading real permission states (18–20), and every UI, including the banners and onboarding (31) and Settings' permission status (30).
