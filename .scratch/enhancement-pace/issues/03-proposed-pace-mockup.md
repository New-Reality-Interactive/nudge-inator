# 03: Proposed pace mockup

**What to build:** A proposed mockup with the pace changes, so Brian can see what they look like before any of them is built. It is a copy of the as-built mockup (02) changed only for pace and the Relentless changes, so the two can be compared directly. Every later ticket builds to it. Spec stories 3 and 4; the screens it draws are described in stories 23–47 and the Implementation Decisions.

**Blocked by:** 02.

**Status:** resolved

- [x] The proposed mockup is a copy of the as-built one in its own dated folder, with a README listing every change from the as-built mockup.
- [x] The reminder form shows a Pace segmented control (Escalating | Consistent) under Strength, an Every row with the 11 waits revealed only under Consistent, and the control as a menu at accessibility text sizes.
- [x] Choosing Relentless shows Break through Focus on and disabled, with a footnote saying Relentless always rings.
- [x] How It Nudges (form, details, Settings page) shows a Consistent reminder's equal waits, and Relentless as alarms from nudge 1, for each strength.
- [x] Reminder details show the pace, and the wait when Consistent.
- [x] Locked Pace and Every rows look like the other locked rows.
- [x] Settings shows a Default pace row, Consistent · 10 min.
- [x] Now and My Day are unchanged.
- [x] The mockup's controls can switch pace and strength so each combination can be seen.
- [x] Brian approves it. Changes he asks for are made and listed in Comments.

## Before you start

- Builds on: ticket 02: the as-built mockup, `docs/mockups/2026-10-21-as-built/`, is what to copy. Its README lists what it corrected. Ticket 02's Comments record that My Day's AX5 row is drawn as intended (the app's bug is ticket 11), and that section headers are headline style (DESIGN.md).
- Watch for: How It Nudges, the strength line in the form and the Via labels all come from `deliveryOf`, `nudgeSummary`, `hinSection` and `strengthBlurb` in the mockup's script, so Consistent waits and Relentless's alarms from nudge 1 change there once. The banners' reach text follows Relentless's new delivery too (spec story 11). No app code changes, so compare the two mockups with `scripts/mockup-shots.py` and `scripts/contact-sheet.sh`, not the simulators. The app writes "Break Through Focus" with a capital T.
- Developer stops: no `tdd` (a mockup); Brian's approval of the proposed mockup.

## Comments

**2026-10-21, the proposed pace mockup.** `docs/mockups/2026-10-21-proposed-pace/` (`index.html`, `README.md`), a copy of the as-built mockup changed for pace and Relentless; the README lists 21 changes. No `tdd`: a mockup. DESIGN.md's Precedence paragraph now names it as what the enhancement-pace tickets build to. `scripts/mockup-shots.py` knows four new screens (`details-relentless`, `form-new-escalating`, `form-new-relentless`, `settings-default-pace`).

**Choices for Brian to confirm with his approval:**
- The line under Strength now says only how the strength arrives and the give-up limit; the waits moved under Pace ("Every 30 min at first, down to every 5 min." / "Every 10 min, from when it's due."), so the two can't disagree (story 35).
- Default Pace is a Settings row that opens its own page with the form's controls, rather than controls inline in Settings.
- Words not named by a story but made untrue by Relentless or pace: Settings' footer gains "Every Relentless nudge is Urgent.", and onboarding's first and third points are reworded (README items 14 and 17).
- "Now and My Day are unchanged" is read as their layout and words. Two made-up reminders changed: Take the bins out is Consistent · 30 min on nudge 2, so a nudging reminder shows the locked Pace and Every rows and the early-notification control still has a reminder (Relentless's next nudge is now always an alarm); Reply to Alex is Urgent because it's Relentless.

**Also fixed, not for pace:** both mockups drew Settings' How It Nudges row outside the Nudges list, with a stray list bullet (a stray `</ul>`); the app has one Nudges section (`App/Shell/SettingsTab.swift`). Fixed in the as-built mockup too.

**Check.** Headless Chrome shots of both mockups in portrait, landscape and AX5, compared side by side; every new path runs with no script errors, and How It Nudges was read for each strength at 2 min, 10 min and 16 hr. `scripts/test.sh` passed on both simulators (no app code changed).

**Review (2026-10-21, `code-review` from main).** Standards: no hard findings. Fixed: a helper for a reminder's effective switch (`btActs`) instead of five copies, the Default Pace page's header as h2 like other Settings pages, the mockup controls re-syncing when a locked form ignores them, the shots script's docstring, DESIGN.md's wrap, a redundant default. Kept: `pace.pace` naming and the repeated `"consistent"` tests, as in the mockup's idiom. Spec: no criterion missing. Fixed: the line under Strength used the Escalating ladder (Firm at 16 hr said "Rings as an alarm from nudge 4"); long waits that never reach High said "Normal nudges wait until High" and "All 2 nudges"; Pay rent's history now Urgent was missing from the README; DESIGN.md's "the mockup wins" now says which one.

**Brian's check (2026-10-21).** Brian approved the mockup, including the four choices above, with no changes asked for. He showed it to the product owner as a Claude artifact (a copy with a short "What's proposed" panel added, not committed), and it matched how they imagined pace would work.
