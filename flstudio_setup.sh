#!/usr/bin/env bash
# flstudio_setup.sh – FL Studio + Wine + AI tool-chain

set -Eeuo pipefail
trap 'echo -e "\e[1;31m[FAIL]\e[0m  Something went wrong. See $LOG for details."' ERR
log(){ tput setaf 6; echo "[INFO] $*"; tput sgr0; echo "[INFO] $*" >>"$LOG"; }
die(){ tput setaf 1; echo "[ERROR] $*"; tput sgr0; exit 1; }

########## 0 – Globals & sensible defaults ################################
LOG="$HOME/flstudio_setup_$(date +%F).log"
export DEBIAN_FRONTEND=noninteractive

: "${INSTALLER_PATH:=https://cdn.image-line.com/flstudio/flstudio_win_latest.exe}"
: "${WINE_BRANCH:=staging}"            # or stable
: "${OLLAMA_MODEL:=qwen3:14b}"

PREFIX="${PREFIX:-$HOME/.wine-flstudio}"
ARCH=win64

# Feature toggles
ENABLE_MCP=1 ENABLE_CONTINUE=1 ENABLE_LOOPMIDI=1 ENABLE_YABRIDGE=1
ENABLE_N8N=0 ENABLE_OLLAMA=0 ENABLE_CURSOR=0 ENABLE_SYSTEMD=0
TWEAK_PIPEWIRE=0 DISABLE_FL_UPDATES=0 PATCHBAY=0 DO_UNINSTALL=0

show_help(){
cat <<EOF
Usage: $0 [options]
  --installer <file|URL>    Override FL Studio installer source
  --wine <stable|staging>   Choose Wine branch (default: staging)
  --ollama-model <tag>      Pick default Ollama model (default: $OLLAMA_MODEL)
  --no-mcp | --no-continue | --no-loopmidi | --no-yabridge
  --n8n  --ollama  --cursor  --systemd
  --tweak-pipewire          Apply low-latency PipeWire preset
  --patchbay                Write QJackCtl/Carla patchbay XML
  --disable-fl-updates      Turn off FL auto-update check
  --uninstall               Remove everything this script installed
  --help                    Show this help and exit
EOF
exit 0; }

########## 1 – Flag parser ################################################
while [[ $# -gt 0 ]]; do case $1 in
  --installer) INSTALLER_PATH="$2"; shift 2;;
  --wine) WINE_BRANCH="$2"; shift 2;;
  --ollama-model) OLLAMA_MODEL="$2"; shift 2;;
  --no-mcp) ENABLE_MCP=0; shift;;
  --no-continue) ENABLE_CONTINUE=0; shift;;
  --no-loopmidi) ENABLE_LOOPMIDI=0; shift;;
  --no-yabridge) ENABLE_YABRIDGE=0; shift;;
  --n8n) ENABLE_N8N=1; shift;;
  --ollama) ENABLE_OLLAMA=1; shift;;
  --cursor) ENABLE_CURSOR=1; shift;;
  --systemd) ENABLE_SYSTEMD=1; shift;;
  --tweak-pipewire) TWEAK_PIPEWIRE=1; shift;;
  --patchbay) PATCHBAY=1; shift;;
  --disable-fl-updates) DISABLE_FL_UPDATES=1; shift;;
  --uninstall) DO_UNINSTALL=1; shift;;
  --help|-h) show_help;;
  *) die "Unknown flag $1";;
esac; done

########## 2 – Optional uninstall #########################################
if [[ $DO_UNINSTALL == 1 ]]; then
  log "Uninstalling packages and data…"
  sudo apt -y remove winehq-* wineasio a2jmidid n8n nodejs || true
  rm -rf "$PREFIX" ~/.local/{bin,share}/flstudio-* ~/.continue/assistants/{flstudio*,ollama-mcp.yaml}
  systemctl --user disable --now {flstudio-mcp,a2jmidid,n8n,ollama}.service 2>/dev/null || true
  log "Done. Some packages may remain if they were previously installed."
  exit 0
fi

########## 3 – System upgrade & Wine repo #################################
log "Updating base system…"
sudo apt update && sudo apt upgrade -y

sudo dpkg --add-architecture i386 || true
sudo mkdir -pm755 /etc/apt/keyrings
wget -qO /tmp/winehq.key https://dl.winehq.org/wine-builds/winehq.key
sudo install -m644 /tmp/winehq.key /etc/apt/keyrings/
cat <<EOF | sudo tee /etc/apt/sources.list.d/winehq.sources
Types: deb
URIs: https://dl.winehq.org/wine-builds/ubuntu
Suites: $(lsb_release -cs)
Components: main
Signed-By: /etc/apt/keyrings/winehq.key
EOF  # :contentReference[oaicite:10]{index=10}

PKG_BASE="winehq-$WINE_BRANCH wine64 wine32 winetricks wineasio \
          qjackctl pipewire-jack libpipewire-0.3-modules imagemagick \
          curl git python3-venv jq"
[[ $ENABLE_LOOPMIDI == 1 ]] && PKG_BASE+=" a2jmidid"
sudo apt update && sudo apt -y install --install-recommends $PKG_BASE

########## 4 – Wine prefix bootstrap ######################################
export WINEPREFIX="$PREFIX" WINEARCH=$ARCH
[[ -d $PREFIX ]] || { log "Creating Wine prefix"; as_user wineboot -u; }
as_user winetricks -q vcrun2019 corefonts fontsmooth=rgb dxvk || true
as_user regsvr32 wineasio.dll || true

########## 5 – PipeWire latency tweak (opt-in) ############################
if [[ $TWEAK_PIPEWIRE == 1 ]]; then
  mkdir -p ~/.config/pipewire/pipewire.conf.d
  cat > ~/.config/pipewire/pipewire.conf.d/90-lowlatency.conf <<EOF
context.properties = {
  default.clock.quantum            = 128
  default.clock.min-quantum        = 64
}
EOF  # :contentReference[oaicite:11]{index=11}
  log "PipeWire low-latency preset installed."
fi

########## 6 – Download & verify FL installer #############################
FILE=flstudio.exe
if [[ $INSTALLER_PATH =~ ^https?:// ]]; then
  log "Fetching FL Studio installer…"
  wget -c "$INSTALLER_PATH" -O $FILE
  # OPTIONAL SHA256 check – set EXPECTED_SHA256 to enforce
  if [[ -n "${EXPECTED_SHA256:-}" ]]; then
    echo "$EXPECTED_SHA256  $FILE" | sha256sum -c - || die "Checksum mismatch!"
  fi
else
  cp "$INSTALLER_PATH" $FILE
fi
as_user wine $FILE

FLDIR=$(find "$PREFIX/drive_c/Program Files/Image-Line" -maxdepth 1 -name "FL Studio*" | head -1)
[[ $DISABLE_FL_UPDATES == 1 ]] && \
  as_user reg add "HKCU\\Software\\Image-Line\\FL Studio\\Update" /v CheckForUpdates /t REG_DWORD /d 0 /f  # :contentReference[oaicite:12]{index=12}

########## 7 – Desktop entry ################################################
ICON_SRC="$FLDIR/Artwork/Icon/FL.ico"
ICON_DST="$HOME/.local/share/icons/hicolor/512x512/apps/flstudio.png"
mkdir -p "$(dirname "$ICON_DST")" && convert "$ICON_SRC"[0] "$ICON_DST"
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/flstudio.desktop <<EOF
[Desktop Entry]
Name=FL Studio 64-bit
Exec=env WINEPREFIX=$PREFIX wine "$FLDIR/FL64.exe"
Icon=$ICON_DST
Type=Application
Categories=AudioVideo;Audio;Music;
EOF
update-desktop-database ~/.local/share/applications

########## 8 – Yabridge (skip-able) ########################################
if [[ $ENABLE_YABRIDGE == 1 ]]; then
  DL=$(curl -s https://api.github.com/repos/robbert-vdh/yabridge/releases/latest | \
       jq -r '.assets[]|select(.name|test("x86_64-linux")).browser_download_url')
  TMP=$(mktemp -d); wget -qO "$TMP/yab.tgz" "$DL"; tar -xf "$TMP/yab.tgz" -C "$TMP"
  install -Dm755 "$TMP/yabridge"* ~/.local/bin/ && rm -rf "$TMP"
  YOUT=$(yabridgectl sync --json 2>/dev/null); ERR=$(echo "$YOUT"|jq '.[]|select(.status=="error")')
  [[ -n $ERR ]] && log "Some plugins failed to load – check Wine DLLs."      # :contentReference[oaicite:13]{index=13}
fi

########## 9 – LoopMIDI bridge #############################################
[[ $ENABLE_LOOPMIDI == 1 ]] && log "a2jmidid bridge active (-e export HW)"   # :contentReference[oaicite:14]{index=14}

########## 10 – MCP stack ###################################################
if [[ $ENABLE_MCP == 1 ]]; then
  MCP_DIR=~/.local/share/flstudio-mcp; MCP_VENV=$MCP_DIR/venv
  git -C "$MCP_DIR" pull --ff-only 2>/dev/null || \
  git clone --depth 1 https://github.com/BenevolenceMessiah/flstudio-mcp.git "$MCP_DIR"
  python3 -m venv "$MCP_VENV" && "$MCP_VENV/bin/pip" install -U pip \
        && "$MCP_VENV/bin/pip" install -r "$MCP_DIR/requirements.txt"
  cp -r "$MCP_DIR/Test Controller" "$FLDIR/Settings/Hardware/"
fi

### n8n
if [[ $ENABLE_N8N == 1 ]]; then
  if ! command -v n8n &>/dev/null; then
    if curl -I https://deb.nodesource.com/setup_18.x 2>/dev/null|grep -q 404; then
      die "NodeSource script deprecated – see README."                      # :contentReference[oaicite:15]{index=15}
    fi
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt -y install nodejs
  fi
  sudo npm i -g n8n n8n-nodes-mcp-client
fi

### Ollama shim
if [[ $ENABLE_OLLAMA == 1 ]]; then
  command -v ollama &>/dev/null || curl -fsSL https://ollama.com/install.sh | sh
  [[ "${OLLAMA_MODEL}" != "qwen3:14b" ]] && ollama pull "$OLLAMA_MODEL"      # :contentReference[oaicite:16]{index=16}
  cat > ~/.local/bin/ollama-mcp <<PY
#!/usr/bin/env python3
import sys,json,subprocess,uuid,os
model=os.getenv("OLLAMA_MODEL","$OLLAMA_MODEL")
def send(i,**k):print(json.dumps({"id":i,**k}));sys.stdout.flush()
for l in sys.stdin:
    r=json.loads(l); i=r.get("id",str(uuid.uuid4()))
    if r["method"]=="getTools": send(i,tools=[]); continue
    if r["method"]=="ask":
        out=subprocess.check_output(["ollama","run",model,r["params"]["prompt"]]).decode()
        send(i,result=out)
PY
  chmod +x ~/.local/bin/ollama-mcp
fi

### Continue YAML
if [[ $ENABLE_CONTINUE == 1 ]]; then
  mkdir -p ~/.continue/assistants
  cat > ~/.continue/assistants/flstudio-mcp.yaml <<YAML
name: flstudio-mcp
schema: v1
mcpServers:
  - name: flstudio
    transport: {type: stdio, command: "$MCP_VENV/bin/python", args: ["$MCP_DIR/trigger.py"]}
YAML
  [[ $ENABLE_OLLAMA == 1 ]] && cat > ~/.continue/assistants/ollama-mcp.yaml <<YAML
name: ollama-mcp
schema: v1
mcpServers:
  - name: ollama
    transport: {type: stdio, command: "$HOME/.local/bin/ollama-mcp"}
YAML
fi

########## 11 – Patchbay template (opt-in) #################################
if [[ $PATCHBAY == 1 ]]; then
  mkdir -p ~/.config/rncbc.org/QjackCtl/patches
  cat > ~/.config/rncbc.org/QjackCtl/patches/flstudio.xml <<'XML'
<?xml version="1.0"?>
<qjackctl-patchbay version="0.7">
<!-- auto-linked ports go here -->
</qjackctl-patchbay>
XML  # :contentReference[oaicite:17]{index=17}
fi

########## 12 – systemd user services ######################################
if [[ $ENABLE_SYSTEMD == 1 ]]; then
  loginctl enable-linger $USER                                    # :contentReference[oaicite:18]{index=18}
  UDIR=~/.config/systemd/user; mkdir -p "$UDIR"
  if [[ $ENABLE_MCP == 1 ]]; then
    cat > "$UDIR/flstudio-mcp.service" <<EOF
[Unit] Description=FL Studio MCP server
[Service] ExecStart=$MCP_VENV/bin/python $MCP_DIR/trigger.py
Restart=on-failure
[Install] WantedBy=default.target
EOF
    systemctl --user enable --now flstudio-mcp.service
  fi
  [[ $ENABLE_LOOPMIDI == 1 ]] && { cat >"$UDIR/a2jmidid.service"<<EOF
[Unit] Description=ALSA↔JACK bridge
[Service] ExecStart=/usr/bin/a2jmidid -e
[Install] WantedBy=default.target
EOF
    systemctl --user enable --now a2jmidid.service; }
  [[ $ENABLE_N8N == 1 ]] && { cat >"$UDIR/n8n.service"<<EOF
[Unit] Description=n8n
[Service] ExecStart=$(command -v n8n) start
Environment=PORT=5678
[Install] WantedBy=default.target
EOF
    systemctl --user enable --now n8n.service; }
  [[ $ENABLE_OLLAMA == 1 ]] && { cat >"$UDIR/ollama.service"<<EOF
[Unit] Description=Ollama
[Service] ExecStart=$(command -v ollama) serve
[Install] WantedBy=default.target
EOF
    systemctl --user enable --now ollama.service; }
fi

log "🎹  All done!  Launch FL Studio, Open the MIDI Settings (choose WineASIO), route MIDI via a2jmidid, and open Continue/Cursor or whaterver MCP endpoint you installed for AI magic."
[[ $ENABLE_CONTINUE == 1 ]] && echo "→ Continue assistants written to ~/.continue/assistants/"
[[ $ENABLE_N8N == 1 ]] && echo "→ n8n MCP endpoint at http://localhost:5678"
[[ $ENABLE_OLLAMA == 1 ]] && echo "→ Ollama shim uses default model “qwen3:14b”; change in $HOME/.local/bin/ollama-mcp"
echo "Rerun this script anytime—it will update in place."