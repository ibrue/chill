# Project Structure

## Directory Layout

```
Chill/
├── README.md                        # Main documentation
├── STRUCTURE.md                     # This file
├── .gitignore                       # Git ignore rules
├── project.yml                      # XcodeGen configuration
├── setup.sh                         # Installation script for helper
│
├── Config/
│   ├── Chill.entitlements          # App entitlements (disable sandbox)
│   ├── ChillHelper.entitlements    # Helper entitlements
│   └── com.chill.helper.plist      # LaunchDaemon configuration
│
├── Shared/                          # Code shared between app and helper
│   ├── XPCProtocol.swift           # ChillXPCProtocol definition
│   └── ChillConstants.swift         # Shared constants
│
├── Chill/                           # Main application target
│   ├── Info.plist                  # App bundle info
│   ├── App/
│   │   ├── ChillApp.swift          # @main app entry point
│   │   └── AppDelegate.swift       # Menu bar setup and popover
│   │
│   ├── Core/
│   │   ├── SMC/
│   │   │   ├── SMCKeys.swift       # SMC key constants
│   │   │   ├── SMCTypes.swift      # Type conversions and helpers
│   │   │   └── SMCBridge.swift     # IOKit interface (reads only)
│   │   ├── SensorManager.swift     # Real-time sensor polling (@Observable)
│   │   ├── FanController.swift     # XPC connection to helper
│   │   ├── ProfileEngine.swift     # Profile evaluation and hysteresis
│   │   ├── AppMonitor.swift        # App rule triggering
│   │   └── PowerMonitor.swift      # Power state monitoring
│   │
│   ├── Models/
│   │   ├── FanProfile.swift        # Profile definition + built-ins
│   │   ├── SensorReading.swift     # Sensor data container
│   │   └── AppRule.swift           # App trigger rules
│   │
│   └── UI/
│       ├── PopoverView.swift       # Main menu bar popover UI
│       ├── Components/
│       │   ├── FanGauge.swift      # RPM gauge visualization
│       │   ├── TempPill.swift      # Temperature badge
│       │   ├── ProfileSwitcher.swift # Profile selector
│       │   ├── PowerBar.swift      # Power state display
│       │   └── GlassCard.swift     # Glass effect container
│       │
│       └── Settings/
│           ├── SettingsView.swift  # Settings window with tabs
│           ├── ProfileEditorView.swift # Edit/create profiles
│           └── AppRulesView.swift  # Manage app rules
│
└── ChillHelper/                    # Privileged helper daemon target
    ├── Info.plist                  # Helper bundle info
    ├── main.swift                  # Entry point
    ├── ChillHelperDaemon.swift     # XPC listener and control logic
    └── SMCBridgeHelper.swift       # Helper wrapper (writes allowed)
```

## File Purpose Summary

### Configuration Files
- **project.yml**: XcodeGen spec defining two targets, frameworks, entitlements
- **Chill.entitlements**: App disables sandbox, allows mach-lookup for helper
- **ChillHelper.entitlements**: Helper runs unsandboxed with no special flags
- **com.chill.helper.plist**: LaunchDaemon config - runs at load, provides mach service

### Shared Code
- **XPCProtocol.swift**: Interface for app-helper communication
- **ChillConstants.swift**: Bundle IDs, mach service name, SMC constants

### SMC Access
- **SMCBridge.swift**: IOKit wrapper using IOConnectCallStructMethod
  - Opens AppleSMC service
  - Performs reads (no root needed on Apple Silicon)
  - Available to app for monitoring
- **SMCBridgeHelper.swift**: Wrapper for root-level SMC writes in helper
  - Manages Ftst unlock flag
  - Writes fan modes and targets
  - Maintains control loop

### Core Logic (App)
- **SensorManager**: 2-second polling of all temps and fan RPMs
- **FanController**: XPC connection to privileged helper
- **ProfileEngine**: Evaluates curve and applies hysteresis
- **AppMonitor**: Watches frontmost app, triggers profiles by bundle ID
- **PowerMonitor**: Monitors AC/battery state, suggests profiles

### UI Components
- **PopoverView**: Main menu bar interface (300x420pt)
- **FanGauge**: Arc-based RPM visualization with color interpolation
- **TempPill**: Small badge showing temp and color-coded status
- **ProfileSwitcher**: Pill buttons to switch between 5 profiles
- **PowerBar**: Shows watts + battery status
- **GlassCard**: Reusable container with glassmorphism (macOS 15+) or NSVisualEffectView

### Settings UI
- **SettingsView**: Tab navigation (General, Profiles, App Rules, About)
- **ProfileEditorView**: Drag curve points, adjust hysteresis
- **AppRulesView**: Pair apps to profiles, app picker

### Helper Daemon
- **ChillHelperDaemon**: Sets up XPC listener, manages fan state machine
  - Maintains `Ftst=1` at 150ms intervals
  - Handles wake/sleep transitions
  - Exposes XPC protocol methods
- **SMCBridgeHelper**: Root-level fan control operations

## Data Flow

```
Menu Bar UI (PopoverView)
    ↓
SensorManager ─→ (reads temperatures, RPMs)
    ↓
User selects Profile
    ↓
ProfileEngine ─→ (evaluates curve, computes target RPM)
    ↓
FanController ─→ XPC RPC ─→ ChillHelper Daemon (runs as root)
    ↓
SMCBridgeHelper ─→ IOKit ─→ AppleSMC
    ↓
Fan RPM changes
    ↓
SensorManager picks up new RPM → UI updates
```

## Key Design Decisions

1. **Two Targets**
   - App: no privileges, easy to update, access to XPC only
   - Helper: root-level, persistent, handles all SMC writes

2. **Ftst Maintenance**
   - App suppresses thermalmonitord by writing `Ftst=1`
   - Helper re-asserts every 150ms (firmware resets on wake)
   - Automatic re-unlock on sleep/wake detection

3. **Thread Safety**
   - SMC reads on dedicated serial queue
   - Sensor updates dispatched to main thread
   - XPC calls use completion handlers (async)

4. **Observable Pattern**
   - Core managers use Swift 5.9 `@Observable` macro
   - UI reactively updates when state changes
   - No publishers needed for this simple state model

5. **Sensor Strategy**
   - Keyboard sensor (Ts0S) is primary for "Cool Keys" profile
   - CPU complex (TCXC) fallback for most profiles
   - Reads work without root on Apple Silicon
   - Actual fan control requires root via helper

6. **Curve Format**
   - Simple array of (tempCelsius, rpmPercent) points
   - Linear interpolation between points
   - Hysteresis enforced by delaying RPM decreases
   - Increases apply immediately

## Building and Running

```bash
# Generate Xcode project
cd Chill
xcodegen generate

# Build in Xcode
xcode Chill.xcodeproj

# Install helper (one-time)
./setup.sh

# Launch app
open Chill/build/Release/Chill.app
```

## Debugging

- Helper logs to `/var/log/com.chill.helper.log`
- Monitor daemon: `sudo launchctl list | grep com.chill`
- Restart helper: `sudo launchctl unload /Library/LaunchDaemons/com.chill.helper.plist && sudo launchctl load /Library/LaunchDaemons/com.chill.helper.plist`
