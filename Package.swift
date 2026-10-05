// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShiftInput",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ShiftInput", targets: ["ShiftInput"])
    ],
    targets: [
        .target(name: "ShiftInputCore"),
        .executableTarget(name: "ShiftInput", dependencies: ["ShiftInputCore"])
    ],
    swiftLanguageModes: [.v5]
)
