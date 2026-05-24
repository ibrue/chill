import Foundation
import Observation
import IOKit.ps

/// Monitors power state and suggests profiles
@Observable
final class PowerMonitor {
    private var timer: Timer?

    var isOnAC: Bool = false
    var batteryPercent: Int = 100
    var isCharging: Bool = false
    var suggestedProfileOverride: String?

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

                // Suggest profile based on power state
                if onAC && !charging {
                    self.suggestedProfileOverride = "Performance"
                } else if !onAC && percent < 30 {
                    self.suggestedProfileOverride = "Auto"
                } else {
                    self.suggestedProfileOverride = nil
                }
            }
        }
    }
}
