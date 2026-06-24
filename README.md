# WinDiskCleanup

A PowerShell disk cleanup script for Windows developers. Frees up space by cleaning browser caches, package manager caches, temp files, WSL/Docker virtual disks, and inactive project dependencies — all in one run.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.4.0-brightgreen)

---

## What It Cleans

| Step | Target | Notes |
|------|--------|-------|
| 1 | Chrome cache (all profiles) | Auto-detects all profiles |
| 2 | Claude Desktop cache | Auto-detects MSIX install |
| 3 | Microsoft Edge cache | Auto-detects all profiles |
| 4 | npm cache | Skipped if npm not installed |
| 5 | pip cache | Skipped if pip not installed |
| 6 | Temp files | User temp + Windows temp |
| 7 | Windows Update cache | Safely stops/restarts wuauserv |
| 8 | Windows Store cache | wsreset |
| 9 | Recycle Bin | Configurable |
| 10 | VS Code duplicate extensions | Keeps newest version, removes older |
| 11 | Projects __pycache__ | Configurable path |
| 12 | Inactive node_modules | You define which ones |
| 13 | Inactive Python venvs | You define which ones |
| 14 | Docker prune | Docker Desktop or Docker in WSL — auto-detected |
| 15 | WSL apt cleanup | apt clean + autoremove |
| 16 | WSL + Docker vhdx compaction | Reclaims unused virtual disk space |

Everything is **auto-detected**. If a tool is not installed, that step is silently skipped.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later (built into Windows)
- Run as **Administrator**

WSL, Docker, npm, pip, Chrome, Edge, VS Code, and Claude are all optional. The script detects what you have and skips what you don't.

---

## Installation

```powershell
git clone https://github.com/AbdulWaseaDev/WinDiskCleanup.git
cd WinDiskCleanup
```

Or download the ZIP from GitHub and extract it anywhere.

---

## Usage

Open PowerShell as Administrator, then:

> **First time only:** If PowerShell blocks the script, run this once:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

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
```

You can combine flags:

```powershell
.\WinDiskCleanup.ps1 -Interactive -SkipWSLCompact
```

---

## Configuration

Edit `cleanup-config.ps1` to customize the script for your machine.

### Set your projects folder(s)

Supports multiple folders across different drives — add as many as you need:

```powershell
# Single folder
$Config_ProjectsPath = @("C:\Projects")

# Multiple folders across different drives
$Config_ProjectsPath = @(
    "C:\Projects",
    "D:\Dev",
    "E:\Work"
)
```

### Add inactive node_modules to delete

```powershell
$Config_InactiveNodeModules = @(
    "C:\Projects\old-project\node_modules",
    "C:\Projects\backup\website\node_modules"
)
```

### Add inactive Python venvs to delete

```powershell
$Config_InactivePythonVenvs = @(
    "C:\Projects\old-bot\venv",
    "C:\Projects\old-scraper\.venv"
)
```

### Skip specific steps permanently

Every step can be disabled individually in `cleanup-config.ps1`:

```powershell
# Browser caches
$Config_SkipChrome        = $true
$Config_SkipEdge          = $true

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

# Projects folder
$Config_SkipPycache       = $true
$Config_SkipNodeModules   = $true
$Config_SkipPythonVenvs   = $true

# Docker / WSL
$Config_SkipDocker        = $true
$Config_SkipWSLApt        = $true
$Config_SkipWSLCompact    = $true
$Config_SkipDockerCompact = $true
```

Set any to `$true` to permanently skip that step without needing a CLI flag.

---

## Reports

After every run, two report files are saved to your Desktop:

- `WinDiskCleanup-YYYY-MM-DD_HH-mm.txt` — plain text summary
- `WinDiskCleanup-YYYY-MM-DD_HH-mm.html` — interactive dark-theme HTML report (opens automatically)

The HTML report includes:
- Before/after disk space comparison
- Savings broken down by category
- Chrome cache per profile
- Docker container status
- Top 10 largest files on your drive
- Warnings and errors log

---

## WSL + Docker Disk Compaction

WSL and Docker store their filesystems in `.vhdx` virtual disk files. These files grow over time but never shrink automatically, even after you delete files inside WSL or Docker.

Step 16 runs `diskpart compact vdisk` to reclaim that unused space. This is safe — it does not delete any data.

The script:
1. Shuts down WSL (`wsl --shutdown`)
2. Finds all WSL distros via the Windows registry (`HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss`) — compacts every one
3. Compacts the Docker vhdx if found (`AppData\Local\Docker\wsl\data` or `wsl\main`)
4. Restarts WSL

Docker containers configured with `restart: always` will come back up automatically.

**Docker Desktop users:** The script detects Docker Desktop via `docker.exe` on your PATH and runs prune commands natively — no WSL needed.

**Docker in WSL users:** The script detects Docker inside WSL and runs prune via `wsl -e bash`.

To skip compaction: `.\WinDiskCleanup.ps1 -SkipWSLCompact`

---

## First Run Tip

Run with `-DryRun` first to see what the script will clean on your machine before committing:

```powershell
.\WinDiskCleanup.ps1 -DryRun
```

---

## Changelog

### v1.4.0
- `$Config_ProjectsPath` is now an array — supports multiple project folders across different drives (e.g. `C:\Projects`, `D:\Dev`, `E:\Work`)
- `__pycache__` cleanup now scans all configured project folders, not just one
- Before/after size tracking sums across all project folders

### v1.3.0
- Added per-step skip flags for every step in `cleanup-config.ps1` — users can permanently disable any individual step without CLI flags or Interactive mode
- Removed Videos folder scan — not needed, users can manage their Videos folder manually

### v1.2.0
- Chrome and Edge are now stopped before cache deletion if they are running — prevents silently skipped locked files
- Added WSL command timeouts (30s for reads, 60s for prune/apt) — script no longer hangs if WSL is in a bad state
- Added error logging — failed or locked deletions are tracked, shown in terminal and saved to both TXT and HTML reports with WARN status instead of false OK
- Added execution time to final summary, report cards, and TXT report
- Top 10 largest files scan now uses `-Depth 7` — prevents multi-minute scans on deep folder structures

### v1.1.0
- WSL vhdx detection now uses Windows registry (`HKCU:\...\Lxss`) — official Microsoft method, replaces slow recursive scan
- WSL compaction now handles multiple distros — all registered distros are compacted in one run
- Docker Desktop support — prune and health check now work with Docker Desktop (native `docker.exe`) in addition to Docker in WSL
- Docker vhdx detection checks both `wsl\data` and `wsl\main` paths
- Fixed `wsreset.exe` — removed invalid `-i` argument
- Fixed Recycle Bin size reporting — reads `$Recycle.Bin` folder directly instead of unreliable Shell COM object
- Fixed top 10 files scan — excludes reparse points and junctions to prevent infinite loops; excludes system files (pagefile.sys, hiberfil.sys, swapfile.sys)
- Fixed WSL running check — handles UTF-16 encoded output from `wsl --list --running` on PowerShell 5.1

### v1.0.0
- Initial release

---

## Contributing

Pull requests are welcome. If you find a bug or want a new cleanup step, open an issue.

---

## License

MIT — see [LICENSE](LICENSE)

---

Made by [Abdul Wasea](https://github.com/AbdulWaseaDev)
