// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pin",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "Pin",
            path: "Pin/Sources"
        ),
        .testTarget(
            name: "PinTests",
            dependencies: ["Pin"],
            path: "Tests"
        )
    ]
)
