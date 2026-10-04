# Rubric review: ARCHITECTURE-SPINE.md (revalidation)

- **Target:** `docs/architecture/ARCHITECTURE-SPINE.md` at `acb3a01` (branch `architecture/spine-update`)
- **Read against:** brief §3, §4, §6, §10, §11; addendum; EXPERIENCE.md; `.memlog.md` (update-run entries for reasons)
- **Mode:** report only. Earlier review folders were not read.
- **Date:** 2026-10-03

## Verdict

The spine is in good shape. Its paradigm, write path, identity scheme, ledger and OS split are specific and enforceable, and the Map covers every brief §11 question. Two high findings remain. Neither is a contradiction; both are rules that leave a central contract open. (1) The rules don't say which occurrences belong to `evaluate`'s window. (2) They don't say whether a command source waits for its job to finish before it hands control back to iOS. Either gap, read the wrong way, lets nudges continue after Done or stop while the occurrence is still open.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 2 |
| Medium | 5 |
| Low | 9 |

---

## High

### H1. "Every occurrence in the window" doesn't say whether an occurrence due before the window still counts

- **Location:** AD-1 Rule: "`evaluate(facts, settings, capabilities, now, window) -> Evaluation`, holding the derived state of every occurrence in the window … The live model and the reconciler pass the default window, from the start of yesterday … through 8 days after `now`, which covers My Day, Coming Up, Last 24 Hours and Assistive Access". AD-14 › What `evaluate` reads: "each reminder's latest occurrence before the window with the facts since then (for carry-over and Not Done)".
- **Problem:** "In the window" can mean *due* in the window or *active* in the window. The coverage list leaves out Now's Nudging section, the one surface that must show every open occurrence whatever its due time. AD-14 says the engine *reads* the latest occurrence before the window. It doesn't say that occurrence's nudges go into the delivery plan, or that its state goes into `Evaluation`.
- **Concrete failure:** these are realistic ways for an open occurrence to have a due instant before the start of yesterday:
  - **Not Done days later.** A weekly reminder is done by an alarm's Stop on Monday. Not Done applies until next Monday (brief §3), and Reminder details offers it. On Thursday the person taps Not Done, and `accepts` takes it, since it judges against all committed facts. The reopened occurrence is due Monday, before the window. An engine that reads "in the window" as "due in the window" plans no nudge for it, so the occurrence reads as nudging but nothing arrives. That breaks brief §1 ("keeps nudging until you tap Done") and §3's "The next nudge comes one interval after reopening".
  - **A long Gentle run.** A Gentle occurrence with a 100-nudge, 7-day limit takes about 35 hours of nudges, and quiet hours and snoozes stretch that further. One due at 9 PM Monday is still open on Wednesday, so the same split decides whether it keeps nudging and whether it has a Now card.
  - The reconciler and `NudgeModel` both use this window. If they read it the same wrong way, the bug is consistent and silent.
- **Suggested fix:** in AD-1, define window membership: "An occurrence is in the window if its due instant is in it, *or* it is open or Not-Done-eligible at any instant in it. The delivery plan and Now's Nudging section always include every open occurrence." Add Now › Nudging to the coverage list. Add an engine test: Not Done on a weekly occurrence 3 days later produces a planned next nudge.

### H2. Nothing says a command source waits for its job (and the reconcile) before handing control back to iOS

- **Location:** AD-4 › One queue ("Each job runs to completion …"); AD-5 › How intents reach the coordinator ("only through `CommandSubmitting` …"); AD-12 › Intents only submit commands. The only hint is the Structural Seed sequence diagram's `Q-->>Src: done (next job starts)`.
- **Problem:** the spine fixes what a job does, but not what the *submitter* does. It doesn't say whether `CommandSubmitting.submit` returns once the command is enqueued or once the job, including its reconcile, has finished. It also doesn't say that an intent's `perform` and the notification delegate's `didReceive` completion handler must wait for it. iOS may suspend a background-launched app as soon as `perform` returns or the completion handler is called. These are separate units (the delegate in NudgeShell, the alarm and Live Activity intents in NudgeLiveActivity, the Siri intents in NudgeIntents), so each will pick its own answer.
- **Concrete failure:** with the phone locked and the app suspended, the person taps Done on a High notification. The delegate submits fire-and-forget and calls the completion handler right away, and iOS suspends the app before the job's reconcile removes the occurrence's pending notifications and alarms. The next nudge, or an Urgent alarm, arrives after Done. That breaks brief §8 ("no notification or alarm arrives after Done for the same occurrence") and §2 ("It must stop the moment they act"). The same race affects the Done follow-up after an alarm's Stop, which is posted by the reconcile.
- **Suggested fix:** add to AD-4 or AD-5: "`CommandSubmitting.submit` is `async` and returns only after the command's job, including its reconcile, has finished. Every source awaits it: an intent's `perform` before returning, and the notification delegate before calling its completion handler. The shell wraps the job in a `UIApplication` background task." If the submitter can't wait (journal path, open failure), say what happens instead.

---

## Medium

### M1. AD-9's trigger rule can't express an immediate delivery

- **Location:** AD-9: "notification triggers are non-repeating `UNCalendarNotificationTrigger`s built from UTC date components … No request uses a repeating, wall-clock or relative trigger." AD-6 › What the plan holds: deliveries "whose fire instant equals the instant of a write committed in this job" (the Done follow-up, the nudge when an edit ends quiet hours early). AD-6 › Exceptions: Test Nudge posts directly. AD-16: the stop intent posts `followup/<key>/<n>`.
- **Problem:** each of these fires at an instant that has already passed by the time the request is added. A calendar trigger for a past date has no next trigger date, so it isn't delivered (this should be checked in the simulator test AD-9 already requires). The documented way to deliver at once is a `nil` trigger (`UNNotificationRequest`: "Specify nil to deliver the notification right away"), which the rule as written doesn't allow.
- **Concrete failure:** an implementer who follows AD-9 to the letter builds a follow-up that never appears. Brief §4's "sends an ordinary notification at once" fails, and Not Done after a reflex Stop is lost. A second implementer uses `nil` for Test Nudge and a calendar trigger at now + 1 s for the follow-up. The reconciler's diff then compares fire instants that don't match either request.
- **Suggested fix:** in AD-9, add: "A delivery whose fire instant is at or before `now` when it's added uses a `nil` trigger (delivered at once). That covers AD-6's at-once items, Test Nudge and AD-16's follow-up. Every other request uses the calendar trigger." Note in AD-6 that an at-once item is never pending, so the diff doesn't look for it in the pending list.

### M2. One `nudge` category can't carry "Snooze N min" for per-reminder snooze lengths

- **Location:** AD-17 › Categories: "`nudge`: Done and Snooze". EXPERIENCE › Nudge Surfaces, Notification: "**Done**, **Snooze 15 min** (while snoozes are left)". Brief §3: snooze length is set per reminder (5, 10, 15 or 30 min). AD-6's diff treats a change of category as a change.
- **Problem:** a `UNNotificationAction`'s title belongs to its registered category. It can't change from one notification to the next. With one `nudge` category, the action can say only "Snooze", which differs from EXPERIENCE's copy. To keep "Snooze 15 min", the app needs one category per length.
- **Concrete failure:** the notifications unit adds `nudge-5`, `nudge-10`, `nudge-15` and `nudge-30` to match the copy. The engine or plan unit follows AD-17 and emits `nudge`. Since the category is part of the plan item AD-6 diffs, the two units disagree about what the plan holds, and either the copy or the AD-17 set is broken.
- **Suggested fix:** decide in AD-17. Either use categories `nudge-<seconds>` (and `nudge-final`), registered at launch for every allowed length, with the engine choosing per delivery; or plain "Snooze" on notifications, with EXPERIENCE's copy changed to match (the alarm's button can keep its length).

### M3. AD-16's stop intent posts a notification, but its target may not import UserNotifications

- **Location:** Layer table, Live Activity row: `NudgeLiveActivity` may import "NudgeCore, AppIntents, AlarmKit". AD-16 › The journal: "If the command is a Stop, the intent also posts `followup/<key>/<n>`". AD-12 › Intents only submit commands: "touch no OS API, except as in AD-16".
- **Problem:** the stop intent lives in `NudgeLiveActivity`, which isn't allowed to import UserNotifications. The localized follow-up text also needs a catalog that target doesn't have (see M4). The spine allows the exception in AD-12 but not in the import table.
- **Concrete failure:** one implementer adds UserNotifications to `NudgeLiveActivity`, against the table. Another routes the post through `CommandSubmitting` to the shell, which is a different path with different timing before the first unlock. Either way the table and AD-16 disagree, and the two units' copy of the follow-up content can drift.
- **Suggested fix:** either add UserNotifications to `NudgeLiveActivity`'s imports with a note citing AD-16, or say that the coordinator posts the follow-up when it journals a Stop (it's in the app process, and that keeps the intent "submit only").

### M4. Where package-target strings live isn't decided

- **Location:** Conventions › Strings: "Every user-facing string, including notification, alarm, Live Activity, App Shortcut and accessibility text, is in a String Catalog … The widget extension has its own catalog." Map › Localization: "String Catalogs in app and widget". Folder tree: catalogs only under `App/` and `Widgets/`.
- **Problem:** notification and alarm content is built in `NudgeShell`, intent titles and phrases are declared in `NudgeIntents`, and the Live Activity intents are in `NudgeLiveActivity`. All three are package targets. Xcode extracts a package target's strings into that target's own catalog and looks them up in `Bundle.module`. `String(localized:)` and `LocalizedStringResource` default to the main bundle. The spine doesn't say which approach to use.
- **Concrete failure:** the shell's notification strings go into a `NudgeShell` catalog read with `bundle: .module`, while the intents unit puts its strings in the app's catalog and reads them from `.main`. Both look right in English. A pseudo-localized build (brief §8 "Ready to translate") then shows keys or English in one of them, and a translator has to find catalogs in places the spine doesn't list.
- **Suggested fix:** add to Conventions › Strings: each package target with user-facing text has its own String Catalog and passes `bundle: .module` (or `#bundle`) explicitly. App Shortcut phrases stay in the app target's `AppShortcuts.xcstrings`. Update the folder tree and the Map row to match.

### M5. `Evaluation`'s contents don't cover per-reminder state that screens need outside the window

- **Location:** AD-1's list of what `Evaluation` holds (occurrence states, next due times, plan, `nextChangeAt`); AD-2 (the engine computes a reminder's Active, Paused or Completed status); AD-20 ("Views read derived state only from it"). EXPERIENCE › Reminder details: "Latest occurrence done | **Not Done** shows while Not Done applies"; Tags and Search sections "Today, Later, Paused and Completed".
- **Problem:** `Evaluation` isn't required to carry each reminder's status, or whether Not Done is available on its latest done occurrence. That occurrence is often older than yesterday (any weekly or monthly reminder). With the default window, `NudgeModel` doesn't have either answer.
- **Concrete failure:** the Reminder details unit works out "Not Done applies" itself from the last done row and the repeat rule, against AD-1. Or it calls `NudgeQuerying`'s 90-day History query, which isn't live, so the button doesn't disappear when the next occurrence falls due. The Tags unit derives Completed in a view and gets the Paused-over-Completed rule wrong.
- **Suggested fix:** in AD-1, add to `Evaluation` per-reminder fields for status (AD-2), the latest done occurrence's key with whether Not Done applies and until when, and carry-over pending. `nextChangeAt` should include the instant Not Done stops applying.

---

## Low

1. **Where shared types live.** The Layer table's Shell row says it holds `Capabilities`, but `NudgeCore.evaluate` takes `capabilities` as a parameter and Core can't import Shell, so the type has to be in Core with only its construction in Shell (as AD-18 says). Conventions › Clock doesn't name a target for the `Clock` protocol. *Fix:* list `Capabilities` (the type) and `Clock` in the Core row, and keep "builds `Capabilities`" in the Shell row.
2. **AD-6's exceptions list is incomplete.** AD-6 says "Only the reconciler schedules, cancels or removes", but AD-16's open-failure path ("The shell cancels every pending notification and alarm") isn't in AD-6 › Exceptions. *Fix:* add it there, or have AD-16 name itself as an AD-6 exception.
3. **Zone facts are facts, but they're written as bookkeeping.** The paradigm says "a command writes facts, then a reconcile follows", while AD-4 lists zone facts among a reconcile's bookkeeping writes (AD-3 calls them versioned facts). It works, but it breaks the stated split. *Fix:* qualify the paradigm sentence ("… except zone facts, which a reconcile records").
4. **The `keep/` request and the ledger.** AD-15 gives "every delivery the reconciler schedules" a row with an occurrence key and nudge index. The ER diagram hangs `LEDGER_ENTRY` off `OCCURRENCE`. `keep/<…>` has neither, and AD-15's second restore signal counts "future `scheduled` rows that were handed over". *Fix:* say whether `keep/` gets a row (with a null occurrence) or none.
5. **"iOS 18 and 26/27 simulators" is ambiguous.** Conventions › Testing and the deployment diagram use the phrase. CI › Environments downloads only an iOS 18 runtime, so in practice CI runs iOS 18 and 27 and never iOS 26, though brief §5 tests all three. *Fix:* name the runtimes. Either pin an iOS 26 runtime too, or state that iOS 26 is covered on devices only.
6. **Product rules restated, not pointed to.** These are short, but they can drift:
   - AD-3 › How versions apply repeats brief §3 Edit's "from the next due time / next nudge / next snooze" and the gentler-strength raise, as well as citing it.
   - AD-11's Normal/High/Urgent channel lines and "Past the alarm limit" repeat brief §4's table.
   - AD-14 › Notification order repeats brief §4's slot order.
   - AD-12's "moved, or dropped, if the snooze would end after a takeover or inside quiet hours" repeats brief §4.
   - AD-2's Completed and Paused derivation repeats brief §3's Completed row.

   *Fix:* keep only the technical addition in each (the interruption-level mapping, the 63 + 1 cut, the fact that versions are what the engine reads) and point to the brief for the rule.
7. **Map, Q4 row.** It lists only AD-14. Q4 also asks how quiet hours, Ignore Quiet Hours and edits reschedule what's pending at once, which is answered by AD-4 and AD-6 (a reconcile after every command, and AD-6's at-once rule) and AD-3 (versions). *Fix:* add AD-3, AD-4 and AD-6 to that row.
8. **Opening a database migrated by a newer build.** TestFlight testers can install an older build after a newer one has run its migrations. The spine doesn't say whether that counts as AD-16's open failure (GRDB's `hasBeenSuperseded` can detect it) or is allowed. *Fix:* one sentence in AD-16: an unknown applied migration is an open failure, so the app shows the EXPERIENCE › Any message.
9. **Channel `none` is decided in AD-15, not AD-11.** AD-11 › Who decides lists the channels without `none`, which appears only in AD-15 (notifications off, and no alarm). *Fix:* add a line to AD-11: "With `notificationsAllowed` false, a delivery that would be a notification has channel `none` (AD-15)."

---

## Checked and holding

- **Paradigm and write path.** Functional core with a reconciler, one serial `AsyncStream` consumer, `package`-access writes, and a reconcile after every command. AD-1, AD-4 and AD-6 agree on these, and they directly prevent the drift the brief warns about (§7 "Predictable and testable", §11 Q3).
- **Layer table vs dependency diagram.** Every edge in the diagram (Shell→LA, Intents→LA, Widget→LA/Core, Store→Core) is allowed by the "May import" column. The widget never links Store or Shell (AD-5).
- **Process model.** App-only database, no App Group, `allowedExecutionTargets` on iOS 27, and the iOS 26 question sent to the first spike with a fail-toward-nudging default (AD-5, Structural Seed, brief §10 checklist). It's deferred properly, with what the result would change.
- **Identity (AD-7).** Locale-independent keys, delivery IDs unique for the life of an occurrence and tested, UUIDv5 for alarms, nudge index from the plan item, and a DST rule. Two units can't name a delivery differently.
- **AD-8.** The materialization instant uses the zone fact in effect at the time, and an eastward skip makes the occurrence due at once. This matches brief §3 Reminder ("8:00 AM stays 8:00 AM") and §10's "worst failure".
- **Alarm answering and adoption (AD-6).** A Clear doesn't answer an alarm. Adoption takes only alarms seen in `.countdown` after their fire instant, never an alarm that has disappeared. Deduplication is through `accepts`. This is consistent with AD-4's rejection rule and with brief §10's before-first-unlock risk.
- **AD-12 and the addendum's AlarmKit notes.** The engine plans the post-snooze alarm, with the `.custom` fallback recorded and tied to its device check.
- **AD-13.** Points to brief §4 for when a chain starts, what it sends and how it counts, and keeps only per-notification rows and the nudge index. Nothing about chains is restated.
- **AD-14.** The 63 + 1 budget, the learned `alarmCapacity` (starting unknown and re-diffed in the same job), the 8-day horizon with the keep-nudging notice when the horizon cuts the plan, and BG refresh at most 12 hours ahead. Matches brief §4 System limits.
- **AD-15.** Immutable ledger rows, `handedOverAt`, History lines derived from counted nudges, the "couldn't be sent" reasons matching EXPERIENCE's verbatim History phrases, two restore signals, and pruning tied to `prunable`.
- **AD-16.** Folder-level file protection, numbered migrations with fixture tests, a journal with no titles (AD-19), replay as one first job, and the open-failure message matching EXPERIENCE › Any word for word. Delete All Data keeps settings as brief §3 does.
- **AD-17 and AD-18.** No authentication on any action, matching the brief's architecture decision. `#available` checks are confined to the AlarmKit adapter, `NudgeLiveActivity` and named app wrappers. `Tab(role: .search)` is correctly treated as iOS 18+. Layout is decided by size class, never by idiom.
- **AD-19 and Environments.** No dependency besides GRDB, a privacy manifest with `UserDefaults` declared under reason CA92.1, Data Not Collected, and a crash-report statement consistent with brief §1.
- **AD-20.** One `NudgeModel` fed the coordinator's published inputs, so the screens and the scheduled nudges can't disagree between a change and its reconcile.
- **Conventions.** Integer-second durations (fits 7.5- and 2.5-minute intervals), a Foundation case-folded tag key, one search matcher, the Siri order pointing to EXPERIENCE, `SceneStorage` filters (brief §11 Q14) with read-time dropping of deleted tags, and the Export format (Q12).
- **Coverage.**
  - Every brief §11 question (Q1–Q14) has a Map row, and every §6 screen or feature maps to an AD or a convention.
  - Keyboard shortcuts point to EXPERIENCE's one list.
- **Dimensions the spine owns.**
  - **Decided:** stack and versions, environments (Debug, TestFlight, App Store), signing, entitlements, CI, crash reporting, and "no infrastructure".
  - **Deferred:** release automation, iPad, sync and SQLCipher, none of which can let two units diverge.
  - **Open:** device unknowns, in a table that names the decision each would change.
- **Cross-references.**
  - AD numbers cited in the brief (§4: AD-12, AD-16; §10 checklist: AD-5, AD-6, AD-11, AD-12, AD-14, AD-15, AD-16) and in the addendum (AD-12, AD-14) point at the right rules.
  - The ER diagram's event labels match AD-3.
  - The Deferred device-unknowns bullet points to the Structural Seed table, not a second list.
- **Precedence** is stated once, by pointer to the brief's introduction, and the brief lists the spine second.
