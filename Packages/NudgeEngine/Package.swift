// swift-tools-version: 6.0
import PackageDescription

// Pure Swift: no Apple framework imports (Foundation at most). scripts/test.sh enforces this.
// The words the engine shows (notification bodies, repeat summaries) are in its own String
// Catalog, compiled only by xcodebuild (see scripts/test.sh).
let package = Package(
    name: "NudgeEngine",
    defaultLocalization: "en",
    platforms: [.iOS("26.1"), .macOS("26.0")],
    products: [.library(name: "NudgeEngine", targets: ["NudgeEngine"])],
    targets: [
        .target(name: "NudgeEngine", resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "NudgeEngineTests", dependencies: ["NudgeEngine"]),
    ]
)
