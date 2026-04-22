// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexRemoteHost",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "CodexRemoteHost",
            targets: ["CodexRemoteHost"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "CodexRemoteHost"
        ),
        .testTarget(
            name: "CodexRemoteHostTests",
            dependencies: ["CodexRemoteHost"]
        ),
    ]
)
