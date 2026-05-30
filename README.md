# Hermes ARM64 Setup

[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20ARM64-0078D6.svg)](https://github.com/manofiron111/hermes-arm64-setup)

> One-command installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on ARM64 Windows devices.

**Hermes Agent** is an open-source AI agent framework by [Nous Research](https://nousresearch.com/). This project provides a compatibility installer for ARM64 Windows (Snapdragon X, Surface Pro X, Huawei MateBook E, etc.) where the official installer may encounter ARM64-specific issues.

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
8. **Post-install**: desktop shortcut, optional Web UI with auto-start

---

## Compatibility: What's Different from the Official Installer?

The [official Hermes Agent installer](https://github.com/NousResearch/hermes-agent/blob/main/scripts/install.ps1) works excellently on x64 Windows. On ARM64, the following issues arise — and this installer addresses each:

| Step | Official Installer | ARM64 Issue | This Installer's Fix |
|------|-------------------|-------------|---------------------|
| **Python** | Uses system Python or x86 uv Python | x86 Python under emulation is slower and causes native module mismatches | Explicitly installs ARM64-native `cpython-3.11-windows-arm64-none` via uv |
| **Git Clone** | `git clone` with submodules | ARM64 Git's `sh.exe` fails ("Function not implemented"); submodules error out | Downloads ZIP archive from GitHub instead of cloning |
| **psutil** | `psutil==7.2.2` compiled from source | No ARM64 wheel for 7.2.2; compilation requires Visual C++ Build Tools (~5 GB) | Installs `psutil==7.1.1` pre-built wheel; API-compatible |
| **Dependencies** | `pip install -e .[cli]` resolves all at once | Resolver re-downloads psutil 7.2.2 source, fails to build | Installs hermes-agent with `--no-deps`, then installs deps individually |
| **Web UI** | hermes-web-ui via npm | Works but stability varies; boot can hang on gateway auto-start | Installs with Task Scheduler auto-start; `-SkipWebUI` flag available |
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
pip install psutil --only-binary :all:
```

### Web UI starts but `localhost:8648` shows nothing

```powershell
hermes-web-ui status
hermes-web-ui stop
hermes-web-ui start
# Check logs:
Get-Content "$env:USERPROFILE\.hermes-web-ui\logs\server.log" -Tail 20
```

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

---

## Requirements

- Windows 10/11 ARM64 (or x64 with override)
- 5 GB free disk space
- Internet connection (HTTP proxy supported)
- PowerShell 5.1+

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

---

## License

AGPL-3.0 — see [LICENSE](LICENSE).

Hermes Agent is MIT-licensed by Nous Research. This installer is a separate work under AGPL-3.0.
