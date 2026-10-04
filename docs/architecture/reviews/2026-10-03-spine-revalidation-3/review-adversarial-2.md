# Adversarial review 2: compatible-but-incompatible units (last fixes, 564b9fa..2dd32dc)

Target: ARCHITECTURE-SPINE.md at 8adaf14. Scope: the 10 changed lines, attacked in context.
Counts: critical 0, high 2, medium 4, low 4.

## HIGH

### H1. The at-once alarm is cancelled by the next reconcile inside its 5-second lead
Units: Reconciler/engine job (NudgeShell Coordinator) and the trigger sources (zone-change observers, foreground, a second command).

Quoted text:
- AD-6: "It also holds what a write in the same job made due at once. The engine places such a notification at the instant of the fact that caused it, and such an alarm that instant plus 5 seconds".
- AD-1: `jobWrites` "are the instants of writes committed in the current job".
- AD-6: "Before its fire instant, an alarm follows the plan like any other".
- AD-4: "several pending ones coalesce".

Scenario: an eastward flight lands with the app open. `NSSystemTimeZoneDidChange` and significant time change both fire.
- Reconcile 1 writes the zone fact at T and plans the made-due Urgent occurrence as an alarm at T+5. It is handed to AlarmKit and gets a ledger row.
- Reconcile 2 starts at T+0.2 with empty `jobWrites`. The engine now sees the nudge as having fallen due at T, which "matches no write, so it isn't sent late". The plan has no delivery for it.
- The pending alarm at T+5 is in no plan and is before its fire instant, so it is "extra". The diff removes it and its row goes `cancelled`. It never rings.

The same happens with an edit that ends quiet hours early (Urgent), when any second job (foreground, a Done on another card) lands within 5 seconds.

Build A: the trigger source enqueues a reconcile for every notification that arrives while one is running. It is not "pending", so nothing coalesces. The alarm is dropped.
Build B: the trigger source drops a trigger that arrives while a reconcile is running (also "coalescing"). The alarm rings.

Why both comply: AD-4 coalesces only pending jobs, and nothing says whether a trigger during a running reconcile counts. Nothing in AD-6 lets the plan keep an alarm already handed over for a write from an earlier job.

Notifications are immune (nil trigger, never pending). Only alarms lose, and brief §4 Urgent is the alarm channel. A nudge is silently lost.

Close: extend the at-once rule to keep an alarm whose ledger row is `scheduled`, whose fire instant is in the future, and which was placed by the at-once rule. Alternatively, treat an alarm within `alarmLead` of a committed write's instant as in progress until its fire instant.

### H2. The clock-back clamp covers only occurrence events, but pause, resume, edit and quiet hours are rejected the same way
Units: `CommandSubmitting.submit` (clamp) and `accepts` (NudgeCore), with the form, Pause, Resume and quiet-hours handlers.

Quoted text:
- AD-3: "never earlier than the latest committed event of the command's occurrence, read inside the job after it's dequeued, so setting the clock back can't make `accepts` reject a new command".
- AD-4: `accepts` "rejects it if its occurrence already has a committed event ... or its reminder a committed pause or resume, with a later `issuedAt`".
- AD-4: "A version's saved instant is the command's `issuedAt`".

Pause, Resume, edit and quiet-hours commands have no occurrence, so the literal clamp is empty for them.

Scenario: a tester pauses a reminder at 10:00, sets the clock back to 09:00, and taps Resume or edits the reminder.
- Build A (literal): no clamp. Resume's `issuedAt` is 09:00, earlier than the pause's 10:00, so `accepts` rejects it. The user sees nothing happen. An edit is also rejected for the reminder's pause/resume.
- A second case: edit at 10:00, clock back, edit again at 09:00. Build A saves the new version with saved instant 09:00. Version order is by saved instant, so the older 10:00 version stays in effect and the new edit is silently ignored. The same happens to a quiet-hours change.
- Build B: clamps every command to the latest committed fact of the entity it touches (reminder's events and versions, quiet-hours versions). The command applies.

Why both comply: the clamp text names only "the command's occurrence". Both builds read "never earlier than the latest committed event of the command's occurrence" the same way, then differ on what a command without an occurrence does.

The stated purpose of the clamp ("setting the clock back can't make `accepts` reject a new command") fails for every reminder-level command.

Close: say the clamp is per entity the command touches: occurrence events, a reminder's pause/resume and versions, quiet-hours versions.

## MEDIUM

### M1. A slow job behind the command puts the at-once alarm's fire instant in the past
Units: Reconciler diff, AlarmKit adapter.

Quoted text:
- AD-6 step 1: "Take `now` once".
- AD-6 step 7: "A pending request or alarm whose fire instant is at or before `now` is left alone, because it's firing."
- AD-6: "that instant plus 5 seconds (`alarmLead` ... because AlarmKit's behavior for a past `.fixed` date is undocumented)".
- AD-3: `issuedAt` is stamped "when it's called".

`issuedAt` is stamped at the call, but the job may wait behind a reconcile or an Export read. If `now` at step 1 is more than 5 seconds after `issuedAt`, the plan still holds the alarm (the instant equals a committed write's instant plus `alarmLead`), but its fire instant is already past.

Build A: adds the alarm with the past `.fixed` date, which is the case `alarmLead` was meant to avoid.
Build B: reads step 7's "at or before `now` is left alone" as covering plan items, and never adds it. The alarm never rings, and there is no ledger row.

Why both comply: step 7 names pending requests and alarms. The plan-item case has no rule, unlike notifications, which get AD-9's nil trigger. The clamp can also push `issuedAt` earlier than `now` by any amount.

Close: for an alarm whose fire instant is at or before `now` at add time, say what to do. For example, re-time it to `now + alarmLead` and record that instant on the row. The row fire instant is "never changes", so choose that value at plan time.

### M2. `NudgeQuerying` waits for "the first job after the store opens", which is undefined when no replay job exists or protected data is still locked
Units: `NudgeQuerying` (Coordinator) and Siri/App Entity queries (NudgeIntents).

Quoted text:
- AD-5: "`NudgeQuerying` waits for the first job to finish after the store opens".
- AD-4: "plus the journal replay that runs first once the store opens".
- AD-6: launch trigger is "from `scenePhase` or the `UIApplication` notifications".
- AD-5: `submit` "when the store failed to open it returns store unavailable at once".

Scenario A, cold start by a Siri query ("what's nudging?"), app not running, no journal.
- Build A: always enqueues the replay job, even with an empty journal. The query completes.
- Build B: skips replay when there is no journal. With no scene, no scene-phase or foreground trigger fires. No job runs, and the query waits for a job that never comes (`submit`'s job, if any, is also the first job, but a pure query has none). Siri hangs until it times out.

Scenario B, query before first unlock (Siri needs no authentication): the store has not opened and has not "failed".
- Build A: waits until the first unlock.
- Build B: answers store unavailable at once.

Why both comply: "when the store is unavailable it says so, as `submit` does" can read either way for the locked state. `submit`'s own rule distinguishes "failed to open" and "journaled".

Close: the query waits for the first job only if one is guaranteed (the replay job always runs, and the launch registration enqueues an initial reconcile). While protected data is unavailable, it returns store unavailable.

### M3. History/Export read jobs can block `submit`'s await rule for a long time
Units: Export/History (app target via `NudgeQuerying`) and every source that awaits `submit` (notification delegate, intents).

Quoted text:
- AD-5: "History and Export reads run as read jobs on the queue".
- AD-4: "Each job runs to completion, including its awaits, before the next starts."
- AD-5: "Every source awaits it before handing control back to iOS ... the notification delegate before its completion handler".

Build A: the read job only reads the window's facts, then evaluates and encodes outside the queue. Short.
Build B: the whole Export (90-day `evaluate`, JSON encoding, file write) is the job body. With 200 reminders, a Done from a notification or Siri waits behind it. The delegate's completion handler is late, and the stale-action case grows.

Why both comply: "reads run as read jobs" doesn't say where the work after the read happens. The 50 ms benchmark covers the default window only.

Close: say a read job covers only the store read, returning the facts, and that evaluation and encoding run off the queue.

### M4. A `DeepLink` held in the Coordinator has no stated consume trigger when `NudgeModel` already exists
Units: notification delegate/Coordinator (NudgeShell) and `NudgeModel` (app target).

Quoted text:
- AD-17: "The delegate hands the target ... to the `Coordinator`, which holds it until `NudgeModel`, created later on a cold launch, consumes it."

Cold launch is the only case written. Warm cases (app open and the user taps a banner; app suspended) are left open.
- Build A: `NudgeModel` consumes a pending link when it creates itself, when the coordinator publishes, and on foreground. A tap on a banner while the app is open (`willPresent` shows banners) triggers no job and no foreground, so the link sits until the next publish (up to `nextChangeAt`).
- Build B: the Coordinator exposes an observable property or callback, and the model navigates at once.
- Also: A keeps one slot (the latest tap wins), B queues. Two taps before the model exists open different targets.

Close: state that the model observes the coordinator's pending link (not only polls on publish), and that it holds one slot, last tap wins.

## LOW

- L1: skip-by-edit "with no nudge index". The event table's nudge-index column can be nullable (Core writes nil) or NOT NULL with 0 meaning none. Export shows `null` or `0`. A schema detail the first migration owns, and the Store and Core units can settle it by one reading.
- L2: "in effect from the beginning of time". Store can write `Date.distantPast`, `Date(timeIntervalSince1970: 0)` or a nullable start. Export and `prunable` may meet the odd value, which only matters if quiet-hours versions are exported or pruned (AD-15 doesn't say).
- L3: the clamp's "latest committed event" can include a Clear (Build A) or exclude it like `accepts` does (Build B). Event order differs by one Clear under clock-back. No status changes.
- L4: `NudgeQuerying` evaluates "published inputs at the caller's `now`" while History reads facts in a queued read job. Build A snapshots the published inputs at the call, B at job start. If a quiet-hours edit commits between them, History mixes new facts with old settings. Settings include versions per AD-14, so the effect is a one-job-stale nudge line.

## What held

- The `DeepLink` type in `NudgeCore` and the Coordinator as holder: a single owner, no second process.
- `NudgeQuerying` using the same `NudgeCore` function as `NudgeModel`: Siri and screens can't diverge in rules.
- skip-by-edit counting in AD-4's later-event rejection, plus the occurrence row written in the same `accepts` write set: no two writers for the row; the occurrence key supplies its due instant (AD-8).
- The clamp being read inside the job: a queue-delayed command can't be stamped below an event committed while it waited, for occurrence events.
- The first quiet-hours version being in effect from the start: removes a "no version at this instant" gap for evaluating old facts.
- Notifications made due at once: nil trigger plus the same-instant rule is consistent and never pending.
