# Adversarial review: two compliant units that build incompatibly

Target: ARCHITECTURE-SPINE.md at 564b9fa. Lens: two units one level down, each obeying every AD to the letter. Effort went to text changed since 8c2ce98.

Verdict: the spine holds on queue, order, identity and journal, but two new-text gaps (at-once alarms, and what `NudgeQuerying` answers before and between publications) let compliant units diverge in scenarios a tester will hit.

Counts: critical 0, high 2, medium 3, low 2.

## H1. An at-once Urgent delivery is an alarm, and only notifications have a past-instant rule

Units: the AlarmKit adapter (NudgeShell) and the reconciler diff/ledger code (NudgeShell, Coordinator). Also the engine's plan item shape (NudgeCore).

Quoted text:
- AD-6: "The engine places such a delivery at the instant of the fact that caused it ... Examples are ... the nudge sent when an edit ends quiet hours early, and an occurrence an eastward zone change made due".
- AD-9: "alarms are `Alarm.Schedule.fixed`. No request uses a repeating, wall-clock or relative trigger. A notification whose fire instant is at or before `now` when it's added ... uses a `nil` trigger".
- AD-6 diff: "A pending request or alarm whose fire instant is at or before `now` is left alone, because it's firing."

Scenario: iOS 26, an Urgent reminder is held by quiet hours. The user edits quiet hours to end earlier. The nudge is due at the write's `issuedAt`, so the plan item is an alarm whose fire instant is already past when it's added. AD-9 gives a nil-trigger escape for notifications only.

- Build A: calls `AlarmManager.schedule` with `.fixed(date: issuedAt)`. That is a past date. Apple doesn't document what AlarmKit does with one (throw, ring, or silently drop).
- Build B: schedules `.fixed(now + 2 s)` so it rings. The alarm's fire instant now differs from the plan item's, so the ledger row's fire instant, the AlarmKit ID hash and AD-6's "which command answers an alarm" (events at or after fire instant) all differ from Build A's.

Why both comply: AD-9 forbids relative triggers but names no rule for a past-instant alarm. AD-11 says Urgent is "an AlarmKit alarm when `alarmsAvailable`" with no at-once exception.

Close: add one sentence to AD-9 or AD-12. Either an at-once alarm delivery is handed to AlarmKit as `.fixed` at `now` as read in step 1 (with the ledger row recording that instant), or an at-once delivery is always a notification with a nil trigger. Add a device-checklist row for whichever is chosen.

## H2. `NudgeQuerying` answers from "the latest published Evaluation", but when that exists and how old it is are unstated

Units: the Coordinator's `NudgeQuerying` implementation (NudgeShell) and the Siri intents (NudgeIntents). `NudgeModel` is the third reader.

Quoted text:
- AD-5: "`NudgeQuerying` answers from the coordinator's latest published `Evaluation`, so Siri sees what the screens see."
- AD-20: "`NudgeModel` evaluates only from the inputs the coordinator last published ... changing nothing but `now`" and refreshes "at the evaluation's `nextChangeAt`".
- AD-5 (launch): the coordinator is created and `NudgeQuerying` registered in `willFinishLaunching`; AD-6: launch triggers a reconcile.

Scenario: the app isn't running. The user asks Siri "what's nudging?" iOS launches the app process for the intent. The intent calls `NudgeQuerying` while the launch reconcile is still queued, so nothing has been published yet.

- Build A (coordinator): returns the empty or nil `Evaluation` it holds before the first publication. The Siri unit reads it as "nothing is nudging".
- Build B (coordinator): suspends until the first job ends. Siri answers correctly.

A second divergence arises when the app has been running. The published `Evaluation` carries the `now` of its last job. Build A returns it verbatim, so a reminder that began nudging an hour ago with no job since reads as "coming up". `NudgeModel` re-evaluates with a fresh `now` and shows it as nudging. Build B re-evaluates the published inputs at the current `now`, like `NudgeModel`.

Why both comply: "latest published" fixes the source, not its currency. `submit` has an explicit await rule, and `NudgeQuerying` has none. The brief wants Siri to answer what the screens show.

Close: state that `NudgeQuerying` awaits the first completed job after the store opens, and answers by evaluating the published inputs at the caller's `now` (the same function `NudgeModel` uses). Alternatively put that function in `NudgeCore` as the one shared re-evaluation. Say what it returns when the store is unavailable (as `submit` does).

## M1. History/Export read live store facts but take settings from the published inputs

Units: the `NudgeQuerying` History/Export path (NudgeShell) and the Coordinator publisher.

Quoted text:
- AD-1: "`NudgeQuerying`, which reads the window's facts from the store and takes settings, capabilities and zone facts from the coordinator's published inputs".
- AD-20: "the coordinator ... owns the one `DatabasePool`; nothing else opens a connection ... so a refresh never sees a command's rows before its reconcile".

AD-20's no-partial-view guarantee covers the model's refresh. History's read goes to the same pool at any moment, including between a command job's write transaction and its reconcile's ledger writes.

- Build A: reads facts through the pool directly, so it can see a just-committed quiet-hours version or event against the previous published settings.
- Build B: reads facts from the last published snapshot.

The two disagree for a few hundred milliseconds. Export taken from a Siri or Shortcut intent while a job is mid-flight could therefore show a nudge line with no ledger row yet ("the app wasn't opened"). Both comply.

Close: say that History and Export read inside the coordinator's job boundary, either as a read job on the queue or as a snapshot taken with the published inputs.

## M2. An edit's skip-by-edit event needs an occurrence row, and two owners can write it

Units: `NudgeCore.accepts` (returns the write set) and the Coordinator's materialization (AD-8).

Quoted text:
- AD-3: "`accepts` writes a `skip-by-edit` event as part of an edit that closes the occurrence".
- AD-4: "`accepts` returns the command's whole write set, inserts, updates and deletes (events, versions, tags, ...)"; "A command naming a valid projected occurrence key materializes it (AD-8)".
- AD-8: "the coordinator writes its row the first time either of these happens: a command names its key; a reconcile finds that it's due".

An Edit command names a reminder, not an occurrence key. If the open occurrence it closes is projected with no row (the app was closed since it fell due), the event has nothing to attach to.

- Build A: `accepts` includes the occurrence insert in the edit's write set.
- Build B: the coordinator materializes first because the occurrence is closing, then applies the write set. Or, since an edit "names no key", it writes no event.

Result: with Build B's second variant, the occurrence shows as still open (or later missed) after the edit.

The same text also gives the event no nudge index: AD-3 lists "the nudge index the surface showed" as a field of every event. An edit has no surface index; one unit writes 0 and another the count so far.

Mitigation: the foreground reconcile usually materializes due occurrences first, which keeps this medium.

Close: say that `accepts` returns the occurrence row for each occurrence it closes, and the skip-by-edit event's nudge index is nil.

## M3. The pending deep link has no owner type or home

Units: the notification delegate (NudgeShell) and `NudgeModel` (app target). This may predate the diff but is a shared-shape gap.

Quoted text: AD-17 "The delegate publishes the target (occurrence key or reminder ID) as a pending deep link that `NudgeModel` consumes." NudgeShell can't import the app target, and `NudgeModel` doesn't exist at cold launch when the tap arrives.

- Build A: the delegate stores the link on the `Coordinator` (a retained property), and `NudgeModel` reads it when created.
- Build B: the delegate posts a `NotificationCenter` notification or sets an observable on a shell singleton that `NudgeModel` observes after it appears.

Build B drops the link on a cold start from a tap (the main flow), because no observer exists yet. Either build is fine for a warm app.

Close: name the type in `NudgeCore` and say it's held by the coordinator until consumed.

## L1. issuedAt "never earlier than the latest committed event's": scope and read point

Units: `submit` (NudgeShell) and any handler stamping before calling it.

Quoted text: AD-3 "stamped by `CommandSubmitting.submit` ... when it's called (never earlier than the latest committed event's ...)"; journal replay "keeps the entry's".

- Build A clamps against the latest event across the whole store (pause and resume included).
- Build B clamps against the latest event of the command's occurrence.

Both read committed state at submit, which isn't in the queue. Outcomes differ only after the clock has been set back, so this is low. The text also doesn't say how `submit` reads committed events before the database opens (before the first unlock). Journaled entries are stamped with no clamp, and replay's `accepts` can then reject a post-unlock-clock-set-back Stop. Say the clamp is per-occurrence and reads inside the job (after dequeue) when the store is open.

## L2. First settings facts' saved instants

Units: the first migration (NudgeStore) and the coordinator's first zone fact.

Quoted text: AD-16 "The first migration writes the default quiet-hours version ... The coordinator writes the first zone fact before the first `evaluate`, which treats a missing quiet-hours version or zone fact as an error". AD-3: versions "carry the instant they were saved".

- Build A: the migration stamps `distantPast`.
- Build B: the migration stamps its own wall time.

A History window reaches 90 days back. For an instant before B's stamp there is "no version in effect", which `evaluate` calls an error. The brief bars past one-offs, so such instants carry no occurrences and the engine can skip them, which keeps this low. Say the first versions apply from the beginning of time.

## What held

- Single queue, `accepts` as the one gate with a whole write set, and reconcile-after-every-command: no second write path found.
- `skip-by-edit` counted in later-event rejection removes a double-close between an edit and a stale Done.
- The reconcile order in AD-6 matches the sequence diagram, and `jobWrites` matches the at-once rule for notifications.
- Adoption is enqueued, not awaited, so the queue can't deadlock. Zone-fact-then-evaluate order closes the earlier gap.
- Categories: `nudge-<minutes>` covers the snooze lengths in brief §3 (5, 10, 15, 30 min; defaults 30, 15, 5), all whole minutes, so no fractional-name clash. `nudge-final` and `followup` names are fixed in one place.
- One `DatabasePool` owned by the coordinator, with AD-20's refresh at end of job, stops the model seeing a command's rows before its reconcile.
- Before-unlock follow-up: `submit` posts under the planned ID, and replay writes its ledger row; no double post found.
- Single scene plus the AssistiveAccess scene with `SceneStorage` matches the UI-state convention. Widget imports are consistent with AD-5's widget rule.
- Delivery-ID identity, frozen due instant, journal replay and snooze adoption were not broken by the new text.
