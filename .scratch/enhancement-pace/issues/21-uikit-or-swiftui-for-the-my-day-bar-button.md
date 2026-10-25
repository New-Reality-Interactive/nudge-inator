# 21: Research: should My Day's Filter button move from SwiftUI to UIKit?

**What to build:** A written recommendation, in this ticket's Comments, on whether My Day's Filter button and its badge stay in SwiftUI or use UIKit's bar button item, with what each choice costs and buys the app, backed by Apple's docs and a throwaway spike. The app doesn't change.

**Type:** research

**Blocked by:** None (can start immediately).

**Status:** resolved

Raised by Brian, 2026-10-24, during ticket 19. Brian decides whether it's ready.

## Why it came up

Ticket 19 gave the Filter button SwiftUI's `.badge` for the number of tags chosen. On the iPhone (iOS 27.0.1) and the iOS 27.0 simulator the system draws that badge at the text size, so at the accessibility sizes it covers the tag icon and 999 reads "9…". The iOS 26.5 simulator keeps it small.

SwiftUI gives no control over the badge's size or color: tinting the button, styling the `Text` overload and limiting the button's Dynamic Type size all did nothing. UIKit's `UIBarButtonItem.Badge` (iOS 26) has a background color, a foreground color and a font. Ticket 19 therefore left the badge off at the accessibility sizes "for now" and kept the system's red capsule. The same `.badge` also kept a stale count when a token took it down without the filter sheet closing, which ticket 19 fixed by giving each count its own button.

Brian wants to know what the UIKit route would mean before deciding whether it is worth it.

## Questions

- **Reach:** what is the smallest UIKit surface that puts a badged bar button item into a SwiftUI `NavigationStack`'s bar, and which routes does Apple document, as against ones that depend on looking up views and could break in a later iOS?
- **What it buys:** can a UIKit badge be teal, and can its size be kept in step with the bar's icons at the accessibility sizes? Does it look like the Now tab's badge?
- **What it costs:**
  - the bar's glass look and grouping (the two buttons share one capsule on iOS 27);
  - VoiceOver reading the button once;
  - Swift 6 isolation, and the engine and app split (AGENTS.md, Structure);
  - what the tests and the screenshot harness can reach;
  - keeping the minimum at iOS 26.1.
- **Elsewhere:** is anything else in the app likely to need UIKit for the same reason?

Not in scope: building the bridge in the app, or changing the badge.

## What it should do

- [x] **Reach:** the Comments name the smallest route, and say for each route Apple documents whether it is documented or depends on lookups that could break, citing the page (found with `apple-rag-mcp`) or marking it as only observed.
- [x] **Buys:** a throwaway spike, not merged, shows on both simulators at the default and the largest text size whether a UIKit badge can be teal and can stay small; the Comments record what each shot showed. If the simulators show promise, it is also checked on the iPhone.
- [x] **Costs:** each cost above gets an answer in a sentence or two, marked as confirmed by docs or only observed.
- [x] **Elsewhere:** the Comments say whether another screen is likely to need the same.
- [x] **Recommendation:** the Comments end with one of keep SwiftUI, bridge this one button, or something else, with the evidence, and list the tickets it would create. Brian accepts or rejects it, and that is recorded in Comments.

## Before you start

- Builds on: ticket 19 (Comments: the badge color, the largest-text findings and the stale-badge fix).
- Watch for: the iPhone (iOS 27.0.1) and the iOS 26.5 simulator drew the badge differently, so check each.
- Developer stops: an iPhone check of the spike, if it gets that far; Brian's decision on the recommendation.

## Comments

### 2026-10-24: What Apple's docs say, before the spike

Docs research with `apple-rag-mcp`, in `.scratch/enhancement-pace/research/21-uikit-or-swiftui-for-the-my-day-bar-button.md` (citations and the full list of checks are there). The spike hasn't been run, so no criterion is ticked. Reach and Costs still need the spike's answers to their checks; Buys, Elsewhere and Recommendation are open too.

- **Reach:** the smallest documented route is a `UIViewControllerRepresentable` holding a `UINavigationController` with a `UIHostingController` root, with the bar's items on its `navigationItem.rightBarButtonItems`. Each piece is documented, but no page says how SwiftUI's `.toolbar`, `.navigationTitle` and pushes behave inside it (only macOS documents bridging). New Reminder, the title and My Day's pushes would move with it. Reaching the bar that SwiftUI's `NavigationStack` builds, from a representable or by walking views, depends on undocumented internals. A UIKit view in a `ToolbarItem` gets no UIKit badge, since `badge` is only on `UIBarButtonItem`.
- **Buys:** `UIBarButtonItem.Badge` has `backgroundColor`, `foregroundColor` and `font`, all iOS 26.0+, so a teal badge is documented. Whether a set font keeps it small at AX5 on iOS 27 is not documented; that is the spike's main question. A teal badge would no longer match the Now tab's, which stays red because the docs say SwiftUI styling has no effect on `TabView` badges.
- **Costs:** grouping: confirmed for UIKit-only bars (WWDC25 284: image items in `rightBarButtonItems` share one capsule); mixing UIKit and SwiftUI items in one bar is a check. VoiceOver: the docs say nothing for either framework; device check. Swift 6: confirmed, all of it is `@MainActor` app-target code, and NudgeEngine is untouched. Tests and harness: how XCUITest sees a UIKit badge is a check. iOS 26.1: confirmed, every API is iOS 26.0+, so no `#available`. The UIKit large content viewer is documented for standard UIKit bars (WWDC19 261); SwiftUI's isn't.
- **Elsewhere:** confirmed from the code: no other bar button shows a count. The Now tab badge is a tab-bar badge, and ticket 20's clear-all icon is in the content, not the bar.
- **Provisional recommendation:** keep SwiftUI, unless the spike shows a UIKit badge that stays bar-sized and teal at AX5 on the iOS 27.0 simulator and the iPhone. Bridging means moving My Day's bar and navigation to UIKit for one badge. Next: the spike, then Brian's decision.

### 2026-10-25: Brian keeps SwiftUI

> *This was generated by AI during triage.*

Brian accepted the recommendation without the spike: **keep SwiftUI**. The Filter button keeps SwiftUI's `.badge`, still off at the accessibility sizes (ticket 19), and no tickets are created. Why: SwiftUI is Apple's default for new work and UIKit is for where SwiftUI falls short (WWDC24 10150, *SwiftUI essentials*). The only documented bridge moves My Day's bar and navigation to UIKit for one badge, and nothing else in the app needs it.

The criteria, with the changes Brian agreed:

- **Reach:** met by the docs research (2026-10-24 comment, and `.scratch/enhancement-pace/research/21-uikit-or-swiftui-for-the-my-day-bar-button.md`).
- **Buys:** changed. The spike isn't run, so whether a UIKit badge can be teal and stay small at AX5 is left unanswered. The docs confirm only that it can be teal.
- **Costs:** changed. The costs marked "check" in the research note (mixed-bar grouping, VoiceOver, XCUITest, the stale count) stay unanswered, since no bridge is built.
- **Elsewhere:** met: no other bar button shows a count.
- **Recommendation:** met: keep SwiftUI, accepted by Brian on 2026-10-25.

If iOS changes how it draws the bar badge, or the app needs a badge that SwiftUI can't style, this research is the place to start.
