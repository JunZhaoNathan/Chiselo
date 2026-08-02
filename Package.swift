// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Chiselo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Chiselo", targets: ["Chiselo"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "Chiselo",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Chiselo",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChiseloTests",
            dependencies: ["Chiselo"],
            path: "Tests/ChiseloTests"
        )
    ]
)
