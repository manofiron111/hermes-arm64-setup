# Hermes Agent ARM64 Windows Setup
# One-command installer for ARM64 Windows devices (Snapdragon X, Surface Pro X, etc.)
# Hermes Agent by Nous Research: https://github.com/NousResearch/hermes-agent
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey sk-xxx
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Proxy http://proxy:port -ApiKey sk-xxx
#
# TIP: If you see "running scripts is disabled", run this first:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

param(
    [string]$Proxy = "",
    [string]$ApiKey = "",
    [string]$Model = "deepseek-v4-pro",
    [string]$Provider = "deepseek",
    [switch]$SkipWebUI = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Continue"
$script:StartTime = Get-Date

# Provider -> env var mapping
$ProviderEnvVars = @{
    "deepseek"    = "DEEPSEEK_API_KEY"
    "openai"      = "OPENAI_API_KEY"
    "anthropic"   = "ANTHROPIC_API_KEY"
    "openrouter"  = "OPENROUTER_API_KEY"
    "xai"         = "XAI_API_KEY"
    "google"      = "GOOGLE_API_KEY"
    "kimi"        = "KIMI_API_KEY"
    "dashscope"   = "DASHSCOPE_API_KEY"
    "minimax"     = "MINIMAX_API_KEY"
}

# ============================================================
# Banner
# ============================================================
function Show-Banner {
    Write-Host @"
================================================
  Hermes Agent - ARM64 Windows Installer
  For Snapdragon / ARM-based Windows devices
  Hermes Agent by Nous Research
================================================
"@ -ForegroundColor Cyan
}

function Show-Help {
    Show-Banner
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File install.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -ApiKey sk-xxx              API key for your LLM provider"
    Write-Host "  -Model deepseek-v4-pro      Model name (default: deepseek-v4-pro)"
    Write-Host "  -Provider deepseek          Provider: deepseek, openai, anthropic, openrouter, etc."
    Write-Host "  -Proxy http://proxy:port    HTTP proxy for GitHub access"
    Write-Host "  -SkipWebUI                  Skip Web UI installation"
    Write-Host "  -Help                       Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1 -ApiKey sk-xxx"
    Write-Host "  .\install.ps1 -Provider openai -Model gpt-4o -Proxy http://127.0.0.1:10809 -ApiKey sk-xxx"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  If you see 'running scripts is disabled', run:"
    Write-Host "    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass"
    exit 0
}

if ($Help) { Show-Help }

# ============================================================
# Helpers
# ============================================================
function Write-Step { Write-Host "`n>>> $args" -ForegroundColor Yellow }
function Write-OK { Write-Host "    [OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "    [WARN] $args" -ForegroundColor Yellow }
function Write-Fail { Write-Host "    [FAIL] $args" -ForegroundColor Red }

# ============================================================
# Step 1: Detect Environment
# ============================================================
function Invoke-Detect {
    Write-Step "Step 1/8: Detecting environment..."

    $arch = $env:PROCESSOR_ARCHITECTURE
    Write-OK "Architecture: $arch"

    if ($arch -ne "ARM64") {
        Write-Warn "This installer is optimized for ARM64. Your arch is $arch."
        Write-Warn "For x64, use: irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1 | iex"
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y") { exit 0 }
    }

    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-OK "OS: $os"

    $disk = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free/1GB, 1)
    Write-OK "Disk: $freeGB GB free"
    if ($freeGB -lt 5) {
        Write-Fail "Less than 5GB free. Please free up space."
        exit 1
    }
}

# ============================================================
# Step 2: Configure Proxy
# ============================================================
function Invoke-Proxy {
    Write-Step "Step 2/8: Configuring network..."

    if ($Proxy) {
        $env:HTTP_PROXY = $Proxy
        $env:HTTPS_PROXY = $Proxy
        Write-OK "Proxy set: $Proxy"
    } else {
        Write-OK "No proxy (direct connection)"
    }

    try {
        Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 10 -UseBasicParsing | Out-Null
        Write-OK "GitHub reachable"
    } catch {
        Write-Warn "GitHub not reachable. Use -Proxy parameter if needed."
        Write-Warn "Example: .\install.ps1 -Proxy http://127.0.0.1:10809 -ApiKey sk-xxx"
        if (-not $Proxy) {
            $userProxy = Read-Host "Enter proxy URL (or press Enter to skip)"
            if ($userProxy) {
                $script:Proxy = $userProxy
                $env:HTTP_PROXY = $userProxy
                $env:HTTPS_PROXY = $userProxy
            }
        }
    }
}

# ============================================================
# Step 3: Check/Install Prerequisites
# ============================================================
function Invoke-Prerequisites {
    Write-Step "Step 3/8: Checking prerequisites..."

    $needed = @()

    try { $nv = (node --version 2>$null); Write-OK "Node.js: $nv" }
    catch { $needed += "Node.js"; Write-Warn "Node.js not found" }

    try { $gv = (git --version 2>$null); Write-OK "Git: $gv" }
    catch { $needed += "Git"; Write-Warn "Git not found" }

    try { $uv = (uv --version 2>$null); Write-OK "uv: $uv" }
    catch { $needed += "uv"; Write-Warn "uv not found" }

    if ($needed.Count -gt 0) {
        Write-Warn "Missing: $($needed -join ', ')"
        Write-Warn "Attempting to install via winget..."
        foreach ($pkg in $needed) {
            switch ($pkg) {
                "Node.js" { winget install OpenJS.NodeJS --silent 2>$null }
                "Git"     { winget install Git.Git --silent 2>$null }
                "uv"      { powershell -c "irm https://astral.sh/uv/install.ps1 | iex" 2>$null }
            }
        }
        Write-Warn "Please restart your terminal and run this script again."
        exit 0
    }
}

# ============================================================
# Step 4: Install ARM64 Python
# ============================================================
function Invoke-Python {
    Write-Step "Step 4/8: Installing ARM64 Python 3.11..."

    $existing = uv python list 2>&1 | Select-String "aarch64"
    if ($existing) {
        Write-OK "ARM64 Python already installed"
    } else {
        Write-OK "Downloading ARM64 Python 3.11..."
        uv python install cpython-3.11-windows-arm64-none 2>&1 | Out-Null
        Write-OK "ARM64 Python installed"
    }
}

# ============================================================
# Step 5: Download and Extract Hermes
# ============================================================
function Invoke-Download {
    Write-Step "Step 5/8: Downloading Hermes Agent..."

    $hermesHome = "$env:LOCALAPPDATA\hermes"
    $targetDir = "$hermesHome\hermes-agent"
    $zipPath = "$env:TEMP\hermes-main.zip"

    if (Test-Path $targetDir) {
        Write-OK "Removing previous installation..."
        Remove-Item -Recurse -Force $targetDir
    }

    Write-OK "Downloading from GitHub..."
    try {
        Invoke-WebRequest -Uri "https://github.com/NousResearch/hermes-agent/archive/refs/heads/main.zip" `
            -OutFile $zipPath -TimeoutSec 180 -UseBasicParsing
        Write-OK "Downloaded: $([math]::Round((Get-Item $zipPath).Length/1MB, 1)) MB"
    } catch {
        Write-Fail "Download failed. Try: .\install.ps1 -Proxy http://proxy:port"
        exit 1
    }

    Write-OK "Extracting..."
    try {
        Expand-Archive -Path $zipPath -DestinationPath $hermesHome -Force
        Rename-Item "$hermesHome\hermes-agent-main" $targetDir -Force
    } catch {
        Write-Fail "Extraction failed. The ZIP may be corrupt. Try re-running."
        exit 1
    }
    Remove-Item $zipPath
    Write-OK "Extracted to: $targetDir"
}

# ============================================================
# Step 6: Setup Python Environment
# ============================================================
function Invoke-Venv {
    Write-Step "Step 6/8: Setting up Python environment..."

    $targetDir = "$env:LOCALAPPDATA\hermes\hermes-agent"
    $python = "$targetDir\venv\Scripts\python.exe"

    Write-OK "Creating venv with ARM64 Python..."
    uv venv --python cpython-3.11 "$targetDir\venv" 2>&1 | Out-Null

    Write-OK "Installing psutil==7.1.1 (only ARM64 wheel available)..."
    # Pinned to 7.1.1 — the last version with a published ARM64 wheel.
    # 7.2.2+ require source compilation (Visual C++ Build Tools ~5 GB).
    & $python -m pip install psutil==7.1.1 --only-binary :all: -q 2>&1 | Out-Null

    Write-OK "Installing hermes-agent core..."
    & $python -m pip install --no-deps -e $targetDir -q 2>&1 | Out-Null

    Write-OK "Installing remaining dependencies..."
    # NOTE: These versions are pinned for hermes-agent v0.15.x.
    # If a newer hermes-agent requires different versions, update this list.
    $deps = @(
        "openai==2.24.0", "python-dotenv", "fire", "httpx[socks]", "rich",
        "tenacity", "pyyaml", "ruamel.yaml", "requests", "jinja2",
        "pydantic", "prompt_toolkit", "croniter", "PyJWT[crypto]", "tzdata",
        "simple-term-menu", "fastapi", "uvicorn",
        "pywin32"  # Required for Windows-specific features (service mgmt, COM, etc.)
    )
    foreach ($dep in $deps) {
        & $python -m pip install $dep --no-cache-dir -q 2>&1 | Out-Null
    }
    Write-OK "All dependencies installed"

    $result = & $python -c "import hermes_cli; print('OK')" 2>&1
    if ($result -match "OK") {
        Write-OK "hermes_cli verified"
    } else {
        Write-Fail "hermes_cli import failed: $result"
    }
}

# ============================================================
# Step 7: Configure
# ============================================================
function Invoke-Configure {
    Write-Step "Step 7/8: Configuring Hermes..."

    $hermesHome = "$env:LOCALAPPDATA\hermes"
    New-Item -ItemType Directory -Force -Path $hermesHome | Out-Null

    # Use the correct env var for this provider
    $envVarName = $ProviderEnvVars[$Provider.ToLower()]
    if (-not $envVarName) {
        $envVarName = $Provider.ToUpper() + "_API_KEY"
    }

    if ($ApiKey) {
        @"
$envVarName=$ApiKey
API_SERVER_ENABLED=true
"@ | Out-File -FilePath "$hermesHome\.env" -Encoding ascii
        Write-OK "$envVarName configured"
    } else {
        Write-Warn "No API key provided. Add it to: $hermesHome\.env"
        @"
# Add your API key here:
# $envVarName=sk-xxx
API_SERVER_ENABLED=true
"@ | Out-File -FilePath "$hermesHome\.env" -Encoding ascii
    }
    Write-OK ".env configured"

    @"
model:
  default: $Model
  provider: $Provider
"@ | Out-File -FilePath "$hermesHome\config.yaml" -Encoding utf8
    Write-OK "Model: $Model / Provider: $Provider"

    # Add to PATH
    $scriptDir = "$hermesHome\hermes-agent\venv\Scripts"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$scriptDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$scriptDir", "User")
        Write-OK "Added to user PATH"
    }
}

# ============================================================
# Step 8: Post-Install
# ============================================================
function Invoke-PostInstall {
    Write-Step "Step 8/8: Post-install..."

    $hermesHome = "$env:LOCALAPPDATA\hermes"
    $venvScripts = "$hermesHome\hermes-agent\venv\Scripts"

    # Desktop shortcut
    @"
[InternetShortcut]
URL=http://localhost:8648
IconFile=$env:SystemRoot\System32\SHELL32.dll
IconIndex=130
"@ | Out-File -FilePath "$env:USERPROFILE\Desktop\Hermes AI.url" -Encoding ascii
    Write-OK "Desktop shortcut created"

    # Refresh PATH for this session so hermes is available immediately
    $env:Path = "$venvScripts;" + [Environment]::GetEnvironmentVariable("Path", "User")

    # Web UI
    if (-not $SkipWebUI) {
        Write-OK "Installing Web UI..."
        npm install -g hermes-web-ui@latest 2>&1 | Out-Null

        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-WindowStyle Hidden -Command `"`$env:HERMES_HOME='$hermesHome'; `$env:Path='$venvScripts;' + [Environment]::GetEnvironmentVariable('Path','Machine'); hermes-web-ui start`""
        $trigger = New-ScheduledTaskTrigger -AtLogon
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName "HermesWebUI" -Action $action -Trigger $trigger `
            -Principal $principal -Force | Out-Null
        Write-OK "Web UI auto-start registered"

        # Start Web UI now with health check
        $env:HERMES_HOME = $hermesHome
        Write-OK "Starting Web UI..."
        hermes-web-ui start 2>&1 | Out-Null

        # Health check: retry up to 10 times (5 seconds)
        $healthy = $false
        for ($i = 1; $i -le 10; $i++) {
            Start-Sleep -Milliseconds 500
            try {
                $r = Invoke-WebRequest -Uri "http://localhost:8648" -TimeoutSec 2 -UseBasicParsing
                if ($r.StatusCode -eq 200) {
                    $healthy = $true
                    break
                }
            } catch {}
        }
        if ($healthy) {
            Write-OK "Web UI running at http://localhost:8648"
        } else {
            Write-Warn "Web UI may still be starting. Check: http://localhost:8648"
            Write-Warn "If the page doesn't load, run: hermes-web-ui restart"
        }
    }

    Write-OK "Testing Hermes..."
    & "$venvScripts\hermes.exe" --version 2>&1 | ForEach { Write-OK $_ }
}

# ============================================================
# Main
# ============================================================
function Main {
    Show-Banner
    Invoke-Detect
    Invoke-Proxy
    Invoke-Prerequisites
    Invoke-Python
    Invoke-Download
    Invoke-Venv
    Invoke-Configure
    Invoke-PostInstall

    $elapsed = [math]::Round(((Get-Date) - $script:StartTime).TotalMinutes, 1)
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  Installation complete! ($elapsed min)" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Quick start:" -ForegroundColor Cyan
    Write-Host "  hermes chat -q 'Hello!'"
    Write-Host "  Web UI: http://localhost:8648"
    Write-Host ""
    Write-Host "To uninstall, delete these folders:" -ForegroundColor Cyan
    Write-Host "  $env:LOCALAPPDATA\hermes"
    Write-Host "  $env:USERPROFILE\.hermes-web-ui"
    Write-Host ""
    Write-Host "Hermes Agent by Nous Research: https://github.com/NousResearch/hermes-agent"
}

Main
