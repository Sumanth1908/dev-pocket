// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DevPocket",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic for each utility — no UI, fully unit-testable.
        .target(name: "DevPocketCore"),
        // The menu bar / floating bubble app.
        .executableTarget(name: "DevPocket", dependencies: ["DevPocketCore"]),
        .testTarget(name: "DevPocketCoreTests", dependencies: ["DevPocketCore"]),
    ]
)
