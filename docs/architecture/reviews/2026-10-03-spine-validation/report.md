# Architecture spine validation: Nudge-inator

Validated: `docs/architecture/ARCHITECTURE-SPINE.md` on branch `docs/align-precedence-and-mockup`, 2026-10-03. Validate only: no edits.

**Verdict:** the paradigm and structure hold, and the lint is clean, but the spine isn't yet safe to build from: 2 critical and 13 high findings (after merging overlaps) would let units diverge. 6 of them come from edits made on this branch; the rest predate it.

Reviewers: deterministic lint (0 findings); rubric walker (0 C / 6 H / 11 M / 10 L); technology currency (0 C / 2 H / 4 M / 6 L); adversarial unit pairs (2 C / 8 H / 5 M / 2 L).

## Critical and high (merged)

| Tier | Finding | Where | Fix | Origin | Reviewers |
|---|---|---|---|---|---|
| Critical | **Delivered notifications and the reconciler's diff**. The plan doesn't say whether it holds deliveries that already fired. Leave them out and the diff deletes a nudging occurrence's delivered nudges; keep them and it re-posts cleared nudges, the Done follow-up and rung-out alarms. | AD-6, AD-14 | The plan holds only future deliveries; the diff compares it with pending requests and alarms only; delivered notifications are never re-added; the Done follow-up is added once, checked against the ledger. | Before this branch | Adversarial C1; Rubric H4 |
| Critical | **An alarm's intent can't recover the delivery ID it answers**. Alarm metadata carries only the occurrence key and nudge index, and the AlarmKit ID is a one-way UUIDv5. A snooze intent records nudge/<key>/<n> while the alarm counting down is snooze/<key>/<n>/1, so today's dedupe never matches and counts twice. | AD-7 vs AD-6 (dedupe added today) | Put the full delivery ID string in alarm metadata and notification userInfo (AD-7). | This branch | Adversarial C2; Rubric M5 |
| High | **Snooze adoption adopts the engine's own post-snooze alarm**. The engine's post-snooze alarm has a pre-alert countdown, so it can sit in .countdown with a different delivery ID from the snooze that was committed: phantom snoozes that use up the cap. | AD-6 (today) with AD-12 | Adopt only alarms the plan doesn't itself count down (exclude snooze/<key>/<n>/<s> the plan holds). Whether a .fixed alarm with preAlert reports .countdown is worth confirming in the docs. | This branch | Rubric H2 |
| High | **Durations in integer minutes can't hold 7.5 and 2.5 minutes**. Brief §3's Firm and Relentless intervals include 7.5 and 2.5 minutes. | Conventions › Durations | Integer seconds in the model and engine. | Before this branch | Rubric H1 |
| High | **No engine entry point for past occurrences**. evaluate reads only each reminder's open or latest occurrence, so My Day's Done/Missed counts, Last 24 Hours, Assistive Access 'Done today', History and Export would each derive past statuses themselves. | AD-14 with AD-1, AD-20 | Add a named NudgeCore history function (or widen evaluate's window). | Before this branch | Rubric H3; Adversarial H7 |
| High | **AlarmKit placement contradicts AD-18, and NudgeShell needs NudgeLiveActivity**. AD-18 confines AlarmKit to app-target wrappers, but the layer table puts it in NudgeShell and NudgeLiveActivity; NudgeShell may not import NudgeLiveActivity yet needs its NudgeAlarmMetadata and intents to schedule an alarm. | Layer table vs AD-18 | Move NudgeAlarmMetadata and the intent types to a target both can import (or allow the dependency), and align AD-18 with the table. | Before this branch | Rubric H5, H6 |
| High | **`swift test` on macOS can't build the package**. AlarmKit and ActivityKit have no macOS; swift test builds every target, so the engine test job fails with the iOS-only targets. | Testing convention, Structural Seed, CI | Split Core and Store into their own package, guard iOS-only targets with canImport, or run those tests through an xcodebuild scheme. | Before this branch | Currency H1; Rubric M6 |
| High | **Which process runs a shared-package intent**. Apple's docs say a LiveActivityIntent runs in the app's process (verified), but WWDC26 session 345 says intents in a package shared by app and extension are routed by heuristic: the extension is launched if the app isn't running (verified). AD-5 says only the app opens the database. | AD-5 | Widen the first spike to where the intent runs; on iOS 27 pin the app with ExecutionTargets. | Before this branch | Currency H2 |
| High | **Commands from the app, Siri and Assistive Access answer no delivery**. 'A command about it' means different things to different units: one build leaves the alarm ringing, another counts the snooze twice. | AD-3, AD-6 | Define which delivery each command source answers, or how commands without one map to the alarm in progress. | This branch | Adversarial H1 |
| High | **Event order and what accepts() sees are undefined**. Today's adoption and journal replay write backdated events; folding by issuedAt vs commit order gives different results. | AD-3, AD-4 | State the fold order (issuedAt, then commit order) and the facts accepts() evaluates against. | This branch | Adversarial H2 |
| High | **AD-8 freezes the due instant from a ledger fire instant**. When quiet hours hold nudge 1, the fire instant is 7:00, not the 3:00 due time; the command payload that should carry the instant is undefined. | AD-8 | Freeze from the computed due instant, carried in the command payload. | Before this branch | Adversarial H3; Rubric M4 |
| High | **Live model and coordinator can evaluate with different inputs**. NudgeModel and the Coordinator can call evaluate with different time zone and permission inputs. | AD-20, AD-4 | One published input snapshot both read. | Before this branch | Adversarial H4 |
| High | **The journal drops `source`**. Replay can't tell an alarm's Stop from a notification's Done; both answer nudge/<key>/<n>. | AD-16 | Add source to journal entries. | This branch | Adversarial H5 |
| High | **`alarmCapacity` has no starting value; the limit doesn't replan in the job**.  | AD-14, AD-11 | Give alarmCapacity an initial value and replan within the same job on maximumLimitReached. | Before this branch | Adversarial H6 |
| High | **Chain IDs can collide when a chain restarts**. A chain restarted after a snooze with the same startNudge reuses chain/<key>/<startNudge>/<k> IDs still in the delivered list, so they're never sent; a chain row's nudge index is ambiguous. | AD-7, AD-13, AD-15 (today) | Include a chain-run ordinal in chain IDs and give each row its nudge index explicitly. | This branch | Adversarial H8 |

## Medium and low

Rubric: 11 medium, 10 low. Currency: 4 medium, 6 low. Adversarial: 5 medium, 2 low. Full text in the review files:

- review-rubric.md
- review-currency.md
- review-adversarial.md

## Added from the narrow edge-case pass on the documentation branch

These were routed here by the owner for the Update run (not fixed on the documentation branch).

| Where | Finding | Fix |
|---|---|---|
| AD-4 | The extra nudge after Not Done at the limit with no channel (notifications off, no alarm) is never delivered, so its miss interval never starts and the occurrence stays open. | Count the interval from the planned fire instant when there's no channel. |
| AD-15 | A row with channel none past its fire instant shows as scheduled in History until the next reconcile settles it. | History treats a channel-none row past its fire instant as undeliverable, whatever its state. |
| AD-6 | Several snoozes before the first unlock, all under one delivery ID, adopt as one snooze, so 'at worst one extra snooze' can be wrong. | Adopt one snooze per observed countdown cycle (key on delivery ID plus the countdown's fire instant), or state that only one is counted. |
