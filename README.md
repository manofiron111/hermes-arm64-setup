# Hermes ARM64 Setup

[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20ARM64-0078D6.svg)](https://github.com/manofiron111/hermes-arm64-setup)

> One-command installer + runtime patch suite for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on ARM64 Windows devices.

**Hermes Agent** is an open-source AI agent framework by [Nous Research](https://nousresearch.com/). This project provides:
- 📦 A one-command **installer** for ARM64 Windows (Snapdragon X, Surface Pro X, Huawei MateBook E, etc.)
- 🔧 **Runtime patches** for ARM64-specific issues that persist after installation
- 📋 **Troubleshooting guides** for known ARM64 problems

**Supported Hermes Agent versions:** v0.15.x (tested with v0.15.1). Newer versions may work but have not been verified.

---

## Quick Start

```powershell
# One-liner download and run:
irm https://raw.githubusercontent.com/manofiron111/hermes-arm64-setup/main/install.ps1 | iex

# Or download first, then run with options:
Invoke-WebRequest -Uri https://raw.githubusercontent.com/manofiron111/hermes-arm64-setup/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey sk-your-key-here

# With proxy (for users in China):
powershell -ExecutionPolicy Bypass -File install.ps1 -Proxy http://127.0.0.1:10809 -ApiKey sk-your-key-here
```

**⚠️ After installation, apply the [runtime patch](#runtime-patch-required) before starting the Gateway.**

---

## Tested Hardware

| Device | CPU | RAM | Windows | Status |
|--------|-----|-----|---------|--------|
| Huawei MateBook E | Snapdragon 850 (ARM64) | 8 GB | Win10 22H2 (19045) | ✅ Fully working |
| *(Your device here)* | | | | *Please report!* |

**Test environment details:**
- Hermes Agent v0.15.1
- Python 3.11.15 (ARM64 native)
- Node.js v24.16.0
- Git 2.54.0 (with known ARM64 limitations, see Compatibility section)

---

## Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ApiKey` | *(optional)* | API key for your LLM provider (can be set later) |
| `-Model` | `deepseek-v4-pro` | Model name |
| `-Provider` | `deepseek` | Provider (deepseek, openai, anthropic, openrouter, etc.) |
| `-Proxy` | *(none)* | HTTP proxy URL for GitHub access |
| `-SkipWebUI` | `false` | Skip Web UI installation |
| `-Help` | | Show help message |

---

## What It Does (8 Steps)

1. **Detects** ARM64 architecture and available disk space
2. **Configures** proxy if needed (essential for users in China)
3. **Checks/installs** prerequisites: Node.js, Git, uv (via winget)
4. **Installs ARM64-native** Python 3.11 via uv (not x86 emulation)
5. **Downloads** Hermes Agent source as ZIP (avoids ARM64 Git issues)
6. **Sets up** Python venv + installs all dependencies with ARM64 workarounds
7. **Configures** API key, model, provider (auto-selects correct env var per provider)
8. **Post-install**: desktop shortcut, optional Web UI with auto-start + health check

---

## ⚠️ Runtime Patch (Required)

After installation, the Gateway will **hang indefinitely** on startup. This is the most critical ARM64 issue — `discover_plugins()` → `_scan_entry_points()` deadlocks on ARM64 Windows. Three files must be patched:

### Affected files (under `C:\Users\<user>\AppData\Local\hermes\hermes-agent\`):

#### 1. `hermes_cli/plugins.py` — Core fix

```python
# Replace _scan_entry_points to return empty list immediately
def _scan_entry_points(self) -> List[PluginManifest]:
    """SKIPPED: hangs on Windows ARM64."""
    import logging; logging.getLogger(__name__).debug("_scan_entry_points SKIPPED (ARM64)")
    return []

# Replace discover_and_load to short-circuit
def discover_and_load(self, force: bool = False) -> None:
    """SKIPPED: hangs on Windows ARM64."""
    self._discovered = True
    return
```

#### 2. `gateway/config.py` — Comment out two `discover_plugins()` calls (~line 792, ~line 1814)

#### 3. `gateway/run.py` — Comment out `discover_plugins()` call (~line 4110)

> ℹ️ QQ Bot and other built-in platform adapters work without plugin discovery — only external plugins are affected.

### Run this after patching:

```powershell
pip install websockets  # Fixes browser_dialog_tool warning
```

Then start Gateway:
```powershell
hermes gateway run
```

**Expect ~2-3 minutes for first startup** — `discover_mcp_tools` has a 120-second timeout on ARM64 (not a deadlock, just slow).

---

## Compatibility: What's Different from the Official Installer?

The [official Hermes Agent installer](https://github.com/NousResearch/hermes-agent/blob/main/scripts/install.ps1) works excellently on x64 Windows. On ARM64, the following issues arise — and this installer addresses each:

| Step | Official Installer | ARM64 Issue | This Installer's Fix |
|------|-------------------|-------------|---------------------|
| **Python** | Uses system Python or x86 uv Python | x86 Python under emulation is slower and causes native module mismatches | Explicitly installs ARM64-native `cpython-3.11-windows-arm64-none` via uv |
| **Git Clone** | `git clone` with submodules | ARM64 Git's `sh.exe` fails ("Function not implemented"); submodules error out | Downloads ZIP archive from GitHub instead of cloning |
| **psutil** | `psutil==7.2.2` compiled from source | No ARM64 wheel for 7.2.2; compilation requires Visual C++ Build Tools (~5 GB) | Installs `psutil==7.1.1` pre-built wheel; API-compatible |
| **Plugin Discovery** | `discover_plugins()` scans entry points | `_scan_entry_points()` hangs indefinitely on ARM64 | **Requires manual runtime patch** (see [Runtime Patch](#runtime-patch-required) above) |
| **Dependencies** | `pip install -e .[cli]` resolves all at once | Resolver re-downloads psutil 7.2.2 source, fails to build | Installs hermes-agent with `--no-deps`, then installs deps individually |
| **Web UI** | hermes-web-ui via npm | Works but stability varies; boot can hang on gateway auto-start | Installs with Task Scheduler auto-start; `-SkipWebUI` flag available; health check with retry |
| **GitHub Access** | Direct connection assumed | GitHub may be unreachable in some regions | Built-in `-Proxy` parameter; interactive fallback prompt |
| **API Key** | User must know correct env var name | Easy to use wrong env var for non-DeepSeek providers | Auto-selects correct env var (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.) |

---

## Supported Providers

The installer automatically uses the correct environment variable for each provider:

```powershell
# DeepSeek (default) → DEEPSEEK_API_KEY
.\install.ps1 -Provider deepseek -Model deepseek-v4-pro -ApiKey sk-xxx

# OpenAI → OPENAI_API_KEY
.\install.ps1 -Provider openai -Model gpt-4o -ApiKey sk-xxx

# Anthropic → ANTHROPIC_API_KEY
.\install.ps1 -Provider anthropic -Model claude-sonnet-4-20250514 -ApiKey sk-ant-xxx

# OpenRouter → OPENROUTER_API_KEY
.\install.ps1 -Provider openrouter -Model openai/gpt-4o -ApiKey sk-or-xxx
```

---

## After Installation

```powershell
# Command line
hermes chat -q "Hello!"
hermes chat                     # Interactive session

# Web UI
# Open http://localhost:8648 in your browser
# Desktop shortcut "Hermes AI" is also created
```

---

## Updating

When a new version of Hermes Agent is released:

```powershell
# 1. Download the updated installer
Invoke-WebRequest -Uri https://raw.githubusercontent.com/manofiron111/hermes-arm64-setup/main/install.ps1 -OutFile install.ps1

# 2. Run with your existing credentials
powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey sk-your-key-here
```

The installer will remove the previous installation and reinstall cleanly. Your API key and configuration will be preserved in `$env:LOCALAPPDATA\hermes\.env`.

**⚠️ After every upgrade, re-apply the [runtime patch](#runtime-patch-required).** Upgrading Hermes Agent overwrites the patched files.

**Note:** If the dependency list (`$deps` in `Invoke-Venv`) is outdated for a new Hermes Agent version, you'll see import errors. Please [open an issue](https://github.com/manofiron111/hermes-arm64-setup/issues) with the error output.

---

## Known Issues

### 1. Gateway startup is slow (~2-3 minutes)

`discover_mcp_tools()` on ARM64 has a 120-second timeout. This is not a deadlock — the process will eventually continue. Just wait.

**Workaround:** None needed for now. The timeout is cosmetic; Gateway functions normally after startup completes.

### 2. `discover_plugins()` hangs indefinitely (CRITICAL)

The most severe ARM64 issue. `_scan_entry_points()` deadlocks during Gateway startup, producing zero log output and never recovering.

**Fix:** Apply the [runtime patch](#runtime-patch-required) before starting Gateway. Must be re-applied after every Hermes Agent upgrade.

### 3. Web UI stability on ARM64

The `hermes-web-ui` npm package (v0.6.5) has known stability issues on ARM64 Windows due to native `rollup` module compatibility. Symptoms include:
- Gateway bootstrap hangs at startup
- Process crashes silently after a few hours
- `localhost:8648` returns "connection refused" after working initially

**Workaround:** Use the `hermes chat` CLI directly, or run `hermes-web-ui restart` when the UI becomes unresponsive. This is an upstream issue tracked by Nous Research — not specific to this installer.

### 4. FRP (Fast Reverse Proxy) ARM64 instability

The ARM64 `frpc` binary frequently crashes on Snapdragon 850 devices.

**Workaround:** Use Python TCP tunnels instead of FRP for remote access:
```python
# Example: simple TCP forwarder
import socket, threading
def forward(src, dst):
    while True:
        try:
            data = src.recv(4096)
            if not data: break
            dst.sendall(data)
        except: break
```

### 5. `WinError 216` — Binary incompatibility

```
[WinError 216] 该版本的 %1 与你运行的 Windows 版本不兼容
```

This appears when Hermes tries to execute x86-compiled binaries on ARM64. The error is **non-fatal** — affected operations fall back gracefully. No user action required.

### 6. `browser_dialog_tool` missing `websockets`

```
WARNING: Could not import tool module tools.browser_dialog_tool: No module named 'websockets'
```

**Fix:**
```powershell
pip install websockets
```

### 7. Git submodules on ARM64

Git for ARM64 Windows has a known limitation where `sh.exe` fails with "Function not implemented" when running submodule operations. This installer avoids Git entirely (uses ZIP download). For general Git usage on ARM64, basic clone/push/pull work; avoid submodules.

### 8. `pywin32` COM errors on ARM64

Certain Windows COM operations may fail with `pywin32` on ARM64. The `search_files` tool and some Windows-specific features may show errors. These are non-fatal and don't affect core Gateway functionality.

### 9. `winget` not available on some Windows 10 builds

Older Windows 10 ARM64 builds may not include `winget`. If prerequisite installation fails, install Node.js, Git, and uv manually before running this script.

---

## Uninstall

```powershell
# Remove Hermes Agent
Remove-Item -Recurse -Force $env:LOCALAPPDATA\hermes

# Remove Web UI
Remove-Item -Recurse -Force $env:USERPROFILE\.hermes-web-ui
npm uninstall -g hermes-web-ui

# Remove Scheduled Task
Unregister-ScheduledTask -TaskName "HermesWebUI" -Confirm:$false

# Remove from PATH via: Windows Settings → Environment Variables
```

---

## Troubleshooting

### Installation fails with "GitHub not reachable"

**Fix:** Use the `-Proxy` parameter:
```powershell
.\install.ps1 -Proxy http://your-proxy:port -ApiKey sk-xxx
```

### `psutil` build fails with "Microsoft Visual C++ 14.0 or greater is required"

Should not happen with this installer. If it does:
```powershell
pip install psutil==7.1.1 --only-binary :all:
```

### Gateway starts but no log output (hanging)

This is the `discover_plugins()` deadlock. Apply the [runtime patch](#runtime-patch-required).

### Web UI starts but `localhost:8648` shows nothing

```powershell
hermes-web-ui status
hermes-web-ui stop
hermes-web-ui start
# Check logs:
Get-Content "$env:USERPROFILE\.hermes-web-ui\logs\server.log" -Tail 20
```

### QQ Bot messages not being delivered

Common causes on ARM64:
1. **Shared appid with another Gateway instance** — use a dedicated QQ Bot appid for the tablet
2. **Session residue** — delete `sessions/` directory and restart Gateway
3. **`/new` command ineffective** — manually remove `$env:LOCALAPPDATA\hermes\.hermes\sessions\`

### `hermes` command not found after install

Open a new PowerShell window, or:
```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
hermes --version
```

### ARM64 Git errors ("sh.exe: Function not implemented")

Known ARM64 Git limitation. This installer avoids git entirely (uses ZIP). Git works for basic operations but submodules may fail.

### Installer reports "Not ARM64" on Snapdragon X

Some devices report `AMD64` in emulation mode. Verify with:
```powershell
systeminfo | findstr "System Type"
```
The installer will prompt to continue anyway.

### "Running scripts is disabled" error

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Requirements

- Windows 10/11 ARM64 (or x64 with override)
- 5 GB free disk space
- Internet connection (HTTP proxy supported)
- PowerShell 5.1+

---

## Contributing

Contributions are welcome — especially:

- **Test reports** from devices not yet listed above
- **Fixes** for new ARM64-specific issues with newer Hermes Agent versions
- **Dependency updates** when `$deps` in `Invoke-Venv` needs refreshing
- **Runtime patch improvements** for `discover_plugins()` and other ARM64 issues

To contribute:
1. Fork the repository
2. Make your changes (focus on `install.ps1`)
3. Test on an ARM64 Windows device
4. Open a pull request with a description of what you changed and why

Please keep the installer self-contained: no additional files unless absolutely necessary.

---

## FAQ

**Q: Is this an official Hermes Agent project?**
A: No. This is a community installer. Hermes Agent is by [Nous Research](https://github.com/NousResearch/hermes-agent). This project does not modify Hermes Agent source code.

**Q: Why a separate project?**
A: The changes are substantial and target a specific platform. This keeps both installers simple for their audiences.

**Q: Will this work on x64 Windows?**
A: Yes, but the [official installer](https://github.com/NousResearch/hermes-agent) is recommended.

**Q: How do I report an issue?**
A: [Open an issue](https://github.com/manofiron111/hermes-arm64-setup/issues) with your device model, Windows version, and the error output.

**Q: Do I need to re-apply the runtime patch after upgrading Hermes?**
A: Yes. Hermes Agent upgrades overwrite the patched files. Re-apply the patch after every upgrade.

---

## License

AGPL-3.0 — see [LICENSE](LICENSE).

Hermes Agent is MIT-licensed by Nous Research. This installer is a separate work under AGPL-3.0.
