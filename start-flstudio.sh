#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$HOME/.wine-flstudio/drive_c/Program Files/Image-Line"
EXE_PATH="$APP_DIR/FL Studio */FL64.exe"
INSTALLER="$HOME/flstudio.exe"
PULSE_COOKIE_SRC="$XDG_RUNTIME_DIR/pulse/cookie"
PULSE_COOKIE_DST="$HOME/.config/pulse/cookie"

# --------------------------------------------------------------------
# 1.  Copy Pulse cookie (avoids auth errors inside container)
# --------------------------------------------------------------------
if [[ -f "$PULSE_COOKIE_SRC" && ! -f "$PULSE_COOKIE_DST" ]]; then
  echo "[INFO] Copying Pulse cookie into container …"
  mkdir -p "$(dirname "$PULSE_COOKIE_DST")"
  cp "$PULSE_COOKIE_SRC" "$PULSE_COOKIE_DST"
fi

# --------------------------------------------------------------------
# 2.  Download installer if missing
# --------------------------------------------------------------------
if [[ ! -f $INSTALLER ]]; then
  echo "[INFO] Downloading latest FL-Studio installer …"
  wget -q --show-progress -c \
       https://cdn.image-line.com/flstudio/flstudio_win_latest.exe \
       -O "$INSTALLER"
fi

# --------------------------------------------------------------------
# 3.  First-run → launch installer; else start FL Studio
# --------------------------------------------------------------------
if compgen -G "$EXE_PATH" > /dev/null; then
  echo "[INFO] FL Studio detected — launching …"
  wine $(compgen -G "$EXE_PATH" | head -1)
else
  echo "[INFO] Running FL Studio installer …"
  wine "$INSTALLER"
  echo "[INFO] Installer finished.  Tip: run 'yabridgectl sync' after adding VSTs."
fi

exec bash   # keep container interactive
