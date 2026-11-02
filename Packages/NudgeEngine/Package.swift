// swift-tools-version: 6.2
import PackageDescription

// Pure Swift: no Apple framework imports (Foundation at most). scripts/test.sh enforces this.
// The words the engine shows (notification bodies, repeat summaries) are in its own String
// Catalog, compiled only by xcodebuild (see scripts/test.sh).
// Warnings are errors: a new toolchain's warnings otherwise pass unnoticed (pace ticket 01).
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "NudgeEngine",
    defaultLocalization: "en",
    platforms: [.iOS("26.1"), .macOS("26.0")],
    products: [.library(name: "NudgeEngine", targets: ["NudgeEngine"])],
    targets: [
        .target(name: "NudgeEngine", resources: [.process("Localizable.xcstrings")], swiftSettings: strict),
        .testTarget(name: "NudgeEngineTests", dependencies: ["NudgeEngine"], swiftSettings: strict),
        // The device seed (#134): test data a Debug build loads for manual device checks. Not a
        // product, so nothing links it. The app compiles its source folder in Debug builds only
        // (project.yml), and every file there is wrapped in `#if DEBUG`. It lives in this package so
        // its tests run on the Mac with the engine's, and it needs only Foundation and NudgeEngine.
        .target(name: "NudgeDeviceSeed", dependencies: ["NudgeEngine"], swiftSettings: strict),
        .testTarget(name: "NudgeDeviceSeedTests", dependencies: ["NudgeDeviceSeed"], swiftSettings: strict),
    ]
)
