// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "rswift",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v11),
    .tvOS(.v11),
    .watchOS(.v4),
  ],
  products: [
    .executable(name: "rswift", targets: ["rswift"]),
    .executable(name: "rswift-legacy", targets: ["rswift-legacy"]),
    .library(name: "RswiftCombined", targets: ["RswiftResources"])
  ],
  dependencies: [
    .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
    .package(url: "https://github.com/tomlokhorst/XcodeEdit", from: "2.8.0"),
  ],
  targets: [
    .target(name: "RswiftResources"),
    .target(name: "RswiftGenerators", dependencies: ["RswiftResources"]),
    .target(name: "RswiftParsers", dependencies: ["RswiftResources", "XcodeEdit"]),

    // Core of R.swift, brings all previous parts together
    .target(name: "RswiftCore", dependencies: ["RswiftParsers", "RswiftGenerators"]),

    // Executable that calls Core
    .target(name: "rswift", dependencies: ["RswiftCore"]),

    // Legacy code
    .target(name: "rswift-legacy", dependencies: ["RswiftCoreLegacy"]),
    .target(name: "RswiftCoreLegacy", dependencies: ["Commander", "XcodeEdit"]),
    .testTarget(name: "RswiftCoreLegacyTests", dependencies: ["RswiftCoreLegacy"]),
  ]
)
