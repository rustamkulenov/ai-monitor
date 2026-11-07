import AppKit

public struct SparklineChart {

    public enum ColorScheme {
        case green
        case yellow
        case red

        var strokeColor: NSColor {
            switch self {
            case .green:  return .systemGreen
            case .yellow: return .systemYellow
            case .red:    return .systemRed
            }
        }

        var fillColor: NSColor {
            switch self {
            case .green:  return NSColor.systemGreen.withAlphaComponent(0.15)
            case .yellow: return NSColor.systemYellow.withAlphaComponent(0.15)
            case .red:    return NSColor.systemRed.withAlphaComponent(0.15)
            }
        }
    }

    public let width: CGFloat
    public let height: CGFloat
    public let lineWidth: CGFloat
    public let padding: CGFloat

    public let colorScheme: ColorScheme

    public let data: [Double]

    public init(
        data: [Double],
        width: CGFloat = 50,
        height: CGFloat = 20,
        lineWidth: CGFloat = 1.2,
        colorScheme: ColorScheme
    ) {
        self.data = data
        self.width = width
        self.height = height
        self.lineWidth = lineWidth
        self.colorScheme = colorScheme
        self.padding = 2
    }

    public var image: NSImage {
        let size = NSSize(width: width, height: height)
        return NSImage(size: size, flipped: false) { bounds in
            self.draw(in: bounds)
            return true
        }
    }

    private func draw(in bounds: NSRect) {
        guard !data.isEmpty else { return }

        let inset = padding
        let chartWidth = bounds.width - inset * 2
        let chartHeight = bounds.height - inset * 2

        let points = data.enumerated().map { index, value in
            normalizedPoint(value, chartWidth, chartHeight, index: index, total: data.count)
        }

        if points.count > 1 {
            let fillPath = NSBezierPath()
            fillPath.move(to: CGPoint(x: inset, y: inset))
            for point in points {
                fillPath.line(to: point)
            }
            fillPath.line(to: CGPoint(x: inset + chartWidth, y: inset))
            fillPath.close()
            colorScheme.fillColor.setFill()
            fillPath.fill()
        }

        if points.count > 1 {
            let strokePath = NSBezierPath()
            strokePath.move(to: points[0])
            for point in points.dropFirst() {
                strokePath.line(to: point)
            }
            strokePath.lineWidth = lineWidth
            strokePath.lineJoinStyle = .round
            colorScheme.strokeColor.setStroke()
            strokePath.stroke()
        }

        if let lastPoint = points.last {
            let dotRadius = lineWidth * 1.5
            let dotRect = NSRect(
                x: lastPoint.x - dotRadius,
                y: lastPoint.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            colorScheme.strokeColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }

    private func normalizedPoint(
        _ value: Double,
        _ chartWidth: CGFloat,
        _ chartHeight: CGFloat,
        index: Int,
        total: Int
    ) -> CGPoint {
        let x: CGFloat = total <= 1
            ? padding + chartWidth / 2
            : CGFloat(index) / CGFloat(total - 1) * chartWidth + padding

        let clampedValue = max(0, min(100, value))
        let yRatio = clampedValue / 100
        let y = yRatio * chartHeight + padding
        return CGPoint(x: x, y: y)
    }
}
