# Research for ticket 21: SwiftUI or UIKit for My Day's Filter button

Docs research only, from `apple-rag-mcp` on 2026-10-24. The ticket's throwaway spike has not been run yet. Each claim below is marked **docs** (a cited Apple page says it) or **check** (the docs say nothing, so a simulator or iPhone has to show it).

## Answer first

- **Smallest documented route:** host My Day's content in a `UIHostingController` inside a `UINavigationController`, wrapped in a `UIViewControllerRepresentable`. Then set `navigationItem.rightBarButtonItems` to UIKit `UIBarButtonItem`s, with `badge` on the Filter item. Every piece is documented, but no page documents the mix. Nothing says how SwiftUI's `.toolbar`, `.navigationTitle` and `NavigationStack` path behave inside a hosting controller that UIKit pushes. New Reminder, the title and My Day's pushes to Details would also have to move to UIKit's bar and stack. That surface is not small.
- **Smaller routes are not documented:** reaching the `UINavigationController` or `UIBarButtonItem` that SwiftUI's `NavigationStack` builds, either from a representable or by walking the view tree, depends on SwiftUI being built on UIKit internally. No page says it is, so a later iOS could break it. Putting a UIKit view inside a SwiftUI `ToolbarItem` gives no UIKit badge, because `badge` exists only on `UIBarButtonItem`. Anything drawn there would be a custom badge, which ticket 19 ruled out.
- **What UIKit buys, per the docs:** `UIBarButtonItem.Badge` has `backgroundColor`, `foregroundColor` and `font` (iOS 26.0+), so a teal badge is documented. **Not documented:** whether a set `font` keeps the badge small at the accessibility sizes on iOS 27. That is the problem ticket 19 hit, so it is the spike's main question.
- **Recommendation: keep SwiftUI.** Accepted by Brian on 2026-10-25 without the spike (the ticket's Comments). The case: the only documented route rebuilds My Day's bar and navigation in UIKit for one badge, the docs alone don't justify that, and nothing else in the app needs it (see Elsewhere). Whether a UIKit badge stays bar-sized and teal at AX5 was left unchecked.

## Evidence per question

### Reach

| Route | Status | Source |
|---|---|---|
| SwiftUI `.badge(_:)` on the toolbar item's content (what ships now) | **docs**: "Badges appear in list rows, tab bars, toolbar items, and menus." iOS 15.0+. WWDC25 323 badges a toolbar item by applying the modifier to its content. | `badge(_:)`; WWDC25 323 |
| `UIViewControllerRepresentable` → `UINavigationController` → `UIHostingController` root, items on its `navigationItem` | **docs** for each piece: representables create and update a UIKit controller (iOS 13.0+); a hosting controller is used "like you would any other view controller" (iOS 13.0+); a navigation controller shows the top controller's `rightBarButtonItems`; `UIBarButtonItem.badge` is "Supported in navigation bars and toolbars" (iOS 26.0+). **check**: how SwiftUI's own `.toolbar` and `.navigationTitle` inside the hosted view behave there. The iOS docs say nothing; only macOS documents bridging (`NSHostingController.sceneBridgingOptions`, macOS 14+). | `UIViewControllerRepresentable`, `UIHostingController`, `UINavigationController`, `UINavigationItem`, `UIBarButtonItem.badge`, `NSHostingSceneBridgingOptions` |
| Representable inside SwiftUI's `NavigationStack` that sets its parent's `navigationItem` | **Depends on lookups**: no page says `NavigationStack` is backed by a `UINavigationController`. `navigationItem`'s doc warns against touching it "if you are not using a navigation controller". | `UIViewController.navigationItem` |
| Walking the view or controller tree to find SwiftUI's bar button item and set `.badge` | **Depends on lookups**: undocumented internals. | none |
| UIKit view (a `UIButton`) in a SwiftUI `ToolbarItem` | No UIKit badge: `badge` is a `UIBarButtonItem` property, not a `UIView` one. It would need a custom badge, which ticket 19 ruled out. | `UIBarButtonItem.badge` |

### What it buys

- **Teal: docs.** `UIBarButtonItemBadge.backgroundColor` is "The badge's background color. A nil value will be treated as an indication to use the system default." `foregroundColor` reads the same. Both iOS 26.0+.
- **Size: partly docs.** `UIBarButtonItemBadge.font`: "The font to use for the badge. A nil value… system default." (iOS 26.0+). `UIFontMetrics.scaledFont(for:maximumPointSize:)` (iOS 11.0+) returns a Dynamic Type font capped "when your interface cannot accommodate text that is any larger". **check**: whether the badge's capsule follows a supplied font, and whether iOS 27 still scales it to the text size.
- **Constructors: docs.** `Badge.count(_:)` ("The count is localized when shown, and will update when the app's locale changes"), `.string(_:)` and `.indicator()` (background only, no content). All iOS 26.0+.
- **Looks like the Now tab's badge? Not if it's teal.** The Now tab uses SwiftUI's `Tab.badge(_:)` (iOS 18.0+), and `badge(_:)` says "Styling the text view has no effect when the badge appears in a `TabView`", so the Now badge stays system red. A teal Filter badge would differ from it, which DESIGN.md's badge rule would have to say. A UIKit badge with `backgroundColor` left nil would be the system default, so presumably red. **check**: whether it matches the tab badge's red and shape.
- **iOS 27: docs silent.** The June 2026 SwiftUI updates list no badge changes. The toolbar additions are `visibilityPriority(_:)`, `ToolbarOverflowMenu`, `topBarPinnedTrailing` and `toolbarMinimizeBehavior(_:for:)`. No page says iOS 27 draws bar badges at the text size. That is observed only (ticket 19).

### What it costs

- **Glass and grouping: docs for UIKit-only bars.** WWDC25 284: "bar button items using images share the background with other image buttons". Assign all items "directly to the navigationItem's rightBarButtonItems" for the default grouping. A `fixedSpace` splits a group. Tint colors only the symbol; `.prominent` tints the background. So Filter and New Reminder share one capsule only if both are UIKit items in the same `rightBarButtonItems`. **check**: mixing a UIKit item with SwiftUI toolbar items in one bar. The docs say nothing about it.
- **VoiceOver reads the button once: docs silent for both frameworks.** No page says whether a SwiftUI or UIKit badge is read in addition to the label. Device check with 0, 1 and 12 chosen.
- **Large content viewer: docs for UIKit.** WWDC19 261: "If you're using standard UIKit bars, you already show the Large Content Viewer", and only at the accessibility sizes. Whether SwiftUI's toolbar does the same is not documented. **check**: long-press the Filter button at AX5.
- **Swift 6 isolation: docs.** `UIBarButtonItem.badge` and `UIBarButtonItem.Badge` are `@MainActor`, and `UIViewControllerRepresentable` and `UIHostingController` are `@MainActor @preconcurrency`. A bridge is main-actor UI code in the app target. NudgeEngine stays Foundation-only, so the AGENTS.md split is unaffected. `UIKit` is already imported in the app target (`App/Shell/SettingsStatus.swift`, `App/AppModel/AppDelegate.swift`).
- **Tests and screenshot harness: docs silent, check.** No page says how a `UIBarButtonItem` badge shows to XCUITest: whether it is in the button's label or value. `ShotsUITests` finds the button by its label, and `BadgeBarShot` in the harness would need the UIKit path too. Neither the SwiftUI nor the UIKit badge can be unit-tested.
- **Minimum iOS 26.1: docs.** Every badge API is iOS 26.0+, so no `#available` is needed and there is no iOS 26 fallback to keep.
- **Stale count (ticket 19's `.id` workaround): check.** With UIKit the badge is set directly in `updateUIViewController`, the representable's documented update path. Whether that removes the need for `.id(badgeCount)` is a spike check.

### Elsewhere

The app has only two badges: the Now tab's nudging count (`App/Shell/RootView.swift`, `Tab.badge`) and the Filter button. No other toolbar item shows a count; the toolbars are in `TagsTab`, `NowTab`, `ReminderDetailsView`, `TagRemindersView`, the sheets and `MyDayTab`. The Now tab badge is a tab-bar badge: the docs say SwiftUI styling has no effect there, and recoloring it in UIKit would mean bridging the whole `TabView`. Ticket 20's clear-all icon sits in My Day's content, not the bar. No other screen is likely to need UIKit for this reason.

## Docs silent, so device or simulator checks

1. Does `Badge.font` set to a fixed font, or to `UIFontMetrics…scaledFont(for:maximumPointSize:)`, keep the badge bar-sized at AX5 on the iOS 27.0 simulator and the iPhone (iOS 27.0.1)? And on the iOS 26.5 simulator?
2. Does `backgroundColor = AccentColor` show teal, with the number legible in light and dark?
3. In the representable route, do SwiftUI's `.navigationTitle`, `.toolbar` and `navigationDestination` inside the hosted view still work, or do they conflict with the UIKit navigation item?
4. Do a UIKit Filter item and New Reminder share one glass capsule on iOS 27 and iOS 26.5?
5. VoiceOver: is the badge read on top of the label, for both frameworks? (iPhone.)
6. Large content viewer on long-press at AX5, for both frameworks.
7. How XCUITest sees a UIKit badge (label or value), for `ShotsUITests`.
8. Does a UIKit badge follow a count that goes down without the filter sheet closing, with no `.id` workaround?
9. iOS 27 drawing bar badges at the text size has been observed only (ticket 19); no page explains it.

## Sources (apple-rag-mcp)

- SwiftUI `badge(_:)`, Text overload: https://developer.apple.com/documentation/swiftui/view/badge(_:)-6k2u9 ; Int overload: https://developer.apple.com/documentation/swiftui/view/badge(_:)
- SwiftUI `TabContent.badge(_:)`: https://developer.apple.com/documentation/swiftui/tabcontent/badge(_:)-8bxge
- SwiftUI `badgeProminence(_:)` (lists only): https://developer.apple.com/documentation/swiftui/view/badgeprominence(_:)
- UIKit `UIBarButtonItem.badge`: https://developer.apple.com/documentation/uikit/uibarbuttonitem/badge-1zzen and https://developer.apple.com/documentation/uikit/uibarbuttonitem/badge-4sz3f
- `UIBarButtonItem.Badge`: https://developer.apple.com/documentation/uikit/uibarbuttonitem/badge-swift.struct ; `count(_:)`: …/badge-swift.struct/count(_:) ; `string(_:)`: …/badge-swift.struct/string(_:) ; `indicator()`: …/badge-swift.struct/indicator()
- `UIBarButtonItemBadge`: https://developer.apple.com/documentation/uikit/uibarbuttonitembadge ; `backgroundColor`: …/uibarbuttonitembadge/backgroundcolor ; `foregroundColor`: …/uibarbuttonitembadge/foregroundcolor ; `font`: …/uibarbuttonitembadge/font ; `badgeWithCount:`: …/uibarbuttonitembadge/badgewithcount:
- `UIBarButtonItem.Style.prominent`: https://developer.apple.com/documentation/uikit/uibarbuttonitem/style-swift.enum/prominent
- `UINavigationItem`: https://developer.apple.com/documentation/uikit/uinavigationitem ; `UIViewController.navigationItem`: https://developer.apple.com/documentation/uikit/uiviewcontroller/navigationitem ; `UINavigationController`: https://developer.apple.com/documentation/uikit/uinavigationcontroller
- `UIHostingController`: https://developer.apple.com/documentation/swiftui/uihostingcontroller ; `UIViewControllerRepresentable`: https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable
- `NSHostingController.sceneBridgingOptions` (macOS only): https://developer.apple.com/documentation/swiftui/nshostingcontroller/scenebridgingoptions
- `UIFontMetrics.scaledFont(for:maximumPointSize:)`: https://developer.apple.com/documentation/uikit/uifontmetrics/scaledfont(for:maximumpointsize:)
- SwiftUI `accessibilityShowsLargeContentViewer(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(_:)
- UIKit updates (June 2025: "Add a badge to a UIBarButtonItem with badge"): https://developer.apple.com/documentation/updates/uikit
- SwiftUI updates (June 2026 toolbars, no badge changes): https://developer.apple.com/documentation/updates/swiftui
- WWDC25 284 "Build a UIKit app with the new design": https://developer.apple.com/videos/play/wwdc2025/284
- WWDC25 323 "Build a SwiftUI app with the new design": https://developer.apple.com/videos/play/wwdc2025/323
- WWDC26 269 "What's new in SwiftUI": https://developer.apple.com/videos/play/wwdc2026/269
- WWDC19 261 "Large Content Viewer": https://developer.apple.com/videos/play/wwdc2019/261
- WWDC22 10072 "Use SwiftUI with UIKit": https://developer.apple.com/videos/play/wwdc2022/10072
