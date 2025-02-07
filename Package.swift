// swift-tools-version:5.5
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
            path: "Sources/SwiftRadioStreams"
        )
    ]
)
