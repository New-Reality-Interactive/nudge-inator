# Adversarial review — ARCHITECTURE-SPINE.md (revalidation)

- **Target:** `docs/architecture/ARCHITECTURE-SPINE.md` at `acb3a01`
- **Read against:** brief §3, §4 and §10; `docs/design/EXPERIENCE.md`; `.memlog.md` for the reasons behind decisions
- **Lens:** build two units one level down that each follow every AD to the letter but still don't fit together: shared data in clashing shapes, two owners of one entity, or conflicting paths for changing state. Each pair is a hole that a new or tighter AD should close.
- **Earlier review folders:** not read.

## Verdict

**Needs changes before build.** The structural core holds: one writer, one fold, deterministic identity, an append-only fact model. I couldn't build two compliant units that disagree about who writes the database or how an event is ordered. The holes sit where the spine meets the OS and where the engine's inputs are underspecified. Six pairs diverge in realistic use, or one of the two builds breaks a brief rule.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 6 |
| Medium | 6 |
| Low | 9 |

---

## High

### H1. `CommandSubmitting` has no completion contract, so an alarm's Stop may never reach the reconciler

- **Units:** `NudgeLiveActivity` stop, snooze and Done intents, plus the notification delegate (caller), and `NudgeShell.Coordinator`'s `CommandSubmitting` (callee).
- **Quoted text:**
  - AD-12: "the alarm's snooze and stop intents submit `snooze` and `done(source: .alarm)` and touch no OS API".
  - AD-5: "only through `CommandSubmitting` and `NudgeQuerying` (both `Sendable`, defined in `NudgeCore`)".
  - AD-4: "Each job runs to completion, including its awaits, before the next starts."
- **Build A:** `submit(_:) async` returns only after the command's job has finished, including its reconcile. `perform()` and the delegate's `completionHandler` wait for it.
- **Build B:** `submit(_:)` adds the command to the queue's `AsyncStream` and returns at once. `perform()` returns, and the delegate calls `completionHandler()` straight away.
- **Why both comply:** neither AD says when `submit` returns or what it returns. "Runs to completion" is about jobs relative to each other, not relative to the caller.
- **Divergence:** AlarmKit or a notification action launches the app in the background. In Build B, iOS may suspend the process once `perform` or the completion handler returns, before the job commits or the reconcile cancels nudge 5's alarm. Relentless rings again 2 minutes after Stop, or the command is lost if the process is killed. That breaks brief §2 ("It must stop the moment they act") and §4 ("Closing an occurrence clears its nudges … as soon as the app runs"). Siri has the same problem: it can't say "Nothing is nudging you" or "No snoozes left" from what the command actually did.
- **Close (tighten AD-5):** make `CommandSubmitting.submit(_:) async -> CommandOutcome` (accepted, rejected or journaled). It returns only after the job's transaction and reconcile have finished, or after the journal append and any follow-up post. Every intent's `perform`, the notification delegate's completion handler and `BGAppRefreshTask.setTaskCompleted` wait for it. Siri phrases its answer from the outcome.

### H2. The alarm diff can't see what it's told to compare, and the only workable source is forbidden

- **Units:** the reconciler's diff (`NudgeShell`) and the AlarmKit adapter.
- **Quoted text:**
  - AD-6: "diffs the plan against pending requests and `AlarmManager.alarms` only … it changed if anything handed to the OS for it differs: … for an alarm its secondary button, `postAlert`, presentations and metadata".
  - AD-6: "Checking for those rows is the only ledger read that decides what to schedule."
  - AD-15: "A row's delivery ID, … channel, content and fire instant never change".
  - `.memlog.md` (G3): "Alarm exposes only id, schedule, countdownDuration and a state snapshot".
- **Build A:** compares only what `Alarm` exposes (`schedule`, `countdownDuration`). Changes to the title (presentation and metadata) and to the snooze button's label are never detected. The alarm is left in place.
- **Build B:** can't detect changes either, so it replaces every future alarm on every reconcile to be safe.
- **Why both comply:** neither reads the ledger to decide what to schedule, and both diff against `AlarmManager.alarms` only. The third option, comparing against the ledger row's recorded `content`, is ruled out by the "only ledger read" sentence.
- **Divergence:** the person renames "Morning pill" or changes its snooze length from 5 to 15 minutes. Under Build A, the next 8 days of alarms ring with the old title and say "Snooze 5 min", with a 5-minute `postAlert`. That contradicts brief §4: the alarm shows the reminder's title and "**Snooze** (with its length, such as "Snooze 15 min")". Build B churns every alarm on each foreground. It reuses alarm IDs, which brief §10 lists as unverified, and restarts any pre-alert Live Activity.
- **Close (AD-6):** say that alarm changes are detected against the configuration recorded on the newest non-cancelled ledger row for that delivery ID, and list that as a second permitted ledger read. Alternatively, put a configuration hash into the delivery ID's UUIDv5 input so that any change produces a new alarm ID.

### H3. The notification order and the horizon allow two incompatible slot policies

- **Units:** the `NudgeCore` slot policy, and the shell's background-refresh request and keep-nudging request.
- **Quoted text:**
  - AD-14: "the plan covers 8 days ahead, or until the budgets are full, whichever comes first."
  - AD-14: "1. nudge 1 of every coming-up occurrence, soonest first 2. every other delivery, soonest first. The plan is cut to 63 requests".
  - AD-14: "requests a `BGAppRefreshTask` for the plan's earliest top-up time".
- **Build A:** the horizon is a fixed 8 days. Tier 1 takes nudge 1 of every occurrence in those 8 days, then tier 2 takes what's left.
- **Build B:** walks forward soonest first until 63 requests fill, and that instant becomes the horizon ("until the budgets are full"). Inside it, nudge 1s are ordered first.
- **Why both comply:** "until the budgets are full" doesn't say whether the budget shrinks the window before the ordering or cuts after it. "Top-up time" is never defined.
- **Divergence:** take a person with 8 daily reminders. Medication taken several times a day, or Custom "times of day", gets there quickly. That's 64 nudge 1s in 8 days, so Build A's tier 2 is empty. Today's Gentle reminders get nudge 1 only, and Firm gets nudge 1 and then silence until its first alarm. The keep-nudging notice fires an hour after the first reminder of the day. Build B nudges today fully and puts the notice about a day out. Build A follows brief §4's ordering literally but breaks brief §1 ("keeps nudging until you tap Done"). The two builds also schedule background refresh at different times, because "top-up time" means something different in each.
- **Close (AD-14):** give the algorithm. For example: "Tier 1 is limited to occurrences due before the instant at which tier 1 plus the open occurrences' remaining nudges for the next N hours fit in 63; the horizon is the earlier of 8 days and the first instant a delivery is cut." Define top-up time, for example as the fire instant of the K-th-last scheduled request, and test the 8-a-day case.

### H4. Nothing defines how to tell "before the first unlock" from "any other open failure", and one reading cancels the whole schedule after a reboot

- **Units:** the store-opening path at launch (`NudgeShell` with `NudgeStore`) and the AD-16 failure handler.
- **Quoted text:**
  - AD-16: "while protected data is unavailable (before the first unlock), a command goes to an append-only journal".
  - AD-16: "Any other open failure (a failed migration, corruption): … The shell cancels every pending notification and alarm".
- **Build A:** checks `UIApplication.isProtectedDataAvailable` before opening. If it's false, the build doesn't open the store, journals commands and waits for `protectedDataDidBecomeAvailable`.
- **Build B:** opens the database at launch and sorts the error that comes back. Anything that isn't a recognised migration failure, such as the `SQLITE_IOERR`, `SQLITE_CANTOPEN` or `EPERM` that GRDB raises for a locked file, is treated as "any other open failure".
- **Why both comply:** AD-16 names two cases but not the test that tells them apart. "Any other" reads as a catch-all.
- **Divergence:** after an overnight iOS update reboot, Rosa's 8:00 alarm or a background refresh launches the app before she unlocks. Build B cancels every pending notification and alarm. Nothing nudges until she opens the app, and then she sees the "can't open your reminders" message for a fault that doesn't exist. That is brief §10's "worst failure", and it happens on an ordinary reboot.
- **Close (AD-16):** the store is opened only while `isProtectedDataAvailable` is true. The cancel-all path runs only after an open attempt fails while protected data is available. An open error that comes back while protected data is unavailable is treated as locked and goes to the journal.

### H5. "Each reminder's latest occurrence before the window" can mean a row or a projection, and the reconcile can't create the row

- **Units:** the `NudgeStore` read that gathers `evaluate`'s inputs, and `NudgeCore`'s carry-over fold.
- **Quoted text:**
  - AD-14: "`evaluate` reads … each reminder's latest occurrence before the window with the facts since then (for carry-over and Not Done)".
  - AD-8: rows are written when "a command names its key" or "a reconcile finds that it's due".
  - AD-1: the reconciler passes "the default window, from the start of yesterday … through 8 days after `now`".
- **Build A:** the store passes the newest `OCCURRENCE` row older than the window.
- **Build B:** the engine projects the reminder's immediately preceding occurrence from its versions. It finds that occurrence's events, if any, and derives its status.
- **Why both comply:** "latest occurrence" doesn't say whether that's a materialized row or a projection, and both readings are natural in their own unit.
- **Divergence:** a missed occurrence is exactly the kind no command ever names. If no reconcile ran between its due time and the next day, it never gets a row, because the reconcile's window starts at yesterday and can't "find" it later. Take monthly rent, or a weekly reminder whose occurrence was missed while the app stayed closed. Build A reads a done occurrence from two periods back and gives no carry-over. Build B gives "↑ Starts higher". Brief §3's carry-over rule decides differently depending on the build. AD-15's "latest occurrence … never prunable" has the same row-or-projection split.
- **Close (AD-14 and AD-8):** state that "latest occurrence" is the latest projected occurrence, which the engine computes. The store supplies the versions and events needed to derive it, whether or not it has a row. Alternatively, require a reconcile to materialize every occurrence since the last reconcile, not just those in its window.

### H6. The post-snooze alarm's pre-alert length is open, and it decides whether the Live Activity covers the snooze

- **Units:** the `NudgeCore` plan item for `snooze/<key>/<n>/<s>`, and the AlarmKit adapter that builds `Alarm.CountdownDuration`.
- **Quoted text:**
  - AD-12: "It's an `Alarm.Schedule.fixed` alarm (AD-9) with a pre-alert countdown, so the Live Activity shows before it fires."
  - Brief §4: "After a snooze, the countdown shows on the Lock Screen as the app's Live Activity, with **Done**."
  - EXPERIENCE › Nudge Surfaces: Live Activity "(after Snooze on an alarm)", "Snoozed. Rings again at 8:35 AM."
- **Build A:** pre-alert = fire instant − `now` at reconcile time, so the countdown spans the snooze.
- **Build B:** a fixed short pre-alert, such as 60 s, "so the Live Activity shows before it fires".
- **Why both comply:** AD-12 requires a pre-alert but gives no length.
- **Divergence:** Build B shows no Live Activity and no Done for 14 of 15 minutes, which breaks brief §4. Build A computes the duration from `now`, so it changes on every reconcile. AD-6's diff ("presentations … differs") then replaces the alarm each time, restarting the Live Activity and reusing the alarm ID.
- **Close (AD-12):** pre-alert = fire instant − the snooze event's `issuedAt`. That comes from a fact, so it stays the same across reconciles. A replan that moves the fire instant recomputes it from the same `issuedAt`.

---

## Medium

### M1. The meaning and source of an event's nudge index are undefined

- **Units:** the command producers (delegate from `userInfo`, alarm intents and adoption from metadata or the ledger, views from `NudgeModel`, Siri from `NudgeQuerying`) and the `NudgeCore` fold.
- **Quoted text:**
  - AD-3: each event records "the occurrence key and nudge index".
  - AD-7: "`snooze/<key>/<n>/<s>`, the alarm that ends snooze `s` and delivers nudge `n`"; "A delivery's nudge index always comes from its plan item".
- **Build A:** the fold takes the event's stored nudge index as the nudge being answered, so the post-snooze nudge is index + 1.
- **Build B:** the fold ignores the stored index and derives the answered nudge from the planned fire instants before `issuedAt`.
- **Divergence:** the person snoozes from an older delivered notification (nudge 3) after nudge 4 has fired. The same thing happens with an adopted snooze on nudge 4's alarm after nudge 5 rang before the first unlock. Build A delivers "nudge 4" again and rewinds the count, so the give-up limit moves. Build B delivers nudge 5. History's "Snoozed 15 min" line also lands in a different place.
- **Close (AD-3):** the event's nudge index is a record of the surface only, used for History. The fold always derives the answered nudge from `issuedAt`. Alternatively, drop the field.

### M2. "Delivered" in the snooze rule could mean the ledger or the plan

- **Units:** `NudgeCore.accepts` and its inputs from the store.
- **Quoted text:** AD-4: "rejected if a committed snooze already answers the same delivered nudge (the latest one delivered before its `issuedAt`)". AD-6: "An alarm's fire instant is its ledger row's".
- **Build A:** "delivered" means a handed-over ledger row, so `accepts` is given ledger rows.
- **Build B:** "delivered" means the engine's latest counted nudge, from facts only.
- **Divergence:** with notifications off, nudges 2 and 3 have channel `none`. Two in-app snoozes in a row both have no handed-over row, so Build A treats them as answering the same nudge and rejects the second. Build B counts nudge 3 and accepts it. Budget-cut nudges split the builds the same way.
- **Close (AD-4):** define "delivered" as the latest nudge `evaluate` counted at or before `issuedAt`, whatever its channel. State whether ledger rows are an input to `accepts`.

### M3. The `Evaluation` doesn't carry "Not Done applies", which three units need

- **Units:** AD-6 Cleanup (shell), Not Done on My Day, Last 24 Hours and Reminder details (app, through `NudgeModel`), and Assistive Access's "Not done yet".
- **Quoted text:**
  - AD-6: Cleanup removes "a Done follow-up once Not Done no longer applies or has been used".
  - AD-12: "planned only while Not Done applies".
  - AD-1 lists what `Evaluation` holds, and Not Done applicability isn't on the list.
- **Build A:** each consumer calls `accepts` with a synthetic Not Done at its own `now`.
- **Build B:** Cleanup treats "no longer planned" as "no longer applies". The follow-up's fire instant is in the past, so it is never in the plan after the first job, and Build B removes the delivered follow-up on the next reconcile.
- **Divergence:** under Build B, Rosa's follow-up disappears the moment she opens the app (Flow 2's failure path), while the row still offers Not Done. That breaks brief §4: the notification is removed only "once Not Done no longer applies".
- **Close (AD-1):** `Evaluation` gives each done occurrence's `notDoneUntil`, or nil, and every consumer reads it.

### M4. "Capacity minus protected alarms" isn't one of the inputs, so `NudgeModel` can't match the plan

- **Units:** the reconciler (which has the OS snapshot) and `NudgeModel` (which has only the persisted inputs).
- **Quoted text:**
  - AD-14: "The plan's alarm cap is `alarmCapacity` minus the protected alarms".
  - AD-20: "`NudgeModel` evaluates only from the inputs the coordinator last published (facts, settings, the zone facts and the persisted capabilities)".
  - AD-1's signature has no protected-alarm count.
- **Build A:** the reconciler subtracts the protected count before calling `evaluate`. The model uses the raw persisted capacity.
- **Build B:** the reconciler persists the effective cap as `alarmCapacity`, which contradicts "persists the number in `AlarmManager.alarms`".
- **Divergence:** at the alarm limit, while an alarm is ringing, Build A's card says "Alarm" for a nudge the reconciler scheduled as "Notification: too many alarms scheduled". AD-20 exists to prevent exactly that.
- **Close:** add `protectedAlarms` to `Capabilities`, or make it a published input. Persist it with capability state.

### M5. Conventions › Time says "current zone", while AD-3, AD-8 and AD-20 say zone facts

- **Units:** whoever builds the injected `Calendar` (shell or `NudgeModel`) and the engine's wall-clock conversions.
- **Quoted text:**
  - Conventions › Time: "Wall-clock values as a `LocalDateTime`, read in the iPhone's current zone (AD-9). All date math in `NudgeCore` through an injected Gregorian `Calendar`."
  - AD-3: "Each past instant is evaluated with the quiet hours and zone in effect then."
  - AD-20: "changing nothing but `now`".
- **Build A:** injects `Calendar` with `TimeZone.current`, rebuilt on each refresh.
- **Build B:** the engine sets the calendar's zone from the zone fact in effect for each instant.
- **Divergence:** after a zone change and before the reconcile, Build A's My Day "today" and card times move ahead of what's scheduled. History shows past projected occurrences in the new zone. Build B doesn't.
- **Close (Conventions):** the injected `Calendar`'s zone is ignored. `NudgeCore` sets the zone per instant from zone facts. Only display formatters use the current zone.

### M6. The before-first-unlock follow-up has no legal owner

- **Units:** the `NudgeLiveActivity` stop intent and `NudgeShell`'s `CommandSubmitting`.
- **Quoted text:**
  - AD-16: "If the command is a Stop, the intent also posts `followup/<key>/<n>`, taking the reminder's title from the alarm's `NudgeAlarmMetadata`".
  - Layer table: `NudgeLiveActivity` "May import: NudgeCore, AppIntents, AlarmKit", with no UserNotifications and no UIKit for `isProtectedDataAvailable`.
  - AD-16's journal holds "never titles".
- **Build A:** the intent imports UserNotifications and posts the follow-up itself, which goes against the import table.
- **Build B:** the shell posts it when it journals, which needs the title. So `Command` or `CommandSubmitting` has to carry a title, while the journal must not store one.
- **Divergence:** the two teams build incompatible `CommandSubmitting` shapes, one with a title and one without. Build A also needs an import that the layer table forbids.
- **Close (AD-16):** the shell's `submit` posts the follow-up. The stop intent passes the title from its metadata as a transient argument that is never journaled.

---

## Low

- **L1. Siri order has no final tie-break.** Two Relentless reminders due at 8:00 with the same nudge count tie on all three keys in EXPERIENCE › Siri. "Snooze Nudge-inator" may snooze a different reminder than the one "What's nudging me" read out first. The order of Now's Nudging cards isn't tied to this order either. Close: add a final key, such as title and then reminder UUID, and say whether Now uses the same order.
- **L2. `accepts` "returns every row the command writes", but deletes and in-place updates aren't rows.** Examples are the reminder delete cascade, title and notes edits, Rename Tag and trimming Recent Searches to 5. One build has `accepts` return a write set that includes deletes. Another relies on SQL cascades and a trim inside the store. Recent Searches can then grow without limit in one build. Close: `accepts` returns a write set of inserts, updates and deletes.
- **L3. Test Nudge has no reserved slot.** "posts `test/…` directly". A calendar trigger a few seconds out, an absolute UTC trigger so AD-9 holds, makes 65 pending requests when the plan has 63 plus 1. iOS silently drops the furthest one, the keep-nudging request, and AD-15 then marks it `lost`. Close: Test Nudge uses a nil trigger, or the budget reserves a slot.
- **L4. The form's duplicate-tag check could use the matcher or the uniqueness key.** The search matcher ignores diacritics, while the tag key ignores case only. The form says "Using #cafe" for "café" in one build and creates `#café` in another. Close: the form's check calls `accepts`, or uses the uniqueness key.
- **L5. A rejected command could still materialize its occurrence.** AD-4 says both "A command naming a valid projected occurrence key materializes it" and "A command that doesn't apply writes nothing." A build that materializes on rejection freezes a future occurrence's instant early. Close: say materialization happens only when the command is accepted.
- **L6. Journal append and replay delete aren't serialized.** An intent appends just as protected data becomes available, after replay has read the file and before it deletes it, and the entry is lost. Close: replay renames the file before reading, and appends go to a fresh file.
- **L7. The `Clock` is injected only into the shell, but views and intents stamp `issuedAt`.** One build uses `Date()` in views, another reads time through `CommandSubmitting`. Tests with a fixed clock then disagree. Close: `CommandSubmitting` exposes `now()`, or stamps `issuedAt` when it's called.
- **L8. Export's offset and zone for each instant, and the window's end, are unspecified.** One build uses the current zone, another the zone fact in effect. One window ends at `now`, another at +8 days. Close: Conventions › Export names both.
- **L9. The identifier for Siri's occurrence entity is unspecified.** A reminder-UUID entity resolved at `perform` can mark the occurrence that took over done, instead of the one Siri listed. Close: the Occurrence entity's ID is the `OccurrenceKey`.

---

## What held

I couldn't build a compliant pair that breaks any of these:

- the single writer and queue (AD-4, AD-5)
- event ordering and backdated commands (AD-3, AD-4)
- delivery-ID uniqueness and its single owner (AD-7)
- the frozen due instant (AD-8)
- the at-once delivery rule (AD-6)
- journal replay's ledger row for the follow-up (AD-16)
- adoption of system snoozes (AD-6)

Each of these names its owner and what it reads precisely enough that two teams would converge.
