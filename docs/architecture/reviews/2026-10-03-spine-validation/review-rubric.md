# Rubric walker review: ARCHITECTURE-SPINE.md (2026-10-03, after hand edits)

Spine: `docs/architecture/ARCHITECTURE-SPINE.md` (460 lines). Read against `.memlog.md`, brief §1–§11, addendum §B/§E/§F, EXPERIENCE.md (Foundation, State Patterns, Nudge Surfaces, Assistive Access, Siri, Responsive, Open Items).

**Verdict:** the spine is structurally sound. The paradigm, the single queue, the derived status and the identity scheme hold together, and the cross-references to AD numbers and brief sections all resolve. The hand edits have left six high-severity problems, though. One convention can't represent the brief's own intervals. Two dependency or layering rules contradict the layer table. Two reconciler rules misfire on the engine's own deliveries. And the engine's input scope doesn't cover the screens AD-20 says must read only from it. No critical issues.

| Tier | Count |
|---|---|
| Critical | 0 |
| High | 6 |
| Medium | 10 |
| Low | 10 |

---

## High

### H1. Conventions › Durations: integer minutes can't hold the brief's intervals
- **Location:** Consistency Conventions, "Durations" row ("Integer minutes in the model and engine").
- **Problem:** brief §3's strength table has intervals of 7.5 min (Firm) and 2.5 min (Relentless). Integer minutes can't represent them.
- **Why it matters:** this is a hard contradiction between the spine and the nudging rules it binds. One implementer will round (to 7/8 or 2/3), another will switch to seconds or `Double`. The 50-minute and 2 h 12 min totals in the brief, How It Nudges and the scheduler would then drift apart, which is exactly what AD-1 exists to prevent.
- **Fix:** "Integer **seconds** in the model and engine (brief intervals include 7.5 and 2.5 min); `TimeInterval` only at the OS adapters." Alternatively, use a fixed-point minute type with half-minute resolution.

### H2. AD-6's snooze adoption would adopt the engine's own post-snooze alarm
- **Location:** AD-6 "Uncounted snoozes", together with AD-12 "The post-snooze alarm … has a pre-alert countdown so the Live Activity shows".
- **Problem:** AD-6 adopts any alarm for an open occurrence that is in AlarmKit's `.countdown` state and has no committed `snooze` carrying *that alarm's* delivery ID. The engine's own replacement alarm, `snooze/<key>/<n>/<s>`, is planned with a pre-alert countdown, so it sits in `.countdown` while the snooze runs. The snooze that created it was committed with the delivery ID it *answered* (`nudge/<key>/<n>`, or the previous `snooze/…/<s-1>`), not with `snooze/<key>/<n>/<s>`. So the dedupe check fails, and the next reconcile commits a phantom `snooze(source: .alarmCountdown)`. That burns one of the 3 snoozes and moves the later alarms again, and it repeats.
- **Why it matters:** this is the main alarm path on iOS 26+. A single person-initiated snooze would count as two or more and remove Snooze early.
- **Fix:** limit adoption to alarms in `.countdown` that the current plan does **not** itself contain as a pre-alert countdown, i.e. "never adopt an alarm whose delivery ID is in the plan as a countdown alarm". Equivalently, adopt only when the OS alarm's state differs from the planned state. Add a test: snooze → reconcile → reconcile, and the snooze count must stay at 1. Also confirm with the verification reviewer that a `.fixed` alarm with `preAlert` really reports `.countdown`. (If it doesn't, AD-12's own Live Activity claim fails, which is a separate problem.)

### H3. AD-14's input scope for `evaluate` doesn't cover what AD-1 and AD-20 require it to derive
- **Location:** AD-14 "What `evaluate` reads" ("current and future versions, plus each reminder's open or latest occurrence and the facts since then. History screens read past facts separately"), against AD-1 ("Any code that needs a … status, count … gets it from `NudgeCore`") and AD-20 ("Views read derived state only from [the Evaluation]").
- **Problem:** several v1 surfaces need the status of closed occurrences that aren't a reminder's *latest*:
  - My Day's Done and Missed counts and rows for today (for example, Stretch break at 10 AM and 2 PM, both closed before 4 PM)
  - Now's Last 24 Hours
  - Assistive Access "Done today"
  - Reminder details history
  - Export

  `Evaluation` doesn't contain them, and the layer table lists no other engine entry point (`evaluate`, `accepts`, `prunable`, Siri order only).
- **Why it matters:** each feature team will derive past statuses (done, missed by takeover, missed at limit, skipped) on its own from raw events. That is the drift AD-1 forbids, and My Day's counts could disagree with History.
- **Fix:** either widen `evaluate`'s window to "every occurrence due since the start of yesterday in the current zone, plus each reminder's latest" (covers Now's Last 24 h, My Day and Assistive Access), or add a named pure function `NudgeCore.history(reminder, facts, settings) -> [OccurrenceRecord]` that History and Export must use. List it in the Core row of the layer table and bind it in AD-1.

### H4. AD-6 re-posts a Done follow-up the person has cleared
- **Location:** AD-6 "The diff" (diffs only against the OS, "never against the ledger"; "adds what's missing") with AD-12 (`followup/<key>` "sent at once") and AD-17 (the `followup` category has no `customDismissAction`, so a Clear isn't recorded).
- **Problem:** while the Not Done window is open (until the next due time, or 24 h for a one-off), every evaluate plans `followup/<key>` as an immediate delivery. If the person clears it from Notification Center, it is neither pending nor delivered. The next reconcile sees it as missing and posts it again, at launch, on foreground and after every command, for up to 24 h. The same holds for any planned delivery whose instant is now or in the past.
- **Why it matters:** this is a user-visible nag loop on the confirmation notification, and it directly contradicts "the reconciler diffs only against the OS".
- **Fix:** add a rule to AD-6 that the plan contains only deliveries whose fire instant is after `now`, except an immediate delivery that has no ledger row yet. Equivalently: "a delivery whose ledger row is past its fire instant is never re-added". This makes one narrow, named exception to "never against the ledger". Say it in AD-6 and AD-12.

### H5. AD-18 confines AlarmKit to the app target, but the layer table puts it in two NudgeKit targets
- **Location:** AD-18 "iOS 26-only APIs: used only inside named wrappers in the app target: … AlarmKit", against the layer table (`NudgeShell` imports AlarmKit; `NudgeLiveActivity` imports AlarmKit and holds `NudgeAlarmMetadata` and the alarm intents) and the Widget row (ActivityKit / `AlarmAttributes`).
- **Problem:** the rule can't be followed as written. The AlarmKit adapter, the reconciler's `AlarmManager` diff and the alarm intents all live outside the app target.
- **Why it matters:** an enforceability gap. A reviewer applying AD-18 literally would reject the AlarmKit adapter, and one following the table would scatter `#available` across targets with no named boundary, which is the divergence AD-18 says it prevents.
- **Fix:** rewrite AD-18's list by target:
  - **NudgeShell:** AlarmKit only in the `AlarmScheduling` adapter, behind `@available(iOS 26, *)`.
  - **NudgeLiveActivity:** the whole target is `@available(iOS 26, *)`.
  - **NudgeWidgets:** the alarm Live Activity is iOS 26+.
  - **App target:** named view wrappers for `tabBarMinimizeBehavior`, `navigationSubtitle` and the `AssistiveAccess` scene.

### H6. `NudgeShell` can't build alarms without depending on `NudgeLiveActivity`
- **Location:** layer table, Shell row ("May import: NudgeCore, NudgeStore, UserNotifications, AlarmKit, BackgroundTasks"), and the mermaid graph (Shell → Store, Core only).
- **Problem:** scheduling an alarm requires an `AlarmConfiguration` typed on `AlarmAttributes<NudgeAlarmMetadata>`, plus `stopIntent` and `secondaryIntent` instances. Per the table, all three live in `NudgeLiveActivity`, which the Shell may not import.
- **Why it matters:** the first implementer of the AlarmKit adapter has to break the import rule or move the metadata type. Two units would then disagree about where `NudgeAlarmMetadata` lives, and the widget, which renders from it, depends on that answer.
- **Fix:** add `NudgeLiveActivity` to Shell's imports and add `Shell --> LA` to the graph. Alternatively, move `NudgeAlarmMetadata` into `NudgeCore` (but the intents still need constructing). While editing, also add `Security` (Keychain install marker, AD-15) and `os` (AD-19) to the relevant rows.

---

## Medium

### M1. AD-18 "UIKit only for `UITabBarAppearance`" can't be followed either
- **Location:** AD-18 "UIKit".
- **Problem:** several rules elsewhere in the spine need UIKit symbols:
  - **Notification delegate:** it must be assigned before launch finishes so background action launches are delivered (AD-5), which in SwiftUI means a `UIApplicationDelegateAdaptor`.
  - **Reconcile triggers (AD-6):** `significantTimeChangeNotification` and `protectedDataDidBecomeAvailableNotification` are `UIApplication` notifications.
  - **iOS 18 Assistive Access:** the check is `UIAccessibility.isAssistiveAccessEnabled`.
  - **Open Settings:** it uses `UIApplication.openSettingsURLString`.
- **Why it matters:** the rule is wrong as written, so people will ignore it, and then it constrains nothing.
- **Fix:** "UIKit only in the shell's app-lifecycle adapter (`UIApplicationDelegateAdaptor`, the `UIApplication` notifications, the Settings URL), `UIAccessibility.isAssistiveAccessEnabled`, and `UITabBarAppearance` on iOS 18."

### M2. AD-6's "Exceptions" says the journaled follow-up is never removed, but it has to be
- **Location:** AD-6 "Exceptions" ("both outside the reconciler's namespace and never removed by it"), against AD-6 Cleanup ("removes … expired Done follow-ups"), AD-16 (the stop intent posts `followup/<key>`) and brief §11 Q13 ("removed … by AD-6's cleanup").
- **Problem:** the journaled follow-up uses the same `followup/<key>` ID that the engine plans after replay. It is inside the namespace, and brief Q13 relies on AD-6 removing it. Only `test/…` is truly outside.
- **Why it matters:** two rules contradict each other. An implementer who follows "never removed by it" leaves a stale follow-up with a dead **Not Done** button.
- **Fix:** "Send a Test Nudge's `test/…` is outside the reconciler's namespace. The before-first-unlock follow-up is posted under its planned ID `followup/<key>`, and once the journal is replayed the reconciler owns it like any other delivery."

### M3. AD-14 posts no keep-nudging notice when the 8-day horizon runs out
- **Location:** AD-14 "The plan is cut to 63 requests, plus 1 keep-nudging request at the fire time of the first dropped nudge".
- **Problem:** if the plan stops at the 8-day horizon before the budget fills, no nudge is "dropped", so no `keep/` request is planned. If the app isn't opened (and background refresh doesn't run) for 8 days, nudging stops silently. Brief §4 places the notice "at the time its scheduled nudges run out", whatever the reason.
- **Why it matters:** silent stop is the failure the brief ranks worst ("a reminder that never nudges").
- **Fix:** "… plus 1 keep-nudging request at the earlier of the first dropped nudge and the first delivery past the horizon."

### M4. AD-8 has no source for the frozen instant in one of its own triggers
- **Location:** AD-8 "Its instant" ("frozen from that delivery's ledger row, or from the command's payload if there's no row").
- **Problem:** a reconcile can materialize an occurrence because "it's due" when it has no ledger row and no command, for example:
  - its nudge 1 was cut by the budget or past the horizon
  - its rows were marked `lost` after a restore
  - the app was installed or opened late

  Also, AD-16's journal format (kind, key, nudge index, delivery ID, `issuedAt`) and AD-3's event fields carry no due instant, so "the command's payload" isn't defined.
- **Why it matters:** implementers will pick different fallbacks (current zone, or the zone fact at the time), and that is the flight double-ring AD-8 exists to prevent.
- **Fix:** "… otherwise resolve the key's wall time in the zone fact in effect at that wall time (AD-3)." And either state that commands carry the due instant or drop "command's payload".

### M5. Intents can't record "the delivery ID it answered" from what AD-7 puts on a delivery
- **Location:** AD-7 "One owner" ("Every notification's `userInfo` and every alarm's metadata carry the occurrence key and nudge index"), against AD-3 (events record the answered delivery ID) and AD-6 (dedupes on it).
- **Problem:** an alarm's ID is a one-way UUIDv5. Key plus nudge index can't tell `nudge/<key>/<n>` apart from `snooze/<key>/<n>/<s>`, and a chain notification's `chain/<key>/<start>/<k>` can't be rebuilt from the key and current nudge number alone. The stop and snooze intents and the notification delegate have no reliable way to fill in the delivery ID that AD-6's dedupe depends on.
- **Fix:** "Every notification's `userInfo`, every alarm's metadata and every alarm intent's parameters carry the full delivery ID string (plus key, nudge index and, for alarms, the title)."

### M6. CI's macOS `swift test` versus the package's iOS-only frameworks
- **Location:** Structural Seed CI line ("swift test, xcodebuild test…"), the folder tree ("NudgeCore … swift test on macOS"), the layer table.
- **Problem:** `NudgeKit` also contains `NudgeShell` (AlarmKit, BackgroundTasks, UserNotifications on iOS), `NudgeLiveActivity` (AlarmKit) and `NudgeIntents`. AlarmKit and BGTaskScheduler aren't available on macOS, and `swift test` builds the package's targets for the host. As described, the macOS run either fails to build or needs guards nobody has specified.
- **Why it matters:** the CI design and the package layout are both mandated and they conflict. Each target author would invent their own `#if canImport` scheme.
- **Fix:** state the mechanism. Either: (a) `NudgeCore` and `NudgeStore` sit in their own package (or test plan) that builds for macOS, and the rest is tested with `xcodebuild` on simulators; or (b) every iOS-only import is wrapped in `#if canImport(AlarmKit)` / `#if os(iOS)` as a convention. Add it to the First spike.

### M7. AD-14's 50 ms benchmark can't be enforced where the tests run
- **Location:** AD-14 "Cost" and Conventions › Testing ("the 50 ms benchmark").
- **Problem:** the target is "on the oldest iPhone that runs iOS 18", but the benchmark runs under Swift Testing on macOS or simulators in CI, which can't measure an iPhone XS.
- **Fix:** set a CI proxy budget (for example, under 10 ms on the GitHub macOS runner for the 200-reminder fixture) as the enforced test. Add "evaluate under 50 ms on an iOS 18 minimum-spec device" to brief §10's device checklist.

### M8. AD-11's "ask once on launch" overlaps with onboarding's alarm prompt
- **Location:** AD-11 Urgent ("When AlarmKit is available and authorization is `.notDetermined` (an iPhone updated from iOS 18), the shell asks once on launch").
- **Problem:** a fresh install on iOS 26 is also `.notDetermined`. Brief §6 First launch and EXPERIENCE › Any want Welcome, then notifications, then alarms in onboarding, with no Welcome only for the update case. The condition in the rule doesn't tell the two apart, so the shell and the onboarding flow could both prompt, or prompt before Welcome.
- **Fix:** "… the shell asks once on launch only when the onboarding-done flag is set (an update from iOS 18). Otherwise onboarding asks."

### M9. Deployment envelope: the "one list" of keys has no privacy manifest
- **Location:** Structural Seed › Environments › Entitlements and keys. Addendum §F calls this "the one list".
- **Problem:** the app uses `UserDefaults` (a required-reason API) and may use file-timestamp APIs through the store. App Store Connect requires a `PrivacyInfo.xcprivacy` declaring these, plus the "Data Not Collected" privacy label that matches AD-19. Neither is on the list, and the list is what the setup story will copy.
- **Fix:** add "`PrivacyInfo.xcprivacy` in the app and widget targets (UserDefaults CA92.1; tracking false; no collected data), and App Privacy label 'Data Not Collected'". Flag GRDB's bundled manifest for the verification reviewer.

### M10. Ledger and history: nudges cut by the budget leave no trace
- **Location:** AD-15 "What's recorded" ("every delivery the reconciler schedules gets a ledger row …").
- **Problem:** brief §4 says a nudge that can't be delivered "still counts … and its history shows each nudge that couldn't be sent". Channel `none` covers permission loss. But a nudge the engine counts that was never scheduled, because it fell outside the 63-slot budget or the horizon while the app stayed closed, gets no row. History would then show a gap: nudge 3, then nudge 9.
- **Why it matters:** History and the engine's nudge count disagree, and a feature team will fill the gap ad hoc.
- **Fix:** at the first reconcile after a planned delivery's fire instant, write a row (state `undeliverable`, reason `notScheduled`) for every engine-counted nudge in the elapsed interval that has no row. Or state explicitly that History lists engine-derived nudges, annotated with ledger data where it exists.

### M11 (medium–low). AD-3's `source` list has no value for the alarm's Snooze button
- **Location:** AD-3 Events, `source` values.
- **Problem:** `alarmStop`, `alarmCountdown` (adoption) and `liveActivity` exist, but the alarm's secondary (Snooze) intent has no source. Implementers will reuse `alarmStop` or `app`, and History can't say "Snoozed from alarm".
- **Fix:** add `alarmSnooze` (or rename to `alarm` and record the action kind separately).

---

## Low

1. **AD-13 chain end conditions:** "It ends early on Done, Snooze or the start of quiet hours" reads as complete, but brief §4 also stops everything at any close (give-up time limit reached mid-chain, takeover, Pause, Delete, a skipping edit). Fix: "… or when the occurrence closes for any reason."
2. **AD-4 vs AD-6 on stale commands:** AD-4 reconciles only "if it applies"; AD-6 triggers "after every command". EXPERIENCE › Nudge Surfaces › States needs a stale action to clear its delivered notification. Pick one. Suggest: every command job ends with a reconcile.
3. **AD-11 exception scope:** "The one extra nudge after Not Done at the limit is the exception (AD-4)" sits under Urgent and doesn't say whether it is an exception to the chain only (per AD-4, with alarms available it is still an alarm). Fix: "is the exception to the chain fallback (AD-4)".
4. **Conventions › Export, "sent ledger rows":** "sent" isn't an AD-15 state. Fix: "the ledger rows History shows (AD-15), including `undeliverable` ones."
5. **AD-12 pre-alert vs AD-9 "alarms are `Alarm.Schedule.fixed`":** if the post-snooze alarm is built as a countdown alarm (`preAlert`, no schedule), it breaks AD-9's absolute-trigger rule. If it's `.fixed` plus `preAlert`, say so explicitly. This is for the verification reviewer, and it feeds H2.
6. **AD-5 wording:** "Siri and App Shortcuts intents run in the app target", while the layer table puts them in the `NudgeIntents` package target. Say "run in the app process".
7. **Deferred vs device checklist:** Deferred says "revisit AD-14 if the alarm limit is very low", while the device-checklist paragraph and brief §10 tie the alarm limit to AD-11. Also, Deferred gives no revisit target for "intents after force-quit" (AD-12). Align them.
8. **Frontmatter `binds`** omits brief §10, which the precedence order ranks with §3/§4 and which holds the device checklist the spine defers to. The ER diagram's `OCCURRENCE_EVENT` label also omits not done and skip-by-edit.
9. **Uncovered small feature mechanics (brief §3, §5, §6):**
   - **Deleting one reminder or one tag:** no AD or convention says what is removed, or that it reconciles. AD-16 covers only Delete All, and "events are append-only" invites the question.
   - **Search matching:** no rule for title, notes and tag matching (case and diacritic folding). Search, the Tags tab's "Find tags" and Siri entity queries could diverge. Suggest reusing the Tags convention's Foundation folding.
   - **Keyboard shortcuts:** ⌘N/⌘F/⌘1–4 (brief §5) aren't mapped.

   One line each in Conventions or the Map would close these.
10. **Operational envelope details:**
    - **Not decided:** signing (automatic signing; CI builds unsigned for tests), build and version numbering, the `BGTaskSchedulerPermittedIdentifiers` identifier value.
    - **Crash and diagnostic channel:** "TestFlight and App Store Connect crash reports" is in the memlog (line 41) but not in the spine.
    - **Store won't open for a reason other than lock** (failed migration, corruption): the app has no defined behavior, and commands would journal forever.
    - **Conventions › Testing** doesn't cover brief §11 Q10's "iPad running the iPhone app, both orientations", although the Map points Q10 there.

---

## Checked and holding
- **Cross-references:** every AD number cited inside the spine (AD-4/6/7/8/11/12/13/16), the brief's citations of the spine (§4 → AD-12; §10 → AD-6, AD-11, AD-12, AD-14, AD-15, AD-16; §11 Q7 → AD-9; Q13 → AD-12/16/6), EXPERIENCE › State Patterns › Any, and Conventions › UI state ↔ AD-16 all resolve and agree.
- **Precedence:** the spine and EXPERIENCE point to the brief introduction, which gives the ranked order. The memlog's older Q5 order is superseded (memlog line 69).
- **Time Sensitive off:** stated once in AD-11 and once in brief §4. They're consistent.
- **Time zones:** AD-9 (iPhone zone only), AD-3 (zone facts), AD-7 (no zone mode) and Conventions › Time are consistent after the edit. No leftover zone-mode wording.
- **Delete All Data:** AD-16, brief §3 and EXPERIENCE › Settings agree on what is kept.
- **Coverage:** brief §6 features and §11 Q1–Q14 each map to an AD or convention, apart from the low-tier gaps above. The operational envelope (environments, no infrastructure, CI, TestFlight → App Store, manual release with automation deferred) is decided or deferred, apart from M9 and Low 10.
- **Named tech** (Xcode 27.0 27A266a, Swift 6.4, GRDB 7.11.1, iOS 27 `appEntityIdentifier` beta status) is left to the verification reviewer.
