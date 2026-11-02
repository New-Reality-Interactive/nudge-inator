// swift-tools-version: 6.2
import PackageDescription

// Loads named sets of test data into the app for manual device checks (docs/agents/device-testing.md).
// Pure Swift, like NudgeEngine: Foundation and NudgeEngine only, so its tests run on the Mac with
// no simulator. The app doesn't link this package: project.yml compiles its source folder into the
// app, and every file there is wrapped in `#if DEBUG`, so a Release build holds none of it.
// Warnings are errors, as in NudgeEngine.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "NudgeDeviceSeed",
    platforms: [.iOS("26.1"), .macOS("26.0")],
    products: [.library(name: "NudgeDeviceSeed", targets: ["NudgeDeviceSeed"])],
    dependencies: [.package(path: "../NudgeEngine")],
    targets: [
        .target(
            name: "NudgeDeviceSeed",
            dependencies: [.product(name: "NudgeEngine", package: "NudgeEngine")],
            swiftSettings: strict
        ),
        .testTarget(name: "NudgeDeviceSeedTests", dependencies: ["NudgeDeviceSeed"], swiftSettings: strict),
    ]
)
