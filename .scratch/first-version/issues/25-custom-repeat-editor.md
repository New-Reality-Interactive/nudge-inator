Status: ready-for-agent

# Custom repeat editor

Visual spec: mockup Repeat and Custom pages of the New Reminder form (`docs/mockups/2026-10-04-first-version/`).

Design spec: `docs/design/DESIGN.md`. The page uses only system controls (`Picker` in the segmented style, `Stepper`, checkmark lists and a `DatePicker`), which DESIGN.md says are drawn as the system draws them, so it adds no new component. Where it and the mockup disagree, see its Precedence note.

## What to build

The Repeat page lists the seven presets, then **Custom** in its own section with a chevron, as Calendar does. Its footer is the summary when Custom is chosen, and a one-line hint otherwise. Choosing Custom starts from the preset that was chosen (Every 2 Weeks becomes weekly, every 2 weeks, on the start's weekday) and pushes the Custom page. The page builds a rule through the engine's rule type (ticket 09). The person never sees or types RRULE.

- **Summary** at the top, from the engine ("Every 2 weeks on Monday and Wednesday at 9:00 AM, 5 times."). It updates as the choices change.
- **Frequency:** Daily, Weekly, Monthly or Yearly, then a stepper row "Every 2 weeks". The upper limits are 30 days, 12 weeks, 12 months and 10 years.
- **On**, for weekly: a checkmark list of the weekdays, Monday first. The last chosen day can't be cleared.
- **On**, for monthly: a choice derived from the start date, so there's nothing else to pick.
  - "On the 28th".
  - "On the fourth Monday", offered when it's the first to fourth.
  - "On the last Monday", offered when the start is in the month's last week.
  - "On the last day".
  - For the 29th to the 31st, the footer says those months are skipped and points to "On the last day".
- **Yearly:** no extra control. The footer says it repeats on the start's day and month.
- **Ends:** Never, After or On Date. After adds a stepper ("After 10 times", 2 to 30). On Date adds a date picker no earlier than the start.
- **Next Times:** the next three due times from the engine, with the year when it isn't this year, and "Then it ends." when fewer remain.
- An end date before the start shows its reason as text and disables Save. So does a rule with no times left.

## Acceptance criteria

- [ ] Choosing Custom after a preset opens it with that preset's frequency, interval and day already set.
- [ ] Each control builds the rule the summary describes (UI or unit test through the app model).
- [ ] Monthly choices follow the start date, and a choice the new start doesn't offer falls back to the day of the month.
- [ ] Next Times matches the engine's output and updates as controls change.
- [ ] An end date before the start shows a visible reason, and Save is disabled.
- [ ] Choosing a preset after Custom replaces the custom rule, and reopening an existing reminder with a custom rule shows Custom checked with its choices restored.
- [ ] VoiceOver reads each weekday as a checkbox with its name and state, each monthly choice as a radio button, and the summary as one element. Nothing relies on colour alone.
- [ ] Works at the largest Dynamic Type size (segmented pickers become menus) and in landscape.
- [ ] A `#Preview` for the page in Light, Dark and the largest Dynamic Type size.

Blocked by: 09, 24
