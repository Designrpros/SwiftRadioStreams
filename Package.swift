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
        // (No additional dependencies in this example)
    ],
    targets: [
        .target(
            name: "SwiftRadioStreams",
            dependencies: [],
            path: "Sources/SwiftRadioStreams",
            resources: [
                // Adjust the relative path as needed; this example assumes that External is at the root of your package.
                .copy("../../External/internet-radio-streams")
            ]
        )
    ]
)