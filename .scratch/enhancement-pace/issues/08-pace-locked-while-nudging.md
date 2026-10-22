# 08: Pace locked while nudging

**What to build:** While a reminder is Nudging its pace, and its Consistent wait, are locked like its strength (ADR 0002). The engine rejects an edit that changes either, and the form shows the Pace and Every rows locked, looking and reading like the other locked rows. Spec stories 22 and 32.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] Engine: pace is a locked field while an occurrence is Nudging; an edit switching Escalating and Consistent, or changing the wait, is rejected; it is allowed again once the occurrence closes.
- [ ] Form: the Pace and Every rows of a Nudging reminder are locked as in the proposed mockup, and the other editable fields (title, notes, tags) still save.
- [ ] The lock note, in the form and on reminder details, reads "Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them."
- [ ] Simulators (26.5 and 27.x): the locked rows in portrait, landscape and large text.
- [ ] VoiceOver reads the locked rows as the other locked rows read.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a Nudging reminder's Pace row can't be changed (phone and iOS version recorded).

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the lock note naming pace. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 7.
