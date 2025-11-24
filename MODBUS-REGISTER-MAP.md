# Modbus Register Map - S32 HMI

This document describes the complete Modbus register map for the S32 Load Bank HMI system.

## Register Map Summary

### Coils (Function Code 1/5) - Boolean Status

| Address | Tag Alias | Tag Name | Description | Read/Write |
|---------|-----------|----------|-------------|------------|
| 0 | `Gen_1_52A` | `COIL_00000` | Generator 1 Circuit Breaker 52A Status | Read/Write |
| 1 | `Gen_2_52A` | `COIL_00001` | Generator 2 Circuit Breaker 52A Status | Read/Write |
| 2 | `Gen_3_52A` | `COIL_00002` | Generator 3 Circuit Breaker 52A Status | Read/Write |

**Values:**
- `0` (False) = Circuit Breaker OPEN
- `1` (True) = Circuit Breaker CLOSED

### Holding Registers (Function Code 3/16) - Generator Power Values

| Address | Stop | Tag Alias | Tag Name | Data Type | Description |
|---------|------|-----------|----------|-----------|-------------|
| 0 | 1 | `Modbus_Server_Kw_GenSet_1` | `HREG_00000` | uint32 (MSR) | Generator 1 Power (kW) |
| 1 | 2 | `Modbus_Server_Kw_GenSet_2` | `HREG_00001` | uint32 (MSR) | Generator 2 Power (kW) |
| 2 | 3 | `Modbus_Server_Kw_GenSet_3` | `HREG_00002` | uint32 (MSR) | Generator 3 Power (kW) |

**Note:** These are 32-bit unsigned integers using Most Significant Register (MSR) first byte order. Each value spans 2 consecutive registers.

## HMI Configuration Mapping

The `modbus.config.json` file maps these Modbus registers to the HMI state object:

### Circuit Breaker Status (Coils)

```json
{
  "GEN1_BREAKER": {
    "function": "coil",
    "address": 0,
    "datatype": "bool",
    "path": "gen.g1_52A"
  },
  "GEN2_BREAKER": {
    "function": "coil",
    "address": 1,
    "datatype": "bool",
    "path": "gen.g2_52A"
  },
  "GEN3_BREAKER": {
    "function": "coil",
    "address": 2,
    "datatype": "bool",
    "path": "gen.g3_52A"
  }
}
```

### Generator Power (Holding Registers)

```json
{
  "GEN1_KW": {
    "function": "holding",
    "address": 3300,
    "length": 2,
    "datatype": "uint32",
    "scale": 0.01,
    "path": "gen.g1_kW"
  },
  "GEN2_KW": {
    "function": "holding",
    "address": 3302,
    "length": 2,
    "datatype": "uint32",
    "scale": 0.01,
    "path": "gen.g2_kW"
  },
  "GEN3_KW": {
    "function": "holding",
    "address": 3304,
    "length": 2,
    "datatype": "uint32",
    "scale": 0.01,
    "path": "gen.g3_kW"
  }
}
```

## XML Configuration

The `Modbus_Server_Registers_HMI.xml` file has been updated to include:

### Added Coils Section

Three new coil registers for circuit breaker status:
- **COIL_00000** → Gen_1_52A (Address 0)
- **COIL_00001** → Gen_2_52A (Address 1)
- **COIL_00002** → Gen_3_52A (Address 2)

### Existing Holding Registers

Three 32-bit holding registers for generator power:
- **HREG_00000** → Modbus_Server_Kw_GenSet_1 (Address 0-1)
- **HREG_00001** → Modbus_Server_Kw_GenSet_2 (Address 1-2)
- **HREG_00002** → Modbus_Server_Kw_GenSet_3 (Address 2-3)

## Usage in HMI

The HMI (`test.html`) displays these values in the generator cards:

```javascript
// Circuit Breaker Status
state.gen.g1_52A  // true = CLOSED, false = OPEN
state.gen.g2_52A  // true = CLOSED, false = OPEN
state.gen.g3_52A  // true = CLOSED, false = OPEN

// Generator Power
state.gen.g1_kW   // Generator 1 power in kW
state.gen.g2_kW   // Generator 2 power in kW
state.gen.g3_kW   // Generator 3 power in kW
```

## Testing

To test the circuit breaker status reading:

1. **Start the server:**
   ```bash
   npm start
   ```

2. **Check the API:**
   ```bash
   curl http://localhost:4000/api/tags/GEN1_BREAKER
   curl http://localhost:4000/api/tags/GEN2_BREAKER
   curl http://localhost:4000/api/tags/GEN3_BREAKER
   ```

3. **View in HMI:**
   Open `http://localhost:4000/test.html` and check the generator cards:
   - "52A: CLOSED" when breaker is closed (true)
   - "52A: OPEN" when breaker is open (false)

## Write Operations

To control circuit breakers via the API:

```bash
# Close Generator 1 breaker
curl -X POST http://localhost:4000/api/write \
  -H "Content-Type: application/json" \
  -d '{"tag": "GEN1_BREAKER", "value": true}'

# Open Generator 1 breaker
curl -X POST http://localhost:4000/api/write \
  -H "Content-Type: application/json" \
  -d '{"tag": "GEN1_BREAKER", "value": false}'
```

## Notes

1. **Addressing:** All addresses use 0-based indexing
2. **Byte Order:** 32-bit values use MSR (Most Significant Register first)
3. **Scaling:** Power values may need scaling factor (check device documentation)
4. **Read-Only vs Writable:** Circuit breaker coils can be read/write depending on device configuration

## Updating the Configuration

If your actual device uses different addresses, update `modbus.config.json`:

```json
{
  "GEN1_BREAKER": {
    "address": 0,  // ← Change to match your device
    ...
  }
}
```

Then restart the server: `npm start`

