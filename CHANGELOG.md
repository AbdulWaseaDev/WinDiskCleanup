# Changelog

## v1.4.0
- `$Config_ProjectsPath` is now an array — supports multiple project folders across different drives (e.g. `C:\Projects`, `D:\Dev`, `E:\Work`)
- `__pycache__` cleanup now scans all configured project folders, not just one
- Before/after size tracking sums across all project folders

## v1.3.0
- Added per-step skip flags for every step in `cleanup-config.ps1` — users can permanently disable any individual step without CLI flags or Interactive mode
- Removed Videos folder scan — not needed, users can manage their Videos folder manually

## v1.2.0
- Chrome and Edge are now stopped before cache deletion if they are running — prevents silently skipped locked files
- Added WSL command timeouts (30s for reads, 60s for prune/apt) — script no longer hangs if WSL is in a bad state
- Added error logging — failed or locked deletions are tracked, shown in terminal and saved to both TXT and HTML reports with WARN status instead of false OK
- Added execution time to final summary, report cards, and TXT report
- Top 10 largest files scan now uses `-Depth 7` — prevents multi-minute scans on deep folder structures

## v1.1.0
- WSL vhdx detection now uses Windows registry (`HKCU:\...\Lxss`) — official Microsoft method, replaces slow recursive scan
- WSL compaction now handles multiple distros — all registered distros are compacted in one run
- Docker Desktop support — prune and health check now work with Docker Desktop (native `docker.exe`) in addition to Docker in WSL
- Docker vhdx detection checks both `wsl\data` and `wsl\main` paths
- Fixed `wsreset.exe` — removed invalid `-i` argument
- Fixed Recycle Bin size reporting — reads `$Recycle.Bin` folder directly instead of unreliable Shell COM object
- Fixed top 10 files scan — excludes reparse points and junctions to prevent infinite loops; excludes system files (pagefile.sys, hiberfil.sys, swapfile.sys)
- Fixed WSL running check — handles UTF-16 encoded output from `wsl --list --running` on PowerShell 5.1

## v1.0.0
- Initial release
