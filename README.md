# S32 HMI – Modbus TCP Master

Load Bank control HMI with integrated Modbus TCP master for real-time monitoring and control.

## Overview

This project provides a **Modbus TCP Master (Client)** that connects to your Modbus slave device:

```
[Your PLC/RTU/Slave] ←→ [This Modbus Master Server] ←→ [Web Browser HMI]
    (Modbus TCP)                  (REST API)
```

The server acts as a Modbus TCP **master/client** that:
- ✅ Connects to your Modbus TCP **slave device** (PLC, RTU, gateway)
- ✅ Polls configured registers automatically (every 1 second by default)
- ✅ Exposes REST API for the web HMI to read/write values
- ✅ Serves the HMI interface directly at `http://localhost:4000/test.html`

## Prerequisites

- **Node.js 18+** (includes npm)
- **Network access** to your Modbus TCP slave device
- **Modbus slave device** (PLC, RTU, or gateway) with known register map

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Your Modbus Slave Connection

Edit `modbus.config.json` and update these settings to match your device:

```json
{
  "slaveHost": "192.168.1.100",  // ← Your PLC/RTU IP address
  "slavePort": 502,               // ← Modbus TCP port (standard is 502)
  "unitId": 1,                    // ← Modbus unit/slave ID
  "httpPort": 4000,               // ← Port for the REST API and HMI
  "timeoutMs": 3000,              // ← Modbus request timeout
  "pollIntervalMs": 1000,         // ← How often to poll tags (1 second)
  ...
}
```

### 3. Update Tag Addresses

Update the `tags` section in `modbus.config.json` to match your device's register map. Each tag needs:

- `address`: Modbus register address (0-based)
- `function`: `"holding"`, `"input"`, `"coil"`, or `"discrete"`
- `datatype`: `"uint16"`, `"int16"`, `"uint32"`, `"int32"`, `"float32"`, or `"bool"`
- `scale`: Scaling factor (e.g., `0.01` to convert from centiwatts to kW)
- `path`: Where to store the value in the state object
- `writable`: `true` or `false` (optional, defaults to false)

**Example:**
```json
"Load_Bank_Power": {
  "function": "holding",
  "address": 1000,
  "length": 2,
  "datatype": "uint32",
  "scale": 0.01,
  "path": "lb.measured_kW"
}
```

### 4. Start the Server

```bash
npm start
```

The server will:
- Connect to your Modbus slave device
- Start polling configured tags
- Serve the HMI at `http://localhost:4000/test.html`
- Expose REST API at `http://localhost:4000/api/*`

### 5. Open the HMI

Navigate to: **http://localhost:4000/test.html**

The HMI will automatically connect to the backend and display live data.

## Configuration Details

### Connection Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `slaveHost` | IP address of your Modbus slave | `"192.168.1.100"` |
| `slavePort` | Modbus TCP port | `502` |
| `unitId` | Modbus unit/slave ID | `1` |
| `httpPort` | Port for REST API and HMI | `4000` |
| `timeoutMs` | Modbus request timeout | `3000` |
| `pollIntervalMs` | Tag polling interval | `1000` |

### Supported Datatypes

- `uint16` – Unsigned 16-bit integer (1 register)
- `int16` – Signed 16-bit integer (1 register)
- `uint32` – Unsigned 32-bit integer (2 registers)
- `int32` – Signed 32-bit integer (2 registers)
- `float32` – 32-bit floating point (2 registers)
- `bool` – Boolean/coil (1 bit)

### Modbus Functions

- `holding` – Read/write holding registers (function code 3/16)
- `input` – Read input registers (function code 4, read-only)
- `coil` – Read/write coils (function code 1/5)
- `discrete` – Read discrete inputs (function code 2, read-only)

## REST API

### GET /healthz
Check server health and connection status.

**Response:**
```json
{
  "ok": true,
  "connected": true,
  "lastPoll": "2025-11-16T05:30:45.123Z"
}
```

### GET /api/state
Get complete system state (used by HMI for polling).

**Response:**
```json
{
  "state": {
    "mode": "AUTO",
    "commsOK": true,
    "gen": { "g1_kW": 2050, "g2_kW": 2080, ... },
    "lb": { "measured_kW": 1850, "setpoint_kW": 1900, ... },
    ...
  },
  "meta": {
    "lastPoll": "2025-11-16T05:30:45.123Z",
    "tags": 15
  }
}
```

### GET /api/tags
Get all cached tag values.

### GET /api/tags/:tagName
Get specific tag value.

**Response:**
```json
{
  "value": 1850,
  "ts": "2025-11-16T05:30:45.123Z"
}
```

### POST /api/write
Write a value to a Modbus register.

**Request:**
```json
{
  "tag": "Modbus_Load_Bank_Requested_Resistive_Load",
  "value": 1900,
  "meta": { "units": "kW" }
}
```

**Response:**
```json
{
  "ok": true,
  "tag": "Modbus_Load_Bank_Requested_Resistive_Load",
  "value": 1900
}
```

### POST /api/command
Execute a pre-configured command.

**Request:**
```json
{
  "command": "ENABLE_AUTO",
  "payload": {}
}
```

**Response:**
```json
{
  "ok": true,
  "command": "ENABLE_AUTO",
  "result": true
}
```

## HMI Configuration

By default, `test.html` connects to `http://localhost:4000`. To change this:

```html
<script>
  window.HMI_MODBUS_API = "http://192.168.1.25:4000";
</script>
<!-- Load test.html after setting the API URL -->
```

To run in demo/simulation mode (no backend):
```html
<script>
  window.HMI_MODBUS_API = null;
</script>
```

## Troubleshooting

### Connection Issues

1. **"connected": false** in `/healthz`
   - Verify `slaveHost` and `slavePort` are correct
   - Check network connectivity: `ping <slaveHost>`
   - Ensure firewall allows port 502 (or your configured port)
   - Verify Modbus slave device is running and accessible

2. **"Modbus poll failure" alarms**
   - Check that `unitId` matches your device's slave ID
   - Verify register addresses exist on your device
   - Check datatype and length match your device's configuration

3. **"Illegal data address" errors**
   - Register address doesn't exist on the device
   - Update `address` in `modbus.config.json` to match your device

4. **Timeout errors**
   - Increase `timeoutMs` in config
   - Check network latency to device
   - Reduce number of tags being polled

### HMI Issues

1. **HMI shows "COMMS FAULT"**
   - Backend server not running: run `npm start`
   - Wrong API URL: check `window.HMI_MODBUS_API`
   - CORS issues: ensure server is running on same machine or CORS is configured

2. **Values not updating**
   - Check `/api/state` endpoint directly in browser
   - Verify tags are configured with correct `path` in config
   - Check browser console for errors

## Development

### Run with auto-restart (nodemon)

```bash
npm run dev
```

### Add New Tags

1. Add tag definition to `modbus.config.json`:
```json
"My_New_Tag": {
  "function": "holding",
  "address": 2000,
  "length": 1,
  "datatype": "uint16",
  "path": "custom.myValue"
}
```

2. Restart server: `npm start`

3. Access via API: `GET /api/tags/My_New_Tag`

### Add New Commands

1. Add command to `modbus.config.json`:
```json
"MY_COMMAND": {
  "function": "coil",
  "address": 100,
  "value": true,
  "path": "custom.commandExecuted",
  "pathValue": true
}
```

2. Restart server and execute: `POST /api/command` with `{"command": "MY_COMMAND"}`

## Files

- `server.js` – Modbus TCP master server with REST API
- `modbus.config.json` – Configuration for Modbus connection and tag mapping
- `test.html` – Web-based HMI interface
- `package.json` – Node.js dependencies

## License

Private project for S32 load bank control system.
