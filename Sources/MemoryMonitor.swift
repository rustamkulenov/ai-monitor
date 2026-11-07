import Foundation
import Darwin

// MARK: - Helpers

private func sysctlUint64(_ name: String) -> UInt64? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    var value: UInt64 = 0
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
}

private func sysctlInt64(_ name: String) -> Int64? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    var value: Int64 = 0
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
}

private func sysctlInt32(_ name: String) -> Int32? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    var value: Int32 = 0
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
    return value
}

private func formatBytes(_ bytes: UInt64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var size = Double(bytes)
    var unitIndex = 0
    while size >= 1024.0 && unitIndex < units.count - 1 {
        size /= 1024.0
        unitIndex += 1
    }
    return String(format: "%.2f %@", size, units[unitIndex])
}

// MARK: - MemoryInfo

struct MemoryInfo {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var free: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var external: UInt64 = 0
    var speculative: UInt64 = 0
    var pageable: UInt64 = 0
    var purgeable: UInt64 = 0

    var usagePercent: Double {
        total > 0 ? Double(used) / Double(total) * 100.0 : 0
    }
}

// MARK: - SwapInfo

struct SwapInfo {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var free: UInt64 = 0

    var usagePercent: Double {
        total > 0 ? Double(used) / Double(total) * 100.0 : 0
    }
}

// MARK: - PressureInfo

enum MemoryPressure {
    case green
    case yellow
    case red

    var description: String {
        switch self {
        case .green: return "Green (Normal)"
        case .yellow: return "Yellow (Warning)"
        case .red:   return "Red (Critical)"
        }
    }
}

// MARK: - MemoryMonitor

enum MemoryMonitor {

    /// Collect comprehensive memory information from the system
    static func collect() -> (memory: MemoryInfo, swap: SwapInfo, pressure: MemoryPressure, pageSize: Int) {
        var memory = MemoryInfo()
        var swap = SwapInfo()
        var pressure = MemoryPressure.green
        var pageSize = 4096

        // Page size
        pageSize = Int(getpagesize())

        // Total physical memory
        if let total = sysctlUint64("hw.memsize") {
            memory.total = total
        }

        // Get vm_statistics
        var vmStat = vm_statistics_data_t()
        var count: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size)
        let host = mach_host_self()

        var result: kern_return_t = KERN_FAILURE
        withUnsafeMutablePointer(to: &vmStat) { ptr in
            result = host_statistics(host, HOST_VM_INFO,
                                     ptr.withMemoryRebound(to: natural_t.self, capacity: 1) { $0 },
                                     &count)
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(getpagesize())

            // Access vm_statistics_data_t fields by name (correct macOS layout)
            memory.free       = UInt64(vmStat.free_count) * pageSize
            memory.active     = UInt64(vmStat.active_count) * pageSize
            memory.inactive   = UInt64(vmStat.inactive_count) * pageSize
            memory.speculative = UInt64(vmStat.speculative_count) * pageSize
            memory.wired      = UInt64(vmStat.wire_count) * pageSize
            // macOS vm_statistics does not expose pageable/purgeable/external
            memory.pageable   = 0
            memory.purgeable  = 0
            memory.external   = 0

            // Used = total - (free * pageSize)
            memory.used = memory.total > memory.free ? memory.total - memory.free : 0
        }

        // Swap usage via sysctl (vm.swapusage returns struct xsw_usage)
        var swapInfo = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapInfo, &swapSize, nil, 0) == 0 {
            swap.total = UInt64(swapInfo.xsu_total)
            swap.used = UInt64(swapInfo.xsu_used)
            swap.free = UInt64(swapInfo.xsu_avail)
        }

        // Memory pressure via sysctl
        if let pressureLevel = sysctlInt32("vm.memory_pressure") {
            switch pressureLevel {
            case 0: pressure = .green
            case 1: pressure = .yellow
            case 2: pressure = .red
            default: pressure = .green
            }
        }

        return (memory, swap, pressure, pageSize)
    }

    /// Print formatted memory report to console
    static func printReport() {
        let (memory, swap, pressure, pageSize) = collect()

        let separator = String(repeating: "═", count: 60)
        let thinSeparator = String(repeating: "─", count: 60)

        print("")
        print(separator)
        print("  Memory Usage Report")
        print(separator)

        print("")
        print("  \(thinSeparator)")
        print("  Physical Memory")
        print("  \(thinSeparator)")
        print("    Total:        \(formatBytes(memory.total))")
        print("    Used:         \(formatBytes(memory.used)) (\(String(format: "%.1f", memory.usagePercent))%)")
        print("    Free:         \(formatBytes(memory.free))")
        print("    Active:       \(formatBytes(memory.active))")
        print("    Inactive:     \(formatBytes(memory.inactive))")
        print("    Wired:        \(formatBytes(memory.wired))")
        print("    External:     \(formatBytes(memory.external))")
        print("    Speculative:  \(formatBytes(memory.speculative))")
        print("    Pageable:     \(formatBytes(memory.pageable))")

        print("")
        print("  \(thinSeparator)")
        print("  Swap Memory")
        print("  \(thinSeparator)")
        print("    Total:    \(formatBytes(swap.total))")
        print("    Used:     \(formatBytes(swap.used)) (\(String(format: "%.1f", swap.usagePercent))%)")
        print("    Free:     \(formatBytes(swap.free))")

        print("")
        print("  \(thinSeparator)")
        print("  Memory Pressure")
        print("  \(thinSeparator)")
        print("    Status:   \(pressure.description)")

        print("")
        print("  \(thinSeparator)")
        print("  System")
        print("  \(thinSeparator)")
        print("    Page Size: \(pageSize) bytes (\(formatBytes(UInt64(pageSize))))")

        let now = Date.now
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let dateStr = formatter.string(from: now)

        print("")
        print("  \(separator)")
        print("  \(dateStr)")
        print("\(separator)")
        print("")
    }
}
