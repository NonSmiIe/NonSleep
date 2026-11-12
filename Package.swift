// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NonSleep",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NonSleepCore"),
        .executableTarget(name: "NonSleepHelper", dependencies: ["NonSleepCore"]),
        .executableTarget(name: "NonSleep", dependencies: ["NonSleepCore"]),
        .testTarget(name: "NonSleepCoreTests", dependencies: ["NonSleepCore"]),
    ]
)
