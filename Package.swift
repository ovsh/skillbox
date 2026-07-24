// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Loadout",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Loadout", targets: ["Loadout"]),
        .library(name: "LoadoutKit", targets: ["LoadoutKit"]),
    ],
    dependencies: [
        // Pinned: 3.4x is the last line that compiles cleanly against the
        // macOS 15.2 SDK via SwiftPM (newer versions break in PLCrashReporter).
        .package(url: "https://github.com/PostHog/posthog-ios", "3.41.1"..<"3.42.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "LoadoutKit",
            path: "Sources/LoadoutKit"
        ),
        .executableTarget(
            name: "Loadout",
            dependencies: [
                "LoadoutKit",
                .product(name: "PostHog", package: "posthog-ios"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/Loadout",
            resources: [
                .copy("Resources/AppIcon.png")
            ],
            swiftSettings: [
                // Workaround for Swift 6.0.x compiler crash in release builds:
                // https://github.com/swiftlang/swift/issues/73970
                .unsafeFlags(["-Xfrontend", "-disable-round-trip-debug-types"],
                             .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "LoadoutKitTests",
            dependencies: ["LoadoutKit"],
            path: "Tests/LoadoutKitTests"
        ),
    ]
)
