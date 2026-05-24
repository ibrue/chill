import Foundation
import Darwin

/// ChillHelper - Privileged daemon for fan control
/// Runs as root via LaunchDaemon at com.chill.helper
/// Handles SMC access and maintains Ftst unlock flag

// Line-buffer stdio so /var/log/com.chill.helper.log updates in real time
// instead of after the (rare, for this quieter daemon) block-buffer flush.
setlinebuf(stdout)
setlinebuf(stderr)

let helper = ChillHelperDaemon()
helper.start()

// Keep the daemon running
RunLoop.current.run()
