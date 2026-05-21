// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EfficientTime",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EfficientTimeCore",
            targets: ["EfficientTimeCore"]
        ),
        .executable(
            name: "EfficientTimeApp",
            targets: ["EfficientTimeApp"]
        )
    ],
    targets: [
        .target(
            name: "EfficientTimeCore"
        ),
        .executableTarget(
            name: "EfficientTimeApp",
            dependencies: ["EfficientTimeCore"]
        ),
        .testTarget(
            name: "EfficientTimeCoreTests",
            dependencies: ["EfficientTimeCore"]
        )
    ]
)

