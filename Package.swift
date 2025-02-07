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
        // No additional dependencies
    ],
    targets: [
        .target(
            name: "SwiftRadioStreams",
            dependencies: [],
            path: "Sources/SwiftRadioStreams",
            resources: [
                // Copy the external folder from two directories up (adjust the relative path if needed)
                .copy("../../External/internet-radio-streams")
            ]
        )
    ]
)