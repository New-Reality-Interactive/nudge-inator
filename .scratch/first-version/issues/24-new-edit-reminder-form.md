Status: resolved

# New / Edit Reminder form

Visual spec: mockup New Reminder and Edit screens. For the locked state, turn on **Lock nudging reminders** in the mockup controls, then edit a nudging reminder. The switch exists only so the mockup can compare the two: the app always locks (ticket 13).

Design spec: `docs/design/DESIGN.md` (Components: Buttons, Tags, Sheet bar buttons). Where it and the mockup disagree, see its Precedence note.

## What to build

The form: Title, Notes, Tags (any number, create a tag inline, one word shown as `#name`, case-insensitive unique), start date and time, Repeat (the seven presets, plus **Custom** in its own section, which opens the page from ticket 25 and may be disabled until then), Strength (Gentle, Firm, Relentless) and the **Break through Focus** switch. Save creates or edits through the app model (ticket 21). While the reminder is Nudging, due time, Repeat, Strength and the switch are shown disabled, each with a `lock` glyph, and a note at the top gives the reason: "Nudging now. Start, repeat, strength and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them. A new title shows from the next nudge." Each locked control's accessibility hint includes that note. Title, Notes and Tags stay editable. Ticket 13 owns the rule and the form reads it from the engine. The new reminder appears on the screen the person came from.

## Acceptance criteria

- [x] Saving with an empty title is blocked with a visible reason.
- [x] A new reminder with tags, Relentless and the switch on is saved and appears under Coming Up (needs ticket 26 to display; until then verify via the store in a UI/unit test).
- [x] Typing `Home` when `#home` exists attaches the existing tag.
- [x] Editing a Nudging reminder shows due time, Repeat, Strength and the switch disabled with the reason as text (not colour alone), and Title, Notes and Tags still save.
- [x] Editing a paused, finished or not-yet-due reminder shows every field enabled.
- [ ] **Custom** on the Repeat page opens the ticket 25 page, and with a custom rule the Repeat row reads Custom and the footer gives its summary.
- [x] Form works with VoiceOver labels on every control and at the largest Dynamic Type size.

Blocked by: 13, 17, 22, 23

## Comments

**Decisions settled with the user before coding (2026-10-17).** Apple's docs, read through apple-rag, confirm the following:
- `Button(role: .confirm)` is iOS 26+ and belongs in a sheet's toolbar. `.cancel` "implies progress will be lost".
- `interactiveDismissDisabled(_:)` blocks the swipe-down and not dismissal from code. `dismissalConfirmationDialog` is **iOS 27 only**, so the form uses a `confirmationDialog` on ✕ instead.
- Setting `FocusState` to `nil` dismisses the keyboard. `DatePicker(in:)` takes open ranges.
- `accessibilityHint` takes a `LocalizedStringResource`.
- SwiftUI has no general token field, only `searchable` tokens, so Tags is the mockup's pushed page.
- The docs don't say VoiceOver reads a disabled control's hint (a device check, below).

The decisions:
1. **The form model is `ReminderForm`** (`App/ReminderForm/`), an `@Observable @MainActor final class` holding the draft: title, notes, tag IDs, due time, repeat rule, strength and Break Through Focus.
   - It is built from an engine provider (`{ model.engine }`), plus the reminder to edit, if any.
   - It saves through `AppModel` (`add`, `edit`, `createTag`), and nothing else touches the store.
   - Previews build it over a bare `Engine` with a no-op scheduler, so they need no `AppModel`.
2. **How the lock rule reaches the UI.**
   - `form.lockedFields` reads `engine.lockedFields(of:)` from the app's current engine, so it follows the model (a Done from a notification while the form is open) and the clock. The form has no rule of its own.
   - Save checks the lock with the engine's own `LockedField.isChanged(from:to:)`, which is now public, before it creates any typed tags.
   - If the reminder started nudging while the form was open, Save is turned down, the four locked fields go back to their saved values, and the lock note says why. A second Save of the title still goes through.
3. **Tag matching uses the engine's `createTag` rule**, run on the form's copy of the engine, whose `.taken(by:)` gives the existing tag. So `Home` attaches `#home` without a second copy of the rule.
   - A typed new tag is created only on Save, and only if it's still chosen, as the mockup's `newTags`. Cancel leaves none behind.
4. **Defaults for a new reminder:** the next whole hour, Never, Firm, Break Through Focus on.
5. **A start that has passed is blocked** with "This time has passed. Choose a later time.", for one-offs and repeats alike, unless the start is the saved one (compared to the minute).
   - The repeat half came from review. Ticket 13's note says "The form shouldn't offer a past time", because a repeat moved into the past opens an occurrence at once. The mockup's `pastOneOff` checks one-offs only.
6. **Presentation:** a `.sheet` from the + on Now and My Day. In compact height it is the system's full-screen sheet; `presentationCompactAdaptation` isn't used.
   - The + is enabled only once the model has launched, because `perform` drops events before that.
   - Save dismisses the sheet, so the person is back where they came from and no route is needed.
   - With changes, a swipe down is blocked and ✕ asks "Discard Changes". Without changes, ✕ closes at once.
   - Edit's entry point is ticket 27, which presents `ReminderFormSheet(form:)` with `ReminderForm(engine:editing:now:)`.
7. **The lock in the UI:**
   - The note at the top reads "**Nudging now.** Start, repeat, strength and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them. A new title shows from the next nudge." The `lock` glyph next to it is hidden from VoiceOver.
   - Each locked control is disabled, shows the `lock` glyph and has the whole note as its hint (`lockedWhileNudging(_:)`, `LockNote.hint`), so the reason is text, not dimming alone. The hint is its own catalog string because a hint can't carry the bold.
   - A locked Repeat row isn't a link.
   - An Edit form that isn't locked shows the mockup's "A new schedule applies from the next time it's due…".
8. **Repeat:** `RepeatPreset` holds Never and the six presets, each one of the engine's rules; any other rule is Custom.
   - The Repeat page puts Custom in its own section. Its row is **disabled until ticket 25**, and its footer is the hint line, or the engine's summary when the rule is custom.
   - Choosing a preset replaces a custom rule. The page stays open after a choice, as in the mockup.
9. **Left out by agreement:**
   - How It Nudges isn't in the form (ticket 31 owns it).
   - The strength blurbs ("Every 30 min, down to every 5…") are catalog copy until ticket 31 reads the ladder from the engine. The give-up sentence takes its numbers from `GiveUpLimit.shipped`.
10. **Coming Up:** a saved reminder is in the engine's `comingUp()` and the store, but Now and My Day still show ticket 22's fixed empty text until tickets 26 and 28.

**Tests:** `ReminderFormTests` has 21 tests through `ReminderForm` and the real `AppModel` (in-memory store, real adapters over the fakes). They cover:
- an empty title;
- a new reminder with tags, Relentless and the switch on, in `comingUp()`;
- `Home`, `#home` and ` HOME ` all attaching `#home`;
- a typed tag created on Save, and not created when it's no longer chosen;
- a Nudging reminder: four fields locked, and title, notes and tags saved;
- paused, finished and not yet due: nothing locked;
- the lock arriving while the form is open;
- the seven presets;
- a custom rule reading as Custom with the engine's summary until a preset replaces it;
- a past start, for one-offs and repeats;
- a kept start, to the minute;
- the default start;
- `hasChanges`;
- trimming, and a title's line breaks saved as spaces;
- the Tags row text;
- a turned-down save creating no tag;
- the lock lifting on a Done;
- a double Save adding once.

The summary is compared with the engine's own output, whose wording `RepeatSummaryTests` pins in a fixed locale, so the test passes in any locale.
- **Red first:** every slice except the not-nudging cases, which passed on their first run because the engine already held the rule. They're kept as acceptance coverage.
- **Mutation check:** dropping a re-read of the engine after a rejection left the test passing. The snapshot shared the clock, so the dead line went. Review then moved the lock read to the current engine.
- **`scripts/test.sh` passes:** the engine tests, and 139 app tests on each of the iOS 26.1 and 26.5 simulators.

**Screenshots** (iPhone 17 simulator, iOS 26.5): a throwaway XCUITest in the scratchpad, with a stand-in `@main` that opened a nudging reminder's Edit form from a launch argument. Nothing was committed. The simulator's text size and appearance were put back to `large` and light, and the app was uninstalled. Compared with the mockup's New Reminder and Edit screens:
- **New Reminder:**
  - the glass ✕ and the accent ✓ (gray when disabled);
  - Title, Notes, then Tags with "None" or `#home #Garden`;
  - Starts with date and time pills, and Repeat;
  - the summary footer, Strength as a segmented control with its blurb, and Break Through Focus with its footer.

  This matches the mockup, apart from How It Nudges (left out).
- **Locked Edit:**
  - the lock note at the top;
  - `lock` beside Starts, Repeat, the Strength header and Break Through Focus;
  - the date as plain text, the segments dimmed, the switch dimmed;
  - Repeat with no chevron.

  This matches the mockup's form with Lock nudging reminders on. Dark mode reads well.
- **Tags page:** New Tag with a bordered Add, its footer, and Your Tags with checkmarks. **Repeat page:** the presets with a checkmark, and Custom in its own section with the hint footer. **Discard:** iOS 26 shows Discard Changes as a popover on ✕.
- **AX5:**
  - rows stack (Tags above `#home`, Repeat above Never);
  - Strength becomes a menu under its label;
  - the lock note and footers wrap.
- **Landscape:** the sheet goes full-screen and its content is centered at the readable width.

**Code review** (two axes, against main). Fixed, each behaviour with a test that was red first:
- **Spec:**
  - The lock came from the snapshot taken when the form opened, so it went stale after a Done, and a rejection could fail silently. It's now read from the current engine.
  - A turned-down Save still created the typed tags. The lock is now checked first.
  - Repeats weren't blocked from a past start (decision 5).
  - The kept-start check compared exact dates. It now compares to the minute, as the mockup does.
  - A pasted title lost its line breaks with no space. They're now saved as spaces, and the rule lives in the model, not the view.
  - A double tap on Save could add the reminder twice.
  - The hint left out "A new title shows from the next nudge."
- **Standards: no hard violations.** Fixed:
  - The strength footer glued two sentences with a space; they now stack.
  - Two call sites shared the bare `"%@."` key; there's now one `RepeatSummarySentence` with one comment.
  - `TagRow` and `CheckmarkRow` were the same view; there's now one `CheckmarkRow`.
  - The `TagNameError` handling was written twice; it's now one helper.
  - `Text("Strength")` was written twice.
  - `isEditing` was passed in beside the form; it's now `form.isEditing`.
  - The "seven presets" comments now say Never and the six presets, as GLOSSARY.md does.
- **Kept, as judgement calls:**
  - The Tags row joins `#name` tokens with spaces: they're tokens, not a sentence, so not a list format.
  - The lock note and hint are two catalog strings (bold against plain).
  - Several keys (`Add`, `Tags`, `Repeat`, `New Tag`, `New Reminder`, `Custom`) are shared with merged comments.

**Device run (2026-10-17), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Before:** Nudge-inator was not installed. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator.
- **All 139 app tests pass on the phone** from a fresh install (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`, two prompts). The ring check was skipped, as it is by default.
- **Manual checks Brian ran with the app installed: all 8 passed.**
  1. The + opens the form with the title focused. Return closes the keyboard, and the keyboard doesn't cover Notes.
  2. With an empty title, ✓ is dimmed and the red reason shows.
  3. `Home` then `home` gives one `#Home`.
  4. The Repeat presets get checkmarks, Custom is dimmed, and the summary footer shows.
  5. A past start shows its reason and disables ✓.
  6. A swipe down is blocked with changes, ✕ offers Discard Changes, and ✕ closes at once without changes.
  7. VoiceOver reads a label on every control, and "selected" on chosen rows.
  8. At the largest text size, in portrait and landscape, rows stack, Strength is a menu, nothing is cut short, and landscape is full-screen and centered.

**Device checks still pending** (record the iOS version when they are run):
- **The lock on a nudging reminder on the phone (ticket 27, which adds Edit):** the note at the top, and VoiceOver reading the lock note as the hint of each disabled control, including the segmented Strength picker, whose segments may not carry it. The docs don't say a disabled control's hint is read.
- **Custom opening ticket 25's page:** this criterion stays open for ticket 25. The rest of it is done: with a custom rule, the Repeat row reads Custom and the footer gives the engine's summary (unit test and preview).

**Left alone:**
- the Custom page (25);
- Now, My Day and Tags content (26, 28, 29), including showing the new reminder under Coming Up;
- reminder details and Edit's entry point (27);
- How It Nudges (31);
- the Open intent (20);
- onboarding and banners (31).

**For ticket 25:**
- Enable the Custom row in `RepeatPage` and push the Custom page from it.
- The form's `repeatRule` is the rule to edit; `repeatPreset` is `nil` for Custom.

**For ticket 27:** Edit is `ReminderFormSheet(form: ReminderForm(engine: { model.engine }, editing: id, now: { .now }))` in a sheet. Show `LockNote`'s wording under Schedule.

**For ticket 29:** a tag's + can preset `form.tagIDs` before presenting the sheet.

