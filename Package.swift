// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MemoryMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MemoryMonitor",
            path: "Sources",
            linkerSettings: [.linkedFramework("AppKit")]),
    ]
)