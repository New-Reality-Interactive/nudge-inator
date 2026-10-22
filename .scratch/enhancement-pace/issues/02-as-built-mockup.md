# 02: As-built mockup

**What to build:** A mockup that matches the app as it is today, so there is a true record of the shipped design to propose changes against. It is an HTML copy of the first-version mockup, changed wherever the built app differs, and checked screen by screen against simulator screenshots. The first-version mockup moves to the mockup archive, its README saying it is superseded by this one. Spec stories 1 and 2.

**Blocked by:** 01 (the screenshots come from its simulators).

**Status:** resolved

- [x] The as-built mockup is a single HTML file with a README, in a dated folder under the mockups, opening in a browser with no dependencies, as the first-version one does.
- [x] Every screen in the app (Now, My Day, Tags and a tag's list, Settings, the reminder form and its pages, reminder details, How It Nudges, onboarding, the permission banners) appears in it and matches simulator screenshots from both the 26.5 and 27.x simulators in portrait, landscape and a large text size.
- [x] The README lists each difference from the first-version mockup that was found and corrected.
- [x] The screenshots used for the check are kept with it, or the README says where they are and how to make them again.
- [x] The first-version mockup is in the archive, its README marked superseded with a link to this one, and links to it elsewhere (README, DESIGN.md, the first-version spec) point to its new place.
- [x] Brian has looked it over and agrees it matches the app.

## Comments

**2026-10-21, the as-built mockup.** `docs/mockups/2026-10-21-as-built/` (`index.html`, `README.md`), a copy of the first-version mockup corrected to the app. No `tdd`: no behaviour changed (a mockup, docs and a screenshot harness).

**Screenshots, agreed with the developer:** not committed (`docs/screenshots` stays git-ignored). The harness that makes them is committed instead: `scripts/screenshots.sh` and `scripts/screenshots/` (a stand-in `@main` over the test fakes, seeded with the mockup's reminders, and a UI test that walks every screen). The recipe the spec cited didn't exist; it is now in `docs/agents/device-testing.md`, Simulator screenshots. The README says where they are and how to make them again.

**Check.** 48 screens each on `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0`, in portrait, landscape and AX5 (288 screenshots, all tests passing on the second full run), compared by eye with headless Chrome shots of the mockup. 26.5 and 27.0 draw every screen the same. The README lists 32 corrections. Not compared: the system's own UI (notifications, the alarm, prompts), dark mode and the other accessibility settings.

**Found, not fixed here:**
- Bug: at the accessibility text sizes a My Day row keeps its status label beside the stacked time and title, so "Done", the time and titles break mid-word (`App/MyDay/MyDayRows.swift`, `opener`). The mockup draws the intended row. Needs a bug ticket.
- DESIGN.md says section headers are footnote (13 pt); the app uses iOS 26's system headers (17 pt semibold headline), and the mockup follows the app. Open: which one changes.

**Links.** The first-version mockup moved to `docs/mockups/archive/2026-10-04-first-version/`, its README marked superseded with a link to the as-built one, and its own relative links fixed for the deeper folder. Links to it now point to the archive: the first-version spec, its tickets 03, 04, 22, 23 and 25, and a comment in `FirmAndRelentlessLadderTests.swift`. The root README had no link to it. DESIGN.md's Precedence paragraph names the mockup that owns screen layout, so it now links the as-built mockup and names the archived first version's new place.

**Harness quirks (iOS 26.5 and 27.0 simulators, Xcode 27.1):** in landscape a tap on a navigation bar button never landed and `swipeUp()` didn't scroll, so bar buttons are tapped in portrait and the phone turned back, and scrolling is a coordinate drag. Going back from the form's Tags page closed the sheet on 27.0, so that page has a test of its own.


**Review (2026-10-21, `code-review` from main).** Standards: two hard findings, both fixed: `scripts/screenshots.sh` booted simulators it never shut down (it now shuts down any it booted), and dismissing the simulator's keyboard tip can't be undone (now said in device-testing.md). Judgement calls fixed: a `Scenario` enum for `SHOT_SCENARIO`, the seed called directly (with a once-only guard), `scrollToTop()` extracted, a doc comment that said "up" for down, the force unwraps noted as harness-only, DESIGN.md's reflowed paragraph and "the archived mockup" made unambiguous. Spec: four corrections missing from the README (Reminder Not Found, the notifications-off Settings footer and How It Nudges sentence, the unlocked Edit note), now folded into items 8, 11, 14 and 19; leftovers of the removed lock control and take-over row deleted from the mockup. Spec also flagged that the My Day AX5 row is drawn as intended rather than as the app draws it: for the developer to agree with criterion 6. After the fixes the harness passed portrait on 27.0 and landscape on 26.5 (48 screenshots each), and the mockup's screens load with no script errors.

**Brian's check (2026-10-21).** Brian approved the mockup as matching the app (criterion 6). He agreed the one exception, the My Day row at AX5 drawn as intended rather than as the app draws it, and asked for a bug ticket: ticket 11 (`.scratch/enhancement-pace/issues/11-my-day-row-status-at-accessibility-sizes.md`; first-version is closed as v1.0.0). On the section headers he chose DESIGN.md to match the app: headline (17 pt semibold) in the secondary label color, no longer footnote; the mockup and its README now say so.

