import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    // Core objects owned by AppDelegate — injected into SwiftUI environment
    let sensorManager = SensorManager()
    let fanController = FanController()
    let profileEngine = ProfileEngine()
    let powerMonitor = PowerMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: Brand.menuBarSymbol, accessibilityDescription: Brand.name)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        let popoverView = PopoverView()
            .environment(sensorManager)
            .environment(fanController)
            .environment(profileEngine)
            .environment(powerMonitor)

        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: popoverView)
        popover?.contentSize = NSSize(width: 300, height: 420)
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover(nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
