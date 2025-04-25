// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "pushpushgo_sdk",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "pushpushgo-sdk", targets: ["pushpushgo_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/ppgco/ios-sdk.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "pushpushgo_sdk",
            dependencies: [
                .product(name: "PPG_framework", package: "ios-sdk")
            ],
            resources: []
        )
    ]
)
