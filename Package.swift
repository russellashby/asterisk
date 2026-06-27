// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WordStarMac",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "WordStarMac",
            path: "Sources/WordStarMac"
        )
    ],
    swiftLanguageVersions: [.v5]
)
