#!/usr/bin/env bash
# flstudio_setup.sh – Production-ready FL Studio + WineASIO setup for Ubuntu & Linux Mint
# Version: 2.1.2 (Production Fix Release)
# Tested on: Ubuntu 22.04 LTS, 24.04 LTS, Linux Mint 20.x/21.x/22.x with Wine 10.x, FL Studio 21-25
# Repository: https://github.com/BenevolenceMessiah/flstudio_setup

# ============================================================================
# 0 – CRITICAL: Initialize all variables to prevent unbound variable errors
# ============================================================================

# This MUST come before set -Eeuo pipefail to avoid "unbound variable" errors
VERBOSE=${VERBOSE:-0}
DO_UNINSTALL=${DO_UNINSTALL:-0}
DO_UNINSTALL_FULL=${DO_UNINSTALL_FULL:-0}
DO_UPDATE=${DO_UPDATE:-0}
MINIMAL_MODE=${MINIMAL_MODE:-0}
ENABLE_MCP=${ENABLE_MCP:-1}
ENABLE_CONTINUE=${ENABLE_CONTINUE:-1}
ENABLE_LOOPMIDI=${ENABLE_LOOPMIDI:-1}
ENABLE_YABRIDGE=${ENABLE_YABRIDGE:-1}
ENABLE_N8N=${ENABLE_N8N:-0}
ENABLE_OLLAMA=${ENABLE_OLLAMA:-0}
ENABLE_CURSOR=${ENABLE_CURSOR:-0}
ENABLE_SYSTEMD=${ENABLE_SYSTEMD:-0}
TWEAK_PIPEWIRE=${TWEAK_PIPEWIRE:-0}
DISABLE_FL_UPDATES=${DISABLE_FL_UPDATES:-0}
PATCHBAY=${PATCHBAY:-0}
USE_KXSTUDIO=${USE_KXSTUDIO:-0}
FORCE_REINSTALL=${FORCE_REINSTALL:-0}
FORCE_REBUILD=${FORCE_REBUILD:-0}
HIDE_BROKEN_TABS=${HIDE_BROKEN_TABS:-0}
PRESERVE_PROJECTS=${PRESERVE_PROJECTS:-0}
CREATE_CMD_LAUNCHER=${CREATE_CMD_LAUNCHER:-0}
NO_TIMEOUT=${NO_TIMEOUT:-0}
AUDIO_SAMPLE_RATE=${AUDIO_SAMPLE_RATE:-48000}
AUDIO_BUFFER_SIZE=${AUDIO_BUFFER_SIZE:-256}
MANUAL_REG_KEY=${MANUAL_REG_KEY:-}
INSTALLER_PATH=${INSTALLER_PATH:-}
WINE_BRANCH=${WINE_BRANCH:-}
OLLAMA_MODEL=${OLLAMA_MODEL:-}
PREFIX=${PREFIX:-}
WINE_TIMEOUT=${WINE_TIMEOUT:-}
CURL_TIMEOUT=${CURL_TIMEOUT:-}
WINE_CMD=${WINE_CMD:-wine}
WINEDEBUG=${WINEDEBUG:--all}
DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}

# Now safe to enable strict error checking
set -Eeuo pipefail

# ============================================================================
# 1 – MODULAR FLAG PARSER (MUST BE FIRST)
# ============================================================================

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --installer) INSTALLER_PATH="$2"; shift 2 ;;
            --wine) WINE_BRANCH="$2"; shift 2 ;;
            --sample-rate) AUDIO_SAMPLE_RATE="$2"; shift 2 ;;
            --buffer-size) AUDIO_BUFFER_SIZE="$2"; shift 2 ;;
            --audio-interface) AUDIO_INTERFACE="$2"; shift 2 ;;
            --ollama-model) OLLAMA_MODEL="$2"; shift 2 ;;
            --no-mcp) ENABLE_MCP=0; shift ;;
            --no-continue) ENABLE_CONTINUE=0; shift ;;
            --no-loopmidi) ENABLE_LOOPMIDI=0; shift ;;
            --no-yabridge) ENABLE_YABRIDGE=0; shift ;;
            --no-features) MINIMAL_MODE=1; ENABLE_MCP=0; ENABLE_CONTINUE=0; ENABLE_LOOPMIDI=0; ENABLE_YABRIDGE=0; 
                           ENABLE_N8N=0; ENABLE_OLLAMA=0; ENABLE_CURSOR=0; ENABLE_SYSTEMD=0; TWEAK_PIPEWIRE=0; 
                           PATCHBAY=0; DISABLE_FL_UPDATES=0; shift ;;
            --no-systemd) ENABLE_SYSTEMD=0; shift ;;
            --tweak-pipewire) TWEAK_PIPEWIRE=1; shift ;;
            --patchbay) PATCHBAY=1; shift ;;
            --disable-fl-updates) DISABLE_FL_UPDATES=1; shift ;;
            --n8n) ENABLE_N8N=1; shift ;;
            --ollama) ENABLE_OLLAMA=1; shift ;;
            --cursor) ENABLE_CURSOR=1; shift ;;
            --systemd) ENABLE_SYSTEMD=1; shift ;;
            --use-kxstudio) USE_KXSTUDIO=1; shift ;;
            --reg) MANUAL_REG_KEY="$2"; shift 2 ;;
            --hide-broken) HIDE_BROKEN_TABS=1; shift ;;
            --preserve-projects) PRESERVE_PROJECTS=1; shift ;;
            --path) CREATE_CMD_LAUNCHER=1; shift ;;
            --force-reinstall) FORCE_REINSTALL=1; shift ;;
            --force-rebuild) FORCE_REBUILD=1; shift ;;
            --no-timeout) NO_TIMEOUT=1; shift ;;
            --verbose|-v) VERBOSE=1; shift ;;
            --uninstall) DO_UNINSTALL=1; shift ;;
            --uninstall-full) DO_UNINSTALL_FULL=1; shift ;;
            --update) DO_UPDATE=1; shift ;;
            --help|-h) show_help ;;
            *) die "Unknown flag: $1 (use --help for usage)" ;;
        esac
    done
}

# ============================================================================
# 2 – ENHANCED LOGGING & GLOBALS
# ============================================================================

LOG="$HOME/flstudio_setup_$(date +%F_%H-%M-%S).log"

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\e[36m[INFO]\e[0m $*" | tee -a "$LOG"
    echo "[${timestamp}] [INFO] $*" >> "$LOG"
}

debug() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "\e[35m[DEBUG]\e[0m $*" | tee -a "$LOG"
    else
        echo "[${timestamp}] [DEBUG] $*" >> "$LOG"
    fi
}

warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\e[33m[WARNING]\e[0m $*" | tee -a "$LOG" >&2
    echo "[${timestamp}] [WARNING] $*" >> "$LOG"
}

die() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\e[31m[ERROR]\e[0m $*" | tee -a "$LOG" >&2
    echo "[${timestamp}] [ERROR] $*" >> "$LOG"
    exit 1
}

# ============================================================================
# 3 – UTILITY FUNCTIONS
# ============================================================================

run_with_timeout() {
    local timeout=$1; shift
    timeout "$timeout" "$@" || {
        local exit_code=$?
        [[ $exit_code == 124 ]] && warn "Command timed out after ${timeout}s: $*" || warn "Command failed with code $exit_code: $*"
        return $exit_code
    }
}

safe_kill() {
    local pid=$1
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

# Add a directory to PATH if it's not already there
ensure_path_entry() {
    local dir="$1"
    local shell_rc
    
    # Check if directory is already in PATH (handles various formats)
    if [[ ":$PATH:" != *":$dir:"* && ":$PATH:" != *":$dir" && "$PATH" != "$dir:"* && "$PATH" != "$dir" ]]; then
        warn "Command launcher directory '$dir' is not in your PATH"
        
        # Detect user's shell and choose appropriate config file
        case "$SHELL" in
            */zsh)
                shell_rc="$HOME/.zshrc"
                ;;
            */bash)
                shell_rc="$HOME/.bashrc"
                ;;
            */fish)
                shell_rc="$HOME/.config/fish/config.fish"
                echo "set -x PATH $dir \$PATH" >> "$shell_rc"
                log "✓ Added $dir to PATH in $shell_rc"
                log "  Please restart your terminal or run: source $shell_rc"
                return 0
                ;;
            *)
                shell_rc="$HOME/.profile"
                ;;
        esac
        
        # Add to PATH (avoid duplicates)
        echo "export PATH=\"$dir:\$PATH\"" >> "$shell_rc"
        log "✓ Added $dir to PATH in $shell_rc"
        log "  Please restart your terminal or run: source $shell_rc"
    else
        debug "✓ $dir is already in PATH"
    fi
}

install_packages() {
    local -a packages=("$@")
    for pkg in "${packages[@]}"; do
        debug "Installing: $pkg"
        if sudo apt install -y "$pkg" 2>/dev/null; then
            debug "✓ $pkg installed"
        else
            warn "✗ Failed to install $pkg (may be optional)"
        fi
    done
}

check_internet() {
    if ! curl -fsSL --max-time 10 https://www.image-line.com >/dev/null 2>&1; then
        warn "Cannot reach Image-Line website. Please check internet connection."
        return 1
    fi
    debug "✓ Internet connectivity verified"
    return 0
}

get_ubuntu_version() {
    lsb_release -rs 2>/dev/null || echo "unknown"
}

get_wine_info() {
    WINE_VERSION=$(wine --version 2>/dev/null || echo "wine not found")
    if command -v wine64 &>/dev/null; then
        WINE_CMD="wine64"
        debug "Using wine64 command (preferred for 64-bit)"
    else
        debug "Using wine command (wine64 not found)"
    fi
    debug "Wine: $WINE_VERSION, Command: $WINE_CMD"
}

# --- LINUX MINT DETECTION AND MAPPING ---
detect_mint_ubuntu_base() {
    local mint_codename=""
    local ubuntu_base=""
    
    # Check if this is Linux Mint
    if [[ -f /etc/linuxmint/info ]]; then
        mint_codename=$(grep "^CODENAME=" /etc/linuxmint/info | cut -d'=' -f2 | tr -d '"')
        log "Detected Linux Mint: $mint_codename"
    fi
    
    # Map Mint codenames to Ubuntu base versions
    case "$mint_codename" in
        wilma|xara|xia)
            ubuntu_base="noble"  # Mint 22.x based on Ubuntu 24.04
            log "Mapping to Ubuntu 24.04 LTS (Noble)"
            ;;
        virginia|victoria|vera|vanessa)
            ubuntu_base="jammy"  # Mint 21.x based on Ubuntu 22.04
            log "Mapping to Ubuntu 22.04 LTS (Jammy)"
            ;;
        ulyana|ulyssa|uma|una)
            ubuntu_base="focal"  # Mint 20.x based on Ubuntu 20.04
            log "Mapping to Ubuntu 20.04 LTS (Focal)"
            ;;
        "")
            # Not Linux Mint, use standard detection
            if command -v lsb_release &>/dev/null; then
                ubuntu_base=$(lsb_release -cs 2>/dev/null || echo "")
            fi
            ;;
        *)
            warn "Unknown Linux Mint version: $mint_codename"
            warn "Attempting to use detected Ubuntu codename"
            if command -v lsb_release &>/dev/null; then
                ubuntu_base=$(lsb_release -cs 2>/dev/null || echo "")
            fi
            ;;
    esac
    
    # Final fallback if still empty
    if [[ -z "$ubuntu_base" ]]; then
        if command -v lsb_release &>/dev/null; then
            ubuntu_base=$(lsb_release -cs 2>/dev/null || echo "")
        fi
    fi
    
    echo "$ubuntu_base"
}

wait_for_wine_prefix() {
    local prefix=$1 timeout=${2:-60}
    debug "Waiting up to ${timeout}s for Wine prefix..."
    for i in $(seq 1 "$timeout"); do
        [[ -f "$prefix/system.reg" ]] && debug "✓ Wine prefix ready" && return 0
        sleep 1
    done
    warn "Wine prefix may not be fully initialized"
    return 1
}

# ============================================================================
# 4 – SYSTEM TUNING
# ============================================================================

tune_system_for_wine() {
    debug "Applying system tuning for Wine..."
    
    if [[ -w /proc/sys/vm/legacy_va_layout ]] && [[ $(cat /proc/sys/vm/legacy_va_layout) != 0 ]]; then
        echo 0 | sudo tee /proc/sys/vm/legacy_va_layout >/dev/null 2>&1 || warn "Could not set legacy_va_layout"
    fi
    
    ulimit -s 8192 2>/dev/null || true
    ulimit -n 4096 2>/dev/null || true
    
    export WINE_DISABLE_MEMORY_MANAGER=1
    export WINE_LARGE_ADDRESS_AWARE=1
}

# ============================================================================
# 5 – HELP TEXT
# ============================================================================

show_help() {
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                   FL Studio Linux Setup - Professional Edition            ║
║                 Version 2.1.1 | Ubuntu 22.04+ & Linux Mint 20.x+          ║
╚═══════════════════════════════════════════════════════════════════════════╝

USAGE:
    ./flstudio_setup.sh [OPTIONS]

INSTALLATION:
    --installer <file|URL>    Path or URL to FL Studio installer
    --wine <stable|staging>   Wine branch (default: staging)
    --reg <file>              Manual registry key (e.g., FLRegkey.reg)
    --use-kxstudio           Use KXStudio repositories for WineASIO
    --no-timeout             Disable installer timeout
    --force-reinstall        Force reinstall even if version matches
    --force-rebuild          Rebuild WineASIO from source
    --update                 Update all components to latest versions

AUDIO CONFIGURATION:
    --sample-rate <rate>      Sample rate in Hz (default: 48000)
    --buffer-size <size>      Buffer size in samples (default: 256)
    --audio-interface <name>  Specific interface name
    --tweak-pipewire         Apply PipeWire low-latency tweaks

FEATURE TOGGLES:
    --no-features            MINIMAL MODE: Only FL Studio + WineASIO
    --no-mcp                 Skip MCP installation
    --no-continue            Skip Continue.ai assistant files
    --no-loopmidi            Skip a2jmidid bridge
    --no-yabridge            Skip Yabridge installation
    --no-systemd             Skip systemd services
    --disable-fl-updates     Disable FL Studio auto-update dialog
    --hide-broken            Hide broken WebView2 tabs (SOUNDS, HELP, GOPHER)
    --patchbay               Create QJackCtl patchbay template
    --n8n                    Install n8n workflow engine
    --ollama                 Install Ollama AI service
    --cursor                 Create Cursor IDE MCP config
    --systemd                Enable all systemd services

USER EXPERIENCE:
    --preserve-projects      Always preserve project files during uninstall
    --path                   Create 'fl-studio' command-line launcher
    --verbose|-v             Enable detailed debug output
    --help|-h               Show this help

DISTRIBUTION SUPPORT:
    • Ubuntu 24.04 LTS (Noble), 22.04 LTS (Jammy), 20.04 LTS (Focal)
    • Linux Mint 22.x (Noble), 21.x (Jammy), 20.x (Focal)
    - Automatic Mint detection maps to correct Ubuntu base for WineHQ

ENVIRONMENT VARIABLES:
    Installation Control:
        INSTALLER_PATH          Override installer source path/URL
        WINE_BRANCH             Override Wine branch (stable/staging)
        OLLAMA_MODEL            Override Ollama model (default: hf.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q8_K_XL)
        PREFIX                  Override Wine prefix location
        MANUAL_REG_KEY          Path to manual registry key file

    Audio Configuration:
        AUDIO_SAMPLE_RATE       Default sample rate (default: 48000)
        AUDIO_BUFFER_SIZE       Default buffer size (default: 256)
        WINEASIO_VERSION        Override WineASIO version (default: v1.3.0)

    Behavior & Features:
        VERBOSE                 Enable verbose output (1/0)
        MINIMAL_MODE            Skip all optional features (1/0)
        ENABLE_MCP              Install MCP stack (default: 1)
        ENABLE_CONTINUE         Create Continue.ai configs (default: 1)
        ENABLE_LOOPMIDI         Setup MIDI bridge (default: 1)
        ENABLE_YABRIDGE         Install Yabridge plugin host (default: 1)
        ENABLE_N8N              Install n8n workflows (default: 0)
        ENABLE_OLLAMA           Install Ollama AI (default: 0)
        ENABLE_CURSOR           Create Cursor MCP config (default: 0)
        ENABLE_SYSTEMD          Create systemd services (default: 0)
        TWEAK_PIPEWIRE          Apply PipeWire tweaks (default: 0)
        DISABLE_FL_UPDATES      Disable FL update checks (default: 0)
        PATCHBAY                Create patchbay template (default: 0)
        USE_KXSTUDIO            Use KXStudio repositories (default: 0)
        FORCE_REINSTALL         Force reinstallation (default: 0)
        FORCE_REBUILD           Force WineASIO rebuild (default: 0)
        HIDE_BROKEN_TABS        Hide WebView2 tabs (default: 0)
        PRESERVE_PROJECTS       Preserve projects on uninstall (default: 0)
        CREATE_CMD_LAUNCHER     Create 'fl-studio' command (default: 0)
        NO_TIMEOUT              Disable installer timeout (default: 0)

    Advanced/Timeouts:
        WINE_TIMEOUT            Wine operation timeout seconds (default: 900)
        CURL_TIMEOUT            Download timeout seconds (default: 600)
        WINE_CMD                Wine command override (default: wine)
        WINEDEBUG               Wine debug output (default: -all)
        DEBIAN_FRONTEND         APT frontend mode (default: noninteractive)
        FL_STUDIO_LATEST_VERSION Override FL Studio version (default: 25.2.0.5125)

EXAMPLES:
    # Minimal installation
    ./flstudio_setup.sh --no-features

    # Install with offline key
    ./flstudio_setup.sh --reg ~/Downloads/FLRegkey.reg

    # Install from URL with command launcher
    ./flstudio_setup.sh --installer https://example.com/flstudio.exe --path

    # Update existing installation
    ./flstudio_setup.sh --update

    # Fully uninstall but keep projects
    ./flstudio_setup.sh --uninstall --preserve-projects

    # Professional setup with custom audio
    ./flstudio_setup.sh --sample-rate 44100 --buffer-size 128 --systemd

    # Using environment variables
    VERBOSE=1 WINE_BRANCH=stable ./flstudio_setup.sh --no-features

    # Linux Mint 22.x automatic support
    ./flstudio_setup.sh --installer /path/to/flstudio.exe

IMPORTANT NOTES:
    • Browser integration automatically configured for license activation
    • Use JACK2 for best audio performance (Ubuntu 24.04+ uses PipeWire)
    • Full log saved to: ~/flstudio_setup_*.log
    • Run with --verbose for detailed debugging
    • Linux Mint users: Your distribution will be automatically detected

BUG REPORTS: https://github.com/BenevolenceMessiah/flstudio_setup/issues
EOF
    exit 0
}

# ============================================================================
# 6 – CONSTANTS & GLOBALS (Set after flag parsing)
# ============================================================================

# Re-initialize with potentially updated values after flag parsing
export DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
export WINEDEBUG="$WINEDEBUG"

# Parse flags now (variables already initialized above)
parse_flags "$@"

# Set additional global constants after flag parsing
WINE_TIMEOUT=${WINE_TIMEOUT:-900}
CURL_TIMEOUT=${CURL_TIMEOUT:-600}
TIMEOUT_ARG=$([[ $NO_TIMEOUT == 1 ]] && echo "0" || echo "$WINE_TIMEOUT")

FL_STUDIO_LATEST_VERSION="25.2.0.5125"
# FIXED: Removed extra spaces in URL construction
INSTALLER_PATH=${INSTALLER_PATH:-"https://install.image-line.com/flstudio/flstudio_win64_${FL_STUDIO_LATEST_VERSION}.exe"}
WINE_BRANCH=${WINE_BRANCH:-"staging"}
PREFIX=${PREFIX:-"$HOME/.wine-flstudio"}
OLLAMA_MODEL=${OLLAMA_MODEL:-"hf.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q8_K_XL"}

WINEASIO_VERSION="v1.3.0"
FL_VERSION="25"

# ============================================================================
# 7 – UNINSTALLER (Enhanced)
# ============================================================================

if [[ $DO_UNINSTALL == 1 || $DO_UNINSTALL_FULL == 1 ]]; then
    log "=== UNINSTALLING FL STUDIO SETUP ==="
    
    # Stop Wine processes
    log "Stopping Wine processes..."
    wineserver -k 2>/dev/null || true
    pkill -9 -f "wine.*flstudio" 2>/dev/null || true
    sleep 3
    
    # Stop systemd services
    if [[ $ENABLE_SYSTEMD == 1 ]]; then
        log "Stopping systemd services..."
        for service in flstudio-mcp a2jmidid n8n ollama; do
            systemctl --user disable --now "${service}.service" 2>/dev/null || true
            rm -f ~/.config/systemd/user/"${service}.service"
        done
        systemctl --user daemon-reload
    fi
    
    # Remove MCP stack
    log "Removing MCP stack..."
    if command -v curl &>/dev/null; then
        MCP_USE_VENV=0 curl -fsSL \
            https://raw.githubusercontent.com/BenevolenceMessiah/flstudio-mcp/main/flstudio-mcp-install.sh | \
            bash -- --uninstall 2>/dev/null || true
    fi
    
    # Prompt for Wine packages removal
    if [[ $DO_UNINSTALL_FULL == 1 ]]; then
        read -p "Also remove Wine packages? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Removing Wine packages..."
            sudo apt -y remove winehq-* wine-staging wine-stable winetricks 2>/dev/null || true
            sudo apt -y autoremove 2>/dev/null || true
        fi
    fi
    
    # Remove WineASIO
    log "Removing WineASIO..."
    sudo rm -f /usr/local/lib/wine/x86_64-windows/wineasio.dll
    sudo rm -f /usr/local/lib64/wine/wineasio64.dll.so
    sudo rm -f /usr/local/bin/wineasio-register
    sudo rm -f /usr/lib/x86_64-linux-gnu/wine/x86_64-windows/wineasio.dll
    sudo rm -f /usr/lib/x86_64-linux-gnu/wine/x86_64-unix/wineasio64.dll.so
    
    # Remove FL Studio installation
    log "Removing FL Studio installation..."
    rm -rf "$PREFIX"
    rm -f ~/.local/bin/flstudio-launcher
    rm -f ~/.local/bin/fl-studio
    rm -f ~/.local/share/applications/flstudio.desktop
    rm -f ~/.local/share/icons/flstudio.png
    
    # Remove audio configuration
    rm -f ~/.config/pipewire/pipewire.conf.d/90-lowlatency.conf
    rm -f ~/.config/rncbc.org/QjackCtl/patches/flstudio.xml
    
    # Handle user data
    FL_USER_DATA_DIR=~/Documents/Image-Line
    if [[ $PRESERVE_PROJECTS == 1 || $DO_UNINSTALL_FULL == 0 ]]; then
        if [[ -d "$FL_USER_DATA_DIR" ]]; then
            log "Preserving user projects in $FL_USER_DATA_DIR"
            log "To remove manually: rm -rf \"$FL_USER_DATA_DIR\""
        fi
    else
        log "Removing user data..."
        rm -rf "$FL_USER_DATA_DIR"
        rm -rf ~/.local/share/flstudio-*
    fi
    
    # Remove assistant configs
    rm -f ~/.continue/assistants/flstudio-mcp.yaml
    rm -f ~/.continue/assistants/ollama-mcp.yaml
    rm -f ~/.cursor/mcp.json
    
    log "✓ Uninstall complete!"
    exit 0
fi

# ============================================================================
# 8 – VERSION & UPDATE CHECK
# ============================================================================

get_installed_version() {
    local version_file="$PREFIX/flstudio_version.txt"
    [[ -f "$version_file" ]] && cat "$version_file" || echo ""
}

extract_version_from_url() {
    local url="$1"
    if [[ "$url" =~ flstudio_win64_([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.exe ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

check_for_updates() {
    log "=== VERSION CHECK ==="
    
    local installed_version installed_version_file
    installed_version_file="$PREFIX/flstudio_version.txt"
    installed_version=$(get_installed_version)
    
    local target_version
    if [[ "$INSTALLER_PATH" =~ ^https?:// ]]; then
        target_version=$(extract_version_from_url "$INSTALLER_PATH")
    else
        target_version=$(extract_version_from_url "$INSTALLER_PATH")
    fi
    
    [[ -z "$target_version" ]] && target_version="$FL_STUDIO_LATEST_VERSION"
    
    log "Installed: ${installed_version:-None}"
    log "Target: $target_version"
    
    if [[ -n "$installed_version" && "$installed_version" == "$target_version" && $FORCE_REINSTALL == 0 && $DO_UPDATE == 0 ]]; then
        log "✓ Already installed and up-to-date"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 0
    elif [[ $DO_UPDATE == 1 ]]; then
        log "Update mode enabled - proceeding with update..."
        FORCE_REINSTALL=1
        FORCE_REBUILD=1
    fi
    
    export TARGET_FL_VERSION="$target_version"
}

# ============================================================================
# 9 – MAIN INSTALLATION
# ============================================================================

log "=== FL STUDIO SETUP STARTED ==="
log "Log file: $LOG"
log "Options: WINE_BRANCH=$WINE_BRANCH, PREFIX=$PREFIX, FORCE_REINSTALL=$FORCE_REINSTALL"
log "Features: MINIMAL=$MINIMAL_MODE, KXSTUDIO=$USE_KXSTUDIO, NO_TIMEOUT=$NO_TIMEOUT"

# Detect distribution and Ubuntu base codename
UBUNTU_CODENAME=$(detect_mint_ubuntu_base)
log "Detected Ubuntu base codename: $UBUNTU_CODENAME"

# Validate detected codename
case "$UBUNTU_CODENAME" in
    noble|jammy|focal)
        log "✓ Supported Ubuntu base detected: $UBUNTU_CODENAME"
        ;;
    "")
        die "Could not detect Ubuntu base codename. Please check your distribution."
        ;;
    *)
        warn "Untested Ubuntu base: $UBUNTU_CODENAME"
        warn "This may work but has not been verified"
        ;;
esac

# System check & tuning
tune_system_for_wine

# Check required commands
for cmd in curl git make gcc; do
    command_exists "$cmd" || die "Required command not found: $cmd"
done

# Check internet
check_internet

# FIXED: Removed premature Wine check that prevented automatic installation
# Wine will be installed in STEP 1 and 2 below

# Update and upgrade system packages before installation
log "=== UPDATING SYSTEM PACKAGES ==="
sudo apt update && sudo apt upgrade -y

# ============================================================================
# 10 – WINE REPOSITORY SETUP
# ============================================================================

log "=== STEP 1: Configuring Wine repository ==="

if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
    log "Adding i386 architecture..."
    sudo dpkg --add-architecture i386
    sudo apt update
fi

if [[ ! -f /etc/apt/keyrings/winehq.key ]]; then
    log "Adding WineHQ key..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo tee /etc/apt/keyrings/winehq.key >/dev/null
fi

REPO_FILE="/etc/apt/sources.list.d/winehq.sources"
if [[ ! -f "$REPO_FILE" ]]; then
    log "Adding WineHQ repository for Ubuntu base: $UBUNTU_CODENAME"
    cat <<EOF | sudo tee "$REPO_FILE" >/dev/null
Types: deb
URIs: https://dl.winehq.org/wine-builds/ubuntu
Suites: $UBUNTU_CODENAME
Components: main
Architectures: amd64 i386
Signed-By: /etc/apt/keyrings/winehq.key
EOF
    sudo apt update
else
    debug "WineHQ repository already exists"
fi

# ============================================================================
# 11 – PACKAGE INSTALLATION
# ============================================================================

log "=== STEP 2: Installing packages ==="

# Install WineHQ if not present
if ! dpkg -l | grep -q "winehq-$WINE_BRANCH"; then
    log "Installing WineHQ $WINE_BRANCH..."
    sudo apt install -y --install-recommends "winehq-$WINE_BRANCH" winetricks
fi

# Refresh Wine info after installation
get_wine_info

# Check Wine is now available
[[ "$WINE_VERSION" == *"not found"* ]] && die "Wine installation failed! Please install Wine manually."

# Perform version check now that Wine is available
check_for_updates

# Check Ubuntu version
UBUNTU_VER=$(get_ubuntu_version)
if (( $(echo "$UBUNTU_VER >= 24.04" | bc -l) )); then
    warn "Ubuntu $UBUNTU_VER detected - PipeWire may cause WineASIO issues"
    warn "Recommended: sudo apt install jackd2 && use JACK instead of PipeWire"
fi

# Core packages
CORE_PKGS=(
    pipewire-jack qjackctl a2jmidid curl git jq imagemagick
    build-essential libasound2-dev libjack-jackd2-dev libwine-dev unzip
)

# Wine dev packages
if [[ "$WINE_VERSION" == *"Staging"* ]]; then
    CORE_PKGS+=(wine-staging-dev wine-tools)
elif [[ "$WINE_VERSION" == *"Stable"* ]]; then
    CORE_PKGS+=(wine-stable-dev wine-tools)
else
    CORE_PKGS+=(wine-staging-dev wine-tools)
fi

install_packages "${CORE_PKGS[@]}"

# Optional packages
if [[ $MINIMAL_MODE == 0 ]]; then
    OPTIONAL_PKGS=()
    (( $(echo "$UBUNTU_VER >= 24.04" | bc -l) )) || OPTIONAL_PKGS+=(catia ladish)
    OPTIONAL_PKGS+=(jackd2 carla)
    install_packages "${OPTIONAL_PKGS[@]}"
fi

# ============================================================================
# 12 – WINEASIO INSTALLATION (Enhanced)
# ============================================================================

log "=== STEP 3: Installing WineASIO $WINEASIO_VERSION ==="

# Determine WineASIO paths
WINEASIO_DLL="/usr/local/lib/wine/x86_64-windows/wineasio.dll"
WINEASIO_SO="/usr/local/lib64/wine/wineasio64.dll.so"

# Option 1: KXStudio repositories (RECOMMENDED)
if [[ $USE_KXSTUDIO == 1 ]]; then
    log "Using KXStudio repositories for WineASIO..."
    
    if [[ ! -f /etc/apt/sources.list.d/kxstudio-debian.list ]]; then
        log "Adding KXStudio repository..."
        wget -q https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_10.0.3_all.deb -O /tmp/kxstudio-repos.deb
        sudo dpkg -i /tmp/kxstudio-repos.deb || true
        sudo apt update
    fi
    
    if sudo apt install -y wineasio; then
        log "✓ WineASIO installed from KXStudio"
        WINEASIO_DLL="/usr/lib/x86_64-linux-gnu/wine/x86_64-windows/wineasio.dll"
        WINEASIO_SO="/usr/lib/x86_64-linux-gnu/wine/x86_64-unix/wineasio64.dll.so"
    else
        warn "KXStudio WineASIO failed, falling back to build method"
        USE_KXSTUDIO=0
    fi
fi

# Option 2: Build from source
if [[ $USE_KXSTUDIO == 0 ]]; then
    if [[ -f "$WINEASIO_SO" && $FORCE_REBUILD == 0 ]]; then
        log "✓ WineASIO already built (use --force-rebuild to override)"
    else
        log "Building WineASIO from source..."
        BUILD_DIR=$(mktemp -d) || die "Failed to create build directory"
        debug "Build directory: $BUILD_DIR"
        
        cd "$BUILD_DIR" || die "Failed to enter build directory"
        
        # Clone repository
        log "Cloning WineASIO repository..."
        if ! git clone --depth 1 --branch "$WINEASIO_VERSION" https://github.com/wineasio/wineasio.git .; then
            warn "Tag $WINEASIO_VERSION not found, trying master..."
            git clone --depth 1 https://github.com/wineasio/wineasio.git . || die "Failed to clone repository"
        fi
        
        # Verify files
        [[ ! -f "Makefile" || ! -f "wineasio-register" ]] && die "Repository structure invalid"
        
        # Find Wine headers
        WINE_INCLUDE=""
        for path in "/usr/include/wine/wine/windows" "/usr/include/wine-development/wine/windows" "/usr/include/wine/windows"; do
            [[ -f "$path/objbase.h" ]] && WINE_INCLUDE="$path" && debug "Found Wine headers at: $WINE_INCLUDE" && break
        done
        
        [[ -z "$WINE_INCLUDE" ]] && die "Wine headers not found. Install wine-staging-dev"
        
        # Build
        export CFLAGS="-I$WINE_INCLUDE"
        debug "Building with CFLAGS=$CFLAGS"
        if ! run_with_timeout "$WINE_TIMEOUT" make 64; then
            cd "$HOME" || true
            rm -rf "$BUILD_DIR"
            die "WineASIO build failed. Check logs: $LOG"
        fi
        
        # Verify build
        [[ ! -f "build64/wineasio64.dll.so" || ! -f "build64/wineasio64.dll" ]] && \
            die "Build failed: output files not found"
        
        # Install
        log "Installing WineASIO files..."
        sudo mkdir -p /usr/local/lib/wine/x86_64-windows/ /usr/local/lib64/wine/ /usr/local/bin/
        sudo cp build64/wineasio64.dll.so "$WINEASIO_SO"
        sudo cp build64/wineasio64.dll "$WINEASIO_DLL"
        sudo cp wineasio-register /usr/local/bin/
        sudo chmod +x /usr/local/bin/wineasio-register
        
        # Cleanup
        cd "$HOME" || true
        rm -rf "$BUILD_DIR"
        log "✓ WineASIO built and installed"
    fi
fi

# Verify files
[[ ! -f "$WINEASIO_DLL" || ! -f "$WINEASIO_SO" ]] && die "WineASIO files missing"

# ============================================================================
# 13 – WINE PREFIX SETUP
# ============================================================================

log "=== STEP 4: Setting up Wine prefix ==="

export WINEARCH=win64
export WINEPREFIX="$PREFIX"

# Kill existing processes
wineserver -k 2>/dev/null || true
sleep 2

# Remove existing prefix if forcing reinstall
if [[ $FORCE_REINSTALL == 1 && -d "$PREFIX" ]]; then
    log "Removing existing prefix for clean install..."
    rm -rf "$PREFIX"
fi

# Create prefix if needed
if [[ ! -d "$PREFIX" ]]; then
    log "Creating Wine prefix at $PREFIX..."
    mkdir -p "$PREFIX"
    
    run_with_timeout "$WINE_TIMEOUT" wineboot --init || warn "wineboot had minor issues"
    wait_for_wine_prefix "$PREFIX" 60
    
    # Configure Windows version
    winecfg -v win10 2>/dev/null || true
    
    # Disable crash dialogs
    cat > /tmp/disable_dlg.reg <<'EOF'
REGEDIT4
[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000
EOF
    wine regedit /tmp/disable_dlg.reg 2>/dev/null || true
    rm -f /tmp/disable_dlg.reg
    
    log "✓ Wine prefix created"
else
    log "Using existing Wine prefix"
fi

# Install Windows runtimes
log "=== STEP 5: Installing Windows runtime libraries ==="

# Update winetricks if old
if [[ ! -f ~/.cache/winetricks/lastupdate ]] || [[ $(find ~/.cache/winetricks/lastupdate -mtime +7 2>/dev/null) ]]; then
    log "Updating winetricks..."
    sudo winetricks --self-update 2>/dev/null || warn "Could not update winetricks"
    mkdir -p ~/.cache/winetricks
    touch ~/.cache/winetricks/lastupdate
fi

WINETRICKS_OPTS="-q --force"
for runtime in vcrun2019 vcrun2022 corefonts dxvk; do
    log "Installing $runtime..."
    if ! WINEPREFIX="$PREFIX" winetricks $WINETRICKS_OPTS "$runtime" 2>/dev/null; then
        warn "$runtime had minor issues (non-critical)"
    else
        debug "✓ $runtime installed"
    fi
done

# ============================================================================
# 14 – WINEASIO REGISTRATION (Enhanced with WINEDLLPATH)
# ============================================================================

log "=== STEP 6: Registering WineASIO ==="

WINEASIO_DST_DLL="$PREFIX/drive_c/windows/system32/wineasio.dll"
WINEASIO_DST_SO="$PREFIX/drive_c/windows/system32/wineasio64.dll.so"

# Copy to prefix
cp "$WINEASIO_DLL" "$WINEASIO_DST_DLL"
debug "DLL copied to: $WINEASIO_DST_DLL"

[[ ! -f "$WINEASIO_DST_DLL" ]] && die "Failed to copy WineASIO DLL to prefix"

# Register with multiple methods (using WINEDLLPATH fix)
log "Registering WineASIO..."
REG_SUCCESS=0

# Method 1: Direct registration with WINEDLLPATH
debug "Method 1: Direct registration with WINEDLLPATH..."
if WINEPREFIX="$PREFIX" WINEDLLPATH="$PREFIX/drive_c/windows/system32" $WINE_CMD regsvr32 "C:\\windows\\system32\\wineasio.dll" 2>&1 | tee -a "$LOG"; then
    log "✓ WineASIO registered (Method 1)"
    REG_SUCCESS=1
fi

# Method 2: wineasio-register script
if [[ $REG_SUCCESS == 0 && -x /usr/local/bin/wineasio-register ]]; then
    debug "Method 2: wineasio-register..."
    if WINEPREFIX="$PREFIX" wineasio-register 2>&1 | tee -a "$LOG"; then
        log "✓ WineASIO registered (Method 2)"
        REG_SUCCESS=1
    fi
fi

[[ $REG_SUCCESS == 0 ]] && warn "⚠ WineASIO registration may have issues"

# Verify registration
debug "Verifying WineASIO registration..."
if WINEPREFIX="$PREFIX" wine reg query "HKCU\\Software\\Wine\\Drivers" /v Audio 2>/dev/null | grep -i asio; then
    log "✓ WineASIO appears to be registered in Wine registry"
else
    warn "⚠ WineASIO may not be registered properly"
fi

# ============================================================================
# 15 – MANUAL REGISTRY KEY (if provided)
# ============================================================================

if [[ -n "$MANUAL_REG_KEY" && -f "$MANUAL_REG_KEY" ]]; then
    log "=== STEP 6.5: Installing manual registry key ==="
    log "Importing: $MANUAL_REG_KEY"
    WINEPREFIX="$PREFIX" wine regedit "$(winepath -w "$MANUAL_REG_KEY")" 2>/dev/null || {
        warn "Registry import had issues, but continuing..."
    }
fi

# ============================================================================
# 16 – INSTALL FL STUDIO
# ============================================================================

log "=== STEP 7: Installing FL Studio ==="
INSTALLER_FILE="/tmp/flstudio_installer.exe"

# Handle installer source
if [[ "$INSTALLER_PATH" =~ ^https?:// ]]; then
    if [[ ! -f "$INSTALLER_FILE" || $FORCE_REINSTALL == 1 ]]; then
        log "Downloading installer from URL (timeout: ${CURL_TIMEOUT}s)..."
        rm -f "$INSTALLER_FILE"
        
        for i in {1..3}; do
            run_with_timeout "$CURL_TIMEOUT" curl -fSL "$INSTALLER_PATH" -o "$INSTALLER_FILE" && break
            warn "Download attempt $i failed"
            sleep 5
        done
        
        [[ ! -f "$INSTALLER_FILE" || ! -s "$INSTALLER_FILE" ]] && die "Failed to download installer after 3 attempts"
        
        file_size=$(stat -c%s "$INSTALLER_FILE" 2>/dev/null || echo "0")
        [[ $file_size -lt 1000000 ]] && die "Downloaded file too small ($file_size bytes)"
        
        log "✓ Download complete ($(numfmt --to=iec-i --suffix=B "$file_size"))"
    else
        log "Using cached installer"
    fi
else
    [[ -f "$INSTALLER_PATH" ]] && INSTALLER_FILE="$INSTALLER_PATH" || die "Installer file not found: $INSTALLER_PATH"
fi

# Run installer
log "Launching FL Studio installer GUI..."
chmod +x "$INSTALLER_FILE"
WINEPREFIX="$PREFIX" $WINE_CMD "$INSTALLER_FILE" &
INSTALLER_PID=$!
sleep 10

INSTALLATION_DETECTED=0

if [[ $NO_TIMEOUT == 1 ]]; then
    log "Please complete installation wizard (no timeout - press Ctrl+C to abort)..."
    while kill -0 "$INSTALLER_PID" 2>/dev/null; do
        if [[ $INSTALLATION_DETECTED == 0 ]]; then
            if find "$PREFIX/drive_c/Program Files/Image-Line" -name "FL*.exe" 2>/dev/null | grep -q .; then
                log "✓ FL Studio installation detected (waiting for completion)..."
                INSTALLATION_DETECTED=1
            fi
        fi
        sleep 10
    done
    log "Installer process finished naturally"
else
    max_iterations=1440  # 240 minutes max
    log "Please complete installation wizard (timeout: 240 minutes)..."
    for i in $(seq 1 $max_iterations); do
        kill -0 "$INSTALLER_PID" 2>/dev/null || break
        
        if [[ $INSTALLATION_DETECTED == 0 ]]; then
            if find "$PREFIX/drive_c/Program Files/Image-Line" -name "FL*.exe" 2>/dev/null | grep -q .; then
                log "✓ FL Studio installation detected (waiting for completion)..."
                INSTALLATION_DETECTED=1
            fi
        fi
        
        sleep 10
    done
    
    if kill -0 "$INSTALLER_PID" 2>/dev/null; then
        warn "Timeout reached, killing installer..."
        safe_kill "$INSTALLER_PID"
    fi
fi

# Wait for background processes
log "Installer closed. Waiting for background Wine processes to complete..."
POST_INSTALL_WAIT=300
for i in $(seq 1 $POST_INSTALL_WAIT); do
    if pgrep -f "WINEPREFIX=$PREFIX" >/dev/null 2>&1 || pgrep -f "$PREFIX" >/dev/null 2>&1; then
        [[ $((i % 30)) == 0 ]] && debug "Background processes still running... $i/$POST_INSTALL_WAIT seconds"
    else
        log "✓ All background processes finished after $i second(s)"
        break
    fi
    sleep 1
done

sleep 5

# Save version
echo "$TARGET_FL_VERSION" > "$PREFIX/flstudio_version.txt"

# ============================================================================
# 17 – FIND FL STUDIO EXECUTABLE
# ============================================================================

log "Searching for FL Studio executable..."
FL_EXE=""
for path in "$PREFIX/drive_c/Program Files/Image-Line/FL Studio $FL_VERSION/FL64.exe" \
             "$PREFIX/drive_c/Program Files (x86)/Image-Line/FL Studio $FL_VERSION/FL64.exe"; do
    [[ -f "$path" ]] && FL_EXE="$path" && log "✓ Found: $path" && break
done

if [[ -z "$FL_EXE" ]]; then
    warn "Initial search failed, performing deep search..."
    FL_EXE=$(find "$PREFIX/drive_c" -name "FL64.exe" -type f 2>/dev/null | head -1)
    [[ -n "$FL_EXE" ]] && log "✓ Found via deep search: $FL_EXE"
fi

[[ -z "$FL_EXE" ]] && warn "⚠ Could not find FL64.exe - installation may be incomplete"

# ============================================================================
# 18 – DESKTOP INTEGRATION & LAUNCHER
# ============================================================================

log "=== STEP 8: Creating desktop integration ==="

ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"
LAUNCHER_DIR="$HOME/.local/bin"

mkdir -p "$ICON_DIR" "$DESKTOP_DIR" "$LAUNCHER_DIR"

# Remove old files
rm -f "$LAUNCHER_DIR/flstudio-launcher" "$LAUNCHER_DIR/fl-studio" \
      "$DESKTOP_DIR/flstudio.desktop" "$ICON_DIR/flstudio.png"

# Extract or create icon
ICON_PATH="$ICON_DIR/flstudio.png"
if [[ -n "$FL_EXE" && -f "$FL_EXE" ]]; then
    if command_exists wrestool && command_exists convert; then
        if wrestool -x -t 14 "$FL_EXE" 2>/dev/null | convert - -resize 512x512 "$ICON_PATH" 2>/dev/null; then
            log "✓ Extracted icon from executable"
        else
            log "Creating generic icon..."
            convert -size 512x512 xc:"#FF00FF" -fill white -gravity center -pointsize 96 -annotate 0 "FL" "$ICON_PATH" 2>/dev/null || true
        fi
    else
        log "Creating generic icon..."
        convert -size 512x512 xc:"#FF00FF" -fill white -gravity center -pointsize 96 -annotate 0 "FL" "$ICON_PATH" 2>/dev/null || true
    fi
else
    log "Creating generic icon..."
    convert -size 512x512 xc:"#FF00FF" -fill white -gravity center -pointsize 96 -annotate 0 "FL" "$ICON_PATH" 2>/dev/null || true
fi

# Create wrapper script
WRAPPER_SCRIPT="$LAUNCHER_DIR/flstudio-launcher"
log "Creating launcher script..."
WINDOWS_EXE_PATH=$(winepath -w "$FL_EXE" 2>/dev/null | sed 's/\\/\//g' || echo "C:/Program Files/Image-Line/FL Studio $FL_VERSION/FL64.exe")

cat > "$WRAPPER_SCRIPT" <<'EOWRAPPER'
#!/bin/bash
# FL Studio Launcher

export WINEPREFIX="__PREFIX_PLACEHOLDER__"
export WINEARCH=win64
export WINEDEBUG=${WINEDEBUG:--all}
export BROWSER=${BROWSER:-xdg-open}
export WINE_DISABLE_MEMORY_MANAGER=1
export WINE_LARGE_ADDRESS_AWARE=1
export PIPEWIRE_LATENCY="__BUFFER__/48000"

exec __WINE_CMD_PLACEHOLDER__ "__EXE_PATH_PLACEHOLDER__" "$@" 2>/dev/null
EOWRAPPER

sed -i "s|__PREFIX_PLACEHOLDER__|$PREFIX|g" "$WRAPPER_SCRIPT"
sed -i "s|__WINE_CMD_PLACEHOLDER__|$WINE_CMD|g" "$WRAPPER_SCRIPT"
sed -i "s|__EXE_PATH_PLACEHOLDER__|$WINDOWS_EXE_PATH|g" "$WRAPPER_SCRIPT"
sed -i "s|__BUFFER__|$AUDIO_BUFFER_SIZE|g" "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

# Create command-line launcher if requested
if [[ $CREATE_CMD_LAUNCHER == 1 ]]; then
    CMD_LAUNCHER="$LAUNCHER_DIR/fl-studio"
    ln -sf "$WRAPPER_SCRIPT" "$CMD_LAUNCHER"
    debug "✓ Command-line launcher created: fl-studio"
    
    # Ensure launcher directory is in PATH so 'fl-studio' command works
    ensure_path_entry "$LAUNCHER_DIR"
fi

# Create desktop entry
DESKTOP_PATH="$DESKTOP_DIR/flstudio.desktop"
WM_CLASS="fl64.exe"  # Wine generates lowercase with underscores

cat > "$DESKTOP_PATH" <<EODESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=FL Studio
Comment=Digital Audio Workstation (Installed: $(date +%Y-%m-%d))
Exec=$WRAPPER_SCRIPT %U
Icon=$ICON_PATH
Terminal=false
Categories=AudioVideo;Audio;Music;Midi;
Keywords=music;audio;production;daw;flstudio;
StartupNotify=true
StartupWMClass=$WM_CLASS
MimeType=audio/x-flstudio-project;

[Desktop Action KillWine]
Name=Kill Wine Processes
Exec=wineserver -k

[Desktop Action ConfigureWine]
Name=Configure Wine Audio
Exec=env WINEPREFIX="$PREFIX" winecfg
EODESKTOP

chmod +x "$DESKTOP_PATH"

# Update desktop database
update-desktop-database -q "$DESKTOP_DIR" 2>/dev/null || debug "Desktop update returned non-zero"
xdg-desktop-menu forceupdate 2>/dev/null || debug "xdg-desktop-menu not available"

# Validate desktop entry
if command_exists desktop-file-validate; then
    if ! desktop-file-validate "$DESKTOP_PATH" 2>/dev/null; then
        warn "⚠ Desktop entry validation warnings"
    fi
fi

# ============================================================================
# 19 – BROWSER INTEGRATION (Enhanced)
# ============================================================================

log "=== STEP 9: Configuring browser integration for licensing ==="

cat > /tmp/flstudio_browser_fix.reg <<'EOF'
REGEDIT4

; HTTP/HTTPS URL handlers
[HKEY_CLASSES_ROOT\http]
@="URL:HyperText Transfer Protocol"
"URL Protocol"=""
[HKEY_CLASSES_ROOT\http\shell]
[HKEY_CLASSES_ROOT\http\shell\open]
[HKEY_CLASSES_ROOT\http\shell\open\command]
@="winebrowser \"%1\""

[HKEY_CLASSES_ROOT\https]
@="URL:HyperText Transfer Protocol Secure"
"URL Protocol"=""
[HKEY_CLASSES_ROOT\https\shell]
[HKEY_CLASSES_ROOT\https\shell\open]
[HKEY_CLASSES_ROOT\https\shell\open\command]
@="winebrowser \"%1\""

; Image-Line specific handler
[HKEY_CLASSES_ROOT\image-line]
@="URL:Image-Line Protocol"
"URL Protocol"=""
[HKEY_CLASSES_ROOT\image-line\shell]
[HKEY_CLASSES_ROOT\image-line\shell\open]
[HKEY_CLASSES_ROOT\image-line\shell\open\command]
@="winebrowser \"%1\""

; Default browser setting
[HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice]
"ProgId"="https"

[HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice]
"ProgId"="https"

; File associations
[HKEY_CLASSES_ROOT\.htm]
@="htmlfile"
[HKEY_CLASSES_ROOT\.html]
@="htmlfile"

[HKEY_CLASSES_ROOT\htmlfile\shell\open\command]
@="winebrowser \"%1\""

; Ensure winebrowser is the default browser
[HKEY_LOCAL_MACHINE\Software\Wine\Browser]
"BROWSER"="winebrowser"
EOF

# Import registry settings
WINEPREFIX="$PREFIX" regedit /tmp/flstudio_browser_fix.reg 2>&1 || warn "Registry import had issues"
rm -f /tmp/flstudio_browser_fix.reg

# Verify winebrowser exists
WINE_BROWSER="$PREFIX/drive_c/windows/syswow64/winebrowser.exe"
[[ ! -f "$WINE_BROWSER" ]] && WINE_BROWSER="$PREFIX/drive_c/windows/system32/winebrowser.exe"
[[ -f "$WINE_BROWSER" ]] && debug "✓ winebrowser.exe found" || warn "winebrowser.exe not found"

# ============================================================================
# 20 – HIDE BROKEN WEBVIEW2 TABS (if requested)
# ============================================================================

if [[ $HIDE_BROKEN_TABS == 1 ]]; then
    log "=== STEP 9.5: Hiding broken WebView2 tabs ==="
    
    cat > /tmp/hide_broken_tabs.reg <<'EOF'
REGEDIT4

; Hide SOUNDS, HELP, and GOPHER tabs that require WebView2
[HKEY_CURRENT_USER\Software\Image-Line\FL Studio\24\Content]
"ShowSoundsTab"=dword:00000000
"ShowHelpTab"=dword:00000000
"ShowGopherTab"=dword:00000000

; Alternative registry path for older versions
[HKEY_CURRENT_USER\Software\Image-Line\FL Studio\21\Content]
"ShowSoundsTab"=dword:00000000
"ShowHelpTab"=dword:00000000
"ShowGopherTab"=dword:00000000
EOF
    
    WINEPREFIX="$PREFIX" regedit /tmp/hide_broken_tabs.reg 2>/dev/null || warn "Could not hide broken tabs"
    rm -f /tmp/hide_broken_tabs.reg
fi

# ============================================================================
# 21 – OPTIONAL FEATURES (Minimal mode check)
# ============================================================================

if [[ $MINIMAL_MODE == 1 ]]; then
    log "MINIMAL MODE: Skipping optional features..."
    log "=== INSTALLATION COMPLETE ==="
    log "Next steps: Configure audio settings in FL Studio to use WineASIO"
    exit 0
fi

# ============================================================================
# 22 – YABRIDGE INSTALLATION
# ============================================================================

if [[ $ENABLE_YABRIDGE == 1 ]]; then
    log "=== STEP 10: Installing Yabridge ==="
    
    if command_exists yabridgectl && [[ $FORCE_REINSTALL == 0 ]]; then
        log "Yabridge already installed"
    else
        YABRIDGE_INFO=$(curl -s https://api.github.com/repos/robbert-vdh/yabridge/releases/latest)
        YABRIDGE_URL=$(echo "$YABRIDGE_INFO" | jq -r '.assets[] | select(.name | test("tar\\.gz$")) | .browser_download_url' | head -1)
        
        if [[ -z "$YABRIDGE_URL" || "$YABRIDGE_URL" == "null" ]]; then
            warn "Could not find Yabridge download URL"
        else
            debug "Yabridge URL: $YABRIDGE_URL"
            TMPDIR=$(mktemp -d)
            
            if curl -fsSL "$YABRIDGE_URL" -o "$TMPDIR/yabridge.tar.gz"; then
                if tar -xzf "$TMPDIR/yabridge.tar.gz" -C "$TMPDIR"; then
                    YABRIDGE_BIN=$(find "$TMPDIR" -name "yabridge" -type f -executable | head -1)
                    YABRIDGECTL_BIN=$(find "$TMPDIR" -name "yabridgectl" -type f -executable | head -1)
                    
                    if [[ -n "$YABRIDGE_BIN" && -n "$YABRIDGECTL_BIN" ]]; then
                        mkdir -p ~/.local/bin
                        cp "$YABRIDGE_BIN" "$YABRIDGECTL_BIN" ~/.local/bin/
                        chmod +x ~/.local/bin/yabridge ~/.local/bin/yabridgectl
                        ~/.local/bin/yabridgectl add "$PREFIX" 2>/dev/null
                        ~/.local/bin/yabridgectl sync 2>/dev/null
                        log "✓ Yabridge installed and synced"
                    else
                        warn "Yabridge binaries not found after extraction"
                    fi
                else
                    warn "Failed to extract Yabridge"
                fi
            else
                warn "Failed to download Yabridge"
            fi
            rm -rf "$TMPDIR"
        fi
    fi
fi

# ============================================================================
# 23 – MIDI BRIDGE (a2jmidid)
# ============================================================================

if [[ $ENABLE_LOOPMIDI == 1 ]]; then
    log "=== STEP 11: Setting up a2jmidid MIDI bridge ==="
    
    if [[ $ENABLE_SYSTEMD == 1 ]]; then
        mkdir -p ~/.config/systemd/user
        
        cat > ~/.config/systemd/user/a2jmidid.service <<'EOF'
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
        
        systemctl --user daemon-reload
        log "✓ MIDI service created (enable with: systemctl --user enable a2jmidid)"
    else
        log "✓ MIDI bridge available (run manually: a2jmidid -e)"
    fi
fi

# ============================================================================
# 24 – MCP STACK INSTALLATION
# ============================================================================

if [[ $ENABLE_MCP == 1 ]]; then
    log "=== STEP 12: Installing MCP stack ==="
    
    MCP_INSTALL_URL="https://raw.githubusercontent.com/BenevolenceMessiah/flstudio-mcp/main/flstudio-mcp-install.sh"
    TMP_MCP_SCRIPT=$(mktemp)
    
    if curl -fsSL "$MCP_INSTALL_URL" -o "$TMP_MCP_SCRIPT"; then
        chmod +x "$TMP_MCP_SCRIPT"
        MCP_USE_VENV=1 bash "$TMP_MCP_SCRIPT"
        rm -f "$TMP_MCP_SCRIPT"
        log "✓ MCP stack installed"
    else
        warn "Failed to download MCP installer"
    fi
fi

# ============================================================================
# 25 – n8n INSTALLATION
# ============================================================================

if [[ $ENABLE_N8N == 1 ]]; then
    log "=== STEP 13: Installing n8n ==="
    
    if ! command -v n8n &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
    
    sudo npm install -g n8n n8n-nodes-mcp-client
    log "✓ n8n installed"
fi

# ============================================================================
# 26 – OLLAMA SETUP
# ============================================================================

if [[ $ENABLE_OLLAMA == 1 ]]; then
    log "=== STEP 14: Setting up Ollama ==="
    
    if ! command -v ollama &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    
    if [[ "$OLLAMA_MODEL" != "hf.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q8_K_XL" ]]; then
        ollama pull "$OLLAMA_MODEL"
    fi
    
    cat > ~/.local/bin/ollama-mcp <<'EOF'
#!/bin/bash
export OLLAMA_MODEL="${OLLAMA_MODEL:-hf.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:Q8_K_XL}"
ollama run "$OLLAMA_MODEL" "$@"
EOF
    chmod +x ~/.local/bin/ollama-mcp
    
    # Add to PATH if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi

# ============================================================================
# 27 – ASSISTANT CONFIGS (Continue.ai & Cursor)
# ============================================================================

if [[ $ENABLE_CONTINUE == 1 ]]; then
    log "=== STEP 15: Creating Continue.ai configs ==="
    
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

# ============================================================================
# 28 – PIPEWIRE TWEAKS
# ============================================================================

if [[ $TWEAK_PIPEWIRE == 1 ]]; then
    log "=== STEP 16: Applying PipeWire low-latency tweaks ==="
    warn "PipeWire mode is experimental - JACK2 is strongly recommended for production"
    
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    cat > ~/.config/pipewire/pipewire.conf.d/90-lowlatency.conf <<EOF
stream.properties = {
    node.latency = $AUDIO_BUFFER_SIZE/$AUDIO_SAMPLE_RATE
    node.rate = $AUDIO_SAMPLE_RATE
}
EOF
    
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || \
        warn "PipeWire restart failed (changes will apply after reboot)"
    log "✓ PipeWire tweaks applied"
fi

# ============================================================================
# 29 – PATCHBAY TEMPLATE
# ============================================================================

if [[ $PATCHBAY == 1 ]]; then
    log "=== STEP 17: Creating QJackCtl patchbay template ==="
    
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
    log "✓ Patchbay template created"
fi

# ============================================================================
# 30 – SYSTEMD SERVICES
# ============================================================================

if [[ $ENABLE_SYSTEMD == 1 ]]; then
    log "=== STEP 18: Setting up systemd services ==="
    
    loginctl enable-linger "$USER" 2>/dev/null || warn "Could not enable linger"
    
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
Description=ALSA to JACK MIDI Bridge
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
    
    # Enable and start
    systemctl --user daemon-reload
    for service in flstudio-mcp a2jmidid n8n ollama; do
        if [[ -f "$UDIR/${service}.service" ]]; then
            log "Enabling ${service}.service"
            systemctl --user enable --now "${service}.service" 2>/dev/null || warn "Failed to start $service"
        fi
    done
fi

# ============================================================================
# 31 – FL STUDIO REGISTRY TWEAKS
# ============================================================================

if [[ $DISABLE_FL_UPDATES == 1 ]]; then
    log "=== STEP 19: Disabling FL Studio auto-update dialog ==="
    
    cat > /tmp/fl_disable_updates.reg <<'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Image-Line]
"AutoUpdate"=dword:00000000
"CheckForUpdates"=dword:00000000
"LastUpdateCheck"=dword:00000000

[HKEY_CURRENT_USER\Software\Image-Line\FL Studio]
"AutoUpdate"=dword:00000000
"CheckForUpdates"=dword:00000000
EOF
    
    WINEPREFIX="$PREFIX" wine regedit /tmp/fl_disable_updates.reg 2>/dev/null || true
    rm -f /tmp/fl_disable_updates.reg
fi

# ============================================================================
# 32 – FINAL CLEANUP & VERIFICATION
# ============================================================================

log "=== STEP 20: Final cleanup and verification ==="

# Kill any remaining Wine processes
wineserver -k 2>/dev/null || true
sleep 2

# Verification
log "=== VERIFICATION SUMMARY ==="

ALL_GOOD=1

# Check WineASIO files
if [[ -f "$WINEASIO_DLL" && -f "$WINEASIO_SO" ]]; then
    log "✓ WineASIO files installed"
else
    warn "✗ WineASIO files missing"
    ALL_GOOD=0
fi

# Check registration
if WINEPREFIX="$PREFIX" wine reg query "HKCU\\Software\\Wine\\Drivers" /v Audio 2>/dev/null | grep -i asio; then
    log "✓ WineASIO registered in Wine"
else
    warn "✗ WineASIO not registered"
    ALL_GOOD=0
fi

# Check FL Studio executable
if [[ -n "$FL_EXE" && -f "$FL_EXE" ]]; then
    log "✓ FL Studio executable found"
else
    warn "✗ FL Studio executable not found"
    ALL_GOOD=0
fi

# Check launcher
if [[ -x "$WRAPPER_SCRIPT" ]]; then
    log "✓ Launcher script created"
else
    warn "✗ Launcher script not executable"
    ALL_GOOD=0
fi

# Check desktop entry
if [[ -f "$DESKTOP_PATH" ]]; then
    log "✓ Desktop entry created"
else
    warn "✗ Desktop entry missing"
    ALL_GOOD=0
fi

# Check command-line launcher
if [[ $CREATE_CMD_LAUNCHER == 1 ]]; then
    if [[ -L "$LAUNCHER_DIR/fl-studio" ]]; then
        log "✓ Command-line launcher 'fl-studio' created"
    else
        warn "✗ Command-line launcher not created"
    fi
fi

# ============================================================================
# 33 – FINAL INSTRUCTIONS
# ============================================================================

log ""
log "════════════════════════════════════════════════════════════════"
log "              FL STUDIO INSTALLATION COMPLETE!"
log "════════════════════════════════════════════════════════════════"
log ""

if [[ $ALL_GOOD == 1 ]]; then
    log "✅ All critical components installed successfully!"
else
    log "⚠️ Installation completed with some issues - see warnings above"
fi

log "🎵 NEXT STEPS:"
log "1. Launch FL Studio from your applications menu"
log "2. OR run from command line: ~/.local/bin/flstudio-launcher"
[[ $CREATE_CMD_LAUNCHER == 1 ]] && log "   OR simply: fl-studio"
log "3. OR run: WINEPREFIX=\"$PREFIX\" wine \"C:\\Program Files\\Image-Line\\FL Studio $FL_VERSION\\FL64.exe\""
log ""

log "🎚️ AUDIO CONFIGURATION (CRITICAL):"
log "1. Open FL Studio"
log "2. Go to Options > Audio Settings"
log "3. Select 'WINEASIO' as the device"
log "4. Set Sample Rate: $AUDIO_SAMPLE_RATE Hz"
log "5. Set Buffer Size: $AUDIO_BUFFER_SIZE samples"
log "6. If WineASIO doesn't appear, restart FL Studio or run:"
log "   WINEPREFIX=\"$PREFIX\" wine regsvr32 C:\\windows\\system32\\wineasio.dll"
log ""

log "🌐 LICENSING & ACTIVATION:"
log "• Browser integration is configured for Image-Line account login"
log "• If browser doesn't open, check winebrowser.exe configuration"
log ""

log "🐛 TROUBLESHOOTING:"
log "• Full log: $LOG"
log "• Wine prefix: $PREFIX"
log "• Kill Wine: wineserver -k"
log "• Test launch: ~/.local/bin/flstudio-launcher"
log ""

log "⚡ PERFORMANCE TIPS:"
log "• Use JACK2 instead of PipeWire for best audio performance"
log "• Increase buffer size if you experience audio dropouts"
log "• Consider using --tweak-pipewire on Ubuntu 24.04+"
log ""

log "🗑️ UNINSTALL:"
log "• Keep projects: ./flstudio_setup.sh --uninstall"
log "• Full cleanup: ./flstudio_setup.sh --uninstall-full"
log ""

log "📂 USER DATA LOCATION:"
log "• Projects: ~/Documents/Image-Line/FL Studio"
log "• Settings: $PREFIX"
log ""

log "════════════════════════════════════════════════════════════════"
log "🎉 Enjoy making music with FL Studio on Linux!"
log "════════════════════════════════════════════════════════════════"

exit 0

