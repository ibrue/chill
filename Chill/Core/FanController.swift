import Foundation
import Observation

/// Manages XPC connection to ChillHelper for fan control
@Observable
final class FanController: NSObject {
    private var connection: NSXPCConnection?
    private var reconnectTimer: Timer?

    var isHelperConnected: Bool = false
    var isManualMode: Bool = false
    var activeProfileName: String = "Auto"

    // MARK: - Lifecycle

    override init() {
        super.init()
        connect()
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    func connect() {
        let connection = NSXPCConnection(machServiceName: ChillConstants.helperMachServiceName, options: [])

        connection.remoteObjectInterface = NSXPCInterface(with: ChillXPCProtocol.self)

        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isHelperConnected = false
                self?.scheduleReconnect()
            }
        }

        connection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isHelperConnected = false
                self?.scheduleReconnect()
            }
        }

        connection.resume()
        self.connection = connection
        isHelperConnected = true
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connection?.invalidate()
        connection = nil
        isHelperConnected = false
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.connect()
            if self?.isHelperConnected == true {
                self?.reconnectTimer?.invalidate()
                self?.reconnectTimer = nil
            }
        }
    }

    // MARK: - Fan Control

    /// Set manual fan mode with target RPM
    func setFanMode(manual: Bool, fanIndex: Int = 0, targetRPM: Float, completion: @escaping (Bool) -> Void) {
        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ error in
            print("[FanController] XPC error: \(error)")
            completion(false)
        }) as? ChillXPCProtocol else {
            print("[FanController] Helper not connected")
            completion(false)
            return
        }

        proxy.setFanMode(manual: manual, fanIndex: fanIndex, targetRPM: targetRPM) { success in
            DispatchQueue.main.async {
                if success {
                    self.isManualMode = manual
                }
                completion(success)
            }
        }
    }

    /// Return to auto mode
    func setAutoMode(completion: @escaping (Bool) -> Void) {
        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ error in
            print("[FanController] XPC error: \(error)")
            completion(false)
        }) as? ChillXPCProtocol else {
            print("[FanController] Helper not connected")
            completion(false)
            return
        }

        proxy.setAutoMode { success in
            DispatchQueue.main.async {
                if success {
                    self.isManualMode = false
                    self.activeProfileName = "Auto"
                }
                completion(success)
            }
        }
    }

    /// Read sensor values from helper
    func readSensors(completion: @escaping ([String: Float]) -> Void) {
        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ error in
            print("[FanController] XPC error: \(error)")
            completion([:])
        }) as? ChillXPCProtocol else {
            completion([:])
            return
        }

        proxy.readSensors { readings in
            DispatchQueue.main.async {
                completion(readings)
            }
        }
    }

    /// Get current fan status
    func getStatus(completion: @escaping (Bool, Float, Float) -> Void) {
        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ error in
            print("[FanController] XPC error: \(error)")
            completion(false, 0, 0)
        }) as? ChillXPCProtocol else {
            completion(false, 0, 0)
            return
        }

        proxy.getStatus { isManual, fan0RPM, fan1RPM in
            DispatchQueue.main.async {
                self.isManualMode = isManual
                completion(isManual, fan0RPM, fan1RPM)
            }
        }
    }
}
