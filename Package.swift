// swift-tools-version: 6.0

import PackageDescription

let strictSwift6: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]

let package = Package(
    name: "SpotiBind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SpotiBindCore",
            targets: ["SpotiBindCore"]
        ),
        .executable(
            name: "SpotiBind",
            targets: ["SpotiBind"]
        )
    ],
    targets: [
        .target(
            name: "SpotiBindCore",
            path: "Sources/SpotiBindCore",
            swiftSettings: strictSwift6
        ),
        .executableTarget(
            name: "SpotiBind",
            dependencies: ["SpotiBindCore"],
            path: "Sources/SpotiBind",
            swiftSettings: strictSwift6
        ),
        .testTarget(
            name: "SpotiBindCoreTests",
            dependencies: ["SpotiBindCore"],
            path: "Tests/SpotiBindCoreTests",
            swiftSettings: strictSwift6
        ),
        .testTarget(
            name: "SpotiBindAppTests",
            dependencies: ["SpotiBind"],
            path: "Tests/SpotiBindAppTests",
            resources: [.process("Fixtures")],
            swiftSettings: strictSwift6
        )
    ]
)
