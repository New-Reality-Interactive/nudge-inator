# #433 Research: a "connection ended" marker in the CloudKit public database

Researched 2026-11-16 for shared-reminders #433 (an account change ends connections the other person never hears about).
Sources are Apple's developer documentation, WWDC and Tech Talk transcripts, the App Review Guidelines, the App Store
"App privacy details" page, and this repo. Where Apple's pages are silent, the text says so. Statements marked
(reasoning) are my inference from the cited sources, not something Apple states.

## Answer first

Option (a) is **technically workable but not free**, and it changes what the company stores.

- **It can work.** A public-database record can be created by any signed-in user, fetched by a known record name,
  and watched with a `CKQuerySubscription`. `CKSyncEngine` can't be used for it, so the app needs its own save,
  fetch, retry and subscription code.
- **The biggest cost is privacy, not code.** Public-database records are visible to the developer in the CloudKit
  Console. The app's current "Data Not Collected" answer rests on the company having no server and not being able to
  read the person's iCloud (`docs/agents/privacy-compliance.md`). A public record the company can read breaks that
  premise. The label, the privacy manifest, `docs/privacy-policy.md` and the spec's "CloudKit sharing only / no
  server of ours" wording would all need a decision. The marker is also stamped with the creator's user record ID,
  and that ID can't be removed.
- **A wrong "ended" is possible.** The marker says "this device left account A", not "account A left the
  connection". If account A is still signed in on another iPhone, or signs back in, the other person has been told
  something false and the marker can't be taken back by anyone but the new account that wrote it.
- **Security is manageable only with a secret.** A marker name derived from the connection ID alone is unguessable
  (UUID), but anyone who learns the ID can forge it. Deriving the name with an HMAC keyed by a secret stored in the
  shared zone makes forging need both devices' secret. The record can't be hidden from other signed-in users by any
  documented role, so the secret is the only real access control.
- **Several things the docs don't settle** need a CloudKit Console or TestFlight check before anyone builds this:
  the default role grants on a new type, runtime creation of a query subscription in production (one Apple page says
  it fails), subscription limits, push reliability, and what the share owner sees when a participant's device
  switches accounts. See "Open questions".

Recommendation (reasoning): the cheapest honest fix is (b), tell the person on the switching device that others
aren't told, optionally with (c), a local list of pending disconnects sent if the old account signs back in. Take
(a) only if Brian accepts the label and policy change and the multi-device false positive. Detail below.

---

## 1. Public database security roles

- Apple's schema language names three implicit roles on every record type: `_creator` ("the user that created a
  given record"), `_world` ("all users") and `_icloud` ("all authenticated users").
  Source: [Integrating a Text-Based Schema into Your Workflow](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow)
  and [WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118) (same three, same definitions).
- The recommended grants for a type used in the public database are `GRANT WRITE TO "_creator"`,
  `GRANT CREATE TO "_icloud"`, `GRANT READ TO "_world"`.
  Source: [Integrating a Text-Based Schema](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow).
- The grammar is `GRANT { READ | CREATE | WRITE } [, ...] TO role`, so each permission is granted per role per
  record type. Same source.
- **Defaults conflict between two Apple pages.** The `CKDatabase.Scope.public` page says public records "by default
  are world readable, owner writable" ([source](https://developer.apple.com/documentation/cloudkit/ckdatabase/scope/public)).
  The schema article says "Unless your schema explicitly grants permissions, a type has no security privileges
  available in the `PUBLIC` database, making the type unusable"
  ([source](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow)).
  Docs don't say which applies to a type created through the Console UI or just-in-time schema: needs a Console check.
- What can be changed: security role settings can be modified after production deployment, as can indexes
  ([WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118)). Roles are managed in the Console UI
  ([WWDC21 10117](https://developer.apple.com/videos/play/wwdc2021/10117)). The client API has no roles
  ("Roles are not present in the client API", [CKDatabase.Scope.public](https://developer.apple.com/documentation/cloudkit/ckdatabase/scope/public)).
- **Create by any signed-in user, but not readable by everyone?** The grammar allows it: grant `CREATE` to
  `_icloud` and omit `READ` from `_world`. What it breaks (reasoning): the recipient is not the creator, so
  to read the marker the recipient needs `READ` through some role. The only role every app user holds is `_icloud`
  (or `_world`). A custom role (`CREATE ROLE`) exists in the schema language, but assigning people to it is a
  Console/developer action and the client API has no roles, so it can't be per-person. So the narrowest workable
  read is `READ` to `_icloud`: any signed-in user can fetch a marker whose name they know. A failed access returns
  `CKError.permissionFailure`, which Apple says typically occurs in the public database when "you have roles for
  record types" ([source](https://developer.apple.com/documentation/cloudkit/ckerror/permissionfailure)).
- Docs don't say whether `WRITE` implies `READ` for `_creator`: needs a Console check.

## 2. Fetching a public record by ID

- Fetching by ID is a documented, direct operation: "Use a record ID to fetch the corresponding `CKRecord` object
  from a database quickly" via `CKFetchRecordsOperation` or `fetch(withRecordID:)`
  ([CKRecord.ID](https://developer.apple.com/documentation/cloudkit/ckrecord/id)). `CKDatabase.records(for:desiredKeys:)`
  (iOS 15+) fetches many IDs in one call and returns a per-ID `Result`
  ([source](https://developer.apple.com/documentation/cloudkit/ckdatabase/records(for:desiredkeys:))).
  A missing record is `CKError.unknownItem`, "the specified record doesn't exist"
  ([source](https://developer.apple.com/documentation/cloudkit/ckerror/unknownitem)).
- **Index needed?** None of the fetch pages mention an index. Docs don't say outright that a fetch by ID needs no
  index; the index requirement is documented only for searching (below). Treat "no index" as likely but confirm in
  production.
- **Queries do need an index.** To search records of a type "you must first add a queryable index for that record
  type's `recordName`"; otherwise the error is `Field recordName is not marked queryable`
  ([Handling an iCloud Container's Data](https://developer.apple.com/documentation/cloudkit/handling-an-icloud-container-s-data),
  [Inspecting and Editing a Schema](https://developer.apple.com/documentation/cloudkit/inspecting-and-editing-an-icloud-container-s-schema)).
- **Enumeration.** `TRUEPREDICATE` "matches every record" of a type, paged with a cursor
  ([CKQuery](https://developer.apple.com/documentation/cloudkit/ckquery)). With no queryable index on the marker type
  that query is refused, so (reasoning) enumeration is blocked as long as the type has no queryable indexes. A
  subscription or a field the app wants to filter on would likely need a queryable field index (see 3), and then
  any reader could run queries on it. Docs don't say what a query on one queryable field can enumerate: Console check.
- Record names: ASCII, at most 255 characters, can't start with an underscore
  ([CKRecord.ID init](https://developer.apple.com/documentation/cloudkit/ckrecord/id/init(recordname:))). A
  64-character hex HMAC fits.
- "Only one record uses a specific record ID in the public database" across all users
  ([CKRecord.ID](https://developer.apple.com/documentation/cloudkit/ckrecord/id)). So a deterministic marker name is
  a first-writer-wins slot (see 11, squatting).

## 3. Subscriptions on the public database

- `CKQuerySubscription`: "Only public and private databases support query subscriptions"
  ([CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription)).
- `CKDatabaseSubscription`: "Only private and shared databases support database subscriptions. If you attempt to
  save a database subscription in the public database, CloudKit returns an error"
  ([CKDatabaseSubscription](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription)).
  `CKRecordZoneSubscription` wasn't retrieved; docs I read don't cover it for public. Public has only the default
  zone in practice (reasoning), so a zone subscription adds nothing.
- Scope: a query subscription is "scope[d] ... to an individual record type" with a predicate, optionally to a zone
  ([CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription)).
- **Predicate fields.** The page points to `CKQuery`'s rules for the predicate
  ([CKQuery](https://developer.apple.com/documentation/cloudkit/ckquery)), which allow `IN` over a literal list
  (`favoriteColor IN { 'red', 'green' }`) on fields. Whether the fields must be indexed, whether `recordName` can be
  used, the maximum list size, and the maximum number of subscriptions per user: **docs don't say.** Console or
  device check.
- **Creating a subscription in production.** The `CKSubscription` page says: "Create subscriptions in the
  development environment first and then promote them to production. Attempting to create a subscription directly
  in the production environment results in an error"
  ([CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription)). That reads as if an app
  can't create a subscription at runtime in production, yet `CKSyncEngine` creates its database subscription itself
  ([CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)) and the
  `CKQuerySubscription` page tells apps to "create any subscriptions on your app's first launch". The pages
  contradict each other, so a TestFlight check is needed before design depends on this.
- **Silent push.** Set only `shouldSendContentAvailable = true` for background delivery; any other property makes
  it a visible, high-priority notification that needs permission. Silent push needs the Background Modes
  "Remote notifications" option
  ([CKQueryNotification](https://developer.apple.com/documentation/cloudkit/ckquerynotification)).
- **Delivery guarantees.** There are none: "Don't rely on push notifications for changes because the system can
  coalesce them. CloudKit can omit data to keep the notification's payload size under the APNs size limit"; treat
  it as "an indication of remote changes" and then fetch
  ([CKQueryNotification](https://developer.apple.com/documentation/cloudkit/ckquerynotification)). A visible alert
  would carry a fixed subscription-time `alertBody`, so a generic "a connection ended" text, or a silent push that
  makes the app fetch and post its own local notification (reasoning). Docs I read don't give silent-push throttling
  or force-quit behaviour: device check.
- **Per user.** "A subscription applies only to the user that creates it"
  ([CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription)); "Subscriptions
  belong to the users that create them. iCloud can notify several users' devices in response to a change in the
  public database" ([Remote Records](https://developer.apple.com/documentation/cloudkit/remote-records)). Docs
  don't say what happens to a subscription on an account change. From "belongs to the user" (reasoning), the old
  account keeps its subscription server-side and the new account has none, so a person who switches accounts must
  re-create subscriptions, and the *other* person's subscription is unaffected by this person's switch.
- Design consequence (reasoning): one subscription per connection (or one with a changing `IN` list) must follow
  the person's connection list, so the app would have to modify subscriptions each time a connection is made or
  ended. A single subscription on the whole type would push every app user on every marker anywhere.
- The subscription is not an account-level liveness signal: it fires when a marker is created, and the other app
  must still fetch to confirm.

## 4. `CKSyncEngine` and the public database

- Not supported. "**Important**: Don't use `CKSyncEngine` to sync your app's public database"
  ([CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)). Its configuration takes
  "either a person's private database or their shared database"
  ([Configuration init](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/configuration/init(database:stateserialization:delegate:))).
- API for the marker: `CKDatabase.save(_:)` (the "Designing and Creating a CloudKit Database" article shows
  `database.save(record)`: [source](https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database)),
  or `CKModifyRecordsOperation`
  ([Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records)). Reading uses
  `records(for:desiredKeys:)` or `CKFetchRecordsOperation`. Subscriptions use `CKModifySubscriptionsOperation` or
  `CKDatabase.save`
  ([CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription)).
- **Retries and offline are the app's job.** `CKSyncEngine` retries `networkFailure`, `networkUnavailable`,
  `requestRateLimited`, `serviceUnavailable`, `zoneBusy`, `notAuthenticated` and `accountTemporarilyUnavailable`
  for its own engines
  ([CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)). A public-database write
  gets none of that. The app would need a persisted outbox of markers to send, backoff using
  `CKErrorRetryAfterKey` on `serviceUnavailable` / `requestRateLimited`
  ([CKError.retryAfterSeconds](https://developer.apple.com/documentation/cloudkit/ckerror/retryafterseconds)), and
  its own trigger to try again. Whether `CKOperation` long-lived operations would help: not researched.
- Saving to the public database "requires an active iCloud account to identify the owner of those records"
  ([CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)). After a switch the new account
  is signed in, so the write is allowed; with no account it isn't.
- **Timing in this repo (reasoning from the code).** `SharingModel.record(_ id:)` in
  `App/Sharing/AccountChange.swift` sees the old connections (`kept.connections`) just before it replaces the store
  with the new account's. The marker list would have to be captured there and kept in a store that survives the wipe
  until each write succeeds. `CKSyncEngine` itself "resets its internal state" on account change and may deliver
  one event for several switches
  ([AccountChange](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange)), so
  the app only learns "old ID, new ID", never each hop. Nothing is written if the app isn't opened after the
  switch.

## 5. Who can modify, delete or read a marker

- Under the recommended grants only `_creator` has `WRITE`, so a non-creator can't overwrite or delete it. This is
  the role design Apple recommends
  ([schema article](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow));
  the `publicCloudDatabase` page says "users have write access to the records ... they create"
  ([source](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase)). I didn't find
  Apple text on exactly what a `permissionFailure` on overwrite looks like: Console check.
- The developer can modify and delete public records in the Console, in development and production
  ([Handling an iCloud Container's Data](https://developer.apple.com/documentation/cloudkit/handling-an-icloud-container-s-data)).
- Anyone with `READ` who knows the record name can fetch it. With `READ` to `_world` that includes a device with no
  iCloud account: "When there isn't an iCloud account, your app can fetch records from and query the public
  database, but it can't save changes"
  ([CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer)).
- **Creator exposure.** Every record carries `creatorUserRecordID` and `lastModifiedUserRecordID`, "the ID of the
  user who creates the record", resolving to that user's record: "Every user of the app has a unique user record
  that is empty by default"
  ([creatorUserRecordID](https://developer.apple.com/documentation/cloudkit/ckrecord/creatoruserrecordid),
  [lastModifiedUserRecordID](https://developer.apple.com/documentation/cloudkit/ckrecord/lastmodifieduserrecordid)).
  The schema lists `___createdBy` and `___modifiedBy` as implicit, non-removable fields
  ([schema article](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow)).
  Apple also warns "other users of your app can access the discoverable user record in a public database"
  ([CKFetchRecordsOperation](https://developer.apple.com/documentation/cloudkit/ckfetchrecordsoperation)).
  Here the creator is the **new** account B, not the old account A.
- **Opaque or resolvable?** Docs I read don't say whether the user record ID is scoped to the container (the same
  across apps) or what it looks like: device check; the repo already reads this ID as the `AppleAccountID`
  (`App/Sharing/CloudKit/CloudKitAccountReader.swift`). Resolving an ID to a name or email: the discovery API
  `discoverUserIdentity(withEmailAddress:)` is deprecated ("No longer supported") and had required that "the user
  grants the `userDiscoverability` permission for the container" and has run the app
  ([source](https://developer.apple.com/documentation/cloudkit/ckcontainer/discoveruseridentity(withemailaddress:completionhandler:))).
  I fetched only that one deprecated method; the sibling APIs weren't checked. Sharing's own identity lookups run
  through `CKShare` participants, not this path.

## 6. Quotas, costs and rate limits

- Public data counts toward the **app's** storage quota, not any user's: "That data doesn't count toward the
  storage quota of any single user"
  ([CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer),
  [publicCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase)).
  When the app's container is out of storage, `quotaExceeded` says "Individual users can't do anything about this";
  the developer manages it in the Console
  ([CKError.quotaExceeded](https://developer.apple.com/documentation/cloudkit/ckerror/quotaexceeded)).
- Quota size, request-per-second limits and per-user limits: **docs don't say.** The Console's Telemetry app shows
  request rate, latency and error count
  ([WWDC21 10117](https://developer.apple.com/videos/play/wwdc2021/10117)), so it is where to watch them.
- Throttling: `requestRateLimited` and `serviceUnavailable` carry a retry-after value in `CKErrorRetryAfterKey`;
  "use the value ... as the number of seconds to wait before retrying"
  ([CKError.requestRateLimited](https://developer.apple.com/documentation/cloudkit/ckerror/requestratelimited),
  [retryAfterSeconds](https://developer.apple.com/documentation/cloudkit/ckerror/retryafterseconds)).
- Request size limits (CloudKit Web Services, archived 2016): 200 operations per request, 200 records per
  response, 1 MB per record
  ([Data Size Limits](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/PropertyMetrics.html)).
  A marker is tens of bytes; the limits don't matter at this size.
- Cost (reasoning): the number of requests is what grows. Polling N connection markers on each fetch is N record
  lookups per person per fetch against the app's container (one `records(for:)` call).

## 7. Schema deployment

- Yes, deployment is required. "Apps in the App Store can access only the production environment. Before you
  publish your app, you must deploy the development schema to the production environment"
  ([Deploying an iCloud Container's Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)).
  Apps from TestFlight too: without deployment "apps that work in the production environment, like the ones people
  download from the App Store or TestFlight, can't communicate with the CloudKit server"
  ([Sharing Core Data objects sample](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)).
  Just-in-time schema creation isn't available in production there ("CloudKit doesn't have that capability").
- Additive only: "once record types have been promoted to the production environment ... they can't be deleted or
  renamed, and custom fields ... cannot be deleted or renamed, either"; indexes and security role settings can
  still be changed
  ([WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118),
  [Designing and Creating a CloudKit Database](https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database)).
  A marker type, once shipped, stays in the production schema for good.
- Older app versions: Apple's stated purpose of the additive rule is that "the CloudKit server always understands
  record types and fields, which older versions of your app might still be using"
  ([WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118)). A version that doesn't know the type
  never reads or writes it, so it keeps working, but it also never sees a marker: a person on an old version
  keeps seeing Connected (reasoning). The feature only helps when both people are on a build that looks for markers.
- The schema is shared across databases: "every database within your app's container shares the same schema"
  ([Designing and Creating a CloudKit Database](https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database)).
  Storing a per-zone secret for the HMAC (section 11) adds a record type or field to the private/shared schema too.
- Deployment is a Console step by someone with production-edit rights on the team
  ([Deploying](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)). The
  Console shows a diff before deploying, since "production changes cannot be reversed"
  ([WWDC21 10117](https://developer.apple.com/videos/play/wwdc2021/10117)).

## 8. Record lifetime and cleanup

- Who deletes: the creator (account B) could delete its own marker, but nothing in the flow tells it to. The other
  person can't under the recommended roles. The developer can in the Console
  ([Handling an iCloud Container's Data](https://developer.apple.com/documentation/cloudkit/handling-an-icloud-container-s-data));
  Apple adds "Don't use the CloudKit Database app as a general data editor".
- TTL: **docs I found don't describe any expiry mechanism** for public records. Cleanup would be a developer chore
  (Console or `cktool`, which can create and query public records with a user token:
  [WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118); whether it deletes: not verified).
- Stale markers: each ended connection leaves one record forever unless removed. Markers are tiny (section 6), so
  the cost is bookkeeping and the privacy retention story (section 9), not storage. The receiving app can ignore a
  marker older than a chosen age, and a timestamp field would allow that (reasoning).
- A connection ID is random per connection, so a name is never reused for a new connection; "only one record uses a
  specific record ID in the public database"
  ([CKRecord.ID](https://developer.apple.com/documentation/cloudkit/ckrecord/id)).

## 9. Privacy and App Review

- **"Collect"** means "transmitting data off the device in a way that allows you and/or your third-party partners
  to access it for a period longer than what is necessary to service the transmitted request in real time". Even
  data collected only for app functionality "still needs to be declared"
  ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).
- Apple's frameworks: "You are not responsible for disclosing data collected by Apple" (same page, CloudKit named).
  The repo's current reasoning is that private and shared database data isn't ours to read
  (`docs/agents/privacy-compliance.md`). **The public database is different:** its "contents are visible in the
  developer portal" and visible "to the application developer via the Developer Portal"
  ([CKDatabase.Scope.public](https://developer.apple.com/documentation/cloudkit/ckdatabase/scope/public),
  [publicCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase)). So
  the company can read the marker and its creator ID, which meets the "collect" definition (reasoning).
- Apple does not rule on this exact case. The nearest data-type rows are "User ID" ("account ID, assigned user ID
  ... or other user- or account-level ID") and "Other Data Types" (same page). The creator ID ties the record to an
  account, so "linked to the user" is the cautious answer: data is linked unless direct identifiers are stripped
  before collection, and `___createdBy` can't be stripped. Purpose would be App Functionality. Not used for
  tracking. The optional-disclosure exemption doesn't fit: it needs data the user enters and affirms each time.
- Consequences (reasoning): the label changes from Data Not Collected; `PrivacyInfo.xcprivacy` needs a
  collected-data entry (it is empty now, per `docs/agents/privacy-compliance.md`); the update goes through App
  Store Connect, which Apple says you can change without an app update (same page).
- **Review Guidelines 5.1.1(i)**: the privacy policy must "identify what data ... the app/service collects, how ...,
  and all uses", and "explain its data retention/deletion policies and describe how a user can revoke consent
  and/or request deletion". 5.1.1(iii) data minimization: "only collect and use data that is required to
  accomplish the relevant task"
  ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). An opaque, one-purpose marker
  is easy to defend under (iii); the retention and deletion text is what's missing, since markers outlive the
  connection and the person's own Delete All Data can't remove one written by another account.
- GDPR angle: Apple's Tech Talk says that for the public database "you'll need to review the data that you're
  storing related to a given user and determine which data is appropriate to delete"
  ([GDPR & CloudKit](https://developer.apple.com/videos/play/tech-talks/703)). A marker whose creator is account B
  is data "related to" B.
- `docs/privacy-policy.md` statements that would no longer hold: "Nudge-inator collects no data about you";
  "New Reality Interactive can't read them" (true of the reminders, not of markers); "The app asks iCloud nothing
  until you open Connections or accept an invite" (a write at account-switch time would be a request before either)
  and the short version's bullets. Also the TestFlight "developer receives" wording is unaffected.
- The spec's "CloudKit sharing only, no server of the company's": a public database is CloudKit, but it is a store the
  company owns and can read. Whether it's still "no server of ours" is a spec decision for Brian.
  (The spec's text was not re-read here; the wording comes from the brief.)

## 10. Alternatives inside sharing

- What the owner sees when a participant's device switches accounts: **docs don't say.** `CKShare.Participant`
  documents `acceptanceStatus` values `pending`, `accepted`, `removed`, `unknown`, and says records "remain
  accessible for as long as the participant's status is `accepted`"; the participants a person sees are those "the
  current user has permissions to see"
  ([Participant](https://developer.apple.com/documentation/cloudkit/ckshare/participant),
  [participants](https://developer.apple.com/documentation/cloudkit/ckshare/participants)). Nothing links a
  participant's device-level account change to those values. Reasoning: the share belongs to account A, which still
  exists, so the participant stays `accepted` and nothing changes for the owner. Device check, with two test
  accounts.
- The device can't act as the old account any more: `CKSyncEngine` "resets its internal state, including unsaved
  changes" on an account change and the docs say "delete any locally-stored data for the previous account"
  ([AccountChange](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange),
  [switchAccounts](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange/changetype-swift.enum/switchaccounts(previoususer:currentuser:))).
  Apple documents no pre-switch hook; the change event arrives after, once, even for several switches.
- Leaving a share is "delete the share record from their shared database"; the owner ends it by deleting the
  share or zone
  ([Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records)). Both need the signed-in
  account that owns or participates, so neither works from account B (this is the premise of #433).
- Other routes to the old account's share: none found in the docs. Only that account's own sessions
  reach it. If account A signs in again (on this phone or another device), those writes work again. That is option (c).
- One more in-sharing idea, not researched against sources: a "last seen" record each device writes into the zone,
  so the other side can show "not heard from since ..." without any ending. It adds no public data but also no
  certainty.

## 11. Security concerns

All of these are my reasoning from the sources above.

| Concern | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Spoofing by someone who learns a connection ID.** With a name derived only from the ID, anyone with `READ` and `CREATE` as `_icloud` can create the marker and end the connection for the other person. | Low. IDs are random UUIDs known to two devices and Apple; no screen shows them. | High for that connection: a false Connection Ended. | Derive the name as an HMAC of the connection ID with a per-connection secret stored in the zone (shared by both devices, encrypted field). A third party can't compute it. Add a MAC field and verify before trusting. Old connections with no secret fall back to the weaker scheme or are skipped. |
| **The other participant forges a marker for the old account.** They know the ID and the secret. | Low | Low: that person can already disconnect on their own. | None needed. |
| **Squatting / pre-creation.** Record names are unique across all users, and only the creator can write. Whoever creates a name first owns it. | Low with an unguessable name. | A squatted name blocks the real marker. | Same HMAC naming. A creation that fails because the name is taken can be retried under a second derived name (version counter in the HMAC input). |
| **Enumeration of markers.** Any reader could list them if a queryable index exists on the type. | Low if no queryable index. Higher if subscriptions force one. | Reveals the count and timing of ended connections, not who. | Leave `recordName` unindexed. If a field index is needed for subscriptions, put only an opaque value in it, and check in the Console what a query can return. Prefer `READ` for `_icloud` over `_world`. |
| **Replay of an old marker.** | Low | Low: ended is final, and IDs aren't reused. Real risk is the false positive below. | Include a timestamp and ignore markers older than the connection's creation. |
| **Wrong ending: old account A still active elsewhere, or A returns.** The marker says the device left, not the account. The other person's app ends a live connection and A can't undo B's marker. | **Medium** (second iPhone, shared family device, testers swapping accounts) | High: connection lost on one side, still live on the other, and no way to retract. | Don't treat the marker as the connection's end silently; show "may have ended" and let the person confirm, or only mark when the old account is known to have no other device (not knowable from docs). The retraction needs the creator (B), which isn't present. |
| **Denial of service / spam writes.** Any signed-in user of the app can create unlimited marker records. Records count toward the app's quota; throttling returns `requestRateLimited`. | Low (needs a modified client or API-token access) | Medium: quota fill-up or throttling of the whole container affects every sharing user. | Watch Telemetry; tiny records; the developer can bulk-delete in the Console. Docs don't give any per-user cap. Rate-limit client writes. |
| **Leakage.** The creator user record ID and times are readable with the marker. The company can see them in the Console. | Certain, by design | Low to medium: links account B to "had a connection that ended" and its timing. | HMAC naming reveals nothing about the connection; keep fields to a type and timestamp; document it in the policy and label (section 9). |
| **Receiving-side trust.** An attacker with the name pattern but not the secret can't pass the check; one who has the secret can. | Low | See above. | Verify the MAC against the secret before showing anything. |

## 12. Pros and cons of option (a), compared with (b) and (c)

**(a) Public-database marker**
- Pros: the other person is told without the old account ever signing in again; a push can reach them without
  opening the app; one small record per ended connection.
- Cons: the privacy label, manifest, policy and the spec's "no server of ours" wording change; public data is
  readable by the company and carries the writer's account ID; a new production schema and a Console deploy step;
  the app needs its own retry and an outbox that survives the wipe and a persistent trigger; needs a second app
  version on the other side to be of any use; "device left" is mistaken for "account left"; markers can't be
  retracted or expire; subscriptions must follow the connection list; "No iCloud until asked" is bent because the
  switch triggers a write; an unresolved doc conflict on creating a subscription at runtime in production.

**(b) Tell the person who switched** (the Apple Account Changed note says the other people aren't told)
- Pros: no new data, no schema, no label change; honest and quick; matches the delete-local-data guidance.
- Cons: the other person still sees Connected with no way to know; relies on the switcher to tell them.

**(c) Send the disconnects if the old account signs back in**
- Pros: no new CloudKit surface; the disconnect then works as designed from the right account.
- Cons: may never happen; needs the app to keep each old account's connection IDs (and the disconnects pending)
  locally past the point Apple says to delete local data for the previous account; the old account's zones still
  exist on the server meanwhile.
- Pairs with (b): (b) tells the person, (c) cleans up if they come back.

Reasoned pick: (b), plus (c) if the keep-IDs-locally question is acceptable, until there is a product reason to
carry the label and policy change.

## Open questions (Console or device checks)

1. **Default grants.** In the Console, what grants does a new record type have in Development, and does it keep
   them when deployed to Production? Does `CREATE` to `_icloud`, `READ` to `_icloud` (no `_world`) and `WRITE` to
   `_creator` work, and can a non-creator signed-in user fetch the marker? Does `WRITE` imply `READ` for `_creator`?
2. **Fetch by ID in production.** Does `records(for:)` on a missing marker return `unknownItem` per ID with no
   index at all on the type? Does a `TRUEPREDICATE` query fail with no queryable `recordName` index?
3. **Query subscription in production.** Can a TestFlight/App Store build create a `CKQuerySubscription`
   at runtime (the `CKSubscription` page says it errors)? Which predicate fields need indexes? Is `IN` over a list
   allowed, how long may the list be, and how many subscriptions can one person have?
4. **Push behaviour.** Latency and reliability of the silent push to a terminated app; behaviour after a force-quit
   and in Low Power Mode; what the visible alert can say.
5. **Owner's view of the share.** On a two-account setup, switch a participant's device to another account and look
   at the owner's `CKShare.participants` and `acceptanceStatus`, and what the participant's old account still sees.
6. **A returning or second device.** Switch to account B, then back to A: does the app on A's other device still
   work, and what happens to the zones. This decides how often the false positive occurs.
7. **Creator ID.** What does the other person's fetch show for `creatorUserRecordID`; is it the same value across
   this team's apps?
8. **Limits.** Container quota and any per-user or per-second public-database limit shown in the Console; Telemetry
   after a burst of marker writes.
9. **Account-switch write.** After the switch, does the first public-database save succeed before the app has
   re-read the account, and how does the outbox behave offline?
10. **Owner's decisions (not research).** Is a public record the company can read acceptable for "no server of
    ours"? Is a Connection Ended that might be false acceptable, or should it say "may have ended"?

## Sources

- CloudKit: [CKDatabase.Scope.public](https://developer.apple.com/documentation/cloudkit/ckdatabase/scope/public),
  [CKContainer](https://developer.apple.com/documentation/cloudkit/ckcontainer),
  [publicCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase),
  [Integrating a Text-Based Schema](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow),
  [Deploying a Schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema),
  [Designing and Creating a CloudKit Database](https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database),
  [Inspecting and Editing a Schema](https://developer.apple.com/documentation/cloudkit/inspecting-and-editing-an-icloud-container-s-schema),
  [Handling a Container's Data](https://developer.apple.com/documentation/cloudkit/handling-an-icloud-container-s-data),
  [CKQuery](https://developer.apple.com/documentation/cloudkit/ckquery),
  [CKSubscription](https://developer.apple.com/documentation/cloudkit/cksubscription),
  [CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription),
  [CKDatabaseSubscription](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription),
  [CKQueryNotification](https://developer.apple.com/documentation/cloudkit/ckquerynotification),
  [Remote Records](https://developer.apple.com/documentation/cloudkit/remote-records),
  [Shared Records](https://developer.apple.com/documentation/cloudkit/shared-records),
  [CKShare.Participant](https://developer.apple.com/documentation/cloudkit/ckshare/participant),
  [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9),
  [AccountChange](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange),
  [CKRecord.ID](https://developer.apple.com/documentation/cloudkit/ckrecord/id),
  [CKError.permissionFailure](https://developer.apple.com/documentation/cloudkit/ckerror/permissionfailure),
  [requestRateLimited](https://developer.apple.com/documentation/cloudkit/ckerror/requestratelimited),
  [quotaExceeded](https://developer.apple.com/documentation/cloudkit/ckerror/quotaexceeded).
- WWDC and Tech Talks: [WWDC21 10117](https://developer.apple.com/videos/play/wwdc2021/10117),
  [WWDC21 10118](https://developer.apple.com/videos/play/wwdc2021/10118),
  [WWDC23 10188](https://developer.apple.com/videos/play/wwdc2023/10188),
  [GDPR & CloudKit](https://developer.apple.com/videos/play/tech-talks/703),
  [Get the most out of CloudKit Sharing](https://developer.apple.com/videos/play/tech-talks/10874).
- App Store: [App privacy details](https://developer.apple.com/app-store/app-privacy-details/),
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- Repo: `App/Sharing/AccountChange.swift`, `App/Sharing/CloudKit/CloudKitSync.swift`,
  `App/Sharing/CloudKit/CloudKitAccountReader.swift`, `docs/agents/privacy-compliance.md`, `docs/privacy-policy.md`.
  The app uses no public-database API today (searched `App/Sharing/CloudKit`).
