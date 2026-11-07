import Darwin
import Foundation

private func sysctlUint64(_ name: String) -> UInt64? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    var value: UInt64 = 0
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

public struct MemoryInfo {
    public var total: UInt64 = 0
    public var used: UInt64 = 0
    public var free: UInt64 = 0
    public var active: UInt64 = 0
    public var inactive: UInt64 = 0
    public var wired: UInt64 = 0
    public var external: UInt64 = 0
    public var speculative: UInt64 = 0
    public var pageable: UInt64 = 0
    public var purgeable: UInt64 = 0

    public var usagePercent: Double {
        total > 0 ? Double(used) / Double(total) * 100.0 : 0
    }

    public var wiredPercent: Double {
        total > 0 ? Double(wired) / Double(total) * 100.0 : 0
    }
}

public struct SwapInfo {
    public var total: UInt64 = 0
    public var used: UInt64 = 0
    public var free: UInt64 = 0

    public var usagePercent: Double {
        total > 0 ? Double(used) / Double(total) * 100.0 : 0
    }
}

public enum MemoryPressure {
    case green
    case yellow
    case red

    public var description: String {
        switch self {
        case .green: return "Green (Normal)"
        case .yellow: return "Yellow (Warning)"
        case .red: return "Red (Critical)"
        }
    }
}

public enum MemoryMonitor {

    public static func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        while size >= 1024.0 && unitIndex < units.count - 1 {
            size /= 1024.0
            unitIndex += 1
        }
        return String(format: "%.2f %@", size, units[unitIndex])
    }

    public static func collect() -> (
        memory: MemoryInfo,
        swap: SwapInfo,
        pressure: MemoryPressure,
        pageSize: Int,
        compressedMemory: UInt64,
        pressureLevel: Int32
    ) {
        var memory = MemoryInfo()
        var swap = SwapInfo()
        var pressure = MemoryPressure.green
        var pageSize = 4096
        var compressedMemory: UInt64 = 0
        var pressureLevel: Int32 = 0

        pageSize = Int(getpagesize())

        if let total = sysctlUint64("hw.memsize") {
            memory.total = total
        }

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()

        let HOST_VM64_INFO: host_flavor_t = 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM64_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(getpagesize())

            memory.free = UInt64(vmStats.free_count) * pageSize
            memory.active = UInt64(vmStats.active_count) * pageSize
            memory.inactive = UInt64(vmStats.inactive_count) * pageSize
            memory.speculative = UInt64(vmStats.speculative_count) * pageSize
            memory.wired = UInt64(vmStats.wire_count) * pageSize
            memory.purgeable = UInt64(vmStats.purgeable_count) * pageSize
            memory.pageable = 0
            memory.external = 0

            memory.used = memory.total > memory.free ? memory.total - memory.free : 0

            compressedMemory = UInt64(vmStats.compressor_page_count) * pageSize
        }

        var swapInfo = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapInfo, &swapSize, nil, 0) == 0 {
            swap.total = UInt64(swapInfo.xsu_total)
            swap.used = UInt64(swapInfo.xsu_used)
            swap.free = UInt64(swapInfo.xsu_avail)
        }

        if let pl = sysctlInt32("vm.memory_pressure") {
            pressureLevel = pl
            switch pressureLevel {
            case 0: pressure = .green
            case 1: pressure = .yellow
            case 2: pressure = .red
            default: pressure = .green
            }
        }

        return (memory, swap, pressure, pageSize, compressedMemory, pressureLevel)
    }

    public static func printReport() {
        let (memory, swap, pressure, pageSize, _, _) = collect()

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
        print(
            "    Used:         \(formatBytes(memory.used)) (\(String(format: "%.1f", memory.usagePercent))%)"
        )
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
        print(
            "    Used:     \(formatBytes(swap.used)) (\(String(format: "%.1f", swap.usagePercent))%)"
        )
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
