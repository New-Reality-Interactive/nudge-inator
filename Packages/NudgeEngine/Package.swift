// swift-tools-version: 6.0
import PackageDescription

// Pure Swift: no Apple framework imports (Foundation at most). scripts/test.sh enforces this.
let package = Package(
    name: "NudgeEngine",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "NudgeEngine", targets: ["NudgeEngine"])],
    targets: [
        .target(name: "NudgeEngine"),
        .testTarget(name: "NudgeEngineTests", dependencies: ["NudgeEngine"]),
    ]
)
