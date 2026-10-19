Status: resolved

# Keep a Done chosen before the first unlock

## What to build

After a restart, the store is unreadable until the person first unlocks the phone (data protection, ticket 21). A nudge can still arrive then, and choosing **Done** on it from the Lock Screen launches the app. Today that Done is lost and the occurrence keeps nudging (ticket 21, device check 2).

The user decided (2026-10-17) to keep it. While the store can't be opened, the app records the Done in a small file that is readable before the first unlock, and stops the nudging. Once protected data is available, it merges the Done into the store and deletes the file.

**What Apple's docs confirm** (apple-rag):
- [Encrypting Your App's Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files): the default protection keeps a file "inaccessible until the first time the user unlocks the device", and one protection level is "always accessible".
- The app delegate's `applicationProtectedDataDidBecomeAvailable(_:)`, and [`protectedDataDidBecomeAvailableNotification`](https://developer.apple.com/documentation/uikit/uiapplication/protecteddatadidbecomeavailablenotification), say when protected files can be read again.
- Precedent, not advice to apps: HealthKit's own [`errorDatabaseInaccessible`](https://developer.apple.com/documentation/healthkit/hkerror/code/errordatabaseinaccessible) says data saved while the device is locked "is saved into a temporary file, which is merged with HealthKit's data when the user unlocks their device". Ticket 21's earlier "Apple suggests saving such changes temporarily" had no other source, and is dropped.

**Questions to settle before coding:**
- **What the file holds.** It needs only the reminder ID and the occurrence's due time. It is written with no protection, so it must hold nothing personal: no titles, notes or tags.
- **Whether the adapters can act before the first unlock.** Removing the occurrence's pending notifications and cancelling its alarms would stop the nudging, but the docs don't say either works then. This is a device check.
- **What the model knows before the store opens.** It has no reminders yet. The Done may need to be applied to the plan through the adapters alone, by the identifiers derived from the occurrence (ticket 18), and to the engine only after the store loads.
- **Several Dones**, and a Done for an occurrence that is no longer the latest by the time it's merged. The engine already ignores a stale Done (ticket 18).

## Acceptance criteria

- [x] A Done that arrives while the store can't be opened is written to a file readable before the first unlock, holding only the reminder ID, the occurrence's due time and when Done was chosen (unit test over a store opener that fails, then succeeds).
- [x] That occurrence stops nudging before the first unlock: its pending notifications and alarms are removed (fake adapters).
- [x] When protected data becomes available, or the next App opened, the queued Dones are merged into the store as Done, and the file is deleted (unit test).
- [x] A queued Done for an occurrence that is no longer the latest is dropped without error (unit test).
- [x] No title, note or tag is written to the file (assert on its contents).
- [x] Device (human): restart the phone and, before unlocking, check whether a nudge offers Done from the Lock Screen. If it does, choose it and check that the nudging stops, then unlock and check that the reminder reads Done after the next launch. If it doesn't, record that the case doesn't arise on that iOS version. Record the iOS version. *(Reworded, see Comments.)*
- [x] Device (human): on a fresh install, go through onboarding (Continue, then both prompts) and check that nothing freezes when the alarm prompt closes. This checks ticket 31's 2 s window, in which App opened leaves AlarmKit's state alone after the prompts' answer; it replaced the flag the device checks ran with. *(Moved here from ticket 31.)*
- [x] Device (human): a permission changed in iOS Settings while the app is suspended: record whether it arrives through AlarmKit's `authorizationUpdates` or App opened's re-read (`AlarmAdapter.refreshAuthorization()`), which needs a log line on each path. Ticket 30 found no update arrives. Knowledge only: the banner already clears on return either way. *(Moved here from ticket 31.)*
- [x] Device (human), or agree to drop it: the alarms-only onboarding step (`AppModel.Onboarding.alarmsOnly`), for data restored from a backup with alarms never asked, shows the alarm explanation and then the alarm prompt. It needs a backup restore, or a debug-only way to fake one; Apple's docs don't say whether iOS restores the alarm permission with a backup, and if it does the step never shows. *(Moved here from ticket 31.)*

Blocked by: 21

## Comments

**Decided before coding (Brian, 2026-10-19).**
1. **The queue file** is `queued-dones.json` in the app's own Application Support folder (not the App Group: the widget extension never reads it). It is written `[.atomic, .noFileProtection]`. Apple's `noFileProtection` says the app "can access this file at boot time". It holds each Done's reminder ID, the occurrence's due time, and when Done was chosen (`doneAt`), nothing else. A Done that can't be written is logged and its nudges are left to come, so what's pending still matches the store (the Done is lost, as before this ticket).
2. **Stopping the nudging per occurrence.** Every plan holds the reminder's next occurrence's ladder too (`Engine.plan()`), so cancelling all of a reminder's nudges would cancel tomorrow's until the app next ran. So the due time names the occurrence:
   - `SchedulePlan.Item.dueTime`.
   - Notification identifiers `nudge.<reminder>.<due ms>.<fire ms>`, with `dueTime` in `userInfo`, so a Done carries it.
   - Alarm IDs are now a version 8 UUID. Its first 8 bytes hash the reminder and due time, and its last 8 hash the fire time and title, so a title Edit still re-IDs. AlarmKit's `Alarm` has only `id`, `schedule`, `countdownDuration` and `state` (SDK 26.5 interface; apple-rag's page lists no members), so `NudgeAlarmMetadata` couldn't carry the reminder.

   The adapters' `cancelNudges(of:dueAt:)` find the occurrence's nudges by identifier alone. An alarm that is ringing is left to Stop or Open, as in a re-plan.
3. **The merge** happens in `AppModel.load()`, right after the store reads. That covers a cold launch, App opened's retry, and the new `applicationProtectedDataDidBecomeAvailable` (`protectedDataBecameAvailable()`), which retries the store.
   - The file is deleted only once the save works.
   - A Done for an occurrence that is no longer the latest is dropped (the engine's new `markDone(_:occurrenceDueAt:doneAt:)`).
   - One that gave up between the Done and the merge is recorded as Done at `doneAt`, since the person chose Done in time.
4. **The "temporarily" quote**: see What to build.
5. **The moved checks**: all three run in this ticket's device session. The alarms-only step fakes a restored backup with the launch argument `-onboardingFinished YES` (UserDefaults' argument domain), so no debug code is needed.
6. **Onboarding before the first unlock.** `UserDefaults` is shut then too, and the model read `OnboardingRecord` only at init, so a Done launch would have brought onboarding back. `load()` now reads it again once the store opens. Apple's docs don't say what `UserDefaults` returns before the first unlock; this follows from its file's protection.

**Criterion 1 reworded (Brian, 2026-10-19):** the file also holds when Done was chosen (`doneAt`), for decision 3's Done after a give-up. It is no more personal than the due time.

**Built.**
- `DoneQueue` and `QueuedDone` (App/Store).
- `AppModel.markDone(_:)` queues while the store is unreadable, then calls both adapters' `cancelNudges`.
- The queue's folder is made each time the store opens, so a Done before the first unlock writes only the file. Apple's docs don't say a folder can be made then.
- A queue file that won't decode is deleted at load and started again by the next Done. One that can't be read is kept.
- Log lines on AlarmKit's `authorizationUpdates` path and on `refreshAuthorization()`, for criterion 8 (category `AlarmAdapter`).
- `doneQueue` is a required `AppModel` parameter, so no test reads or deletes the app's own queue. Tests pass `DoneQueue.temporary`.

**Tests.**
- Engine:
  - each nudge carries its occurrence's due time;
  - a queued Done closes its occurrence when it was chosen, even after the give-up;
  - one for an earlier occurrence is dropped.
- Adapters:
  - cancelling one occurrence's nudges leaves the next occurrence's, another reminder's, the test nudge and a ringing alarm;
  - the alarm ID is pinned to a value worked out in Python.
- `DoneQueueTests`: order, delete, contents, a file that won't decode, a folder that can't be made.
- `DoneBeforeFirstUnlockTests`, through the model with a store that fails and then opens:
  - queued with `doneAt`;
  - nudges stopped for that reminder only;
  - no title, note or tag in the file;
  - merged on protected data and on App opened, with the file deleted;
  - several Dones merged;
  - a stale Done dropped without a save error;
  - a write that fails leaves the nudges;
  - a file that won't decode is deleted;
  - the folder is made;
  - onboarding is read again.

**Code review** (one full round, Standards and Spec).
- Fixed:
  - tests used the app's real queue;
  - a `for` loop over cases;
  - three unclear names;
  - an unreadable queue was deleted on any read error;
  - no test merged several Dones;
  - an untestable pause condition, which is removed.
- Left, with reasons:
  - **The duplicated `milliseconds(of:)` helper:** it is small.
  - **An occurrence-ID type:** it would ripple across the engine.
  - **Banners delivered by an earlier build carry no `dueTime`:** nothing has shipped.
  - **Merging plans the occurrence's nudges again for a moment before the merged Done removes them:** in order, within one launch.
  - **A failed save at merge keeps the file until the next cold launch:** the Done is already in memory, and the next save stores it.

**Device checks (Brian's iPhone 15, iOS 27.0.1, build 37176b1, 2026-10-19).**
- **Criterion 9, met.** Fresh install, launched with `-onboardingFinished YES`: the alarm explanation came first, with no welcome and no notification prompt, then the AlarmKit prompt (allowed).
- **Criterion 7, met.** Uninstalled, reinstalled, normal launch: welcome, Continue, notification prompt (Allow), alarm prompt (Allow). Tabs switched straight away after the alarm prompt closed, with no freeze.
- **Criterion 8, met.** Logs read through `devicectl device process launch --console` with `OS_ACTIVITY_DT_MODE=YES`. Both changes made in Settings while the app was suspended (same process throughout) arrived only through App opened's re-read: "re-read: denied, was authorized" for alarms off, "re-read: authorized, was denied" for back on. `authorizationUpdates` sent nothing for either. Its only line was the current value it yields when the app subscribes at launch.
- **Criterion 6, first attempt.** After the restart, holding "Test 32"'s nudge 1 on the Lock Screen gave a haptic and no Done action. Show Previews was "When Unlocked" (global and the app's default), which we first took to be the cause. Brian then unlocked, so that attempt tested nothing.
- **Criterion 6, rerun (Show Previews: Always for Nudge-inator).** Restarted and left locked. "Test 32" nudge 1 arrived at 6:28 PM showing its title and "Nudge 1 of 20", High. Holding it again gave only a haptic and no Done action. Tapping it asked for the passcode. "Control 32" (Gentle, Break Through Focus off) arrived at 6:33 PM, still locked. So on iOS 27.0.1 notifications arrive and show their content before the first unlock, but offer no actions. A Lock Screen Done can't reach the app then, and the queue isn't exercised on a device. Apple's docs don't say this; it is what the iPhone did.

**Criterion 6 reworded (Brian, 2026-10-19):** a Time Sensitive notification that can't be marked Done from the Lock Screen after a restart is acceptable. It matches an alarm, which can't mark a reminder Done either and needs the app. Criterion 6 now records whether the case arises, and on iOS 27.0.1 it doesn't. The queue stays as a guard in case some iOS version or setting does deliver a Done before the first unlock. The unit tests (criteria 1-5) cover it.
