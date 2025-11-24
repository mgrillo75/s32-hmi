# S32 HMI Deployment Guide

## Package Contents

This HMI application can run in two modes:

### 1. **SIMULATION MODE** (Standalone - No Backend Required)
- Only requires: `test.html`
- Opens directly in a web browser
- Perfect for demos, testing UI changes, or offline use
- Uses built-in JavaScript simulation

### 2. **LIVE MODE** (Full Stack - Modbus TCP Communication)
- Requires: All files listed below
- Needs Node.js runtime installed
- Connects to real Modbus TCP devices/PLCs

---

## Files Required

### For SIMULATION MODE (Minimal)
```
test.html                    # Main HMI interface (self-contained)
```

### For LIVE MODE (Complete)
```
test.html                    # Main HMI interface
server.js                    # Node.js backend server
package.json                 # Node.js dependencies
modbus.config.json          # Modbus register configuration
README.md                    # Project documentation (optional)
```

---

## Installation Instructions

### Option A: SIMULATION MODE (Quick Start)

1. Copy `test.html` to the target machine
2. Open `test.html` in any modern web browser
3. Click "Switch to Simulation" if not already in simulation mode
4. Done! The HMI will run with simulated data

**Requirements:**
- Any modern web browser (Chrome, Edge, Firefox)
- No installation needed

---

### Option B: LIVE MODE (Full Installation)

#### Prerequisites
- **Node.js** (v16 or higher) - Download from: https://nodejs.org/
- Network access to your Modbus TCP device/PLC

#### Step 1: Copy Files
Copy all files to a folder on the target machine:
```
C:\HMI\s32-hmi\
  ├── test.html
  ├── server.js
  ├── package.json
  ├── modbus.config.json
  └── README.md
```

#### Step 2: Configure Modbus Connection
Edit `modbus.config.json` to match your setup:

```json
{
  "slaveHost": "192.168.1.100",  // ← Change to your PLC IP
  "slavePort": 502,               // ← Modbus TCP port (usually 502)
  "unitId": 1,                    // ← Modbus Unit ID
  "httpPort": 4000,               // ← Web server port (leave as-is)
  "timeoutMs": 2000,
  "pollIntervalMs": 1000,
  "staticDir": ".",
  // ... rest of config (registers/tags)
}
```

**Important:** Update the `slaveHost` and `slavePort` to match your Modbus device.

#### Step 3: Install Dependencies
Open a terminal/command prompt in the HMI folder and run:

```bash
npm install
```

This downloads required Node.js packages (~3-5 MB).

#### Step 4: Start the Backend Server
```bash
npm start
```

You should see:
```
Modbus master server listening on port 4000
Target slave 192.168.1.100:502 (unit 1)
```

#### Step 5: Open the HMI
Open your web browser and navigate to:
```
http://localhost:4000/test.html
```

Click "Switch to Live" to enable Modbus communication.

---

## Running as a Service (Optional)

### Windows - Run on Startup

1. Install **PM2** (process manager):
   ```bash
   npm install -g pm2
   npm install -g pm2-windows-startup
   pm2-startup install
   ```

2. Start and save the service:
   ```bash
   cd C:\HMI\s32-hmi
   pm2 start server.js --name s32-hmi
   pm2 save
   ```

3. The HMI will now start automatically on boot.

### Windows - Manual Service

Create a batch file `start-hmi.bat`:
```batch
@echo off
cd /d "%~dp0"
start "S32 HMI Backend" cmd /k npm start
timeout /t 3
start http://localhost:4000/test.html
```

Double-click to start both server and browser.

---

## Troubleshooting

### Cannot Connect to Modbus Device
1. Check `modbus.config.json` has correct IP/port
2. Verify network connectivity: `ping <PLC_IP>`
3. Ensure firewall allows port 502 (Modbus TCP)
4. Check Modbus device is powered on and accessible

### Server Won't Start
1. Verify Node.js is installed: `node --version`
2. Reinstall dependencies: `npm install`
3. Check port 4000 is not in use by another app
4. Review error messages in the console

### Browser Shows "Comms Fault"
1. Make sure backend server is running (`npm start`)
2. Check browser console (F12) for errors
3. Verify HMI is in "Live" mode (not simulation)
4. Test server health: http://localhost:4000/healthz

### HMI Shows Old Data
1. Hard refresh browser: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
2. Clear browser cache
3. Restart backend server

---

## Port Configuration

**Default Ports:**
- Backend API: `4000` (configurable in `modbus.config.json`)
- Modbus TCP: `502` (standard, set by your PLC)

**To Change Backend Port:**
Edit `modbus.config.json`:
```json
{
  "httpPort": 8080,  // Change to desired port
  ...
}
```

Then access HMI at: `http://localhost:8080/test.html`

---

## Network Access

### Access HMI from Other Computers

1. Find the server machine's IP address:
   ```bash
   ipconfig  # Windows
   ifconfig  # Linux/Mac
   ```

2. On other computers, open:
   ```
   http://<SERVER_IP>:4000/test.html
   ```
   Example: `http://192.168.1.50:4000/test.html`

3. **Firewall:** Allow inbound connections on port 4000

---

## File Structure Reference

```
s32-hmi/
│
├── test.html              # HMI user interface (frontend)
├── server.js              # Modbus gateway server (backend)
├── package.json           # Node.js dependencies
├── modbus.config.json     # Modbus register mappings
├── README.md              # Project documentation
│
├── node_modules/          # (Created by npm install)
└── package-lock.json      # (Created by npm install)
```

---

## Security Notes

1. **Do not expose port 4000 to the internet** - This is for local networks only
2. Consider adding authentication if deploying on shared networks
3. Keep Node.js updated: `npm update`
4. Review Modbus security best practices for industrial environments

---

## Support Checklist

Before reporting issues, verify:
- [ ] Node.js version: `node --version` (should be v16+)
- [ ] NPM dependencies installed: `npm install` completed without errors
- [ ] Modbus config matches PLC: IP, port, unit ID correct
- [ ] Network connectivity: Can ping PLC from server machine
- [ ] Firewall rules: Ports 4000 (HMI) and 502 (Modbus) allowed
- [ ] Backend running: `npm start` shows "listening on port 4000"
- [ ] Browser console: Check for JavaScript errors (F12)

---

## Quick Reference

| Action | Command |
|--------|---------|
| Install dependencies | `npm install` |
| Start server | `npm start` |
| Test connection | `npm run verify` |
| Access HMI | http://localhost:4000/test.html |
| Check server health | http://localhost:4000/healthz |
| Stop server | `Ctrl+C` in terminal |

---

## License & Support

- Version: 1.0.0
- Node.js dependencies: Express, modbus-serial, cors, morgan
- For configuration changes, edit `modbus.config.json`
- For UI changes, edit `test.html`

