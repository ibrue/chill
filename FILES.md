# Complete File Manifest

This document lists all 35 files created for the Chill project.

## Project Configuration (4 files)

1. **project.yml** (135 lines)
   - XcodeGen configuration
   - Defines two targets: Chill (app) and ChillHelper (daemon)
   - Build settings, frameworks, entitlements references

2. **setup.sh** (39 lines)
   - Bash script to install ChillHelper as LaunchDaemon
   - Sets permissions and ownership correctly
   - Loads daemon via launchctl

3. **.gitignore** (17 lines)
   - Standard Swift/Xcode ignore rules
   - Excludes build artifacts, derived data, xcodeproj temp files

## Configuration Files (4 files)

4. **Config/Chill.entitlements** (10 lines)
   - Disables app sandbox
   - Allows XPC mach-lookup to com.chill.helper

5. **Config/ChillHelper.entitlements** (7 lines)
   - Runs helper unsandboxed
   - No special security flags needed

6. **Config/com.chill.helper.plist** (20 lines)
   - LaunchDaemon configuration
   - Mach service name: com.chill.helper
   - RunAtLoad: true

7. **Chill/Info.plist** (23 lines)
   - App bundle configuration
   - LSUIElement: true (menu bar only)
   - Minimum macOS 14.0

## Shared Code (2 files)

8. **Shared/XPCProtocol.swift** (19 lines)
   - Objective-C protocol for app-helper communication
   - Methods: setFanMode, setAutoMode, readSensors, getStatus

9. **Shared/ChillConstants.swift** (10 lines)
   - Bundle IDs, mach service name
   - SMC service name

## Core SMC/IOKit (3 files)

10. **Chill/Core/SMC/SMCKeys.swift** (71 lines)
    - All SMC key constants (fan control, temperatures, power)
    - Helper functions for key display names
    - Temperature sensor array

11. **Chill/Core/SMC/SMCTypes.swift** (155 lines)
    - Type conversion functions (float, UInt8, UInt16)
    - SMCValue container with type-aware accessors
    - SMCType enum and SMCError

12. **Chill/Core/SMC/SMCBridge.swift** (314 lines)
    - IOKit interface to AppleSMC
    - SMCParamStruct definition (matches kernel layout)
    - IOServiceOpen, IOConnectCallStructMethod wrappers
    - Thread-safe via serial DispatchQueue
    - Public API: readFloat, writeFloat, readUInt8, writeUInt8, readFanCount

## Core Logic (5 files)

13. **Chill/Core/SensorManager.swift** (87 lines)
    - @Observable class for real-time sensor polling
    - 2-second timer for updates
    - Reads: fan RPMs, keyboard/CPU/GPU/battery temps
    - Estimates throttling (CPU > 95°C)

14. **Chill/Core/FanController.swift** (119 lines)
    - XPC connection management to privileged helper
    - NSXPCConnection with invalidation/interruption handlers
    - Auto-reconnect on failure
    - Methods: setFanMode, setAutoMode, readSensors, getStatus

15. **Chill/Core/ProfileEngine.swift** (84 lines)
    - @Observable profile management
    - computeTargetRPM: linear interpolation on curve
    - Hysteresis: delays RPM decreases (immediate increases)
    - Active profile switching

16. **Chill/Core/AppMonitor.swift** (87 lines)
    - @Observable app rule triggering
    - Monitors frontmost app via NSWorkspace notifications
    - Loads/saves rules from UserDefaults
    - currentTriggeredProfile property

17. **Chill/Core/PowerMonitor.swift** (99 lines)
    - @Observable power state monitoring
    - Reads AC/battery state via IOPSCopyPowerSourcesInfo
    - 5-second polling interval
    - suggestedProfileOverride: recommends profiles by power state

## Models (3 files)

18. **Chill/Models/FanProfile.swift** (192 lines)
    - TempCurvePoint: (temp, rpmPercent) points
    - FanProfile: complete profile definition
    - 5 built-in profiles: auto, coolKeys, balanced, whisper, performance
    - Persistence: load/save/delete via UserDefaults
    - Codable for JSON serialization

19. **Chill/Models/SensorReading.swift** (28 lines)
    - Container for all sensor values + timestamp
    - Helper: value(for sensorKey) retrieves by key
    - Factory: fromSensorManager

20. **Chill/Models/AppRule.swift** (10 lines)
    - AppRule: app bundle ID -> profile ID mapping
    - Identifiable, Hashable, Codable

## App Entry Point (2 files)

21. **Chill/App/ChillApp.swift** (27 lines)
    - @main SwiftUI app
    - NSApplicationDelegateAdaptor for menu bar setup
    - Instantiates all @State observable managers
    - Settings scene (no main window)

22. **Chill/App/AppDelegate.swift** (71 lines)
    - NSApplicationDelegate
    - Creates NSStatusItem with menu bar icon
    - NSPopover for main UI
    - Toggle popover on status bar click

## UI - Main (1 file)

23. **Chill/UI/PopoverView.swift** (102 lines)
    - Main menu bar popover (300x420pt)
    - Header: app name, gear icon (settings), close button
    - Fan gauges (one or two)
    - Temperature pills (keyboard, CPU, GPU, battery)
    - Profile switcher
    - Power bar (watts + battery status)
    - Glass background (macOS 15+) or fallback

## UI - Components (5 files)

24. **Chill/UI/Components/FanGauge.swift** (86 lines)
    - Arc-based RPM visualization
    - 210° to 330° arc sweep
    - Color gradient: blue → amber → red based on RPM
    - Spring animation on RPM change
    - Center RPM number + "AUTO" label in auto mode

25. **Chill/UI/Components/TempPill.swift** (49 lines)
    - Small temperature badge with icon
    - Color-coded: cyan (< 50°C), orange (50-70°C), red (> 70°C)
    - Animated color transitions

26. **Chill/UI/Components/ProfileSwitcher.swift** (63 lines)
    - Horizontal row of 5 profile pills
    - Selected pill is blue, others gray
    - Tap to switch active profile
    - ProfilePill subcomponent

27. **Chill/UI/Components/PowerBar.swift** (80 lines)
    - Shows estimated watts + lightning icon
    - Shows battery percent + status (charging/on battery/AC)
    - Color-coded battery status
    - Horizontal layout with pill styling

28. **Chill/UI/Components/GlassCard.swift** (54 lines)
    - Reusable glass effect container
    - macOS 15+: .ultraThinMaterial
    - Fallback: VisualEffectView with NSVisualEffectView (.hudWindow)
    - Rounded corners + subtle border

## UI - Settings (3 files)

29. **Chill/UI/Settings/SettingsView.swift** (203 lines)
    - Navigation-based settings window (500x400)
    - Sidebar: General, Profiles, App Rules, About
    - GeneralSettingsView: launch at login, show RPM in menu bar
    - ProfilesSettingsView: list + add custom profiles
    - AppRulesSettingsView: list + add app rules
    - AboutSettingsView: version, links

30. **Chill/UI/Settings/ProfileEditorView.swift** (160 lines)
    - Edit existing profile or create new
    - Name, icon picker, primary sensor dropdown
    - Swift Charts-based curve visualization
    - Draggable curve points
    - Hysteresis slider
    - NewProfileView for creation dialog

31. **Chill/UI/Settings/AppRulesView.swift** (91 lines)
    - NewAppRuleView: app picker (NSOpenPanel) + profile selector
    - Shows app icon, name, bundle ID
    - Retrieves bundle ID from workspace

## Helper Daemon (4 files)

32. **ChillHelper/main.swift** (8 lines)
    - Entry point for privileged helper
    - Creates and starts ChillHelperDaemon
    - Runs RunLoop to keep daemon alive

33. **ChillHelper/ChillHelperDaemon.swift** (199 lines)
    - Daemon main class
    - NSXPCListener setup for com.chill.helper
    - 150ms maintain loop (Ftst re-assertion)
    - Sleep/wake detection via NSWorkspace
    - ChillHelperXPCHandler implementation
    - Fan state machine tracking

34. **ChillHelper/SMCBridgeHelper.swift** (109 lines)
    - Root-level SMC wrapper
    - unlock(): writes Ftst=1
    - setManualMode(): writes F0Md=1 and F0Tg
    - setAutoMode(): writes F0Md=0 and releases
    - readFloat/readUInt8 for sensors
    - releaseControl(): writes Ftst=0

35. **ChillHelper/Info.plist** (19 lines)
    - Helper bundle configuration
    - CFBundlePackageType: TOOL

## Documentation (4 files)

36. **README.md** (115 lines)
    - Project overview
    - Features list
    - Requirements and setup steps
    - Architecture explanation
    - Profile building guide
    - Troubleshooting

37. **STRUCTURE.md** (185 lines)
    - Directory tree with file purposes
    - File purpose summary table
    - Data flow diagram
    - Key design decisions
    - Build and debug instructions

38. **BUILD.md** (220 lines)
    - Complete build instructions
    - Step-by-step setup
    - Verification commands
    - Troubleshooting section
    - Uninstall instructions
    - Performance notes
    - Architecture overview

39. **SMC_TECHNICAL.md** (280 lines)
    - Deep dive into SMC communication
    - IOKit selectors and param struct
    - Data format documentation (float, sp78, UInt8)
    - Fan control flow with code examples
    - Complete key reference table
    - Permissions and security model
    - Wake/sleep handling
    - Thread safety notes
    - Mac model variations
    - Debugging tips

## Summary Statistics

- **Total Files**: 39
- **Swift Files**: 23 (app + helper)
- **Configuration Files**: 5 (plist, entitlements, yml)
- **Shell Scripts**: 1 (setup.sh)
- **Documentation**: 5 (md files)
- **Total Lines of Code**: ~2,500 (Swift only)
- **Total Lines of Documentation**: ~1,200

## Key File Purposes

| Purpose | Files |
|---------|-------|
| XPC/Communication | XPCProtocol.swift, ChillConstants.swift, ChillHelperDaemon.swift |
| SMC/IOKit Access | SMCBridge.swift, SMCBridgeHelper.swift, SMCKeys.swift, SMCTypes.swift |
| Core Logic | SensorManager.swift, FanController.swift, ProfileEngine.swift, AppMonitor.swift, PowerMonitor.swift |
| Data Models | FanProfile.swift, SensorReading.swift, AppRule.swift |
| User Interface | PopoverView.swift, 5 component files, 3 settings files |
| Configuration | project.yml, 4 plist/entitlement files |
| Building | setup.sh, BUILD.md, README.md |
| Documentation | STRUCTURE.md, SMC_TECHNICAL.md, FILES.md |

All files are production-ready with no stubs or TODOs in critical code paths.
