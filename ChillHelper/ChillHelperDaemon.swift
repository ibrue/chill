import Foundation

/// Main daemon class that sets up the XPC listener and manages SMC fan control.
///
/// Concurrency model: every method that touches SMC state or the fan-mode flags
/// runs on a single serial queue (`controlQueue`). XPC handlers, the 150ms
/// maintain loop (a DispatchSourceTimer on that queue), the sleep/wake handler,
/// and the termination signal handlers all hop onto it. That makes the whole
/// fan-control state machine race-free without any locks, and guarantees the
/// maintain timer actually fires (a run-loop Timer started from an XPC delivery
/// thread would not).
///
/// Ftst policy: the Ftst suppression flag is held ONLY while a fan is actually
/// in manual mode. Holding it in Auto would suppress macOS's own thermal control
/// and leave the fans stuck off, since nothing else commands them.
class ChillHelperDaemon: NSObject {
    private let smc = SMCBridgeHelper()
    private let controlQueue = DispatchQueue(label: "com.chill.helper.control")
    private var listener: NSXPCListener?

    private var currentFan0Mode: Bool = false  // true = manual
    private var currentFan0Target: Float = 4000
    private var currentFan1Mode: Bool = false
    private var currentFan1Target: Float = 4000

    private var selectedTemperatureSources: [String: String] = [:]
    private var temperatureMissCounts: [String: Int] = [:]

    private var maintainTimer: DispatchSourceTimer?
    private var connectedClients: Int = 0
    private var terminationSources: [DispatchSourceSignal] = []

    /// True while any fan is under manual control. All access is on controlQueue.
    private var needsControl: Bool { currentFan0Mode || currentFan1Mode }
    private var shouldHoldUnlock: Bool { needsControl }

    func start() {
        print("[ChillHelper] Starting daemon...")
        // Clear any leftover manual/suppression state from a previous run (or a
        // crashed helper, or an interrupted diagnostic) so the fans are under
        // normal macOS control until a client explicitly takes over.
        controlQueue.sync { _ = self.smc.setAutoMode() }
        setupTerminationHandler()
        listener = NSXPCListener(machServiceName: ChillConstants.helperMachServiceName)
        listener?.delegate = self
        listener?.resume()
        print("[ChillHelper] XPC listener started on \(ChillConstants.helperMachServiceName)")
        setupSleepWakeNotifications()
    }

    /// Restore automatic fan control when the daemon is told to quit (e.g.
    /// `launchctl bootout` during an upgrade sends SIGTERM). Without this, a
    /// helper killed mid-control would leave Ftst=1 / a fan pinned and the fans
    /// stuck. Runs on controlQueue so it serializes against the maintain loop and
    /// is safe to call into SMC/IOKit.
    private func setupTerminationHandler() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: controlQueue)
            source.setEventHandler { [weak self] in
                print("[ChillHelper] Caught termination signal; restoring automatic fan control")
                _ = self?.smc.setAutoMode()
                exit(0)
            }
            source.resume()
            terminationSources.append(source)
        }
    }

    // MARK: - Connection bookkeeping

    func clientConnected() {
        controlQueue.async {
            self.connectedClients += 1
            print("[ChillHelper] Client connected (active=\(self.connectedClients))")
            // Do NOT unlock or start the maintain loop here. We only suppress
            // macOS's thermal control once a manual fan command actually arrives;
            // until then the system manages the fans normally (see setFanMode).
        }
    }

    func clientDisconnected() {
        controlQueue.async {
            self.connectedClients = max(0, self.connectedClients - 1)
            print("[ChillHelper] Client disconnected (active=\(self.connectedClients))")
            guard self.connectedClients == 0 else { return }
            if self.needsControl {
                print("[ChillHelper] No clients remain - returning fans to auto")
            }
            self.currentFan0Mode = false
            self.currentFan1Mode = false
            _ = self.smc.setAutoMode()
            self.stopMaintainLoop()
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
        controlQueue.async {
            guard self.shouldHoldUnlock else { return }
            print("[ChillHelper] Power state changed - re-establishing control")
            self.stopMaintainLoop()
            self.controlQueue.asyncAfter(deadline: .now() + 2.0) {
                guard self.shouldHoldUnlock else { return }
                _ = self.smc.unlock()
                self.startMaintainLoop()
            }
        }
    }

    // MARK: - Maintain Loop (always on controlQueue)

    private func startMaintainLoop() {
        guard maintainTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: controlQueue)
        timer.schedule(deadline: .now() + 0.15, repeating: 0.15)
        timer.setEventHandler { [weak self] in self?.maintain() }
        timer.resume()
        maintainTimer = timer
    }

    private func stopMaintainLoop() {
        maintainTimer?.cancel()
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

    // MARK: - Fan Control Methods (XPC entry points, serialized on controlQueue)

    func setFanMode(manual: Bool, fanIndex: Int, targetRPM: Float, reply: @escaping (Bool) -> Void) {
        controlQueue.async {
            if manual {
                // Entering manual control for the first time: take the unlock and
                // start holding/re-asserting it. (No-op on later ticks.)
                if !self.needsControl {
                    _ = self.smc.unlock()
                    self.startMaintainLoop()
                }
                let success = self.smc.setManualMode(fanIndex: fanIndex, targetRPM: targetRPM)
                if success {
                    if fanIndex == 0 {
                        self.currentFan0Mode = true
                        self.currentFan0Target = targetRPM
                    } else {
                        self.currentFan1Mode = true
                        self.currentFan1Target = targetRPM
                    }
                }
                reply(success)
                return
            }

            // Switching this fan back to auto.
            if fanIndex == 0 { self.currentFan0Mode = false }
            if fanIndex == 1 { self.currentFan1Mode = false }

            let success: Bool
            if self.needsControl {
                // Another fan is still manual, so Ftst stays held by the loop;
                // just drop this one fan to auto.
                success = self.smc.setAutoMode(fanIndex: fanIndex)
            } else {
                // Last override gone: full robust restore (ensures Ftst=1 before
                // the F*Md=0 writes, then releases Ftst) and stop the loop.
                success = self.smc.setAutoMode()
                self.stopMaintainLoop()
            }
            reply(success)
        }
    }

    func setAutoMode(reply: @escaping (Bool) -> Void) {
        controlQueue.async {
            print("[ChillHelper] setAutoMode")
            // Return both fans to auto and fully release so macOS resumes normal
            // fan control. smc.setAutoMode() unlocks first (F*Md=0 needs Ftst=1),
            // sets both fans to auto, then clears Ftst with retries.
            self.currentFan0Mode = false
            self.currentFan1Mode = false
            let ok = self.smc.setAutoMode()
            self.stopMaintainLoop()
            reply(ok)
        }
    }

    func readSensors(reply: @escaping ([String: Float]) -> Void) {
        controlQueue.async {
            var readings: [String: Float] = [:]
            for sensor in SMCKey.temperatureSensors {
                if let value = self.readTemperature(sensor) {
                    readings[sensor.primary] = value
                }
            }
            if let fan0 = self.smc.readFloat(key: SMCKey.fanActual0) {
                readings[SMCKey.fanActual0] = fan0
            }
            if let fan1 = self.smc.readFloat(key: SMCKey.fanActual1) {
                readings[SMCKey.fanActual1] = fan1
            }
            // Report the fan count (FNum) so the app can adapt to the model: 0 on a
            // fanless MacBook Air, 1 on a Mac mini / 13" MacBook Pro, 2 on a 14"/16".
            if let fanCount = self.smc.readUInt8(key: SMCKey.fanCount) {
                readings[SMCKey.fanCount] = Float(fanCount)
            }
            if let watts = self.smc.readFloat(key: SMCKey.systemWatts), watts > 0 {
                readings[SMCKey.systemWatts] = watts
            }
            reply(readings)
        }
    }

    private func readTemperature(_ sensor: (primary: String, fallback: String?)) -> Float? {
        if sensor.primary == SMCKey.cpuComplex, sensor.fallback == SMCKey.cpuComplexAlt {
            return readAveragedCPUTemperature(sensor)
        }

        if let selectedKey = selectedTemperatureSources[sensor.primary] {
            if let value = smc.readFloat(key: selectedKey), isPlausibleTemperature(value, for: selectedKey) {
                temperatureMissCounts[sensor.primary] = 0
                return value
            }

            let misses = (temperatureMissCounts[sensor.primary] ?? 0) + 1
            temperatureMissCounts[sensor.primary] = misses
            if misses < 3 {
                return nil
            }
        }

        for key in temperatureCandidates(for: sensor) {
            if let value = smc.readFloat(key: key), isPlausibleTemperature(value, for: key) {
                if selectedTemperatureSources[sensor.primary] != key {
                    print("[ChillHelper] \(SMCKey.displayName(for: sensor.primary)) sensor source: \(key)")
                }
                selectedTemperatureSources[sensor.primary] = key
                temperatureMissCounts[sensor.primary] = 0
                return value
            }
        }

        return nil
    }

    private func readAveragedCPUTemperature(_ sensor: (primary: String, fallback: String?)) -> Float? {
        // Sample every available CPU core sensor and report the hottest core.
        // A single core sensor swings ~40C(idle)<->~60C(active) as the core
        // sleeps and wakes, which is the random jumping users see. The cluster
        // max is stable and is the thermally meaningful value for fan control.
        var hottest: Float = 0
        for key in SMCKey.cpuCoreSensors {
            if let value = smc.readFloat(key: key), isPlausibleTemperature(value, for: key) {
                hottest = max(hottest, value)
            }
        }
        if hottest > 0 {
            if selectedTemperatureSources[sensor.primary] != "cluster-max" {
                print("[ChillHelper] CPU sensor source: hottest of \(SMCKey.cpuCoreSensors.count) core sensors")
            }
            selectedTemperatureSources[sensor.primary] = "cluster-max"
            temperatureMissCounts[sensor.primary] = 0
            return hottest
        }

        // Fall back to the primary/fallback single sensors if no core sensor
        // responded on this Mac.
        let single = plausibleTemperature(for: sensor.primary)
            ?? (sensor.fallback.flatMap { plausibleTemperature(for: $0) })
        guard let single else {
            temperatureMissCounts[sensor.primary] = (temperatureMissCounts[sensor.primary] ?? 0) + 1
            return nil
        }
        selectedTemperatureSources[sensor.primary] = "single"
        return single
    }

    private func plausibleTemperature(for key: String) -> Float? {
        guard let value = smc.readFloat(key: key), isPlausibleTemperature(value, for: key) else {
            return nil
        }
        return value
    }

    private func temperatureCandidates(for sensor: (primary: String, fallback: String?)) -> [String] {
        if let fallback = sensor.fallback {
            return [sensor.primary, fallback]
        }
        return [sensor.primary]
    }

    private func isPlausibleTemperature(_ value: Float, for key: String) -> Bool {
        guard value.isFinite else { return false }
        if key == SMCKey.ambientTemp {
            return (-20...80).contains(value)
        }
        return (10...125).contains(value)
    }

    func getStatus(reply: @escaping (Bool, Float, Float) -> Void) {
        controlQueue.async {
            let fan0RPM = self.smc.readFloat(key: SMCKey.fanActual0) ?? 0
            let fan1RPM = self.smc.readFloat(key: SMCKey.fanActual1) ?? 0
            reply(self.needsControl, fan0RPM, fan1RPM)
        }
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
            self?.clientDisconnected()
        }
        newConnection.interruptionHandler = { [weak self] in
            self?.clientDisconnected()
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
