# Nudge-inator iOS mockup: Tags tab tools

The change mockup for #138: the [no-chips mockup](../2026-11-01-no-chips/README.md) with the Reminders
tab's tools on the Tags tab (spec #104, Decisions 40 to 51 and 53). Once Brian signs it off on #138,
the Tags tab tools tickets are checked against it. The release's `1.3.0` mockup takes it in and
deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The
"Tags tab tools (#138)" group in the controls panel reaches every state below.

## What changed since the no-chips mockup

- **Header row:** "9 tags out of 9" replaces "Your Tags", in every case.
- **The bar:** Filter and Sort in one glass group, New Tag apart, and no Edit button (Decision 49).
  With no tags, only New Tag. It stays during a search. No quick filter chips (Decision 51).
- **Search:** the field under the large title, "Search tags", name only, with a leading `#` ignored.
- **Filter button and sheet:** a badge of 1 or none, and with the filter on, a menu of Filter and
  Clear All Filters. The sheet, "Filter Tags", has one condition, Has no reminders (Decision 53), with
  Cancel, Apply, Reset and the prompt before discarding a changed draft.
- **Sort menu:** Name (A to Z, Z to A) and Reminders (Most First, Fewest First), one checked. Ties on
  the count sort by name, A to Z.
- **Swipe, replacing Edit mode:** Edit and Delete tiles, no full swipe. Edit opens the rename sheet.
  Delete asks first, in the app's words. Edit mode, its row and its footer are gone.
- **Row height:** at least 78 pt, so the system draws the tiles as circles (#126).
- **A row animates out** after a delete, and when the filter excludes it (a control gives #yoga its
  first reminder). The count follows.
- **Empty states:** No Tags with help text, and three nothing-matches forms with no help text.
- **Made-up data:** two tags no reminder uses, #volunteer and #yoga, so Has no reminders has rows.
  They sort last, so My Day's and the screenshot script's first tags don't change.
- `scripts/mockup-shots.py`: the `tags-*` screens this mockup adds. Its `tags-edit` screen now draws
  the plain list here, since Edit mode is gone; earlier mockups still need it.

## The help text (Decision 48)

Static text, not a dismissible tip. Draft copy, with the final wording agreed in review.

| Where | Copy |
|---|---|
| The no-tags empty state's description | Tags are labels, like #home or #errands, that you add to reminders so you can find them together. Tap + to make one, or add one when you create or edit a reminder. |
| The footer under the list, in `{typography.footnote}`, wrapping at large text and in landscape | Tags are labels you add to reminders. Choose one to see every reminder that has it. |

The footer no longer says how many reminders have no tags, or that My Day can show them: Brian's call
in review, 2026-11-04. The nothing-matches state has no help text.

The Human Interface Guidelines behind it, read through `apple-rag-mcp`:

- **Offering help:** relate help to what people are doing now, and describe a task in a few words. It
  also says to make help easy to dismiss or avoid, which a static footer isn't; it's short and last
  on the screen, so it stays out of the way. A tip would be dismissible, but it needs stored state.
- **Writing:** an empty state can educate and should guide people to the next action, but it's
  usually temporary, "so don't show crucial information that could then disappear". So the
  explanation is in the footer too. Writing also says possessives like "Your" are often unnecessary,
  which suits the header row replacing "Your Tags".
- **Lists and tables:** the grouped style uses headers and footers to separate groups, so the text
  belongs in the footer and the header row stays first.

## Choices to check in review

- **The tile order and color aren't in the spec:** Edit at the edge with Delete beside it, as Done and
  Delete sit on Reminders. Edit is `tile-blue` with `pencil`.
- **Wording the spec leaves open:** the prompt "Search tags"; the sheet's footer "Shows only tags that
  no reminder uses."; and the nothing-matches lines "No tags with this filter." and "No tags with this
  filter match this search.", with Clear Filter and Clear Search and Filter, singular because the sheet
  has one condition. The menu keeps the ticket's Clear All Filters.

## Differs from the ticket or earlier mockups, on purpose

- **Copied from the no-chips mockup, not 1.2.0,** because 1.2.0 has no Reminders tab, whose tools this
  draws (the ticket names no-chips).
- **Apply is drawn as the `checkmark`** on this sheet, not the word in the ticket's bullet: #113 made
  that the filter sheets' confirm, and VoiceOver still calls it Apply.
- **The sheet has one condition:** Decision 53 replaces the three in Decision 45.
- **The Tags tiles are drawn from the app,** measured on iOS 27.0: a 50 pt circle holding the glyph,
  the word under it, and the swiped row gray and rounded. The Reminders tab's tiles and its Apply stay
  as the no-chips mockup draws them, as does its bar's three separate buttons, since this change
  isn't about them. `DESIGN.md` has the built form of each.
- **A tap above a changed Tags filter springs back,** as the spec and `DESIGN.md` say. The Reminders
  sheet in this file still asks, as the no-chips mockup draws it.
- **The word under a tile keeps one size here.** Apple's docs don't say how the system scales it, so
  the built screen is the check at the largest text.

Nothing else changed. The earlier mockups' choices, known differences and screens stand.
