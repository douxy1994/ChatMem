// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChatMemNew",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ChatMemNew", targets: ["ChatMemNew"])
    ],
    targets: [
        .executableTarget(
            name: "ChatMemNew",
            path: "Sources/ChatMemNew"
        ),
        .testTarget(
            name: "ChatMemNewTests",
            dependencies: ["ChatMemNew"],
            path: "Tests/ChatMemNewTests"
        )
    ]
)
