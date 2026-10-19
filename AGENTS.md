## Agent skills

### Issue tracker

Issues and specs are local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

A ticket is `resolved` only when every acceptance criterion is ticked. While one is open, its `Status:` stays as it was. Say which criterion is open and why, and resolve it with the user: meet it, or agree a change to it (reworded, or moved to a named ticket) and record that agreement in Comments.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Design system

Colors, type, spacing, shapes and components are in `docs/design/DESIGN.md`. UI stories meet it; screen layout is the mockup under `docs/mockups/`.

### Code review and session size

How a ticket is reviewed and how to keep a session small: `docs/agents/review.md`.

## Apple platform questions

For any iOS design, implementation or testing question, or any Xcode question, look it up with the `apple-rag-mcp` tools before answering or deciding: `search` first, then `fetch` for a full page. Don't answer from memory.

- Say what the docs confirm and what they don't. If they're silent, mark it as a device check instead of guessing.
- If `apple-rag-mcp` has nothing on a page (for example a support.apple.com guide), say so before falling back to another source.

## Coding standards

Nudge-inator is a Swift 6, SwiftUI, iPhone-only app (iOS 26.1 minimum) with a widget extension and two local packages. `project.yml` is the source of truth for the Xcode project: edit it, then run `xcodegen generate`. Never hand-edit the generated `.xcodeproj`.

### Toolchain

The project builds with **Xcode 26.6 and the iOS 26.5 SDK**, the newest the development Mac (Intel) can run. There is no iOS 27 SDK or simulator here. Don't use iOS 27-only APIs, don't add an iOS 27 simulator to the test matrix, and don't raise the SDK or tooling past 26.x. Physical-device checks can still run on a newer iOS. Rationale: `docs/agents/device-testing.md`.

### Structure

- `Packages/NudgeEngine` is pure Swift: no Apple framework imports, `Foundation` at most. `scripts/test.sh` enforces this. Anything that touches Apple frameworks (AlarmKit, store, adapters) lives in the app target, behind a type the engine can use without importing the framework.
- `Packages/NudgeShared` holds only code that both the app and the widget extension compile (AlarmKit `AlarmMetadata`, the Open intent).
- Use the domain terms in `GLOSSARY.md` for type and function names. Don't invent synonyms.

### Swift

- Keep the project in the Swift 6 language mode. Fix data-race errors with value types, `Sendable` and actors, not `@unchecked Sendable` or `nonisolated(unsafe)`. If one of those is unavoidable, add a comment saying why it is safe.
- Prefer `struct` and `enum` for model and engine types. Use `final class` only when you need reference identity or `@Observable`.
- Isolate UI-facing models with `@MainActor`. Keep engine code free of actor isolation so it stays testable on macOS.
- No force unwraps (`!`), `try!` or `as!` outside tests and previews. Model failure with `throws` or `Optional`.
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). apple-rag didn't return that page, so check it directly if you're unsure.

### SwiftUI

Apple's "Managing model data in your app" and WWDC23 "Discover Observation in SwiftUI" confirm the following:

- Model types use the `@Observable` macro, not `ObservableObject` or `@Published`.
- Pick the wrapper by asking: does the view own the model? `@State` (private). Is it shared app-wide? `@Environment`. Does the view only need bindings? `@Bindable`. Otherwise pass it as a plain property.
- Keep `body` cheap and free of side effects. Move logic into the model or the engine.
- Keep views small. Extract a subview when a `body` stops fitting on one screen.
- Add a `#Preview` for each non-trivial view.
- The app turns to landscape, so lay out with size classes, safe areas and `ScrollView`/`List`, never fixed screen sizes. Put a screen's content in `TabScreen`, which centers it at `Design.Spacing.readableWidth`, and leave sheets to the system's full-screen adaptation in compact height.

### Accessibility

Apple's SwiftUI accessibility docs and the WWDC accessibility sessions confirm the following:

- Use text styles (`.font(.body)`, etc.), not fixed font sizes. Let text wrap. Switch to a stacked layout at large Dynamic Type sizes.
- Give every icon-only control an `accessibilityLabel`. Hide decorative images from VoiceOver.
- Combine multi-part cells into one accessibility element with a meaningful label and value.
- Any custom gesture needs an equivalent `accessibilityAction` or a real `Button`.
- Don't use color as the only signal.

### Localization

The app ships in English, but every string a person sees goes through a String Catalog, so another language needs only translations. Apple's "Discover String Catalogs" (WWDC23) and "Explore localization with Xcode" (WWDC25) confirm the following:

- The app's strings are in `App/Resources/Localizable.xcstrings` and `InfoPlist.xcstrings`. NudgeEngine's (notification bodies, repeat summaries) are in its own catalog, read with `bundle: .module`.
- In views, pass string literals to SwiftUI (`Text`, `Button`, `navigationTitle`, `accessibilityLabel`). Text held outside a view is a `LocalizedStringResource`, never a `String`. Elsewhere use `String(localized:)`.
- Give each string a `comment:` that says where it shows and what each placeholder holds.
- Whole sentences with placeholders, never fragments glued together. Counts use plural variants in the catalog. Names, lists, ordinals, dates and times come from Foundation's formatters in the locale, never hand-written English.
- Text the person wrote (a reminder's title) is never translated. Mark its catalog entry "Don't translate".
- Command-line builds don't update the catalogs. After adding or changing a string, run `scripts/sync-strings.sh .build/derived` (after `scripts/test.sh`, or any build into that folder), then fill in plural variants. `scripts/test.sh` fails if a catalog is out of date.

### AlarmKit

Apple's AlarmKit docs confirm that scheduling fails silently without a non-empty `NSAlarmKitUsageDescription`, and that the app must handle the `denied` authorization state in its UI. The docs don't say how alert-only alarms behave with the empty widget extension present. Ticket 02 checks that on a device. Don't assume it works.

Never read `AlarmManager.authorizationState` directly. It is a synchronous call to the system's alarm service, and on the iPhone, read on the main thread right after the prompt was answered, it froze the app for 69 s, and once for good (ticket 22). Apple's docs don't say it can block. `AlarmAdapter` reads it off the main thread with a time limit, at launch and each time the app comes forward (`refreshAuthorization()`, never while an earlier read is still outstanding), and between those takes the state from `requestAuthorization()`'s answer and from `authorizationUpdates`. The updates alone aren't enough: on the iPhone (iOS 27.0.1) a change made in Settings while the app was suspended sent none (ticket 30). Ask the adapter (`permissions(updating:)`) for the state instead.

### Testing

- Write new tests with Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), not XCTest. Use XCTest only for UI automation or performance tests, which Swift Testing doesn't support.
- Group related tests in a `struct` suite. Use parameterized `@Test(arguments:)` instead of `for` loops over cases.
- Test names describe behavior, without a `test` prefix.
- Engine logic is tested in `NudgeEngineTests` with no simulator. App-target tests cover only code that needs Apple frameworks.
- Automated tests always run against **both** the iOS 26.1 and iOS 26.5 simulators (the minimum, and the newest this Mac's Xcode supports; see Toolchain); `scripts/test.sh` does this. Don't narrow it to one version to get a pass. Simulators don't cover AlarmKit behavior, so device checks stay on a physical iPhone and record its iOS version.
- Run everything with `scripts/test.sh` before committing. UI, VoiceOver and AlarmKit behavior can't be checked in unit tests, so mark those as device checks.
- Any test run on the physical iPhone is safe and leaves the phone exactly as it found it. Each test undoes everything it changed: pending and delivered notifications, scheduled alarms, stored data, and the app's own state. The cleanup runs even when the test fails, so put it in a `defer` or in a class or actor suite's `deinit`, which Swift Testing runs after each test. A test acts only on what it created, found by its own identifiers, and leaves the person's reminders, notifications from other apps, and system settings (permissions, Focus, Time Sensitive) as they were. If a test can't undo something, make it a manual device check instead. Before a device run, note whether the app is installed (`xcrun devicectl device info apps`). If it wasn't, uninstall it afterwards, which also resets its permissions. If it was, keep it and its data.
- Uninstalling does **not** remove the app's AlarmKit alarms on a device, so a device test cancels every alarm it schedules and doesn't assume a fresh install holds none. A device test shows a permission prompt only when the run says the app wasn't installed (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`). History and detail: `docs/agents/device-testing.md`.
- When closing an acceptance criterion needs device checks that need the person, walk them through one check at a time and wait for their go before each run. If a run does not do what you said it would, stop and explain before running anything else. Procedure: `docs/agents/device-testing.md`.

### Comments and style

- Comment why, not what. Skip comments that restate the code.
- Match the surrounding code's naming and formatting. No formatter or linter is configured; don't add one without asking.
