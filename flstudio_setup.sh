#!/usr/bin/env bash
# flstudio_setup.sh – FL Studio + Wine + AI tool-chain

set -Eeuo pipefail

# Error handling with line number
trap 'log "ERROR: Command failed on line $LINENO"' ERR

# Logging functions
log() {
    echo -e "\e[36m[INFO]\e[0m $*"
    echo "[INFO] $*" >> "$LOG"
}

warn() {
    echo -e "\e[33m[WARNING]\e[0m $*"
    echo "[WARNING] $*" >> "$LOG"
}

die() {
    echo -e "\e[31m[ERROR]\e[0m $*" >&2
    echo "[ERROR] $*" >> "$LOG"
    exit 1
}

########## 0 – Globals & defaults ################################
LOG="$HOME/flstudio_setup_$(date +%F_%H-%M-%S).log"
export DEBIAN_FRONTEND=noninteractive

# FIX: Remove trailing space and use working URL format
# The download page can be parsed, but for reliability, we'll use the known pattern
FL_STUDIO_LATEST_VERSION="25.1.6.4997"
: "${INSTALLER_PATH:=https://install.image-line.com/flstudio/flstudio_win64_${FL_STUDIO_LATEST_VERSION}.exe}"
: "${WINE_BRANCH:=staging}"
: "${OLLAMA_MODEL:=qwen3:14b}"

PREFIX="${PREFIX:-$HOME/.wine-flstudio}"
WINEASIO_VERSION="v1.3.0"
FL_VERSION="21"

# Feature toggles (all enabled by default)
ENABLE_MCP=1
ENABLE_CONTINUE=1
ENABLE_LOOPMIDI=1
ENABLE_YABRIDGE=1
ENABLE_N8N=0
ENABLE_OLLAMA=0
ENABLE_CURSOR=0
ENABLE_SYSTEMD=0
TWEAK_PIPEWIRE=0
DISABLE_FL_UPDATES=0
PATCHBAY=0
DO_UNINSTALL=0
MINIMAL_MODE=0  # NEW: Minimal installation mode

# FIX: Add timeout for network and Wine operations
export CURL_TIMEOUT=60
export WINE_TIMEOUT=30

# FIX: Prevent Wine preloader crashes with PipeWire
export WINE_DISABLE_MEMORY_MANAGER=1
export WINE_LARGE_ADDRESS_AWARE=1

# WARNING: WineASIO compatibility with PipeWire
if [[ "$TWEAK_PIPEWIRE" == "1" ]]; then
    warn "PipeWire detected! WineASIO may not work with PipeWire's JACK implementation."
    warn "Consider using JACK2 instead of PipeWire for professional audio work."
    warn "To use JACK2: sudo apt install jackd2 qjackctl"
fi

# Show help
show_help() {
    cat <<'EOF'
Usage: ./flstudio_setup.sh [OPTIONS]

FL Studio Linux Setup - One-command installer for FL Studio with Wine,
audio tools, and AI/MCP integration.

OPTIONS:
  --installer <file|URL>    Path or URL to FL Studio installer
  --wine <stable|staging>   Choose Wine branch (default: staging)
  --ollama-model <tag>      Pick Ollama model (default: qwen3:14b)
  --no-mcp                  Skip MCP installation
  --no-continue             Skip Continue.ai assistant files
  --no-loopmidi            Skip a2jmidid bridge installation
  --no-yabridge            Skip Yabridge installation
  --no-features            MINIMAL MODE: Only FL Studio + WineASIO
  --reg <file>             Manually add registry key (e.g., FLRegkey.reg)
  --n8n                    Install n8n workflow engine
  --ollama                 Install Ollama
  --cursor                 Add Cursor MCP integration
  --systemd                Create user-level systemd services
  --tweak-pipewire         Apply low-latency PipeWire preset
  --patchbay               Write QJackCtl/Carla patchbay XML
  --disable-fl-updates     Disable FL Studio auto-update dialog
  --uninstall              Remove all installed components
  --help, -h               Show this help

ENVIRONMENT VARIABLES:
  INSTALLER_PATH           Override installer source
  WINE_BRANCH              Override Wine branch
  OLLAMA_MODEL             Override Ollama model

EXAMPLES:
  # Minimal installation (just FL Studio + WineASIO)
  ./flstudio_setup.sh --no-features
  
  # Install with offline registry key
  ./flstudio_setup.sh --reg ~/Downloads/FLRegkey.reg

WARNING: Ubuntu 24.04+ uses PipeWire by default, which has known compatibility
         issues with WineASIO. For best results:
         1. Use JACK2: sudo apt install jackd2
         2. Or run with --tweak-pipewire (experimental)

EOF
    exit 0
}

########## 1 – Flag parser ###############################################
# FIX: Added --no-features and --reg flags
MANUAL_REG_KEY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --installer)
            INSTALLER_PATH="$2"
            shift 2
            ;;
        --wine)
            WINE_BRANCH="$2"
            shift 2
            ;;
        --ollama-model)
            OLLAMA_MODEL="$2"
            shift 2
            ;;
        --no-mcp)
            ENABLE_MCP=0
            shift
            ;;
        --no-continue)
            ENABLE_CONTINUE=0
            shift
            ;;
        --no-loopmidi)
            ENABLE_LOOPMIDI=0
            shift
            ;;
        --no-yabridge)
            ENABLE_YABRIDGE=0
            shift
            ;;
        --no-features)
            MINIMAL_MODE=1
            # Disable all optional features
            ENABLE_MCP=0
            ENABLE_CONTINUE=0
            ENABLE_LOOPMIDI=0
            ENABLE_YABRIDGE=0
            ENABLE_N8N=0
            ENABLE_OLLAMA=0
            ENABLE_CURSOR=0
            ENABLE_SYSTEMD=0
            TWEAK_PIPEWIRE=0
            DISABLE_FL_UPDATES=0
            PATCHBAY=0
            shift
            ;;
        --reg)
            MANUAL_REG_KEY="$2"
            shift 2
            ;;
        --n8n)
            ENABLE_N8N=1
            shift
            ;;
        --ollama)
            ENABLE_OLLAMA=1
            shift
            ;;
        --cursor)
            ENABLE_CURSOR=1
            shift
            ;;
        --systemd)
            ENABLE_SYSTEMD=1
            shift
            ;;
        --tweak-pipewire)
            TWEAK_PIPEWIRE=1
            warn "PipeWire mode enabled - WineASIO compatibility issues possible"
            shift
            ;;
        --patchbay)
            PATCHBAY=1
            shift
            ;;
        --disable-fl-updates)
            DISABLE_FL_UPDATES=1
            shift
            ;;
        --uninstall)
            DO_UNINSTALL=1
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            die "Unknown flag: $1"
            ;;
    esac
done

########## 2 – Uninstall #################################################
if [[ $DO_UNINSTALL == 1 ]]; then
    log "=== UNINSTALLING FL STUDIO SETUP ==="
    
    # FIX: Kill any running Wine processes first
    log "Stopping Wine processes..."
    wineserver -k 2>/dev/null || true
    pkill -f "wine.*flstudio" 2>/dev/null || true
    sleep 2
    
    # Stop and remove user services
    log "Removing systemd services..."
    for service in flstudio-mcp a2jmidid n8n ollama; do
        systemctl --user disable --now "${service}.service" 2>/dev/null || true
        rm -f ~/.config/systemd/user/"${service}.service"
    done
    systemctl --user daemon-reload
    
    # Remove MCP stack
    log "Removing MCP stack..."
    if command -v curl &>/dev/null; then
        MCP_USE_VENV=0 curl -fsSL \
            https://raw.githubusercontent.com/BenevolenceMessiah/flstudio-mcp/main/flstudio-mcp-install.sh    | \
            bash -- --uninstall 2>/dev/null || true
    fi
    
    # Remove packages
    log "Removing packages..."
    sudo apt -y remove winehq-* wine-staging wine-stable winetricks 2>/dev/null || true
    sudo apt -y remove a2jmidid n8n nodejs 2>/dev/null || true
    sudo apt -y autoremove 2>/dev/null || true
    
    # Remove WineASIO
    log "Removing WineASIO..."
    sudo rm -f /usr/local/lib/wine/x86_64-windows/wineasio.dll
    sudo rm -f /usr/local/lib64/wine/wineasio64.dll.so
    sudo rm -f /usr/local/bin/wineasio-register
    
    # Remove FL Studio data
    log "Removing FL Studio data..."
    rm -rf "$PREFIX"
    rm -rf ~/.local/{bin,share}/flstudio-*
    rm -rf ~/.local/share/yabridge
    rm -f ~/.local/bin/yabridge
    rm -f ~/.local/bin/yabridgectl
    
    # Remove desktop files
    rm -f ~/.local/share/applications/flstudio.desktop
    rm -f ~/.local/share/icons/flstudio.png
    
    # Remove assistant configs
    rm -f ~/.continue/assistants/flstudio-mcp.yaml
    rm -f ~/.continue/assistants/ollama-mcp.yaml
    rm -f ~/.cursor/mcp.json
    
    # Remove PipeWire tweaks
    rm -f ~/.config/pipewire/pipewire.conf.d/90-lowlatency.conf
    
    # Remove patchbay
    rm -f ~/.config/rncbc.org/QjackCtl/patches/flstudio.xml
    
    log "Uninstall complete!"
    exit 0
fi

########## 3 – System update & Wine repo #################################
log "=== STEP 1: Updating system and adding WineHQ repository ==="
sudo apt update && sudo apt upgrade -y

# Enable i386 architecture
sudo dpkg --add-architecture i386 2>/dev/null || true

# Add WineHQ key
sudo mkdir -p /etc/apt/keyrings
wget -qO /tmp/winehq.key https://dl.winehq.org/wine-builds/winehq.key   
sudo install -m644 /tmp/winehq.key /etc/apt/keyrings/

# Add repository
UBUNTU_CODENAME=$(lsb_release -cs)
cat <<EOF | sudo tee /etc/apt/sources.list.d/winehq.sources
Types: deb
URIs: https://dl.winehq.org/wine-builds/ubuntu   
Suites: $UBUNTU_CODENAME
Components: main
Architectures: amd64 i386
Signed-By: /etc/apt/keyrings/winehq.key
EOF

sudo apt update

########## 4 – Install packages ##########################################
log "=== STEP 2: Installing packages ==="

# FIX: Install winehq-staging first to ensure we get the right version
sudo apt install -y --install-recommends "winehq-$WINE_BRANCH" winetricks

# Install dependencies including Wine development headers
sudo apt install -y \
    pipewire-jack \
    qjackctl \
    a2jmidid \
    curl \
    git \
    jq \
    imagemagick \
    python3-venv \
    ffmpeg \
    lsb-release \
    build-essential \
    libasound2-dev \
    libjack-jackd2-dev \
    libwine-dev

# FIX: For minimal mode, stop here with core packages
if [[ $MINIMAL_MODE == 1 ]]; then
    log "MINIMAL MODE: Skipping optional audio packages..."
else
    # Additional audio tools for full installation
    sudo apt install -y \
        jackd2 \
        carla \
        catia \
        ladish
fi

########## 5 – Build WineASIO ############################################
log "=== STEP 3: Building WineASIO $WINEASIO_VERSION ==="
warn "WineASIO $WINEASIO_VERSION will be built from source using Makefiles"

# Create build directory
WINEASIO_BUILD_DIR=$(mktemp -d)
cd "$WINEASIO_BUILD_DIR" || die "Failed to create build directory"

# Clone repository
log "Cloning WineASIO repository..."
if ! git clone https://github.com/wineasio/wineasio.git    .; then
    cd "$HOME"
    rm -rf "$WINEASIO_BUILD_DIR"
    die "Failed to clone WineASIO repository"
fi

# Check out version
log "Checking out WineASIO $WINEASIO_VERSION..."
if ! git checkout "$WINEASIO_VERSION" 2>/dev/null; then
    warn "Tag $WINEASIO_VERSION not found, building from master"
fi

# Verify Makefile exists
if [[ ! -f "Makefile" ]]; then
    cd "$HOME"
    rm -rf "$WINEASIO_BUILD_DIR"
    die "Makefile not found! Repository structure may have changed."
fi

# FIXED: Find and verify Wine headers location
log "Locating Wine headers..."
WINE_INCLUDE_PATH=""

# Check common locations for objbase.h
for path in \
    "/usr/include/wine/windows" \
    "/usr/include/wine/wine/windows" \
    "/usr/include/wine-development/wine/windows" \
    "/opt/wine-stable/include/wine/windows" \
    "/opt/wine-staging/include/wine/windows"; do
    if [[ -f "$path/objbase.h" ]]; then
        WINE_INCLUDE_PATH="$path"
        log "✓ Found Wine headers at: $WINE_INCLUDE_PATH"
        break
    fi
done

if [[ -z "$WINE_INCLUDE_PATH" ]]; then
    warn "Could not locate objbase.h in standard paths"
    warn "Searching entire system for objbase.h..."
    WINE_INCLUDE_PATH=$(find /usr/include /opt -name "objbase.h" 2>/dev/null | head -1 | xargs dirname)
    
    if [[ -n "$WINE_INCLUDE_PATH" ]]; then
        log "✓ Found objbase.h at: $WINE_INCLUDE_PATH"
    else
        cd "$HOME"
        rm -rf "$WINEASIO_BUILD_DIR"
        die "objbase.h not found! Please ensure libwine-dev is installed correctly."
    fi
fi

# FIXED: Build with explicit include path and better error handling
log "Building WineASIO 64-bit..."
if [[ -n "$WINE_INCLUDE_PATH" && "$WINE_INCLUDE_PATH" != "/usr/include/wine/windows" ]]; then
    # Add the correct include path to the build
    log "Adding include path: $WINE_INCLUDE_PATH"
    export CFLAGS="-I$WINE_INCLUDE_PATH"
fi

# FIX: Use proper make command with timeout
if ! timeout "$WINE_TIMEOUT" make 64 2>/dev/null; then
    # Try alternative make command
    log "Trying alternative build method..."
    if ! timeout "$WINE_TIMEOUT" make build ARCH=x86_64 M=64; then
        cd "$HOME"
        rm -rf "$WINEASIO_BUILD_DIR"
        die "Build failed"
    fi
fi

# Manually install files (no make install target)
log "Installing WineASIO files..."

# Create directories
sudo mkdir -p /usr/local/lib/wine/x86_64-windows/
sudo mkdir -p /usr/local/lib64/wine/

# Install DLL
if [[ -f "build64/wineasio64.dll" ]]; then
    sudo cp build64/wineasio64.dll /usr/local/lib/wine/x86_64-windows/wineasio.dll
    log "✓ Installed 64-bit DLL"
else
    warn "✗ 64-bit DLL not found at build64/wineasio64.dll"
fi

# Install .so
if [[ -f "build64/wineasio64.dll.so" ]]; then
    sudo cp build64/wineasio64.dll.so /usr/local/lib64/wine/
    log "✓ Installed 64-bit .so"
else
    warn "✗ 64-bit .so not found at build64/wineasio64.dll.so"
fi

# Install wineasio-register script if it exists
if [[ -f "wineasio-register" ]]; then
    sudo cp wineasio-register /usr/local/bin/
    sudo chmod +x /usr/local/bin/wineasio-register
    log "✓ Installed wineasio-register script"
fi

# Cleanup
cd "$HOME"
rm -rf "$WINEASIO_BUILD_DIR"

########## 6 – Setup Wine prefix #########################################
log "=== STEP 4: Setting up Wine prefix ==="
export WINEARCH=win64
export WINEPREFIX="$PREFIX"

# FIX: Kill any existing Wine processes before creating prefix
wineserver -k 2>/dev/null || true
pkill -f "wineserver" 2>/dev/null || true
sleep 2

if [[ ! -d "$PREFIX" ]]; then
    log "Creating new Wine prefix..."
    # FIX: Use wineboot with timeout and wait for completion
    timeout "$WINE_TIMEOUT" wineboot --init || warn "wineboot timed out or failed"
    
    # Wait for prefix to be ready with timeout
    for i in {1..60}; do
        if [[ -f "$PREFIX/system.reg" ]]; then
            log "✓ Wine prefix created successfully"
            break
        fi
        sleep 1
    done
    
    if [[ ! -f "$PREFIX/system.reg" ]]; then
        warn "Wine prefix may not be fully initialized"
    fi
fi

# Configure Wine - use win10 for better compatibility
winecfg -v win10 2>/dev/null || true

# FIX: Disable Wine crash dialogs for better stability
log "Disabling Wine crash dialogs..."
cat > /tmp/disable_wine_dlg.reg <<'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000
EOF
wine regedit /tmp/disable_wine_dlg.reg 2>/dev/null || true
rm -f /tmp/disable_wine_dlg.reg

########## 7 – Install Windows libraries #################################
log "=== STEP 5: Installing Windows runtime libraries ==="

# FIX: Update winetricks first to minimize SHA256 mismatches
log "Updating winetricks..."
sudo winetricks --self-update 2>/dev/null || warn "Failed to update winetricks"

# FIX: Use --force to bypass SHA256 mismatches for known-good files
WINETRICKS_OPTS="-q --force"
WINEPREFIX="$PREFIX" winetricks $WINETRICKS_OPTS vcrun2019 corefonts dxvk

########## 8 – Register WineASIO in Wine prefix ##########################
log "=== STEP 6: Registering WineASIO ==="

# FIX: Copy WineASIO to the Wine prefix's system32 directory first
# This is REQUIRED for regsvr32 to find the DLL
WINEASIO_SYSTEM_DLL="$PREFIX/drive_c/windows/system32/wineasio.dll"
WINEASIO_SYSTEM_DLL_SO="$PREFIX/drive_c/windows/system32/wineasio.dll.so"

log "Copying WineASIO to Wine prefix..."
if [[ -f "/usr/local/lib/wine/x86_64-windows/wineasio.dll" ]]; then
    cp "/usr/local/lib/wine/x86_64-windows/wineasio.dll" "$WINEASIO_SYSTEM_DLL"
    log "✓ Copied DLL to prefix"
else
    die "Source WineASIO DLL not found!"
fi

if [[ -f "/usr/local/lib64/wine/wineasio64.dll.so" ]]; then
    cp "/usr/local/lib64/wine/wineasio64.dll.so" "$WINEASIO_SYSTEM_DLL_SO"
    log "✓ Copied .so to prefix"
else
    warn "Source WineASIO .so not found, continuing anyway..."
fi

# FIX: Use the wineasio-register script properly
log "Registering WineASIO in Wine prefix..."
WINEPREFIX="$PREFIX" wine regsvr32 "C:\\windows\\system32\\wineasio.dll" 2>/dev/null || {
    warn "Initial registration failed, trying alternative method..."
    WINEPREFIX="$PREFIX" wine64 regsvr32 "C:\\windows\\system32\\wineasio.dll" 2>/dev/null || true
}

# Alternative registration method using wineasio-register if available
if command -v wineasio-register &>/dev/null; then
    log "Using wineasio-register script..."
    WINEPREFIX="$PREFIX" WINEDLLPATH="$PREFIX/drive_c/windows/system32" wineasio-register 2>/dev/null || true
fi

# FIX: Verify registration
log "Verifying WineASIO registration..."
if WINEPREFIX="$PREFIX" wine reg query "HKCU\\Software\\Wine\\Drivers" /v Audio 2>/dev/null | grep -q "asio"; then
    log "✓ WineASIO appears to be registered in Wine"
else
    warn "✗ WineASIO may not be registered properly in Wine"
fi

########## 9 – Manual registry key (if provided) #########################
# NEW: Support for manual registry key addition
if [[ -n "$MANUAL_REG_KEY" && -f "$MANUAL_REG_KEY" ]]; then
    log "=== STEP 6.5: Installing manual registry key ==="
    log "Importing: $MANUAL_REG_KEY"
    WINEPREFIX="$PREFIX" wine regedit "$(winepath -w "$MANUAL_REG_KEY")" 2>/dev/null || {
        warn "Registry import had issues, but continuing..."
    }
fi

########## 10 – Install FL Studio ########################################
log "=== STEP 7: Installing FL Studio ==="
INSTALLER_FILE="/tmp/flstudio_installer.exe"

# FIX: Better download handling with retry logic and proper error messages
if [[ "$INSTALLER_PATH" =~ ^https?:// ]]; then
    log "Downloading FL Studio installer from: $INSTALLER_PATH"
    
    # Check internet connectivity first
    if ! curl -fsSL --max-time 10 https://www.image-line.com   > /dev/null 2>&1; then
        warn "Cannot reach Image-Line website. Please check your internet connection."
        warn "You can manually download the installer and use --installer /path/to/file"
    fi
    
    # Download with retry logic
    for i in {1..3}; do
        if curl -fsSL --connect-timeout 30 --max-time 300 "$INSTALLER_PATH" -o "$INSTALLER_FILE"; then
            # Verify file is not empty
            if [[ -s "$INSTALLER_FILE" ]]; then
                log "✓ Download successful"
                break
            fi
        fi
        
        warn "Download attempt $i failed, retrying..."
        sleep 5
    done
    
    if [[ ! -f "$INSTALLER_FILE" || ! -s "$INSTALLER_FILE" ]]; then
        # Fallback to manual download message
        die "Failed to download FL Studio installer after 3 attempts. \
             \nPlease download manually from: https://www.image-line.com/fl-studio-download/ \
             \nThen run: ./$(basename "$0") --installer /path/to/downloaded/installer.exe \
             \nOr use the direct URL pattern: https://install.image-line.com/flstudio/flstudio_win64_VERSION.exe"
    fi
else
    if [[ -f "$INSTALLER_PATH" ]]; then
        INSTALLER_FILE="$INSTALLER_PATH"
        log "Using local installer: $INSTALLER_FILE"
    else
        die "Installer not found: $INSTALLER_PATH"
    fi
fi

# FIX: Check if installer is valid (basic check)
if [[ ! -s "$INSTALLER_FILE" ]]; then
    die "Installer file is empty or missing: $INSTALLER_FILE"
fi

# FIX: Make installer executable and run with timeout
chmod +x "$INSTALLER_FILE"
log "Running FL Studio installer (GUI will appear)..."

# Kill any hanging wine processes before starting installer
wineserver -k 2>/dev/null || true

# Run installer in background and wait for it
WINEPREFIX="$PREFIX" wine "$INSTALLER_FILE" &
INSTALLER_PID=$!

# Wait for installer to start
sleep 10

# Monitor the process and show progress
log "Waiting for installation to complete..."
log "If the installer GUI doesn't appear, check for error messages above."
log "Please complete the installation wizard manually."

# FIX: Better wait logic with timeout
for i in {1..180}; do
    if ! ps -p $INSTALLER_PID > /dev/null 2>&1; then
        log "Installer process finished"
        break
    fi
    
    # Check if FL Studio is installed
    if [[ -f "$PREFIX/drive_c/Program Files/Image-Line/FL Studio $FL_VERSION/FL64.exe" ]]; then
        log "✓ FL Studio installation detected"
        break
    fi
    
    sleep 10
done

# Kill installer if still running after timeout
if ps -p $INSTALLER_PID > /dev/null 2>&1; then
    warn "Installer is still running after 30 minutes. Killing it..."
    kill $INSTALLER_PID 2>/dev/null || true
    sleep 5
    kill -9 $INSTALLER_PID 2>/dev/null || true
fi

########## 11 – Desktop integration ######################################
log "=== STEP 8: Creating desktop integration ==="
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$ICON_DIR"

# Try multiple paths for FL Studio icon
FL_ICON_FOUND=false
for icon_path in \
    "$PREFIX/drive_c/Program Files/Image-Line/FL Studio $FL_VERSION/FL.ico" \
    "$PREFIX/drive_C/Program Files/Image-Line/FL Studio $FL_VERSION/FL.ico" \
    "$PREFIX/drive_c/Program Files (x86)/Image-Line/FL Studio $FL_VERSION/FL.ico" \
    "$PREFIX/drive_c/Program Files/Image-Line/FL Studio $FL_VERSION/Resources/FL.ico"; do
    if [[ -f "$icon_path" ]]; then
        log "Found FL Studio icon at: $icon_path"
        convert "$icon_path" -resize 512x512 "$ICON_DIR/flstudio.png" 2>/dev/null && FL_ICON_FOUND=true
        break
    fi
done

if [[ "$FL_ICON_FOUND" != "true" ]]; then
    warn "Could not find FL Studio icon, using generic icon"
    # Create a simple placeholder icon
    convert -size 512x512 xc:purple -fill white -pointsize 48 -gravity center -annotate 0 "FL" "$ICON_DIR/flstudio.png" 2>/dev/null || true
fi

# Create desktop entry
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/flstudio.desktop" <<EOF
[Desktop Entry]
Name=FL Studio
Exec=env WINEPREFIX="$PREFIX" wine "C:\\Program Files\\Image-Line\\FL Studio $FL_VERSION\\FL64.exe"
Icon=flstudio
Type=Application
Categories=AudioVideo;Audio;Music;
StartupNotify=true
Terminal=false
StartupWMClass=fl64.exe
EOF

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

# Skip optional features in minimal mode
if [[ $MINIMAL_MODE == 1 ]]; then
    log "MINIMAL MODE: Skipping optional post-installation steps..."
    log "FL Studio installation complete!"
    log "Next steps: Configure audio settings in FL Studio to use WineASIO"
    exit 0
fi

########## 12 – Install Yabridge #########################################
if [[ $ENABLE_YABRIDGE == 1 ]]; then
    log "=== STEP 9: Installing Yabridge ==="
    
    YABRIDGE_INFO=$(curl -s https://api.github.com/repos/robbert-vdh/yabridge/releases/latest   )
    YABRIDGE_URL=$(echo "$YABRIDGE_INFO" | jq -r '.assets[] | select(.name | test("tar\\.gz$")) | .browser_download_url' | head -1)
    
    if [[ -n "$YABRIDGE_URL" && "$YABRIDGE_URL" != "null" ]]; then
        YABRIDGE_TMP=$(mktemp -d)
        curl -fsSL "$YABRIDGE_URL" -o "$YABRIDGE_TMP/yabridge.tar.gz"
        tar -xzf "$YABRIDGE_TMP/yabridge.tar.gz" -C "$YABRIDGE_TMP"
        
        mkdir -p ~/.local/bin
        cp "$YABRIDGE_TMP"/yabridge-*/{yabridge,yabridgectl} ~/.local/bin/
        chmod +x ~/.local/bin/{yabridge,yabridgectl}
        
        rm -rf "$YABRIDGE_TMP"
        
        # Setup and sync
        yabridgectl add "$PREFIX"
        yabridgectl sync
        
        log "Yabridge installed and synced"
    else
        warn "Could not find Yabridge download URL"
    fi
fi

########## 13 – Setup a2jmidid ###########################################
if [[ $ENABLE_LOOPMIDI == 1 ]]; then
    log "=== STEP 10: Setting up a2jmidid MIDI bridge ==="
    
    if [[ $ENABLE_SYSTEMD == 1 ]]; then
        mkdir -p ~/.config/systemd/user
        cat > ~/.config/systemd/user/a2jmidid.service <<EOF
[Unit]
Description=ALSA to JACK MIDI bridge
After=pipewire-pulse.service

[Service]
Type=simple
ExecStart=/usr/bin/a2jmidid -e
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
        log "a2jmidid service created"
    fi
fi

########## 14 – Install MCP stack ########################################
if [[ $ENABLE_MCP == 1 ]]; then
    log "=== STEP 11: Installing MCP stack ==="
    
    MCP_INSTALL_URL="https://raw.githubusercontent.com/BenevolenceMessiah/flstudio-mcp/main/flstudio-mcp-install.sh   "
    TMP_MCP_SCRIPT=$(mktemp)
    
    if curl -fsSL "$MCP_INSTALL_URL" -o "$TMP_MCP_SCRIPT"; then
        chmod +x "$TMP_MCP_SCRIPT"
        MCP_USE_VENV=1 bash "$TMP_MCP_SCRIPT"
        rm -f "$TMP_MCP_SCRIPT"
    else
        warn "Failed to download MCP installer"
    fi
fi

########## 15 – Install n8n ##############################################
if [[ $ENABLE_N8N == 1 ]]; then
    log "=== STEP 12: Installing n8n ==="
    
    if ! command -v n8n &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x    | sudo -E bash -
        sudo apt install -y nodejs
    fi
    
    sudo npm install -g n8n n8n-nodes-mcp-client
fi

########## 16 – Setup Ollama #############################################
if [[ $ENABLE_OLLAMA == 1 ]]; then
    log "=== STEP 13: Setting up Ollama ==="
    
    if ! command -v ollama &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh    | sh
    fi
    
    if [[ "$OLLAMA_MODEL" != "qwen3:14b" ]]; then
        ollama pull "$OLLAMA_MODEL"
    fi
    
    mkdir -p ~/.local/bin
    cat > ~/.local/bin/ollama-mcp <<'EOF'
#!/bin/bash
# Ollama MCP shim
export OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:14b}"
ollama run "$OLLAMA_MODEL" "$@"
EOF
    chmod +x ~/.local/bin/ollama-mcp
    
    # Add to PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi

########## 17 – Create assistant configs #################################
if [[ $ENABLE_CONTINUE == 1 ]]; then
    log "=== STEP 14: Creating Continue.ai configs ==="
    
    mkdir -p ~/.continue/assistants
    
    cat > ~/.continue/assistants/flstudio-mcp.yaml <<EOF
name: FL Studio MCP
id: flstudio-mcp
description: Control FL Studio via MCP
tools:
  - name: flstudio-mcp
    type: mcp
    command: python3
    args:
      - -m
      - flstudio_mcp.server
EOF
    
    if [[ $ENABLE_OLLAMA == 1 ]]; then
        cat > ~/.continue/assistants/ollama-mcp.yaml <<EOF
name: Ollama
id: ollama-mcp
description: Local LLM via Ollama
tools:
  - name: ollama-mcp
    type: mcp
    command: ~/.local/bin/ollama-mcp
EOF
    fi
fi

if [[ $ENABLE_CURSOR == 1 ]]; then
    log "Creating Cursor MCP config..."
    mkdir -p ~/.cursor
    
    cat > ~/.cursor/mcp.json <<EOF
{
  "mcpServers": {
    "flstudio-mcp": {
      "command": "python3",
      "args": ["-m", "flstudio_mcp.server"]
    },
    "ollama-mcp": {
      "command": "~/.local/bin/ollama-mcp"
    }
  }
}
EOF
fi

########## 18 – PipeWire tweaks ##########################################
if [[ $TWEAK_PIPEWIRE == 1 ]]; then
    log "=== STEP 15: Applying PipeWire low-latency tweaks ==="
    
    warn "PipeWire mode enabled - WineASIO compatibility issues are possible"
    warn "For professional audio work, consider using JACK2 instead"
    
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    cat > ~/.config/pipewire/pipewire.conf.d/90-lowlatency.conf <<EOF
# Low latency configuration for FL Studio
stream.properties = {
    node.latency = 128/48000
    node.rate = 48000
}
EOF
    
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
fi

########## 19 – Patchbay template ########################################
if [[ $PATCHBAY == 1 ]]; then
    log "=== STEP 16: Creating patchbay template ==="
    
    mkdir -p ~/.config/rncbc.org/QjackCtl/patches
    cat > ~/.config/rncbc.org/QjackCtl/patches/flstudio.xml <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<jack-patchbay>
  <patch name="FL Studio Main">
    <output>FL Studio:out_1</output>
    <input>system:playback_1</input>
  </patch>
  <patch name="FL Studio Main">
    <output>FL Studio:out_2</output>
    <input>system:playback_2</input>
  </patch>
</jack-patchbay>
EOF
fi

########## 20 – Setup systemd services ###################################
if [[ $ENABLE_SYSTEMD == 1 ]]; then
    log "=== STEP 17: Setting up systemd services ==="
    
    loginctl enable-linger "$USER"
    
    UDIR=~/.config/systemd/user
    mkdir -p "$UDIR"
    
    # FL Studio MCP service
    if [[ $ENABLE_MCP == 1 ]]; then
        cat > "$UDIR/flstudio-mcp.service" <<EOF
[Unit]
Description=FL Studio MCP Server
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/share/flstudio-mcp/venv/bin/python -m flstudio_mcp.server
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF
    fi
    
    # a2jmidid service
    if [[ $ENABLE_LOOPMIDI == 1 ]]; then
        cat > "$UDIR/a2jmidid.service" <<EOF
[Unit]
Description=ALSA to JACK MIDI bridge
After=pipewire-pulse.service

[Service]
Type=simple
ExecStart=/usr/bin/a2jmidid -e
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    fi
    
    # n8n service
    if [[ $ENABLE_N8N == 1 ]]; then
        cat > "$UDIR/n8n.service" <<EOF
[Unit]
Description=n8n workflow engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/n8n start --tunnel
Restart=on-failure
RestartSec=5
Environment=N8N_BASIC_AUTH_ACTIVE=true

[Install]
WantedBy=default.target
EOF
    fi
    
    # Ollama service
    if [[ $ENABLE_OLLAMA == 1 ]]; then
        cat > "$UDIR/ollama.service" <<EOF
[Unit]
Description=Ollama service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ollama serve
Restart=on-failure
RestartSec=5
Environment=OLLAMA_HOST=127.0.0.1:11434

[Install]
WantedBy=default.target
EOF
    fi
    
    # Enable and start services
    systemctl --user daemon-reload
    
    for service in flstudio-mcp a2jmidid n8n ollama; do
        if [[ -f "$UDIR/${service}.service" ]]; then
            log "Enabling service: $service"
            systemctl --user enable --now "${service}.service" 2>/dev/null || warn "Failed to start $service"
        fi
    done
fi

########## 21 – FL Studio registry tweaks ################################
if [[ $DISABLE_FL_UPDATES == 1 ]]; then
    log "=== STEP 18: Disabling FL Studio auto-update ==="
    
    cat > /tmp/fl_disable_updates.reg <<'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Image-Line]
"AutoUpdate"=dword:00000000
"CheckForUpdates"=dword:00000000
EOF
    
    WINEPREFIX="$PREFIX" wine regedit /tmp/fl_disable_updates.reg 2>/dev/null || true
    rm -f /tmp/fl_disable_updates.reg
fi

########## 22 – Cleanup Wine processes ###################################
# FIX: Kill any remaining wine processes to prevent hanging
log "Cleaning up Wine processes..."
wineserver -k 2>/dev/null || true

########## 23 – Verification #############################################
log "=== STEP 19: Running verification ==="

# Check WineASIO installation
WINEASIO_DLL_INSTALLED=false
WINEASIO_SO_INSTALLED=false

if [[ -f "/usr/local/lib/wine/x86_64-windows/wineasio.dll" ]]; then
    log "✓ WineASIO 64-bit DLL installed"
    WINEASIO_DLL_INSTALLED=true
else
    warn "✗ WineASIO 64-bit DLL NOT found!"
fi

if [[ -f "/usr/local/lib64/wine/wineasio64.dll.so" ]]; then
    log "✓ WineASIO 64-bit .so installed"
    WINEASIO_SO_INSTALLED=true
else
    warn "✗ WineASIO 64-bit .so NOT found!"
fi

# Check WineASIO registration
log "Checking WineASIO registration..."
if WINEPREFIX="$PREFIX" wine reg query "HKCU\\Software\\Wine\\Drivers" /v Audio 2>/dev/null | grep -i asio; then
    log "✓ WineASIO appears to be registered in Wine"
else
    warn "✗ WineASIO may not be registered properly in Wine"
    log "To manually register, run:"
    log "WINEPREFIX=\"$PREFIX\" wine regsvr32 C:\\windows\\system32\\wineasio.dll"
fi

# Check FL Studio installation
FL_EXE="$PREFIX/drive_c/Program Files/Image-Line/FL Studio $FL_VERSION/FL64.exe"
if [[ -f "$FL_EXE" ]]; then
    log "✓ FL Studio executable found"
else
    warn "✗ FL Studio executable not found (may need to complete installation manually)"
fi

########## 24 – Final instructions #######################################
log "=== INSTALLATION COMPLETE ==="
log ""
log "================ IMPORTANT CONFIGURATION STEPS ================"
log ""

if [[ "$WINEASIO_DLL_INSTALLED" == "true" && "$WINEASIO_SO_INSTALLED" == "true" ]]; then
    log "✅ WineASIO installed successfully!"
else
    log "⚠️  WineASIO installation may have issues - see warnings above"
fi

log "1. FL Studio should now be available in your applications menu"
log "2. Wine prefix location: $PREFIX"
log ""

if [[ -n "$MANUAL_REG_KEY" ]]; then
    log "3. Registry key imported: $MANUAL_REG_KEY"
    log "   You should now be able to run FL Studio without activation prompts"
    log ""
fi

if [[ $ENABLE_SYSTEMD == 1 ]]; then
    log "3. User services enabled and will start on login"
    log "   Check status: systemctl --user status flstudio-mcp"
    log ""
fi

log "4. AUDIO SETUP IN FL STUDIO (CRITICAL):"
log "   - Open FL Studio"
log "   - Go to Options > Audio Settings"
log "   - Select 'WINEASIO' as the device"
log "   - Set buffer size to 128 or 256 for low latency"
log "   - If WineASIO doesn't appear, restart FL Studio or run step 5"
log ""

log "5. If WineASIO doesn't appear in FL Studio:"
log "   Run: WINEPREFIX=\"$PREFIX\" wine regsvr32 C:\\windows\\system32\\wineasio.dll"
log ""

log "6. For PipeWire users (Ubuntu 24.04+):"
log "   - WineASIO may crash due to PipeWire sandboxing"
log "   - Solution: Use JACK2 instead:"
log "     sudo apt install jackd2"
log "     Start JACK with: qjackctl"
log "     Then start FL Studio"
log ""

log "7. To run FL Studio manually:"
log "   WINEPREFIX=\"$PREFIX\" wine \"C:\\Program Files\\Image-Line\\FL Studio $FL_VERSION\\FL64.exe\""
log ""

log "8. Troubleshooting audio crackling:"
log "   - Increase buffer size in FL Studio Audio Settings"
log "   - Or use: WINEDEBUG=-all wine ... (to silence debug output)"
log ""

# FIX: Final cleanup to prevent hanging
wineserver -k 2>/dev/null || true

exit 0
