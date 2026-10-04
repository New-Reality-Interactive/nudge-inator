# Rubric review — ARCHITECTURE-SPINE.md at 8c2ce98

- **Target:** `docs/architecture/ARCHITECTURE-SPINE.md`, branch `architecture/spine-update`, commit 8c2ce98 (clean working tree)
- **Read against:** brief §3, §4, §6, §10, §11; addendum; EXPERIENCE.md; `.memlog.md` for the reasons behind decisions. Nothing under `reviews/` was read.
- **Apple checks:** apple-rag-mcp was available. Claims checked with it are marked *(verified)*. Claims not checked are marked *(unverified)*.

## Verdict

**Pass with fixes.** The spine fixes the real divergence points for this app's features. Every brief §11 question and §6 screen maps to a decision. Deployment, environments and operations are all decided. No Deferred item could let two units diverge. One high finding remains: nothing says when the launch-time registrations must happen. The shell owns them and the app target owns the launch, and Apple requires them before launch finishes. If they run late, a Lock Screen Done or an alarm Stop is silently lost. The medium findings are a race at a delivery's fire instant, an import table that omits SwiftUI, and wall-clock `issuedAt` ordering when the clock moves backward.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 1 |
| Medium | 3 |
| Low | 9 |

## High

### H1 — Launch-time registrations have no owner and no deadline

- **Location:** AD-5: "The app registers both with `AppDependencyManager` at launch." AD-5: "Notification actions run in the app's `UNUserNotificationCenterDelegate`." AD-6 Triggers: "never from `UIApplicationDelegate` life-cycle methods". AD-14: "each reconcile requests a `BGAppRefreshTask`". AD-18: UIKit is "used only for the app lifecycle (the `UIApplicationDelegateAdaptor` in the app target; …)".
- **Problem:** three registrations must be finished before the app finishes launching:
  - the notification center's delegate
  - the `BGTaskScheduler` launch handler
  - the `AppDependencyManager` registration of `CommandSubmitting` and `NudgeQuerying`

  Apple says the delegate "must [be assigned] in the `application(_:willFinishLaunchingWithOptions:)` or `application(_:didFinishLaunchingWithOptions:)` method … Assigning a delegate after the system calls these methods might cause you to miss incoming notifications" *(verified: UNUserNotificationCenterDelegate overview)*. For `BGTaskScheduler`: "Registration of all launch handlers must be complete before the end of `applicationDidFinishLaunching(_:)`" *(verified: BGTaskScheduler.register)*. The spine names the adaptor but never says these registrations happen there, or which unit does them. AD-6's "never from `UIApplicationDelegate` life-cycle methods" applies only to foreground triggers, but it can be read as steering people away from the delegate entirely. These objects live in `NudgeShell`, the launch belongs to the app target, and nothing in the spine sits between the two.
- **Concrete failure:** a compliant app-target unit builds the `Coordinator` and assigns the delegate lazily, from the root scene's `.task`. That's a common SwiftUI pattern. The person taps Done on a Lock Screen notification while the app isn't running. iOS launches the app in the background without connecting a scene, so the delegate is never set and the action is dropped. The same can happen to an alarm's Stop intent: it can run before registration, find no `CommandSubmitting`, and do nothing (AD-5, "No coordinator, no effect"). Either way the occurrence keeps nudging after the person acted, which breaks brief §2 ("It must stop the moment they act") and the §8 measure. A late `BGTaskScheduler` registration also raises an exception at runtime.
- **Fix:** add a rule to AD-5 or AD-18. The app target's `UIApplicationDelegateAdaptor`, in `application(_:willFinishLaunchingWithOptions:)`, or `App.init`, which runs earlier, synchronously creates the `Coordinator` (without opening the store) and then:
  - assigns it as the `UNUserNotificationCenter` delegate
  - registers the categories (AD-17)
  - registers the one `BGTaskScheduler` handler
  - registers `CommandSubmitting` and `NudgeQuerying` with `AppDependencyManager`

  Say that AD-6's ban covers only the foreground triggers. Add a UI test or launch test that asserts the delegate is set before `didFinishLaunching` returns.

## Medium

### M1 — The diff can remove a pending request or alarm that is due but not yet delivered

- **Location:** AD-6, What the plan holds: "deliveries whose fire instant is after `now`". AD-6, The diff: "adds what's missing, removes what's extra". AD-6, Alarms in progress: "an alarm past its fire instant that is alerting or counting down … is never removed".
- **Problem:** the plan leaves out everything at or before `now`. The diff then removes anything pending that the plan doesn't contain. iOS doesn't move a notification from pending to delivered at the exact trigger instant, and an alarm can still be `.scheduled` a moment after its fire instant. The reconcile also reads `now` before it awaits the pending and alarm snapshots. Any request whose fire instant is at or before `now` but that is still pending is "extra" and gets removed. Alarm protection covers only `alerting` and `countdown`, not a `.scheduled` alarm a moment past its instant.
- **Concrete failure:** Firm's 7.5-minute interval puts nudges on 30-second boundaries, and chains fire every minute. Suppose a reconcile runs within a second or two of a fire instant (a foreground, a command or a time-change trigger). It removes that nudge, or that Urgent alarm, before it is shown. Its ledger row becomes `cancelled`, so History reads "couldn't be sent (the app wasn't opened)" even though the app was open. One build that snapshots before evaluating and another that evaluates first will show this at different rates.
- **Fix:** in AD-6, never remove a pending request, or an alarm in `.scheduled`, whose fire instant is at or before the snapshot time, unless its occurrence is closed, or the plan changed it before its instant (for example its reminder was deleted or paused). Otherwise leave it to deliver and to Cleanup. Alternatively, take `now` after the OS snapshots and treat items within a small grace period as already handed over.

### M2 — The layer table's import lists leave out SwiftUI, which AlarmKit's types need

- **Location:** Design Paradigm table, "May import". Shell: "NudgeCore, NudgeStore, NudgeLiveActivity, UserNotifications, AlarmKit, BackgroundTasks, UIKit (AD-18)". Live Activity: "NudgeCore, AppIntents, AlarmKit". Widget: "NudgeLiveActivity, NudgeCore, AlarmKit, ActivityKit, WidgetKit". UI: "all of the above, plus Accessibility".
- **Problem:** no row lists SwiftUI. `AlarmAttributes.init(presentation:metadata:tintColor:)` takes `tintColor: Color` *(verified: AlarmKit docs)*, and `AlarmButton` takes a text color. The shell's AlarmKit adapter, which builds alarms (AD-12, AD-18), can't construct them under its own import list. Read literally, the widget's SwiftUI Live Activity view and the app's views break the rule too. The table is meant to be an enforceable rule, but as written it is wrong. That leaves open which unit owns the tint and button colors: the shell, `NudgeLiveActivity`, or the app target passing them in.
- **Concrete failure:** one unit adds SwiftUI to `NudgeShell`. Another moves the presentation-building into `NudgeLiveActivity`. A third hard-codes the accent in two places. The alarm's tint (`{colors.accent-dark}`, EXPERIENCE › Nudge Surfaces) and the AlarmKit ID hash inputs (AD-7: "presentations, metadata") are then built in more than one place. Builds can disagree on IDs and replace every alarm on each reconcile.
- **Fix:** add SwiftUI to the Live Activity, Widget and UI rows. Put the construction of `AlarmPresentation`, `AlarmAttributes` and the tint in one place: `NudgeLiveActivity`, which already holds `NudgeAlarmMetadata`. The shell calls it. The tint should come from that target's asset catalog or a literal shared with DESIGN.md's token. If SwiftUI should stay out of `NudgeShell`, say so.

### M3 — Wall-clock `issuedAt` plus "reject if a later event exists" fails when the clock moves backward

- **Location:** AD-3: "`issuedAt`, stamped by `CommandSubmitting.submit` from the shell's injected `Clock`". AD-4: "rejects it if its occurrence already has a committed event other than a Clear … with a later `issuedAt`".
- **Problem:** `issuedAt` is wall-clock time, and every live command is judged against later-stamped committed events. The clock can move backward: the person sets the time manually, a tester changes it to try a schedule, or an automatic correction steps it back. After that, every new command on an occurrence with a later-stamped event is rejected until the clock passes that stamp. The significant-time-change trigger only reconciles, and it can't reverse this.
- **Concrete failure:** a tester sets the clock forward, snoozes (`issuedAt` 9:00), then sets it back to 8:20 and taps Done. `accepts` rejects Done because a snooze has a later `issuedAt`. The card keeps nudging and Done appears to do nothing for 40 minutes. The same can happen to a real user whose clock was wrong and is then corrected. Testers changing the device time is common in TestFlight.
- **Fix:** have `submit` stamp `issuedAt` as `max(clock.now, latest committed issuedAt + ε)` for live commands. Journaled and adopted commands keep their backdated stamps, which is the only case the later-event rule exists for (memlog D5). Or state that live commands are ordered by commit sequence and the rule applies only to journal replay and adoption. Add a test with a backward clock step.

## Low

1. **Chain at Not Done vs "next nudge one interval after reopening" (brief ambiguity).** Brief §4 lists "Not Done" among the moments a chain starts, and a chain sends "a Time Sensitive notification at once". Brief §3, Not Done, says "The next nudge comes one interval after reopening." AD-13 points to §4. The engine is one unit, so builds can't diverge, but the engine story has to pick one. Fix: have the brief owner say whether the chain after Not Done starts at reopening or at the next nudge one interval later. AD-6's at-once rule handles either.
2. **`NudgeQuerying` for History and Export: where the 90 days of facts come from.** AD-1 says History and Export call `evaluate` "with the coordinator's published inputs, a 90-day window". AD-20's published inputs cover the default window. A History unit could pass the published snapshot and show nothing older than yesterday. Fix: say that `NudgeQuerying` reads the window's facts from the store, and that only settings, capabilities and zone facts come from the published inputs.
3. **One database connection, and what "store change" means.** AD-20 refreshes on GRDB `ValueObservation`, and the app imports `NudgeStore`. GRDB observes only writes made through the same `DatabasePool` or `DatabaseQueue`. If a UI unit opens its own reader, it never sees the coordinator's writes. Separately, a raw observation can fire between a command's commit and its reconcile, before capabilities and zone facts are published. That conflicts with "evaluates only from the inputs the coordinator last published". Fix: the coordinator owns the single `DatabasePool` and publishes a snapshot once a job ends. `NudgeModel` observes that publication, not the tables.
4. **What `submit` returns before the first unlock.** AD-5 says `submit` "returns the command's outcome only after its job, reconcile included, has finished". When a command is journaled (AD-16), no job runs. Fix: name a `journaled` outcome that returns once the journal entry is written (and the follow-up posted).
5. **Routing a notification tap from the shell to the UI.** AD-17 says "tapping a nudge opens Now at its occurrence; tapping a follow-up opens the reminder". The delegate is in `NudgeShell` and navigation is in the app target, and the spine names no channel between them. Feature work can settle this as long as one unit owns it. Fix: one line saying that the shell publishes a pending deep link (occurrence key or reminder ID), and `NudgeModel` or the root view consumes it.
6. **AD-17 restates the brief's snooze lengths.** It says "one per snooze length brief §3 allows (5, 10, 15 and 30)". If §3 changes, the category list goes stale. Fix: "one per snooze length brief §3 allows", with the values left in the brief.
7. **Scene model is undecided.** Conventions › UI state assumes several scenes ("each scene has its own `SceneStorage`"). Memlog line 169 says "v1 is a single-scene iPhone app", and the Assistive Access scene is separate. Nothing decides `UIApplicationSupportsMultipleScenes`. Fix: state it in Environments, and make the UI-state convention match.
8. **Widget extension on iOS 18.** Every type in the Live Activity is `@available(iOS 26, *)` (AD-18), but the spine doesn't say whether the extension's deployment target is 26.0, or whether it stays at 18.0 with an availability-guarded `WidgetBundle`. That decision belongs to one unit, but CI and the first spike depend on it. Fix: one line under Stack or Environments.
9. **Operations: privacy manifest reasons and tester diagnostics.** The manifest declares only `UserDefaults` (`CA92.1`). If the `Clock`, the 50 ms benchmark or the marker-file code calls required-reason APIs (system boot time, file timestamps), the manifest has to grow *(unverified which APIs the code will use)*. There is also no decision on how testers send diagnostics beyond TestFlight feedback and crash reports. Fix: note that the manifest is re-checked whenever a required-reason API is added. Record "no in-app log export in v1" under Deferred.

## Checked and holding

- **Paradigm and AD-1/AD-2:** one pure fold. Statuses are derived, and How It Nudges, History, Export and Siri all go through `evaluate`. The window rule covers Not Done reopenings.
- **AD-3/AD-4:** command, journal and adoption ordering by (`issuedAt`, commit sequence). The rule for Clear events. `accepts` owns the whole write set and validation. One serial queue, with an adopted snooze enqueued rather than awaited, so it can't deadlock.
- **AD-5:** single writer, no App Group. `submit` is awaited before control goes back to iOS. Late or missing coordinator fails toward nudging. The iOS 26 extension-process question is in the first spike and the device checklist.
- **AD-6:** the at-once rule matches only a write in the job. Delivered notifications are never re-added. The answering rule for alarms excludes Clear. Adoption looks only at `.countdown` after the fire instant, never at absence. Echoes are ignored. Exceptions (Test Nudge, cancel-all, before-unlock follow-up) are listed.
- **AD-7:** IDs are deterministic and locale-free. AlarmKit IDs hash the configuration, so they are never reused. The nudge index comes from the plan item. Uniqueness has a test.
- **AD-8/AD-9:** due instants are frozen. The eastward gap rule is tested. Triggers are absolute. A `nil` trigger is used for past instants. The `nextTriggerDate()` zone test is in place.
- **AD-10–AD-13:** a closed `RepeatRule`. One fallback capability. Time Sensitive off is stated once. Every snooze is replaced by the engine's alarm, with the `.custom` fallback tied to a device check. Chain rules point to brief §4.
- **AD-14:** order from brief §4, a cut at 63 plus keep, an 8-day horizon, capacity learned in the same job and capped by protected alarms. The benchmark split between CI and the device is reasonable.
- **AD-15:** ledger rows are immutable apart from state. History's lines are derived. Restore detection uses two signals. Pruning is bounded by `prunable`.
- **AD-16:** opening is gated by protected data rather than error codes. The journal is title-free and renamed before replay. Replay is one job followed by one reconcile. The open-failure behavior matches EXPERIENCE › Any. Delete All keeps settings, matching brief §3.
- **AD-17–AD-20:** no authentication on any action. OS checks are confined to the shell and named wrappers (`AccessibilitySettings.isAssistiveAccessEnabled`, `Tab(role: .search)` on iOS 18+). The privacy floor matches brief §1/§7. One live model, with announcements from diffs.
- **Conventions:** integer-second durations (Firm 7.5 min, Relentless 2.5 min), Foundation tag key, one search matcher, a String Catalog per target, Siri tie-break and entity ID, Export format.
- **Coverage:** every brief §6 screen and §11 Q1–Q14 maps to an AD or convention. Keyboard shortcuts point to EXPERIENCE. The device table ties each device check to the decision it would change, and brief §10 stays the one list.
- **Deployment, environments, operations:** decided (Builds, TestFlight, App Store, entitlements, privacy manifest and label, CI runtimes with a fallback chain, signing, versions, crash reports, no infrastructure). Release automation and SQLCipher are deferred with reasons.
- **Deferred:** none of the items could let two units diverge. The view structure is constrained by named ADs, table names belong to one migration, and the iOS 27 APIs are deliberately not adopted.
- **Pointing, not restating:** precedence, Not Done windows, chain rules, month ends, Siri order and Delete All's kept settings all point to the brief or EXPERIENCE. The remaining restatements are the technical mappings in AD-11, plus Low 6.
- **Not re-verified this pass:** AD-12's fixed-schedule alarm with a pre-alert countdown (the memlog cites WWDC25-230; this pass's apple-rag search didn't surface it) *(unverified)*. Removing an alarm ends its Live Activity *(unverified)*.
