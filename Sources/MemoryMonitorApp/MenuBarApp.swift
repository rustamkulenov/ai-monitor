import AppKit
import SwiftUI
import Foundation
import MemoryMonitorLib

private final class LLMStatusMenuItem {
    let reporter: any LLMStatusReporter
    let item: NSMenuItem
    private var isChecking = false

    init(reporter: any LLMStatusReporter) {
        self.reporter = reporter
        self.item = NSMenuItem(title: "\(reporter.name): Checking…", action: nil, keyEquivalent: "")
        self.item.isEnabled = false
    }

    func refresh() {
        guard !isChecking else { return }
        isChecking = true

        Task { @MainActor in
            let status = await reporter.checkStatus()
            item.title = "\(status.label) \(reporter.name)"
            isChecking = false
        }
    }
}

private final class MemoryUsageView: NSView {

    private let history = MemoryHistory(capacity: 20)

    private var pressure: MemoryPressure = .green
    private var wiredPercent: Double = 0
    private var usagePercent: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(wiredPercent: Double, memoryUsage: Double, pressure: MemoryPressure) {
        self.wiredPercent = wiredPercent
        self.usagePercent = memoryUsage
        self.pressure = pressure
        history.append(wiredPercent)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.systemFont(ofSize: 11)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font,
        ]

        let wiredLine = String(format: "%.1f%% Wired Memory", wiredPercent)
        let usageLine = String(format: "%.1f%% Usage", usagePercent)
        let fullText = "\(wiredLine)\n\(usageLine)"

        let textRect = NSRect(x: 16, y: 2, width: bounds.width - 16 - 48 - 16, height: bounds.height - 4)
        fullText.draw(in: textRect, withAttributes: textAttributes)

        let chart = SparklineChart(
            data: history.readings(),
            width: 48,
            height: 24,
            lineWidth: 1.2,
            colorScheme: chartColorScheme
        )
        let chartImage = chart.image
        let chartX = bounds.width - chartImage.size.width - 16
        let chartY = (bounds.height - chartImage.size.height) / 2
        chartImage.draw(in: NSRect(x: chartX, y: chartY, width: chartImage.size.width, height: chartImage.size.height))
    }

    private var chartColorScheme: SparklineChart.ColorScheme {
        switch pressure {
        case .green:  return .green
        case .yellow: return .yellow
        case .red:    return .red
        }
    }
}

enum MenuBarApp {

    static func main() {
        let _ = NSApplication.shared

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.title = "Memory Monitor"

        let memoryView = MemoryUsageView(frame: NSRect(x: 0, y: 0, width: 140, height: 36))
        let memoryMenuItem = NSMenuItem()
        memoryMenuItem.view = memoryView
        menu.addItem(memoryMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem.separator())
        let llmHeader = NSMenuItem(title: "Local LLM Services", action: nil, keyEquivalent: "")
        llmHeader.isEnabled = false
        menu.addItem(llmHeader)

        let reporters: [any LLMStatusReporter] = [
            OllamaStatusReporter(),
            LMStudioStatusReporter(),
        ]
        let llmStatusItems = reporters.map { LLMStatusMenuItem(reporter: $0) }
        for llmStatusItem in llmStatusItems {
            menu.addItem(llmStatusItem.item)
        }

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)

        statusItem.menu = menu

        for llmStatusItem in llmStatusItems {
            llmStatusItem.refresh()
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let sample = MemoryMonitor.collect()
            let (memory, _, pressure, _, _, _) = sample
            let pressureSymbol: String
            switch pressure {
            case .green:   pressureSymbol = "●"
            case .yellow:  pressureSymbol = "▲"
            case .red:     pressureSymbol = "⚠"
            }

            let displayText = String(format: "%d%% %@", Int(memory.wiredPercent), pressureSymbol)
            statusItem.button?.title = displayText

            memoryView.update(wiredPercent: memory.wiredPercent, memoryUsage: memory.usagePercent, pressure: pressure)

            for llmStatusItem in llmStatusItems {
                llmStatusItem.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        _ = timer

        NSApp.run()
    }
}


