# Settings shortcuts

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the Settings rows mockup (`docs/mockups/2026-11-23-settings-rows/`, #372) adds. It rewrites
nothing above except that Settings no longer has an Open iOS Settings row.
- **Notifications, Alarms and Badges are buttons:** each keeps its tile, label and status (and the
  status colors) and ends in the chevron (`chevron.forward`, `{colors.tertiary-label}`) after the
  status. A row with a status and a chevron together is the exception to the Settings row's "status
  or a chevron" below. Rows that open iOS Settings use the chevron, not `arrow.up.forward`, which
  stays for a row that opens a web page.
- **Where they go:** Notifications and Badges open the app's notification settings in iOS Settings;
  Alarms opens the app's own page there, since alarms are reached only from it. A row opens Settings
  whatever it reads, On included.
- **VoiceOver:** one button per row that reads its label and status, then a short hint ("Opens
  notification settings."; Alarms: "Opens the app's settings.").
- **No Open iOS Settings row** (the developer's call, 2026-11-23): the three rows are the way in, so
  the row that appeared only while something was off is gone. The permission banners keep their
  Open Settings button.
