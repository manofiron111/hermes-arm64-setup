# Hermes ARM64 Setup

> One-command installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on ARM64 Windows devices.

**Hermes Agent** is an open-source AI agent framework by [Nous Research](https://nousresearch.com/). This project provides a compatibility installer for ARM64 Windows (Snapdragon X, Surface Pro X, Huawei MateBook E, etc.) where the official installer may encounter ARM64-specific issues.

---

## Quick Start

```powershell
# 1. Download install.ps1 from this repo
# 2. Run:
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
- Git 2.54.0 (with known ARM64 limitations, see below)

---

## Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ApiKey` | *(required)* | API key for your LLM provider |
| `-Model` | `deepseek-v4-pro` | Model name |
| `-Provider` | `deepseek` | Provider (deepseek, openai, anthropic, etc.) |
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
7. **Configures** API key, model, provider settings
8. **Post-install**: desktop shortcut, optional Web UI with auto-start

---

## Compatibility: What's Different from the Official Installer?

The [official Hermes Agent installer](https://github.com/NousResearch/hermes-agent/blob/main/scripts/install.ps1) works excellently on x64 Windows. On ARM64, the following issues arise — and this installer addresses each:

| Step | Official Installer | ARM64 Issue | This Installer's Fix |
|------|-------------------|-------------|---------------------|
| **Python** | Uses system Python or x86 uv Python | x86 Python under emulation is slower and causes native module mismatches | Explicitly installs ARM64-native `cpython-3.11-windows-arm64-none` via uv |
| **Git Clone** | `git clone` with submodules | ARM64 Git's `sh.exe` fails ("Function not implemented"); submodules error out | Downloads ZIP archive from GitHub instead of cloning |
| **psutil** | `psutil==7.2.2` compiled from source | No ARM64 wheel for 7.2.2; compilation requires Visual C++ Build Tools (~5 GB) | Installs `psutil==7.1.1` pre-built wheel; API-compatible with 7.2.2 |
| **Dependencies** | `pip install -e .[cli]` resolves all at once | Dependency resolver re-downloads psutil 7.2.2 source, fails to build | Installs hermes-agent with `--no-deps`, then installs each dependency individually |
| **Web UI** | hermes-web-ui via npm | Works but stability varies; boot can hang on gateway auto-start | Installs with auto-start via Task Scheduler; `-SkipWebUI` flag available |
| **GitHub Access** | Direct connection assumed | GitHub may be unreachable in some regions | Built-in `-Proxy` parameter; interactive prompt on connection failure |

---

## Supported Providers

Any provider supported by Hermes Agent:

```powershell
# DeepSeek (default)
.\install.ps1 -Provider deepseek -Model deepseek-v4-pro -ApiKey sk-xxx

# OpenAI
.\install.ps1 -Provider openai -Model gpt-4o -ApiKey sk-xxx

# Anthropic
.\install.ps1 -Provider anthropic -Model claude-sonnet-4-20250514 -ApiKey sk-ant-xxx

# OpenRouter
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

## Troubleshooting

### Installation fails with "GitHub not reachable"

**Cause:** Direct GitHub access is blocked or slow in your region.

**Fix:** Use the `-Proxy` parameter:
```powershell
.\install.ps1 -Proxy http://your-proxy:port -ApiKey sk-xxx
```

### `psutil` build fails with "Microsoft Visual C++ 14.0 or greater is required"

This should not happen with this installer (we use a pre-built wheel). If you see it:
```powershell
# Manually install the pre-built wheel
pip install psutil --only-binary :all:
```

### Web UI starts but `localhost:8648` shows nothing

**Cause:** On some ARM64 devices, hermes-web-ui may take longer to boot or fail silently.

**Fix:**
```powershell
# Check status
hermes-web-ui status

# Restart
hermes-web-ui stop
hermes-web-ui start

# Check logs
type %USERPROFILE%\.hermes-web-ui\logs\server.log
```

### `hermes` command not found after install

**Cause:** PATH update requires a new terminal session.

**Fix:** Open a new PowerShell/CMD window, or run:
```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
hermes --version
```

### ARM64 Git errors ("sh.exe: Function not implemented")

This is a known ARM64 Git limitation. This installer avoids git operations entirely (uses ZIP download). If you need git for other purposes, it will work for basic operations but submodules and some shell-based features may fail.

### Installer reports "Not ARM64" on my Snapdragon X device

Some Snapdragon X devices report `AMD64` in `$env:PROCESSOR_ARCHITECTURE` when running in emulation mode. Run this to verify:
```powershell
systeminfo | findstr "System Type"
# Should show "ARM64-based PC"
```
The installer will prompt to continue anyway on non-ARM64 arch.

---

## Requirements

- Windows 10/11 ARM64 (or x64 with explicit override)
- 5 GB free disk space
- Internet connection (HTTP proxy supported)
- PowerShell 5.1+

---

## FAQ

**Q: Is this an official Hermes Agent project?**
A: No. This is a community-maintained installer for ARM64 compatibility. Hermes Agent is created and maintained by [Nous Research](https://github.com/NousResearch/hermes-agent). This installer does not modify Hermes Agent source code.

**Q: Why a separate project instead of contributing to the official installer?**
A: The changes required are substantial (ZIP download path, ARM64 Python selection, dependency workarounds) and target a specific platform. A separate tool keeps the official installer simple for the majority x64 user base while providing a clear solution for ARM64 users.

**Q: Will this work on x64 Windows?**
A: Yes, but the [official installer](https://github.com/NousResearch/hermes-agent) is recommended for x64. This installer is optimized for ARM64.

---

## License

AGPL-3.0 — see [LICENSE](LICENSE).

Hermes Agent is MIT-licensed by Nous Research. This installer is a separate, independent work under AGPL-3.0.
