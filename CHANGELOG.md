# Changelog

## v1.6.0
- Added Yarn, pnpm, NuGet, Maven, Gradle, Cargo, Go, and Flutter/Dart cache cleanup — all auto-detected, zero config, skipped silently if not installed
- Added build artifact cleanup — auto-scans project folders for `bin/`, `obj/`, `dist/`, `target/`, `.next/` etc. using marker files (`*.csproj`, `Cargo.toml`, `pom.xml`, `package.json`); lists candidates and asks before deleting
- Added git repository clean — runs `git clean -fdX` (removes gitignored files only) across all repos under configured project folders; lists repos and asks before running
- Added crash dumps cleanup — removes `CrashDumps` folder and Windows Error Reporting archives
- Added DISM component store cleanup — runs `dism /online /cleanup-image /startcomponentcleanup` to reclaim WinSxS space
- Steps renumbered: 31 total steps (was 19)

## v1.5.1
- Fixed parse errors on PowerShell 5.1 — added UTF-8 BOM so PS 5.1 reads the file correctly instead of misinterpreting em-dash bytes as string terminators
- Fixed `if` expression used as a hashtable value (not valid in PS 5.1) — pre-computed `$emailVal` for Chrome profile email detection
- Fixed nested double quotes inside `$()` in a double-quoted string — pre-computed `$projectsFolderDesc` for projects folder status line
- Improved Pester tests — replaced dot-source approach with AST parsing to avoid Pester v5 scope isolation issues
- Improved README — centered header, navigation links, Quick Start section, single CI badge

## v1.5.0
- Added Firefox cache cleanup — auto-detects all profiles, closes Firefox if running
- Added Brave cache cleanup — auto-detects all profiles, closes Brave if running
- Added Microsoft Teams cache cleanup — supports both classic Teams and new MSIX Teams
- Fixed `$profile` automatic variable conflict in Chrome and Edge loops (renamed to `$chromeProfile` / `$edgeProfile`)
- Renamed `Compact-VhdxFile` to `Invoke-VhdxCompact` to use a PSScriptAnalyzer-approved verb
- Added GitHub Actions CI workflow (`PSScriptAnalyzer` on every push and PR)
- Steps renumbered: 19 total steps (was 16)

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
