// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShiftIME",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ShiftIME", targets: ["ShiftIME"])
    ],
    targets: [
        .target(name: "ShiftIMECore"),
        .executableTarget(name: "ShiftIME", dependencies: ["ShiftIMECore"])
    ],
    swiftLanguageModes: [.v5]
)
