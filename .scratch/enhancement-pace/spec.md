Status: ready-for-agent

# Nudge-inator enhancement: pace

## Problem Statement

A reminder's strength decides both how fast it nudges and how loud. The only rhythm on offer is one that speeds up as the nudging goes on, so I can't have a steady "every 15 minutes" reminder, and a loud reminder always comes with the fast rhythm. Relentless is meant for the reminder that must get through, yet its first three nudges are Time Sensitive notifications that a Focus can hold, and its Break through Focus switch can be turned off, which makes it quieter than a Firm reminder with the switch on.

## Solution

Each reminder gets a **pace**: **Escalating** (the strength's own waits, which shrink, exactly as today) or **Consistent** (one wait the person picks, the same between every nudge). Strength keeps deciding how each nudge arrives and the give-up limit. A **Default pace** in Settings, shipped as Consistent every 10 min, is what every new reminder starts with; each reminder then keeps its own. **Relentless** nudges only with alarms, from nudge 1, under either pace, and always breaks through Focus.

Vocabulary is in `GLOSSARY.md` (Pace, Escalating, Consistent, and the updated Strength, Break through Focus and Locked). The decision is ADR 0004; ADR 0002 now locks pace too. The screens follow a proposed pace mockup, made from an as-built mockup of the app as it is today. The first-version mockup is superseded and moves to the mockup archive for the record.

## User Stories

### Mockups

1. As the developer, I want an as-built mockup that matches the app as it is today, checked against simulator screenshots, so that the record of the shipped design is true.
2. As the developer, I want the first-version mockup archived and marked superseded, so that it stays as history without being mistaken for today's design.
3. As the developer, I want a proposed pace mockup copied from the as-built one and changed only for pace, so that the change is visible against the current app.
4. As the developer, I want to approve the proposed mockup before any of the work is implemented, engine or UI, so that I see what it looks like first.

### How an Escalating reminder nudges

5. As a person, with an Escalating pace I want a Gentle or Firm reminder to nudge exactly as it does today, so that nothing I rely on changes.
6. As a person, with an Escalating pace I want a Relentless reminder to keep today's waits (10, 5, 2.5, then 2 min), so that only how it arrives changes, not when.

### Relentless only rings

7. As a person, I want every Relentless nudge, from the first at the due time, to be an alarm, so that a Relentless reminder always rings.
8. As a person, I want a Relentless reminder always to break through Focus, so that a Focus can never hold it.
9. As a person, when alarms are denied I still want Relentless nudges to arrive as Time Sensitive notifications, or ordinary ones when Time Sensitive is off, so that I get something rather than nothing.
10. As a person, when the alarm limit is reached I want Relentless nudges past it to fall back the same way, marked "too many alarms scheduled", as Urgent nudges do today.
11. As a person, I want the permission banners to say what can still reach me with Relentless's new delivery, so that the reach they describe stays true.

### How a Consistent reminder nudges

12. As a person, with a Consistent pace I want the first nudge at the due time and each later nudge exactly one wait after the one before, so that the rhythm is predictable.
13. As a person, with a Consistent pace I want the strength to keep deciding how each nudge arrives (Gentle: notifications, Time Sensitive from nudge 5; Firm: notifications, Time Sensitive at nudge 3, alarms from nudge 4; Relentless: alarms), so that a steady rhythm can still be quiet or loud.
14. As a person, I want Relentless to nudge only with alarms under Consistent as well as Escalating, so that the pace never makes Relentless quieter.
15. As a person, I want a Consistent reminder to give up after 20 nudges or 24 hours, whichever comes first, the same as Escalating, so that one rule decides when a nudge counts as Missed.
16. As a person, with a long wait (say 16 h) I want the reminder to give up at 24 hours after the due time, so that a long wait can't nudge into the next day.
17. As a person, I want a Consistent reminder's last nudge to leave me one full wait to answer before it closes as Missed (unless the 24 hours run out first), as Escalating does.
18. As a person, I want Stop on a Consistent reminder's alarm to silence that ring only, with the next nudge still coming one wait later, so that Stop means what it means today.
19. As a person, I want Done to end a Consistent reminder's nudging, as for any reminder.
20. As a person, I want a repeating Consistent reminder whose next occurrence comes due while it is still nudging to close as Missed and hand over, as today.
21. As a person, I want Pause and Resume to work on a Consistent reminder as they do today.

### Locked while nudging

22. As a person, I want a Nudging reminder's pace, and its Consistent wait, locked like its strength, so that an edit can't reshape a schedule that is already running.

### Choosing a pace in the form

23. As a person, I want to choose a pace for each reminder, Escalating or Consistent, so that I decide the rhythm separately from how loud it is.
24. As a person, I want the pace choice right under Strength in the reminder form, so that the two decisions about how it nudges sit together.
25. As a person, I want choosing Consistent to reveal an Every row, so that I only see a wait to pick when it matters.
26. As a person, I want the Every row to offer 2, 5, 10, 15 and 30 min and 1, 2, 4, 8, 12 and 16 h, so that I can pick anything from "answer me now" to "a few times a day".
27. As a person, I want choosing Escalating to hide the Every row, so that the form doesn't offer a choice that has no effect.
28. As a person, I want a reminder to remember the wait I chose even if I switch to Escalating and back before saving, so that toggling doesn't lose my choice.
29. As a person, I want the reminder details to show the pace, and the wait when it is Consistent, so that I can see how a reminder nudges without opening the form.

### Relentless in the form

30. As a person, when I choose Relentless in the form I want Break through Focus shown on and not editable, with a short footnote saying Relentless always rings, so that I understand why I can't turn it off.
31. As a person, when I switch a reminder from Relentless to Firm or Gentle I want the Break through Focus switch editable again, keeping its previous value, so that the switch I set isn't lost.

### Locked rows in the form

32. As a person, I want the locked Pace and Every rows to look and read like the other locked rows, so that the lock is consistent.

### How It Nudges

33. As a person, I want How It Nudges in the reminder form to show the nudges for the chosen pace and strength, so that I can see what I'm choosing before I save.
34. As a person, I want How It Nudges on reminder details to show the reminder's own pace.
35. As a person, I want the line under Strength in the form, and How It Nudges' summary sentence, to describe the chosen pace, so that the words never contradict the table.

### Default pace in Settings

36. As a person, I want a Default pace row in Settings, so that I set once how my new reminders nudge.
37. As a person, I want it to start as Consistent · 10 min, so that a new reminder nudges at a steady rhythm out of the box.
38. As a person, I want the Default pace row to use the same Pace and Every controls as the form, so that it works the way I already know.
39. As a person, I want every new reminder to start with the Default pace, whether I make it with + on Now, My Day or a tag's list, so that the default holds everywhere.
40. As a person, I want changing the Default pace never to change a reminder I already have, so that my existing reminders keep nudging the way I set them.
41. As a person, I want the Default pace to survive the app being closed and relaunched, so that I set it once.
42. As a person, I want Delete All Data to set the Default pace back to Consistent · 10 min, so that it really is a fresh start.
43. As a person, I want How It Nudges in Settings to show each strength under the Default pace, so that the page matches what a new reminder will do.

### Accessibility and language

44. As a VoiceOver user, I want the Pace control read as a picker with its value, and the Every row read with its wait, so that I can set them without seeing them.
45. As a VoiceOver user, I want the disabled Break through Focus switch read as on and dimmed, with the footnote's reason reachable, so that I know why it can't change.
46. As a person using large text, I want the Pace control to become a menu at accessibility sizes, as other segmented controls in the app do, so that it doesn't truncate.
47. As a person using another language later, I want every wait written by the system's duration formatting, so that "16 h" reads correctly in my language.

### Beta install

48. As a beta tester, I want to run Delete All Data and reinstall cleanly to get this version, so that no old reminder or leftover alarm survives into it.

## Implementation Decisions

- **Pace is a reminder field in the engine.** `Reminder` gains a pace: Escalating, or Consistent carrying one wait from the fixed list of 11. The list is part of the engine, so the form, Settings and tests all read the same choices.
- **Strength's ladder splits in two.** The waits come from the pace: Escalating uses the strength's existing ladder constants (initial wait, factor, floor), and Consistent uses its one wait. Urgency steps (`highFrom`, `urgentFrom`) stay on the strength. Nudge times and give-up time are worked out from the reminder's pace and strength together, not from the strength alone.
- **Relentless's urgency** is Urgent from nudge 1. Its ladder constants for waits are unchanged.
- **Relentless forces Break through Focus.** The engine's delivery rule treats a Relentless reminder as breaking through Focus whatever its stored switch says, so a stored `false` can't make it quieter. The form also shows the switch on and disabled for Relentless. The stored value is left as the person last set it, so switching back to Firm or Gentle restores it.
- **Fallback is unchanged.** Urgent nudges that can't ring still fall back to Time Sensitive, then ordinary notifications; the reach and banners follow from that with no new rule.
- **Give-up limit** is unchanged: 20 nudges or 24 h for both paces.
- **Lock.** Pace joins the engine's locked fields. Changing between Escalating and Consistent, or changing a Consistent wait, is rejected while an occurrence is Nudging.
- **How It Nudges read-out** takes the pace as well as the strength and Break through Focus switch, and its rows fold the same way (a Consistent reminder's equal waits fold into one row per urgency).
- **Default pace** is an app setting, kept in `UserDefaults` like the onboarding record, read when a new reminder draft is made. It is Consistent · 10 min when nothing is stored. Delete All Data clears it.
- **Storage.** The stored reminder record gains its pace (kind and wait). No migration: beta testers reinstall cleanly. Delete All Data before uninstalling also clears leftover AlarmKit alarms, which uninstalling doesn't remove.
- **Form.** A Pace segmented control (Escalating | Consistent) under Strength, following DESIGN.md's segmented control (a menu at accessibility sizes). Consistent reveals an Every row. The draft keeps the last chosen wait while Escalating is selected. Relentless shows Break through Focus on and disabled with a footnote.
- **Settings.** A Default pace row in the Nudges section, with the same two controls.
- **Where pace shows:** the form, reminder details and Settings. Not on Now or My Day rows, nor in alarm or notification text.
- **Strings.** New strings go through the String Catalogs with comments. Waits are formatted with Foundation's duration formatting in the locale.
- **Mockups.** The as-built mockup is an HTML copy of the first-version mockup, changed to match the app as built and checked against simulator screenshots in portrait, landscape and large text. The proposed mockup is a copy of the as-built one changed only for pace. The first-version mockup moves to the archive with its README saying it is superseded. All implementation, engine and UI, starts only once the proposed mockup is approved; the UI is built to it.

## Testing Decisions

- A good test drives a public entry point and checks what the person would see: when nudges fire, how urgent they are and how they arrive, what is locked, what a new draft holds. It doesn't reach into private helpers or the ladder constants.
- **Engine, through the plan.** Give the engine reminders and check the scheduler's last plan: each nudge's fire time, urgency and delivery. This covers Consistent waits for each choice, give-up for short and long waits (2 min gives up after 40 min; 16 h nudges twice and gives up at 24 h), Relentless Urgent from nudge 1 under both paces, a stored Break through Focus `false` ignored for Relentless, Gentle and Firm under Consistent keeping their urgency steps, and the alarm-limit and permission fallbacks for Relentless. Expected values are worked out by hand. Prior art: the ladder, give-up limit, Break through Focus, alarm-limit fallback and permission fallback suites.
- **Engine, How It Nudges and the lock.** The read-out under each pace, and pace edits rejected while Nudging. Prior art: the How It Nudges and lock-while-nudging suites.
- **App, store.** A reminder's pace survives a save and reload. Prior art: the reminder store suite.
- **App, form.** A new draft starts with the Default pace (from +, and from a tag's list); choosing Relentless turns Break through Focus on and disables it, and leaving Relentless restores it; the wait survives switching to Escalating and back. The Default pace record is injected. Prior art: the reminder form suite and the onboarding record's tests.
- **App, Default pace.** Reads Consistent · 10 min when nothing is stored, and Delete All Data clears it.
- `scripts/test.sh` runs everything on the `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` simulators (chosen in ticket 01; the Mac also offers 27.1, left out for now). The iOS 26.1 simulator is dropped from the matrix for now; the deployment target stays iOS 26.1.
- **Visual changes are checked on the simulators first.** A story that changes something on screen has its visual criteria checked on both simulators in the test matrix (above), in portrait, landscape and large text (the simulator screenshots recipe), before anything runs on the iPhone. Once those criteria pass there, the developer is offered a run on the iPhone and chooses whether to take it.
- **Device checks** that simulators can't cover stay on the iPhone (recording its iOS version), after the simulator pass: a Relentless reminder rings as an alarm at its due time under a Focus; a Consistent reminder's second nudge comes one wait after the first; VoiceOver reads the Pace control, the Every row and the disabled switch correctly; the Pace control turns into a menu at accessibility text sizes.

## Out of Scope

- A different wait between each nudge, or a free-form wait picker.
- A give-up limit that depends on the pace.
- Migrating existing reminders.
- Showing pace on Now or My Day, or in alarm and notification text.
- Retuning Gentle's or Firm's ladders, or Relentless's waits.
- A fourth strength.

## Further Notes

- This release goes to two beta testers only, who will run Delete All Data and reinstall.
- The mockups come first. No implementation, engine or UI, starts until the proposed mockup is approved, so the change is seen before it is built.
- The as-built mockup can use the existing simulator screenshots recipe for its checks.
