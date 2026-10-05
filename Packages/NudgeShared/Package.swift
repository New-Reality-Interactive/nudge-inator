// swift-tools-version: 6.0
import PackageDescription

// Code compiled into both the app and the widget extension (AlarmKit metadata, Open intent).
let package = Package(
    name: "NudgeShared",
    platforms: [.iOS("26.1")],
    products: [.library(name: "NudgeShared", targets: ["NudgeShared"])],
    targets: [.target(name: "NudgeShared")]
)
