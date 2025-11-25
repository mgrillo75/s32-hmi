# HMI Auto/Manual Mode Implementation Guide

## Overview
The HMI interface (`test.html`) now supports Auto/Manual control mode switching based on the PLC implementation documented in `AUTO_MANUAL_MODE_IMPLEMENTATION.md`.

## Features Added

### 1. Control Mode Selector
- **Location:** Prominent card at the top of the control section
- **Components:**
  - AUTO Mode button (green when active)
  - MANUAL Mode button (red when active)
  - Help text explaining each mode

### 2. Mode Indicator
- **Location:** Header bar
- **Display:** Shows current control mode (AUTO/MANUAL)
- **Visual:** Green badge for AUTO, Orange badge for MANUAL

### 3. AUTO Mode Panel
- **Visibility:** Shown when `s.controlMode = true`
- **Controls:**
  - Target Gen kW (Read/Write)
  - Current target display from PLC
  - Write button to update target
- **Purpose:** Allows setting generator target for automatic control algorithm

### 4. MANUAL Mode Panel
- **Visibility:** Shown when `s.controlMode = false`
- **Controls:**
  - Manual Setpoint (Read/Write)
  - Current setpoint display from PLC
  - Write button to update manual setpoint
  - Maximum allowed load display
- **Purpose:** Allows direct control of load bank setpoint

### 5. Load Bank Status
- **Display:** Real-time load bank metrics
  - Measured kW
  - Applied kW
  - Available kW
  - Setpoint kW
- **Visibility:** Always visible in both modes

## Modbus Tag Mapping

### Control Mode Tags
| Tag Name | Register | Type | Direction | Purpose |
|----------|----------|------|-----------|---------|
| `HMI_Modbus_Server_Tags_Control_Mode` | 12 | BOOL | PLC → HMI | Mode feedback (1=AUTO, 0=MANUAL) |
| `HMI_Modbus_Server_Tags_Control_Mode_Input` | 13 | BOOL | HMI → PLC | Mode command (1=AUTO, 0=MANUAL) |
| `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP` | 14 | DINT | PLC → HMI | Manual setpoint feedback (kW) |
| `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input` | 15 | DINT | HMI → PLC | Manual setpoint command (kW) |

### Generator Input Register Tags (Read-Only)
| Tag Name | Register | Type | Purpose |
|----------|----------|------|---------|
| `HMI_Modbus_Server_Tags_Kw_GenSet_1` | 30001 | UINT | Gen-1 kW (Input Register) |
| `HMI_Modbus_Server_Tags_Kw_GenSet_2` | 30003 | UINT | Gen-2 kW (Input Register) |
| `HMI_Modbus_Server_Tags_Kw_GenSet_3` | 30005 | UINT | Gen-3 kW (Input Register) |

### Configuration Tags (Holding Registers)
| Tag Name | Purpose |
|----------|---------|
| `HMI_Modbus_Server_Tags_Target_kW_Input` | Target Gen kW setpoint (Write) |
| `HMI_Modbus_Server_Tags_Load_Bank_Cap_Input` | Load Bank capacity limit (Write) |
| `HMI_Modbus_Server_Tags_KW_High_Limit_Input` | Generator high limit (Write) |

## User Workflow

### Switching to MANUAL Mode
1. Click **"MANUAL Mode"** button in the mode selector
2. System writes `0` to register 13 (`Control_Mode_Input`)
3. Header updates to show "MANUAL" in orange badge
4. AUTO panel hides, MANUAL panel appears
5. PLC performs bumpless transfer (initializes manual setpoint to current AUTO setpoint)
6. Operator can now directly control load bank

### Operating in MANUAL Mode
1. Enter desired load bank setpoint (kW) in "New Setpoint" field
2. System validates: 0 ≤ value ≤ LB_Max
3. Click **"Write Manual Setpoint"** button
4. System writes value to register 15 (`Manual_Load_Bank_SP_Input`)
5. PLC applies setpoint to load bank
6. Feedback appears in "Current Setpoint" field (register 14)

### Switching to AUTO Mode
1. Click **"AUTO Mode"** button in the mode selector
2. System writes `1` to register 13 (`Control_Mode_Input`)
3. Header updates to show "AUTO" in green badge
4. MANUAL panel hides, AUTO panel appears
5. PLC resumes automatic control algorithm

### Adjusting AUTO Parameters
1. Ensure system is in AUTO mode
2. Modify Target Gen kW, Load Bank Cap, or High Limit as needed
3. Click corresponding write button
4. PLC automatically adjusts load bank to maintain generator targets

## Simulation Mode Support

The HMI includes a simulation mode for testing without a live PLC connection:

### Simulation Features
- Toggle between simulation and live mode using the header button
- In simulation mode:
  - Mode changes are applied locally
  - Manual setpoints are clamped and applied to simulated load bank
  - AUTO mode runs simplified control algorithm
  - Generator kW values are simulated with realistic noise
- All UI behaviors work identically in both modes

### Simulation Logic
```javascript
// Control mode writes
if (tagName === "HMI_Modbus_Server_Tags_Control_Mode_Input") {
  s.controlMode = value ? true : false;
}

// Manual setpoint writes
if (tagName === "HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input") {
  s.manualSetpoint_kW = clamp(value, 0, s.cfg.maxLB_kW);
}
```

## Safety Features

### Input Validation
- Manual setpoint is validated: `0 ≤ value ≤ maxLB_kW`
- Invalid inputs show error messages
- Maximum load is dynamically updated based on available capacity

### Visual Feedback
- Mode buttons change color based on active mode
- Status messages show write progress and results
- Timestamps track last configuration write
- Control mode indicator always visible in header

### Bumpless Transfer
- When switching AUTO → MANUAL, PLC initializes manual setpoint to current AUTO setpoint
- Prevents sudden load changes during transitions
- Seamless operation maintained

## Technical Implementation

### State Model Updates
```javascript
const s = {
  // ... existing state ...
  controlMode: true,        // true = AUTO, false = MANUAL
  manualSetpoint_kW: 0,     // Manual setpoint feedback
  // ...
};
```

### Polling Updates
```javascript
async function fetchStateOnce() {
  // Read control mode and manual setpoint from PLC
  const [controlMode, manualSP] = await Promise.all([
    readTag("HMI_Modbus_Server_Tags_Control_Mode"),           // Register 12
    readTag("HMI_Modbus_Server_Tags_Manual_Load_Bank_SP")     // Register 14
  ]);
  
  if (controlMode !== undefined) s.controlMode = controlMode;
  if (manualSP !== undefined) s.manualSetpoint_kW = manualSP;
  // ...
}
```

### UI Update Logic
```javascript
function paint() {
  // Show/hide panels based on mode
  const autoPanel = $("auto-mode-panel");
  const manualPanel = $("manual-mode-panel");
  
  if (autoPanel) autoPanel.style.display = s.controlMode ? "block" : "none";
  if (manualPanel) manualPanel.style.display = s.controlMode ? "none" : "block";
  
  // Update button styling
  btnModeAuto.style.background = s.controlMode ? "#10b981" : "#718096";
  btnModeManual.style.background = s.controlMode ? "#718096" : "#dc2626";
  // ...
}
```

## Testing Checklist

### Simulation Mode Testing
- [ ] Switch between AUTO and MANUAL modes
- [ ] Verify panels show/hide correctly
- [ ] Verify button styling updates
- [ ] Write manual setpoint and confirm it's applied
- [ ] Verify load bank follows manual setpoint
- [ ] Switch back to AUTO and verify automatic control resumes

### Live Mode Testing (with PLC)
- [ ] Connect to PLC via "Switch to Live" button
- [ ] Verify current mode reads correctly from register 12
- [ ] Switch to MANUAL mode
- [ ] Verify PLC confirms mode change
- [ ] Write manual setpoint
- [ ] Verify PLC applies setpoint and sends feedback
- [ ] Monitor load bank response
- [ ] Switch to AUTO mode
- [ ] Verify automatic control resumes

### Validation Testing
- [ ] Try writing manual setpoint < 0 (should reject)
- [ ] Try writing manual setpoint > max (should reject)
- [ ] Verify max load updates dynamically
- [ ] Test mode switching multiple times

## UI Design Notes

### Color Scheme
- **AUTO Mode:** Purple gradient (#667eea → #764ba2)
- **MANUAL Mode:** Pink/red gradient (#f093fb → #f5576c)
- **Mode Selector:** Pink/red gradient (#f093fb → #f5576c)
- **Success Buttons:** Green (#10b981)
- **Inactive Buttons:** Gray (#718096)

### Responsive Design
- Mode selector spans full width on mobile
- AUTO/MANUAL panels adapt to screen size
- Load bank status always visible
- Controls stack vertically on narrow screens

## Future Enhancements

### Potential Additions
1. **Mode Change Confirmation:** Add dialog to confirm mode switches
2. **Manual Limits Display:** Show real-time validation feedback
3. **Mode History Log:** Track mode changes with timestamps
4. **Preset Manual Setpoints:** Quick-select common load values
5. **Rate Limiting:** Prevent rapid mode changes
6. **Interlock Display:** Show why mode change might be blocked

## Summary

The HMI now provides complete Auto/Manual control mode support with:
- ✅ Intuitive mode selection interface
- ✅ Separate control panels for AUTO and MANUAL modes
- ✅ Real-time feedback from PLC
- ✅ Input validation and safety checks
- ✅ Simulation mode for offline testing
- ✅ Visual indicators and status messages
- ✅ Bumpless transfer support
- ✅ Modbus TCP integration ready

All functionality works in both simulation and live modes, allowing for complete testing before PLC connection.

