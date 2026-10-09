// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Runestone",
    defaultLocalization: "en",
    platforms: [
        .iOS("18.0")  // Omnie-dev: raised from 14 for inline-prediction and Writing Tools traits
    ],
    products: [
        .library(name: "Runestone", targets: ["Runestone"])
    ],
    dependencies: [
        .package(url: "https://github.com/tree-sitter/tree-sitter", .upToNextMinor(from: "0.26.13"))
    ],
    targets: [
        .target(name: "Runestone", dependencies: [
            .product(name: "TreeSitter", package: "tree-sitter")
        ], resources: [
            .copy("PrivacyInfo.xcprivacy"),
            .process("TextView/Appearance/Theme.xcassets")
        ]),
        .target(name: "TestTreeSitterLanguages", cSettings: [
            .unsafeFlags(["-w"])
        ]),
        .testTarget(name: "RunestoneTests", dependencies: [
            "Runestone",
            "TestTreeSitterLanguages"
        ])
    ]
)
