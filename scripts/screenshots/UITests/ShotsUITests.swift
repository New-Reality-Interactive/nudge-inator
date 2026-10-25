import XCTest

/// Walks every screen of the harness app and saves a screenshot of each to `SHOTS_DIR` (set by
/// scripts/screenshots.sh as `TEST_RUNNER_SHOTS_DIR`), named `<screen>.png`. `SHOTS_ORIENTATION`
/// is `portrait` or `landscape`; the text size is the simulator's, which the script sets.
@MainActor
final class ShotsUITests: XCTestCase {
    /// The harness's `SHOT_SCENARIO`s (`ShotsApp.Scenario`, which can't be imported here).
    enum ShotScenario: String {
        case app, onboarding, notificationsOff, alarmsOff, timeSensitiveOff, customLocking
    }

    private var app: XCUIApplication!
    private let directory = URL(filePath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory())

    override func setUp() async throws {
        continueAfterFailure = true
        let landscape = ProcessInfo.processInfo.environment["SHOTS_ORIENTATION"] == "landscape"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
    }

    private func launch(_ scenario: ShotScenario, dark: Bool = false) {
        app = XCUIApplication()
        app.launchEnvironment["SHOT_SCENARIO"] = scenario.rawValue
        app.launchEnvironment["SHOT_DARK"] = dark ? "1" : "0"
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

    /// Four scrolls up.
    private func scrollToTop() {
        for _ in 0..<4 { scroll(down: false) }
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Saves the screen, then `pages - 1` more, scrolling down most of a screen before each.
    /// With `stopsAtEnd`, `pages` is a limit: it stops once a scroll leaves the screen as one of
    /// the last two pages, for a page whose length differs a lot between the variants. Two, since
    /// at the end a scroll expands or collapses the tab bar, so the last pages alternate.
    private func shot(_ name: String, pages: Int = 1, stopsAtEnd: Bool = false) {
        pause(0.8)
        var lastTwo: [Data] = []
        for page in 1...pages {
            let suffix = pages > 1 ? "-\(page)" : ""
            let data = XCUIScreen.main.screenshot().pngRepresentation
            if stopsAtEnd, lastTwo.contains(data) {
                break
            }
            lastTwo = Array((lastTwo + [data]).suffix(2))
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

    /// The first element on screen whose label is `label`, of any type, scrolling down up to
    /// `scrolls` times to find it.
    private func scrollTo(_ label: String, scrolls: Int = 14) -> XCUIElement? {
        // A row's label can carry its value: "Repeat, Never". Not the tab bar's buttons, named by
        // their symbols, which stay in the hierarchy under a sheet.
        let query = app.descendants(matching: .any).matching(NSPredicate(
            format: "(label == %@ OR label BEGINSWITH %@) AND NOT (identifier IN %@)",
            label, "\(label), ", ["bell", "calendar", "tag", "gearshape"]
        ))
        // The first one on screen: a sheet leaves the screens under it in the hierarchy.
        func onScreen() -> XCUIElement? { query.allElementsBoundByIndex.first { $0.isHittable } }
        var tries = 0
        while onScreen() == nil, tries < scrolls {
            scroll(down: true)
            tries += 1
        }
        return onScreen()
    }

    /// The first element whose label is `label`, of any type, scrolling down to find it: from the
    /// top unless `inSheet`, where swiping down would close the sheet.
    private func tapText(_ label: String, inSheet: Bool = false, scrolls: Int = 14) {
        if !inSheet {
            scrollToTop()
        }
        guard let element = scrollTo(label, scrolls: scrolls) else {
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

    /// My Day's Filter button, and with a tag chosen its menu (ticket 20), which also has an item
    /// named Filter by Tags: the button is the topmost.
    private var myDayFilterButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "Filter by Tags"))
    }

    /// Opens My Day's filter sheet: with a tag chosen, through the Filter menu's Filter by Tags.
    private func openMyDayFilter() {
        barTap {
            scrollToTop()
            myDayFilterButtons.firstMatch.tap()
            if app.buttons["Clear All Tags"].waitForExistence(timeout: 2) {
                myDayFilterButtons.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }?.tap()
            }
            XCTAssert(app.navigationBars["Filter My Day"].waitForExistence(timeout: 3), "No Filter My Day sheet")
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
        // Nine pages, so the largest text size reaches the locked Pace and Every rows.
        shot("form-edit-locked", pages: 9)
        barTap { tapButton(containing: "Cancel", inSheet: true) }
        back()
        tapText("Water the plants")
        shot("details-coming-up", pages: 4)
    }

    func testMyDay() {
        launch(.app)
        tab("My Day")
        shot("myday", pages: 20, stopsAtEnd: true)
        openMyDayFilter()
        shot("myday-filter")
        // The Filter button with a tag chosen: its badge shows the count.
        tapText("#health", inSheet: true)
        barTap { tapButton(containing: "Done", inSheet: true) }
        shot("myday-filtered")
    }

    /// The Filter button's badge as tags come off the filter: the badge follows the count when a
    /// token is removed from My Day, not only when the filter sheet closes (found on the iPhone,
    /// ticket 19).
    func testMyDayFilterBadgeFollowsTokens() {
        launch(.app)
        tab("My Day")
        openMyDayFilter()
        tapText("#health", inSheet: true)
        tapText("#work", inSheet: true)
        barTap { tapButton(containing: "Done", inSheet: true) }
        shot("myday-badge-2-tags")
        tapButton(containing: "Remove #work")
        shot("myday-badge-1-tag-after-remove")
        tapButton(containing: "Remove #health")
        shot("myday-badge-0-tags-after-remove")
    }

    /// What VoiceOver gets for the Filter button with none, one and two tags chosen: its label and
    /// value, in the test log (`ACCESSIBILITY` lines). VoiceOver speaks the label, then the value.
    func testMyDayFilterAccessibility() {
        launch(.app)
        tab("My Day")
        func report(_ count: Int) {
            let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Filter by Tags")).firstMatch
            print("ACCESSIBILITY \(count) tags: label=\"\(button.label)\" value=\"\(button.value as? String ?? "nil")\"")
        }
        report(0)
        openMyDayFilter()
        tapText("#health", inSheet: true)
        barTap { tapButton(containing: "Done", inSheet: true) }
        report(1)
        openMyDayFilter()
        tapText("#work", inSheet: true)
        barTap { tapButton(containing: "Done", inSheet: true) }
        report(2)
    }

    /// Six tags, wrapping to at most three rows with "+N more" past them, then the Filter button's
    /// menu (ticket 20): a tap shows Filter by Tags and Clear All Tags, at every text size, and Clear
    /// All Tags removes every tag. What VoiceOver gets is in the test log (`ACCESSIBILITY` lines).
    func testMyDayClearAllTags() {
        launch(.app)
        tab("My Day")
        let filter = myDayFilterButtons.firstMatch
        // With none chosen the button isn't a menu: a tap opens the sheet.
        openMyDayFilter()
        // The sheet lists tags A to Z and tapText scrolls only down, so #appointments goes first: last,
        // it was missed in landscape and at the largest size.
        for tag in ["#appointments", "#home", "#health", "#work", "#money", "#morning"] {
            tapText(tag, inSheet: true)
        }
        barTap { tapButton(containing: "Done", inSheet: true) }
        XCTAssertEqual(filter.value as? String, "6 chosen", "A tag wasn't chosen")
        shot("myday-tokens-6")
        // The tokens' hidden measuring copies aren't elements.
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Remove #home from the filter")).count, 1)
        let more = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "more tags")).firstMatch
        if more.exists {
            print("ACCESSIBILITY more token: label=\"\(more.label)\"")
            more.tap()
            XCTAssert(app.navigationBars["Filter My Day"].waitForExistence(timeout: 3), "+N more didn't open the sheet")
            barTap { tapButton(containing: "Done", inSheet: true) }
        }
        print("ACCESSIBILITY 6 tags: label=\"\(filter.label)\" value=\"\(filter.value as? String ?? "nil")\"")
        let clear = app.buttons["Clear All Tags"]
        barTap {
            scrollToTop()
            filter.tap()
            XCTAssert(clear.waitForExistence(timeout: 3), "The Filter menu didn't open")
            shot("myday-filter-menu")
            print("ACCESSIBILITY menu items: \(myDayFilterButtons.count) named Filter by Tags, clear=\"\(clear.label)\"")
            clear.tap()
        }
        shot("myday-cleared")
        XCTAssertFalse(app.buttons["Remove #home from the filter"].exists, "Clear All Tags left a token")
        XCTAssertEqual(filter.value as? String ?? "", "", "The Filter button still has a count")
        // No Tags is cleared too.
        openMyDayFilter()
        tapText("No Tags", inSheet: true)
        barTap { tapButton(containing: "Done", inSheet: true) }
        barTap {
            scrollToTop()
            filter.tap()
            XCTAssert(clear.waitForExistence(timeout: 3), "The Filter menu didn't open with No Tags")
            clear.tap()
        }
        XCTAssertFalse(app.buttons["Remove No Tags from the filter"].exists, "Clear All Tags left No Tags")
    }

    /// The seed's tags, as the filter sheet lists them.
    private let seedTags = ["#appointments", "#health", "#home", "#money", "#morning", "#travel", "#work"]

    /// Where each tag row on screen is, by its tag.
    private func tagRowFrames() -> [String: CGRect] {
        var frames: [String: CGRect] = [:]
        for tag in seedTags {
            let row = app.buttons.matching(NSPredicate(format: "label == %@", tag)).allElementsBoundByIndex.first { $0.isHittable }
            frames[tag] = row?.frame
        }
        return frames
    }

    /// Checks that `tap` left every tag row on screen where it was (ticket 23).
    private func keepingTagRows(_ what: String, _ tap: () -> Void) {
        let before = tagRowFrames()
        tap()
        let after = tagRowFrames()
        XCTAssertFalse(before.isEmpty, "\(what): no tag row on screen")
        for (tag, frame) in before {
            XCTAssertEqual(after[tag], frame, "\(what) moved \(tag)")
        }
    }

    /// `tapText` in the filter sheet, checking the tag rows stay where they were. It scrolls to the
    /// row first, so only the tap is measured.
    private func tapKeepingTagRows(_ label: String) {
        _ = scrollTo(label)
        keepingTagRows("Tapping \(label)") { tapText(label, inSheet: true) }
    }

    /// Checking or unchecking a tag, checking or unchecking No Tags, and Clear leave every tag row
    /// where it was, starting from one tag and from two (ticket 23): Match is always shown above the
    /// rows, so nothing appears there as the count crosses two.
    func testMyDayFilterRowsStayPut() {
        launch(.app)
        tab("My Day")
        // A to Z, since tapText scrolls only down.
        for start in [["#appointments"], ["#appointments", "#health"]] {
            openMyDayFilter()
            start.forEach(tapKeepingTagRows)
            tapKeepingTagRows("#home")
            tapKeepingTagRows("#home")
            tapKeepingTagRows("No Tags")
            tapKeepingTagRows("No Tags")
            barTap { tapButton(containing: "Done", inSheet: true) }
            openMyDayFilter()
            start.forEach(tapKeepingTagRows)
            barTap {
                keepingTagRows("Clear") {
                    app.navigationBars["Filter My Day"].buttons["Clear"].tap()
                    pause(0.8)
                }
                tapButton(containing: "Done", inSheet: true)
            }
        }
    }

    /// The filter sheet's Match choice with no tag, one tag and No Tags (dimmed) and with two tags
    /// (working), light and dark (ticket 23). What VoiceOver gets for it is in the test log
    /// (`ACCESSIBILITY` lines).
    func testMyDayFilterMatch() {
        for dark in [false, true] {
            launch(.app, dark: dark)
            let suffix = dark ? "-dark" : ""
            tab("My Day")
            openMyDayFilter()
            func report(_ state: String) {
                // A segmented control, whose segments carry the text, or at the accessibility sizes a
                // menu button. A list drops it once scrolled out of view.
                let segmented = app.segmentedControls.firstMatch
                let menu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Match")).firstMatch
                if segmented.exists {
                    let segments = segmented.buttons.allElementsBoundByIndex.map { "\($0.label)\($0.isSelected ? " (selected)" : "")" }
                    print("ACCESSIBILITY Match, \(state): segments=\(segments) enabled=\(segmented.isEnabled)")
                } else if menu.exists {
                    print("ACCESSIBILITY Match, \(state): label=\"\(menu.label)\" value=\"\(menu.value as? String ?? "nil")\" enabled=\(menu.isEnabled)")
                } else {
                    print("ACCESSIBILITY Match, \(state): scrolled out of view")
                }
            }
            shot("myday-filter-0\(suffix)")
            report("no tags checked")
            tapText("#appointments", inSheet: true)
            shot("myday-filter-1\(suffix)")
            report("one tag")
            tapText("#health", inSheet: true)
            shot("myday-filter-2\(suffix)")
            report("two tags")
            tapText("No Tags", inSheet: true)
            shot("myday-filter-no-tags\(suffix)")
            report("No Tags")
            app.terminate()
        }
    }

    /// The Filter button's badge at counts the seed can't reach: 12 (two digits) and 999 (the most).
    func testMyDayFilterBadge() {
        for count in [12, 999] {
            app = XCUIApplication()
            app.launchEnvironment["SHOT_BADGE_COUNT"] = "\(count)"
            app.launch()
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
            shot("myday-badge-\(count)")
            app.terminate()
        }
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
        tapText("Default Pace")
        shot("settings-default-pace")
        // A new wait, which the row under the label shows on return.
        // The row's button, "Every, 10 min": a tap on its "Every" text doesn't open the menu.
        tapButton(containing: "Every, ", inSheet: true)
        // Without scrolling to the top first, which would close the menu.
        tapText("30 min", inSheet: true)
        back()
        shot("settings-default-pace-30-min")
        // The page under each pace, as in the mockup (item 13): Consistent · 10 min, then Escalating.
        // Four pages in portrait, many more at the largest text.
        tapText("Default Pace")
        tapButton(containing: "Every, ", inSheet: true)
        tapText("10 min", inSheet: true)
        back()
        tapText("How It Nudges")
        shot("settings-how-it-nudges", pages: 40, stopsAtEnd: true)
        back()
        tapText("Default Pace")
        // At accessibility sizes the pace is a menu rather than segments.
        let segment = app.buttons["Escalating"]
        if !segment.waitForExistence(timeout: 2) || !segment.isHittable {
            tapText("Pace")
        }
        // Without scrolling to the top first, which would close the menu.
        tapText("Escalating", inSheet: true)
        back()
        tapText("How It Nudges")
        shot("settings-how-it-nudges-escalating", pages: 40, stopsAtEnd: true)
    }

    func testForm() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        // Eight pages: Consistent's Every row pushes How It Nudges further down at the largest text.
        shot("form-new", pages: 8)
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

    /// The New form opens at the Default Pace, Consistent · 10 min, so this chooses Escalating.
    func testFormEscalating() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        // At accessibility sizes the pace is a menu rather than segments.
        let segment = app.buttons["Escalating"]
        if !segment.waitForExistence(timeout: 2) || !segment.isHittable {
            tapText("Pace", inSheet: true)
        }
        tapText("Escalating", inSheet: true)
        shot("form-new-escalating", pages: 8)
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
        // The checkmark chooses the weekly repeat the page shows, unchanged, from Never (ticket 17).
        barTap { app.navigationBars["Custom"].buttons["Done"].tap() }
        XCTAssert(app.navigationBars["Repeat"].waitForExistence(timeout: 3), "The checkmark didn't go back to Repeat")
        shot("form-custom-chosen", pages: 2)
        reportFormPageAccessibility("repeat-chosen")
        // Only the Repeat page's checkmark makes the choice the repeat (ticket 22).
        barTap { app.navigationBars["Repeat"].buttons["Done"].tap() }
        XCTAssert(app.navigationBars["New Reminder"].waitForExistence(timeout: 3), "The checkmark didn't go back to the form")
        shot("form-repeat-chosen")
    }

    /// The Custom page of a reminder that starts nudging while it's open (ticket 16), light and
    /// dark, before and after the lock, and what VoiceOver gets for its controls once locked, in the
    /// test log (`ACCESSIBILITY` lines), then the locked Repeat page. Each launch waits up to 210
    /// seconds for the lock. It only scrolls down: at the top of the sheet a drag down would close it.
    func testCustomLocking() {
        for dark in [false, true] {
            let name = dark ? "form-custom-locking-dark" : "form-custom-locking"
            launch(.customLocking, dark: dark)
            tapText("Plan the week")
            openSheet("Edit", title: "Edit Reminder")
            hideKeyboard()
            tapText("Repeat", inSheet: true)
            shot("\(name)-repeat-unlocked")
            tapText("Custom", inSheet: true)
            shot("\(name)-unlocked")
            if !dark { reportFormPageAccessibility("custom-unlocked") }
            let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Nudging now.")).firstMatch
            XCTAssert(note.waitForExistence(timeout: 210), "The Custom page didn't lock")
            for page in 1...5 {
                shot("\(name)-locked-\(page)")
                if !dark { reportFormPageAccessibility("custom-locked-\(page)") }
                scroll(down: true)
            }
            // Back to the Repeat page, locked too, with its checkmark (ticket 22).
            barTap { app.navigationBars["Custom"].buttons.firstMatch.tap() }
            XCTAssert(app.navigationBars["Repeat"].waitForExistence(timeout: 3), "Back didn't go to Repeat")
            shot("\(name)-repeat-locked", pages: 2)
            if !dark { reportFormPageAccessibility("repeat-locked") }
            app.terminate()
        }
    }

    /// The lines of the accessibility tree on screen that name the Repeat and Custom pages'
    /// headings, choices, steppers and checkmarks: each one's type, label, value and whether it's
    /// disabled, under `screen`, such as "custom-locked-2". XCUITest doesn't expose the hint, so
    /// that stays a device check.
    private func reportFormPageAccessibility(_ screen: String) {
        let names = ["Frequency", "Daily", "Weekly", "Monthly", "Yearly", "Every", "'On", "Ends", "Never", "After", "On Date", "End Date", "ncrement", "ecrement", "Done"]
        for line in app.debugDescription.split(separator: "\n") where names.contains(where: { line.contains($0) }) {
            print("ACCESSIBILITY \(screen): \(line.trimmingCharacters(in: .whitespaces))")
        }
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
        shot("banner-time-sensitive-off", pages: 3)
    }
}
