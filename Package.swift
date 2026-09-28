// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Usagebar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Usagebar",
            path: "Sources/Usagebar"
        )
    ]
)
