# S32 HMI Packaging Summary

## 📦 Quick Answer

Your HMI application can be packaged in **two ways**:

### 1. **Simulation Mode** (Standalone - Single File)
- **What to copy:** Just `test.html`
- **Size:** ~25 KB
- **Requirements:** Web browser only
- **Use case:** Demos, UI testing, offline viewing

### 2. **Live Mode** (Full Application - Modbus TCP)
- **What to copy:** See "Essential Files" below
- **Size:** ~2-5 MB (without node_modules) or ~15-25 MB (with node_modules)
- **Requirements:** Node.js + network access to Modbus device
- **Use case:** Production deployment with real PLC/device communication

---

## 🚀 Automated Packaging

I've created packaging scripts to make deployment easy:

### Windows
```powershell
# Full deployment package
.\create-deployment-package.ps1

# Simulation only (just test.html)
.\create-deployment-package.ps1 -SimulationOnly

# Include node_modules (no npm install needed on target)
.\create-deployment-package.ps1 -IncludeNodeModules

# Custom output location
.\create-deployment-package.ps1 -OutputPath "C:\Deploy\HMI"
```

### Linux/Mac
```bash
# Make script executable
chmod +x create-deployment-package.sh

# Full deployment package
./create-deployment-package.sh

# Simulation only
./create-deployment-package.sh --simulation-only

# Include node_modules
./create-deployment-package.sh --include-node-modules

# Custom output location
./create-deployment-package.sh --output /path/to/deploy
```

The scripts will create a ready-to-deploy folder with all necessary files and instructions.

---

## 📄 Essential Files for Live Mode

### Core Application (Required)
```
test.html              - Frontend HMI interface (25 KB)
server.js              - Backend Modbus gateway (12 KB)
package.json           - Node.js dependencies list (1 KB)
modbus.config.json     - Register mappings & PLC config (5 KB)
```

### Documentation (Recommended)
```
DEPLOYMENT-GUIDE.md    - Complete deployment instructions
README.md              - Project overview
```

### Dependencies (Optional - can install on target)
```
node_modules/          - Pre-installed Node.js packages (~15 MB)
package-lock.json      - Dependency version lock file
```

**Decision:** Include `node_modules` if the target machine:
- ❌ Has no internet connection (can't run `npm install`)
- ✅ Has internet → Skip node_modules, run `npm install` on target

---

## 📋 Manual Packaging Steps

If you prefer to package manually without the scripts:

### For Simulation Mode
1. Copy `test.html` to a folder
2. Zip the folder
3. Done! Unzip and open in browser on target machine

### For Live Mode
1. Create a new folder (e.g., `s32-hmi-deployment`)
2. Copy these files:
   - `test.html`
   - `server.js`
   - `package.json`
   - `modbus.config.json`
   - `DEPLOYMENT-GUIDE.md` (helpful for recipient)
3. (Optional) Copy `node_modules/` and `package-lock.json`
4. Create a ZIP archive
5. Send to target machine

---

## 🛠️ Deployment on Target Machine

### Simulation Mode
1. Unzip package
2. Double-click `test.html`
3. Works immediately in any browser!

### Live Mode - Quick Start
1. Unzip package to a folder (e.g., `C:\HMI\s32-hmi`)
2. Install Node.js if not already installed: https://nodejs.org/
3. **Edit `modbus.config.json`** → Set your PLC IP address:
   ```json
   {
     "slaveHost": "192.168.1.100",  ← Change this!
     "slavePort": 502,
     ...
   }
   ```
4. Open terminal in the folder:
   ```bash
   npm install          # If node_modules not included
   npm start            # Start the server
   ```
5. Open browser: http://localhost:4000/test.html
6. Click "Switch to Live" to enable Modbus

### Live Mode - Windows Shortcut
If you included `START-HMI.bat` (created by packaging script):
1. Double-click `START-HMI.bat`
2. Wait for "listening on port 4000"
3. Open: http://localhost:4000/test.html

---

## 🌐 Network Access

### Local Machine Only
- Access: `http://localhost:4000/test.html`
- Default setup

### Access from Other Computers
1. Find server IP: `ipconfig` (Windows) or `ifconfig` (Linux/Mac)
2. Allow port 4000 in firewall
3. Access from other PCs: `http://192.168.1.50:4000/test.html`
   (Replace with actual server IP)

---

## 📊 File Size Reference

| Package Type | Size | Transfer Method |
|--------------|------|-----------------|
| Simulation only | ~25 KB | Email, USB, cloud |
| Live (no node_modules) | ~2-5 MB | Email, USB, cloud |
| Live (with node_modules) | ~15-25 MB | USB, cloud, network share |

**Recommendation:** 
- Email/quick transfer: Don't include node_modules
- Air-gapped system: Include node_modules

---

## 🔧 Configuration Checklist for Live Mode

Before deploying to production, verify in `modbus.config.json`:

- [ ] `slaveHost` - Your PLC/device IP address
- [ ] `slavePort` - Usually 502 for Modbus TCP
- [ ] `unitId` - Modbus unit/slave ID (usually 1)
- [ ] `httpPort` - Web server port (4000 is default)
- [ ] Register addresses match your PLC memory map
- [ ] Data types (uint16, int16, etc.) match PLC configuration

---

## 🎯 Recommended Deployment Strategy

### For Demos/Training
✅ Use **Simulation Mode** → Just copy `test.html`

### For Development/Testing
✅ Use **Live Mode** without node_modules
- Smaller package
- Run `npm install` on target
- Easy to update

### For Production/Air-Gapped Systems
✅ Use **Live Mode** with node_modules included
- No internet needed on target
- Larger package but fully self-contained
- Include all documentation

### For Multiple Sites
✅ Create one master package, then:
- Copy `modbus.config.json` for each site
- Label files: `modbus.config.site1.json`, etc.
- Edit IP addresses for each location
- Deploy with site-specific config

---

## 🔒 Security Notes

- **Do NOT expose to internet** - This is for local networks only
- Configure firewall to allow only trusted IPs
- Consider VPN for remote access
- Keep Node.js and dependencies updated
- Review Modbus security best practices for industrial systems

---

## 📞 Support Materials Created

I've created these files to help with deployment:

1. **DEPLOYMENT-GUIDE.md** - Complete installation & troubleshooting guide
2. **create-deployment-package.ps1** - Windows packaging script
3. **create-deployment-package.sh** - Linux/Mac packaging script
4. **This file (PACKAGING-SUMMARY.md)** - Quick reference

---

## 🎓 Example: Complete Deployment Workflow

### Scenario: Deploying to 3 factory sites

1. **Create master package** (on development machine):
   ```powershell
   .\create-deployment-package.ps1 -IncludeNodeModules
   ```

2. **Customize for each site**:
   ```
   s32-hmi-site1/
     └── modbus.config.json → slaveHost: "192.168.1.10"
   
   s32-hmi-site2/
     └── modbus.config.json → slaveHost: "192.168.2.10"
   
   s32-hmi-site3/
     └── modbus.config.json → slaveHost: "192.168.3.10"
   ```

3. **Copy to USB drive** or network share

4. **Install at each site**:
   - Copy folder to local machine
   - Verify Node.js installed
   - Run `START-HMI.bat`
   - Test connectivity

5. **Set up as Windows service** (optional):
   ```bash
   npm install -g pm2
   pm2 start server.js --name s32-hmi
   pm2 save
   pm2 startup
   ```

---

## ✅ Quick Validation

After deployment, test these:

1. **Server health**: http://localhost:4000/healthz
   - Should return: `{"ok":true,"connected":true}`

2. **HMI loads**: http://localhost:4000/test.html
   - Should display interface

3. **Toggle mode**: Click "Switch to Live"
   - Status should show "LIVE (Modbus TCP)"

4. **Check comms**: Header should show "Modbus OK"
   - If "FAULT", check PLC connection

5. **Test write**: Enter value, click "Write Target Gen kW"
   - Should show "Write OK ✓"

---

## 🆘 Common Issues

| Problem | Solution |
|---------|----------|
| "npm not found" | Install Node.js from nodejs.org |
| "Port 4000 in use" | Change `httpPort` in modbus.config.json |
| "Cannot connect to PLC" | Check IP, firewall, PLC is powered on |
| "Write Failed" | Verify register addresses in config |
| Blank page | Hard refresh: Ctrl+Shift+R |

---

## 📈 Version Information

- **Package:** s32-hmi v1.0.0
- **Node.js Required:** v16 or higher
- **Key Dependencies:**
  - express: ^4.19.2
  - modbus-serial: ^8.0.23
  - cors: ^2.8.5

---

## Next Steps

1. ✅ Run the packaging script for your needs
2. ✅ Edit `modbus.config.json` with your PLC settings
3. ✅ Test the package on a local machine first
4. ✅ Deploy to target machine(s)
5. ✅ Keep `DEPLOYMENT-GUIDE.md` with the package for reference

**Ready to deploy!** 🚀

