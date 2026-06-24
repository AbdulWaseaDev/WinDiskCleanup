<div align="center">

# WinDiskCleanup

**One-command disk cleanup for Windows developers.**

Cleans browser caches, package manager caches, temp files, WSL/Docker virtual disks,  
and inactive project dependencies — all in a single run.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.5.0-brightgreen)](https://github.com/AbdulWaseaDev/WinDiskCleanup/releases/latest)
[![CI](https://github.com/AbdulWaseaDev/WinDiskCleanup/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/AbdulWaseaDev/WinDiskCleanup/actions/workflows/lint.yml)

[Installation](#installation) · [Usage](#usage) · [Configuration](#configuration) · [Contributing](#contributing)

</div>

---

## Quick Start

```powershell
# 1. Clone and open the folder
git clone https://github.com/AbdulWaseaDev/WinDiskCleanup.git
cd WinDiskCleanup

# 2. Preview what will be cleaned (safe — deletes nothing)
.\WinDiskCleanup.ps1 -DryRun

# 3. Run the full cleanup (as Administrator)
.\WinDiskCleanup.ps1
```

> **First time only:** `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

---

## What It Cleans

| # | Target | Notes |
|---|--------|-------|
| 1 | Chrome cache | All profiles, auto-detected |
| 2 | Claude Desktop cache | MSIX install, auto-detected |
| 3 | Microsoft Edge cache | All profiles, auto-detected |
| 4 | Firefox cache | All profiles, auto-detected |
| 5 | Brave cache | All profiles, auto-detected |
| 6 | npm cache | Skipped if npm not installed |
| 7 | pip cache | Skipped if pip not installed |
| 8 | Temp files | User temp + Windows temp |
| 9 | Windows Update cache | Safely stops/restarts wuauserv |
| 10 | Windows Store cache | wsreset |
| 11 | Recycle Bin | Configurable |
| 12 | VS Code duplicate extensions | Keeps newest version only |
| 13 | Microsoft Teams cache | Classic and MSIX Teams |
| 14 | Projects `__pycache__` | Configurable path |
| 15 | Inactive `node_modules` | You define which ones |
| 16 | Inactive Python venvs | You define which ones |
| 17 | Docker prune | Docker Desktop or Docker in WSL |
| 18 | WSL apt cleanup | `apt clean` + `autoremove` |
| 19 | WSL + Docker vhdx compaction | Reclaims unused virtual disk space |

Everything is **auto-detected** — if a tool is not installed, that step is silently skipped.  
No telemetry. No network calls. Runs entirely offline.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later (built into Windows)
- Run as **Administrator**

WSL, Docker, npm, pip, Chrome, Edge, VS Code, and Claude are all optional.

---

## Installation

**Option 1 — Scoop (recommended):**

```powershell
scoop bucket add windiskcleanup https://github.com/AbdulWaseaDev/WinDiskCleanup
scoop install windiskcleanup
```

**Option 2 — Git clone:**

```powershell
git clone https://github.com/AbdulWaseaDev/WinDiskCleanup.git
cd WinDiskCleanup
```

**Option 3 — ZIP:** [Download the latest release](https://github.com/AbdulWaseaDev/WinDiskCleanup/releases/latest) and extract anywhere.

---

## Usage

```powershell
# Full cleanup
.\WinDiskCleanup.ps1

# Preview only — see what would be deleted without deleting anything
.\WinDiskCleanup.ps1 -DryRun

# Confirm before each step
.\WinDiskCleanup.ps1 -Interactive

# Skip WSL and Docker disk compaction (faster run)
.\WinDiskCleanup.ps1 -SkipWSLCompact

# Skip Docker pruning entirely
.\WinDiskCleanup.ps1 -SkipDocker

# Skip all projects folder cleanup (node_modules, venvs, __pycache__)
.\WinDiskCleanup.ps1 -SkipProjects

# Combine flags
.\WinDiskCleanup.ps1 -Interactive -SkipWSLCompact
```

---

## Configuration

Edit `cleanup-config.ps1` to customize for your machine.

### Projects folder(s)

```powershell
$Config_ProjectsPath = @(
    "C:\Projects",
    "D:\Dev",
    "E:\Work"
)
```

### Inactive node_modules to delete

```powershell
$Config_InactiveNodeModules = @(
    "C:\Projects\old-project\node_modules",
    "C:\Projects\backup\website\node_modules"
)
```

### Inactive Python venvs to delete

```powershell
$Config_InactivePythonVenvs = @(
    "C:\Projects\old-bot\venv",
    "C:\Projects\old-scraper\.venv"
)
```

### Skip steps permanently

```powershell
# Browser caches
$Config_SkipChrome        = $true
$Config_SkipEdge          = $true
$Config_SkipFirefox       = $true
$Config_SkipBrave         = $true

# Package managers
$Config_SkipNpm           = $true
$Config_SkipPip           = $true

# System
$Config_SkipTemp          = $true
$Config_SkipWindowsUpdate = $true
$Config_SkipWindowsStore  = $true
$Config_SkipRecycleBin    = $true

# Apps
$Config_SkipClaude        = $true
$Config_SkipVSCode        = $true
$Config_SkipTeams         = $true

# Projects
$Config_SkipPycache       = $true
$Config_SkipNodeModules   = $true
$Config_SkipPythonVenvs   = $true

# Docker / WSL
$Config_SkipDocker        = $true
$Config_SkipWSLApt        = $true
$Config_SkipWSLCompact    = $true
$Config_SkipDockerCompact = $true
```

---

## Reports

After every run, two files are saved to your Desktop:

- `WinDiskCleanup-YYYY-MM-DD_HH-mm.txt` — plain text summary
- `WinDiskCleanup-YYYY-MM-DD_HH-mm.html` — dark-theme HTML report (opens automatically)

The HTML report includes before/after disk space, savings by category, Chrome per-profile breakdown, Docker container status, top 10 largest files, and a warnings/errors log.

---

## Contributing

Pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines, testing steps, and how to suggest new cleanup steps.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## License

MIT — see [LICENSE](LICENSE)

---

<div align="center">

Made by [Abdul Wasea](https://github.com/AbdulWaseaDev)

If this saved you disk space, consider giving it a ⭐

</div>
