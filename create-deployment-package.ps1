# S32 HMI Deployment Package Creator
# This script creates a ready-to-deploy package of the HMI application

param(
    [string]$OutputPath = ".\s32-hmi-deployment",
    [switch]$SimulationOnly = $false,
    [switch]$IncludeNodeModules = $false
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   S32 HMI Deployment Package Creator" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (Test-Path $OutputPath) {
    Write-Host "Warning: Output directory exists. Removing..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $OutputPath
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
Write-Host "Created deployment directory: $OutputPath" -ForegroundColor Green
Write-Host ""

if ($SimulationOnly) {
    Write-Host "SIMULATION ONLY MODE" -ForegroundColor Magenta
    Write-Host "Creating minimal package (test.html only)..." -ForegroundColor Gray
    Write-Host ""
    
    # Copy only test.html
    Copy-Item "test.html" -Destination $OutputPath
    Write-Host "Copied: test.html" -ForegroundColor Green
    
    # Create a simple README
    $readmeText = "# S32 HMI - Simulation Mode`n`n"
    $readmeText += "This package contains the HMI interface in simulation mode.`n`n"
    $readmeText += "## Quick Start`n`n"
    $readmeText += "1. Open test.html in any web browser`n"
    $readmeText += "2. The HMI will run with simulated data`n"
    $readmeText += "3. Click 'Switch to Simulation' if not already active`n`n"
    $readmeText += "No installation or backend required!`n"
    
    Set-Content -Path "$OutputPath\README-SIMULATION.txt" -Value $readmeText
    Write-Host "Created: README-SIMULATION.txt" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "   Deployment Package Created!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Location: $OutputPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Copy the folder to the target machine"
    Write-Host "  2. Open test.html in any browser"
    Write-Host "  3. Done!"
    Write-Host ""
}
else {
    Write-Host "FULL DEPLOYMENT MODE" -ForegroundColor Magenta
    Write-Host "Creating complete package with backend..." -ForegroundColor Gray
    Write-Host ""
    
    # Core application files
    $coreFiles = @(
        "test.html",
        "server.js",
        "package.json",
        "modbus.config.json",
        "DEPLOYMENT-GUIDE.md"
    )
    
    foreach ($file in $coreFiles) {
        if (Test-Path $file) {
            Copy-Item $file -Destination $OutputPath
            Write-Host "Copied: $file" -ForegroundColor Green
        }
        else {
            Write-Host "Missing: $file (skipped)" -ForegroundColor Yellow
        }
    }
    
    # Optional documentation files
    $optionalFiles = @("README.md", "SETUP-GUIDE.md")
    
    foreach ($file in $optionalFiles) {
        if (Test-Path $file) {
            Copy-Item $file -Destination $OutputPath
            Write-Host "Copied: $file" -ForegroundColor Green
        }
    }
    
    # Copy node_modules if requested (large!)
    if ($IncludeNodeModules -and (Test-Path "node_modules")) {
        Write-Host ""
        Write-Host "Including node_modules (this may take a while)..." -ForegroundColor Yellow
        Copy-Item -Recurse "node_modules" -Destination $OutputPath
        if (Test-Path "package-lock.json") {
            Copy-Item "package-lock.json" -Destination $OutputPath
        }
        Write-Host "Copied: node_modules/" -ForegroundColor Green
        Write-Host "Copied: package-lock.json" -ForegroundColor Green
    }
    
    # Create startup batch file
    $batContent = "@echo off`r`n"
    $batContent += "echo ================================================`r`n"
    $batContent += "echo    S32 HMI - Starting Backend Server`r`n"
    $batContent += "echo ================================================`r`n"
    $batContent += "echo.`r`n`r`n"
    $batContent += "REM Check if node_modules exists`r`n"
    $batContent += "if not exist ""node_modules\"" (`r`n"
    $batContent += "    echo Installing dependencies...`r`n"
    $batContent += "    call npm install`r`n"
    $batContent += "    if errorlevel 1 (`r`n"
    $batContent += "        echo.`r`n"
    $batContent += "        echo ERROR: Failed to install dependencies`r`n"
    $batContent += "        echo Please ensure Node.js is installed`r`n"
    $batContent += "        pause`r`n"
    $batContent += "        exit /b 1`r`n"
    $batContent += "    )`r`n"
    $batContent += ")`r`n`r`n"
    $batContent += "echo.`r`n"
    $batContent += "echo Starting server...`r`n"
    $batContent += "echo.`r`n"
    $batContent += "echo Open your browser to: http://localhost:4000/test.html`r`n"
    $batContent += "echo Press Ctrl+C to stop the server`r`n"
    $batContent += "echo.`r`n`r`n"
    $batContent += "node server.js`r`n"
    $batContent += "pause`r`n"
    
    Set-Content -Path "$OutputPath\START-HMI.bat" -Value $batContent -Encoding ASCII
    Write-Host "Created: START-HMI.bat" -ForegroundColor Green
    
    # Create configuration instructions
    $configText = "# IMPORTANT: Configure Before First Run`n`n"
    $configText += "Before starting the HMI, edit modbus.config.json to match your setup:`n`n"
    $configText += "1. Open 'modbus.config.json' in a text editor`n"
    $configText += "2. Update these settings:`n`n"
    $configText += "   ""slaveHost"": ""YOUR_PLC_IP_ADDRESS"",    (Change this!)`n"
    $configText += "   ""slavePort"": 502,                       (Usually 502 for Modbus TCP)`n"
    $configText += "   ""unitId"": 1,                            (Check your device manual)`n`n"
    $configText += "3. Save the file`n`n"
    $configText += "4. Run START-HMI.bat (Windows) or follow DEPLOYMENT-GUIDE.md for other systems`n`n"
    $configText += "For detailed instructions, see DEPLOYMENT-GUIDE.md`n"
    
    Set-Content -Path "$OutputPath\CONFIGURE-FIRST.txt" -Value $configText
    Write-Host "Created: CONFIGURE-FIRST.txt" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "   Deployment Package Created!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Location: $OutputPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Review CONFIGURE-FIRST.txt in the package"
    Write-Host "  2. Edit modbus.config.json with your PLC settings"
    Write-Host "  3. Copy the entire folder to the target machine"
    Write-Host "  4. Ensure Node.js is installed on target machine"
    
    if (-not $IncludeNodeModules) {
        Write-Host "  5. Run 'npm install' in the deployment folder"
        Write-Host "  6. Run START-HMI.bat (or 'npm start')"
    }
    else {
        Write-Host "  5. Run START-HMI.bat (dependencies included)"
    }
    
    Write-Host ""
    Write-Host "Tip: Run with -IncludeNodeModules to bundle dependencies" -ForegroundColor Cyan
    Write-Host "(no npm install needed on target, but larger package)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "For full documentation, see DEPLOYMENT-GUIDE.md" -ForegroundColor Cyan
Write-Host ""
