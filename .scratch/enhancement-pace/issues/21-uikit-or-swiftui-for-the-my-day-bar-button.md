# 21: Research: should My Day's Filter button move from SwiftUI to UIKit?

**What to build:** A written recommendation, in this ticket's Comments, on whether My Day's Filter button and its badge stay in SwiftUI or use UIKit's bar button item, with what each choice costs and buys the app, backed by Apple's docs and a throwaway spike. The app doesn't change.

**Type:** research

**Blocked by:** None (can start immediately).

**Status:** needs-triage

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

- [ ] **Reach:** the Comments name the smallest route, and say for each route Apple documents whether it is documented or depends on lookups that could break, citing the page (found with `apple-rag-mcp`) or marking it as only observed.
- [ ] **Buys:** a throwaway spike, not merged, shows on both simulators at the default and the largest text size whether a UIKit badge can be teal and can stay small; the Comments record what each shot showed. If the simulators show promise, it is also checked on the iPhone.
- [ ] **Costs:** each cost above gets an answer in a sentence or two, marked as confirmed by docs or only observed.
- [ ] **Elsewhere:** the Comments say whether another screen is likely to need the same.
- [ ] **Recommendation:** the Comments end with one of keep SwiftUI, bridge this one button, or something else, with the evidence, and list the tickets it would create. Brian accepts or rejects it, and that is recorded in Comments.

## Before you start

- Builds on: ticket 19 (Comments: the badge color, the largest-text findings and the stale-badge fix).
- Watch for: the iPhone (iOS 27.0.1) and the iOS 26.5 simulator drew the badge differently, so check each.
- Developer stops: an iPhone check of the spike, if it gets that far; Brian's decision on the recommendation.

## Comments
