import Foundation
import Testing
@testable import NudgeInator

/// The tab shell's four tabs, against the mockup's `TABS` and `ROOTS` (index.html).
struct AppTabTests {
    @Test func theTabsAreInTheMockupsOrderWithItsTitlesAndSymbols() {
        let tabs = AppTab.allCases.map { (String(localized: $0.title), $0.systemImage) }

        #expect(tabs.map(\.0) == ["Now", "My Day", "Tags", "Settings"])
        #expect(tabs.map(\.1) == ["bell", "calendar", "tag", "gearshape"])
    }

    /// The mockup's Open goes to Now with the reminder pushed (index.html, `data-alarm="open"`),
    /// so reminder details, like Now itself, select Now.
    @Test(arguments: [AppModel.Route.now, .reminderDetails(UUID())])
    func aRouteSelectsNow(_ route: AppModel.Route) {
        #expect(AppTab(route: route) == .now)
    }
}
