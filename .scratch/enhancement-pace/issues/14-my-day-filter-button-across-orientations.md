# 14: My Day's Filter button, the same in both orientations, and an icon that says tags

**What to build:** Research and a decision, not code yet. Decide whether My Day's Filter button should look and sit the same in portrait as in landscape, and whether its icon can say more clearly that it filters by tags. The outcome is a recommendation Brian agrees, recorded here, and the build tickets it needs.

**Blocked by:** none.

**Status:** needs-triage

Raised by Brian while checking ticket 11's screenshots, 2026-10-23.

## Today

`MyDayFilterButton` (`App/MyDay/MyDayFilterControls.swift`):

- **Portrait:** a bordered button in the content, above the counts. It reads "Filter by Tags", or "Filter (2)" while tags are chosen.
- **Landscape:** the mockup moves it into the navigation bar as an icon (`line.3.horizontal.decrease`) beside New Reminder, with the number of chosen tags.

The as-built mockup (`docs/mockups/2026-10-21-as-built/`) draws both.

## Questions to answer

- Should portrait match landscape, or the other way round? Weigh discoverability, the room a labelled button takes above the list, reach, and what Apple's apps do (Mail, Reminders, Files).
- Is there an SF Symbol, or a pairing, that says "filter by tags" better than the funnel lines? For example a tag symbol, or a tag with a funnel. Check that it reads at every text size, and that it fits the badge for the number chosen.
- How does each option read with VoiceOver and at accessibility sizes, in both orientations?

## What it should do

- [ ] The options, with Apple's guidance (apple-rag-mcp) and the mockup's view of each, are written up here.
- [ ] Brian picks one, recorded in Comments, and the build tickets it needs are filed under the open feature (or he decides no change, recorded in Comments).

## Comments
