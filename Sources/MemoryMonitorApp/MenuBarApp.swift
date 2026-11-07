import AppKit
import Foundation
import MemoryMonitorLib

// MARK: - LLM status menu item

/// Owns one menu item and keeps its title in sync with a reporter's status.
private final class LLMStatusMenuItem {
    let reporter: any LLMStatusReporter
    let item: NSMenuItem
    private var isChecking = false

    init(reporter: any LLMStatusReporter) {
        self.reporter = reporter
        self.item = NSMenuItem(title: "\(reporter.name): Checking…", action: nil, keyEquivalent: "")
        self.item.isEnabled = false
    }

    /// Refreshes the status in the background and updates the menu item on the main thread.
    func refresh() {
        guard !isChecking else { return }
        isChecking = true

        Task { @MainActor in
            let status = await reporter.checkStatus()
            item.title = "\(reporter.name): \(status.label)"
            isChecking = false
        }
    }
}

// MARK: - MenuBarApp

enum MenuBarApp {

    static func main() {
        // Ensure AppKit is loaded
        let _ = NSApplication.shared

        // Create status item with variable length (auto-sizes to content)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Build a simple menu
        let menu = NSMenu()
        menu.title = "Memory Monitor"

        let memoryMenuItem = NSMenuItem(title: "Memory Usage", action: nil, keyEquivalent: "")
        memoryMenuItem.isEnabled = false
        menu.addItem(memoryMenuItem)

        menu.addItem(NSMenuItem.separator())

        // LLM services (local REST APIs)
        let llmHeader = NSMenuItem(title: "LLM Services", action: nil, keyEquivalent: "")
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

        // Prime the LLM statuses immediately instead of waiting for the first tick.
        for llmStatusItem in llmStatusItems {
            llmStatusItem.refresh()
        }

        // Update loop: every 2 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let (memory, _, pressure, _) = MemoryMonitor.collect()
            let freePercent = 100.0 - memory.usagePercent
            let pressureSymbol: String
            switch pressure {
            case .green:   pressureSymbol = "●"
            case .yellow:  pressureSymbol = "▲"
            case .red:     pressureSymbol = "⚠"
            }

            let displayText = String(format: "%d%% %@", Int(freePercent), pressureSymbol)
            statusItem.button?.title = displayText

            // Update menu text
            let usageText = String(format: "%.1f%% used (%.1f%% free)", memory.usagePercent, freePercent)
            if let item = menu.item(at: 0) {
                item.title = usageText
            }

            // Refresh LLM service statuses
            for llmStatusItem in llmStatusItems {
                llmStatusItem.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        // Prevent the timer from being deallocated when main() returns
        _ = timer

        // Run the event loop
        NSApp.run()
    }
}
