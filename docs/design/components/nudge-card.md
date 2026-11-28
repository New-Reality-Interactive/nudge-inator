# Nudge card

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- **Token:** `nudge-card`. **Container:** `{colors.cell}`, `{rounded.card}`, 5 pt leading stripe in
  the urgency color. Top row: strength badge, urgency word ("High" with `arrow.up`, "Urgent" with
  `alarm`, nothing for Normal), and "Nudge 3 of 20". The nudge meter sits below the details. No chevron.
- **Type:** title `{typography.headline}`, details `{typography.subhead}` in `{colors.secondary-label}`,
  footer `{typography.footnote}`.
- **Notes:** **Done** is `button-prominent` with `checkmark`. At accessibility sizes it sits directly
  under the title.
