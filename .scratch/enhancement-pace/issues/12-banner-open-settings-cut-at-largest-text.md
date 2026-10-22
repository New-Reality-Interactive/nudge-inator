# 12: Banners' Open Settings is cut to "Open…" at the largest text

**What to build:** A bug fix. At the accessibility text sizes a permission banner's Open Settings button shows its whole label, wrapping if it must, so a person can read where it goes.

**Blocked by:** none.

**Status:** needs-triage

Found during ticket 06's simulator check, in `scripts/screenshots.sh` screenshots on `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` at the largest text size (AX5), 2026-10-22. Brian asked for this ticket.

## The bug

At AX5 in portrait, the Open Settings button under each permission banner's text reads "Open…": the notifications-off banner (`banner-notifications-off-4`) and the alarms-off banner (`banner-alarms-off-3`). The label is truncated rather than wrapped, so the button no longer says what it opens. VoiceOver isn't affected: it reads the button's own label ("Open Settings for notifications").

The banner (`App/Permissions/PermissionBannerView.swift`) puts the button in the narrow column beside its icon, and the button uses `SmallBorderedButtonStyle` (`App/Design/StatusComponents.swift`), a capsule with horizontal padding whose label truncates when the column is too narrow. Ticket 06 changed the banners' words, not the button or the layout, so the bug was there before. The same style is used in `App/Tags/TagsList.swift` and `App/MyDay/MyDayRows.swift`, which may have it too.

## What it should do

DESIGN.md's Permission banner: "**Open Settings** as a small bordered button." Its label should read whole at every text size.

- [ ] At AX5, in portrait and landscape, each banner's Open Settings label reads whole, with no truncation (simulator screenshots on both simulators: `scripts/screenshots.sh`, the `banner-*` screens).
- [ ] The other uses of `SmallBorderedButtonStyle` are checked at AX5, and fixed too if they truncate.
- [ ] At the default size the banners are unchanged (screenshots compared with the proposed mockup).

## Comments
