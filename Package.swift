// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShiftInput",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ShiftInputCore", targets: ["ShiftInputCore"]),
        .executable(name: "ShiftInput", targets: ["ShiftInput"])
    ],
    targets: [
        .target(name: "ShiftInputCore"),
        .executableTarget(
            name: "ShiftInput",
            dependencies: ["ShiftInputCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
