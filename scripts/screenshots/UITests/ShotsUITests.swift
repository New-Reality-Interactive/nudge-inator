import XCTest

/// Walks every screen of the harness app and saves a screenshot of each to `SHOTS_DIR` (set by
/// scripts/screenshots.sh as `TEST_RUNNER_SHOTS_DIR`), named `<screen>.png`. `SHOTS_ORIENTATION`
/// is `portrait` or `landscape`; the text size is the simulator's, which the script sets.
@MainActor
final class ShotsUITests: XCTestCase {
    /// The harness's `SHOT_SCENARIO`s (`ShotsApp.Scenario`, which can't be imported here).
    enum ShotScenario: String {
        case app, onboarding, notificationsOff, alarmsOff, timeSensitiveOff
    }

    private var app: XCUIApplication!
    private let directory = URL(filePath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory())

    override func setUp() async throws {
        continueAfterFailure = true
        let landscape = ProcessInfo.processInfo.environment["SHOTS_ORIENTATION"] == "landscape"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
    }

    private func launch(_ scenario: ShotScenario) {
        app = XCUIApplication()
        app.launchEnvironment["SHOT_SCENARIO"] = scenario.rawValue
        app.launch()
        // The seed and the first plan.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        pause(1.5)
    }

    /// Drags the window's middle by most of a screen: down shows what's below. Not `swipeUp()`,
    /// which didn't scroll in landscape (iOS 26.5 simulator).
    private func scroll(down: Bool) {
        let window = app.windows.firstMatch
        let low = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let high = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        let (from, to) = down ? (low, high) : (high, low)
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    private func scrollToTop() {
        for _ in 0..<4 { scroll(down: false) }
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Saves the screen, then `pages - 1` more, scrolling down most of a screen before each.
    private func shot(_ name: String, pages: Int = 1) {
        pause(0.8)
        for page in 1...pages {
            let suffix = pages > 1 ? "-\(page)" : ""
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: directory.appending(path: "\(name)\(suffix).png"))
            if page < pages {
                scroll(down: true)
                pause(0.8)
            }
        }
    }

    /// Scrolls to the top first: scrolling down collapses the tab bar to the current tab. The Now
    /// tab's label carries its badge, so it is matched by its start.
    private func tab(_ title: String) {
        scrollToTop()
        let button = app.tabBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        // A short page may leave it collapsed; tapping the one tab left expands it.
        let collapsed = app.tabBars.buttons.matching(NSPredicate(format: "value == 'Collapsed'")).firstMatch
        if !button.exists, collapsed.exists {
            collapsed.tap()
        }
        guard button.waitForExistence(timeout: 3) else {
            XCTFail("No \(title) tab:\n\(app.debugDescription)")
            return
        }
        button.tap()
        pause(0.5)
    }

    /// The first element whose label is `label`, of any type, scrolling down to find it: from the
    /// top unless `inSheet`, where swiping down would close the sheet.
    private func tapText(_ label: String, inSheet: Bool = false, scrolls: Int = 14) {
        // A row's label can carry its value: "Repeat, Never". Not the tab bar's buttons, named by
        // their symbols, which stay in the hierarchy under a sheet.
        let query = app.descendants(matching: .any).matching(NSPredicate(
            format: "(label == %@ OR label BEGINSWITH %@) AND NOT (identifier IN %@)",
            label, "\(label), ", ["bell", "calendar", "tag", "gearshape"]
        ))
        // The first one on screen: a sheet leaves the screens under it in the hierarchy.
        func onScreen() -> XCUIElement? { query.allElementsBoundByIndex.first { $0.isHittable } }
        if !inSheet {
            scrollToTop()
        }
        var tries = 0
        while onScreen() == nil, tries < scrolls {
            scroll(down: true)
            tries += 1
        }
        guard let element = onScreen() else {
            XCTFail("No \(label):\n\(app.debugDescription)")
            return
        }
        element.tap()
        pause(0.8)
    }

    /// Scrolls to the top first, unless `inSheet`: a list drops rows scrolled out of view.
    private func tapButton(containing text: String, inSheet: Bool = false) {
        if !inSheet {
            scrollToTop()
        }
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.tap()
        pause(0.8)
    }

    /// Runs a tap on a navigation bar button. In landscape such a tap never landed (iOS 26.5
    /// simulator) though rows and tabs did, so the phone is turned to portrait for it and back.
    private func barTap(_ tap: () -> Void) {
        let landscape = XCUIDevice.shared.orientation.isLandscape
        if landscape {
            XCUIDevice.shared.orientation = .portrait
            pause(1)
        }
        tap()
        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            pause(1)
        }
    }

    /// Taps the bar button, then waits for the sheet titled `title`.
    private func openSheet(_ button: String, title: String) {
        barTap {
            tapButton(containing: button)
            XCTAssert(app.navigationBars[title].waitForExistence(timeout: 3), "No \(title) sheet")
        }
    }

    /// A return in the focused title hides the keyboard, so the rows under it can be reached.
    private func hideKeyboard() {
        if app.keyboards.firstMatch.waitForExistence(timeout: 2) { app.typeText("\n") }
    }

    /// The simulator's first keyboard shows a tip about sliding to type, over the sheet. Dismissing
    /// it is for good, simulator-wide (device-testing.md, Simulator screenshots).
    private func dismissKeyboardTip() {
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
    }

    /// The topmost screen's back button: a sheet's page leaves the screen under it in the hierarchy.
    private func back() {
        barTap {
            let buttons = app.navigationBars.buttons.matching(identifier: "BackButton")
            let visible = (0..<buttons.count).map { buttons.element(boundBy: $0) }.last { $0.isHittable }
            (visible ?? buttons.firstMatch).tap()
        }
        pause(0.8)
    }

    func testNow() {
        launch(.app)
        shot("now", pages: 3)
        tapText("Take the bins out")
        shot("details-nudging", pages: 4)
        openSheet("Edit", title: "Edit Reminder")
        shot("form-edit-locked", pages: 4)
        barTap { tapButton(containing: "Cancel", inSheet: true) }
        back()
        tapText("Water the plants")
        shot("details-coming-up", pages: 4)
    }

    func testMyDay() {
        launch(.app)
        tab("My Day")
        shot("myday", pages: 3)
        openSheet("Filter", title: "Filter My Day")
        shot("myday-filter")
    }

    func testTags() {
        launch(.app)
        tab("Tags")
        shot("tags", pages: 2)
        tapText("#home")
        shot("tag-home", pages: 2)
        back()
        barTap { tapButton(containing: "Edit") }
        shot("tags-edit")
        barTap { tapButton(containing: "Done") }
        openSheet("New Tag", title: "New Tag")
        dismissKeyboardTip()
        shot("tag-new")
    }

    func testSettings() {
        launch(.app)
        tab("Settings")
        shot("settings", pages: 2)
        tapText("How It Nudges")
        shot("settings-how-it-nudges", pages: 4)
    }

    func testForm() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        shot("form-new", pages: 4)
    }

    /// Its own test: `form-new` ends scrolled down, and scrolling up in a sheet could close it.
    func testFormRelentless() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        // At accessibility sizes the strength is a menu rather than segments.
        let segment = app.buttons["Relentless"]
        if !segment.waitForExistence(timeout: 2) || !segment.isHittable {
            tapText("Strength", inSheet: true)
        }
        tapText("Relentless", inSheet: true)
        // Eight pages: at the largest text, four end at the first How It Nudges row.
        shot("form-new-relentless", pages: 8)
    }

    /// Its own test: going back from the Tags page closed the sheet on the iOS 27.0 simulator.
    func testFormTags() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        tapText("Tags", inSheet: true)
        shot("form-tags")
    }

    func testFormPages() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        tapText("Repeat", inSheet: true)
        shot("form-repeat", pages: 2)
        tapText("Custom", inSheet: true)
        shot("form-custom", pages: 3)
    }

    func testOnboarding() {
        launch(.onboarding)
        shot("onboarding")
    }

    /// Several pages of each long banner: at the largest text the first shows only its start.
    func testNotificationsOff() {
        launch(.notificationsOff)
        shot("banner-notifications-off", pages: 4)
        tab("Settings")
        shot("settings-notifications-off", pages: 2)
    }

    func testAlarmsOff() {
        launch(.alarmsOff)
        shot("banner-alarms-off", pages: 3)
        tab("Settings")
        shot("settings-alarms-off")
    }

    func testTimeSensitiveOff() {
        launch(.timeSensitiveOff)
        shot("banner-time-sensitive-off")
    }
}
