// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Swim",
    products: [
        .library(
            name: "Swim",
            targets: ["Swim"]
        ),
        .executable(
            name: "swimtest",
            targets: [
                "SwimSmoke"
            ]
        ),
    ],
    targets: [
        .target(
            name: "Swim"
        ),
        .executableTarget(
            name: "SwimSmoke",
            dependencies: [
                "Swim"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
