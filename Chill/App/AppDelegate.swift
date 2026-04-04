import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var controlTimer: Timer?
    private var eventMonitor: Any?

    // Core objects owned by AppDelegate — injected into SwiftUI environment
    let sensorManager = SensorManager()
    let fanController = FanController()
    let profileEngine = ProfileEngine()
    let appMonitor = AppMonitor()
    let powerMonitor = PowerMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPopover()
        startControlLoop()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controlTimer?.invalidate()
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        // Return to auto mode on quit
        fanController.setAutoMode { _ in }
    }

    // MARK: - Control Loop

    private func startControlLoop() {
        controlTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.applyActiveProfile()
        }
    }

    private func updateMenuBarText() {
        guard let button = statusItem?.button else { return }
        let showRPM = UserDefaults.standard.bool(forKey: "showRpmInMenuBar")
        if showRPM {
            let rpm = Int(sensorManager.fan0RPM)
            button.image = nil
            button.title = "\(rpm) RPM"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "thermometer.snowflake", accessibilityDescription: "Frostbyte")
        }
    }

    private func applyActiveProfile() {
        // Update menu bar RPM text
        updateMenuBarText()

        // Sync power mode from PowerMonitor into ProfileEngine
        profileEngine.activePowerMode = powerMonitor.currentPowerMode

        let profile = profileEngine.activeProfile

        // Auto profile = let macOS handle it
        if profile.name == "Auto" {
            if fanController.isManualMode {
                fanController.setAutoMode { success in
                    if success {
                        print("[Control] Returned to auto mode")
                    }
                }
            }
            return
        }

        // Build sensor reading snapshot
        var reading = SensorReading.fromSensorManager(sensorManager)

        // Compute target RPM using the profile curve
        let targetRPM = profileEngine.evaluate(sensors: reading, fanMax: 8000)

        // Send to helper via XPC
        fanController.setFanMode(manual: true, fanIndex: 0, targetRPM: targetRPM) { _ in }

        // Also set fan 1 if present
        if sensorManager.fanCount > 1 {
            fanController.setFanMode(manual: true, fanIndex: 1, targetRPM: targetRPM) { _ in }
        }

        fanController.activeProfileName = profile.name
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "thermometer.snowflake", accessibilityDescription: "Frostbyte")
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
        popover?.contentSize = NSSize(width: 300, height: 480)
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            closePopover()
        } else {
            sensorManager.isPopoverVisible = true
            powerMonitor.isPopoverVisible = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Monitor clicks outside the popover to dismiss it
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        sensorManager.isPopoverVisible = false
        powerMonitor.isPopoverVisible = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
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
