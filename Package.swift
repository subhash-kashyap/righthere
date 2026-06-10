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
    targets: [
        .executableTarget(
            name: "right here",
            path: "Sources"
        )
    ]
)
