// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Refiner",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(url: "https://github.com/zats/permiso.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Refiner",
            dependencies: [
                .product(name: "Permiso", package: "permiso"),
            ],
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
