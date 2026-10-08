## Agent skills

### Issue tracker

Issues and specs are local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Design system

Colors, type, spacing, shapes and components are in `docs/design/DESIGN.md`. UI stories meet it; screen layout is the mockup under `docs/mockups/`.

## Apple platform questions

For any iOS design, implementation or testing question, or any Xcode question, look it up with the `apple-rag-mcp` tools before answering or deciding: `search` first, then `fetch` for a full page. Don't answer from memory.

- Say what the docs confirm and what they don't. If they're silent, mark it as a device check instead of guessing.
- If `apple-rag-mcp` has nothing on a page (for example a support.apple.com guide), say so before falling back to another source.

## Coding standards

Nudge-inator is a Swift 6, SwiftUI, iPhone-only app (iOS 26.1 minimum) with a widget extension and two local packages. `project.yml` is the source of truth for the Xcode project: edit it, then run `xcodegen generate`. Never hand-edit the generated `.xcodeproj`.

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

### Accessibility

Apple's SwiftUI accessibility docs and the WWDC accessibility sessions confirm the following:

- Use text styles (`.font(.body)`, etc.), not fixed font sizes. Let text wrap. Switch to a stacked layout at large Dynamic Type sizes.
- Give every icon-only control an `accessibilityLabel`. Hide decorative images from VoiceOver.
- Combine multi-part cells into one accessibility element with a meaningful label and value.
- Any custom gesture needs an equivalent `accessibilityAction` or a real `Button`.
- Don't use color as the only signal.

### AlarmKit

Apple's AlarmKit docs confirm that scheduling fails silently without a non-empty `NSAlarmKitUsageDescription`, and that the app must handle the `denied` authorization state in its UI. The docs don't say how alert-only alarms behave with the empty widget extension present. Ticket 02 checks that on a device. Don't assume it works.

### Testing

- Write new tests with Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), not XCTest. Use XCTest only for UI automation or performance tests, which Swift Testing doesn't support.
- Group related tests in a `struct` suite. Use parameterized `@Test(arguments:)` instead of `for` loops over cases.
- Test names describe behavior, without a `test` prefix.
- Engine logic is tested in `NudgeEngineTests` with no simulator. App-target tests cover only code that needs Apple frameworks.
- Automated tests always run against **both** the iOS 26.1 and iOS 26.5 simulators (the oldest and newest we test on); `scripts/test.sh` does this. Don't narrow it to one version to get a pass. Simulators don't cover AlarmKit behavior, so device checks stay on a physical iPhone and record its iOS version.
- Run everything with `scripts/test.sh` before committing. UI, VoiceOver and AlarmKit behavior can't be checked in unit tests, so mark those as device checks.

### Comments and style

- Comment why, not what. Skip comments that restate the code.
- Match the surrounding code's naming and formatting. No formatter or linter is configured; don't add one without asking.
