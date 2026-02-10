// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWNormalizeAudioPlayer",
    platforms: [
        .iOS(.v15)
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
