# Reminder form's Repeat

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- The Repeat row sits under Starts and shows the current choice. A tap opens a
  pop-up menu, as in Apple's Reminders on iOS 27 (mockup `1.3.0`, #283): Never and the six
  presets in their order, a divider, then Custom, with a checkmark on the current choice. A choice is the
  form's repeat at once, held until the form's own Save like every other field; there is no Repeat page.
- **Custom row:** choosing Custom adds a row below Repeat with no "Custom" label, which Repeat already
  says. It writes the repeat out ("Every Monday at 9:00 AM") with a chevron and opens the Custom repeat
  sheet. Choosing a preset again removes it. It writes the repeat without its end, which End Repeat says
  (#287).
- **Locked while nudging:** the Repeat row and the Custom row are plain text with the `lock`, without the
  menu's or the link's affordance (no chevron), beside the form's lock note, as the form's other locked
  rows are.
- **VoiceOver:** the Repeat row reads its choice, and the menu reads each item with the current one selected.
  The Custom row reads the repeat, with the hint "Opens the custom repeat."
- **End Repeat** (mockup `1.3.0`, #287): under Repeat, and under the Custom row when there
  is one, whenever Repeat isn't Never. A pop-up menu of Never, After and On Date, drawn as the Repeat
  menu, with a checkmark on the current choice. After adds a stepper row, "After 10 times" (2 to 30); On
  Date adds an End Date row with a date button that opens a calendar no earlier than the start. The choice
  is the form's at once and is kept when the repeat changes; it goes back to Never only with Repeat. A
  preset with an end still shows as that preset in the Repeat menu. The footer under the section always
  says the whole repeat, end included ("Every Monday at 9:00 AM, 10 times."), for Never, the presets and
  Custom, and while locked; the Custom row and the Custom page's summary leave the end out. An end date before the start
  disables Save, with "The repeat ends before it starts. Change its end date." under Starts. The Custom
  sheet has no Ends section. Locked while nudging, End Repeat and its rows are plain text with the `lock`.
  VoiceOver reads End Repeat's choice, the stepper's count and End Date's date.
- **Custom repeat sheet** (mockup `1.3.0`, #284): a sheet over the reminder form, as in
  Apple's Reminders on iOS 27, titled "Custom": the summary sentence, Frequency with its Every stepper,
  On, and Next Times. Each change is the form's repeat as it's made, held until the form's own Save.
  **Apply** (✓, the accent-filled confirm button) is its only button: it closes the sheet and is never
  disabled, so the sheet can always close. A swipe down closes it too and keeps the changes. Nothing on
  it asks a question; the form's Cancel asks before discarding. Locked while nudging, its controls are
  disabled with the `lock`, under the form's lock note, and Apply still closes it. This follows Apple's
  app over the HIG's Sheets page, which pairs Done with Cancel and avoids a sheet over a sheet (#284).
