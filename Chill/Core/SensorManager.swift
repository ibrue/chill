import Foundation
import Observation
import UserNotifications

/// Manages real-time SMC sensor readings
/// No root required for reads on Apple Silicon
@Observable
final class SensorManager {
    private let smc = globalSMCBridge
    private var timer: Timer?

    // MARK: - Resolved Keys (detected at startup for this Mac model)

    private var cpuKey: String = SMCKey.cpuComplex
    private var gpuKey: String = SMCKey.gpuDie
    private var kbdKey: String = SMCKey.keyboardTemp

    // MARK: - Published Values

    var fan0RPM: Float = 0
    var fan1RPM: Float = 0
    var keyboardTemp: Float = 0
    var cpuTemp: Float = 0
    var gpuTemp: Float = 0
    var batteryTemp: Float = 0
    var fanCount: Int = 1
    var isThrottling: Bool = false
    private var lastThrottleNotification: Date = .distantPast

    // MARK: - History (rolling 60 samples = ~2 min at 2s interval)

    private static let maxHistoryCount = 60
    private var nextHistoryID = 0

    var fan0History: [TimestampedValue] = []
    var fan1History: [TimestampedValue] = []
    var cpuTempHistory: [TimestampedValue] = []

    // MARK: - Lifecycle

    init() {
        // Discover available sensors on this Mac
        smc.discoverSensors()

        // Resolve which keys work on this Mac
        resolveSensorKeys()

        // Read fan count once at startup
        if let count = smc.readUInt8(key: SMCKey.fanCount) {
            fanCount = Int(count)
        }
        print("[Sensors] Fan count: \(fanCount), CPU=\(cpuKey), GPU=\(gpuKey), Kbd=\(kbdKey)")

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Start polling
        startPolling()
    }

    deinit {
        stopPolling()
    }

    // MARK: - Key Resolution

    private func resolveSensorKeys() {
        // CPU: try primary key, then alternates
        if let found = smc.findWorkingKey(from: [
            SMCKey.cpuComplex, SMCKey.cpuComplexAlt,
            "Tp09", "Tp01", "Tp0T", "TC0D", "TC0P"
        ]) {
            cpuKey = found.key
        }

        // GPU: try primary key, then alternates
        if let found = smc.findWorkingKey(from: [
            SMCKey.gpuDie, SMCKey.gpuDieAlt,
            "TG0P", "Tg0D"
        ]) {
            gpuKey = found.key
        }

        // Keyboard/palm rest: try primary key, then alternates
        if let found = smc.findWorkingKey(from: [
            SMCKey.keyboardTemp, SMCKey.keyboardTempAlt,
            "Ts1P", "Ts1S"
        ]) {
            kbdKey = found.key
        }
    }

    // MARK: - Polling

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateReadings()
        }
        updateReadings()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func sendThrottleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Thermal Throttling Detected"
        content.body = String(format: "CPU temperature is %.0f\u{00B0}C. Consider switching to Performance profile for maximum cooling.", cpuTemp)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "thermal-throttle", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func updateReadings() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let f0 = self.smc.readFloat(key: SMCKey.fanActual0)
            let f1 = self.smc.readFloat(key: SMCKey.fanActual1)
            let kbd = self.smc.readFloat(key: self.kbdKey)
            let cpu = self.smc.readFloat(key: self.cpuKey)
            let gpu = self.smc.readFloat(key: self.gpuKey)
            let bat = self.smc.readFloat(key: SMCKey.batteryTemp)

            if self.nextHistoryID == 0 {
                print("[Sensors] cpu(\(self.cpuKey))=\(cpu as Any) gpu(\(self.gpuKey))=\(gpu as Any) kbd(\(self.kbdKey))=\(kbd as Any) bat=\(bat as Any)")
            }

            DispatchQueue.main.async {
                // Exponential moving average to smooth jittery readings
                let a: Float = 0.4  // smoothing factor (lower = smoother)
                if let v = f0 { self.fan0RPM = self.fan0RPM == 0 ? v : self.fan0RPM * (1 - a) + v * a }
                if let v = f1 { self.fan1RPM = self.fan1RPM == 0 ? v : self.fan1RPM * (1 - a) + v * a }
                if let v = kbd { self.keyboardTemp = self.keyboardTemp == 0 ? v : self.keyboardTemp * (1 - a) + v * a }
                if let v = cpu { self.cpuTemp = self.cpuTemp == 0 ? v : self.cpuTemp * (1 - a) + v * a }
                if let v = gpu { self.gpuTemp = self.gpuTemp == 0 ? v : self.gpuTemp * (1 - a) + v * a }
                if let v = bat { self.batteryTemp = v }  // battery temp is stable, no smoothing needed

                let wasThrottling = self.isThrottling
                self.isThrottling = self.cpuTemp > 95

                // Send throttle notification (at most once per 5 minutes)
                if self.isThrottling && !wasThrottling {
                    let now = Date()
                    if now.timeIntervalSince(self.lastThrottleNotification) > 300 {
                        self.lastThrottleNotification = now
                        self.sendThrottleNotification()
                    }
                }

                let now = Date()
                let id = self.nextHistoryID
                self.nextHistoryID += 1

                self.fan0History.append(TimestampedValue(id: id, date: now, value: self.fan0RPM))
                self.fan1History.append(TimestampedValue(id: id, date: now, value: self.fan1RPM))
                self.cpuTempHistory.append(TimestampedValue(id: id, date: now, value: self.cpuTemp))

                let max = Self.maxHistoryCount
                if self.fan0History.count > max { self.fan0History.removeFirst() }
                if self.fan1History.count > max { self.fan1History.removeFirst() }
                if self.cpuTempHistory.count > max { self.cpuTempHistory.removeFirst() }
            }
        }
    }
}
