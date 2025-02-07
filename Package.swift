// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "SwiftRadioStreams",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftRadioStreams",
            targets: ["SwiftRadioStreams"]
        )
    ],
    dependencies: [
        // No external dependencies.
    ],
    targets: [
        .target(
            name: "SwiftRadioStreams",
            dependencies: [],
            path: "Sources/SwiftRadioStreams",
            resources: [
                // Relative path: from Sources/SwiftRadioStreams, go up two levels then into External/internet-radio-streams.
                .copy("../../External/internet-radio-streams")
            ]
        )
    ]
)