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
            name: "Refiner"
        ),
        .testTarget(
            name: "RefinerTests",
            dependencies: ["Refiner"]
        ),
    ]
)
