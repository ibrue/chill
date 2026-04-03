import Foundation

/// Main daemon class that sets up XPC listener and manages SMC control
class ChillHelperDaemon: NSObject {
    private let smc = SMCBridgeHelper()
    private var listener: NSXPCListener?
    private var currentFan0Mode: Bool = false  // true = manual, false = auto
    private var currentFan0Target: Float = 4000
    private var currentFan1Mode: Bool = false
    private var currentFan1Target: Float = 4000
    private var maintainTimer: Timer?

    func start() {
        print("[ChillHelper] Starting daemon...")

        // Create XPC listener
        listener = NSXPCListener(machServiceName: ChillConstants.helperMachServiceName)
        listener?.delegate = self

        // Start listening
        listener?.resume()

        print("[ChillHelper] XPC listener started on \(ChillConstants.helperMachServiceName)")

        // Unlock SMC and start maintain loop
        smc.unlock()
        startMaintainLoop()

        // Monitor for sleep/wake using Darwin notifications
        setupSleepWakeNotifications()
    }

    // MARK: - Sleep/Wake Handling

    private func setupSleepWakeNotifications() {
        // Use Darwin notification center — works in command-line daemons without AppKit
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        // com.apple.system.loginwindow.logoutNoReturn fires on sleep
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let observer else { return }
                let daemon = Unmanaged<ChillHelperDaemon>.fromOpaque(observer).takeUnretainedValue()
                daemon.systemDidSleep()
            },
            "com.apple.powermanagement.systempowerstate" as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func systemDidSleep() {
        print("[ChillHelper] System power state changed — re-establishing control")
        // After any power state change, wait briefly then re-establish
        maintainTimer?.invalidate()
        maintainTimer = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.smc.unlock()
            self?.startMaintainLoop()
        }
    }

    // MARK: - Maintain Loop

    /// Timer that re-asserts Ftst=1 every 150ms
    /// Also re-writes current target RPMs to keep control
    private func startMaintainLoop() {
        maintainTimer?.invalidate()
        maintainTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.maintain()
        }
    }

    private func maintain() {
        // Re-assert unlock
        smc.unlock()

        // Re-apply current targets
        if currentFan0Mode {
            _ = smc.setManualMode(fanIndex: 0, targetRPM: currentFan0Target)
        }

        if currentFan1Mode {
            _ = smc.setManualMode(fanIndex: 1, targetRPM: currentFan1Target)
        }
    }

    // MARK: - Fan Control Methods

    func setFanMode(manual: Bool, fanIndex: Int, targetRPM: Float, reply: @escaping (Bool) -> Void) {
        print("[ChillHelper] setFanMode: fan\(fanIndex) manual=\(manual) rpm=\(targetRPM)")

        if manual {
            let success = smc.setManualMode(fanIndex: fanIndex, targetRPM: targetRPM)
            if success {
                if fanIndex == 0 {
                    currentFan0Mode = true
                    currentFan0Target = targetRPM
                } else {
                    currentFan1Mode = true
                    currentFan1Target = targetRPM
                }
            }
            reply(success)
        } else {
            reply(false)
        }
    }

    func setAutoMode(reply: @escaping (Bool) -> Void) {
        print("[ChillHelper] setAutoMode")

        let success = smc.setAutoMode()
        if success {
            currentFan0Mode = false
            currentFan1Mode = false
        }

        reply(success)
    }

    func readSensors(reply: @escaping ([String: Float]) -> Void) {
        var readings: [String: Float] = [:]

        // Read temperature sensors
        for key in SMCKey.temperatureSensors {
            if let value = smc.readFloat(key: key) {
                readings[key] = value
            }
        }

        // Read fan RPMs
        if let fan0 = smc.readFloat(key: SMCKey.fanActual0) {
            readings[SMCKey.fanActual0] = fan0
        }
        if let fan1 = smc.readFloat(key: SMCKey.fanActual1) {
            readings[SMCKey.fanActual1] = fan1
        }

        reply(readings)
    }

    func getStatus(reply: @escaping (Bool, Float, Float) -> Void) {
        let fan0RPM = smc.readFloat(key: SMCKey.fanActual0) ?? 0
        let fan1RPM = smc.readFloat(key: SMCKey.fanActual1) ?? 0
        reply(currentFan0Mode || currentFan1Mode, fan0RPM, fan1RPM)
    }
}

// MARK: - XPC Listener Delegate

extension ChillHelperDaemon: NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        print("[ChillHelper] New XPC connection from \(newConnection.processIdentifier)")

        newConnection.exportedInterface = NSXPCInterface(with: ChillXPCProtocol.self)
        newConnection.exportedObject = ChillHelperXPCHandler(daemon: self)

        newConnection.resume()
        return true
    }
}

// MARK: - XPC Protocol Handler

class ChillHelperXPCHandler: NSObject, ChillXPCProtocol {
    private let daemon: ChillHelperDaemon

    init(daemon: ChillHelperDaemon) {
        self.daemon = daemon
    }

    func setFanMode(manual: Bool, fanIndex: Int, targetRPM: Float, reply: @escaping (Bool) -> Void) {
        daemon.setFanMode(manual: manual, fanIndex: fanIndex, targetRPM: targetRPM, reply: reply)
    }

    func setAutoMode(reply: @escaping (Bool) -> Void) {
        daemon.setAutoMode(reply: reply)
    }

    func readSensors(reply: @escaping ([String: Float]) -> Void) {
        daemon.readSensors(reply: reply)
    }

    func getStatus(reply: @escaping (Bool, Float, Float) -> Void) {
        daemon.getStatus(reply: reply)
    }
}
