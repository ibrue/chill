import Foundation

/// ChillHelper - Privileged daemon for fan control
/// Runs as root via LaunchDaemon at com.chill.helper
/// Handles SMC access and maintains Ftst unlock flag

let helper = ChillHelperDaemon()
helper.start()

// Keep the daemon running
RunLoop.current.run()
