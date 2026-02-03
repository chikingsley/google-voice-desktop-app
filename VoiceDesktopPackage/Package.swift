// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VoiceDesktopFeature",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "VoiceDesktopFeature",
            targets: ["VoiceDesktopFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox", from: "0.26.0"),
    ],
    targets: [
        .target(
            name: "VoiceDesktopFeature",
            dependencies: [
                .product(name: "FlyingFox", package: "FlyingFox"),
            ]
        ),
        .testTarget(
            name: "VoiceDesktopFeatureTests",
            dependencies: [
                "VoiceDesktopFeature"
            ]
        ),
    ]
)
