# Buttons

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- Every button is at least 44 pt tall.
- `button-prominent` (accent fill, semibold) for one primary action per context; `button-bordered` for
  secondary; plain accent text for tertiary (honors Button Shapes). A destructive action in a list
  row or a system dialog is text in `{colors.negative}`.
- `button-destructive` (negative fill, on-accent text, semibold) for a destructive action that is a
  screen's own button rather than a list row or a dialog's: Disconnect's and Turn Off Sharing's
  confirmation, and Waiting for You's Remove. Red text on the tertiary fill read as a dimmed control
  (#217's phone check, #402), so a destructive button is never `button-bordered`. On a sheet it is
  the system's prominent button, as Continue is: its capsule and its own weight, so Bold Text applies
  (the developer, 2026-11-15, #402: standard iOS visuals). The #402 mockup draws a semibold rounded
  rectangle; the app follows iOS.
- Waiting for You's rows are the exception to one primary action per context: each row's Accept
  (`button-prominent`) and Remove (`button-destructive`) are an even pair, both filled, as small
  capsules (#402).
- Disabled uses `{colors.secondary-label}`; a disabled prominent button becomes a hairline outline.
