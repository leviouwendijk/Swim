// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Swim",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Swim",
            targets: ["Swim"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Position.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/SwimInterpreter.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/SwimIO.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Swim",
            dependencies: [
                "Position",
                "SwimInterpreter",
                "SwimIO",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
