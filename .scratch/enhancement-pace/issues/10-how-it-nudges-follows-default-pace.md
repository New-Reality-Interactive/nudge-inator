# 10: How It Nudges page follows the Default pace

**What to build:** The How It Nudges page in Settings shows each strength under the Default pace, so it matches what a new reminder will do, and it updates when the Default pace changes. Spec story 43.

**Blocked by:** 09.

**Status:** ready-for-agent

- [x] The page's section for each strength shows its nudges under the Default pace, read from the engine.
- [x] Changing the Default pace changes the page the next time it is shown.
- [x] The page's intro reads "Below is how each strength nudges a new reminder at your Default Pace, <pace>, with Break Through Focus on.", naming the current Default Pace ("Consistent · 10 min").
- [x] Simulators (26.5 and 27.x): the page under both paces in portrait, landscape and large text, as in the proposed mockup.
- [ ] Offered to Brian, after the simulator pass: the page on an iPhone (phone and iOS version recorded).

## Before you start

- Builds on: ticket 09 (PR #52). `AppModel.defaultPace` is the one place to read the Default pace (`App/Shell/DefaultPace.swift` holds `DefaultPace` and its record). It's read from `UserDefaults` each time, and Observation's `access`/`withMutation` make views that read it follow a change, including Delete All Data. `DefaultPace.pace` gives the engine's `Pace`, and `Pace.title` gives "Consistent · 10 min" for the intro. The page (`App/HowItNudges/HowItNudgesPage.swift`) calls `engine.howItNudges(strength, breakThroughFocus: true)`. The engine's `howItNudges(_:pace:breakThroughFocus:)` already takes a pace and folds Consistent rows (ticket 07b), so the page only needs to pass `model.defaultPace.pace`. Its intro string is on line 19. Without a model (previews) the page builds its own engine, so it needs a preview Default pace, as `SettingsTab`'s `previewDefaultPace` does. Ticket 09's Comments, 2026-10-23: the Default Pace row shows its value under its title, Brian's choice, not as in the mockup.
- Watch for: the screenshot walk's `testSettings` sets the Default pace to 30 min before it opens How It Nudges, so `settings-how-it-nudges` will show Consistent · 30 min, while the mockup's page (item 13) is at Consistent · 10 min. "Under both paces" also needs an Escalating shot, so the walk needs to choose each pace before shooting the page. `SHOTS_TESTS="testSettings"` re-shoots just that part (`device-testing.md`). A Consistent page folds rows, so the shot's page count may change. Onboarding's points (`WelcomeFeatures`) at the top of the page are unchanged.
- Developer stops: agree the `tdd` seams (for example, the intro's text for each pace, and the page's sections at the Default pace, which may want a small testable type beside the view); the simulator pass under both paces with `scripts/screenshots.sh`; the offered iPhone run.

## Comments

**2026-10-21, criteria from the proposed mockup.** Added with Brian's agreement after ticket 03, for text and behaviour the approved mockup settled that this ticket didn't name: the page's intro naming the Default Pace. Detail: `docs/mockups/2026-10-21-proposed-pace/README.md`, items 13.

**2026-10-23, built.** `HowItNudgesPageContent` (`App/HowItNudges/HowItNudgesPageContent.swift`) holds the intro and each strength's section at a pace, from the engine. The page builds it once per `body` from `model.defaultPace` (`init(model:)`), so the intro and the sections read the same pace, and Observation redraws the page when it changes (`HowItNudgesPageTests`). The intro nests `Pace.title`, a `LocalizedStringResource`, in its own; Apple's docs don't cover that nesting, so the iOS review checked with a throwaway script that the inner resource localizes in the outer's locale. Without a model the page takes `previewDefaultPace`, which `SettingsTab` now passes too, and it gained an Escalating preview.

**2026-10-23, beyond the criteria.** The walk's `testSettings` puts the Default Pace back to Consistent · 10 min after the 30 min shot, shoots `settings-how-it-nudges` there, then chooses Escalating and shoots `settings-how-it-nudges-escalating`. Before, the page was shot in 4 pages, which at the largest text never got past the welcome's points, and in landscape on iOS 27.0 stopped at Firm. `shot` gained `stopsAtEnd`: `pages` becomes a limit (40 here), and it stops once a page matches one of the two before it, since at the end a scroll expands or collapses the tab bar and the last pages alternate. A rolled-over status-bar minute can leave a few extra end pages; none are lost. `scripts/mockup-shots.py` gained `settings-how-it-nudges-escalating`.

**2026-10-23, simulators passed.** `scripts/screenshots.sh` with `SHOTS_TESTS="testSettings"` on iPhone 15 Pro (iOS 26.5) and iPhone 15 (iOS 27.0), in portrait, landscape and the largest text size. Under Consistent · 10 min the intro reads "…at your Default Pace, Consistent · 10 min, with Break Through Focus on." and the rows fold (Gentle "Nudges 1–4 when due, every 10 min", Relentless one Urgent row); under Escalating it names Escalating and shows each strength's own waits. Every section and summary is shot to the end of Relentless in each variant, and paired with the mockup's page (item 13) it matches. During the 26.5 landscape run the simulator's SpringBoard crashed once (a segfault in Apple's process, not the app); every shot was still taken.

