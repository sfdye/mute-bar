// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mutebar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MuteBar",
            path: "Sources/MuteBar"
        ),
        .executableTarget(
            name: "mutebar-host",
            path: "Sources/MuteBarHost"
        ),
    ]
)
