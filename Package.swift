// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "StayOn",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "StayOn",
            targets: ["StayOn"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "StayOn",
            dependencies: [],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["StayOn"],
            path: "Tests/AppTests"
        )
    ]
)
