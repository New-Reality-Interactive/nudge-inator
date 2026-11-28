# Details tone and Use for All

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the details tone and Use for All mockup (`docs/mockups/2026-11-19-details-tone-use-for-all/`,
#456) adds. It rewrites nothing above except the Default Alarm Sound page's footer.

- **Details, Sound row:** on a reminder's details, in Schedule under Break Through Focus, a row in
  `{typography.body}` with the sound's name trailing in `{colors.secondary-label}` (Default Alarm by
  name), as Pace shows its pace, with no chevron: it only names the sound, and Edit changes it. It
  shows only while the reminder rings, by the form's Sound row's rule, and never on a received copy
  its sender canceled. On a received copy it names
  the sound chosen on this iPhone; while that copy rings, the schedule's lock footer adds "The sound
  is yours: it's chosen on this iPhone." and the footer under Remove Reminder says the person can
  choose its alarm sound.
- **Use for All Reminders:** on Settings' Default Alarm Sound page, its own section under the list,
  one row in `{colors.accent}` text (a tint row, as Pause Reminder). Its footer says choosing a sound
  above leaves existing reminders as they are and this gives every one of them the default, received
  ones included; the list's footer drops "Reminders you already have keep theirs." When every
  reminder already has the default, the row is dimmed and its footer reads "Every reminder you have
  uses <sound>." Tapping it asks with the system confirmation dialog (Components): "Use <sound> for
  All Reminders?", "<n> reminders, including ones people sent you, will use <sound>." counting only
  the reminders it changes ("1 reminder will use <sound>." for one), and a Use for All Reminders
  button that is not destructive, since nothing is deleted. Focus goes where iOS puts it.
