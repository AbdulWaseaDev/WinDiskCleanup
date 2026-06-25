# ============================================================
# WinDiskCleanup — User Configuration File
# Edit this file to customize the cleanup behavior
# ============================================================
# This file is dot-sourced by WinDiskCleanup.ps1 — all variables are used there.
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# ── Projects Folders ─────────────────────────────────────────
# Add ALL folders where you keep your projects.
# Supports multiple folders across different drives.
# Leave empty (@()) to skip all projects-related cleanup.
#
# Examples:
#   Single folder  : $Config_ProjectsPath = @("C:\Projects")
#   Multiple drives: $Config_ProjectsPath = @("C:\Projects", "D:\Dev", "E:\Work")
$Config_ProjectsPath = @(
    # "C:\Projects",
    # "D:\Dev",
    # "E:\Work"
)

# ── Inactive Project Threshold ───────────────────────────────
# Projects not touched in this many days are considered inactive.
# node_modules and Python venvs inside inactive projects are listed
# automatically — you will be asked before anything is deleted.
$Config_InactiveDaysThreshold = 90

# ── Skip Steps ───────────────────────────────────────────────
# Set to $true to permanently skip a step without needing a CLI flag.
# All steps run by default ($false).

# Browser caches
$Config_SkipChrome        = $false   # Skip Chrome cache cleanup
$Config_SkipEdge          = $false   # Skip Edge cache cleanup
$Config_SkipFirefox       = $false   # Skip Firefox cache cleanup
$Config_SkipBrave         = $false   # Skip Brave cache cleanup

# Package managers
$Config_SkipNpm           = $false   # Skip npm cache cleanup
$Config_SkipPip           = $false   # Skip pip cache cleanup

# System cleanup
$Config_SkipTemp          = $false   # Skip Temp files cleanup
$Config_SkipWindowsUpdate = $false   # Skip Windows Update cache cleanup
$Config_SkipWindowsStore  = $false   # Skip Windows Store cache reset
$Config_SkipRecycleBin    = $false   # Skip emptying Recycle Bin

# Apps
$Config_SkipClaude        = $false   # Skip Claude Desktop cache cleanup
$Config_SkipVSCode        = $false   # Skip VS Code duplicate extension cleanup
$Config_SkipTeams         = $false   # Skip Microsoft Teams cache cleanup

# Projects folder
$Config_SkipPycache          = $false   # Skip __pycache__ cleanup in projects folders
$Config_SkipNodeModules      = $false   # Skip inactive node_modules cleanup
$Config_SkipPythonVenvs      = $false   # Skip inactive Python venvs cleanup
$Config_SkipBuildArtifacts   = $false   # Skip build artifact cleanup (bin/obj/dist/target/etc.)
$Config_SkipGitClean         = $false   # Skip git clean -fdX on all repos in project folders

# Package manager caches (auto-detected, no config needed)
$Config_SkipYarn             = $false   # Skip Yarn cache cleanup
$Config_SkipPnpm             = $false   # Skip pnpm store cleanup
$Config_SkipNuGet            = $false   # Skip NuGet packages cache cleanup
$Config_SkipMaven            = $false   # Skip Maven local repository cleanup
$Config_SkipGradle           = $false   # Skip Gradle caches cleanup
$Config_SkipCargo            = $false   # Skip Cargo registry cleanup
$Config_SkipGo               = $false   # Skip Go module cache cleanup
$Config_SkipFlutter          = $false   # Skip Flutter/Dart pub cache cleanup

# System
$Config_SkipCrashDumps       = $false   # Skip crash dumps + WER reports cleanup
$Config_SkipDISM             = $false   # Skip DISM WinSxS component store cleanup (slow)

# Docker / WSL
$Config_SkipDocker        = $false   # Skip Docker prune entirely
$Config_SkipWSLApt        = $false   # Skip WSL apt clean + autoremove
$Config_SkipWSLCompact    = $false   # Skip WSL vhdx compaction
$Config_SkipDockerCompact = $false   # Skip Docker vhdx compaction
