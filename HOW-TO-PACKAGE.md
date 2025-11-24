# How to Package Your S32 HMI for Deployment

## Quick Start - What to Do

### Option 1: Use the Automated Script (Recommended)

**For Simulation Mode (just the HMI interface, no backend):**
```powershell
.\create-deployment-package.ps1 -SimulationOnly
```
Result: Creates a folder with just `test.html` - copy and open in any browser!

**For Live Mode (full application with Modbus backend):**
```powershell
.\create-deployment-package.ps1
```
Result: Creates a folder with all necessary files ready to deploy.

**For Live Mode with bundled dependencies (no internet needed on target):**
```powershell
.\create-deployment-package.ps1 -IncludeNodeModules
```
Result: Includes node_modules so you don't need to run `npm install` on the target machine.

---

## What Gets Packaged

### Simulation Mode
- ✅ `test.html` - Complete HMI interface with built-in simulation
- ✅ `README-SIMULATION.txt` - Quick start instructions
- **Size:** ~25 KB
- **Requires:** Just a web browser

### Full Deployment Mode  
- ✅ `test.html` - HMI interface
- ✅ `server.js` - Backend server (Modbus gateway)
- ✅ `package.json` - Node.js dependencies
- ✅ `modbus.config.json` - PLC/device configuration
- ✅ `DEPLOYMENT-GUIDE.md` - Complete deployment instructions
- ✅ `START-HMI.bat` - Windows startup script (auto-generated)
- ✅ `CONFIGURE-FIRST.txt` - Configuration reminder
- ✅ `README.md` and other documentation (if present)
- ✅ `node_modules/` (optional, if `-IncludeNodeModules` flag used)
- **Size:** 2-5 MB (or 15-25 MB with node_modules)
- **Requires:** Node.js + network access to Modbus device

---

## Step-by-Step Deployment

### To Deploy Simulation Mode

1. Run the packaging script:
   ```powershell
   .\create-deployment-package.ps1 -SimulationOnly
   ```

2. Find the created folder: `s32-hmi-deployment\`

3. Copy the entire folder to target machine (USB, email, network)

4. On target machine: Open `test.html` in any browser

5. Done! The HMI runs with simulated data.

---

### To Deploy Live Mode (Production)

1. Run the packaging script:
   ```powershell
   .\create-deployment-package.ps1
   ```

2. Find the created folder: `s32-hmi-deployment\`

3. **IMPORTANT:** Before copying, edit `s32-hmi-deployment\modbus.config.json`:
   ```json
   {
     "slaveHost": "192.168.1.100",  ← Change to your PLC IP!
     "slavePort": 502,
     "unitId": 1,
     ...
   }
   ```

4. Copy the entire folder to target machine

5. On target machine, ensure Node.js is installed:
   - Download from: https://nodejs.org/
   - Version 16 or higher

6. Open terminal/command prompt in the deployment folder

7. Install dependencies (skip if you used `-IncludeNodeModules`):
   ```bash
   npm install
   ```

8. Start the server:
   ```bash
   npm start
   ```
   Or double-click `START-HMI.bat` on Windows

9. Open browser to: http://localhost:4000/test.html

10. Click "Switch to Live" to enable Modbus communication

---

## Script Options Reference

| Option | Description | Example |
|--------|-------------|---------|
| `-SimulationOnly` | Package only test.html | `.\create-deployment-package.ps1 -SimulationOnly` |
| `-IncludeNodeModules` | Bundle node_modules (larger, no npm install needed) | `.\create-deployment-package.ps1 -IncludeNodeModules` |
| `-OutputPath` | Custom output folder | `.\create-deployment-package.ps1 -OutputPath "C:\Deploy"` |

---

## File Descriptions

| File | Purpose | Editable? |
|------|---------|-----------|
| `test.html` | HMI user interface | ❌ No (unless customizing UI) |
| `server.js` | Backend Modbus gateway | ❌ No |
| `package.json` | Node.js dependencies | ❌ No |
| `modbus.config.json` | **PLC IP, register mappings** | ✅ **YES! Edit before deploying** |
| `DEPLOYMENT-GUIDE.md` | Complete instructions | ❌ No (reference only) |
| `START-HMI.bat` | Windows startup script | ✅ Yes (if needed) |
| `CONFIGURE-FIRST.txt` | Configuration reminder | ❌ No (reference only) |

---

## Network Configuration

### Local Machine Only (Default)
- Access: `http://localhost:4000/test.html`
- No additional setup needed

### Access from Other Computers
1. Find the server machine's IP:
   ```bash
   ipconfig  # Windows
   ```

2. Allow port 4000 in Windows Firewall:
   - Control Panel → Windows Defender Firewall → Advanced Settings
   - Inbound Rules → New Rule → Port → TCP 4000 → Allow

3. From other computers, access:
   ```
   http://192.168.1.50:4000/test.html
   ```
   (Replace with actual server IP)

---

## Deployment Scenarios

### Scenario 1: Demo at Customer Site
**Recommendation:** Simulation Mode
```powershell
.\create-deployment-package.ps1 -SimulationOnly
```
- No setup required
- Works offline
- Just open test.html

### Scenario 2: Production with Internet Access
**Recommendation:** Full mode without node_modules
```powershell
.\create-deployment-package.ps1
```
- Smaller package (~2-5 MB)
- Run `npm install` on target
- Edit modbus.config.json before deploying

### Scenario 3: Air-Gapped/Offline Production
**Recommendation:** Full mode with node_modules
```powershell
.\create-deployment-package.ps1 -IncludeNodeModules
```
- Larger package (~15-25 MB)
- No npm install needed
- Edit modbus.config.json before deploying
- No internet required on target

### Scenario 4: Multiple Sites
1. Create one master package
2. Make copies for each site
3. Edit `modbus.config.json` in each copy with site-specific settings
4. Deploy site-specific packages

---

## Troubleshooting

### "npm: command not found"
→ Install Node.js from https://nodejs.org/

### "Port 4000 already in use"
→ Edit `modbus.config.json`, change `"httpPort": 4000` to another port

### "Cannot connect to Modbus device"
→ Verify PLC IP address in `modbus.config.json`
→ Check network connectivity: `ping <PLC_IP>`
→ Ensure firewall allows port 502

### HMI shows "COMMS FAULT"
→ Make sure backend server is running (`npm start`)
→ Click "Switch to Live" if in simulation mode
→ Check browser console (F12) for errors

---

## Running as a Windows Service

To make the HMI start automatically on boot:

1. Install PM2:
   ```bash
   npm install -g pm2
   npm install -g pm2-windows-startup
   pm2-startup install
   ```

2. Start and save:
   ```bash
   cd C:\path\to\s32-hmi
   pm2 start server.js --name s32-hmi
   pm2 save
   ```

3. The HMI will now start on system boot

---

## Security Checklist

- [ ] Do NOT expose port 4000 to the internet
- [ ] Use only on trusted local networks
- [ ] Keep Node.js updated
- [ ] Consider VPN for remote access
- [ ] Review firewall rules
- [ ] Verify PLC security settings

---

## Additional Resources

All these files are included in your project:

1. **PACKAGING-SUMMARY.md** - Comprehensive packaging overview
2. **DEPLOYMENT-GUIDE.md** - Detailed deployment instructions and troubleshooting
3. **create-deployment-package.ps1** - Windows packaging script
4. **create-deployment-package.sh** - Linux/Mac packaging script

---

## Need Help?

1. Check **DEPLOYMENT-GUIDE.md** for detailed troubleshooting
2. Review **PACKAGING-SUMMARY.md** for more deployment scenarios
3. Test the package on a local machine before deploying to production
4. Verify all settings in `modbus.config.json` match your PLC

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│         S32 HMI DEPLOYMENT QUICK REFERENCE              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  PACKAGE FOR DEMO:                                      │
│  > .\create-deployment-package.ps1 -SimulationOnly      │
│                                                         │
│  PACKAGE FOR PRODUCTION:                                │
│  > .\create-deployment-package.ps1                      │
│                                                         │
│  EDIT BEFORE DEPLOYING:                                 │
│  - modbus.config.json (set PLC IP address)              │
│                                                         │
│  ON TARGET MACHINE:                                     │
│  1. Install Node.js (if not simulation mode)            │
│  2. npm install (if node_modules not included)          │
│  3. npm start                                           │
│  4. Open: http://localhost:4000/test.html               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

**You're all set to deploy your HMI application!** 🚀

