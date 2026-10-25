# 07: Rename PreviewScheduler, which ships in Release

**What to build:** Rename `PreviewScheduler` to `NoOpScheduler` everywhere, so the name says what the type does. It's a `SchedulerAdapter` whose `apply(_:)` does nothing. Ticket 01 took `#if DEBUG` off it, because shipping code uses it: the How It Nudges page builds an engine with it when it has no model, and the strength sections' preview helper does too. The Release archive failed to compile without that. A type named `PreviewScheduler` that ships in Release reads as preview-only code, and someone could put it back under `#if DEBUG` and break the archive again. No behaviour change, and nothing else moves. `PreviewClock` stays where it is, under `#if DEBUG`.

The seven files that name it are `App/Design/PreviewSupport.swift`, `App/Details/ReminderDetailsPreviews.swift`, `App/HowItNudges/HowItNudgesPage.swift`, `App/HowItNudges/HowItNudgesSection.swift`, `App/MyDay/MyDayPreviews.swift`, `App/Now/NowPreviews.swift` and `App/ReminderForm/ReminderFormPreviews.swift`. The type's doc comment says what it does and why it isn't behind `#if DEBUG`, and drops the "previews' engines" framing. The file keeps its name unless a better one is obvious.

No `tdd`: the ticket has no behaviour, and the compiler and the Release archive are its check. No screenshots: nothing changes on screen. Brian chose the rename over keeping the name and its comment (ticket 01, Comments).

**Blocked by:** 01.

**Status:** ready-for-agent

- [ ] No `PreviewScheduler` remains under `App/`, `NudgeWidgets/`, `Packages/` or `NudgeInatorTests/` (a grep shows none).
- [ ] `NoOpScheduler`'s doc comment says what it does and why it ships in Release.
- [ ] `PreviewClock` is still inside `#if DEBUG`.
- [ ] `xcodebuild archive` of the `NudgeInator` scheme in Release succeeds, with no export or upload. This is the check that caught the original failure.
- [ ] `scripts/test.sh` passes on both simulators.

## Comments

- Filed 2026-10-25 from ticket 01's review. It blocks ticket 06 (the first build), so it merges before the first archive. Ticket 06's `Blocked by` now lists 07 too, and its Comments say so.
- It edits `PreviewSupport.swift`, which ticket 01 changed, so ticket 01 merges to `main` first.
- Model and effort: the "Mechanical: config, a docs follow-up, criteria that leave no judgement" row of `docs/agents/ticket-workflow.md`: Sonnet 5.5, medium.
