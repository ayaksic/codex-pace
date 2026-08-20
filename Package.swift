// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexPace",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "CodexPaceCore", targets: ["CodexPaceCore"]),
        .library(name: "CodexPaceUI", targets: ["CodexPaceUI"]),
        .executable(name: "codex-pace", targets: ["CodexPaceCLI"]),
        .executable(name: "CodexPaceMenu", targets: ["CodexPaceMenu"]),
        .executable(name: "codex-pace-preview", targets: ["CodexPacePreview"]),
    ],
    targets: [
        .target(name: "CodexPaceCore"),
        .executableTarget(
            name: "CodexPaceCLI",
            dependencies: ["CodexPaceCore"]
        ),
        .executableTarget(
            name: "CodexPaceMenu",
            dependencies: ["CodexPaceUI"]
        ),
        .target(
            name: "CodexPaceUI",
            dependencies: ["CodexPaceCore"]
        ),
        .executableTarget(
            name: "CodexPacePreview",
            dependencies: ["CodexPaceCore", "CodexPaceUI"]
        ),
        .testTarget(
            name: "CodexPaceCoreTests",
            dependencies: ["CodexPaceCore"]
        ),
        .testTarget(
            name: "CodexPaceUITests",
            dependencies: ["CodexPaceCore", "CodexPaceUI"]
        ),
    ]
)
