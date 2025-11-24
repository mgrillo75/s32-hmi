# Setup Guide – Connecting to Your Modbus Slave Device

This guide will help you configure the S32 HMI Modbus TCP master to connect to your actual Modbus slave device (PLC, RTU, or gateway).

## Step 1: Identify Your Device Information

Before configuring, gather this information about your Modbus slave device:

- [ ] **IP Address** (e.g., `192.168.1.100`)
- [ ] **Modbus TCP Port** (usually `502`)
- [ ] **Unit/Slave ID** (usually `1`, check your device documentation)
- [ ] **Register Map** (list of addresses and their data types)

## Step 2: Update Connection Settings

Edit `modbus.config.json` and update the connection settings:

```json
{
  "slaveHost": "192.168.1.100",  // ← Your device's IP address
  "slavePort": 502,               // ← Modbus TCP port (standard is 502)
  "unitId": 1,                    // ← Your device's unit/slave ID
  ...
}
```

## Step 3: Configure Tag Addresses

Update the `tags` section to match your device's register map. Here's what each field means:

### Tag Configuration Fields

| Field | Description | Example |
|-------|-------------|---------|
| `function` | Register type | `"holding"`, `"input"`, `"coil"`, `"discrete"` |
| `address` | Register address (0-based) | `1000` |
| `length` | Number of registers | `1` (uint16), `2` (uint32/float32) |
| `datatype` | Data type | `"uint16"`, `"int16"`, `"uint32"`, `"int32"`, `"float32"`, `"bool"` |
| `scale` | Scaling factor | `0.01` (convert from centiwatts to kW) |
| `path` | State object path | `"lb.measured_kW"` |
| `writable` | Allow writes | `true` or `false` (optional) |

### Example Tag Configuration

```json
"Load_Bank_Power": {
  "function": "holding",      // Reading holding registers
  "address": 1000,            // Modbus address 1000
  "length": 2,                // 2 registers (32-bit value)
  "datatype": "uint32",       // Unsigned 32-bit integer
  "scale": 0.01,              // Divide by 100 (value is in centiwatts)
  "path": "lb.measured_kW",   // Store in state.lb.measured_kW
  "writable": false           // Read-only
}
```

### Understanding Modbus Addressing

**Important:** This library uses **0-based addressing**:
- If your device documentation says "register 40001", use address `0`
- If your device documentation says "register 40100", use address `99`
- If your device documentation says "register 30001", use address `0` with `"function": "input"`

**Modbus notation reference:**
- `40001-49999` = Holding registers (use `"function": "holding"`, address = notation - 40001)
- `30001-39999` = Input registers (use `"function": "input"`, address = notation - 30001)
- `00001-09999` = Coils (use `"function": "coil"`, address = notation - 1)
- `10001-19999` = Discrete inputs (use `"function": "discrete"`, address = notation - 10001)

## Step 4: Verify Connection

Before starting the full server, test your connection:

```bash
npm run verify
```

This will:
- ✅ Connect to your device
- ✅ Read the first configured tag
- ✅ Display the raw and decoded values
- ✅ Confirm everything is working

**Expected output:**
```
╔════════════════════════════════════════════════════════════╗
║        Modbus TCP Connection Verification                 ║
╚════════════════════════════════════════════════════════════╝

Target Device: 192.168.1.100:502
Unit ID: 1
Timeout: 3000ms

⏳ Connecting to Modbus slave...
✅ TCP connection established!

⏳ Testing read of first configured tag: "Load_Bank_Power"
   Address: 1000, Function: holding, Type: uint32
✅ Read successful!
   Raw value(s): [0, 1850]
   Decoded value: 18.5 (scale: 0.01)

╔════════════════════════════════════════════════════════════╗
║  ✅ CONNECTION VERIFIED - Ready to start server!          ║
╚════════════════════════════════════════════════════════════╝
```

## Step 5: Start the Server

Once verification succeeds, start the full server:

```bash
npm start
```

The server will:
- Connect to your Modbus slave device
- Poll all configured tags every second
- Serve the HMI at `http://localhost:4000/test.html`
- Expose REST API at `http://localhost:4000/api/*`

## Step 6: Open the HMI

Open your web browser and navigate to:

**http://localhost:4000/test.html**

You should see:
- Live data from your Modbus device
- "Modbus OK" in the status bar
- Real-time updates every second

## Troubleshooting

### Connection Fails

**Error: "ECONNREFUSED" or "ETIMEDOUT"**
- ✓ Check IP address is correct
- ✓ Ping the device: `ping 192.168.1.100`
- ✓ Verify device is powered on
- ✓ Check firewall settings
- ✓ Ensure device is on same network or routable

**Error: "Modbus exception 1: Illegal function"**
- ✓ Check `function` field (should be `"holding"`, `"input"`, `"coil"`, or `"discrete"`)
- ✓ Verify your device supports that function code

**Error: "Modbus exception 2: Illegal data address"**
- ✓ Register address doesn't exist on device
- ✓ Check your device's register map documentation
- ✓ Verify you're using 0-based addressing correctly
- ✓ Try reading a known good address first

**Error: "Modbus exception 3: Illegal data value"**
- ✓ Check `length` field matches data type
- ✓ uint32/int32/float32 need `"length": 2`
- ✓ uint16/int16/bool need `"length": 1`

**Error: "Timed out"**
- ✓ Increase `timeoutMs` in config (try 5000)
- ✓ Check network latency
- ✓ Verify `unitId` matches device's slave ID
- ✓ Reduce number of tags being polled

### Data Issues

**Values are wrong or scaled incorrectly**
- ✓ Check `scale` factor in tag configuration
- ✓ Verify `datatype` matches device (signed vs unsigned)
- ✓ Check byte order (this library uses big-endian)

**Values not updating in HMI**
- ✓ Check `/api/state` endpoint in browser
- ✓ Verify `path` field in tag config
- ✓ Check browser console for errors
- ✓ Ensure `pollIntervalMs` is reasonable (1000ms = 1 second)

**Write operations fail**
- ✓ Ensure tag has `"writable": true`
- ✓ Check device allows writes to that register
- ✓ Verify value is within valid range
- ✓ Check `writeFunction` if different from `function`

## Example Configurations

### Simple 16-bit Holding Register

```json
"Temperature": {
  "function": "holding",
  "address": 100,
  "length": 1,
  "datatype": "int16",
  "scale": 0.1,
  "path": "sensors.temp_C"
}
```

### 32-bit Power Reading

```json
"Active_Power": {
  "function": "holding",
  "address": 1000,
  "length": 2,
  "datatype": "uint32",
  "scale": 0.01,
  "path": "power.active_kW"
}
```

### Boolean Coil (Status Bit)

```json
"Pump_Running": {
  "function": "coil",
  "address": 0,
  "length": 1,
  "datatype": "bool",
  "path": "status.pump_running"
}
```

### Writable Setpoint

```json
"Setpoint": {
  "function": "holding",
  "address": 2000,
  "length": 1,
  "datatype": "uint16",
  "scale": 1,
  "path": "control.setpoint",
  "writable": true
}
```

## Need Help?

1. Check server logs for detailed error messages
2. Use `npm run verify` to test individual tags
3. Check `/healthz` endpoint: `http://localhost:4000/healthz`
4. Review your device's Modbus register map documentation
5. Test with a Modbus client tool (like ModScan) first to verify addresses

## Next Steps

Once connected:
1. Add more tags from your device's register map
2. Configure commands for control operations
3. Customize the HMI interface for your needs
4. Set up proper error handling and alarms

