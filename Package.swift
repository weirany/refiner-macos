// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Refiner",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "Refiner",
            resources: [
                .process("Resources/BuildInfo.plist"),
            ]
        ),
        .testTarget(
            name: "RefinerTests",
            dependencies: ["Refiner"]
        ),
    ]
)
