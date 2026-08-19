// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusMintegralKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
           name: "NimbusMintegralKit",
           targets: ["NimbusMintegralKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Mintegral-official/MintegralAdSDK-Swift-Package", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "NimbusMintegralKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "MintegralAdSDK", package: "MintegralAdSDK-Swift-Package")
            ]
        ),
        .testTarget(
            name: "NimbusMintegralKitTests",
            dependencies: ["NimbusMintegralKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.3"))
