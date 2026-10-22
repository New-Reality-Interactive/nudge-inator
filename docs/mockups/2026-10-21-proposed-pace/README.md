# Nudge-inator iOS mockup: proposed pace

The pace changes (enhancement-pace, version 1.1.0) drawn before any of them is built. It's a copy
of the [as-built mockup](../2026-10-21-as-built/README.md), changed only for pace and for
Relentless, so the two can be compared screen by screen. The enhancement-pace tickets build to it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. On a desktop
it shows a phone with **Mockup controls** beside it, in portrait or landscape. On a phone the app
fills the screen and the controls are below it.

The words are in [GLOSSARY.md](../../../GLOSSARY.md) (Pace, Escalating, Consistent), the decision in
[ADR 0004](../../adr/0004-pace-is-separate-from-strength.md), the stories in the
[spec](../../../.scratch/enhancement-pace/spec.md), and the tokens in
[DESIGN.md](../../design/DESIGN.md). Everything this README doesn't list is as the as-built mockup
draws it.

## How nudging works here

- **Pace**, per reminder: **Escalating** uses the strength's own waits, which shrink (Gentle 1 hr
  easing to 20 min, Firm 30 min to 5, Relentless 10 min to 2), as today. **Consistent** uses one
  wait between every nudge: 2, 5, 10, 15 or 30 min, or 1, 2, 4, 8, 12 or 16 hr.
- **Strength** still decides how each nudge arrives: Gentle is Normal, then High from nudge 5; Firm
  is High at nudge 3 and Urgent from nudge 4; **Relentless is Urgent from nudge 1**, so every nudge
  rings, under either pace.
- **Give-up limit:** 20 nudges or 24 hours, whichever comes first, for every strength and pace. A
  16 hr wait nudges twice and gives up 24 hours after it was due.
- **Break Through Focus**, per Gentle or Firm reminder, works as before. **Relentless always breaks
  through**, whatever its switch was set to.
- **Default Pace** in Settings is what every new reminder starts with: Consistent · 10 min.
  Changing it doesn't change existing reminders. Delete All Data puts it back.
- **With alarms off**, an Urgent nudge (so every Relentless nudge) is one Time Sensitive
  notification, or an ordinary one with Time Sensitive off, as before.

## What changed from the as-built mockup

**The reminder form**

1. A **Pace** section sits right under Strength: a segmented control, Escalating | Consistent. At
   the accessibility text sizes it's a menu row, as Strength's is.
2. Choosing Consistent shows an **Every** row under it, a menu of the 11 waits ("10 min", "1 hr",
   "16 hr"). Escalating hides it. The form keeps the chosen wait while Escalating is chosen, so
   switching back finds it again.
3. The line under Strength now says only how the strength arrives, then the give-up limit:
   "Rings as an alarm from nudge 4.", "Every nudge rings as an alarm." (Relentless) or "Never
   rings as an alarm." The waits moved under Pace, so the two lines can't disagree: "Every 30 min
   at first, down to every 5 min." (Escalating) or "Every 10 min, from when it's due."
   (Consistent). This replaces the first sentence of the as-built README's item 27.
4. A new reminder starts with the Default Pace, from + on Now, My Day or a tag's screen.
5. With **Relentless**, Break Through Focus shows on and dimmed, and its footnote says
   "Relentless always rings, so it always breaks through a Focus." Choosing Firm or Gentle again
   gives the switch back as it was.
6. The note on the Edit form of a reminder that isn't nudging says "A new strength, pace or Break
   Through Focus setting applies from the next nudge."

**Locked while nudging** (ADR 0002 now locks pace too)

7. The Pace header and the Every row carry the lock, the Pace control is dimmed, and the Every
   value is plain text without the menu's arrows, like Repeat's. The lock note on the form and on
   the details reads "Start, repeat, strength, pace and Break Through Focus are locked while it's
   nudging."

**Reminder details**

8. Schedule has a **Pace** row, between Next and Break Through Focus: "Escalating" or
   "Consistent · 30 min".
9. The Break Through Focus row says On for a Relentless reminder.

**How It Nudges** (the form, details and Settings' page)

10. The rows follow the pace. A Consistent reminder's equal waits fold into one row per urgency:
    "Nudges 1–2 when due, every 10 min", "Nudge 3 at +20 min, then waits 10 min", "Nudges 4–20 at
    +30 min, every 10 min". The summary's span follows: "20 nudges over 3 hr, 20 min", or "2
    nudges over 24 hr" with a 16 hr wait. Long waits can end before High, Urgent or a third nudge,
    so the summary can say "Both nudges are notifications." and "During a Focus, every nudge
    waits, unless you allow Nudge-inator in that Focus.", and the line under Strength "Never rings
    as an alarm."
11. Relentless is one row, "Nudges 1–20 when due", Urgent, Alarm, and "All 20 nudges ring as
    alarms."

**Settings**

12. A **Default Pace** row, between Send a Test Nudge and How It Nudges, reads "Consistent · 10
    min" and opens a Default Pace page with the form's Pace and Every controls and the note "New
    reminders start with this pace. Changing it doesn't change the reminders you already have."
13. The How It Nudges page draws each strength at the Default Pace, and its intro says so: "Below
    is how each strength nudges a new reminder at your Default Pace, Consistent · 10 min, with
    Break Through Focus on."
14. The footer under Nudges gains "Every Relentless nudge is Urgent."

**Words that described the old Relentless or the old rhythm**

15. The notifications-off banner: "Only Urgent nudges can reach you, as alarms: every Relentless
    nudge, and a Firm reminder's from nudge 4 with Break Through Focus on. Gentle reminders can't
    reach you at all."
16. The alarms-off banner: "Urgent nudges, and so every Relentless nudge, now come as Time
    Sensitive notifications, which silent mode can mute."
17. Onboarding (and the top of Settings' How It Nudges page): "Reminders keep coming back until
    you tap Done: at a steady pace, or more often and more insistently." and "Each Gentle or Firm
    reminder has a Break Through Focus switch. Turn it off and a Focus can hold its nudges, and
    nothing rings. Relentless always breaks through."

**Now and My Day**

18. Their layout and words are unchanged. Two of the made-up reminders changed, so their cards
    look different: **Take the bins out** is Consistent · 30 min and on nudge 2 (Normal, its next
    nudge High at 8:30 AM), so a nudging reminder shows the locked Pace and Every rows; **Reply to
    Alex about the lease** is Relentless, so its card is Urgent and its next nudge an alarm; its
    sent nudges, and Pay rent's from Sep 1, are recorded as Urgent too.
    Morning meds (15 min), Dentist appointment (10 min) and Team stand-up (5 min) are Consistent;
    the rest are Escalating.

**Mockup controls**

19. **Pace and strength** sets the New Reminder form's strength, pace and wait, so each
    combination's How It Nudges can be seen; **Open the New Reminder form** opens one with them.
    Settings › Default Pace sets the How It Nudges page.
20. **Next early nudge** now uses Take the bins out, since every Relentless nudge is Urgent.

**Not for pace**

21. Settings' How It Nudges row was drawn outside the Nudges list, with a stray list bullet. It's
    now in the list, as the app has it; the as-built mockup is fixed the same way.

## How it was checked

On 2026-10-21, `scripts/mockup-shots.py` took this mockup's screens and the as-built one's in
headless Chrome, in portrait, landscape and the largest text size (AX5), and
`scripts/contact-sheet.sh` put them side by side. It now also knows `details-relentless`,
`form-new-escalating`, `form-new-relentless` and `settings-default-pace`. Every new path loads
with no script errors. Nothing here is built yet, so there are no app screenshots to compare.

The clock is fixed at Monday 28 Sep 2026, 8:20 AM, and the data is made up.
