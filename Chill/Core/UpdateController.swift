import Foundation
import Observation
import Sparkle

@Observable
final class UpdateController: NSObject {
    /// True only when Sparkle is properly configured - i.e. the bundle carries a
    /// real EdDSA public key (`SUPublicEDKey`). Local and unsigned builds ship an
    /// empty key; starting Sparkle then fails with "The updater failed to start."
    /// every launch. When disabled, updates are off and the UI hides the control.
    let isUpdaterEnabled: Bool
    var canCheckForUpdates = false
    var lastCheckDate: Date?

    @ObservationIgnored
    private var updaterController: SPUStandardUpdaterController?

    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    override init() {
        let edKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) ?? ""
        isUpdaterEnabled = !edKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        super.init()

        // Don't start Sparkle without a signing key - it would throw at startup
        // and pop a "failed to start" alert on every launch.
        guard isUpdaterEnabled else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller

        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates() {
        guard let updaterController else { return }
        lastCheckDate = Date()
        updaterController.checkForUpdates(nil)
    }
}
