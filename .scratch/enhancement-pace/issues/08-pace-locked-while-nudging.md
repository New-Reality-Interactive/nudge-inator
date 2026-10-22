# 08: Pace locked while nudging

**What to build:** While a reminder is Nudging its pace, and its Consistent wait, are locked like its strength (ADR 0002). The engine rejects an edit that changes either, and the form shows the Pace and Every rows locked, looking and reading like the other locked rows. Spec stories 22 and 32.

**Blocked by:** 07b (it locks the form's Pace control).

**Status:** ready-for-agent

- [ ] Engine: pace is a locked field while an occurrence is Nudging; an edit switching Escalating and Consistent, or changing the wait, is rejected; it is allowed again once the occurrence closes.
- [ ] Form: the Pace and Every rows of a Nudging reminder are locked as in the proposed mockup, and the other editable fields (title, notes, tags) still save.
- [ ] The lock note, in the form and on reminder details, reads "Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them."
- [ ] Simulators (26.5 and 27.x): the locked rows in portrait, landscape and large text.
- [ ] VoiceOver reads the locked rows as the other locked rows read.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a Nudging reminder's Pace row can't be changed (phone and iOS version recorded).

## Before you start

- Builds on: ticket 07b (merged, PR #50): the form's `paceChoice` and `consistentWait` (`App/ReminderForm/PaceChoice.swift`) make the draft's `pace`, and `PaceSection` in `ReminderFormSheet.swift` draws the Pace control and the Every row, with no lock yet. Ticket 07b's Comments: at accessibility sizes the Pace section has no header and the menu row carries the label, as Strength's does. The Standards review left Pace and Strength's shared heading-and-menu code for this ticket, since the lock touches both. The engine's lock is `LockedField` in `Engine.swift` (`dueTime`, `repeatRule`, `strength`, `breakThroughFocus`, each with `isChanged(from:to:)`); its tests are `LockWhileNudgingTests`.
- Watch for: a new `LockedField` case reaches every `switch` over it. The form's `restoreLockedFields(from:)` must put back both `paceChoice` and `consistentWait`. Mockup item 7: the Pace header and the Every row carry the `lock`, the control is dimmed, and the Every value is plain text without the menu's arrows, like Repeat's locked row (`RepeatRow`). The lock note has three copies: the form's top note, `LockNote.hint` (the VoiceOver hint) and the details' Schedule footer. The seed's Take the bins out is Consistent · 30 min and Nudging, so the `form-edit-locked` and `details-nudging` shots show the lock.
- Developer stops: agree the `tdd` seams (the engine rejecting a pace or wait change while Nudging, the form restoring both); the simulator pass in `scripts/screenshots.sh`; VoiceOver on the locked Pace and Every rows; the offered iPhone run.

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the lock note naming pace. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 7.
