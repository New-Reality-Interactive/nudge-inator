Status: ready-for-agent

# Keep a Done chosen before the first unlock

## What to build

After a restart, the store is unreadable until the person first unlocks the phone (data protection, ticket 21). A nudge can still arrive then, and choosing **Done** on it from the Lock Screen launches the app. Today that Done is lost and the occurrence keeps nudging (ticket 21, device check 2).

The user decided (2026-10-17) to keep it. While the store can't be opened, the app records the Done in a small file that is readable before the first unlock, and stops the nudging. Once protected data is available, it merges the Done into the store and deletes the file.

**What Apple's docs confirm** (apple-rag):
- [Encrypting Your App's Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files): the default protection keeps a file "inaccessible until the first time the user unlocks the device", and one protection level is "always accessible".
- The app delegate's `applicationProtectedDataDidBecomeAvailable(_:)`, and [`protectedDataDidBecomeAvailableNotification`](https://developer.apple.com/documentation/uikit/uiapplication/protecteddatadidbecomeavailablenotification), say when protected files can be read again.
- Ticket 21's note says Apple suggests saving such changes "temporarily". That wording wasn't found in these pages. Find its source or drop the quote.

**Questions to settle before coding:**
- **What the file holds.** It needs only the reminder ID and the occurrence's due time. It is written with no protection, so it must hold nothing personal: no titles, notes or tags.
- **Whether the adapters can act before the first unlock.** Removing the occurrence's pending notifications and cancelling its alarms would stop the nudging, but the docs don't say either works then. This is a device check.
- **What the model knows before the store opens.** It has no reminders yet. The Done may need to be applied to the plan through the adapters alone, by the identifiers derived from the occurrence (ticket 18), and to the engine only after the store loads.
- **Several Dones**, and a Done for an occurrence that is no longer the latest by the time it's merged. The engine already ignores a stale Done (ticket 18).

## Acceptance criteria

- [ ] A Done that arrives while the store can't be opened is written to a file readable before the first unlock, holding only the reminder ID and the occurrence's due time (unit test over a store opener that fails, then succeeds).
- [ ] That occurrence stops nudging before the first unlock: its pending notifications and alarms are removed (fake adapters).
- [ ] When protected data becomes available, or the next App opened, the queued Dones are merged into the store as Done, and the file is deleted (unit test).
- [ ] A queued Done for an occurrence that is no longer the latest is dropped without error (unit test).
- [ ] No title, note or tag is written to the file (assert on its contents).
- [ ] Device (human): restart the phone, choose Done on a nudge from the Lock Screen before unlocking, and check that the nudging stops. Then unlock, and check that the reminder reads Done after the next launch. Record the iOS version.

Blocked by: 21
