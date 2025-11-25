# AUTO/MANUAL Mode Implementation Summary

## Overview
The load bank control system now supports two operating modes:
- **AUTO Mode** (default): Automatic control algorithm maintains generator loading at target setpoints
- **MANUAL Mode**: Operator directly specifies the load bank setpoint via HMI

## Changes Made

### 1. New Variables Added (Lines 85-101)

**Control Mode Variables:**
- `Control_Mode` (BOOL): TRUE = AUTO, FALSE = MANUAL (defaults to AUTO)
- `Control_Mode_HMI_Input` (BOOL): Receives mode selection from HMI
- `Last_HMI_Mode_Command` (BOOL): Tracks last mode command to detect changes
- `Mode_Initialized` (BOOL): Flag indicating mode has been initialized

**Manual Mode Variables:**
- `Manual_Load_Bank_Setpoint` (UDINT): Operator-specified load bank setpoint in kW
- `Manual_Load_Bank_Setpoint_HMI_Input` (UDINT): Receives manual setpoint from HMI
- `Last_HMI_Manual_SP_Command` (UDINT): Tracks last manual setpoint command
- `Manual_SP_Initialized` (BOOL): Flag indicating manual setpoint has been initialized

**Limits:**
- `Manual_SP_Min` (UDINT): Minimum manual setpoint = 0 kW
- `Manual_SP_Max` (UDINT): Maximum manual setpoint = LB_Max (dynamic)

### 2. FirstScan Initialization (Lines 125-134)

Added initialization logic to:
- Default to AUTO mode on startup
- Clear any stale mode and manual setpoint inputs
- Ensure clean startup state

### 3. HMI Interface (Lines 237-283)

**Mode Selection Interface:**
- Reads `HMI_Modbus_Server_Tags_Control_Mode_Input` from HMI
- Detects mode changes
- Implements **bumpless transfer**: When switching to MANUAL, initializes manual setpoint with current AUTO setpoint
- Sends mode feedback to HMI via `HMI_Modbus_Server_Tags_Control_Mode`

**Manual Setpoint Interface:**
- Reads `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input` from HMI
- Validates manual setpoint against [0, LB_Max] range
- Dynamically updates `Manual_SP_Max` based on available load bank capacity
- Sends manual setpoint feedback to HMI via `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP`

### 4. Control Logic Modification (Lines 351-382)

**AUTO Mode (Control_Mode = TRUE):**
- Executes original automatic control algorithm
- Monitors generator loading and adjusts load bank incrementally
- All safety features and limits remain active

**MANUAL Mode (Control_Mode = FALSE):**
- Bypasses automatic control algorithm
- Sets `Load_Bank_kW_Set_Point` directly to `Manual_Load_Bank_Setpoint`
- Still reads all generator data and updates HMI
- All existing safety features (burn-in, test mode) remain active

## Modbus Register Configuration

Based on your RTAC configuration (Holding Registers):

| Register | Tag Name | Type | Direction | Purpose |
|----------|----------|------|-----------|---------|
| 12 | `HMI_Modbus_Server_Tags_Control_Mode` | BOOL | RTAC → HMI | Mode feedback (1=AUTO, 0=MANUAL) |
| 13 | `HMI_Modbus_Server_Tags_Control_Mode_Input` | BOOL | HMI → RTAC | Mode selection (1=AUTO, 0=MANUAL) |
| 14 | `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP` | DINT | RTAC → HMI | Manual setpoint feedback (kW) |
| 15 | `HMI_Modbus_Server_Tags_Manual_Load_Bank_SP_Input` | DINT | HMI → RTAC | Manual setpoint command (kW) |

## How It Works

### Switching to MANUAL Mode
1. Operator writes `0` to register 13 (`Control_Mode_Input`)
2. RTAC detects mode change
3. RTAC captures current AUTO setpoint and initializes manual setpoint (bumpless transfer)
4. RTAC switches to MANUAL mode
5. RTAC sends confirmation back to HMI via register 12

### Operating in MANUAL Mode
1. Operator writes desired load (kW) to register 15 (`Manual_Load_Bank_SP_Input`)
2. RTAC validates input against [0, LB_Max]
3. RTAC sets load bank to requested value
4. RTAC sends confirmation back to HMI via register 14
5. Load bank maintains operator-specified load

### Switching to AUTO Mode
1. Operator writes `1` to register 13 (`Control_Mode_Input`)
2. RTAC detects mode change
3. RTAC switches to AUTO mode
4. RTAC resumes automatic control algorithm
5. RTAC sends confirmation back to HMI via register 12

## Safety Features

### Input Validation
- Manual setpoint is clamped to [0, LB_Max] range
- Mode changes are tracked to prevent repeated application
- All inputs have feedback to HMI for confirmation

### Bumpless Transfer
- When switching from AUTO to MANUAL, the manual setpoint is initialized with the current AUTO setpoint
- Prevents sudden load changes during mode transitions

### Dynamic Limits
- `Manual_SP_Max` is continuously updated based on `LB_Max`
- Prevents commanding more load than available capacity
- Automatically adapts to load bank configuration changes

### Existing Safety Features Still Active
- 30-second burn-in delay
- Test mode (`Test_Run`) still prevents outputs
- All data acquisition and HMI updates continue in both modes
- Generator overload protection remains active in AUTO mode

## Operator Usage

### HMI Display Recommendations
Display the following on your HMI:

**Mode Selection:**
- Toggle button or selector: AUTO / MANUAL
- Current mode indicator (from register 12)

**AUTO Mode Display:**
- Target_Gen_kW (target per generator)
- Load_Bank_Cap (user limit)
- Gen_kW_High_Limit (overload threshold)

**MANUAL Mode Display:**
- Manual setpoint input field (0 to LB_Max kW)
- Current manual setpoint (from register 14)
- Maximum allowed load (LB_Max)

**Common Display (both modes):**
- Generator 1/2/3 kW values
- Generator 1/2/3 breaker status
- Load bank measured power
- Number of generators online

## Testing Recommendations

1. **Initial Testing:**
   - Start system in AUTO mode (default)
   - Verify automatic control is working
   - Note current load bank setpoint

2. **Mode Transition Test:**
   - Switch to MANUAL mode
   - Verify manual setpoint initializes to previous AUTO setpoint (bumpless)
   - Verify load bank maintains approximately same load

3. **Manual Operation Test:**
   - Adjust manual setpoint up by 100 kW
   - Verify load bank responds
   - Verify feedback matches command
   - Test min/max limits

4. **Return to AUTO Test:**
   - Switch back to AUTO mode
   - Verify automatic control resumes
   - Verify smooth transition

5. **Limit Testing:**
   - In MANUAL mode, try commanding above LB_Max
   - Verify system clamps to maximum
   - Try commanding negative values
   - Verify system clamps to 0

## Code Quality
- ✅ No linter errors
- ✅ All changes clearly commented with "ADDED" or "MODIFIED" markers
- ✅ Consistent with existing code style
- ✅ Follows SEL RTAC Structured Text conventions
- ✅ Maintains backward compatibility (defaults to AUTO mode)

## Summary of Comments in Code

All modifications are marked with clear comment blocks:
- `// ========== ADDED: ... ==========` - New code sections
- `// ========== MODIFIED: ... ==========` - Modified code sections  
- `// ========== END ... ==========` - End of modified sections
- `// ===== AUTO MODE ... =====` - AUTO mode logic
- `// ===== MANUAL MODE ... =====` - MANUAL mode logic

This makes it easy to identify changes and understand the implementation.


