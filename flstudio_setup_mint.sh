#!/usr/bin/env bash
set -euo pipefail

# FL Studio Linux Setup Script - Linux Mint Branch
# Based on Ubuntu but maps Mint codenames to Ubuntu base versions for WineHQ compatibility

# Version: 1.0.0-mint
# Original Author: Benevolence Messiah
# Mint Branch Adaptation: Community Contribution

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Error handling
trap 'log_error "Command failed on line $LINENO"' ERR

# --- LINUX MINT DETECTION AND MAPPING ---
detect_mint_ubuntu_base() {
    local mint_codename=""
    local ubuntu_base=""
    
    # Check if this is Linux Mint
    if [[ -f /etc/linuxmint/info ]]; then
        mint_codename=$(grep "^CODENAME=" /etc/linuxmint/info | cut -d'=' -f2 | tr -d '"')
        log_info "Detected Linux Mint: $mint_codename"
    fi
    
    # Map Mint codenames to Ubuntu base versions
    case "$mint_codename" in
        wilma|xara|xia)
            ubuntu_base="noble"  # Mint 22.x based on Ubuntu 24.04
            log_info "Mapping to Ubuntu 24.04 LTS (Noble)"
            ;;
        virginia|victoria|vera|vanessa)
            ubuntu_base="jammy"  # Mint 21.x based on Ubuntu 22.04
            log_info "Mapping to Ubuntu 22.04 LTS (Jammy)"
            ;;
        ulyana|ulyssa|uma|una)
            ubuntu_base="focal"  # Mint 20.x based on Ubuntu 20.04
            log_info "Mapping to Ubuntu 20.04 LTS (Focal)"
            ;;
        "")
            # Not Linux Mint, use standard detection
            ubuntu_base="${UBUNTU_CODENAME:-}"
            ;;
        *)
            log_warning "Unknown Linux Mint version: $mint_codename"
            log_warning "Attempting to use detected Ubuntu codename"
            ubuntu_base="${UBUNTU_CODENAME:-}"
            ;;
    esac
    
    # Fallback to standard Ubuntu detection if not set
    if [[ -z "$ubuntu_base" ]]; then
        if command -v lsb_release &>/dev/null; then
            ubuntu_base=$(lsb_release -cs 2>/dev/null || echo "")
        fi
    fi
    
    echo "$ubuntu_base"
}

# --- DEFAULTS AND CONFIGURATION ---
# Detect Ubuntu base codename (handles Mint mapping)
UBUNTU_BASE_CODENAME=$(detect_mint_ubuntu_base)

# Check if detection succeeded
if [[ -z "$UBUNTU_BASE_CODENAME" ]]; then
    log_error "Could not detect Ubuntu base codename"
    log_error "Please ensure you're running a supported Ubuntu-based distribution"
    exit 1
fi

# Validate supported versions
case "$UBUNTU_BASE_CODENAME" in
    noble|jammy|focal)
        log_info "Supported Ubuntu base detected: $UBUNTU_BASE_CODENAME"
        ;;
    *)
        log_warning "Untested Ubuntu base: $UBUNTU_BASE_CODENAME"
        log_warning "This may work but has not been verified"
        ;;
esac

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINE_BRANCH="${WINE_BRANCH:-staging}"
PREFIX="${PREFIX:-$HOME/.wine-flstudio}"
FLSTUDIO_DESKTOP_FILE="$HOME/.local/share/applications/flstudio.desktop"
FLSTUDIO_ICON="$HOME/.local/share/icons/flstudio.png"
INSTALLER_PATH="${INSTALLER_PATH:-}"
REG_PATH="${REG_PATH:-}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:14b}"

# Feature flags
ENABLE_MCP=${ENABLE_MCP:-1}
ENABLE_CONTINUE=${ENABLE_CONTINUE:-1}
ENABLE_LOOPMIDI=${ENABLE_LOOPMIDI:-1}
ENABLE_YABRIDGE=${ENABLE_YABRIDGE:-1}
ENABLE_N8N=${ENABLE_N8N:-0}
ENABLE_OLLAMA=${ENABLE_OLLAMA:-0}
ENABLE_CURSOR=${ENABLE_CURSOR:-0}
ENABLE_SYSTEMD=${ENABLE_SYSTEMD:-0}
ENABLE_TWEAK_PIPEWIRE=${ENABLE_TWEAK_PIPEWIRE:-0}
ENABLE_DISABLE_FL_UPDATES=${ENABLE_DISABLE_FL_UPDATES:-0}
ENABLE_PATCHBAY=${ENABLE_PATCHBAY:-0}

# Parse command-line arguments
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
        --reg)
            REG_PATH="$2"
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
            ENABLE_MCP=0
            ENABLE_CONTINUE=0
            ENABLE_LOOPMIDI=0
            ENABLE_YABRIDGE=0
            ENABLE_N8N=0
            ENABLE_OLLAMA=0
            ENABLE_CURSOR=0
            ENABLE_SYSTEMD=0
            ENABLE_TWEAK_PIPEWIRE=0
            ENABLE_PATCHBAY=0
            shift
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
            ENABLE_TWEAK_PIPEWIRE=1
            shift
            ;;
        --patchbay)
            ENABLE_PATCHBAY=1
            shift
            ;;
        --disable-fl-updates)
            ENABLE_DISABLE_FL_UPDATES=1
            shift
            ;;
        --uninstall)
            log_info "Starting uninstallation..."
            # Uninstall logic would go here
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Help function
show_help() {
    cat << 'EOF'
FL Studio Linux Setup Script - Linux Mint Edition

Usage: ./flstudio_setup_mint.sh [OPTIONS]

OPTIONS:
    --installer <path|URL>      Path or URL to FL Studio installer
    --wine <stable|staging>     Wine branch to use (default: staging)
    --ollama-model <model>      Ollama model for MCP (default: qwen3:14b)
    --reg <path>                Path to FL Studio reg key file
    --n8n                       Install n8n workflow engine
    --ollama                    Install Ollama
    --cursor                    Configure Cursor MCP
    --systemd                   Create systemd user services
    --tweak-pipewire            Apply low-latency PipeWire tweaks
    --patchbay                  Create QJackCtl/Carla patchbay template
    --disable-fl-updates        Disable FL Studio auto-update dialog
    --no-mcp                    Skip MCP installation
    --no-continue               Skip Continue assistant setup
    --no-loopmidi               Skip a2jmidid loopMIDI bridge
    --no-yabridge               Skip Yabridge installation
    --no-features               Minimal mode: only FL Studio + WineASIO
    --uninstall                 Remove all components
    --help, -h                  Show this help message

Linux Mint Support:
    This version automatically detects Linux Mint and maps to the correct
    Ubuntu base version for WineHQ compatibility:
    - Mint 22.x (Wilma/Xara/Xia) → Ubuntu 24.04 Noble
    - Mint 21.x (Vanessa/Vera/Victoria/Virginia) → Ubuntu 22.04 Jammy
    - Mint 20.x (Ulyana/Ulyssa/Uma/Una) → Ubuntu 20.04 Focal

ENVIRONMENT VARIABLES:
    WINE_BRANCH                 Wine branch (stable|staging)
    PREFIX                      Wine prefix location
    INSTALLER_PATH              FL Studio installer path/URL
    OLLAMA_MODEL                Ollama model name
    ENABLE_N8N                  Install n8n (0/1)
    ENABLE_OLLAMA               Install Ollama (0/1)
    ENABLE_CURSOR               Configure Cursor (0/1)

Examples:
    # Minimal install on Linux Mint
    ./flstudio_setup_mint.sh --no-features

    # Full install with AI features
    ENABLE_N8N=1 ENABLE_OLLAMA=1 ./flstudio_setup_mint.sh --systemd

    # Use existing installer
    ./flstudio_setup_mint.sh --installer /path/to/flstudio.exe --reg /path/to/key.reg

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for internet connectivity
    if ! curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
        log_error "No internet connection detected"
        exit 1
    fi
    
    # Check if running on supported architecture
    if [[ "$(uname -m)" != "x86_64" ]]; then
        log_error "This script requires x86_64 architecture"
        exit 1
    fi
    
    # Check if apt is available
    if ! command -v apt &>/dev/null; then
        log_error "apt package manager not found. This script is for Debian/Ubuntu-based systems."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Add architecture i386
add_i386_architecture() {
    log_info "Enabling i386 architecture..."
    sudo dpkg --add-architecture i386
    log_success "i386 architecture enabled"
}

# Setup WineHQ repository
setup_winehq_repository() {
    log_info "Setting up WineHQ repository for Ubuntu base: $UBUNTU_BASE_CODENAME"
    
    # Create keyrings directory
    sudo mkdir -pm755 /etc/apt/keyrings
    
    # Download WineHQ key
    if [[ ! -f /etc/apt/keyrings/winehq-archive.key ]]; then
        log_info "Downloading WineHQ repository key..."
        sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
        log_success "WineHQ key installed"
    else
        log_info "WineHQ key already exists"
    fi
    
    # Add repository
    local repo_file="/etc/apt/sources.list.d/winehq.sources"
    if [[ ! -f "$repo_file" ]]; then
        log_info "Adding WineHQ repository..."
        sudo tee "$repo_file" > /dev/null << EOF
Types: deb
URIs: https://dl.winehq.org/wine-builds/ubuntu
Suites: $UBUNTU_BASE_CODENAME
Components: main
Architectures: amd64 i386
Signed-By: /etc/apt/keyrings/winehq-archive.key
EOF
        log_success "WineHQ repository added"
    else
        log_info "WineHQ repository already exists"
    fi
    
    # Update package lists
    log_info "Updating package lists..."
    sudo apt update
    log_success "Package lists updated"
}

# Install core packages
install_core_packages() {
    log_info "Installing core packages..."
    
    # Build package list
    local packages=(
        "winehq-$WINE_BRANCH"
        "wine:$WINE_BRANCH"
        "wine:$WINE_BRANCH-i386"
        winetricks
        wineasio
        pipewire-jack
        qjackctl
        curl
        git
        jq
        imagemagick
        python3-venv
        python3-pip
    )
    
    # Add optional packages
    if [[ "$ENABLE_LOOPMIDI" -eq 1 ]]; then
        packages+=(a2jmidid)
    fi
    
    # Install packages
    sudo apt install -y --install-recommends "${packages[@]}"
    
    log_success "Core packages installed"
}

# Setup Wine prefix
setup_wine_prefix() {
    log_info "Setting up Wine prefix at $PREFIX"
    
    export WINEPREFIX="$PREFIX"
    
    if [[ ! -d "$PREFIX" ]]; then
        log_info "Creating new Wine prefix..."
        wineserver -k 2>/dev/null || true
        rm -rf "$PREFIX"
        wineboot -i
        log_success "Wine prefix created"
    else
        log_info "Wine prefix already exists"
    fi
    
    # Configure Wine
    log_info "Configuring Wine..."
    winecfg -v win10
    
    # Install essential components
    log_info "Installing Winetricks components..."
    winetricks -q vcrun2019 corefonts dxvk
    
    log_success "Wine prefix configured"
}

# Download and install FL Studio
install_flstudio() {
    local installer_path="$1"
    
    log_info "Installing FL Studio..."
    
    if [[ -z "$installer_path" ]]; then
        # Download latest version
        log_info "Downloading latest FL Studio installer..."
        FL_STUDIO_LATEST_VERSION="25.1.6.4997"
        installer_path="/tmp/flstudio_win64_${FL_STUDIO_LATEST_VERSION}.exe"
        
        if [[ ! -f "$installer_path" ]]; then
            curl -L -o "$installer_path" \
                "https://install.image-line.com/flstudio/flstudio_win64_${FL_STUDIO_LATEST_VERSION}.exe"
        fi
    fi
    
    # Verify installer exists
    if [[ ! -f "$installer_path" ]]; then
        log_error "Installer not found: $installer_path"
        exit 1
    fi
    
    # Run installer
    log_info "Running FL Studio installer (GUI will open)..."
    export WINEPREFIX="$PREFIX"
    wine "$installer_path"
    
    # Wait for installation to complete
    log_info "Please complete the FL Studio installation in the GUI"
    log_info "Press Enter when installation is complete..."
    read -r
    
    # Create desktop entry
    create_desktop_entry
    
    # Import registry key if provided
    if [[ -n "${REG_PATH:-}" && -f "$REG_PATH" ]]; then
        log_info "Importing registry key..."
        wine regedit "$REG_PATH"
        log_success "Registry key imported"
    fi
    
    # Disable FL Studio updates if requested
    if [[ "$ENABLE_DISABLE_FL_UPDATES" -eq 1 ]]; then
        disable_fl_updates
    fi
}

# Create desktop entry
create_desktop_entry() {
    log_info "Creating desktop entry..."
    
    # Find FL Studio executable
    local fl_exe=""
    for path in "$PREFIX/drive_c/Program Files/Image-Line/FL Studio"*/FL64.exe; do
        if [[ -f "$path" ]]; then
            fl_exe="$path"
            break
        fi
    done
    
    if [[ -z "$fl_exe" ]]; then
        log_warning "Could not find FL Studio executable"
        return 1
    fi
    
    # Extract or create icon
    if [[ ! -f "$FLSTUDIO_ICON" ]]; then
        log_info "Creating icon..."
        mkdir -p "$(dirname "$FLSTUDIO_ICON")"
        # Create a simple FL icon using ImageMagick
        convert -size 512x512 xc:purple -fill white -pointsize 200 -gravity center -annotate 0 "FL" "$FLSTUDIO_ICON" 2>/dev/null || \
        cp "$SCRIPT_DIR/flstudio.png" "$FLSTUDIO_ICON" 2>/dev/null || \
        touch "$FLSTUDIO_ICON"
    fi
    
    # Create desktop file
    mkdir -p "$(dirname "$FLSTUDIO_DESKTOP_FILE")"
    cat > "$FLSTUDIO_DESKTOP_FILE" << EOF
[Desktop Entry]
Name=FL Studio
Exec=env WINEPREFIX=$PREFIX wine $(winepath -u "$fl_exe")
Icon=$FLSTUDIO_ICON
Type=Application
Categories=AudioVideo;Audio;Music;
StartupNotify=true
StartupWMClass=fl64.exe
EOF
    
    chmod +x "$FLSTUDIO_DESKTOP_FILE"
    log_success "Desktop entry created"
}

# Install Yabridge
install_yabridge() {
    if [[ "$ENABLE_YABRIDGE" -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing Yabridge..."
    
    # Check if already installed
    if command -v yabridgectl &>/dev/null; then
        log_info "Yabridge already installed, syncing..."
        yabridgectl sync
        return 0
    fi
    
    # Download latest release
    local yabridge_url="https://github.com/robbert-vdh/yabridge/releases/latest/download/yabridge.tar.gz"
    local yabridge_dir="$HOME/.local/share/yabridge"
    
    mkdir -p "$yabridge_dir"
    curl -L "$yabridge_url" | tar -xz -C "$yabridge_dir"
    
    # Install to user bin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$yabridge_dir"/yabridgectl "$HOME/.local/bin/yabridgectl"
    ln -sf "$yabridge_dir"/yabridge-host.exe "$HOME/.local/bin/yabridge-host.exe"
    
    # Add to PATH if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Sync VST plugins
    yabridgectl sync
    
    log_success "Yabridge installed and synced"
}

# Install a2jmidid (LoopMIDI bridge)
install_a2jmidid() {
    if [[ "$ENABLE_LOOPMIDI" -eq 0 ]]; then
        return 0
    fi
    
    log_info "Setting up ALSA-to-JACK MIDI bridge..."
    
    # Create user service
    if [[ "$ENABLE_SYSTEMD" -eq 1 ]]; then
        mkdir -p "$HOME/.config/systemd/user"
        cat > "$HOME/.config/systemd/user/a2jmidid.service" << EOF
[Unit]
Description=ALSA-to-JACK MIDI bridge (LoopMIDI)
After=pipewire.service

[Service]
ExecStart=/usr/bin/a2jmidid -e
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
        
        systemctl --user enable --now a2jmidid.service
        log_success "a2jmidid service enabled"
    else
        log_info "To start a2jmidid manually: a2jmidid -e"
    fi
}

# Install MCP stack
install_mcp() {
    if [[ "$ENABLE_MCP" -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing MCP stack..."
    
    # Create Python virtual environment
    local mcp_dir="$HOME/.local/share/flstudio-mcp"
    local venv_dir="$mcp_dir/venv"
    
    mkdir -p "$mcp_dir"
    
    if [[ ! -d "$venv_dir" ]]; then
        python3 -m venv "$venv_dir"
    fi
    
    # Activate and install dependencies
    source "$venv_dir/bin/activate"
    pip install --upgrade pip
    
    # Install flstudio-mcp and dependencies
    pip install fastmcp python-rtmidi mido librosa numpy
    
    log_success "MCP stack installed"
}

# Main installation sequence
main() {
    log_info "=== FL Studio Linux Setup - Linux Mint Edition ==="
    log_info "Detected Ubuntu base: $UBUNTU_BASE_CODENAME"
    log_info "Wine branch: $WINE_BRANCH"
    log_info "Wine prefix: $PREFIX"
    
    # Check prerequisites
    check_prerequisites
    
    # Add i386 architecture
    add_i386_architecture
    
    # Setup WineHQ repository
    setup_winehq_repository
    
    # Install core packages
    install_core_packages
    
    # Setup Wine prefix
    setup_wine_prefix
    
    # Install FL Studio
    install_flstudio "$INSTALLER_PATH"
    
    # Install optional components
    install_yabridge
    install_a2jmidid
    install_mcp
    
    log_success "=== Installation complete! ==="
    log_info "FL Studio should now be available in your applications menu"
    log_info "If not, run: env WINEPREFIX=$PREFIX wine $(find "$PREFIX" -name "FL64.exe" 2>/dev/null | head -1)"
}

# Run main function
main "$@"
