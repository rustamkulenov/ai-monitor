import Foundation

public final class MemoryHistory {

    public let capacity: Int

    private var buffer: [Double]
    private var head: Int
    private var count: Int

    public init(capacity: Int = 20) {
        self.capacity = capacity
        self.buffer = Array(repeating: 0, count: capacity)
        self.head = 0
        self.count = 0
    }

    public func append(_ usagePercent: Double) {
        buffer[head] = usagePercent
        head = (head + 1) % capacity
        if count < capacity { count += 1 }
    }

    public func readings() -> [Double] {
        guard count > 0 else { return [] }
        let start = (head - count + capacity) % capacity
        return (0..<count).map { buffer[(start + $0) % capacity] }
    }
}
