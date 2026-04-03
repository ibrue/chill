# Chill - Apple Silicon Fan Control

A beautiful, minimal menu bar app for controlling Apple Silicon Mac fans via SMC. Built with SwiftUI and IOKit.

## Features

- **Auto Profile**: System manages fans automatically
- **Cool Keys**: Aggressive keyboard sensor monitoring with early ramp-up
- **Balanced**: Mid-range efficiency curve
- **Whisper**: Ultra-quiet operation
- **Performance**: Maximum cooling for sustained workloads
- **App Rules**: Automatically switch profiles when specific apps launch
- **Real-time Monitoring**: Temperature, RPM, power draw
- **Liquid Glass UI**: Modern glassmorphism on macOS 14+

## Requirements

- macOS 14.0 or later
- Apple Silicon Mac (M1, M2, M3, M4 series)
- Xcode 15+
- XcodeGen

## Setup

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd Chill
   xcodegen generate
   ```

3. Open and build in Xcode:
   ```bash
   open Chill.xcodeproj
   ```

4. Build both targets (Chill app and ChillHelper)

5. Run the setup script to install the privileged helper:
   ```bash
   ./setup.sh
   ```
   You'll be prompted for your password to install the LaunchDaemon.

6. Launch Chill from Applications > Chill or run from Xcode

## Architecture

### Two-Target Design

**Chill (Main App)**
- SwiftUI menu bar interface
- Temperature and RPM monitoring
- Profile management and UI
- XPC communication with helper

**ChillHelper (Privileged Daemon)**
- Runs as root via LaunchDaemon
- Direct SMC access via IOKit
- Maintains `Ftst=1` unlock flag (150ms interval)
- Handles wake/sleep transitions
- XPC service provider

### SMC Details

- **Ftst**: Unlock flag. Writing `Ftst=1` suppresses `thermalmonitord` control
- **F0Md/F1Md**: Fan mode (0=auto, 1=manual)
- **F0Tg/F1Tg**: Fan target RPM (IEEE 754 float, little-endian)
- **F0Ac/F1Ac**: Fan actual RPM
- **Ts0S**: Keyboard/palm rest temperature (primary Cool Keys sensor)
- **TC0D, TG0D, TA0P, TB1T**: Other sensors

All SMC writes require root; reads work without elevation on Apple Silicon.

## Building Custom Profiles

In Settings > Profiles, click + to create a custom profile:

1. Name and icon
2. Select primary sensor (keyboard, CPU, GPU, etc.)
3. Drag points on the curve to set fan ramp behavior
4. Adjust hysteresis (°C before RPM drops)
5. Optionally link app bundle IDs to auto-trigger

## Troubleshooting

**Helper not connecting:**
- Run `sudo launchctl load /Library/LaunchDaemons/com.chill.helper.plist`
- Check `/var/log/system.log` for daemon startup errors

**Fans won't respond:**
- Ensure ChillHelper is running: `sudo launchctl list | grep com.chill`
- Try switching to Auto, then back to a profile
- Reboot and re-run `setup.sh`

**Temperature readings wrong:**
- Sensor keys vary slightly by Mac model. Edit `SMCKeys.swift` if needed

## License

MIT

## Contributing

Pull requests welcome. Please test on your specific Mac model before submitting.
