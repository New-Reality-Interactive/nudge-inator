# Coding standards

How the app's code is written. Read while writing it; `code-review`'s Standards agent checks every diff against it. Project rules that shape the work itself (toolchain, structure, AlarmKit, the test matrix, device safety) are in `AGENTS.md`.

## Naming

- Use the domain terms in `GLOSSARY.md` for type and function names. Don't invent synonyms.

## Swift

- Keep the project in the Swift 6 language mode. Fix data-race errors with value types, `Sendable` and actors, not `@unchecked Sendable` or `nonisolated(unsafe)`. If one of those is unavoidable, add a comment saying why it is safe.
- Prefer `struct` and `enum` for model and engine types. Use `final class` only when you need reference identity or `@Observable`.
- Isolate UI-facing models with `@MainActor`. Keep engine code free of actor isolation so it stays testable on macOS.
- No force unwraps (`!`), `try!` or `as!` outside tests and previews. Model failure with `throws` or `Optional`.
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). apple-rag didn't return that page, so check it directly if you're unsure.

## SwiftUI

Apple's "Managing model data in your app" and WWDC23 "Discover Observation in SwiftUI" confirm the following:

- Model types use the `@Observable` macro, not `ObservableObject` or `@Published`.
- Pick the wrapper by asking: does the view own the model? `@State` (private). Is it shared app-wide? `@Environment`. Does the view only need bindings? `@Bindable`. Otherwise pass it as a plain property.
- Keep `body` cheap and free of side effects. Move logic into the model or the engine.
- Keep views small. Extract a subview when a `body` stops fitting on one screen.
- Add a `#Preview` for each non-trivial view. One that uses a fixture from a `#if DEBUG` file sits inside `#if DEBUG` too, or the Release archive fails to compile.
- The app turns to landscape, so lay out with size classes, safe areas and `ScrollView`/`List`, never fixed screen sizes. Put a screen's content in `TabScreen`, which centers it at `Design.Spacing.readableWidth`, and leave sheets to the system's full-screen adaptation in compact height.

## Accessibility

Apple's SwiftUI accessibility docs and the WWDC accessibility sessions confirm the following:

- Use text styles (`.font(.body)`, etc.), not fixed font sizes. Let text wrap. Switch to a stacked layout at large Dynamic Type sizes.
- Give every icon-only control an `accessibilityLabel`. Hide decorative images from VoiceOver.
- Combine multi-part cells into one accessibility element with a meaningful label and value.
- Any custom gesture needs an equivalent `accessibilityAction` or a real `Button`.
- Don't use color as the only signal.

## Localization

The app ships in English, but every string a person sees goes through a String Catalog, so another language needs only translations. Apple's "Discover String Catalogs" (WWDC23) and "Explore localization with Xcode" (WWDC25) confirm the following:

- The app's strings are in `App/Resources/Localizable.xcstrings` and `InfoPlist.xcstrings`. NudgeEngine's (notification bodies, repeat summaries) are in its own catalog, read with `bundle: .module`.
- In views, pass string literals to SwiftUI (`Text`, `Button`, `navigationTitle`, `accessibilityLabel`). Text held outside a view is a `LocalizedStringResource`, never a `String`. Elsewhere use `String(localized:)`.
- Give each string a `comment:` that says where it shows and what each placeholder holds.
- Whole sentences with placeholders, never fragments glued together. Counts use plural variants in the catalog. Names, lists, ordinals, dates and times come from Foundation's formatters in the locale, never hand-written English.
- Text the person wrote (a reminder's title) is never translated. Mark its catalog entry "Don't translate".
- Command-line builds don't update the catalogs. After adding or changing a string, run `scripts/sync-strings.sh .build/derived` (after `scripts/test.sh`, or any build into that folder), then fill in plural variants. `scripts/test.sh` fails if a catalog is out of date.

## Tests

- Write new tests with Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), not XCTest. Use XCTest only for UI automation or performance tests, which Swift Testing doesn't support.
- Group related tests in a `struct` suite. Use parameterized `@Test(arguments:)` instead of `for` loops over cases.
- Test names describe behavior, without a `test` prefix.
- Engine logic is tested in `NudgeEngineTests` with no simulator. App-target tests cover only code that needs Apple frameworks.

## Comments and style

- Comment why, not what. Skip comments that restate the code.
- Match the surrounding code's naming and formatting. No formatter or linter is configured; don't add one without asking.
