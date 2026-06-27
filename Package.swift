// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecretKnock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SecretKnock",
            path: "Sources/SecretKnock",
            linkerSettings: []
        ),
        .testTarget(
            name: "SecretKnockTests",
            dependencies: ["SecretKnock"],
            path: "Tests/SecretKnockTests"
        )
    ]
)
