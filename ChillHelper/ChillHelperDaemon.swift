import Foundation

/// Main daemon class that sets up XPC listener and manages SMC control.
///
/// Lifecycle:
///   - On startup: do nothing (no SMC unlock until a client appears).
///   - On first client connect: unlock and start the maintain loop so all
///     writes from the client happen with Ftst=1 already held.
///   - On last client disconnect: return both fans to auto and release.
class ChillHelperDaemon: NSObject {
    private let smc = SMCBridgeHelper()
    private var listener: NSXPCListener?

    private var currentFan0Mode: Bool = false  // true = manual
    private var currentFan0Target: Float = 4000
    private var currentFan1Mode: Bool = false
    private var currentFan1Target: Float = 4000

    private var maintainTimer: Timer?
    private var connectedClients: Int = 0

    private var needsControl: Bool { currentFan0Mode || currentFan1Mode }
    /// We keep Ftst=1 held whenever a client is attached, even if every fan
    /// is in auto. This avoids the "first write after a cold connect fails"
    /// problem (the SMC write path needs a few attempts to settle).
    private var shouldHoldUnlock: Bool { connectedClients > 0 }

    func start() {
        print("[ChillHelper] Starting daemon...")
        listener = NSXPCListener(machServiceName: ChillConstants.helperMachServiceName)
        listener?.delegate = self
        listener?.resume()
        print("[ChillHelper] XPC listener started on \(ChillConstants.helperMachServiceName)")
        setupSleepWakeNotifications()
    }

    // MARK: - Connection bookkeeping

    func clientConnected() {
        connectedClients += 1
        print("[ChillHelper] Client connected (active=\(connectedClients))")
        if connectedClients == 1 {
            _ = smc.unlock()
            startMaintainLoop()
        }
    }

    func clientDisconnected() {
        connectedClients = max(0, connectedClients - 1)
        print("[ChillHelper] Client disconnected (active=\(connectedClients))")
        if connectedClients == 0 {
            if needsControl {
                print("[ChillHelper] No clients remain — returning fans to auto")
            }
            _ = smc.setAutoMode()
            currentFan0Mode = false
            currentFan1Mode = false
            stopMaintainLoop()
        }
    }

    // MARK: - Sleep/Wake Handling

    private func setupSleepWakeNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let daemon = Unmanaged<ChillHelperDaemon>.fromOpaque(observer).takeUnretainedValue()
                daemon.systemPowerStateChanged()
            },
            "com.apple.powermanagement.systempowerstate" as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func systemPowerStateChanged() {
        guard shouldHoldUnlock else { return }
        print("[ChillHelper] Power state changed — re-establishing control")
        stopMaintainLoop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.shouldHoldUnlock else { return }
            _ = self.smc.unlock()
            self.startMaintainLoop()
        }
    }

    // MARK: - Maintain Loop

    private func startMaintainLoop() {
        if maintainTimer != nil { return }
        maintainTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.maintain()
        }
    }

    private func stopMaintainLoop() {
        maintainTimer?.invalidate()
        maintainTimer = nil
    }

    private func maintain() {
        guard shouldHoldUnlock else {
            stopMaintainLoop()
            return
        }
        smc.maintainUnlock()
        if currentFan0Mode {
            _ = smc.reapplyManual(fanIndex: 0, targetRPM: currentFan0Target)
        }
        if currentFan1Mode {
            _ = smc.reapplyManual(fanIndex: 1, targetRPM: currentFan1Target)
        }
    }

    // MARK: - Fan Control Methods (called from XPC handler)

    func setFanMode(manual: Bool, fanIndex: Int, targetRPM: Float, reply: @escaping (Bool) -> Void) {
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
            return
        }

        let success = smc.setAutoMode(fanIndex: fanIndex)
        if success {
            if fanIndex == 0 { currentFan0Mode = false }
            if fanIndex == 1 { currentFan1Mode = false }
        }
        reply(success)
    }

    func setAutoMode(reply: @escaping (Bool) -> Void) {
        print("[ChillHelper] setAutoMode")
        // Reset both fans to auto without releasing — the maintain loop keeps
        // Ftst=1 held while a client is connected so the next manual switch
        // doesn't have to cold-start the unlock.
        let s0 = smc.setAutoMode(fanIndex: 0)
        let s1 = smc.setAutoMode(fanIndex: 1)
        currentFan0Mode = false
        currentFan1Mode = false
        reply(s0 && s1)
    }

    func readSensors(reply: @escaping ([String: Float]) -> Void) {
        var readings: [String: Float] = [:]
        for sensor in SMCKey.temperatureSensors {
            if let value = smc.readFloat(key: sensor.primary), isPlausibleTemperature(value, for: sensor.primary) {
                readings[sensor.primary] = value
            } else if let alt = sensor.fallback, let value = smc.readFloat(key: alt), isPlausibleTemperature(value, for: alt) {
                // Report under the primary key so the app doesn't care which one worked.
                readings[sensor.primary] = value
            }
        }
        if let fan0 = smc.readFloat(key: SMCKey.fanActual0) {
            readings[SMCKey.fanActual0] = fan0
        }
        if let fan1 = smc.readFloat(key: SMCKey.fanActual1) {
            readings[SMCKey.fanActual1] = fan1
        }
        if let watts = smc.readFloat(key: SMCKey.systemWatts), watts > 0 {
            readings[SMCKey.systemWatts] = watts
        }
        reply(readings)
    }

    private func isPlausibleTemperature(_ value: Float, for key: String) -> Bool {
        guard value.isFinite else { return false }
        if key == SMCKey.ambientTemp {
            return (-20...80).contains(value)
        }
        return (10...125).contains(value)
    }

    func getStatus(reply: @escaping (Bool, Float, Float) -> Void) {
        let fan0RPM = smc.readFloat(key: SMCKey.fanActual0) ?? 0
        let fan1RPM = smc.readFloat(key: SMCKey.fanActual1) ?? 0
        reply(needsControl, fan0RPM, fan1RPM)
    }
}

// MARK: - XPC Listener Delegate

extension ChillHelperDaemon: NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        print("[ChillHelper] New XPC connection from pid=\(newConnection.processIdentifier)")
        newConnection.exportedInterface = NSXPCInterface(with: ChillXPCProtocol.self)
        newConnection.exportedObject = ChillHelperXPCHandler(daemon: self)
        clientConnected()
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.clientDisconnected() }
        }
        newConnection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async { self?.clientDisconnected() }
        }
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
