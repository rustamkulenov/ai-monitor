import Foundation
@testable import MemoryMonitorLib

// MARK: - Test helpers

var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
        print("  ✓ \(message)")
    } else {
        failed += 1
        print("  X \(message) at \(file):\(line)")
        exit(1)
    }
}

// MARK: - Test cases

func testCollectRunsWithoutError() {
    print("\n── testCollectRunsWithoutError ──")
    _ = MemoryMonitor.collect()
    assert(true, "collect() ran without error")
}

func testCollectReturnsValidTuple() {
    print("\n── testCollectReturnsValidTuple ──")
    let (memory, swap, _, pageSize) = MemoryMonitor.collect()

    assert(memory.total > 0,
           "Total memory is reported (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.used <= memory.total,
           "Used (\(MemoryMonitor.formatBytes(memory.used))) ≤ Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.free <= memory.total,
           "Free (\(MemoryMonitor.formatBytes(memory.free))) ≤ Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.active <= memory.total,
           "Active (\(MemoryMonitor.formatBytes(memory.active))) ≤ Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.inactive <= memory.total,
           "Inactive (\(MemoryMonitor.formatBytes(memory.inactive))) ≤ Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.wired <= memory.total,
           "Wired (\(MemoryMonitor.formatBytes(memory.wired))) ≤ Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.free + memory.used <= memory.total * 2,
           "Free + Used (\(MemoryMonitor.formatBytes(memory.free + memory.used))) within 2× Total (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(swap.total == 0 || swap.used + swap.free == swap.total,
           "Swap used + free = total (\(MemoryMonitor.formatBytes(swap.used + swap.free)))")
    assert(pageSize > 0, "Page size is positive (\(MemoryMonitor.formatBytes(UInt64(pageSize))))")
    assert([4096, 16384].contains(pageSize),
           "Page size is 4096 or 16384 (got \(MemoryMonitor.formatBytes(UInt64(pageSize))))")
}

func testMemoryUsagePercent() {
    print("\n── testMemoryUsagePercent ──")
    let (memory, _, _, _) = MemoryMonitor.collect()

    assert(memory.usagePercent > 0, "Usage percent is greater than zero (\(String(format: "%.2f", memory.usagePercent))%)")
    assert(memory.usagePercent <= 100, "Usage percent ≤ 100% (\(String(format: "%.2f", memory.usagePercent))%)")
}

func testMemoryFieldsAreReasonable() {
    print("\n── testMemoryFieldsAreReasonable ──")
    let (memory, _, _, _) = MemoryMonitor.collect()

    let twoGB: UInt64 = 2 * 1024 * 1024 * 1024
    assert(memory.total > twoGB,
           "Total memory > 2 GB (\(MemoryMonitor.formatBytes(memory.total)))")
    assert(memory.active + memory.inactive + memory.wired <= memory.total,
           "active+inactive+wired (\(MemoryMonitor.formatBytes(memory.active + memory.inactive + memory.wired))) ≤ total (\(MemoryMonitor.formatBytes(memory.total)))")
}

func testSwapInfoPopulated() {
    print("\n── testSwapInfoPopulated ──")
    let (_, swap, _, _) = MemoryMonitor.collect()

    print("  Reported swap: total \(MemoryMonitor.formatBytes(swap.total))"
        + " | used \(MemoryMonitor.formatBytes(swap.used))"
        + " | free \(MemoryMonitor.formatBytes(swap.free))"
        + " | usage \(String(format: "%.2f", swap.usagePercent))%")

    guard swap.total > 0 else {
        assert(true, "No swap configured (total = 0, OK)")
        return
    }

    assert(swap.total > 0, "Swap total is reported (\(MemoryMonitor.formatBytes(swap.total)))")
    assert(swap.used <= swap.total,
           "Swap used (\(MemoryMonitor.formatBytes(swap.used))) ≤ total (\(MemoryMonitor.formatBytes(swap.total)))")
    assert(swap.free <= swap.total,
           "Swap free (\(MemoryMonitor.formatBytes(swap.free))) ≤ total (\(MemoryMonitor.formatBytes(swap.total)))")
    assert(swap.used + swap.free == swap.total,
           "Swap accounting: used + free == total (\(MemoryMonitor.formatBytes(swap.used))"
           + " + \(MemoryMonitor.formatBytes(swap.free))"
           + " = \(MemoryMonitor.formatBytes(swap.total)))")
}

func testSwapUsagePercent() {
    print("\n── testSwapUsagePercent ──")
    let (_, swap, _, _) = MemoryMonitor.collect()

    guard swap.total > 0 else {
        assert(swap.usagePercent == 0, "Swap usage percent is 0 when total is 0")
        return
    }

    let expected = Double(swap.used) / Double(swap.total) * 100.0
    assert(swap.usagePercent >= 0, "Swap usage percent ≥ 0 (\(String(format: "%.2f", swap.usagePercent))%)")
    assert(swap.usagePercent <= 100, "Swap usage percent ≤ 100% (\(String(format: "%.2f", swap.usagePercent))%)")
    assert(abs(swap.usagePercent - expected) < 0.0001,
           "Swap usage percent matches used/total (\(String(format: "%.2f", swap.usagePercent))%"
           + " vs \(String(format: "%.2f", expected))%)")
}

func testPressureIsValidCase() {
    print("\n── testPressureIsValidCase ──")
    let (_, _, pressure, _) = MemoryMonitor.collect()

    switch pressure {
    case .green, .yellow, .red:
        assert(true, "Pressure is a valid case: \(pressure)")
    @unknown default:
        assert(false, "Unexpected pressure case")
    }
}

func testPressureDescription() {
    print("\n── testPressureDescription ──")
    assert(MemoryPressure.green.description == "Green (Normal)",
           "Green description matches")
    assert(MemoryPressure.yellow.description == "Yellow (Warning)",
           "Yellow description matches")
    assert(MemoryPressure.red.description == "Red (Critical)",
           "Red description matches")
}

func testFormatBytesBasic() {
    print("\n── testFormatBytesBasic ──")
    assert(MemoryMonitor.formatBytes(0) == "0.00 B", "0 bytes → \"0.00 B\"")
    assert(MemoryMonitor.formatBytes(1023) == "1023.00 B", "1023 bytes → \"1023.00 B\"")
    assert(MemoryMonitor.formatBytes(1024) == "1.00 KB", "1024 bytes → \"1.00 KB\"")
    assert(MemoryMonitor.formatBytes(1024 * 1024) == "1.00 MB", "1 MB → \"1.00 MB\"")
    assert(MemoryMonitor.formatBytes(1024 * 1024 * 1024) == "1.00 GB", "1 GB → \"1.00 GB\"")
    assert(MemoryMonitor.formatBytes(1024 * 1024 * 1024 * 1024) == "1.00 TB", "1 TB → \"1.00 TB\"")
}

func testFormatBytesFractional() {
    print("\n── testFormatBytesFractional ──")
    let kb = MemoryMonitor.formatBytes(1536)
    assert(kb.hasSuffix("KB"), "1536 bytes → \"\(kb)\" (ends with KB)")
    assert(kb.contains("1.50"), "1536 bytes → \"\(kb)\" (contains \"1.50\")")

    let mb = MemoryMonitor.formatBytes(1_572_864)
    assert(mb.hasSuffix("MB"), "1572864 bytes → \"\(mb)\" (ends with MB)")
}

func testFormatBytesClampsToTB() {
    print("\n── testFormatBytesClampsToTB ──")
    let huge = MemoryMonitor.formatBytes(UInt64.max)
    assert(huge.hasSuffix("TB"), "UInt64.max → \"\(huge)\" (ends with TB)")
}

func testMultipleCollectCallsConsistent() {
    print("\n── testMultipleCollectCallsConsistent ──")
    let results = (0..<5).map { _ in MemoryMonitor.collect() }

    let totals = results.map { $0.memory.total }
    let pageSizes = results.map { $0.pageSize }

    assert(totals == Array(repeating: totals[0], count: totals.count),
           "Total memory consistent across 5 calls (\(MemoryMonitor.formatBytes(totals[0])))")
    assert(pageSizes == Array(repeating: pageSizes[0], count: pageSizes.count),
           "Page size consistent across 5 calls (\(MemoryMonitor.formatBytes(UInt64(pageSizes[0]))))")
}

// MARK: - Main

print("Running MemoryMonitor tests...\n")

testCollectRunsWithoutError()
testCollectReturnsValidTuple()
testMemoryUsagePercent()
testMemoryFieldsAreReasonable()
testSwapInfoPopulated()
testSwapUsagePercent()
testPressureIsValidCase()
testPressureDescription()
testFormatBytesBasic()
testFormatBytesFractional()
testFormatBytesClampsToTB()
testMultipleCollectCallsConsistent()

print("\n═══════════════════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
if failed > 0 {
    print("Status: FAILED")
    exit(1)
} else {
    print("Status: ALL PASSED")
    exit(0)
}
