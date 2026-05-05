// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AniAngliaMacOS",
    defaultLocalization: "ru",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AniAnglia", targets: ["AniAngliaMacOS"])
    ],
    targets: [
        .executableTarget(
            name: "AniAngliaMacOS",
            path: "AniAnglia"
        ),
        .testTarget(
            name: "AniAngliaMacOSTests",
            dependencies: ["AniAngliaMacOS"],
            path: "AniAngliaTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
