import notify
import XCTest

/// Walks every screen of the harness app and saves a screenshot of each to `SHOTS_DIR` (set by
/// scripts/screenshots.sh as `TEST_RUNNER_SHOTS_DIR`), named `<screen>.png`. `SHOTS_ORIENTATION`
/// is `portrait` or `landscape`; the text size is the simulator's, which the script sets.
/// `SHOTS_DIRECTION` `rtl` launches the app under Xcode's Right-to-Left Pseudolanguage (#122), and
/// the walk's swipes and taps that depend on a side follow it.
@MainActor
final class ShotsUITests: XCTestCase {
    /// The harness's `SHOT_SCENARIO`s (`ShotsApp.Scenario`, which can't be imported here).
    enum ShotScenario: String {
        case app, onboarding, notificationsOff, alarmsOff, timeSensitiveOff, badgesOff, badgesNotSet, customLocking, noReminders, spareTag, rowLeaves
    }

    private var app: XCUIApplication!
    private let directory = URL(filePath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory())

    private let isRightToLeft = ProcessInfo.processInfo.environment["SHOTS_DIRECTION"] == "rtl"

    override func setUp() async throws {
        continueAfterFailure = true
        let landscape = ProcessInfo.processInfo.environment["SHOTS_ORIENTATION"] == "landscape"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
    }

    /// A new harness app, under the Right-to-Left Pseudolanguage when the variant asks for it. The
    /// arguments are the ones Xcode's scheme option passes (Xcode 27's IDEFoundation); Apple's docs
    /// name the option, not its arguments. A launch argument lasts only that launch.
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        if isRightToLeft {
            app.launchArguments += ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"]
        }
        return app
    }

    private func launch(_ scenario: ShotScenario, dark: Bool = false) {
        app = makeApp()
        app.launchEnvironment["SHOT_SCENARIO"] = scenario.rawValue
        app.launchEnvironment["SHOT_DARK"] = dark ? "1" : "0"
        app.launch()
        // The seed and the first plan.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        pause(1.5)
        assertDirection()
    }

    /// Now is the first tab, so it sits on the leading side: a run that lost `SHOTS_DIRECTION` fails
    /// here instead of shooting the wrong direction. Onboarding has no tab bar.
    private func assertDirection() {
        let now = app.tabBars.buttons["Now"].firstMatch
        guard now.exists else { return }
        let onRight = now.frame.midX > app.windows.firstMatch.frame.midX
        XCTAssertEqual(onRight, isRightToLeft, "The layout isn't \(isRightToLeft ? "right to left" : "left to right")")
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

    /// My Day's bar (#161): the Filter button is a glass circle of its own with New apart from it,
    /// and with no tags and no reminder today there is no Filter button.
    func testMyDayFilterButtonStandsApartAndHides() {
        launch(.app)
        tab("My Day")
        let filter = myDayFilterButtons.firstMatch
        let new = app.buttons["New Reminder"].firstMatch
        XCTAssert(filter.waitForExistence(timeout: 3), "No Filter button on a day with reminders and tags")
        // A button in the same glass group would sit a few points from New; apart, the bar's spacer
        // is between them.
        let gap = isRightToLeft ? filter.frame.minX - new.frame.maxX : new.frame.minX - filter.frame.maxX
        print("BAR gap between Filter and New: \(gap) pt")
        XCTAssertGreaterThan(gap, 12, "The Filter button shares New's glass group")
        shot("myday-bar-filter-apart")
        launch(.noReminders)
        tab("My Day")
        XCTAssertFalse(myDayFilterButtons.firstMatch.exists, "A Filter button with no tags and no reminder today")
        shot("myday-no-filter")
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
            app = makeApp()
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
        openSheet("New Tag", title: "New Tag")
        dismissKeyboardTip()
        shot("tag-new")
    }

    /// The mockup's `tags-sort-menu`, `tags-sort-z-a`, `tags-sort-most` and `tags-sort-fewest` (#140):
    /// the bar's Sort menu open at Name, A to Z, then each other choice, with the menu open again
    /// at the last to show it checked.
    func testTagsSort() {
        launch(.app)
        tab("Tags")
        assertTagHeaderAndTopRows("#appointments", "#health")
        let sort = app.buttons["Sort"].firstMatch
        sort.tap()
        shot("tags-sort-menu")
        app.buttons["Z to A"].firstMatch.tap()
        pause(0.5)
        assertTagHeaderAndTopRows("#work", "#travel")
        shot("tags-sort-z-a")
        sort.tap()
        pause(0.5)
        app.buttons["Most First"].firstMatch.tap()
        pause(0.5)
        assertTagHeaderAndTopRows("#home", "#health")
        shot("tags-sort-most")
        sort.tap()
        pause(0.5)
        app.buttons["Fewest First"].firstMatch.tap()
        pause(0.5)
        // A tie on the count: both have 1 reminder, by name, A to Z.
        assertTagHeaderAndTopRows("#appointments", "#travel")
        shot("tags-sort-fewest")
        sort.tap()
        shot("tags-sort-menu-fewest")
    }

    /// The mockup's `tags-search-*` and `tags-no-match-search` (#141): the field under the title, the
    /// bar during a search, a leading `#`, the no-match state and its Clear Search, the search kept
    /// going into a tag and back, and Cancel ending the search in one tap.
    func testTagsSearch() {
        launch(.app)
        tab("Tags")
        shot("tags-search-empty")
        let field = app.searchFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "No search field:\n\(app.debugDescription)")
        field.tap()
        field.typeText("#ho")
        pause(0.5)
        XCTAssert(app.buttons["Sort"].firstMatch.isHittable, "The bar's Sort button left during a search:\n\(app.debugDescription)")
        XCTAssert(app.buttons["New Tag"].firstMatch.isHittable, "The bar's New Tag button left during a search:\n\(app.debugDescription)")
        assertTagCount(startsWith: "1 tag out of ")
        shot("tags-search")
        field.typeText("zzz")
        pause(0.5)
        assertTagCount(startsWith: "0 tags out of ")
        XCTAssertFalse(app.staticTexts["No Tags"].exists, "No Tags showed while tags exist")
        shot("tags-no-match-search")
        let clearSearch = app.buttons["Clear Search"].firstMatch
        XCTAssert(clearSearch.exists, "No Clear Search:\n\(app.debugDescription)")
        clearSearch.tap()
        pause(0.8)
        shot("tags-search-cleared")
        assertListAtTop(below: field, after: "Clear Search")
        assertTagCount(startsWith: "7 tags out of 7")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Clear Search left the keyboard up")
        // Going into a tag and back keeps the search.
        field.tap()
        field.typeText("home")
        pause(0.5)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "#home")).firstMatch.tap()
        pause(0.8)
        back()
        XCTAssertEqual(field.value as? String, "home", "Back from a tag lost the search")
        assertTagCount(startsWith: "1 tag out of ")
        shot("tags-search-back")
        // Cancel ends the search in one tap and returns the list as it was.
        let cancel = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "cancel", "close")).firstMatch
        XCTAssert(cancel.exists, "No Cancel after Back from a tag:\n\(app.debugDescription)")
        cancel.tap()
        pause(1)
        shot("tags-search-closed")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "One tap on Cancel left the keyboard up")
        XCTAssertFalse(cancel.exists, "One tap on Cancel left the search open")
        assertTagCount(startsWith: "7 tags out of 7")
        assertListAtTop(below: field, after: "Cancel")
    }

    /// The mockup's `tags-filter-*` and `tags-no-match-*` (#142): the Filter button without and with
    /// its badge and its menu, the sheet, a clean draft closing and a changed one asking first, the
    /// no-match state under the filter alone and with a search, and Reset. Every tag of the walk's
    /// data has reminders, so the walk makes #spare for the filter to find.
    func testTagsFilter() {
        launch(.app)
        tab("Tags")
        shot("tags-filter-bar")
        openFilter(titled: "Filter Tags")
        shot("tags-filter")
        swipeSheetDown(titled: "Filter Tags")
        pause(1)
        XCTAssertFalse(app.navigationBars["Filter Tags"].exists, "A swipe down on a clean draft didn't close the sheet")

        openFilter(titled: "Filter Tags")
        chooseInSheet("Has no reminders")
        shot("tags-filter-changed")
        askToDiscard(titled: "Filter Tags")
        shot("tags-filter-discard")
        keepEditing(titled: "Filter Tags")
        swipeSheetDown(titled: "Filter Tags")
        pause(1)
        XCTAssert(app.navigationBars["Filter Tags"].exists, "A swipe down lost a changed draft")

        // Discard Changes drops the draft: the tags are all still listed.
        askToDiscard(titled: "Filter Tags")
        discardChanges(titled: "Filter Tags")
        assertTagCount(startsWith: "7 tags out of 7")
        openFilter(titled: "Filter Tags")
        chooseInSheet("Has no reminders")

        // Every tag has reminders: the filter alone leaves nothing.
        applyFilter(titled: "Filter Tags")
        assertTagCount(startsWith: "0 tags out of 7")
        XCTAssertFalse(app.staticTexts["No Tags"].exists, "No Tags showed while tags exist")
        XCTAssert(app.staticTexts["No tags with this filter."].exists, "The no-match state doesn't name the filter:\n\(app.debugDescription)")
        shot("tags-no-match-filter")
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        shot("tags-filter-menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.5)
        assertTagCount(startsWith: "7 tags out of 7")

        openSheet("New Tag", title: "New Tag")
        dismissKeyboardTip()
        app.typeText("spare")
        barTap { app.navigationBars["New Tag"].buttons["Done"].tap() }
        pause(0.8)
        openFilter(titled: "Filter Tags")
        chooseInSheet("Has no reminders")
        applyFilter(titled: "Filter Tags")
        assertTagCount(startsWith: "1 tag out of 8")
        shot("tags-filter-badge")

        // A search under the filter that finds nothing names both, and clears both.
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("zzz")
        pause(0.5)
        XCTAssert(app.staticTexts["No tags with this filter match this search."].exists, "The no-match state doesn't name the search and the filter:\n\(app.debugDescription)")
        shot("tags-no-match-both")
        // At the largest text the keyboard covers the button, as on Reminders (#141).
        hideKeyboard()
        guard let clear = scrollTo("Clear Search and Filter") else {
            XCTFail("No Clear Search and Filter:\n\(app.debugDescription)")
            return
        }
        clear.tap()
        pause(0.8)
        assertTagCount(startsWith: "8 tags out of 8")
        shot("tags-filter-cleared")

        // Reset clears the draft, and nothing changes until Apply.
        openFilter(titled: "Filter Tags")
        chooseInSheet("Has no reminders")
        scrollTo("Reset")?.tap()
        shot("tags-filter-reset")
        applyFilter(titled: "Filter Tags")
        assertTagCount(startsWith: "8 tags out of 8")
    }

    private func assertTagCount(startsWith text: String, line: UInt = #line) {
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
        XCTAssert(count.exists, "No count starting \(text):\n\(app.debugDescription)", line: line)
    }

    /// The mockup's `tags-swipe`, `tags-delete` and the no-tags empty state (#139): Edit and Delete
    /// on the trailing swipe, nothing on the leading one, the rename sheet, the Delete question
    /// cancelled and then confirmed, and Back returning to the list where it was.
    func testTagsSwipe() {
        launch(.app)
        tab("Tags")
        swipe("#home")
        assertRoundTile("Edit", on: "Tags")
        assertRoundTile("Delete", on: "Tags")
        shot("tags-swipe")
        app.buttons["Edit"].firstMatch.tap()
        XCTAssert(app.navigationBars["Rename Tag"].waitForExistence(timeout: 3), "No Rename Tag sheet")
        dismissKeyboardTip()
        shot("tags-rename")

        // A new launch rather than closing the sheet: it holds the keyboard, and the bar's taps need the turn.
        launch(.app)
        tab("Tags")
        guard let home = scrollTo("#home") else {
            XCTFail("No #home:\n\(app.debugDescription)")
            return
        }
        swipeLeading(home)
        pause(0.8)
        XCTAssertFalse(app.buttons["Edit"].exists, "A leading swipe showed Edit")
        XCTAssertFalse(app.buttons["Delete"].exists, "A leading swipe showed Delete")

        // A new launch: on the simulator a right swipe opens a list row, on every screen (#139's Comments).
        launch(.app)
        tab("Tags")
        swipe("#home")
        app.buttons["Delete"].firstMatch.tap()
        deleteQuestion(titled: "Delete #home?", saying: "use this tag")
        shot("tags-delete")
        closeDeleteQuestion(titled: "Delete #home?")
        XCTAssertNotNil(scrollTo("#home", scrolls: 0), "Closing the question changed the list")

        swipe("#home")
        app.buttons["Delete"].firstMatch.tap()
        confirmDelete("Delete Tag", titled: "Delete #home?")
        XCTAssertNil(scrollTo("#home", scrolls: 0), "#home is still in the list")
        shot("tags-after-delete")

        launch(.app)
        tab("Tags")
        scroll(down: true)
        pause(0.8)
        guard let row = scrollTo("#morning") else {
            XCTFail("No #morning:\n\(app.debugDescription)")
            return
        }
        let frameBeforeOpening = row.frame
        row.tap()
        pause(0.8)
        back()
        pause(0.8)
        // Not in landscape: `back()` turns the phone for its tap, and turning moves the list.
        if !XCUIDevice.shared.orientation.isLandscape {
            XCTAssertEqual(scrollTo("#morning", scrolls: 0)?.frame, frameBeforeOpening, "Back moved the list")
        }

        launch(.noReminders)
        tab("Tags")
        shot("tags-empty", pages: 2)
    }

    /// #277: a Tags row's Delete question is up, and the row leaves the list under it, as when Has no
    /// reminders is on and its tag gets a reminder. Nothing on screen can remove a tag while the
    /// question covers it, so the harness does it when this test posts a Darwin notification
    /// (`ShotsSeed.giveSpareAReminderNotification`). The question goes with its row, deletes nothing, and
    /// the list and its count are right.
    func testTagsRowLeavesWithItsDeleteQuestionUp() {
        launch(.spareTag)
        tab("Tags")
        openFilter(titled: "Filter Tags")
        chooseInSheet("Has no reminders")
        applyFilter(titled: "Filter Tags")
        assertTagCount(startsWith: "1 tag out of 8")
        swipe("#spare")
        app.buttons["Delete"].firstMatch.tap()
        let question = deleteQuestion(titled: "Delete #spare?", saying: "use this tag")
        shot("tags-delete-row-leaves-before")

        // #spare gets a reminder, so the filter no longer shows it. The name is the harness's
        // `ShotsSeed.giveSpareAReminderNotification`, which this target can't import.
        notify_post("com.newreality.nudgeinator.shots.giveSpareAReminder")
        XCTAssert(question.waitForNonExistence(timeout: 5), "The Delete question stayed after its row left:\n\(app.debugDescription)")
        pause(1)
        XCTAssertEqual(app.state, .runningForeground, "The app isn't running after its row left")
        XCTAssert(app.tabBars.firstMatch.exists, "No tab bar after the row left")
        assertTagCount(startsWith: "0 tags out of 8")
        XCTAssertNil(scrollTo("#spare", scrolls: 0), "#spare is still in the filtered list")
        XCTAssert(app.staticTexts["No tags with this filter."].exists, "No no-match state:\n\(app.debugDescription)")
        shot("tags-delete-row-leaves-after")

        // Nothing was deleted: #spare and the seven others are all there.
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.8)
        assertTagCount(startsWith: "8 tags out of 8")
        scrollToTop()
        // In the list's A to Z order: the lookup only scrolls down.
        for name in ["#appointments", "#health", "#home", "#money", "#morning", "#spare", "#travel", "#work"] {
            XCTAssertNotNil(scrollTo(name), "\(name) is missing from the list")
        }
        XCTAssertEqual(deleteQuestions.count, 0, "A Delete question came back")
    }

    /// #280: a Reminders row's Delete question is up, and the row leaves the list under it, as when the
    /// Nudging status is on and its reminder is marked Done. Nothing on screen can change a reminder
    /// while the question covers it, so the harness marks "Take the bins out" Done when this test posts a
    /// Darwin notification (`ShotsSeed.markTheBinsDoneNotification`). The question goes with its row,
    /// deletes nothing, and the list and its count are right.
    func testRemindersRowLeavesWithItsDeleteQuestionUp() {
        launch(.rowLeaves)
        tab("Reminders")
        openRemindersFilter()
        chooseInSheet("Nudging")
        applyRemindersFilter()
        // The count is read, not written in, so the test doesn't hold the seed's number of Nudging rows.
        let total = 14
        guard let before = shownReminderCount() else { return }
        XCTAssertEqual(before.total, total, "The walk's data isn't \(total) reminders")
        swipe("Take the bins out")
        app.buttons["Delete"].firstMatch.tap()
        let question = deleteQuestion(titled: "Delete “Take the bins out”?", saying: reminderDeleteMessage)
        shot("reminders-delete-row-leaves-before")

        // The bins are marked Done, so the Nudging status no longer shows them. The name is the
        // harness's `ShotsSeed.markTheBinsDoneNotification`, which this target can't import.
        notify_post("com.newreality.nudgeinator.shots.markTheBinsDone")
        XCTAssert(question.waitForNonExistence(timeout: 5), "The Delete question stayed after its row left:\n\(app.debugDescription)")
        pause(1)
        XCTAssertEqual(app.state, .runningForeground, "The app isn't running after its row left")
        XCTAssert(app.tabBars.firstMatch.exists, "No tab bar after the row left")
        let after = shownReminderCount()
        XCTAssertEqual(after?.shown, before.shown - 1, "The count didn't drop by the one row that left")
        XCTAssertEqual(after?.total, total, "A reminder was deleted")
        XCTAssertNil(scrollTo("Take the bins out", scrolls: 0), "The bins are still in the Nudging list")
        shot("reminders-delete-row-leaves-after")

        // Nothing was deleted: with the filter cleared all 14 are listed, the bins among them.
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.8)
        let cleared = shownReminderCount()
        XCTAssertEqual(cleared?.shown, total, "Not every reminder is listed")
        XCTAssertEqual(cleared?.total, total, "A reminder was deleted")
        scrollToTop()
        XCTAssertNotNil(scrollTo("Take the bins out"), "The bins were deleted")
        XCTAssertEqual(deleteQuestions.count, 0, "A Delete question came back")
    }

    /// The header row's count, "3 reminders out of 14": the reminders shown and every reminder.
    /// Scrolls to the top, where the header is. Fails the test and returns nil when there is none.
    private func shownReminderCount(line: UInt = #line) -> (shown: Int, total: Int)? {
        scrollToTop()
        let count = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"\d+ reminders? out of \d+"#)).firstMatch
        guard count.waitForExistence(timeout: 3) else {
            XCTFail("No reminder count:\n\(app.debugDescription)", line: line)
            return nil
        }
        let numbers = count.label.split(separator: " ").compactMap { Int($0) }
        guard numbers.count == 2 else {
            XCTFail("Can't read the count \(count.label)", line: line)
            return nil
        }
        return (numbers[0], numbers[1])
    }

    /// The mockup's `reminders` and `reminders-empty`: every reminder in creation-date order, a
    /// row in each status, then a row's details pushed on the tab (#109).
    func testReminders() {
        launch(.app)
        tab("Reminders")
        shot("reminders", pages: 20, stopsAtEnd: true)
        // A new launch rather than scrolling back: at the largest text four drags don't reach the top.
        launch(.app)
        tab("Reminders")
        tapText("Pay rent")
        shot("reminders-details")
        launch(.noReminders)
        tab("Reminders")
        shot("reminders-empty")
    }

    /// `details-delete` (#276, #286): the details page's Delete Reminder asks with the system's
    /// confirmation dialog, its title showing. Closing it (a tap outside the popover, or Cancel on
    /// an action sheet) keeps the reminder on its page; Delete Reminder deletes it and leaves the page.
    func testDetailsDelete() {
        launch(.app)
        tab("Reminders")
        tapText("Pay rent")
        tapText("Delete Reminder")
        deleteQuestion(titled: "Delete “Pay rent”?", saying: reminderDeleteMessage)
        shot("details-delete")
        closeDeleteQuestion(titled: "Delete “Pay rent”?")
        XCTAssertNotNil(scrollTo("Delete Reminder", scrolls: 0), "Closing the question left the details page")
        tapText("Delete Reminder")
        confirmDelete("Delete Reminder", titled: "Delete “Pay rent”?")
        XCTAssertNil(scrollTo("Pay rent", scrolls: 0), "Pay rent is still in the list")
        shot("details-after-delete")
    }

    /// The Delete Reminder question's message, the same wherever it's asked. A copy of the app's
    /// string, which this target can't import: change both together.
    private let reminderDeleteMessage = "This deletes its history too, and cancels any nudges and alarms."

    /// The delete question titled `title` (#286), the system's confirmation dialog. XCUITest lists
    /// it among `sheets`, as a popover and as an action sheet alike.
    private func deleteQuestionElement(titled title: String, line: UInt = #line) -> XCUIElement {
        let question = app.sheets[title]
        XCTAssert(question.waitForExistence(timeout: 3), "No question \(title):\n\(app.debugDescription)", line: line)
        return question
    }

    /// Any delete question at all: none of the delete questions' titles starts "Delete".
    private var deleteQuestions: XCUIElementQuery {
        app.sheets.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete "))
    }

    /// Waits for the delete question titled `title` and checks its message contains `message`. The
    /// form iOS chose is recorded in the test's activity log ("Delete question …: popover"), since a
    /// swipe tile or VoiceOver action has no button for a popover to point at.
    @discardableResult
    private func deleteQuestion(titled title: String, saying message: String, line: UInt = #line) -> XCUIElement {
        let question = deleteQuestionElement(titled: title, line: line)
        let shown = question.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", message)).firstMatch
        XCTAssert(shown.exists, "The question \(title) doesn't say \(message):\n\(app.debugDescription)", line: line)
        let form = app.popovers.firstMatch.exists ? "popover" : "action sheet"
        XCTContext.runActivity(named: "Delete question \(title): \(form)") { _ in }
        return question
    }

    /// Closes the delete question titled `title` without deleting: a tap outside the popover, or the
    /// action sheet's Cancel. A popover that is up must have its own dismiss region, so a missing
    /// one fails here instead of falling through to Cancel. Checks it closed.
    private func closeDeleteQuestion(titled title: String, line: UInt = #line) {
        let question = deleteQuestionElement(titled: title, line: line)
        if app.popovers.firstMatch.exists {
            XCTAssert(tapOutsidePopover(waiting: 1), "The popover has no dismiss region:\n\(app.debugDescription)", line: line)
        } else {
            let cancel = question.buttons["Cancel"]
            XCTAssert(cancel.exists, "No way out of \(title):\n\(app.debugDescription)", line: line)
            cancel.tap()
        }
        XCTAssert(question.waitForNonExistence(timeout: 3), "The question \(title) stayed up", line: line)
        pause(0.8)
    }

    /// Chooses the delete question's destructive `button` and checks the question closed.
    private func confirmDelete(_ button: String, titled title: String, line: UInt = #line) {
        let question = deleteQuestionElement(titled: title, line: line)
        question.buttons[button].tap()
        XCTAssert(question.waitForNonExistence(timeout: 3), "The question \(title) stayed up", line: line)
        pause(1)
    }

    /// Adds a reminder through the New Reminder form.
    private func addReminder(titled title: String) {
        openSheet("New Reminder", title: "New Reminder")
        dismissKeyboardTip()
        let field = app.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 3), "No title field")
        field.tap()
        field.typeText(title)
        hideKeyboard()
        let add = app.buttons["Add"].firstMatch
        XCTAssert(add.waitForExistence(timeout: 3), "No Add button")
        add.tap()
        pause(1)
    }

    /// `reminders-after-last-delete` (#249): with a search typed, the last reminder is deleted and
    /// the empty state shows. A reminder added afterwards shows, though it doesn't match the old
    /// search.
    func testRemindersAfterTheLastDelete() {
        launch(.noReminders)
        addReminder(titled: "Zebra")
        tab("Reminders")
        let field = app.searchFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 3), "No search field")
        field.tap()
        field.typeText("Zebra")
        hideKeyboard()
        swipe("Zebra")
        app.buttons["Delete"].firstMatch.tap()
        confirmDelete("Delete Reminder", titled: "Delete “Zebra”?")
        XCTAssert(app.staticTexts["No Reminders"].waitForExistence(timeout: 3), "No empty state after the last delete")
        shot("reminders-after-last-delete")
        addReminder(titled: "Apple")
        tab("Reminders")
        XCTAssertNotNil(scrollTo("Apple", scrolls: 2), "The old search hid the new reminder")
        shot("reminders-after-last-delete-added")
    }

    /// Opens a row's trailing swipe, scrolling to the row first. On Now and My Day, which have no
    /// Delete to look for, it swipes all three times; a swipe on an open row leaves it open.
    private func swipe(_ title: String) {
        scrollToTop()
        guard let row = scrollTo(title) else {
            XCTFail("No \(title):\n\(app.debugDescription)")
            return
        }
        // At the largest text four scrolls up can leave the first row under the bar.
        var tries = 0
        while row.frame.minY < app.navigationBars.firstMatch.frame.maxY, tries < 8 {
            scroll(down: false)
            tries += 1
        }
        // A swipe that starts behind the tab bar moves the tab bar's selection instead.
        let tabBar = app.tabBars.firstMatch
        tries = 0
        while tabBar.exists, row.frame.midY > tabBar.frame.minY, tries < 4 {
            scroll(down: true)
            tries += 1
        }
        // In landscape a row can sit under the search field, which takes the swipe. A short drag,
        // since a whole scroll there could take the row off the screen.
        let search = app.searchFields.firstMatch
        if search.exists, row.frame.minY < search.frame.maxY {
            let from = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let distance = search.frame.maxY - row.frame.minY + 8
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .slow, thenHoldForDuration: 0.2)
            pause(0.5)
        }
        // With another row's actions still open, the first swipe only closes them.
        func opened() -> Bool {
            let delete = app.buttons["Delete"].firstMatch
            return delete.exists && row.frame.minY...row.frame.maxY ~= delete.frame.midY
        }
        for _ in 0..<3 where !opened() {
            swipeTrailing(row)
            pause(0.8)
        }
    }

    /// A swipe from the row's trailing edge toward its leading edge, which opens its trailing actions.
    private func swipeTrailing(_ row: XCUIElement) {
        isRightToLeft ? row.swipeRight() : row.swipeLeft()
    }

    /// A swipe toward the row's trailing edge, which would open leading actions.
    private func swipeLeading(_ row: XCUIElement) {
        isRightToLeft ? row.swipeLeft() : row.swipeRight()
    }

    /// The mockup's `reminders-sort-menu`, `reminders-newest` and `reminders-due-date` (#115): the
    /// bar's Sort menu open at Created, Oldest First, then Newest First chosen, then Due
    /// Date, Latest First chosen, with the menu open again to show it checked.
    func testRemindersSort() {
        launch(.app)
        tab("Reminders")
        let sort = app.buttons["Sort"].firstMatch
        sort.tap()
        shot("reminders-sort-menu")
        app.buttons["Newest First"].firstMatch.tap()
        shot("reminders-newest")
        sort.tap()
        pause(0.5)
        app.buttons["Latest First"].firstMatch.tap()
        pause(0.5)
        shot("reminders-due-date", pages: 2)
        scrollToTop()
        sort.tap()
        shot("reminders-sort-menu-due-date")
    }

    /// The mockup's `reminders-swipe-nudging`, `reminders-swipe-other`, `reminders-delete` and
    /// `reminders-after-done` (#110): the trailing swipe on a Nudging and a Coming up row, the
    /// Delete question (cancelled), then Done from the swipe, which leaves the row in place.
    func testRemindersSwipe() {
        launch(.app)
        tab("Reminders")
        swipe("Take the bins out")
        shot("reminders-swipe-nudging")
        swipe("Water the plants")
        shot("reminders-swipe-other")
        // A new launch rather than scrolling back: at the largest text four drags don't reach the top.
        launch(.app)
        tab("Reminders")
        swipe("Pay rent")
        app.buttons["Delete"].firstMatch.tap()
        deleteQuestion(titled: "Delete “Pay rent”?", saying: reminderDeleteMessage)
        shot("reminders-delete")
        closeDeleteQuestion(titled: "Delete “Pay rent”?")
        XCTAssertNotNil(scrollTo("Pay rent", scrolls: 0), "Closing the question deleted the reminder")
        swipe("Take the bins out")
        app.buttons["Done"].firstMatch.tap()
        shot("reminders-after-done")
    }

    /// The swipe tile is one 50 pt circle on every screen, on a tall row and a short one, with
    /// Done alone and beside Delete (#126). The system sets its shape, so no unit test can see it.
    func testSwipeTileShape() {
        launch(.app)
        swipe("Take the bins out")
        assertRoundTile("Done", on: "Now")
        tab("My Day")
        swipe("Take the bins out")
        assertRoundTile("Done", on: "My Day")
        tab("Reminders")
        swipe("Take the bins out")
        assertRoundTile("Done", on: "Reminders, tags")
        assertRoundTile("Delete", on: "Reminders, tags")
        shot("reminders-tile-tags")
        // Two lines of title, so a tall row.
        swipe("Reply to Alex about the lease")
        assertRoundTile("Done", on: "Reminders, tall row")
        assertRoundTile("Delete", on: "Reminders, tall row")
        // A new launch rather than scrolling back: at the largest text four drags don't reach the top.
        launch(.app)
        tab("Reminders")
        swipe("Send the weekly status update")
        assertRoundTile("Delete", on: "Reminders, two-line title")
        // No tags: the list's shortest row.
        launch(.app)
        tab("Reminders")
        swipe("Call Grandma")
        assertRoundTile("Delete", on: "Reminders, no tags")
        shot("reminders-tile-no-tags")
    }

    /// The header row reads every tag, on the screen and above the rows, and `first` is above `second`.
    private func assertTagHeaderAndTopRows(_ first: String, _ second: String, line: UInt = #line) {
        let count = app.staticTexts["7 tags out of 7"].firstMatch
        XCTAssert(count.waitForExistence(timeout: 3), "No header row:\n\(app.debugDescription)", line: line)
        func row(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "\(label), ")).firstMatch
        }
        let (top, next) = (row(first), row(second))
        XCTAssert(top.exists && next.exists, "No \(first) or \(second):\n\(app.debugDescription)", line: line)
        XCTAssertLessThanOrEqual(count.frame.maxX, app.windows.firstMatch.frame.maxX, "The header row runs off the right edge", line: line)
        XCTAssertGreaterThanOrEqual(count.frame.minX, app.windows.firstMatch.frame.minX, "The header row runs off the left edge", line: line)
        XCTAssertLessThanOrEqual(count.frame.maxY, top.frame.minY, "The header row overlaps \(first)", line: line)
        XCTAssertLessThan(top.frame.minY, next.frame.minY, "\(first) isn't above \(second)", line: line)
    }

    /// Checks the open tile named `label` is a 50 pt circle. It is the button with that name nearest
    /// the trailing edge, since Now and My Day have a Done button too. `place` names the row for the failure.
    private func assertRoundTile(_ label: String, on place: String, line: UInt = #line) {
        let tiles = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
        // Larger is nearer the trailing edge.
        let towardTrailing = { (tile: XCUIElement) in self.isRightToLeft ? -tile.frame.minX : tile.frame.maxX }
        guard let tile = tiles.filter({ $0.isHittable }).max(by: { towardTrailing($0) < towardTrailing($1) }) else {
            XCTFail("No \(label) tile on \(place)", line: line)
            return
        }
        XCTAssertEqual(tile.frame.width, 50, accuracy: 0.5, "\(label) on \(place): \(tile.frame)", line: line)
        XCTAssertEqual(tile.frame.height, 50, accuracy: 0.5, "\(label) on \(place): \(tile.frame)", line: line)
    }

    /// The Filter button of Reminders and Tags, and with a filter on its menu, which also has an
    /// item named Filter: the button is the topmost.
    private var filterButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "Filter"))
    }

    /// Opens the Reminders filter sheet: with filters on, through the menu's Filter.
    private func openRemindersFilter() {
        openFilter(titled: "Filter Reminders")
    }

    /// Opens the tab's filter sheet: with a filter on, through the menu's Filter.
    private func openFilter(titled title: String) {
        barTap {
            filterButtons.firstMatch.tap()
            if app.buttons["Clear All Filters"].waitForExistence(timeout: 2) {
                filterButtons.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY }?.tap()
            }
            XCTAssert(app.navigationBars[title].waitForExistence(timeout: 3), "No \(title) sheet")
        }
    }

    private func applyRemindersFilter() {
        applyFilter(titled: "Filter Reminders")
    }

    private func applyFilter(titled title: String) {
        barTap { app.navigationBars[title].buttons["Apply"].tap() }
        pause(0.5)
    }

    private func swipeRemindersFilterDown() {
        swipeSheetDown(titled: "Filter Reminders")
    }

    /// A drag from the sheet's bar down most of the screen: `swipeDown()` on the bar is too short to
    /// close it.
    private func swipeSheetDown(titled title: String) {
        let bar = app.navigationBars[title]
        let from = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 600)), withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// Closes the discard question without discarding (#278), and checks it closed and left the sheet
    /// open. From the ✕ iOS draws it as a popover with Discard Changes alone, closed by a tap outside
    /// it: the popover's own dismiss region, which is there even when the popover fills the screen at
    /// the largest text. Where iOS draws an action sheet instead, its Cancel is the way out.
    private func keepEditing(titled title: String, line: UInt = #line) {
        if !tapOutsidePopover(waiting: 1) {
            let cancel = app.sheets.buttons["Cancel"].firstMatch
            XCTAssert(cancel.exists, "No way out of the discard question:\n\(app.debugDescription)", line: line)
            cancel.tap()
        }
        XCTAssert(app.buttons["Discard Changes"].waitForNonExistence(timeout: 3), "The discard question stayed up", line: line)
        XCTAssert(app.navigationBars[title].exists, "Leaving the discard question closed the sheet", line: line)
    }

    /// Taps an open popover's own dismiss region, a tap outside it, if one shows within `waiting`
    /// seconds; returns whether it did.
    private func tapOutsidePopover(waiting: TimeInterval = 0) -> Bool {
        let outside = app.otherElements["PopoverDismissRegion"].firstMatch
        guard waiting > 0 ? outside.waitForExistence(timeout: waiting) : outside.exists else { return false }
        outside.tap()
        return true
    }

    /// Taps Discard Changes in the discard question (#278) and checks the sheet closed.
    private func discardChanges(titled title: String, line: UInt = #line) {
        app.buttons["Discard Changes"].firstMatch.tap()
        XCTAssert(app.navigationBars[title].waitForNonExistence(timeout: 3), "Discard Changes left the sheet open", line: line)
    }

    /// Taps the Cancel of a sheet with changes and checks it asked first, with its title showing.
    private func askToDiscard(titled title: String, line: UInt = #line) {
        tapCancel(titled: title)
        XCTAssert(app.buttons["Discard Changes"].waitForExistence(timeout: 3), "Cancel didn't ask first:\n\(app.debugDescription)", line: line)
        XCTAssert(app.staticTexts["Are you sure you want to discard these changes?"].exists, "The discard question's title isn't showing", line: line)
    }

    /// Taps the Cancel of a sheet with no changes, and checks it closed without asking.
    private func closeUnchangedSheet(titled title: String, line: UInt = #line) {
        tapCancel(titled: title)
        pause(0.8)
        XCTAssertFalse(app.buttons["Discard Changes"].exists, "Cancel asked with no changes", line: line)
        XCTAssertFalse(app.navigationBars[title].exists, "Cancel didn't close the unchanged sheet", line: line)
    }

    /// A sheet's Cancel, the `xmark`, first in its bar.
    private func tapCancel(titled title: String) {
        barTap { app.navigationBars[title].buttons.element(boundBy: 0).tap() }
    }

    /// A date picker's calendar is a popover: a tap outside closes it. At the largest text it can
    /// fill the screen, so the tap goes to the popover's own dismiss region. Without one (portrait
    /// and landscape), the tap goes to the middle of the sheet's bar, between Cancel and Apply,
    /// which the calendar never covers: a tap low in the window landed on Reset in landscape and
    /// cleared the draft, and in portrait the calendar covers the Due Date header.
    private func closeDatePicker(titled title: String) {
        if !tapOutsidePopover() {
            app.navigationBars[title].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        pause(0.8)
    }

    /// Chooses a row of the open sheet, which scrolls to it.
    private func chooseInSheet(_ label: String) {
        tapText(label, inSheet: true)
    }

    /// A tap at a switch's center doesn't flip it (#114), so this one goes near its end. Nor does that
    /// tap flip it in landscape (iOS 27.0 simulator), so the phone is turned to portrait for it and back,
    /// which moves the list, so this scrolls to the row again.
    private func flipSwitch(_ label: String) {
        barTap {
            XCTAssertNotNil(scrollTo(label), "No \(label):\n\(app.debugDescription)")
            // By type: the row's title shares the label, and comes first on iOS 26.5.
            let row = app.switches[label].firstMatch
            let before = row.value as? String
            row.coordinate(withNormalizedOffset: CGVector(dx: isRightToLeft ? 0.15 : 0.85, dy: 0.5)).tap()
            pause(0.8)
            XCTAssertNotEqual(row.value as? String, before, "\(label) didn't flip")
        }
        XCTAssertNotNil(scrollTo(label), "No \(label):\n\(app.debugDescription)")
    }

    /// Opens a Due Date picker's calendar. By type, since its switch and title share its label (#114).
    private func openDatePicker(_ label: String) {
        guard let picker = app.datePickers.matching(identifier: label).allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No \(label) picker:\n\(app.debugDescription)")
            return
        }
        picker.tap()
        pause(0.8)
    }

    /// The filter sheet's Due Date section (#114): with no end, one end and both, a picker's calendar
    /// bounded by the other end, then Apply's badge and Clear All Filters taking it off.
    func testRemindersDueDate() {
        launch(.app)
        tab("Reminders")
        openRemindersFilter()
        XCTAssertNotNil(scrollTo("To"), "No Due Date section:\n\(app.debugDescription)")
        shot("reminders-due-date-none")

        flipSwitch("From")
        shot("reminders-due-date-one-end")
        flipSwitch("To")
        shot("reminders-due-date-both")
        openDatePicker("From")
        shot("reminders-due-date-picker")
        closeDatePicker(titled: "Filter Reminders")

        applyRemindersFilter()
        shot("reminders-due-date-badge")
        // Not `barTap`: turning the phone back closes the menu, and landscape only runs on iOS 27,
        // where bar buttons take taps.
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.5)
        shot("reminders-due-date-cleared")
    }

    /// The mockup's `reminders-filter`, `reminders-filter-badge`, `reminders-filter-menu`,
    /// `reminders-status-nudging` and `reminders-no-match-filters` (#113): the sheet, a swipe down
    /// closing a clean draft and holding a changed one, the prompt from Cancel, Apply, the badge and
    /// menu, Reset, every Nudging row marked Done under the Status, and Clear Filters.
    func testRemindersFilter() {
        launch(.app)
        tab("Reminders")
        shot("reminders-bar")
        openRemindersFilter()
        shot("reminders-filter", pages: 3, stopsAtEnd: true)

        // A clean draft just closes, and a swipe that closes it leaves the button working.
        swipeRemindersFilterDown()
        pause(1)
        XCTAssertFalse(app.navigationBars["Filter Reminders"].exists, "A swipe down on a clean draft didn't close the sheet")
        openRemindersFilter()

        chooseInSheet("Nudging")
        chooseInSheet("Firm")
        shot("reminders-filter-chosen")
        askToDiscard(titled: "Filter Reminders")
        shot("reminders-filter-discard")
        keepEditing(titled: "Filter Reminders")

        // A changed draft holds the sheet: the swipe springs back, as the reminder form's does.
        swipeRemindersFilterDown()
        pause(1)
        XCTAssert(app.navigationBars["Filter Reminders"].exists, "A swipe down lost a changed draft")

        // Discard Changes drops the draft: the sheet opens again unchanged, so Cancel closes it
        // without asking.
        askToDiscard(titled: "Filter Reminders")
        discardChanges(titled: "Filter Reminders")
        openRemindersFilter()
        closeUnchangedSheet(titled: "Filter Reminders")
        openRemindersFilter()
        chooseInSheet("Nudging")
        applyRemindersFilter()
        shot("reminders-status-nudging")
        // Not `barTap`: turning the phone back closes the menu, and landscape only runs on iOS 27,
        // where bar buttons take taps.
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        shot("reminders-filter-menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.5)
        shot("reminders-filter-cleared")

        // Reset clears the draft. Applying the empty draft changes nothing.
        openRemindersFilter()
        chooseInSheet("Firm")
        scrollTo("Reset")?.tap()
        shot("reminders-filter-reset")
        applyRemindersFilter()

        // A chosen tag is bold on its rows.
        openRemindersFilter()
        chooseInSheet("#home")
        applyRemindersFilter()
        shot("reminders-filter-tag")
        // Not `barTap`: turning the phone back closes the menu, and landscape only runs on iOS 27,
        // where bar buttons take taps.
        filterButtons.firstMatch.tap()
        XCTAssert(app.buttons["Clear All Filters"].waitForExistence(timeout: 3), "No Filter menu")
        app.buttons["Clear All Filters"].firstMatch.tap()
        pause(0.5)

        openRemindersFilter()
        chooseInSheet("Nudging")
        applyRemindersFilter()
        // Which rows are Nudging depends on the time of day the walk runs.
        let nudging = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Nudging,"))
        var marked = 0
        while let label = nudging.allElementsBoundByIndex.first?.label, marked < 6 {
            swipe(label.components(separatedBy: ", Nudging,")[0])
            app.buttons["Done"].firstMatch.tap()
            pause(0.8)
            marked += 1
        }
        shot("reminders-no-match-filters")
        // At the largest text, under the search field, the button starts below the screen.
        guard let clear = scrollTo("Clear Filters") else {
            XCTFail("No Clear Filters:\n\(app.debugDescription)")
            return
        }
        clear.tap()
        pause(0.8)
        shot("reminders-filters-cleared")
        assertListAtTop(below: app.searchFields.firstMatch, after: "Clear Filters")
    }

    /// The mockup's `reminders-search` (#112): the field empty under the title, with text, then a
    /// search that finds nothing, alone and under a filter, each cleared from the empty state's
    /// button. The bar stays during a search, so Filter and Sort can still be reached (#113).
    func testRemindersSearch() {
        launch(.app)
        tab("Reminders")
        shot("reminders-search-empty")
        let field = app.searchFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "No search field:\n\(app.debugDescription)")
        field.tap()
        field.typeText("pill")
        pause(0.5)
        XCTAssert(filterButtons.firstMatch.isHittable, "The bar's Filter button left during a search:\n\(app.debugDescription)")
        XCTAssert(app.buttons["Sort"].firstMatch.isHittable, "The bar's Sort button left during a search:\n\(app.debugDescription)")
        shot("reminders-search-text")
        field.typeText("zzz")
        pause(0.5)
        shot("reminders-no-match-search")
        let clearSearch = app.buttons["Clear Search"].firstMatch
        XCTAssert(clearSearch.exists, "No Clear Search:\n\(app.debugDescription)")
        clearSearch.tap()
        pause(0.8)
        shot("reminders-search-cleared")
        assertListAtTop(below: field, after: "Clear Search")
        openRemindersFilter()
        chooseInSheet("Nudging")
        applyRemindersFilter()
        field.tap()
        field.typeText("zzz")
        pause(0.5)
        shot("reminders-no-match-search-status")
        let clearBoth = app.buttons["Clear Search and Filters"].firstMatch
        XCTAssert(clearBoth.exists, "No Clear Search and Filters:\n\(app.debugDescription)")
        clearBoth.tap()
        pause(0.8)
        shot("reminders-search-status-cleared")
        assertListAtTop(below: field, after: "Clear Search and Filters")
        // Cancel ends the search in one tap on both iOS versions: the Search button's X took three
        // on iOS 27.0, which is why that design went (#113).
        field.tap()
        field.typeText("pill")
        pause(0.5)
        let cancel = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "cancel", "close")).firstMatch
        XCTAssert(cancel.exists, "No Cancel:\n\(app.debugDescription)")
        cancel.tap()
        pause(1)
        shot("reminders-search-closed")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "One tap on Cancel left the keyboard up")
        XCTAssertFalse(cancel.exists, "One tap on Cancel left the search open")
        XCTAssert(filterButtons.firstMatch.isHittable, "Cancel left the bar without its Filter button:\n\(app.debugDescription)")
    }

    /// Clearing returns the list to its top, so the count is on screen and not behind the field. It
    /// compares positions because a tap on the count would still land behind the field (#112).
    private func assertListAtTop(below field: XCUIElement, after button: String, line: UInt = #line) {
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "out of")).firstMatch
        XCTAssert(count.exists, "No count after \(button):\n\(app.debugDescription)", line: line)
        XCTAssertGreaterThanOrEqual(count.frame.minY, field.frame.maxY, "After \(button), the count is behind the search field", line: line)
        // The bar ends 10 to 15 pt below the field, so this catches a list that stopped short with
        // the count just clear of the field, as it did at the largest text (#135).
        let bar = app.navigationBars.firstMatch
        XCTAssertGreaterThanOrEqual(count.frame.minY, bar.frame.maxY, "After \(button), the list stopped short of its top", line: line)
    }

    func testSettings() {
        launch(.app)
        tab("Settings")
        shot("settings", pages: 3)
        tapText("About")
        shot("settings-about", pages: 2)
        back()
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

    /// The form's Cancel (#278): with no changes it closes without asking; with a title typed it
    /// asks, a tap outside the question keeps the title, and Discard Changes closes the form and adds nothing.
    func testFormDiscard() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        dismissKeyboardTip()
        hideKeyboard()
        closeUnchangedSheet(titled: "New Reminder")

        openSheet("New Reminder", title: "New Reminder")
        let field = app.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 3), "No title field")
        field.tap()
        field.typeText("Water the ferns")
        hideKeyboard()
        askToDiscard(titled: "New Reminder")
        shot("form-discard")
        keepEditing(titled: "New Reminder")
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Water the ferns", "Leaving the discard question lost the title")

        askToDiscard(titled: "New Reminder")
        discardChanges(titled: "New Reminder")
        tab("Reminders")
        XCTAssertNil(scrollTo("Water the ferns", scrolls: 0), "Discard Changes added the reminder")
    }

    /// Its own test: going back from the Tags page closed the sheet on the iOS 27.0 simulator.
    func testFormTags() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        tapText("Tags", inSheet: true)
        shot("form-tags")
    }

    /// The Repeat menu, then its Custom row and sheet (#283, #284): choosing a preset or Custom is
    /// the form's repeat at once, and the Custom row opens the Custom sheet, whose changes are the
    /// form's as they're made, whether Apply or a swipe down closes it.
    func testFormPages() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        openRepeatMenu(showing: "Never")
        shot("form-repeat-menu")
        tapMenuItem("Every Week")
        shot("form-repeat-preset")
        openRepeatMenu(showing: "Every Week")
        tapMenuItem("Custom")
        shot("form-repeat-custom", pages: 2)
        openCustomRow()
        reportFormPageAccessibility("custom-sheet")
        let bar = app.navigationBars["Custom"]
        XCTAssertEqual(bar.buttons.count, 1, "The Custom sheet has more than Apply:\n\(bar.debugDescription)")
        XCTAssert(bar.buttons["Apply"].exists, "The Custom sheet has no Apply")
        // Before the shots, which scroll the stepper away: scrolling back up at the top of the
        // sheet would close it.
        stepEvery()
        shot("form-custom", pages: 3)
        // Apply closes the sheet, and the change is on the form's Custom row.
        barTap { bar.buttons["Apply"].tap() }
        XCTAssert(app.navigationBars["New Reminder"].waitForExistence(timeout: 3), "Apply didn't close the Custom sheet")
        XCTAssert(customRow(containing: "Every 2 weeks").waitForExistence(timeout: 3), "Apply lost the change:\n\(app.debugDescription)")
        shot("form-custom-chosen")
        reportFormPageAccessibility("repeat-chosen")
        // A swipe down closes it too, and keeps the change, with no question.
        openCustomRow()
        stepEvery()
        swipeSheetDown(titled: "Custom")
        XCTAssert(bar.waitForNonExistence(timeout: 3), "A swipe down didn't close the Custom sheet")
        XCTAssertFalse(app.buttons["Discard Changes"].exists, "The Custom sheet asked a question")
        XCTAssert(customRow(containing: "Every 3 weeks").waitForExistence(timeout: 3), "A swipe down lost the change:\n\(app.debugDescription)")
        shot("form-custom-swiped")
        // The form's Cancel still asks.
        askToDiscard(titled: "New Reminder")
        keepEditing(titled: "New Reminder")
        openRepeatMenu(showing: "Custom")
        tapMenuItem("Every Day")
        XCTAssertFalse(app.buttons["Custom"].firstMatch.exists, "A preset left the Custom row")
    }

    /// End Repeat under Repeat (#287): its menu, then After with its stepper and On Date with its
    /// End Date row, for a preset and under the Custom row.
    func testEndRepeat() {
        launch(.app)
        openSheet("New Reminder", title: "New Reminder")
        hideKeyboard()
        XCTAssertFalse(app.staticTexts["End Repeat"].exists, "End Repeat shows with Never")
        openRepeatMenu(showing: "Never")
        tapMenuItem("Every Week")
        openEndRepeatMenu(showing: "Never")
        shot("form-end-menu")
        tapMenuItem("After")
        shot("form-end-after", pages: 2)
        reportFormPageAccessibility("end-after")
        openEndRepeatMenu(showing: "After")
        tapMenuItem("On Date")
        shot("form-end-date", pages: 2)
        reportFormPageAccessibility("end-date")
        openRepeatMenu(showing: "Every Week")
        tapMenuItem("Custom")
        shot("form-end-custom", pages: 2)
        openCustomRow()
        shot("form-end-custom-page", pages: 3)
    }

    /// Taps End Repeat's menu button, which shows `current`, and waits for the menu.
    private func openEndRepeatMenu(showing current: String, line: UInt = #line) {
        let label = app.staticTexts["End Repeat"].firstMatch
        reveal(label)
        XCTAssert(label.waitForExistence(timeout: 3), "No End Repeat row:\n\(app.debugDescription)", line: line)
        let menu = app.buttons.matching(NSPredicate(format: "label == %@", current)).allElementsBoundByIndex
            .first { abs($0.frame.midY - label.frame.midY) < 30 } ?? app.buttons[current].firstMatch
        menu.tap()
        XCTAssert(app.buttons["On Date"].firstMatch.waitForExistence(timeout: 3), "The End Repeat menu didn't open", line: line)
        pause(0.8)
    }

    /// Scrolls the form until `element` is on screen and clear of the bar, down first, then up from
    /// where that left it. Not past the top: swiping down there closes the sheet.
    private func reveal(_ element: XCUIElement) {
        let window = app.windows.firstMatch.frame
        // The bar is shorter in landscape.
        let top: CGFloat = window.width > window.height ? 90 : 150
        func clear() -> Bool { element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= window.height - 40 }
        for _ in 0..<8 where !clear() { scroll(down: true) }
        for _ in 0..<10 where !clear() { scroll(down: false) }
    }

    /// Taps the Repeat row's menu button, which shows `current`, the repeat's choice, and waits for
    /// the menu.
    private func openRepeatMenu(showing current: String, line: UInt = #line) {
        let menu = app.buttons[current].firstMatch
        reveal(menu)
        XCTAssert(menu.waitForExistence(timeout: 3), "No Repeat menu showing \(current):\n\(app.debugDescription)", line: line)
        menu.tap()
        XCTAssert(app.buttons["Every Day"].firstMatch.waitForExistence(timeout: 3), "The Repeat menu didn't open", line: line)
        pause(0.8)
    }

    /// Taps an item of the open Repeat menu, scrolling the menu first: at the largest text it doesn't fit.
    private func tapMenuItem(_ title: String, line: UInt = #line) {
        let item = app.buttons[title].firstMatch
        for _ in 0..<8 where !item.isHittable { app.swipeUp() }
        XCTAssert(item.isHittable, "No \(title) in the Repeat menu:\n\(app.debugDescription)", line: line)
        item.tap()
        pause(0.8)
    }

    /// Taps the Custom row below Repeat, which writes the repeat out ("Every Saturday at 4:00 PM").
    private func openCustomRow() {
        let row = customRow(containing: " at ")
        // At the largest text the row is taller than `reveal` can fit clear of the screen's edges,
        // so scrolling for it lost it. A row already hittable is tapped where it is.
        if !(row.exists && row.isHittable) { reveal(row) }
        XCTAssert(row.waitForExistence(timeout: 3), "No Custom row:\n\(app.debugDescription)")
        row.tap()
        XCTAssert(app.navigationBars["Custom"].waitForExistence(timeout: 3), "The Custom row didn't open the Custom sheet")
        pause(0.8)
    }

    /// The Custom row, which starts "Every", by a part of the repeat it writes out.
    private func customRow(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Every", text)).firstMatch
    }

    /// Steps the Custom sheet's Every up by one.
    private func stepEvery(line: UInt = #line) {
        let increment = app.buttons["Increment"].firstMatch
        XCTAssert(increment.waitForExistence(timeout: 3), "No Every stepper:\n\(app.debugDescription)", line: line)
        increment.tap()
        pause(0.5)
    }

    /// The Custom page of a reminder that starts nudging while it's open (ticket 16), light and
    /// dark, before and after the lock, and what VoiceOver gets for its controls once locked, in the
    /// test log (`ACCESSIBILITY` lines), then the locked form. Each launch waits up to 210
    /// seconds for the lock. It only scrolls down: at the top of the sheet a drag down would close it.
    func testCustomLocking() {
        for dark in [false, true] {
            let name = dark ? "form-custom-locking-dark" : "form-custom-locking"
            launch(.customLocking, dark: dark)
            tapText("Plan the week")
            openSheet("Edit", title: "Edit Reminder")
            hideKeyboard()
            shot("\(name)-repeat-unlocked")
            openCustomRow()
            shot("\(name)-unlocked")
            if !dark { reportFormPageAccessibility("custom-unlocked") }
            let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Nudging now.")).firstMatch
            XCTAssert(note.waitForExistence(timeout: 210), "The Custom sheet didn't lock")
            // Apply stays enabled, so the sheet can always close (#284).
            XCTAssert(app.navigationBars["Custom"].buttons["Apply"].isEnabled, "Apply is disabled while locked")
            for page in 1...5 {
                shot("\(name)-locked-\(page)")
                if !dark { reportFormPageAccessibility("custom-locked-\(page)") }
                scroll(down: true)
            }
            // Apply goes back to the form, whose Repeat and Custom rows are locked too.
            barTap { app.navigationBars["Custom"].buttons["Apply"].tap() }
            XCTAssert(app.navigationBars["Edit Reminder"].waitForExistence(timeout: 3), "Apply didn't go to the form")
            shot("\(name)-repeat-locked", pages: 2)
            if !dark { reportFormPageAccessibility("repeat-locked") }
            app.terminate()
        }
    }

    /// The lines of the accessibility tree on screen that name the form's repeat rows, the Custom page's
    /// headings, choices, steppers and checkmarks: each one's type, label, value and whether it's
    /// disabled, under `screen`, such as "custom-locked-2". XCUITest doesn't expose the hint, so
    /// that stays a device check.
    private func reportFormPageAccessibility(_ screen: String) {
        let names = ["Frequency", "Daily", "Weekly", "Monthly", "Yearly", "Every", "'On", "End Repeat", "Never", "After", "On Date", "End Date", "ncrement", "ecrement", "Apply"]
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

    /// The mockup's screens of the same names (`docs/mockups/1.2.0/`).
    func testBadges() {
        launch(.badgesOff)
        tab("Settings")
        // Pages, as for `settings`: at the largest text the row is below the first.
        shot("settings-badges-off", pages: 3)
        launch(.badgesNotSet)
        tab("Settings")
        shot("settings-badges-not-set", pages: 3)
    }
}
