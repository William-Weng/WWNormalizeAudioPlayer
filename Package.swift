// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWNormalizeAudioPlayer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "WWNormalizeAudioPlayer", targets: ["WWNormalizeAudioPlayer"]),
    ],
    targets: [
        .target(name: "WWNormalizeAudioPlayer"),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
