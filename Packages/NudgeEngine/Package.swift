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
    ]
)
