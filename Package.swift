// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "right here",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "right here", targets: ["right here"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "right here",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources"
        )
    ]
)
