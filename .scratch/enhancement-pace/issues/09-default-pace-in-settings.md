# 09: Default pace in Settings

**What to build:** Settings gets a Default pace row, Consistent · 10 min out of the box, using the same Pace and Every controls as the form. Every new reminder starts with it, whether made with + or from a tag's list, and keeps its own pace from then on, so changing the default never moves an existing reminder. It survives relaunch, and Delete All Data sets it back. This ticket also writes the beta note that testers run Delete All Data and reinstall. Spec stories 36–42 and 48.

**Blocked by:** 08.

**Status:** ready-for-agent

- [ ] The Default pace is Consistent · 10 min when nothing is stored, and a chosen one survives relaunch.
- [ ] A new reminder draft starts with the Default pace from every place one is made: + on Now, + on My Day, and + on a tag's list.
- [ ] Changing the Default pace leaves every existing reminder's pace as it was.
- [ ] Delete All Data sets the Default pace back to Consistent · 10 min.
- [ ] Settings' Nudges section has the Default pace row with the form's controls, as in the proposed mockup.
- [ ] The Default Pace row reads "Consistent · 10 min" and opens a Default Pace page with the form's Pace and Every controls and the note "New reminders start with this pace. Changing it doesn't change the reminders you already have."; the screenshot harness walks to that page.
- [ ] Simulators (26.5 and 27.x): the row in portrait, landscape and large text; VoiceOver reads it as the form's controls read.
- [ ] A beta note, where the testers will see it, says to run Delete All Data and then reinstall to get this version.
- [ ] Offered to Brian, after the simulator pass: on an iPhone, a new reminder starts with the Default pace he set (phone and iOS version recorded).

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the Default Pace row opening its own page, and the harness reaching it. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 12.
