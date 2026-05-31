# Changelog

## [0.2.0] — 2026-05-31

### Added
- **Runtime Patch section** documenting the `discover_plugins()` deadlock fix (3 files)
- **Gateway slow startup** (~2-3 min) known issue — `discover_mcp_tools` 120s timeout
- **FRP ARM64 instability** known issue — Python TCP tunnel workaround
- **WinError 216** binary incompatibility known issue (non-fatal)
- **Missing `websockets` module** fix (`pip install websockets`)
- **pywin32 COM errors** on ARM64 known issue
- **QQ Bot troubleshooting**: shared-appid conflict and session residue cleanup
- Re-apply-patch-after-upgrade warnings throughout docs

### Discovered (real-world testing, May 30)
- `_scan_entry_points()` → `importlib.metadata.entry_points()` deadlocks on ARM64 Windows
- `psutil==7.2.2` has no ARM64 wheel; pinned to `7.1.1` (last version with ARM64 wheel)
- ARM64 Git `sh.exe` fails on submodule operations
- QQ Bot messages intercepted when multiple Gateways share same appid
- `/new` command ineffective when `sessions/` directory has stale files
- API key validation must happen BEFORE deployment (wasted hours on dead key)
- FRP ARM64 `frpc` binary crashes frequently on Snapdragon 850
- Web UI `rollup` native module causes silent crashes after hours

### Lessons Learned
1. **Verify before deploy** — test API keys, commands, and full workflows locally before sending to user's device
2. **ARM64 ≠ x64** — never assume binaries work; always check wheel availability
3. **SSH reliability** — 3 failed attempts = stop, switch to PowerShell paste
4. **Independent testing** — each device needs its own QQ Bot appid
5. **Patch persistence** — runtime patches are lost on Hermes Agent upgrade

---

## [0.1.0] — 2026-05-30

### Initial Release

- One-command `install.ps1` for ARM64 Windows
- ARM64-native Python 3.11 installation via uv
- ZIP-based download (bypasses ARM64 Git submodule issues)
- `psutil==7.1.1` pin (only ARM64 wheel available)
- `--no-deps` install strategy for hermes-agent
- Auto-detect correct API key env var per provider
- Proxy support for users in China
- Web UI auto-start via Task Scheduler
- Desktop shortcut creation
- Tested on Huawei MateBook E (Snapdragon 850, Win10 19045)
