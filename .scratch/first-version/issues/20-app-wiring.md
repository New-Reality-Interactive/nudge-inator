Status: ready-for-agent

# App wiring: engine, store and adapters together

## What to build

The composition root. On launch, on foreground, on notification actions and on every user event, build the engine's inputs from the store, the clock and the adapters' permission states; feed the event; persist the resulting occurrence state; hand the plan to the notification and AlarmKit adapters. The "app opened" event runs reconciliation (ticket 07). Done from a notification action goes through here. Expose an observable app model the screens bind to.

## Acceptance criteria

- [ ] Integration test (fake clock, in-memory store, fake adapters): create a Relentless reminder, advance time, see the plan applied to both fakes; send Done, see both fakes cleared and the store updated.
- [ ] Relaunch test: tear down and rebuild the model from the store; occurrence state and plan are the same.
- [ ] Permission change from an adapter re-plans.
- [ ] Notification Done action and Open intent both end up as events through this one path.
- [ ] No Apple framework types leak into `NudgeEngine`.

Blocked by: 16, 17, 18
