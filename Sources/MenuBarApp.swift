import AppKit
import Foundation

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
            let usageText = String(format: "%.1f%% used (%.1f%% free)", memory.usagePercent, freePercent)
            if let item = menu.item(at: 0) {
                item.title = usageText
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        // Run the event loop
        NSApp.run()
    }
}
