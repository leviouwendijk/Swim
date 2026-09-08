// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Swim",
    products: [
        .library(
            name: "Swim",
            targets: ["Swim"]
        ),
    ],
    targets: [
        .target(
            name: "Swim"
        ),
    ],
    swiftLanguageModes: [.v6]
)
