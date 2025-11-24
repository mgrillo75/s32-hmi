#!/bin/bash
# S32 HMI Deployment Package Creator (Linux/Mac)
# This script creates a ready-to-deploy package of the HMI application

OUTPUT_PATH="./s32-hmi-deployment"
SIMULATION_ONLY=false
INCLUDE_NODE_MODULES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --simulation-only)
            SIMULATION_ONLY=true
            shift
            ;;
        --include-node-modules)
            INCLUDE_NODE_MODULES=true
            shift
            ;;
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--simulation-only] [--include-node-modules] [--output PATH]"
            exit 1
            ;;
    esac
done

echo "================================================"
echo "   S32 HMI Deployment Package Creator"
echo "================================================"
echo ""

# Create output directory
if [ -d "$OUTPUT_PATH" ]; then
    echo "⚠️  Output directory exists. Removing..."
    rm -rf "$OUTPUT_PATH"
fi

mkdir -p "$OUTPUT_PATH"
echo "✓ Created deployment directory: $OUTPUT_PATH"

if [ "$SIMULATION_ONLY" = true ]; then
    echo ""
    echo "📦 SIMULATION ONLY MODE"
    echo "   Creating minimal package (test.html only)..."
    echo ""
    
    # Copy only test.html
    cp test.html "$OUTPUT_PATH/"
    
    # Create a simple README
    cat > "$OUTPUT_PATH/README-SIMULATION.txt" << 'EOF'
# S32 HMI - Simulation Mode

This package contains the HMI interface in simulation mode.

## Quick Start

1. Open test.html in any web browser
2. The HMI will run with simulated data
3. Click 'Switch to Simulation' if not already active

No installation or backend required!

EOF
    
    echo "✓ Copied: test.html"
    echo "✓ Created: README-SIMULATION.txt"
    
else
    echo ""
    echo "📦 FULL DEPLOYMENT MODE"
    echo "   Creating complete package with backend..."
    echo ""
    
    # Core application files
    CORE_FILES=(
        "test.html"
        "server.js"
        "package.json"
        "modbus.config.json"
        "DEPLOYMENT-GUIDE.md"
    )
    
    for file in "${CORE_FILES[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$OUTPUT_PATH/"
            echo "✓ Copied: $file"
        else
            echo "⚠️  Missing: $file (skipped)"
        fi
    done
    
    # Optional documentation files
    OPTIONAL_FILES=(
        "README.md"
        "SETUP-GUIDE.md"
    )
    
    for file in "${OPTIONAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$OUTPUT_PATH/"
            echo "✓ Copied: $file"
        fi
    done
    
    # Copy node_modules if requested
    if [ "$INCLUDE_NODE_MODULES" = true ] && [ -d "node_modules" ]; then
        echo ""
        echo "📦 Including node_modules (this may take a while)..."
        cp -r node_modules "$OUTPUT_PATH/"
        [ -f "package-lock.json" ] && cp package-lock.json "$OUTPUT_PATH/"
        echo "✓ Copied: node_modules/"
        echo "✓ Copied: package-lock.json"
    fi
    
    # Create startup script
    cat > "$OUTPUT_PATH/start-hmi.sh" << 'EOF'
#!/bin/bash
echo "================================================"
echo "   S32 HMI - Starting Backend Server"
echo "================================================"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo ""
        echo "ERROR: Failed to install dependencies"
        echo "Please ensure Node.js is installed"
        exit 1
    fi
fi

echo ""
echo "Starting server..."
echo ""
echo "Open your browser to: http://localhost:4000/test.html"
echo "Press Ctrl+C to stop the server"
echo ""

node server.js
EOF
    
    chmod +x "$OUTPUT_PATH/start-hmi.sh"
    echo "✓ Created: start-hmi.sh"
    
    # Create configuration instructions
    cat > "$OUTPUT_PATH/CONFIGURE-FIRST.txt" << 'EOF'
# IMPORTANT: Configure Before First Run

Before starting the HMI, edit modbus.config.json to match your setup:

1. Open 'modbus.config.json' in a text editor
2. Update these settings:

   "slaveHost": "YOUR_PLC_IP_ADDRESS",    ← Change this!
   "slavePort": 502,                       ← Usually 502 for Modbus TCP
   "unitId": 1,                            ← Check your device manual

3. Save the file

4. Run ./start-hmi.sh (Linux/Mac) or follow DEPLOYMENT-GUIDE.md for other systems

For detailed instructions, see DEPLOYMENT-GUIDE.md

EOF
    
    echo "✓ Created: CONFIGURE-FIRST.txt"
fi

echo ""
echo "================================================"
echo "   ✅ Deployment Package Created!"
echo "================================================"
echo ""
echo "Location: $OUTPUT_PATH"
echo ""

if [ "$SIMULATION_ONLY" = true ]; then
    echo "Next Steps:"
    echo "  1. Copy the folder to the target machine"
    echo "  2. Open test.html in any browser"
    echo "  3. Done!"
else
    echo "Next Steps:"
    echo "  1. Review CONFIGURE-FIRST.txt in the package"
    echo "  2. Edit modbus.config.json with your PLC settings"
    echo "  3. Copy the entire folder to the target machine"
    echo "  4. Ensure Node.js is installed on target machine"
    
    if [ "$INCLUDE_NODE_MODULES" = false ]; then
        echo "  5. Run 'npm install' in the deployment folder"
        echo "  6. Run ./start-hmi.sh (or 'npm start')"
    else
        echo "  5. Run ./start-hmi.sh (dependencies included)"
    fi
    
    echo ""
    echo "💡 Tip: Run with --include-node-modules to bundle dependencies"
    echo "   (no npm install needed on target, but larger package)"
fi

echo ""
echo "For full documentation, see DEPLOYMENT-GUIDE.md"
echo ""

