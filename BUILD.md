# Build Instructions

## Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Apple Silicon Mac (M1, M2, M3, M4 series)
- Administrator access for installing the helper daemon

## Step 1: Install XcodeGen

```bash
brew install xcodegen
```

## Step 2: Generate Xcode Project

```bash
cd /path/to/zurich
xcodegen generate
```

This creates `Chill.xcodeproj` from `project.yml`.

## Step 3: Build the Project

### Option A: Command Line

```bash
# Build both targets
xcodebuild -project Chill.xcodeproj -scheme Chill -configuration Release -destination 'platform=macOS' build
xcodebuild -project Chill.xcodeproj -scheme ChillHelper -configuration Release -destination 'platform=macOS' build
```

### Option B: Xcode GUI

```bash
open Chill.xcodeproj
```

Then:
1. Select Product > Scheme > Chill
2. Select Product > Build (or Cmd+B)
3. Switch to ChillHelper scheme and build it too

## Step 4: Install the Privileged Helper

To install the full app into `/Applications` and install/reinstall the helper:

```bash
./install.sh
```

Run the setup script to install ChillHelper as a system daemon:

```bash
./setup.sh
```

You'll be prompted for your password. This script:
- Copies the helper binary to `/Library/PrivilegedHelperTools/com.chill.helper`
- Installs the LaunchDaemon configuration to `/Library/LaunchDaemons/`
- Sets proper permissions (544) and ownership (root:wheel)
- Loads the daemon

## Step 5: Launch the App

### From Xcode
1. Select Product > Scheme > Chill
2. Product > Run (or Cmd+R)

### From Finder
Navigate to Xcode's build output and double-click `Chill.app`, or:

```bash
open ~/Library/Developer/Xcode/DerivedData/Chill-*/Build/Products/Release/Chill.app
```

The app will appear in your menu bar (thermometer icon).

## Verification

Check that the helper is running:

```bash
sudo launchctl list | grep com.chill
```

You should see output like:
```
- 0 com.chill.helper
```

Check the helper log:

```bash
tail -f /var/log/com.chill.helper.log
```

## Troubleshooting Build Issues

### XcodeGen not found
```bash
brew install xcodegen
export PATH="/usr/local/bin:$PATH"
```

### Project.yml not found
Make sure you're in the repository root:
```bash
pwd  # Should show the directory containing project.yml
xcodegen generate
```

### IOKit framework not found
Ensure you're building for macOS only (not iOS). The project.yml specifies `platform: macOS`.

### ChillHelper fails to build
Make sure both targets are in the same project. The XcodeGen config should create them together.

## Troubleshooting Runtime Issues

### Helper not responding
The helper may not have started. Try:
```bash
sudo launchctl load /Library/LaunchDaemons/com.chill.helper.plist
```

### Fans not responding
1. Check helper is running: `sudo launchctl list | grep com.chill`
2. Check permissions: `ls -la /Library/PrivilegedHelperTools/com.chill.helper` (should be `-r-xr-xr-x`)
3. Check log: `sudo tail /var/log/com.chill.helper.log`

### Temperature readings are zero
Sensor keys may vary by Mac model. Edit `SMCKeys.swift` and check sensor values:
```bash
# Check available keys on your Mac (needs separate SMC reader)
# Common keys: Ts0S (keyboard), TC0D (CPU), TG0D (GPU), TA0P (ambient)
```

### App crashes on launch
Check Xcode console for errors. Common issues:
- Missing IOKit import
- SMC service not available (try rebooting)
- XPC connection failed (helper not installed)

## Uninstalling

To remove the app and helper:

```bash
# Unload the daemon
sudo launchctl unload /Library/LaunchDaemons/com.chill.helper.plist

# Remove daemon files
sudo rm /Library/PrivilegedHelperTools/com.chill.helper
sudo rm /Library/LaunchDaemons/com.chill.helper.plist

# Remove the app
rm -rf /Applications/Chill.app
```

## Performance Notes

- The app uses ~5-10 MB of memory at idle
- Sensor polling is every 2 seconds (configurable)
- Helper maintains SMC lock with 150ms refresh (required for stability)
- No impact on battery life when on battery power (fans controlled locally)

## Code Architecture

The project has two targets:

1. **Chill** (Main App)
   - SwiftUI UI
   - Sensor monitoring (no root needed for reads)
   - Profile management
   - XPC communication

2. **ChillHelper** (Privileged Daemon)
   - Runs as root via LaunchDaemon
   - Direct SMC access via IOKit
   - Maintains `Ftst=1` unlock flag
   - Handles all fan writes

See `STRUCTURE.md` for detailed architecture.
