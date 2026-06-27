// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WordStarMac",
    platforms: [.macOS(.v12)],
    targets: [
        // AppKit-free editor core (piece table, layout, document). Unit tested.
        // -enable-testing lets the standalone test runner reach internals via
        // @testable, without needing XCTest (unavailable under CLT-only).
        .target(
            name: "WSCore",
            path: "Sources/WSCore",
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        ),
        // The native AppKit application.
        .executableTarget(
            name: "WordStarMac",
            dependencies: ["WSCore"],
            path: "Sources/WordStarMac"
        ),
        // XCTest-free test runner (exits non-zero on failure).
        .executableTarget(
            name: "WSCoreTests",
            dependencies: ["WSCore"],
            path: "Tests/WSCoreTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
