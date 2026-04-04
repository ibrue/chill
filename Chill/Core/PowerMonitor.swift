import Foundation
import Observation
import IOKit.ps

/// Monitors power state and suggests profiles
@Observable
final class PowerMonitor {
    private let smc = globalSMCBridge
    private var timer: Timer?

    var isPopoverVisible: Bool = false

    var isOnAC: Bool = false
    var batteryPercent: Int = 100
    var isCharging: Bool = false
    var estimatedWatts: Float = 0
    var suggestedProfileOverride: String?
    var currentPowerMode: PowerMode = .balanced

    // MARK: - History (rolling 60 samples = ~5 min at 5s interval)

    private static let maxHistoryCount = 60
    private var nextHistoryID = 0

    var wattsHistory: [TimestampedValue] = []

    // MARK: - Lifecycle

    init() {
        startPolling()
    }

    deinit {
        stopPolling()
    }

    // MARK: - Polling

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePowerStatus()
        }
        // Initial update
        updatePowerStatus()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePowerStatus() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Read system power draw from SMC (no root needed for reads)
            let watts = self.smc.readFloat(key: SMCKey.systemWatts) ?? 0

            // IOPSCopyPowerSourcesInfo returns Unmanaged<CFTypeRef>
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
                return
            }

            guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
                return
            }

            var onAC = false
            var percent = 100
            var charging = false

            for source in sources {
                guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }

                if let powerType = info[kIOPSTransportTypeKey as String] as? String,
                   powerType == kIOPSInternalType as String {
                    // Internal battery source
                    if let currentCapacity = info[kIOPSCurrentCapacityKey as String] as? Int,
                       let maxCapacity = info[kIOPSMaxCapacityKey as String] as? Int,
                       maxCapacity > 0
                    {
                        percent = (currentCapacity * 100) / maxCapacity
                    }

                    if let isChargingVal = info[kIOPSIsChargingKey as String] as? Bool {
                        charging = isChargingVal
                    }

                    if let powerSource = info[kIOPSPowerSourceStateKey as String] as? String {
                        onAC = (powerSource == kIOPSACPowerValue as String)
                    }
                }
            }

            DispatchQueue.main.async {
                self.isOnAC = onAC
                self.batteryPercent = percent
                self.isCharging = charging
                self.estimatedWatts = watts

                // Determine power mode for Adaptive profile
                if !onAC && percent < 30 {
                    self.currentPowerMode = .lowPower
                } else if onAC && watts > 15 {
                    self.currentPowerMode = .highPerformance
                } else {
                    self.currentPowerMode = .balanced
                }

                // Suggest profile based on power state
                if onAC && !charging {
                    self.suggestedProfileOverride = "Performance"
                } else if !onAC && percent < 30 {
                    self.suggestedProfileOverride = "Whisper"
                } else {
                    self.suggestedProfileOverride = nil
                }

                // Only append history when popover is visible (Charts are expensive)
                guard self.isPopoverVisible else { return }

                let id = self.nextHistoryID
                self.nextHistoryID += 1
                self.wattsHistory.append(TimestampedValue(id: id, date: Date(), value: self.estimatedWatts))
                if self.wattsHistory.count > Self.maxHistoryCount {
                    self.wattsHistory = Array(self.wattsHistory.suffix(Self.maxHistoryCount))
                }
            }
        }
    }
}
