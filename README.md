# Hermes ARM64 Setup

> One-command installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) on ARM64 Windows devices.

**Hermes Agent** is an open-source AI agent framework by [Nous Research](https://nousresearch.com/). This project provides a compatibility installer for ARM64 Windows (Snapdragon X, Surface Pro X, Huawei MateBook E, etc.) where the official installer may encounter ARM64-specific issues.

## Quick Start

```powershell
# Download and run
powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey sk-your-key-here

# With proxy (for users in China)
powershell -ExecutionPolicy Bypass -File install.ps1 -Proxy http://127.0.0.1:10809 -ApiKey sk-your-key-here
```

## Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ApiKey` | (required) | API key for your LLM provider |
| `-Model` | `deepseek-v4-pro` | Model name |
| `-Provider` | `deepseek` | Provider (deepseek, openai, anthropic, etc.) |
| `-Proxy` | (none) | HTTP proxy for GitHub access |
| `-SkipWebUI` | false | Skip Web UI installation |
| `-Help` | | Show help |

## What It Does

1. Detects ARM64 architecture and available disk space
2. Configures proxy (if needed for GitHub access)
3. Installs prerequisites (Node.js, Git, uv) via winget
4. Installs ARM64-native Python 3.11 via uv
5. Downloads Hermes Agent source from GitHub
6. Sets up Python venv with ARM64 Python
7. Installs dependencies (with psutil ARM64 workaround)
8. Configures API key and model settings
9. Optionally installs Web UI with auto-start

## ARM64-Specific Issues Addressed

- **ARM64 Python**: Installs native ARM64 Python instead of x86 emulation
- **psutil**: Uses pre-built wheel (psutil 7.1.1) since 7.2.2 has no ARM64 wheel
- **Git clone**: Falls back to ZIP download when ARM64 Git has submodule issues
- **Web UI**: Installs with auto-start, though stability varies by device

## Supported Providers

Any provider supported by Hermes Agent. Common ones:

```powershell
# DeepSeek
.\install.ps1 -Provider deepseek -Model deepseek-v4-pro -ApiKey sk-xxx

# OpenAI
.\install.ps1 -Provider openai -Model gpt-4o -ApiKey sk-xxx

# Anthropic
.\install.ps1 -Provider anthropic -Model claude-sonnet-4-20250514 -ApiKey sk-ant-xxx
```

## After Installation

```powershell
# Command line
hermes chat -q "Hello!"
hermes chat                    # Interactive mode

# Web UI
# Open http://localhost:8648 in your browser
```

## Requirements

- Windows 10/11 ARM64
- 5GB free disk space
- Internet connection (proxy supported)

## FAQ

**Q: Is this an official Hermes Agent project?**
A: No. This is a community installer for ARM64 compatibility. Hermes Agent is by [Nous Research](https://github.com/NousResearch/hermes-agent).

**Q: Why not use the official installer?**
A: The official `install.ps1` works great on x64 but may encounter ARM64-specific issues (Python architecture, psutil compilation, Web UI compatibility). This installer addresses those.

**Q: Will this work on x64 Windows?**
A: Yes, but the official installer is recommended for x64. This one is optimized for ARM64.

## License

AGPL-3.0 — see [LICENSE](LICENSE).

Hermes Agent is MIT-licensed by Nous Research. This installer is a separate work under AGPL-3.0.
