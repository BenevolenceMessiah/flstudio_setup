# FL Studio on Linux — One-Command Installer/Updater & AI-Ready Tool‑chain

**TL;DR** Run a single configurable one-shot shell script or command to get:

* **AI-capable FL Studio Running on Linux** (auto-downloads the latest installer or uses your own)
* Wine 9‑staging **or** *stable* (you choose via `--wine`) + WineASIO + Winetricks to make FL Studio work at full capacity on Linux
* Automatic 32bit architecture enabled for older FL Studio components
* Yabridge for Windows VST/VST3/CLAP plugins
* PipeWire/JACK low‑latency audio *and* an ALSA ↔ JACK *LoopMIDI‑style* bridge (a2jmidid)
* My fork of the community‑maintained **flstudio‑mcp** server, plus optional **n8n**, **Ollama** and **Cursor** MCP endpoints for (unofficial) AI integration!
* Automatic Installation and updates for flstudio‑mcp, n8n and MCP node and Ollama MCP file, all the Linux dependencies, graphics, and runtimes components, etc., and FL Studio itself.
* Auto‑generated **Continue** MCP assistant YAML files (safe even if you still use the old `config.json`) auto‑generated **Ollama** MCP assistant, auto‑generated **n8n** MCP assistant, auto-generated **Cursor** MCP assistant.
* Optional user-level systemd services so everything starts at login **and survives logout** via `loginctl enable-linger`
* One-command **uninstaller** (`--uninstall`) that removes packages, Wine prefix, user services, and desktop entries
* Automatic FL Studio icon integration with GNOME/KDE menus **and** optional registry tweak (`--disable-fl-updates`) to silence the auto-update popup

Re‑run the script/command any time—it upgrades everything in place.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Why This Exists](#why-this-exists)
3. [Prerequisites & Supported Distros](#prerequisites--supported-distros)
4. [Installation Methods](#installation-methods)
5. [Flags & Environment Variables](#flags--environment-variables)
6. [What the Script Actually Does](#what-the-script-actually-does)
7. [MCP Stack Deep-Dive](#mcp-stack-deep-dive)
8. [Updating, Re-running & Uninstalling](#updating-re-running--uninstalling)
9. [Troubleshooting](#troubleshooting)
10. [Credits & License](#credits--license)

---

## Quick Start

```bash
# lean install (Wine + Yabridge + MCP + LoopMIDI bridge) + autostart services - (recommended if you already have VS Code and the Continue Extension installed)

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- --systemd
```

```bash
# leanest install (Wine + Yabridge) - (not recommended, missing all the unique AI dependencies, features, and endpoints)

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- --no-features
```

```bash
# leanest install (Wine + Yabridge) + local installation - (not recommended, missing all the unique AI dependencies, features, and endpoints)

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- --no-features --installer /absolute/path/to/flstudio_win_21_1_99.exe --reg /absolute/path/to/flstudio.reg
```

```bash
# lean install (Wine + Yabridge + MCP + LoopMIDI bridge) + autostart services, specifying a an already downloaded FL .exe file - (recommended if you need an older version of FL Studio)

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- \
  --installer /absolute/path/to/flstudio_win_21_1_99.exe \
  --reg /absolute/path/to/flstudio.reg \
  --systemd
```

```bash
# everything + autostart services - (not recommended unless you need or want multiple MCP endpoints for your AI system)

ENABLE_N8N=1 ENABLE_OLLAMA=1 ENABLE_CURSOR=1 \
curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- \
  --systemd
```

### **Notes 1:**

1. *The first run takes \~5–10 minutes depending on bandwidth and what you chose to install; subsequent runs only fetch updates.*
2. *If you're using a pre-downloaded EXE file for FL STUDIO, make sure you edit the file location via --installer when you paste the command.*
3. The script **auto‑downloads the latest FL Studio installer** if you omit `--installer`.
4. *Read on for all available command line arguments and features!*
5. Tested with installing for `Current User`. I suggest this is what you do too.
6. Registering/Unlocking FL Studio is still a bit wonky but you have a few options (either using the offline .reg file and using the `--reg` command line argument or using the file unlock option via the FL Studio authentication dialogue).

---

## Why This Exists

Running **FL Studio** on Linux has always meant juggling Wine versions, Winetricks DLLs, WineASIO, Windows VST bridges, etc. - and now in the case and era of MCP, it means also necessarily setting up a virtually‑patched MIDI loopback, and dumping Python files into FL Studio's installation and otherwise configuring AI MCP servers; and thus the advent of integrating agentic AI musician assistants is here!
This script wires everything necessary together *idempotently*: every section checks for an existing install and upgrades rather than overwriting.

* Wine repository setup follows the **new keyring‑in‑`/etc/apt/keyrings/`** guide so `apt update` stays warning‑free.
* WineASIO gives near‑native latency by exposing JACK to FL’s ASIO engine.
* DXVK + `vcrun2019` via Winetricks solve most modern graphics/runtime issues.
* **Yabridge** translates Windows plugins to native hosts and auto‑re‑syncs after a Wine update.
* **a2jmidid -e** is the de‑facto “LoopMIDI” for JACK/PipeWire.
* **Model Context Protocol (MCP)** turns FL Studio into an AI‑controllable endpoint—the “USB‑C of AI apps.” To this end, since FL Studio doesn't have an official Linux install, and since this project is presumably the most comprehensive attempt at perpetuating a long term future-proof solution, it ships out of the box with AI capabilities.

---

## Prerequisites & Supported Distros

| Works on                           | Tested | Notes                                                                        |
| ---------------------------------- | ------ | ---------------------------------------------------------------------------- |
| Ubuntu 22.04 / 24.04 & derivatives | ✅      | PipeWire is default; JACK sessions also supported.                           |
| Debian 12 “Bookworm”               | ✅      | Needs PipeWire or JACK.                                                      |
| Arch / Manjaro                     | ⚠      | Script runs, but repository lines for Wine will be skipped.                  |
| Fedora                             | ⚠      | You may need `dnf` instead of `apt` and to add the WineHQ RPM repo manually. |

**Hardware Requirements:** any 64‑bit CPU, 4 GB+ RAM and an audio interface capable of low‑latency JACK operation.

---

## Installation Methods

### 1. One‑liner (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh | bash -- --systemd
```

Pros: fastest; always gets the latest script.

### 2. Local clone

```bash
git clone https://github.com/BenevolenceMessiah/flstudio_setup.git
cd flstudio_setup
chmod +x flstudio_setup.sh
./flstudio_setup.sh --installer /path/to/flstudio.exe --n8n --systemd
```

Pros: you can read or patch the script first for your specific use cases; commits are versioned.

### 3. Docker (not recommended)

#### Why Docker is not Recommended for Audio

* Pulse, PipeWire and JACK sockets are bound into the container; real-time scheduling depends on your host kernel.For Wayland add -e WAYLAND_DISPLAY and mount the Wayland socket.

* If you only need a sandboxed test-bed, Docker is fine. For daily
production work, the bare-metal one-liner `(curl | bash)` yields the
lowest latency. Thus, using either above method is certainly preferred over the Docker Container.

* If you do use Docker, it's suggested you use Docker Desktop.

```bash
git clone https://github.com/BenevolenceMessiah/flstudio_setup.git
cd flstudio_setup/docker
docker compose build  # ARG WINE_BRANCH=staging or stable
xhost +local:docker   # allow GUI forwarding

# first run – downloads the installer and launches the GUI
docker compose run --rm flstudio
```

```bash
# next time – starts Wine & FL-Studio instantly
docker compose run --rm flstudio
```

---

## Flags & Environment Variables

| Switch / Var                          | Default                     | Description                                                                  |                                               |
| ------------------------------------- | --------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------- |
| `--installer <file\|URL>`          | *(auto‑detected)*           | Path or HTTPS URL to the FL Studio installer (ENV: `INSTALLER_PATH=`)        |
| `--no-mcp` / `ENABLE_MCP=0`           | 1                           | Skip **flstudio-mcp**, n8n node, Ollama shim, Cursor YAML and Continue YAML. |                                               |
| `--no-continue` / `ENABLE_CONTINUE=0` | 1                           | Don’t write `~/.continue/assistants/*.yaml`.                                 |                                               |
| `--no-loopmidi` / `ENABLE_LOOPMIDI=0` | 1                           | Skip installing `a2jmidid`.                                                  |                                               |
| `--n8n` / `ENABLE_N8N=1`              | 0                           | Install/upgrade Node 18 LTS, n8n and the MCP‑Client node.                    |                                               |
| `--ollama` / `ENABLE_OLLAMA=1`        | 0                           | Install or update Ollama and add an MCP shim.                                |                                               |
| `--cursor` / `ENABLE_CURSOR=1`        | 0                           | Add Cursor‑style MCP YAML to `~/.cursor/`.                                   |                                               |
| `--systemd` / `ENABLE_SYSTEMD=1`      | 0                           | Create **user‑level** services for MCP, a2jmidid, n8n, Ollama.               |                                               |
| `--wine <stable\|staging>` / `WINE_BRANCH=` | `staging` | Choose Wine branch. |
| `--ollama-model <tag>` / `OLLAMA_MODEL=` | `qwen3:14b` | Default model for the Ollama MCP shim. |
| `--no-yabridge` / `ENABLE_YABRIDGE=0` | 1 | Skip Yabridge install/sync. |
| `--tweak-pipewire` / `TWEAK_PIPEWIRE=1` | 0 | Apply low-latency PipeWire preset. |
| `--patchbay` / `PATCHBAY=1` | 0 | Write QJackCtl/Carla patchbay template.  |
| `--disable-fl-updates` / `DISABLE_FL_UPDATES=1` | 0 | Turn off FL-Studio auto-update dialog. |
| `--uninstall`                          | —  | Remove all packages, Wine prefix, user services, icons, assistants.  |

### **Notes 2:**

* If --installer is not set, the script will automatically download the latest version of FL Studio via CDN, effectively: --installer <https://cdn.image-line.com/flstudio/flstudio_win_latest.exe>
* Environment variables override script defaults; flags override both.

---

## What the Script Actually Does

### 1. Full system upgrade

Runs `sudo apt update && sudo apt upgrade -y` before anything else.

### 2. Wine 9‑staging repository & key

Places `winehq.key` in `/etc/apt/keyrings` and a `.sources` file in `/etc/apt/sources.list.d/` to satisfy modern APT.

### 3. Core package install / update

* **Wine32/64 + Winetricks** – helper for Windows DLLs.
* **WineASIO** – JACK → ASIO bridge.
* **PipeWire‑JACK, qjackctl** – user‑space JACK router.
* **a2jmidid** (optional) – ALSA ↔ JACK loopback.
* CLI helpers: `curl`, `git`, `jq`, `imagemagick`, `python3-venv`.

### 4. Wine prefix bootstrap

`WINEPREFIX=~/.wine-flstudio` is created once; subsequent runs leave your plugins intact.

### 5. Winetricks runtime libraries

`vcrun2019`, `corefonts`, `dxvk` **quietly** installed (or skipped if present).

### 6. FL Studio installer execution

The EXE is *always* run under Wine; GUI prompts appear as on Windows.

### 7. Desktop integration

Extracts `FL.ico` into a 512×512 PNG and writes `flstudio.desktop` so it shows up in GNOME/KDE menus.

### 8. **Yabridge**

Downloads the latest binary tarball, installs to `~/.local/bin/`, then runs `yabridgectl sync`—which also checks Wine compatibility.

### 9. LoopMIDI bridge (`a2jmidid -e`)

Exports every ALSA sequencer port into JACK *and* PipeWire so FL Studio sees “a2j” ports exactly like loopMIDI on Windows.

### 10. MCP stack *(if enabled)*

| Component                    | Purpose                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| **flstudio-mcp**             | Python stdio server exposing playlist, mixer & transport over MCP.                    |
| **n8n MCP node**             | Drag‑and‑drop workflows that call MCP tools.                                          |
| **Ollama shim**              | Wrapper mapping `ask` → `ollama run qwen3:14b` (edit to choose another model). |
| **Continue assistants YAML** | Auto‑discovered by Continue.                                                          |
| **Cursor YAML**              | Optional snippet for Cursor’s MCP side‑panel.                                         |

### 11. Systemd user services *(if enabled)*

Placed in `~/.config/systemd/user/` and started immediately:

| Unit                   | Condition           | Purpose                                       |
| ---------------------- | ------------------- | --------------------------------------------- |
| `flstudio-mcp.service` | `ENABLE_MCP=1`      | Auto‑start the FL‑Studio MCP server on login. |
| `a2jmidid.service`     | `ENABLE_LOOPMIDI=1` | Creates ALSA ↔ JACK loopback ports.           |
| `n8n.service`          | `ENABLE_N8N=1`      | Runs the n8n workflow engine on port 5678.    |
| `ollama.service`       | `ENABLE_OLLAMA=1`   | Keeps Ollama’s local LLM server running.      |

---

## MCP Stack Deep‑Dive

### What is MCP?

Model Context Protocol is an open, JSON‑RPC‑style protocol that lets LLM apps *safely* call external tools. It has been likened to “USB‑C for AI” and is now shipping in Windows AI Foundry.

### flstudio-mcp – autonomous AI bridge for FL Studio

The *flstudio-mcp* stack wires an LLM-aware **Model Context Protocol (MCP)**
server (built with **FastMCP 2.x**) to FL Studio’s Python/MIDI scripting layer.
It now ships a complete tool-chain—composition → arrangement → mix → master—
that installs with a single script and runs automatically as a user-level
systemd service.

#### Core bridge

* Communicates over a **dedicated MIDI channel** and an extended op-code
  scheme to set tempo, jump to markers, solo/unsolo tracks, tweak mixer faders
  and trigger full renders, all exposed through FL Studio’s official Python
  MIDI-scripting API.
* Uses **FastMCP** so any local or cloud LLM (Continue, Cursor, n8n, Ollama)
  can discover tools like `generate_melody`, `mix_project` or `master_audio`
  via standard JSON-RPC.

#### Generative composition

* Wraps Magenta’s **MelodyRNN** (`basic_rnn.mag`) and **DrumRNN**
  (`drum_kit_rnn.mag`) checkpoints to create multi-bar melodies and drum
  grooves on demand, returned as compact note strings the script streams into
  FL’s piano-roll.
* Leverages Magenta’s `note_seq` utilities for fast NoteSequence decoding and
  timing accuracy.

#### Mixing & mastering

* Adds an RMS analyser that balances stems to -12 dB LUFS before mastering.
* Integrates **Matchering 2.0** for reference-based, fully offline mastering;
  FFmpeg is auto-installed for codec support.

#### Linux-first audio stack

* The installer fetches **ffmpeg**, **Wine HQ** (stable|staging), **Winetricks**
  and **Yabridge** so Windows VST2/3 plug-ins run natively on Linux.
* Creates or updates a Wine prefix, applies DXVK, and syncs VST bridges in one
  step.

#### Package & environment management

* Installs all Python wheels with either
  **uv** (light-speed Rust package manager) or plain pip, falling back
  automatically.
* Optional virtual-env (`MCP_USE_VENV=1`, default) keeps dependencies isolated;
  containers set `MCP_USE_VENV=0` for lean layers.

#### Auto-start & lifecycle

* Generates a user-mode `flstudio-mcp.service` that launches the MCP server at
  login; updates or **`--uninstall`** cleanly stop and remove the unit.
* The same install script supports `--uninstall` to delete the venv, model
  bundles, wheels and service, keeping hosts tidy.

With these additions, an LLM can **compose, arrange, mix, master and export a
finished WAV** inside FL Studio—all headless, hands-free and cross-platform.

### Ollama shim

* Location: `~/.local/bin/ollama-mcp`
* Default LLM: **\`$OLLAMA_MODEL\`** (defaults to `qwen3:14b`, can be overridden with `--ollama-model llama3` or `OLLAMA_MODEL=phi3`).
* Swap models any time:

  ```bash
  ollama pull llama3           # downloads the model
  OLLAMA_MODEL=llama3 ollama-mcp
  ```

### Continue assistants YAML

Placing YAML files under `~/.continue/assistants/` is the *official* way to add servers—no merge conflicts with a legacy `config.json`.

---

## Updating, Re‑running & Uninstalling

| Action                 | Command                                                                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Upgrade everything** | Rerun `flstudio_setup.sh` with the same flags.                                                                                                                                                    |
| **Disable a service**  | `systemctl --user disable --now flstudio-mcp.service`                                                                                                                                             |
| **Remove everything**  | Delete `~/.wine-flstudio`, `~/.local/share/flstudio-mcp`, any `~/.config/systemd/user/*.service` units, and the desktop file. Packages can be removed with `sudo apt remove winehq-* wineasio …`. |

---

## Troubleshooting

| Symptom                           | Fix                                                          |
| --------------------------------- | ------------------------------------------------------------ |
| `NO_PUBKEY …` during `apt update` | Re-run script; Wine key is installed to `/etc/apt/keyrings`. |
| Audio crackles                    | Lower buffer (128) in WineASIO or increase PipeWire quantum. |
| VSTs missing in host              | Run `yabridgectl sync`; ensure Wine and yabridge match.      |
| ALSA device not visible in JACK   | Check `systemctl --user status a2jmidid`.                    |
| Ollama says “model not found”     | `ollama pull <model>` then edit \`\~/...                     |

## Credits & License

* **Script and Docs:** © 2025 Benevolence Messiah (MIT).
* **Big Thanks to:** WineHQ, yabridge, JACK/PipeWire, a2jmidid, Ollama, n8n, Continue, Cursor, and the Model Context Protocol community for their open-source brilliance.
* **Shoutout to:** ImageLine for making a program that works great on Windows, and effectively the best DAW out there!
* **Honorable mention to:** ImageLine for refusing to compile the program with native Ubuntu integration and forcing me to make this script!

Contributions are welcome—please open a PR!

---

Enjoy producing beats *and* bending them with AI—now entirely on Linux!
