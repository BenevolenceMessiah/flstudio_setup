# --------------------------------------------------------------------
#  FL-Studio container (Ubuntu 22.04 base)
#  - Wine (stable|staging via ARG) + Winetricks + Yabridge
#  - Delegates MCP stack bootstrap to flstudio-mcp-install.sh
#  - Expects: /tmp/.X11-unix, $DISPLAY, $XAUTHORITY,
#             /run/user/UID/{pulse,pipewire-0,jack}, /dev/snd, /dev/dri
# --------------------------------------------------------------------

ARG  WINE_BRANCH=staging
FROM ubuntu:22.04

ENV  DEBIAN_FRONTEND=noninteractive \
     WINEPREFIX=/home/fluser/.wine-flstudio \
     WINETRICKS_DISABLE_GUI=1 \
     LANG=C.UTF-8

# ----------  Root layer: packages & Wine repo  ----------------------
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      software-properties-common wget curl ca-certificates gnupg \
      # Matchering needs ffmpeg for audio processing
      ffmpeg && \
    wget -qO /etc/apt/keyrings/winehq.key \
         https://dl.winehq.org/wine-builds/winehq.key && \
    echo "deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/winehq.key] \
         https://dl.winehq.org/wine-builds/ubuntu jammy main" \
         > /etc/apt/sources.list.d/winehq.list && \
    apt-get update && \
    apt-get install -y --install-recommends \
      winehq-${WINE_BRANCH} wine32 wine64 winetricks \
      cabextract tar jq python3 python3-venv xauth \
      libpulse0 libpipewire-0.3-modules \
      libvulkan1 mesa-vulkan-drivers mesa-utils \
      alsa-utils && \
    useradd -m -G audio,video fluser
RUN echo "@audio   -  rtprio     99\n@audio   -  memlock    unlimited" \
        >> /etc/security/limits.conf && \
    setcap cap_sys_nice+ep /usr/bin/jackd

# ----------  Root layer: Yabridge install  --------------------------
RUN set -euo pipefail; \
    YAB_URL=$(curl -s https://api.github.com/repos/robbert-vdh/yabridge/releases/latest \
       | jq -r '.assets[] | select(.name|test("x86_64-linux")) | .browser_download_url'); \
    curl -sSL "$YAB_URL" -o /tmp/yab.tgz && \
    tar -xf /tmp/yab.tgz -C /tmp && \
    install -Dm755 /tmp/yabridge* /usr/local/bin/ && \
    rm -rf /tmp/yab.tgz /tmp/yabridge*

# ----------  Copy entry-point script  --------------------------------
COPY start-flstudio.sh /usr/local/bin/start-flstudio.sh
RUN chmod +x /usr/local/bin/start-flstudio.sh

# ----------  Bootstrap MCP stack (root, pre-user switch) -------------
ENV  MCP_USE_VENV=0
RUN set -euo pipefail; \
    export HOME=/home/fluser; \
    export USER=fluser; \
    mkdir -p "$HOME/.wine-flstudio/drive_c/users/fluser/Documents/Image-Line/FL Studio/Settings/Hardware"; \
    curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio-mcp/main/flstudio-mcp-install.sh \
      | bash

# ----------  Switch to runtime user & finish Wine bootstrap ----------
USER fluser
WORKDIR /home/fluser
RUN wineboot -u && \
    winetricks -q vcrun2019 corefonts fontsmooth=rgb dxvk && \
    yabridgectl sync

# ----------  Volumes & entry-point  ----------------------------------
VOLUME ["/home/fluser/Projects", "/home/fluser/Downloads"]
ENTRYPOINT ["/usr/local/bin/start-flstudio.sh"]
CMD ["bash"]
