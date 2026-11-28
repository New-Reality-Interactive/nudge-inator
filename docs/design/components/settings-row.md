# Settings row

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- Icon tile, label in `{typography.body}`, trailing status in `{colors.secondary-label}` (or
  `{colors.negative}` when off) or a chevron. The Badges row is the exception: its status is
  `{colors.secondary-label}` even when off, since badges being off isn't a problem to flag (it
  says On, Off or Not Set; icon-badge #85). A row that opens a page to set a value shows the
  value under the label in `{typography.body}` `{colors.secondary-label}`, with the chevron
  (Default Pace: "Consistent · 10 min"), so it never shares the line with the label. A row that
  opens a web page (About's Privacy Policy and Support) has its label in the accent color and
  `arrow.up.forward` in place of the chevron, and VoiceOver reads it as a link. A row that turns
  something on or off (Sharing) ends in the system switch in place of a status or chevron, and
  VoiceOver reads the label and the switch's state as one element. Tile colors are listed under
  Colors.
