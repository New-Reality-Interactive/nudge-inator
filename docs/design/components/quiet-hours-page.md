# Quiet Hours page

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the Quiet Hours page mockup (`docs/mockups/2026-11-21-quiet-hours-page/`, #370) adds:
- **Settings' Quiet Hours:** a Settings row with a `{colors.tile-gray}` tile and `bell.slash`, in
  Nudges right after Default Pace. Under the label, as Default Pace shows its pace, whether nudges
  are held now and until when: "Until 7:00 AM" while a schedule that's on covers this moment (when
  nudges get through again, so back-to-back schedules read as one), "Starts 10:00 PM" for the next
  start of a schedule that's on, with the short weekday when it isn't today ("Starts Fri
  11:00 PM"), or "Off" with no schedule on. VoiceOver reads "On until 7:00 AM", "Starts Friday at
  11:00 PM". It is read again every minute.
- **Schedule row:** a Settings row ending in the system switch, with a `{colors.tile-gray}` tile and
  `clock`; the times as the label ("10:00 PM–7:00 AM", an en dash with no spaces) and the days under
  it in `{typography.subheadline}` `{colors.secondary-label}`, as the iOS Focus schedules list words
  them: "Every Sun, Mon, Tue, Wed, and Thu", "Every Fri and Sat", "Every day", in the calendar's
  week order. A schedule that's off keeps its row, its times in `{colors.secondary-label}`.
  VoiceOver reads the times, the days and the switch's state as one element.
- **The page:** inline title "Quiet Hours"; the Schedules section with a footer on turning one off
  and on what quiet hours do. With no schedules, the empty state is `bell.slash`, "No Schedules",
  with a bordered Add Schedule button (`plus`). Under the schedules, Add Schedule in its own section
  with no footer (the footer on what quiet hours do stays under Schedules, #370's review), a
  Settings row with a `{colors.tile-blue}` tile and `plus`, its label in the accent color (#371).
- **A schedule's sheet** (#371): tapping a schedule's words opens Edit Schedule; VoiceOver has an
  Edit action on the row instead. Add Schedule and Edit Schedule are a sheet with the inline title,
  Cancel (`xmark`, asks before discarding changes) and Add or Save (`checkmark`). Edit Schedule
  opens with a Schedule switch, in a section of its own with no heading, kept on Save like every
  other edit; Add Schedule has none, since a new schedule is saved on. Starts and Ends
  are compact time pickers; their footer says "Ends at 7:00 AM the next day." (or "the same day."),
  or, in `{colors.negative}`, "The start and end are the same. Change one to save." or, while the
  start, end and days are another schedule's (on or off), "You already have a schedule with these
  times and days." These reasons are text on the sheet, never an alert. Days is a
  checklist of full day names in the calendar's week order, its footer on what a day means, and
  "Choose at least one day to save." in `{colors.negative}` above it while none is checked. Save
  stays off while any of these lines shows. A new schedule is 10:00 PM to 7:00 AM, every day, on. Edit adds
  Delete Schedule (`trash`), which asks "Delete This Schedule?" with its times and days.
- **Symbols added:** `bell.slash`, `clock` on a schedule, `plus` on Add Schedule, `trash` on Delete
  Schedule.
