# Apple Silicon SMC Technical Reference

This document describes how Chill communicates with the Apple Silicon SMC (System Management Controller) for fan control.

## Overview

The SMC is a coprocessor that manages low-level hardware functions including:
- Fan speed control
- Temperature monitoring
- Power management
- Sensor readings

On Apple Silicon Macs, the SMC can be accessed via IOKit without special firmware utilities.

## SMC Service Access

### Finding the SMC Service

```swift
let matchingDict = IOServiceMatching("AppleSMC")
let service = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict)
IOServiceOpen(service, mach_task_self_, 0, &connection)
```

The "AppleSMC" service name is consistent across Apple Silicon models.

### IOKit Selectors

SMC operations use two primary IOKit selectors:

- **Selector 5**: `kSMCReadKey` - Read SMC data
- **Selector 6**: `kSMCWriteKey` - Write SMC data

Some operations (like getting key info) use selector 2: `kSMCGetKeyInfo`

## SMC Parameter Structure

All SMC communication uses a fixed-size struct:

```c
struct SMCParamStruct {
    uint32_t key;              // 4-char code (big-endian)
    SMCVersion vers;           // 4 bytes
    SMCPLimitData pLimitData;  // 12 bytes
    SMCKeyInfo keyInfo;        // 6 bytes
    uint8_t result;            // 1 byte
    uint8_t status;            // 1 byte
    uint8_t data8;             // 1 byte
    uint32_t data32;           // 4 bytes
    uint8_t bytes[32];         // 32 bytes of data
};
```

Total size: 80 bytes

### Key Field

The key field uses 4-character big-endian codes:
```swift
// Example: "Ts0S" becomes 0x54733053
let keyBytes = [0x54, 0x73, 0x30, 0x53]
```

Conversion in Swift:
```swift
func fourCharCode(_ str: String) -> UInt32 {
    let chars = Array(str.utf8)
    var result: UInt32 = 0
    for i in 0..<min(4, chars.count) {
        result = (result << 8) | UInt32(chars[i])
    }
    // Pad with spaces
    for _ in chars.count..<4 {
        result = (result << 8) | UInt32(ascii: " ")
    }
    return result
}
```

## Key Data Format

SMC data is encoded in different formats depending on the key:

### IEEE 754 Float (flt)
Most fan and temperature values use IEEE 754 single-precision floats:
- Size: 4 bytes
- Byte order: Little-endian on Apple Silicon
- Range: ±3.4 × 10^38

```swift
func floatFromSMCBytes(_ bytes: [UInt8]) -> Float {
    guard bytes.count >= 4 else { return 0 }
    var value: Float = 0
    withUnsafeMutableBytes(of: &value) { ptr in
        ptr.copyMemory(from: bytes.prefix(4))
    }
    return value
}
```

### Fixed-Point sp78
Some readings use sp78 format (7-bit integer, 8-bit fractional):
```swift
let uint16val = uint16FromSMCBytes(bytes)
let signed = Int16(bitPattern: uint16val)
let value = Float(signed) / 256.0
```

### UInt8
Single byte values (0-255):
```swift
let value = bytes[0]
```

## Fan Control Flow

### 1. Unlock SMC (Ftst=1)

Writing `Ftst=1` suppresses the system thermal monitor (thermalmonitord):

```swift
smc.writeUInt8(key: "Ftst", value: 1)
```

**Important**: The firmware resets this flag after sleep. The helper re-asserts it every 150ms via a timer.

### 2. Set Fan Mode

Switch a fan to manual mode:

```swift
// Get key info first (required for write)
let modeKey = "F0Md"  // Fan 0 mode
smc.writeUInt8(key: modeKey, value: 1)  // 1 = manual, 0 = auto
```

### 3. Set Target RPM

Write the desired RPM as a float:

```swift
let targetKey = "F0Tg"  // Fan 0 target
let targetRPM: Float = 4500
smc.writeFloat(key: targetKey, value: targetRPM)
```

Valid range: typically 2000-8000 RPM (varies by fan)

### 4. Read Actual RPM

Check what the fan is currently doing:

```swift
let actualKey = "F0Ac"  // Fan 0 actual
if let rpm = smc.readFloat(key: actualKey) {
    print("Fan 0: \(Int(rpm)) RPM")
}
```

### 5. Return to Auto Mode

Release fan control:

```swift
smc.writeUInt8(key: "F0Md", value: 0)  // Auto mode
smc.writeUInt8(key: "Ftst", value: 0)  // Release unlock
```

## Key Reference

### Fan Control Keys

| Key  | Type   | Read/Write | Description |
|------|--------|-----------|-------------|
| Ftst | UInt8  | RW        | Unlock flag (1=manual, 0=auto) |
| FNum | UInt8  | R         | Number of fans |
| F0Md | UInt8  | RW        | Fan 0 mode |
| F0Tg | Float  | RW        | Fan 0 target RPM |
| F0Ac | Float  | R         | Fan 0 actual RPM |
| F0Mn | Float  | R         | Fan 0 minimum RPM |
| F0Mx | Float  | R         | Fan 0 maximum RPM |
| F1Md | UInt8  | RW        | Fan 1 mode |
| F1Tg | Float  | RW        | Fan 1 target RPM |
| F1Ac | Float  | R         | Fan 1 actual RPM |

### Temperature Sensors

| Key  | Type   | Description |
|------|--------|-------------|
| Ts0S | Float  | Keyboard/palm rest (popover display only) |
| TC0D | Float  | CPU proximity |
| TCXC | Float  | CPU complex die |
| TG0D | Float  | GPU die |
| TA0P | Float  | Ambient |
| TB1T | Float  | Battery |

### Power

| Key  | Type   | Description |
|------|--------|-------------|
| PSTR | Float  | System power draw (watts) |

## Permissions and Security

### Reading Sensors
**No root required** for most reads on Apple Silicon.

Sensor values are readable from user space via IOKit.

### Writing Fan Control
**Root access required** via privileged helper.

- App communicates with helper via XPC
- Helper runs as root via LaunchDaemon
- XPC interface defined in `ChillXPCProtocol`

### Entitlements

**App entitlements** (Chill.entitlements):
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.chill.helper</string>
</array>
```

**Helper entitlements** (ChillHelper.entitlements):
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

## Wake/Sleep Handling

The firmware resets `Ftst` on sleep. The helper monitors sleep/wake and re-asserts control:

```swift
NSWorkspace.shared.notificationCenter.addObserver(
    self,
    selector: #selector(systemDidWake),
    name: NSWorkspace.screensDidWakeNotification,
    object: nil
)
```

After wake, the helper waits 2 seconds (for SMC to stabilize), then re-unlocks.

## Thread Safety

SMC operations must be serialized. Chill uses a dedicated serial DispatchQueue:

```swift
private let queue = DispatchQueue(label: "com.chill.smc", qos: .userInitiated)

queue.sync {
    // All SMC reads/writes happen here
}
```

This prevents race conditions on the single IOKit connection.

## Error Handling

IOKit calls return `kern_return_t`:
- `KERN_SUCCESS` (0): Operation succeeded
- Other values: See IOReturn.h

Example:
```swift
let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
if result != KERN_SUCCESS {
    print("Failed with error: \(result)")
}
```

## Mac Model Variations

Sensor keys can vary slightly by Mac model:
- M1 MacBook Pro: All keys listed above work
- M2/M3: Additional sensors may be available
- Check actual key availability before assuming existence

## Debugging

To inspect SMC on your Mac, you can use:

```bash
# List SMC keys (requires separate SMC reader tool)
# Example: https://github.com/acidanthera/VirtualSMC

# Check system logs for thermalmonitord
log stream --predicate 'process == "thermalmonitord"'

# Monitor fan activity
while true; do ioreg -n AppleSMC | grep -i fan; sleep 1; done
```

## References

- IOKit Framework: `/System/Library/Frameworks/IOKit.framework`
- SMC Documentation: Limited official docs; primarily reverse-engineered
- VirtualSMC Project: Reference implementation
