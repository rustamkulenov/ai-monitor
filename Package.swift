// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MemoryMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MemoryMonitorLib",
            path: "Sources/MemoryMonitorLib"),
        .executableTarget(
            name: "MemoryMonitorApp",
            dependencies: ["MemoryMonitorLib"],
            path: "Sources/MemoryMonitorApp",
            linkerSettings: [.linkedFramework("AppKit")]),
        .executableTarget(
            name: "MemoryMonitorTestsRunner",
            dependencies: ["MemoryMonitorLib"],
            path: "Tests/MemoryMonitorTests"),
    ]
)
