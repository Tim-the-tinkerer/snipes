// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snipes",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Snipes", targets: ["Snipes"]),
        .executable(name: "MakeIcon", targets: ["MakeIcon"]),
    ],
    targets: [
        .executableTarget(
            name: "Snipes",
            path: "Sources/Snipes"
        ),
        .executableTarget(
            name: "MakeIcon",
            path: "Sources/MakeIcon"
        ),
    ]
)