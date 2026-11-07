# Memory Monitor

A macOS menu-bar application that displays real-time memory usage, swap activity, and memory pressure — all collected via native system calls (`sysctl`, `host_statistics64`, `getpagesize`).

## Features

- **Physical memory** — total, used, free, active, inactive, wired
- **Swap memory** — total, used, free, usage percentage
- **Memory pressure** — green (normal), yellow (warning), red (critical)
- **Menu-bar widget** — live free-memory percentage with pressure indicator, updates every 2 seconds
- **Console report** — `MemoryMonitor.printReport()` outputs a formatted summary

## Requirements

- macOS 14.0 or later
- [Swift Command Line Tools](https://developer.apple.com/download/all/) (Swift 5.10+)
  - No Xcode required

## Build & Run

### Menu-bar application

```bash
swift build -c release
./build/release/MemoryMonitorApp
```

### Console memory report

```bash
swift run MemoryMonitorApp
```

### Tests

```bash
swift run MemoryMonitorTestsRunner
```

All test functions should pass. Exit code `0` means all passed; `1` indicates failures.

> Note: The test runner must be built in debug mode (not release) because it uses `@testable import MemoryMonitorLib`.

## Project Structure

```
Package.swift
├── Sources/MemoryMonitorLib/
│   └── MemoryMonitor.swift    # Core library: collect(), formatBytes(), printReport()
├── Sources/MemoryMonitorApp/
│   ├── MenuBarApp.swift        # AppKit menu-bar widget (status item + timer)
│   └── main.swift
└── Tests/MemoryMonitorTests/
    └── MemoryMonitorTests.swift  # Custom executable test runner (no XCTest)
```

## Targets

| Target | Type | Description |
|---|---|---|
| `MemoryMonitorLib` | Library | Core memory-collection API |
| `MemoryMonitorApp` | Executable | Menu-bar application (AppKit) |
| `MemoryMonitorTestsRunner` | Executable | Manual test runner (12 test functions) |
