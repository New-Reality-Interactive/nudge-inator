// swift-tools-version: 6.2
import PackageDescription

// Code compiled into both the app and the widget extension (AlarmKit metadata, Open intent).
let package = Package(
    name: "NudgeShared",
    platforms: [.iOS("26.1")],
    products: [.library(name: "NudgeShared", targets: ["NudgeShared"])],
    // Warnings are errors, as in NudgeEngine.
    targets: [.target(name: "NudgeShared", swiftSettings: [.treatAllWarnings(as: .error)])]
)
