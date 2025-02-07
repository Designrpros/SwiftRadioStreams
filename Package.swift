// swift-tools-version:5.3
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
                .process("../../External/internet-radio-streams")
            ]
        )
    ]
)
