import AppKit
import Foundation
import MemoryMonitorLib

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

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)

        statusItem.menu = menu

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
            let pressureLabel: String
            switch pressure {
            case .green:   pressureLabel = "Normal"
            case .yellow:  pressureLabel = "Warning"
            case .red:     pressureLabel = "Critical"
            }
            let usageText = String(format: "%.1f%% used (%.1f%% free)", memory.usagePercent, freePercent)
            if let item = menu.item(at: 0) {
                item.title = usageText
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        // Prevent the timer from being deallocated when main() returns
        _ = timer

        // Run the event loop
        NSApp.run()
    }
}
