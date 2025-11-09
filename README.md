# FL Studio on Linux — One-Command Installer/Updater & Optional AI-Ready Tool‑chain

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Release](https://img.shields.io/badge/release-stable-green.svg)
![Wine](https://img.shields.io/badge/wine-staging|stable-orange.svg)
![FL Studio Compatibility](https://img.shields.io/badge/FL%20Studio%20Compatability-<12|21|>25-purple.svg)
![FL_STUDIO_LATEST_VERSION=](https://img.shields.io/badge/Latest%20FL%20Studio%20Version-25.1.6.4997-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

**TL;DR** Run a single configurable one-shot shell script or command to get:

* **AI-capable (or any vanilla version) of `FL Studio Running on Linux!`** (auto-downloads the [latest FL Studio installer](https://install.image-line.com/flstudio/flstudio_win64_25.1.6.4997.exe) or uses your already downloaded .exe installation file)
* Wine 9‑staging **or** *stable* (you choose via `--wine`) + `WineASIO` + `Winetricks` to make [FL Studio](https://www.image-line.com/fl-studio) work at full capacity on Linux
* Automatic 32bit architecture enabled for older FL Studio components
* `Yabridge` for Windows `VST`/`VST3`/`CLAP` plugins
* `PipeWire`/`JACK` low‑latency audio *and* an `ALSA` ↔ `JACK` *LoopMIDI‑style* bridge (`a2jmidid`)
* **Additional and Unofficial AI-ready toolchain**: My fork of the community‑maintained [**flstudio‑mcp**](https://github.com/BenevolenceMessiah/flstudio-mcp) server, plus optional [**n8n**](https://n8n.io/), [**Ollama**](https://ollama.com/), [**Continue**](https://www.continue.dev/) and [**Cursor**](https://cursor.com/) endpoints for (unofficial) [MCP](https://en.wikipedia.org/wiki/Model_Context_Protocol) AI integration!
* Automatic Installation and updates for `flstudio‑mcp`, `n8n` and MCP node and `Ollama` MCP file, all the Linux dependencies, graphics, and runtimes components, etc., and `FL Studio` itself
* Auto‑generated **Continue** MCP assistant YAML files (safe even if you still use the old `config.json`) auto‑generated **Ollama** MCP assistant, auto‑generated **n8n** MCP assistant, auto-generated **Cursor** MCP assistant.
* Optional user-level systemd services so everything starts at login **and survives logout** via `loginctl enable-linger`
* One-command **uninstaller** (`--uninstall`) that removes packages, Wine prefix, user services, and desktop entries
* Automatic FL Studio icon integration with GNOME/KDE menus **and** optional registry tweak (`--disable-fl-updates`) to silence the auto-update popup

Re‑run the script/command any time with the same command line flags — it upgrades everything in place.

**Don't own FL Studio?** Not a problem! This script installs the official installer - FL Studio's Trial Mode will allow you to play with pretty much the full program; the main limitation is that you can't reopen your saved projects.

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
9. [Current Issues and Limitations](#current-issues-and-limitations)
10. [Roadmap and Future Updates](#roadmap-and-future-updates)
11. [Troubleshooting](#troubleshooting)
12. [Credits & License](#credits--license)

---

## Quick Start

- Open a terminal and customize/run one of the following commands:
- Follow any terminal based, System pop-up, and Windows Installation Wizard popups accordingly

### Recommended for Most Users

```bash
# minimal install (FL Studio + WineASIO only) - fastest option for basic setup

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- --no-features
```

### Recommended for Users Who Already Have the FL Studio .exe File

This method is useful if you're using an older version of FL Studio for compatibility and you already have the installer locally on the computer.

Simply point the installer script to your installer file (`--installer`) and (optionally) to a reg key file (`--reg`) - you can always unlock FL Studio the recommended/normal way once the program is up and running so the `--reg` command line flag is completely optional when using the `--installer` command line flag.

Notably, the `--installer` command line argument also accepts `URLs` in the event you need to pull a version-specific `.exe` file from ImageLine servers directly. This means you could also use any URL or remote server location where an FL Studio installer .exe file hosted/backed up.

```bash
# minimal install with offline installation and activation

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- --no-features --installer /absolute/path/to/flstudio.exe --reg /absolute/path/to/flstudio.reg
```

### Examples for Users Seeking Advanced AI Features and Options

```bash
# lean install (Wine + Yabridge + MCP + LoopMIDI bridge) + autostart services - (recommended if you already have VS Code and the Continue Extension installed)

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- --systemd
```

```bash
# full installation with all AI features and services and multiple (unnecessary?) AI endpoints and integrations

ENABLE_N8N=1 ENABLE_OLLAMA=1 ENABLE_CURSOR=1 \
curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- \
  --systemd
```

```bash
# custom installation with specific components

curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- \
  --installer /absolute/path/to/flstudio_win_21_1_99.exe \
  --reg /absolute/path/to/flstudio.reg \
  --wine stable \
  --ollama-model llama3 \
  --systemd \
  --tweak-pipewire \
  --disable-fl-updates
```

### **Notes 1:**

1. *The first run takes \~5–10 minutes depending on bandwidth and what you chose to install; subsequent runs only fetch updates.* It is a very ugly/glitchy looking install. I deeply apologize for that - but this script is 1,117 lines long presently. This is like the world's most difficult program to integrate with Ubuntu.
2. *If you're using a pre-downloaded EXE file for FL Studio, make sure you edit the file location via `--installer` when you paste the command. You can optionally add `--reg` for your reg key file too at this point or you can manually unlock inside of FL Studio*
3. The script **auto‑downloads the latest FL Studio installer** if you omit `--installer`.
4. *Read on for all available command line arguments and features!*
5. Tested with installing for `Current User`. I suggest this is what you do too.
6. Registering/Unlocking FL Studio is still a bit wonky in `version 1.0.0` but you have a few options (either using the offline .reg file and using the `--reg` command line argument or using the file unlock option via the FL Studio authentication dialog (recommended)).
7. The MCP and AI integrations are all experimental and largely untested. Your results may vary!

---

## Why This Exists

Running **FL Studio** on Linux has always meant juggling Wine versions, Winetricks DLLs, WineASIO, Windows VST bridges, etc. - and now in the case and era of MCP, it means also necessarily setting up a virtually‑patched MIDI loopback, and dumping Python files into FL Studio's installation and otherwise configuring AI MCP servers; and thus the advent of integrating agentic AI musician assistants is here!
This script wires everything necessary together *idempotently*: every section checks for an existing install and upgrades rather than overwriting.

* Wine repository setup follows the **new keyring‑in‑`/etc/apt/keyrings/`** guide so `apt update` stays warning‑free.
* WineASIO gives near‑native latency by exposing JACK to FL’s ASIO engine.
* DXVK + `vcrun2019` via Winetricks solve most modern graphics/runtime issues.
* **Yabridge** translates Windows plugins to native hosts and auto‑re‑syncs after a Wine update.
* **a2jmidid -e** is the de‑facto "LoopMIDI" for JACK/PipeWire.
* **Model Context Protocol (MCP)** turns FL Studio into an AI‑controllable endpoint—the "USB‑C of AI apps." To this end, since FL Studio doesn't have an official Linux install, and since this project is presumably the most comprehensive attempt at perpetuating a long term future-proof solution, it ships out of the box with AI capabilities.

---

## Prerequisites & Supported Distros

| Works on                           | Tested | Notes                                                                        |
| ---------------------------------- | ------ | ---------------------------------------------------------------------------- |
| Ubuntu 22.04 / 24.04 & derivatives | ✅      | PipeWire is default; JACK sessions also supported.                           |
| Debian 12 "Bookworm"               | ✅      | Needs PipeWire or JACK.                                                      |
| Arch / Manjaro                     | ⚠      | Script runs, but repository lines for Wine will be skipped.                  |
| Fedora                             | ⚠      | You may need `dnf` instead of `apt` and to add the WineHQ RPM repo manually. |

**Hardware Requirements:** any 64‑bit CPU, 4 GB+ RAM and an audio interface capable of low‑latency JACK operation.

---

## Installation Methods

### 1. One‑liner (`curl | bash`)

```bash
curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- --systemd
```

-Or- (for vanilla FL Studio)

```bash
curl -fsSL https://raw.githubusercontent.com/BenevolenceMessiah/flstudio_setup/main/flstudio_setup.sh  | bash -- --no-features
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

| Switch / Var                          | Default                     | Description                                                                  |
| ------------------------------------- | --------------------------- | ---------------------------------------------------------------------------- |
| `--installer <file\|URL>`          | *(auto‑detected)*           | Path or HTTPS URL to the FL Studio installer (ENV: `INSTALLER_PATH=`)        |
| `--wine <stable\|staging>`            | `staging`                   | Choose Wine branch (ENV: `WINE_BRANCH=`)                                     |
| `--ollama-model <tag>`                | `qwen3:14b`                 | Default model for Ollama MCP shim (ENV: `OLLAMA_MODEL=`)                     |
| `--no-mcp`                            | 1                           | Skip **flstudio-mcp**, n8n node, Ollama shim, Cursor YAML and Continue YAML. |
| `--no-continue`                       | 1                           | Don't write `~/.continue/assistants/*.yaml`.                                 |
| `--no-loopmidi`                       | 1                           | Skip installing `a2jmidid`.                                                  |
| `--no-yabridge`                       | 1                           | Skip Yabridge install/sync.                                                  |
| `--no-features`                       | 0                           | **MINIMAL MODE**: Only install FL Studio + WineASIO (disables all optional features) |
| `--reg <file>`                        | —                           | Manually add registry key (e.g., FLRegkey.reg for offline activation)        |
| `--n8n`                               | 0                           | Install/upgrade Node 18 LTS, n8n and the MCP‑Client node.                    |
| `--ollama`                            | 0                           | Install or update Ollama and add an MCP shim.                                |
| `--cursor`                            | 0                           | Add Cursor‑style MCP YAML to `~/.cursor/`.                                   |
| `--systemd`                           | 0                           | Create **user‑level** services for MCP, a2jmidid, n8n, Ollama.               |
| `--tweak-pipewire`                    | 0                           | Apply low-latency PipeWire preset.                                           |
| `--patchbay`                          | 0                           | Write QJackCtl/Carla patchbay template.                                      |
| `--disable-fl-updates`                | 0                           | Turn off FL-Studio auto-update dialog.                                       |
| `--uninstall`                         | —                           | Remove all packages, Wine prefix, user services, icons, assistants.          |
| `--help`, `-h`                        | —                           | Show help message and exit.                                                  |

### Environment Variables

| Variable               | Default | Description |
| ---------------------- | ------- | ----------- |
| `INSTALLER_PATH`       | Auto-detect | Override installer source |
| `WINE_BRANCH`          | `staging` | Override Wine branch |
| `OLLAMA_MODEL`         | `qwen3:14b` | Override Ollama model |
| `PREFIX`               | `$HOME/.wine-flstudio` | Custom Wine prefix location |

### **Notes 2:**

* If --installer is not set, the script will automatically download the latest version of FL Studio, effectively: --installer 'https://install.image-line.com/flstudio/flstudio_win64_${FL_STUDIO_LATEST_VERSION}.exe'.
* Environment variables override script defaults; flags override both.
* The `--no-features` flag enables minimal mode, installing only the core components (FL Studio + Wine + WineASIO)
* Use `--reg` to import offline registration keys for FL Studio activation

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

Exports every ALSA sequencer port into JACK *and* PipeWire so FL Studio sees "a2j" ports exactly like loopMIDI on Windows.

### 10. MCP stack *(if enabled)*

| Component                    | Purpose                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| **flstudio-mcp**             | Python stdio server exposing playlist, mixer & transport over MCP.                    |
| **n8n MCP node**             | Drag‑and‑drop workflows that call MCP tools.                                          |
| **Ollama shim**              | Wrapper mapping `ask` → `ollama run qwen3:14b` (edit to choose another model). |
| **Continue assistants YAML** | Auto‑discovered by Continue.                                                          |
| **Cursor YAML**              | Optional snippet for Cursor's MCP side‑panel.                                         |

### 11. Systemd user services *(if enabled)*

Placed in `~/.config/systemd/user/` and started immediately:

| Unit                   | Condition           | Purpose                                       |
| ---------------------- | ------------------- | --------------------------------------------- |
| `flstudio-mcp.service` | `ENABLE_MCP=1`      | Auto‑start the FL‑Studio MCP server on login. |
| `a2jmidid.service`     | `ENABLE_LOOPMIDI=1` | Creates ALSA ↔ JACK loopback ports.           |
| `n8n.service`          | `ENABLE_N8N=1`      | Runs the n8n workflow engine on port 5678.    |
| `ollama.service`       | `ENABLE_OLLAMA=1`   | Keeps Ollama's local LLM server running.      |

---

## MCP Stack Deep‑Dive

### What is MCP?

Model Context Protocol is an open, JSON‑RPC‑style protocol that lets LLM apps *safely* call external tools. It has been likened to "USB‑C for AI" and is now shipping in Windows AI Foundry.

### flstudio-mcp – autonomous AI bridge for FL Studio

The *flstudio-mcp* stack wires an LLM-aware **Model Context Protocol (MCP)**
server (built with **FastMCP 2.x**) to FL Studio's Python/MIDI scripting layer.
It now ships a complete tool-chain—composition → arrangement → mix → master—
that installs with a single script and runs automatically as a user-level
systemd service.

#### Core bridge

* Communicates over a **dedicated MIDI channel** and an extended op-code
  scheme to set tempo, jump to markers, solo/unsolo tracks, tweak mixer faders
  and trigger full renders, all exposed through FL Studio's official Python
  MIDI-scripting API.
* Uses **FastMCP** so any local or cloud LLM (Continue, Cursor, n8n, Ollama)
  can discover tools like `generate_melody`, `mix_project` or `master_audio`
  via standard JSON-RPC.

#### Generative composition

* Wraps Magenta's **MelodyRNN** (`basic_rnn.mag`) and **DrumRNN**
  (`drum_kit_rnn.mag`) checkpoints to create multi-bar melodies and drum
  grooves on demand, returned as compact note strings the script streams into
  FL's piano-roll.
* Leverages Magenta's `note_seq` utilities for fast NoteSequence decoding and
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
| **Minimal reinstall**  | Use `--no-features` for core components only                                                                                                                                                      |
| **Disable a service**  | `systemctl --user disable --now flstudio-mcp.service`                                                                                                                                             |
| **Remove everything**  | Run with `--uninstall` flag to remove all components, or manually delete `~/.wine-flstudio`, `~/.local/share/flstudio-mcp`, any `~/.config/systemd/user/*.service` units, and the desktop file. |

---

## Current Issues and Limitations

### Known Limitations and Issues

1. **WineASIO Registration Warning**
   - **Issue**: "RegSvr32 error: regsvr32: Failed to load DLL '/usr/local/lib/wine/x86_64-windows/wineasio.dll'"
   - **Status**: Non-blocking - Wine's library paths have changed across versions
   - **Workaround**: ASIO for FL Studio installs correctly during FL Studio installation and is fully functional. Use "FL Studio ASIO" as your audio device in FL Studio settings (it should already be default).

2. **Browser Integration Issues**
   - **Issue**: FL Studio's Windows ShellExecute calls fail under Wine due to missing browser associations
   - **Status**: Only affects browser-based FL Studio activation
   - **Workaround**: Use offline registration (`--reg` flag) or file-based authentication through FL Studio's built-in dialog (easier and recommended anyway)

3. **WebView2 Black Screens**
   - **Issue**: SOUNDS, HELP, and GOPHER tabs display as black screens
   - **Cause**: FL Studio uses Microsoft Edge WebView2 (Chromium-based) which has broken rendering in Wine
   - **Status**: Known WineHQ AppDB limitation, not script-related
   - **Workaround**: These tabs are non-functional but core FL Studio features work perfectly

4. **Icon Detection False Warning**
   - **Issue**: Script may show icon detection warnings during installation
   - **Status**: False positive - fallback icon generation works correctly
   - **Workaround**: Ignore the warning - FL Studio desktop entry and icon are created successfully

5. **Inability for Wine to see certain Hard Drives**
   - **Issue**: Wine/Windows File Explorer emulation does not seem to see certain hard drives. I'm not sure why this is.
   - **Status**: May effect you if you're using project files or VSTs on another hard rive. I noticed it on an NTFS NVME m.2 solid state drive.
   - **Workaround**: Copy these directories/files manually to a hard drive that FL Studio can see.

### Audio-Specific Considerations

- **PipeWire vs JACK**: WineASIO works best with native JACK2. PipeWire's JACK implementation may cause stability issues.
- **Low Latency**: For best performance, use `--tweak-pipewire` or install JACK2 separately
- **Buffer Settings**: Start with 128-256 buffer size in FL Studio Audio Settings

---

## Roadmap and Future Updates

### Next Version (v1.1.0) Planned Features

#### 🚀 Core Improvements

- **Enhanced Idempotency**: Every major step will check if work is already done before executing
- **User Data Preservation**: `--uninstall` will preserve `~/Documents/Image-Line/` and prompt before destructive actions
- **New `--uninstall-full`**: Complete clean uninstall option for fresh starts
- **Auto-Update Detection**: Script will detect installed vs latest versions and prompt for updates
- **New `--update` Flag**: Force update all components to latest versions

#### 🔧 Technical Fixes

- **WineASIO Registration**: Use WINEDLLPATH environment variable to solve regsvr32 DLL loading errors
- **Browser Integration**: Configure Wine URL handlers to use winebrowser.exe routing to xdg-open
- **Improved Icon Detection**: Enhanced search paths to prevent false "not found" warnings
- **WebView2 Workaround**: New `--hide-broken` flag to optionally hide non-functional SOUNDS, HELP, and GOPHER tabs via registry

#### 🛡️ Enhanced Reliability

- **Comprehensive Error Handling**: Better verification steps and user prompts for major decisions
- **Network Resilience**: Improved download retry logic and fallback sources
- **Dependency Management**: Smarter package detection and conflict resolution
- **Logging Enhancement**: More detailed installation logs for troubleshooting

#### 🎛️ New Features

- **Audio Backend Selection**: Choose between PipeWire, JACK2, or ALSA during installation
- **Plugin Management**: Enhanced yabridge and Windows VST management tools
- **Performance Profiles**: Pre-configured settings for gaming, production, or battery use
- **Backup/Restore**: Save and restore FL Studio configurations and projects

### Long-term Vision

- **Native .deb/.rpm Packages**: Distribution-specific packages for easier installation
- **Flatpak Support**: Sandboxed installation option
- **GUI Frontend**: Graphical interface for non-technical users
- **Plugin Marketplace**: Curated collection of Wine-compatible VST plugins
- **More AI Model Integration**: Pre-trained music generation models specifically for FL Studio workflows

---

## Troubleshooting

| Symptom                           | Fix                                                          |
| --------------------------------- | ------------------------------------------------------------ |
| `NO_PUBKEY …` during `apt update` | Re-run script; Wine key is installed to `/etc/apt/keyrings`. |
| Audio crackles                    | Lower buffer (128) in WineASIO or increase PipeWire quantum. |
| VSTs missing in host              | Run `yabridgectl sync`; ensure Wine and yabridge match.      |
| ALSA device not visible in JACK   | Check `systemctl --user status a2jmidid`.                    |
| Ollama says "model not found"     | `ollama pull <model>` then edit `~/.local/bin/ollama-mcp`.   |
| Black screens in FL Studio tabs   | Known WebView2 limitation - use alternative methods for sounds/help |
| WineASIO not in audio devices     | Restart FL Studio or manually register: `WINEPREFIX="$PREFIX" wine regsvr32 C:\\windows\\system32\\wineasio.dll` |

### Common Solutions

**Problem**: FL Studio crashes on startup
**Solution**: Run with `WINEDEBUG=-all` to suppress debug output, or increase Wine prefix memory settings

**Problem**: No sound output
**Solution**:

1. Check FL Studio Audio Settings → Device → Select "WineASIO"
2. Ensure JACK/PipeWire is running: `systemctl --user status pipewire`
3. Verify buffer settings: 128-256 samples recommended

**Problem**: MIDI devices not detected
**Solution**:

1. Enable a2jmidid: `systemctl --user enable --now a2jmidid.service`
2. Restart FL Studio
3. Check JACK connections with `catia` or `qjackctl`

## Credits & License

* **Script and Docs:** © 2025 Benevolence Messiah (MIT).
* **Big Thanks to:** WineHQ, yabridge, JACK/PipeWire, a2jmidid, Ollama, n8n, Continue, Cursor, and the Model Context Protocol (MCP) community for their open-source brilliance.
* **Shoutout to:** ImageLine for making a program that works great on Windows, and effectively the best DAW out there!
* **Honorable mention to:** ImageLine for refusing to compile the program with native Ubuntu integration and forcing me to make this script!

Contributions are welcome—please open a PR!

### Disclaimer

It should go without saying, but I'll mention here:

- I am in no way affiliated with ImageLine or FL Studio; this script is not officially endorsed in any capacity by ImageLine or any mentioned third party - it is simply a community resource for people who want to run FL Studio on Linux.

- This script is a hodgepodge of wrapping, additional resources, substituion, and years of combing best practices of running FL Studio on Ubuntu. It isn't guaranteed to work (but the basic `--no-features` install should work just fine for Ubuntu at least and the script should be future proofed because all of the hard stuff is taken care of).

- I don't know when/if Wine will fix the issue with Microsoft Edge WebView2 - as such the HELP, SOUNDS, and GOPHER tabs do not work currently.

---

Enjoy producing beats *and* bending them with AI—now entirely on Linux!
