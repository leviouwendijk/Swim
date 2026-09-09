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
        .executable(
            name: "swimtest",
            targets: ["SwimTestFlows"]
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
        .executableTarget(
            name: "SwimTestFlows",
            dependencies: [
                "Swim",
                .product(
                    name: "Position",
                    package: "Position"
                ),
                .product(
                    name: "SwimInterpreter",
                    package: "SwimInterpreter"
                ),
                .product(
                    name: "SwimIO",
                    package: "SwimIO"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
