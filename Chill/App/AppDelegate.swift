import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var statusUpdateTimer: Timer?

    // Core objects owned by AppDelegate - injected into SwiftUI environment
    let settingsStore = ChillSettingsStore()
    let sensorManager = SensorManager()
    let fanController = FanController()
    let profileEngine = ProfileEngine()
    let powerMonitor = PowerMonitor()
    let updateController = UpdateController()
    private(set) lazy var appMonitor = AppMonitor(
        settingsStore: settingsStore,
        profileEngine: profileEngine
    )
    private(set) lazy var profileApplier = ProfileApplier(
        sensorManager: sensorManager,
        profileEngine: profileEngine,
        fanController: fanController
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPopover()
        _ = appMonitor

        // Wire sensor reads through the helper, and start the profile->fan loop.
        sensorManager.attach(fanController: fanController)
        profileApplier.start()
        startStatusUpdates()

        if !settingsStore.hasCompletedOnboarding {
            showOnboardingWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusUpdateTimer?.invalidate()
        // Release fan control on quit so the helper doesn't pin manual mode.
        profileApplier.stop()
        let group = DispatchGroup()
        group.enter()
        fanController.setAutoMode { _ in group.leave() }
        _ = group.wait(timeout: .now() + 1.0)
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "thermometer.snowflake", accessibilityDescription: "Chill")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateStatusItem()
    }

    private func setupPopover() {
        let popoverView = PopoverView(onOpenSettings: { [weak self] in
            self?.showSettingsWindow()
        })
            .environment(settingsStore)
            .environment(sensorManager)
            .environment(fanController)
            .environment(profileEngine)
            .environment(powerMonitor)
            .environment(updateController)

        popover = NSPopover()
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: popoverView)
        popover?.contentSize = NSSize(width: 320, height: 480)
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            closePopover(sender)
        } else {
            NSApplication.shared.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitoring()
        }
    }

    @objc private func showSettingsWindow() {
        closePopover(nil)
        NSApplication.shared.activate()

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
            .environment(settingsStore)
            .environment(sensorManager)
            .environment(fanController)
            .environment(profileEngine)
            .environment(powerMonitor)
            .environment(appMonitor)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Chill Settings"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: settingsView)
        window.center()
        window.delegate = self
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Onboarding

    private func showOnboardingWindow() {
        if let onboardingWindow {
            NSApplication.shared.activate()
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let onboardingView = OnboardingView(onFinish: { [weak self] in
            self?.completeOnboarding()
        })
            .environment(sensorManager)
            .environment(settingsStore)
            .environment(profileEngine)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.center()
        window.delegate = self
        onboardingWindow = window

        // An .accessory (menu-bar-only) app can't bring a real window to the
        // front; switch to .regular for the walkthrough and revert on close.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func completeOnboarding() {
        settingsStore.hasCompletedOnboarding = true
        onboardingWindow?.close() // windowWillClose reverts the activation policy
        // Point the user at the menu bar by popping the popover open.
        DispatchQueue.main.async { [weak self] in
            self?.togglePopover(nil)
        }
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
        stopEventMonitoring()
    }

    private func startEventMonitoring() {
        stopEventMonitoring()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let popover = self.popover, popover.isShown else { return event }

            if event.window == popover.contentViewController?.view.window ||
                event.window == self.statusItem?.button?.window {
                return event
            }

            self.closePopover(event)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover?.isShown == true else { return }
            DispatchQueue.main.async { [weak self] in
                self?.closePopover(event)
            }
        }
    }

    private func stopEventMonitoring() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopEventMonitoring()
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        if closing === settingsWindow {
            settingsWindow = nil
        }
        if closing === onboardingWindow {
            // Closing the walkthrough (via Get Started or the close button)
            // counts as done; revert to menu-bar-only mode.
            settingsStore.hasCompletedOnboarding = true
            onboardingWindow = nil
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    private func startStatusUpdates() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusItem()
        }
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "thermometer.snowflake", accessibilityDescription: "Chill")
        button.imagePosition = settingsStore.menuBarDisplayMode == .iconOnly ? .imageOnly : .imageLeft

        switch settingsStore.menuBarDisplayMode {
        case .iconOnly:
            button.title = ""
        case .temperature:
            button.title = sensorManager.cpuTemp > 0 ? "\(Int(sensorManager.cpuTemp.rounded()))°" : "-°"
        case .rpm:
            button.title = sensorManager.fan0RPM > 0 ? "\(Int(sensorManager.fan0RPM.rounded()))" : "-"
        case .temperatureAndRPM:
            let temp = sensorManager.cpuTemp > 0 ? "\(Int(sensorManager.cpuTemp.rounded()))°" : "-°"
            let rpm = sensorManager.fan0RPM > 0 ? "\(Int(sensorManager.fan0RPM.rounded()))" : "-"
            button.title = "\(temp) \(rpm)"
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
