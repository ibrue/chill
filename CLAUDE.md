# Chill — Claude in Xcode Instructions

You are working on **Chill**, a macOS menu bar app that controls fan speeds on Apple Silicon Macs (M1–M4). This file is your full briefing. Read it before touching any code.

---

## What This App Does

Chill sits in the menu bar and intelligently controls Mac fans via the SMC (System Management Controller). Apple's default thermal daemon (`thermalmonitord`) is deliberately conservative — it lets the keyboard heat up and lets the CPU throttle before ramping fans. Chill fixes this with offset-based fan profiles (**Chill 4°** and **Chill 8°**) that shift the macOS default ramp curve to trigger 4°C or 8°C earlier than Apple does.

---

## Architecture: Two Targets

```
Chill.app  (com.chill.app)          ←→ XPC ←→  ChillHelper  (com.chill.helper)
- SwiftUI menu bar UI                           - Runs as root (LaunchDaemon)
- Sensor polling (reads work without root)      - Writes Ftst=1 to unlock SMC
- Profile engine / app monitor                  - Writes fan mode + target RPM
- XPC client                                    - Holds unlock at 150ms interval
```

**Why two processes?** SMC writes return `kIOReturnNotPrivileged` from a user process. The helper runs as root and holds the unlock flag permanently.

---

## The Core SMC Unlock (Critical Knowledge)

Apple Silicon's `thermalmonitord` will **silently override** any fan speed you write unless you first set the `Ftst` diagnostic flag to 1. This suppresses the daemon's reclaim logic.

```
1. Write Ftst = 1         → thermalmonitord yields (~3–4 sec window)
2. Write F0Md = 1         → Fan 0 manual mode
3. Write F0Tg = <float>   → Fan 0 target RPM (IEEE 754 float, little-endian)
4. Re-assert Ftst every 150ms  → Prevent reclaim under thermal load
5. On sleep/wake: firmware resets Ftst → re-establish 2s after wake
```

**SMC data format on Apple Silicon:** 4-byte IEEE 754 float, little-endian. NOT Intel's old fixed-point SP78 format. See `Shared/SMCTypes.swift` for conversion functions.

---

## Key SMC Keys

| Key      | Purpose                                      |
|----------|----------------------------------------------|
| `Ftst`   | Unlock flag — write 1 to suppress thermalmonitord |
| `F0Md`   | Fan 0 mode: 0 = auto, 1 = manual            |
| `F0Tg`   | Fan 0 target RPM (float32 LE)               |
| `F0Ac`   | Fan 0 actual RPM (read-only)                |
| `F1*`    | Fan 1 keys (MacBook Pro 14"/16" dual-fan)   |
| `Ts0S`   | **Palm rest / keyboard sensor** (read-only display, not currently driving any built-in profile) |
| `TCXC`   | CPU complex die temp                        |
| `TG0D`   | GPU die temp                                |
| `TB1T`   | Battery temp                                |

---

## File Map

```
Chill/
├── Shared/                     ← Compiled by BOTH targets
│   ├── SMCBridge.swift         ← IOKit interface (core of everything)
│   ├── SMCKeys.swift           ← All SMC key string constants
│   ├── SMCTypes.swift          ← Float/UInt8 ↔ byte array conversions
│   ├── XPCProtocol.swift       ← @objc protocol for app↔helper comms
│   └── ChillConstants.swift    ← Bundle IDs, service names
│
├── Chill/                      ← Main app target only
│   ├── App/
│   │   ├── ChillApp.swift      ← @main, instantiates all @Observable objects
│   │   └── AppDelegate.swift   ← NSStatusItem, NSPopover, menu bar icon
│   ├── Core/
│   │   ├── SMC/                ← (empty — SMC files moved to Shared/)
│   │   ├── SensorManager.swift ← 2s polling loop, publishes temp + RPM data
│   │   ├── FanController.swift ← XPC client, sends commands to helper
│   │   ├── ProfileEngine.swift ← Curve interpolation + hysteresis logic
│   │   └── PowerMonitor.swift  ← IOPowerSources, battery/AC/wattage
│   ├── Models/
│   │   ├── FanProfile.swift    ← Profile model + 4 built-in profiles
│   │   └── SensorReading.swift ← Snapshot of all sensor values
│   └── UI/
│       ├── Brand.swift                 ← Centralized colors / fonts / identity
│       ├── PopoverView.swift           ← Main 270pt popover
│       ├── Components/
│       │   ├── BrandMark.swift         ← Snowflake-in-gradient logo mark
│       │   ├── FanGauge.swift          ← Canvas arc gauge
│       │   ├── TempPill.swift          ← Color-coded temp badge
│       │   ├── ProfileSwitcher.swift   ← Glass pill row
│       │   ├── PowerBar.swift          ← Wattage + battery row
│       │   └── GlassCard.swift         ← macOS 26 glass / NSVisualEffectView fallback
│       └── Settings/
│           ├── SettingsView.swift
│           └── ProfileEditorView.swift
│
├── ChillHelper/                ← Helper daemon target only
│   ├── main.swift              ← XPC listener entry point
│   ├── ChillHelperDaemon.swift ← XPC service impl, wires to SMCBridgeHelper
│   └── SMCBridgeHelper.swift   ← Root-level SMC write operations
│
└── Config/
    ├── Chill.entitlements
    ├── ChillHelper.entitlements
    └── com.chill.helper.plist  ← LaunchDaemon config
```

---

## Four Built-in Fan Profiles (in FanProfile.swift)

| Profile     | Primary Sensor | Philosophy |
|-------------|---------------|------------|
| Auto        | TCXC          | Pass-through — mirrors thermalmonitord |
| Chill 4°    | TCXC          | macOS default curve, shifted 4°C earlier |
| Chill 8° ⭐ | TCXC          | macOS default curve, shifted 8°C earlier |
| Performance | TCXC          | Aggressive ramp, prevent throttle |

The two Chill profiles are derived programmatically by `shifted(autoCurve, by: ...)` — see `Chill/Models/FanProfile.swift`. To change the baseline, edit `autoCurve` in one place and both offset profiles update.

## Brand / Design Tokens

All colors, fonts, and identity strings live in `Chill/UI/Brand.swift`. Use `Brand.primary` / `Brand.warm` / `Brand.hot` for temperature-state colors, `Brand.gradient` for the logo gradient, and `BrandMark` (in `Chill/UI/Components/BrandMark.swift`) wherever the logo is shown. Don't scatter `Color.cyan` / `.orange` / `.red` literals through the views.

---

## Current Build Status

- **Xcode project:** Generated, two targets configured (Chill app + ChillHelper tool)
- **Known fixed:** `Info.plist` path was doubling due to `sourceTree = "<group>"` — fixed to `SOURCE_ROOT`
- **Compile errors may remain** — fix them systematically, starting with `Shared/` files then `Chill/` then `ChillHelper/`

### Common issues to watch for:
1. **`@Observable` macro** — requires macOS 14+ and Swift 5.9. If you see observation errors, check the deployment target is set to 14.0
2. **IOKit imports** — `SMCBridge.swift` imports `IOKit`. Make sure `IOKit.framework` is linked in both targets (it's in the Frameworks build phase)
3. **`kIOMainPortDefault`** — use this, not the deprecated `kIOMasterPortDefault`
4. **XPC protocol `@objc`** — `XPCProtocol.swift` uses `@objc protocol`. Both targets must compile this from `Shared/`
5. **`ServiceManagement` framework** — linked in Chill target for future `SMJobBless` use; safe to remove if it causes issues for now

---

## How to Install the Helper (One-time, After Building)

The helper needs to run as root. After building both targets:

```bash
# From ~/Documents/Chill/
sudo cp /path/to/DerivedData/.../ChillHelper /Library/PrivilegedHelperTools/com.chill.helper
sudo cp Config/com.chill.helper.plist /Library/LaunchDaemons/
sudo chmod 544 /Library/PrivilegedHelperTools/com.chill.helper
sudo chown root:wheel /Library/PrivilegedHelperTools/com.chill.helper
sudo launchctl load /Library/LaunchDaemons/com.chill.helper.plist
```

Or run `./setup.sh` which does the same thing.

---

## Development Priorities (in order)

1. **Get both targets compiling clean** — fix any type errors, missing imports, API mismatches
2. **Verify SMC reads** — add a debug print in `SensorManager` to confirm temp values are non-zero
3. **Test XPC connection** — confirm `FanController` can reach the helper
4. **Test fan writes** — set a manual RPM and verify fans respond
5. **UI polish** — glass effects, animations, profile switcher morphing
6. **App monitor** — per-app profile auto-switching
7. **Helper install UI** — for eventual App Store / easy distribution

---

## Design Guidelines

- **Liquid Glass UI** on macOS 26: use `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))`
- **Fallback** on macOS 14/15: `NSVisualEffectView` with `.hudWindow` material, `behindWindow` blending
- **Colors:** blue-green for cool temps, amber for warm, red for hot — interpolate smoothly
- **Font:** SF Pro Rounded throughout (`Font.system(.rounded)`)
- **Popover size:** 270pt wide, ~340pt tall
- **Menu bar icon:** `thermometer.snowflake` SF Symbol, tinted based on current state

---

## Do Not

- Do not add third-party dependencies — this uses only Apple frameworks (IOKit, SwiftUI, ServiceManagement, XPC)
- Do not use `kIOMasterPortDefault` — it's deprecated, use `kIOMainPortDefault`
- Do not write SMC keys from the main app process — always go through the XPC helper
- Do not change bundle IDs (`com.chill.app`, `com.chill.helper`) — they're referenced in entitlements and the LaunchDaemon plist
