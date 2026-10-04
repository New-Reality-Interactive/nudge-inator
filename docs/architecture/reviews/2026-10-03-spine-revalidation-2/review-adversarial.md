# Adversarial review: ARCHITECTURE-SPINE.md at 8c2ce98

**Lens:** Attack the spine as an adversary. Build two units one level down that each obey every AD to the letter but still don't fit together: clashing shared-data shapes, two owners of one entity, conflicting state-mutation paths. Each pair is a hole to close with a new or tighter AD.

**Read against:** brief §3, §4 and §10; EXPERIENCE.md; .memlog.md for the reasons. Nothing under `reviews/` was read.

**Verdict:** NEEDS WORK. No critical findings. Four highs. In each one, two builds that both follow the spine's text diverge in a scenario a tester would hit early: a fresh install, a permission change or flight, the iOS default previews setting, or Cancel on the form. Every high can be closed with one sentence in an existing AD.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 4 |
| Medium | 6 |
| Low | 6 |

---

## High

### H1. No unit owns the first quiet-hours version, the first zone fact or the first capability state

- **Units:** `NudgeStore` (first migration), `NudgeCore.evaluate`, the app target's Settings view, `NudgeShell` reconciler.
- **Quoted text:**
  - AD-3: "Versioned facts carry the instant they were saved: … quiet hours, and the device time zone. The coordinator writes a zone fact when it detects a change."
  - AD-1: "It reads no clock, OS API or database; `now` and the zone facts are parameters." The default window starts "from the start of yesterday (in the latest zone fact's zone)".
  - AD-20: "`NudgeModel` evaluates only from the inputs the coordinator last published (facts, settings, the zone facts and the persisted capabilities)".
  - EXPERIENCE › Foundation › Defaults: "Quiet hours are on, from 10:00 PM to 7:00 AM".
- **Build A:** The first migration writes no settings rows, because the spine lists none. The engine reads "no quiet-hours version" as no quiet hours (`QuietHours?` is nil). The Settings view shows EXPERIENCE's default of 10 PM to 7 AM, on, because nothing is stored to show otherwise. The engine has no zone fact to fall back on, so it uses the zone the pure function was handed. Before the first reconcile, that is whatever the caller defaulted to.
- **Build B:** The first migration (or the first reconcile) writes a quiet-hours version (on, 10 PM to 7 AM) and a zone fact for `TimeZone.current`, each saved at that instant. Capability state is written before the first evaluate.
- **Why both comply:** AD-3 makes quiet hours and zones versioned facts, but no AD says who writes the first one, or what an empty history means. "Writes a zone fact when it detects a change" doesn't say that no fact counts as a change. EXPERIENCE's default is a UX statement with no architectural owner.
- **Where they diverge:** a fresh install. In Build A, a tester's 11 PM reminder nudges through quiet hours while Settings says quiet hours are on, and How It Nudges in the form shows no quiet-hours hold. Any evaluate that runs before the first zone fact exists (NudgeModel or the form's preview during onboarding) places wall times in the fallback zone. If an AD-8 materialization happens then, the instant is frozen wrong for good.
- **Close (AD-3 or AD-16):** "The first migration writes the initial settings facts, saved at the migration's instant: a quiet-hours version with EXPERIENCE's defaults and a zone fact for the current zone. Capability state starts as `alarmCapacity` unknown, `protectedAlarms` 0 and every permission false until the first reconcile. `evaluate` requires at least one zone fact and one quiet-hours version; an empty history is a programming error, not 'off'. Delete All Data keeps these (as now)."

### H2. The order of a reconcile's bookkeeping relative to `evaluate` isn't pinned

- **Units:** `NudgeShell` reconciler, and the capability builder and zone detection inside it.
- **Quoted text:**
  - AD-4: "A reconcile writes only bookkeeping: materialized occurrences, ledger rows, capability state, zone facts and pruning."
  - AD-6: "the reconcile job evaluates, then diffs …"; "Uncounted snoozes: checked before the diff".
  - AD-6, at-once: "deliveries … whose fire instant equals the instant of a write committed in this job (a command's `issuedAt`, or a zone fact's saved instant) … an occurrence an eastward zone change made due (AD-8)."
  - AD-14: on `maximumLimitReached`, the reconciler "re-evaluates and re-diffs in the same job".
  - Structural Seed sequence diagram: `evaluate(...)` → OS read → add/remove → then "ledger rows, materialized occurrences, capability state" written to the store.
- **Build A:** follows the sequence diagram. It reads persisted capabilities and zone facts, evaluates, diffs and applies. Then it writes the new capability state and any new zone fact as end-of-job bookkeeping, alongside the ledger rows. The only re-evaluate is AD-14's.
- **Build B:** first takes the OS snapshot, builds and persists `Capabilities` and writes any zone fact. Then it evaluates, adopts, diffs and applies, and writes ledger rows and materializations.
- **Why both comply:** AD-4 lists what a reconcile writes but not when in the job. AD-14 names a same-job re-evaluate for capacity only. The diagram draws Build A's order.
- **Where they diverge:**
  - *Permission change:* a tester turns alarms off and returns to the app (an `authorizationUpdates` trigger). Build A plans with the old `alarmsAvailable = true` and tries to add alarms, which fail and are logged. It then persists the new capabilities but plans no chain, so Urgent nudges have neither an alarm nor a chain until some later trigger. Brief §4 ("Urgent, with alarms not allowed: Notification chain") breaks.
  - *Flight:* AD-9 "re-plans every projection" happens one reconcile late in Build A. The at-once delivery for an occurrence an eastward change skipped is never planned. It didn't exist when Build A evaluated, and on the next reconcile the zone fact is no longer "a write committed in this job", so nudge 1 is dropped. That is exactly the loss AD-8 exists to prevent ("due at once rather than lost").
- **Close (AD-6, new first bullet):** "A reconcile runs in this order: (1) snapshot `now`, pending requests, delivered notifications and `AlarmManager.alarms`; (2) build and persist `Capabilities` and write any zone fact; (3) restore detection; (4) adopt uncounted snoozes; (5) evaluate; (6) materialize; (7) diff and apply, re-evaluating on `maximumLimitReached`; (8) ledger rows, Cleanup, pruning. The sequence diagram is redrawn to match."

### H3. `previewsHidden` has no defined mapping and no defined effect on content

- **Units:** `NudgeShell` capability builder, the notification content builder (`NudgeCore` plan or `NudgeShell` adapter), and the diff.
- **Quoted text:**
  - AD-11: "`previewsHidden`" is a canonical `Capabilities` field.
  - AD-6: a notification "changed if … its localized content (title and nudge line, as `previewsHidden` shapes them)" differs.
  - Brief §4 Privacy: "notifications show the title and a second line with the nudge count and urgency … If the person hides notification previews in iOS Settings, the Lock Screen shows only the app's name."
- **Build A:** `previewsHidden = (showPreviewsSetting == .never)`. Content is unchanged when it's true, because iOS already hides it, so it only affects a hint in Settings.
- **Build B:** `previewsHidden = (showPreviewsSetting != .always)`, so "When Unlocked" counts as hidden. When it's true, the content builder drops the title and puts generic text in the body, so that "previews hidden shapes" the content as AD-6 implies.
- **Why both comply:** the spine names the field and says it shapes content, but defines neither the mapping from `UNShowPreviewsSetting` nor the shaping.
- **Where they diverge:** "When Unlocked" is, as far as I know, iOS's default on Face ID iPhones, which is most testers. Build B sends nudges with no title even on an unlocked phone, which breaks brief §4's "notifications show the title". Every `showPreviewsSetting` change also replaces every pending notification in Build B but none in Build A.
- **Close (AD-11 or AD-19):** "`previewsHidden` is true only for `.never`. It changes no notification content: iOS applies the setting itself. Its only uses are [name them, for example a Settings hint], or remove the field." Drop "as `previewsHidden` shapes them" from AD-6, or replace it with the actual rule.

### H4. A form Save (and Resume with a new time) can be one command or several

- **Units:** the app target's form and Tags page, `NudgeCore.Command` / `accepts`, and the coordinator.
- **Quoted text:**
  - AD-4: "The command set: … creating, editing and deleting a reminder; creating, renaming and deleting a tag; …" `accepts` "returns the command's whole write set … (events, versions, tags, title and notes edits, …)". "The form's duplicate-tag check is `accepts` with the Tags convention's key".
  - EXPERIENCE › Sheet bar buttons: "Cancel … With unsaved changes, it asks to discard them." › IA: "Tags are created where they're needed, on the form's Tags page."
  - Brief §3 Edit/Completed: "Resuming one … needs a later time"; "Resume then asks for a new time."
- **Build A:** the Tags page submits `createTag` as soon as the person adds a new name, so the duplicate check runs then, through `accepts`, as AD-4 requires. Save then submits `editReminder` with tag IDs. Resume of a one-off whose time has passed submits `editReminder(newStart)`, then `resume`, as two jobs.
- **Build B:** new tags live in the draft. Save submits one `createReminder`/`editReminder` whose write set includes the new tag rows and links. Resume with a new time is one `resume(newStart)` command whose write set holds the version and the resume event.
- **Why both comply:** `createTag` and the reminder commands are both listed, and nothing says which one a form uses or that one gesture is one command. "Tags" appears in the write-set list without saying whose write set it is.
- **Where they diverge:**
  - A tester adds `#garden` on the Tags page, taps Cancel, then Discard Changes. Build A leaves an orphan `#garden` on the Tags tab ("No reminders have this tag"), contradicting "Discard". Build B leaves nothing.
  - Resume in Build A runs two jobs with two `issuedAt`s and a reconcile in between. If the second is rejected (the chosen time passed while the alert was open), the reminder is resumed with a passed time, which brief §3 forbids. Build B rejects the whole gesture.
  - The two builds also produce different Export event lists for the same history.
- **Close (AD-4):** "One user gesture is one `Command`. The form's Save is one `createReminder` or `editReminder` whose write set includes new tags and links. Tags typed on the form's Tags page aren't written until Save (the duplicate check calls `accepts` without committing). Resume of a one-off takes its new start in the same command. `createTag` exists only for [name its caller] or is dropped."

---

## Medium

### M1. The reconciler can await its own adopted snooze and deadlock the queue

- **Units:** `NudgeShell` reconciler and `Coordinator.submit`.
- **Quoted text:** AD-6: "the reconciler enqueues an ordinary `snooze` command … `accepts` judges it like any other command". AD-4: "The one command it creates is an adopted `snooze` (AD-6), which it enqueues like any other." AD-5: "`submit` is `async` and returns the command's outcome only after its job, reconcile included, has finished. Every source awaits it".
- **Build A:** the reconciler creates the snooze "like any other" source, calling `await submit(...)`. That waits for a job queued behind the reconcile that is waiting for it, and the queue stops.
- **Build B:** the reconciler yields the command to the `AsyncStream` continuation without awaiting.
- **Why both comply:** "like any other" and "every source awaits it" support Build A. "Enqueues" supports Build B.
- **Where they diverge:** the first snooze before the first unlock (a device-checklist scenario). Brief §10's open check says adoption may cover every snooze. Build A then freezes: no Done applies, and the notification delegate never calls its completion handler.
- **Close (AD-4):** "No job awaits `submit`. The reconciler appends the adopted snooze to the queue directly, and it runs after the current job."

### M2. `submit` and `NudgeQuerying` results have no defined shape for rejected, journaled or unavailable

- **Units:** `NudgeIntents` (Siri responses), the notification delegate, `NudgeCore` (`CommandSubmitting`, `NudgeQuerying`).
- **Quoted text:** AD-5: "`submit` … returns the command's outcome". AD-16: before the first unlock, "a command goes to an append-only journal"; on another open failure "the coordinator runs no jobs". EXPERIENCE › Siri: "Snooze Nudge-inator": "Snoozes the first one … if snoozes are left. Otherwise says 'No snoozes left. Only Done stops it.'"; Counts: "Nudging (including a snoozed occurrence)".
- **Build A:** the outcome is `Bool`. Siri's snooze intent maps `false` to "No snoozes left". With the store failed, `submit` enqueues and awaits a job that never runs. Before the first unlock, `NudgeQuerying` returns an empty list.
- **Build B:** the outcome is `enum { applied, rejected(reason), journaled, unavailable }`. The intent says something different for each reason. `submit` returns `.unavailable` at once when the coordinator runs no jobs.
- **Why both comply:** "the command's outcome" isn't typed, and AD-16 doesn't say what `submit` and queries do while there is no store.
- **Where they diverge:**
  - A tester says "Snooze Nudge-inator" twice. The first occurrence is now snoozed but still "nudging", so it is still first. `accepts` rejects the second snooze because a snooze already answers that nudge. Build A tells the tester "No snoozes left" when two are left.
  - Before the first unlock, "What's nudging me" answers "Nothing is nudging you" in Build A while an alarm is ringing.
  - After an open failure, Build A's delegate hangs until iOS kills it.
- **Close (AD-5):** define `CommandOutcome` in `NudgeCore` (applied, rejected with an `accepts` reason, journaled, unavailable), and a `NudgeQuerying` result that can say the store is unavailable. State that `submit` returns at once when no jobs run, and whether Siri's "first" for Snooze skips occurrences already snoozed.

### M3. How It Nudges in the form doesn't say which facts surround the draft

- **Units:** the app target's form, `NudgeCore.evaluate`, `NudgeModel`'s published inputs.
- **Quoted text:** AD-1: "How It Nudges is `evaluate` on the form's draft." Brief §7: "The 'How It Nudges' preview and what's actually scheduled come from the same rules".
- **Build A:** the published facts with the draft added as a new `ReminderConfig` version saved at `now` (or as a new reminder), so the other reminders, this reminder's events and carry-over, and the persisted capabilities all apply.
- **Build B:** only the draft (one reminder, no events), with default capabilities.
- **Why both comply:** "`evaluate` on the form's draft" doesn't name the other inputs.
- **Where they diverge:**
  - Editing a reminder that's nudging: Build B shows nudge 1 onward rather than "the nudge count carries on" (brief §3 Edit), and leaves out "↑ Starts higher".
  - With many Urgent reminders, Build B shows every alarm as "Alarm" while the real plan puts some past `alarmCapacity` ("Notification: too many alarms scheduled").
- **Close (AD-1):** "The form evaluates the coordinator's published inputs with the draft added as a version saved at `now` (or as a new reminder with a temporary UUID), and the persisted capabilities."

### M4. `evaluate`'s signature can't express AD-6's "a write in this job", so the plan's shape between Core and Shell is unpinned

- **Units:** `NudgeCore.evaluate` (plan, 63-request cut) and `NudgeShell` reconciler (plan filter).
- **Quoted text:** AD-1: `evaluate(facts, settings, capabilities, now, window)`, "the ordered desired delivery plan". AD-6: "What the plan holds: deliveries whose fire instant is after `now`. It also holds what a write in the same job made due at once … Checking for those rows is the only ledger read that decides what to schedule." AD-14: "the first 63 are kept, plus 1 keep-nudging request at the fire time of the earliest delivery left out".
- **Build A:** `evaluate` returns only deliveries after `now` (AD-6's first sentence), cut at 63. It can't know which writes belong to this job, so the Done follow-up (placed at a past `issuedAt`) is never in the plan.
- **Build B:** `evaluate` also returns every delivery placed at the instant of a fact at or before `now`, and counts them in the 63. The shell filters them by write instant and ledger row.
- **Why both comply:** AD-6 describes the plan the reconciler acts on, not what `evaluate` returns. The signature passes no write instants and no ledger.
- **Where they diverge:** in Build A the follow-up after Stop never posts, which breaks brief §4's "Stopping an alarm is confirmed". In Build B, at-once candidates take slots from future nudges, and `NudgeModel` (which has no job) sees a different plan from the reconciler.
- **Close (AD-1/AD-6):** "`evaluate` returns future deliveries (cut by AD-14) and a separate list of at-once candidates (deliveries at a fact's instant at or before `now`), which don't count toward the 63. The reconciler keeps a candidate only if its instant equals a write in this job and it has no ledger row."

### M5. When a reconcile reads `now` relative to its OS snapshot isn't pinned

- **Units:** `NudgeShell` reconciler (plan membership, `lost` marking).
- **Quoted text:** AD-6: "deliveries whose fire instant is after `now`"; the diff is "against pending requests and `AlarmManager.alarms`". AD-15: "`lost`: it vanished from the OS before its fire instant without the reconciler removing it". AD-9: a request whose instant is "at or before `now` when it's added … uses a `nil` trigger".
- **Build A:** reads `now`, then reads pending requests. A notification firing between the two reads is in the plan (fire > `now`) and missing from pending. It's re-added with a nil trigger, so it's delivered twice, and its row is marked `lost`, so History says "couldn't be sent" for a nudge that arrived.
- **Build B:** takes the snapshot, then `now`. That nudge is past and left alone.
- **Why both comply:** AD-3 says an adopted snooze "takes the reconcile's `now`" but not when that is read.
- **Where they diverge:** a reconcile running in the same few milliseconds a nudge fires. The window is narrow but recurs over a beta with many foreground reconciles, and nudges cluster on whole minutes.
- **Close (part of H2's ordering):** "`now` is read after the OS snapshot. A request missing from the snapshot whose fire instant is at or before `now` is neither re-added nor marked `lost`."

### M6. Permission state behind the banners, the Settings rows and Got It has two possible owners

- **Units:** the app target's banners and Settings rows, `NudgeShell` capability builder, `UserDefaults` flags.
- **Quoted text:** AD-20: "Views read derived state only from [`NudgeModel`]." Conventions › UI state: "Non-personal flags (onboarding done, banners acknowledged) live in `UserDefaults`." EXPERIENCE › Permission banner: "Got It is remembered for each permission until that permission changes; any change clears it".
- **Build A:** banners read the persisted `Capabilities` through `NudgeModel`. The reconciler clears a Got It flag when it persists a changed field.
- **Build B:** the app target reads `UNUserNotificationCenter` settings and AlarmKit authorization itself on foreground (permission state isn't "derived state"). It clears Got It by diffing against the previous in-memory reading, which is nil on a cold launch, and treats nil as "changed".
- **Why both comply:** permission state isn't named as derived state, `notificationsAllowed` has no defined mapping from `UNNotificationSettings`, and no unit owns clearing the acknowledged flags.
- **Where they diverge:**
  - In Build B, a collapsed banner comes back in full after every relaunch.
  - The banner can say "Notifications are off" while the engine (with a different `notificationsAllowed` mapping) plans notifications, or the other way round, contradicting the cards' Via labels.
- **Close (AD-11 + Conventions › UI state):** "Banners, Settings rows and the Test Nudge disabled state read only the persisted `Capabilities`. `notificationsAllowed` is `authorizationStatus ∈ {authorized, provisional}` [or the owner's choice]. The reconciler clears a permission's acknowledged flag when it persists a change to that field."

---

## Low

### L1. `skip-by-edit` can be a stored event or derived from the version

- **Quoted text:** AD-3 lists `skip-by-edit` among "append-only rows". AD-4 rejects a command if "its occurrence already has a committed event other than a Clear … with a later `issuedAt`". The memlog (entry 139) says "Versions don't count: an earlier Done arriving after an edit still applies".
- **Build A:** `editReminder`'s write set includes a `skip-by-edit` event when the edit closes the occurrence.
- **Build B:** the engine derives the skip from the version alone and writes no event.
- **Divergence:** Export's event lists differ. In Build A, a backdated Done that arrives after a skipping edit is rejected; in Build B it's accepted, which is what the memlog intends. A backdated command after an edit needs a stamp-then-enqueue race, so this is unlikely.
- **Close:** say whether `accepts` writes `skip-by-edit`, and whether it counts in the later-event rejection.

### L2. The follow-up's `n` has two sources

- **Quoted text:** AD-7: "`followup/<key>/<n>`, where `n` is the stopped alarm's nudge index". AD-3: the stored nudge index is "for History only; the engine derives which nudge an event answers from `issuedAt`". AD-16: before the first unlock, `submit` posts the follow-up "under its planned ID" with no engine available, so `n` comes from the alarm metadata.
- **Divergence:** if a later alarm of the same occurrence was counted before the Stop, the engine derives a different `n` from the one `submit` posted. Replay writes the row under one ID and the engine plans the other, so a second follow-up posts at once. This needs overlapping alarms before the first unlock.
- **Close:** "The follow-up's `n` is the `done` event's stored nudge index (from the alarm's metadata)". Make that the one exception to "for History only".

### L3. No owner is named for the restore marker file

- **Quoted text:** AD-15: "a marker file beside the database … then the marker is written."
- **Divergence:** `NudgeStore` writes it on open (Build A), or the reconciler writes it after marking rows lost (Build B). If the process is killed between open and the first reconcile, Build A never marks the restored rows `lost`, and History claims they were sent.
- **Close:** "The reconciler writes the marker, after restore handling commits."

### L4. History's nudge lines have no named home, so History and Export can implement the join twice

- **Quoted text:** AD-15: History's nudge lines … "Export uses the same lines." The Core row lists "export encoding" but no nudge-line function, and the app target may import `NudgeStore`.
- **Divergence:** History in the app target joins the ledger itself while Export does it in Core. "Earliest row" can be read by fire instant or by row sequence. Edge cases only.
- **Close:** add a `NudgeCore` function for nudge lines that both History and Export call, with "earliest" meaning earliest fire instant, then row sequence.

### L5. A journal entry appended during replay waits for the next launch

- **Quoted text:** AD-16: "It first renames the journal, so an entry appended meanwhile goes to a fresh file and is replayed next time."
- **Divergence:** Build A replays the fresh file at once as a second replay job. Build B waits for the next first open, which in the same process never comes, so a Done stays unapplied for days. The race window is milliseconds.
- **Close:** "After replay, if a journal file exists, replay runs again before any other job."

### L6. "Tries one more" alarm doesn't say how `alarmCapacity` changes on success

- **Quoted text:** AD-14: "a later reconcile tries one more only when that's more than `alarmCapacity`."
- **Divergence:** on success, Build A adds 1 to `alarmCapacity`. Build B resets it to unknown and relearns from the next `maximumLimitReached`. Both reach the right set; Build B churns more.
- **Close:** "On success, `alarmCapacity` goes up by 1."

---

## What held

I tried these attacks and the spine's text closed each one:

- **Two writers.** AD-4's single serial queue, package-access writes and the coordinator as the only user of the write API, together with AD-5's app-process-only rule and the absence of an App Group container, leave no second write path.
- **Two derivations of state.** AD-1 ("`evaluate` is the only fold"), AD-2 (no stored status), and the Evaluation's per-reminder fields (status, next due, carry-over, `notDoneUntil`) remove the places where the UI, Cleanup, the follow-up plan or Siri would each derive "Not Done applies" or a status.
- **IDs.** AD-7's single `DeliveryID` owner, nudge indexes taken from plan items and never parsed from IDs, lifetime-unique IDs, and AlarmKit IDs as a UUIDv5 of the delivery ID plus a configuration hash leave no way for two units to name one delivery differently, or for an alarm to keep a stale configuration.
- **Ordering of backdated facts.** Events ordered by `issuedAt` then commit sequence everywhere, and `accepts`' later-event rejection (ignoring Clears, counting pause and resume), stop adopted snoozes and replay from re-folding history. The one-snooze-per-counted-nudge rule, which needs no ledger, stops double counting.
- **Who answers an alarm.** The rule is based on events and holds for every source, since commands carry no delivery ID, and alarms past their fire instant are protected. This closes the earlier Clear-silences-alarm and Done-during-snooze pairs.
- **The ledger.** Immutable columns, replacement by cancel and insert, channel-none rows matched against the ledger rather than the OS, and History's derived "couldn't be sent" copy leave no second owner of delivery state.
- **Time.** `issuedAt` is stamped once by `submit` from the injected clock. Instants are UTC; the calendar zone comes from zone facts per instant; durations are integer seconds. Every trigger is absolute. No two units can disagree on a nudge's instant.
- **Before the first unlock.** The journal holds a fixed set of fields, keeps titles out (passed as arguments), replays as one job first, writes the follow-up's ledger row, and AD-6 owns the follow-up afterwards. Each earlier split here is closed (L2 and L5 are residual edges).
- **Packaging.** The widget has no store or shell, `NudgeLiveActivity` holds the shared metadata type, and the first spike is stated once. No second process can write, and no two copies of the alarm metadata can drift.
- **Tags and search.** One case-folded key column with no `NOCASE`, uniqueness checked in `accepts`, one Foundation matcher for search, tag search and Siri, and filters that drop missing IDs on read leave no clash between the form, Rename Tag and the filters.
