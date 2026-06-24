# ============================================================
# WinDiskCleanup — Windows Disk Cleanup Script
# Version: 1.4.0
# Author: Abdul Wasea (github.com/AbdulWaseaDev)
# License: MIT
# ============================================================
# REQUIREMENTS: Run as Administrator in PowerShell
#
# USAGE:
#   .\WinDiskCleanup.ps1                   # Full cleanup
#   .\WinDiskCleanup.ps1 -DryRun           # Preview only, nothing deleted
#   .\WinDiskCleanup.ps1 -Interactive      # Confirm before each step
#   .\WinDiskCleanup.ps1 -SkipWSLCompact   # Skip WSL/Docker vhdx compaction
#   .\WinDiskCleanup.ps1 -SkipDocker       # Skip Docker pruning
#   .\WinDiskCleanup.ps1 -SkipProjects     # Skip projects folder cleanup
#
# CONFIGURATION:
#   Edit cleanup-config.ps1 to set your projects folder path,
#   inactive node_modules, and inactive Python venvs.
# ============================================================

param(
    [switch]$DryRun,
    [switch]$Interactive,
    [switch]$SkipWSLCompact,
    [switch]$SkipDocker,
    [switch]$SkipProjects
)

# ── Admin Check ──────────────────────────────────────────────

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[ERROR] Please run this script as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell -> 'Run as Administrator', then re-run the script.`n" -ForegroundColor Red
    exit 1
}

# ── Load Config ──────────────────────────────────────────────

$configPath = Join-Path $PSScriptRoot "cleanup-config.ps1"

# Defaults (overridden by cleanup-config.ps1 if present)
$Config_ProjectsPath         = @()
$Config_InactiveNodeModules  = @()
$Config_InactivePythonVenvs  = @()
$Config_SkipChrome           = $false
$Config_SkipEdge             = $false
$Config_SkipNpm              = $false
$Config_SkipPip              = $false
$Config_SkipTemp             = $false
$Config_SkipWindowsUpdate    = $false
$Config_SkipWindowsStore     = $false
$Config_SkipRecycleBin       = $false
$Config_SkipClaude           = $false
$Config_SkipVSCode           = $false
$Config_SkipPycache          = $false
$Config_SkipNodeModules      = $false
$Config_SkipPythonVenvs      = $false
$Config_SkipDocker           = $false
$Config_SkipWSLApt           = $false
$Config_SkipWSLCompact       = $false
$Config_SkipDockerCompact    = $false

if (Test-Path $configPath) {
    . $configPath
    Write-Host "  Config loaded from: $configPath" -ForegroundColor DarkGray
} else {
    Write-Host "  No config file found — using defaults. Create cleanup-config.ps1 to customize." -ForegroundColor Yellow
}

# Merge CLI flags with config
if ($SkipWSLCompact)  { $Config_SkipWSLCompact    = $true }
if ($SkipDocker)      { $Config_SkipDocker         = $true }
if ($SkipProjects)    { $Config_ProjectsPath        = @() }

# ── Mode Banner ──────────────────────────────────────────────

Write-Host ""
if ($DryRun)      { Write-Host "  *** DRY RUN MODE — Nothing will be deleted ***" -ForegroundColor Magenta }
if ($Interactive) { Write-Host "  *** INTERACTIVE MODE — You will confirm each step ***" -ForegroundColor Cyan }

# ── Stopwatch + Error Log ────────────────────────────────────

$scriptTimer = [System.Diagnostics.Stopwatch]::StartNew()
$errorLog    = [System.Collections.Generic.List[string]]::new()

function Write-ErrorLog($step, $msg) {
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $step — $msg"
    $script:errorLog.Add($entry)
    Write-Host "   WARN: $msg" -ForegroundColor DarkYellow
}

# ── Helpers ─────────────────────────────────────────────────

function Get-FreeGB  { return [math]::Round((Get-PSDrive C).Free / 1GB, 2) }
function Get-UsedGB  { return [math]::Round((Get-PSDrive C).Used / 1GB, 2) }

function Write-Header($text) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Step($text)    { Write-Host "`n>> $text" -ForegroundColor Yellow }
function Write-Done($text)    { Write-Host "   OK: $text" -ForegroundColor Green }
function Write-Skipped($text) { Write-Host "   SKIPPED: $text" -ForegroundColor DarkGray }
function Write-DryRun($text)  { Write-Host "   [DRY RUN] Would delete: $text" -ForegroundColor Magenta }
function Write-Info($text)    { Write-Host "   INFO: $text" -ForegroundColor White }

function Get-FolderSizeGB($path) {
    if (-not $path -or -not (Test-Path $path)) { return 0 }
    $size = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
    return [math]::Round($size / 1GB, 2)
}

function Confirm-Step($stepName) {
    if (-not $Interactive) { return $true }
    $answer = Read-Host "`n  Run step: $stepName ? (Y/n)"
    return ($answer -eq '' -or $answer -match '^[Yy]')
}

function Compact-VhdxFile($vhdxFullPath, $label) {
    if (-not $vhdxFullPath -or -not (Test-Path $vhdxFullPath)) {
        Write-Skipped "$label vhdx not found"; return $false
    }
    Write-Step "Compacting $label disk: $vhdxFullPath"
    $tmp = "$env:TEMP\compact_$([System.IO.Path]::GetRandomFileName()).txt"
    @"
select vdisk file="$vhdxFullPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@ | Out-File -FilePath $tmp -Encoding ASCII
    diskpart /s $tmp 2>&1 | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Done "$label disk compacted"
    return $true
}

# Run a WSL bash command with a timeout (seconds). Returns output or $null on timeout.
function Invoke-WSLCommand($bashCmd, $timeoutSec = 30) {
    $job = Start-Job -ScriptBlock {
        param($cmd)
        $prevEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        $out = wsl -e bash -c $cmd 2>&1
        [Console]::OutputEncoding = $prevEnc
        $out
    } -ArgumentList $bashCmd
    $completed = Wait-Job $job -Timeout $timeoutSec
    if ($completed) {
        $result = Receive-Job $job
        Remove-Job $job -Force
        return $result
    } else {
        Stop-Job  $job
        Remove-Job $job -Force
        return $null
    }
}

# ── HTML/TXT Report Builder ──────────────────────────────────

$htmlRows    = @()
$reportLines = @()

function Add-Report($action, $status, $saved) {
    $script:reportLines += "$status | $action | $saved"
    $color = switch ($status) {
        "OK"      { "#4CAF50" }
        "SKIPPED" { "#888"    }
        "ERROR"   { "#f44336" }
        "WARN"    { "#FF9800" }
        default   { "#FF9800" }
    }
    $script:htmlRows += "<tr><td>$action</td><td style='color:$color'>$status</td><td>$saved</td></tr>"
}

# ── Auto-Detect Available Tools ──────────────────────────────

$hasNpm    = $null -ne (Get-Command npm    -ErrorAction SilentlyContinue)
$hasPip    = $null -ne (Get-Command pip    -ErrorAction SilentlyContinue)
$hasWSL    = $null -ne (Get-Command wsl    -ErrorAction SilentlyContinue)
$hasVSCode = Test-Path "$env:USERPROFILE\.vscode\extensions"

# Auto-detect WSL vhdx paths via registry (official Microsoft method)
# Source: https://learn.microsoft.com/en-us/windows/wsl/disk-space
$wslVhdxList = @()
$wslVhdx     = $null
if ($hasWSL) {
    $lxssKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (Test-Path $lxssKey) {
        Get-ChildItem $lxssKey -ErrorAction SilentlyContinue | ForEach-Object {
            $distro   = $_.GetValue("DistributionName")
            $basePath = $_.GetValue("BasePath")
            if ($distro -and $basePath -and $distro -notmatch "docker") {
                # BasePath may have \\?\ prefix — normalize it
                $basePath   = $basePath -replace '^\\\\\?\\', ''
                $vhdxPath   = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhdxPath) {
                    $wslVhdxList += [PSCustomObject]@{ Distro=$distro; Path=$vhdxPath }
                }
            }
        }
    }
    # Use first non-docker distro for before/after size tracking
    $wslVhdx = $wslVhdxList | Select-Object -First 1
}

# Auto-detect Docker vhdx (Desktop stores it under wsl\data or wsl\main)
$dockerVhdx = $null
$dockerVhdxSearchPaths = @(
    "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx",
    "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
)
foreach ($p in $dockerVhdxSearchPaths) {
    if (Test-Path $p) { $dockerVhdx = Get-Item $p; break }
}

# Auto-detect Docker install type
# Native = Docker Desktop installed, docker.exe available directly in PowerShell
# WSL    = Docker running inside WSL (no docker.exe on Windows PATH)
$hasDockerNative = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
$hasDockerWSL    = $false
if ($hasWSL -and -not $hasDockerNative) {
    # Use [Console]::OutputEncoding fix for UTF-16 WSL output on PS 5.1
    $prevEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    $wslDockerCheck = wsl -e bash -c "command -v docker 2>/dev/null" 2>&1
    [Console]::OutputEncoding = $prevEncoding
    $hasDockerWSL = ($wslDockerCheck -join "") -match "/docker"
} elseif ($hasWSL -and $hasDockerNative) {
    $hasDockerWSL = $false
}
$hasAnyDocker = $hasDockerNative -or $hasDockerWSL

# Auto-detect Claude MSIX package
$claudePkg = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match "^Claude_" } | Select-Object -First 1

# ── Capture Before State ─────────────────────────────────────

Write-Header "CAPTURING BEFORE STATE"

$beforeFree       = Get-FreeGB
$beforeUsed       = Get-UsedGB
$beforeNpm        = Get-FolderSizeGB "$env:LOCALAPPDATA\npm-cache"
$beforeTemp       = Get-FolderSizeGB "$env:TEMP"
$beforeWinTemp    = Get-FolderSizeGB "C:\Windows\Temp"
$chromeBase       = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$edgeBase         = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$beforeChrome     = Get-FolderSizeGB $chromeBase
$beforeEdge       = Get-FolderSizeGB $edgeBase
$beforeWinUpdate  = Get-FolderSizeGB "C:\Windows\SoftwareDistribution\Download"
$beforeProjects = ($Config_ProjectsPath | Where-Object { Test-Path $_ } |
                   ForEach-Object { Get-FolderSizeGB $_ } |
                   Measure-Object -Sum).Sum
$beforeProjects = [math]::Round($beforeProjects, 2)
$beforeClause     = if ($claudePkg) { Get-FolderSizeGB (Join-Path $claudePkg.FullName "LocalCache") } else { 0 }
$beforeWSLVhdx    = if ($wslVhdx)    { [math]::Round((Get-Item $wslVhdx.Path -EA SilentlyContinue).Length / 1GB, 2) }    else { 0 }
$beforeDockerVhdx = if ($dockerVhdx) { [math]::Round($dockerVhdx.Length / 1GB, 2) } else { 0 }

# Per-profile Chrome sizes
$chromeProfilesBefore = @{}
if (Test-Path $chromeBase) {
    Get-ChildItem $chromeBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^Profile|^Default" } | ForEach-Object {
            $pref = Join-Path $_.FullName "Preferences"
            $email = ""
            if (Test-Path $pref) {
                try { $email = (Get-Content $pref -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue).account_info[0].email } catch {}
            }
            $chromeProfilesBefore[$_.Name] = @{ Size = Get-FolderSizeGB $_.FullName; Email = if ($email) { $email } else { "unknown" } }
        }
}

Write-Host "  C: Free           : $beforeFree GB"
Write-Host "  C: Used           : $beforeUsed GB"
Write-Host "  Chrome            : $beforeChrome GB $(if ($beforeChrome -eq 0) { '(not installed)' })"
Write-Host "  Edge              : $beforeEdge GB $(if ($beforeEdge -eq 0) { '(not installed)' })"
Write-Host "  npm cache         : $beforeNpm GB $(if (-not $hasNpm) { '(npm not found)' })"
Write-Host "  Temp files        : $([math]::Round($beforeTemp + $beforeWinTemp, 2)) GB"
Write-Host "  Windows Update    : $beforeWinUpdate GB"
Write-Host "  Claude cache      : $beforeClause GB $(if (-not $claudePkg) { '(not installed)' })"
Write-Host "  Projects folder   : $beforeProjects GB $(if ($Config_ProjectsPath.Count -eq 0) { '(not configured)' } else { "($($Config_ProjectsPath.Count) folder(s))" })"
Write-Host "  WSL vhdx          : $beforeWSLVhdx GB $(if (-not $wslVhdx) { '(WSL not found)' })"
Write-Host "  Docker vhdx       : $beforeDockerVhdx GB $(if (-not $dockerVhdx) { '(Docker not found)' })"
$dockerType = if ($hasDockerNative) { 'Docker Desktop' } elseif ($hasDockerWSL) { 'Docker in WSL' } else { 'not installed' }
Write-Host "  Docker type       : $dockerType" -ForegroundColor $(if ($hasAnyDocker) { 'Green' } else { 'DarkGray' })

# ── Step 1: Chrome Cache ─────────────────────────────────────

Write-Header "STEP 1 — Chrome Cache Cleanup"

if (-not (Test-Path $chromeBase)) {
    Write-Skipped "Chrome not installed"; Add-Report "Chrome Cache" "SKIPPED" "not installed"
} elseif ($Config_SkipChrome) {
    Write-Skipped "Chrome cache (disabled in config)"; Add-Report "Chrome Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Chrome Cache Cleanup") {
    # Stop Chrome so cache files are not locked
    $chromeWasRunning = $false
    if (Get-Process -Name "chrome" -ErrorAction SilentlyContinue) {
        $chromeWasRunning = $true
        Write-Info "Chrome is running — closing it to unlock cache files"
        if (-not $DryRun) {
            Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    $cacheFolders = @("Cache", "Code Cache", "GPUCache", "DawnCache", "ShaderCache")
    $profileDirs  = Get-ChildItem $chromeBase -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "^Profile|^Default" }
    $count = 0; $locked = 0
    foreach ($profile in $profileDirs) {
        foreach ($folder in $cacheFolders) {
            $path = Join-Path $profile.FullName $folder
            if (Test-Path $path) {
                if ($DryRun) { Write-DryRun "$($profile.Name)\$folder ($(Get-FolderSizeGB $path) GB)" }
                else {
                    try {
                        Remove-Item "$path\*" -Recurse -Force -ErrorAction Stop
                    } catch {
                        $locked++
                        Write-ErrorLog "Chrome Cache" "Could not delete $path — $($_.Exception.Message)"
                    }
                }
                $count++
            }
        }
    }
    $status = if ($locked -gt 0) { "WARN" } else { "OK" }
    $note   = "$count folders processed$(if ($locked -gt 0) { ", $locked locked/failed" } else { '' })$(if ($chromeWasRunning) { ' (Chrome was closed)' })"
    Write-Done "$note"
    Add-Report "Chrome Cache" $status $note
} else { Write-Skipped "Chrome cache"; Add-Report "Chrome Cache" "SKIPPED" "-" }

# ── Step 2: Claude Desktop Cache ────────────────────────────

Write-Header "STEP 2 — Claude Desktop Cache Cleanup"

if (-not $claudePkg) {
    Write-Skipped "Claude desktop not installed"; Add-Report "Claude Cache" "SKIPPED" "not installed"
} elseif ($Config_SkipClaude) {
    Write-Skipped "Claude cache (disabled in config)"; Add-Report "Claude Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Claude Desktop Cache Cleanup") {
    $claudeCache = Join-Path $claudePkg.FullName "LocalCache"
    if ($DryRun) { Write-DryRun "Claude LocalCache ($beforeClause GB)" }
    else {
        Stop-Process -Name "Claude" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Remove-Item "$claudeCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Done "Claude cache cleared ($beforeClause GB freed)"
    Add-Report "Claude Cache" "OK" "$beforeClause GB"
} else { Write-Skipped "Claude cache"; Add-Report "Claude Cache" "SKIPPED" "-" }

# ── Step 3: Edge Cache ───────────────────────────────────────

Write-Header "STEP 3 — Microsoft Edge Cache Cleanup"

if (-not (Test-Path $edgeBase)) {
    Write-Skipped "Edge not installed"; Add-Report "Edge Cache" "SKIPPED" "not installed"
} elseif ($Config_SkipEdge) {
    Write-Skipped "Edge cache (disabled in config)"; Add-Report "Edge Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Edge Cache Cleanup") {
    $edgeWasRunning = $false
    if (Get-Process -Name "msedge" -ErrorAction SilentlyContinue) {
        $edgeWasRunning = $true
        Write-Info "Edge is running — closing it to unlock cache files"
        if (-not $DryRun) {
            Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    $cacheFolders    = @("Cache", "Code Cache", "GPUCache", "DawnCache", "ShaderCache")
    $edgeProfileDirs = Get-ChildItem $edgeBase -Directory -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match "^Profile|^Default" }
    $count = 0; $locked = 0
    foreach ($profile in $edgeProfileDirs) {
        foreach ($folder in $cacheFolders) {
            $path = Join-Path $profile.FullName $folder
            if (Test-Path $path) {
                if ($DryRun) { Write-DryRun "Edge $($profile.Name)\$folder" }
                else {
                    try {
                        Remove-Item "$path\*" -Recurse -Force -ErrorAction Stop
                    } catch {
                        $locked++
                        Write-ErrorLog "Edge Cache" "Could not delete $path — $($_.Exception.Message)"
                    }
                }
                $count++
            }
        }
    }
    $status = if ($locked -gt 0) { "WARN" } else { "OK" }
    $note   = "$count folders processed$(if ($locked -gt 0) { ", $locked locked/failed" } else { '' })$(if ($edgeWasRunning) { ' (Edge was closed)' })"
    Write-Done "$note"
    Add-Report "Edge Cache" $status $note
} else { Write-Skipped "Edge cache"; Add-Report "Edge Cache" "SKIPPED" "-" }

# ── Step 4: npm Cache ────────────────────────────────────────

Write-Header "STEP 4 — npm Cache Cleanup"

if (-not $hasNpm) {
    Write-Skipped "npm not installed"; Add-Report "npm Cache" "SKIPPED" "not installed"
} elseif ($Config_SkipNpm) {
    Write-Skipped "npm cache (disabled in config)"; Add-Report "npm Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "npm Cache Cleanup") {
    if ($DryRun) { Write-DryRun "npm cache ($beforeNpm GB)" }
    else { npm cache clean --force 2>&1 | Out-Null }
    Write-Done "npm cache cleaned ($beforeNpm GB)"; Add-Report "npm Cache" "OK" "$beforeNpm GB"
} else { Write-Skipped "npm cache"; Add-Report "npm Cache" "SKIPPED" "-" }

# ── Step 5: pip Cache ────────────────────────────────────────

Write-Header "STEP 5 — pip Cache Cleanup"

if (-not $hasPip) {
    Write-Skipped "pip not installed"; Add-Report "pip Cache" "SKIPPED" "not installed"
} elseif ($Config_SkipPip) {
    Write-Skipped "pip cache (disabled in config)"; Add-Report "pip Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "pip Cache Cleanup") {
    if (-not $DryRun) { pip cache purge 2>&1 | Out-Null }
    Write-Done "pip cache purged"; Add-Report "pip Cache" "OK" "purged"
} else { Write-Skipped "pip cache"; Add-Report "pip Cache" "SKIPPED" "-" }

# ── Step 6: Temp Files ───────────────────────────────────────

Write-Header "STEP 6 — Temp Files Cleanup"

if ($Config_SkipTemp) {
    Write-Skipped "Temp files (disabled in config)"; Add-Report "Temp Files" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Temp Files Cleanup") {
    $total = [math]::Round($beforeTemp + $beforeWinTemp, 2)
    if ($DryRun) { Write-DryRun "User + Windows Temp ($total GB)" }
    else {
        Remove-Item "$env:TEMP\*"       -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Done "Temp files cleared ($total GB)"; Add-Report "Temp Files" "OK" "$total GB"
} else { Write-Skipped "Temp files"; Add-Report "Temp Files" "SKIPPED" "-" }

# ── Step 7: Windows Update Cache ────────────────────────────

Write-Header "STEP 7 — Windows Update Cache Cleanup"

if ($Config_SkipWindowsUpdate) {
    Write-Skipped "Windows Update cache (disabled in config)"; Add-Report "Windows Update Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Windows Update Cache Cleanup") {
    if ($DryRun) { Write-DryRun "SoftwareDistribution\Download ($beforeWinUpdate GB)" }
    else {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }
    Write-Done "Windows Update cache cleared ($beforeWinUpdate GB)"
    Add-Report "Windows Update Cache" "OK" "$beforeWinUpdate GB"
} else { Write-Skipped "Windows Update cache"; Add-Report "Windows Update Cache" "SKIPPED" "-" }

# ── Step 8: Windows Store Cache ─────────────────────────────

Write-Header "STEP 8 — Windows Store Cache Cleanup"

if ($Config_SkipWindowsStore) {
    Write-Skipped "Windows Store cache (disabled in config)"; Add-Report "Windows Store Cache" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Windows Store Cache Cleanup") {
    if (-not $DryRun) { Start-Process wsreset.exe -NoNewWindow -Wait -ErrorAction SilentlyContinue }
    Write-Done "Windows Store cache reset"; Add-Report "Windows Store Cache" "OK" "reset"
} else { Write-Skipped "Windows Store cache"; Add-Report "Windows Store Cache" "SKIPPED" "-" }

# ── Step 9: Recycle Bin ──────────────────────────────────────

Write-Header "STEP 9 — Empty Recycle Bin"

if ($Config_SkipRecycleBin) {
    Write-Skipped "Recycle Bin (disabled in config)"; Add-Report "Recycle Bin" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Empty Recycle Bin") {
    # Get size by reading $Recycle.Bin directly — Shell COM .Size is unreliable across Windows versions
    try {
        $recycleSize = [math]::Round((
            Get-ChildItem "C:\`$Recycle.Bin" -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum -ErrorAction SilentlyContinue
        ).Sum / 1GB, 2)
    } catch { $recycleSize = 0 }
    if ($DryRun) { Write-DryRun "Recycle Bin ($recycleSize GB)" }
    else { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
    Write-Done "Recycle Bin emptied ($recycleSize GB)"; Add-Report "Recycle Bin" "OK" "$recycleSize GB"
} else { Write-Skipped "Recycle Bin"; Add-Report "Recycle Bin" "SKIPPED" "-" }

# ── Step 10: VS Code Duplicate Extensions ───────────────────

Write-Header "STEP 10 — VS Code Duplicate Extension Cleanup"

if (-not $hasVSCode) {
    Write-Skipped "VS Code not installed"; Add-Report "VS Code Duplicates" "SKIPPED" "not installed"
} elseif ($Config_SkipVSCode) {
    Write-Skipped "VS Code cleanup (disabled in config)"; Add-Report "VS Code Duplicates" "SKIPPED" "disabled"
} elseif (Confirm-Step "VS Code Duplicate Extensions Cleanup") {
    $extDir  = "$env:USERPROFILE\.vscode\extensions"
    $allExts = Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue
    $grouped = $allExts | ForEach-Object {
        if ($_.Name -match "^(.+?)-(\d+\.\d+[\.\d]*)(-[a-z0-9\-]+)?$") {
            [PSCustomObject]@{ Full=$_.Name; Base=$Matches[1]; Version=$Matches[2]; Path=$_.FullName }
        }
    } | Where-Object { $_ } | Group-Object Base

    $removed = 0
    foreach ($group in $grouped) {
        if ($group.Count -gt 1) {
            $sorted   = $group.Group | Sort-Object { [version]($_.Version -replace '[^\d\.]','') } -Descending
            $toDelete = $sorted | Select-Object -Skip 1
            foreach ($ext in $toDelete) {
                $size = Get-FolderSizeGB $ext.Path
                if ($DryRun) { Write-DryRun "Old extension: $($ext.Full) ($size GB)" }
                else { Remove-Item $ext.Path -Recurse -Force -ErrorAction SilentlyContinue }
                $removed++
            }
        }
    }
    if ($removed -gt 0) { Write-Done "$removed duplicate extensions removed" }
    else { Write-Done "No duplicate extensions found" }
    Add-Report "VS Code Duplicates" "OK" "$removed removed"
} else { Write-Skipped "VS Code extensions"; Add-Report "VS Code Duplicates" "SKIPPED" "-" }

# ── Step 11: Projects __pycache__ ──────────────────────────

Write-Header "STEP 11 — Projects __pycache__ Cleanup"

if ($Config_ProjectsPath.Count -eq 0 -or $SkipProjects) {
    Write-Skipped "Projects path not configured (set Config_ProjectsPath in cleanup-config.ps1)"
    Add-Report "Projects __pycache__" "SKIPPED" "not configured"
} elseif ($Config_SkipPycache) {
    Write-Skipped "Projects __pycache__ (disabled in config)"; Add-Report "Projects __pycache__" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Projects __pycache__ Cleanup") {
    $totalCount = 0
    foreach ($projPath in $Config_ProjectsPath) {
        if (-not (Test-Path $projPath)) {
            Write-ErrorLog "Projects __pycache__" "Path not found: $projPath"; continue
        }
        $pycacheDirs = Get-ChildItem $projPath -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue
        $count = $pycacheDirs.Count
        if ($DryRun) { Write-DryRun "__pycache__ folders ($count found in $projPath)" }
        else { $pycacheDirs | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
        $totalCount += $count
    }
    Write-Done "$totalCount __pycache__ folders removed across $($Config_ProjectsPath.Count) project folder(s)"
    Add-Report "Projects __pycache__" "OK" "$totalCount folders"
} else { Write-Skipped "Projects __pycache__"; Add-Report "Projects __pycache__" "SKIPPED" "-" }

# ── Step 12: Inactive node_modules ──────────────────────────

Write-Header "STEP 12 — Inactive node_modules Cleanup"

if ($Config_InactiveNodeModules.Count -eq 0 -or $SkipProjects) {
    Write-Skipped "No inactive node_modules configured (edit cleanup-config.ps1 to add paths)"
    Add-Report "Inactive node_modules" "SKIPPED" "not configured"
} elseif ($Config_SkipNodeModules) {
    Write-Skipped "node_modules cleanup (disabled in config)"; Add-Report "Inactive node_modules" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Inactive node_modules Cleanup") {
    $removed = 0; $totalSize = 0
    foreach ($path in $Config_InactiveNodeModules) {
        if (Test-Path $path) {
            $size = Get-FolderSizeGB $path
            $totalSize += $size
            if ($DryRun) { Write-DryRun "$path ($size GB)" }
            else {
                Write-Step "Removing: $path"
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
            $removed++
        }
    }
    Write-Done "$removed node_modules removed (~$([math]::Round($totalSize,2)) GB)"
    Add-Report "Inactive node_modules" "OK" "~$([math]::Round($totalSize,2)) GB"
} else { Write-Skipped "node_modules cleanup"; Add-Report "Inactive node_modules" "SKIPPED" "-" }

# ── Step 13: Inactive Python Venvs ──────────────────────────

Write-Header "STEP 13 — Inactive Python Venvs Cleanup"

if ($Config_InactivePythonVenvs.Count -eq 0 -or $SkipProjects) {
    Write-Skipped "No inactive Python venvs configured (edit cleanup-config.ps1 to add paths)"
    Add-Report "Inactive Python Venvs" "SKIPPED" "not configured"
} elseif ($Config_SkipPythonVenvs) {
    Write-Skipped "Python venvs cleanup (disabled in config)"; Add-Report "Inactive Python Venvs" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "Inactive Python Venvs Cleanup") {
    $removed = 0; $totalSize = 0
    foreach ($path in $Config_InactivePythonVenvs) {
        if (Test-Path $path) {
            $size = Get-FolderSizeGB $path
            $totalSize += $size
            if ($DryRun) { Write-DryRun "$path ($size GB)" }
            else {
                Write-Step "Removing: $path"
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
            $removed++
        }
    }
    Write-Done "$removed Python venvs removed (~$([math]::Round($totalSize,2)) GB)"
    Add-Report "Inactive Python Venvs" "OK" "~$([math]::Round($totalSize,2)) GB"
} else { Write-Skipped "Python venvs cleanup"; Add-Report "Inactive Python Venvs" "SKIPPED" "-" }

# ── Step 14: Docker Prune (via WSL) ─────────────────────────

Write-Header "STEP 14 — Docker Cleanup"

if ($Config_SkipDocker) {
    Write-Skipped "Docker cleanup (disabled in config)"; Add-Report "Docker Prune" "SKIPPED" "disabled"
} elseif (-not $hasAnyDocker) {
    Write-Skipped "Docker not installed (neither Docker Desktop nor Docker in WSL)"
    Add-Report "Docker Prune" "SKIPPED" "not installed"
} elseif (Confirm-Step "Docker Cleanup") {
    if ($hasDockerNative) {
        # Docker Desktop — docker.exe available directly in PowerShell
        Write-Info "Docker Desktop detected — running natively"
        if ($DryRun) {
            docker system df 2>&1 | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray }
        } else {
            Write-Step "Pruning stopped containers"
            docker container prune -f 2>&1 | Out-Null
            Write-Step "Pruning unused volumes"
            docker volume prune -f 2>&1 | Out-Null
            Write-Step "Pruning dangling images"
            docker image prune -f 2>&1 | Out-Null
        }
        Write-Done "Docker cleanup complete (Docker Desktop)"; Add-Report "Docker Prune" "OK" "Docker Desktop"
    } elseif ($hasDockerWSL) {
        # Docker running natively inside WSL (no Docker Desktop)
        Write-Info "Docker in WSL detected — running via WSL"
        # Fix: wsl --list --running outputs UTF-16 on PS 5.1 — join and check for non-whitespace
        $prevEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        $wslRunning = (wsl --list --running 2>&1) -join " "
        [Console]::OutputEncoding = $prevEnc
        if ($wslRunning -match "\S") {
            if ($DryRun) {
                $dfOut = Invoke-WSLCommand "docker system df" 30
                if ($null -eq $dfOut) { Write-ErrorLog "Docker Prune" "WSL command timed out after 30s" }
                else { $dfOut | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray } }
            } else {
                Write-Step "Pruning stopped containers"
                $r1 = Invoke-WSLCommand "docker container prune -f" 60
                if ($null -eq $r1) { Write-ErrorLog "Docker Prune" "container prune timed out after 60s" }
                Write-Step "Pruning unused volumes"
                $r2 = Invoke-WSLCommand "docker volume prune -f" 60
                if ($null -eq $r2) { Write-ErrorLog "Docker Prune" "volume prune timed out after 60s" }
                Write-Step "Pruning dangling images"
                $r3 = Invoke-WSLCommand "docker image prune -f" 60
                if ($null -eq $r3) { Write-ErrorLog "Docker Prune" "image prune timed out after 60s" }
            }
            $hasErrors = ($null -eq $r1 -or $null -eq $r2 -or $null -eq $r3)
            $status    = if ($hasErrors) { "WARN" } else { "OK" }
            Write-Done "Docker cleanup complete (WSL)"; Add-Report "Docker Prune" $status "via WSL"
        } else {
            Write-Skipped "WSL not running — start WSL first"; Add-Report "Docker Prune" "SKIPPED" "WSL not running"
        }
    }
} else { Write-Skipped "Docker cleanup"; Add-Report "Docker Prune" "SKIPPED" "-" }

# ── Step 16: WSL apt Cleanup ─────────────────────────────────

Write-Header "STEP 15 — WSL Ubuntu apt Cleanup"

if (-not $hasWSL) {
    Write-Skipped "WSL not installed"; Add-Report "WSL apt Cleanup" "SKIPPED" "WSL not installed"
} elseif ($Config_SkipWSLApt) {
    Write-Skipped "WSL apt cleanup (disabled in config)"; Add-Report "WSL apt Cleanup" "SKIPPED" "disabled in config"
} elseif (Confirm-Step "WSL apt clean + autoremove") {
    $prevEnc = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    $wslRunning = (wsl --list --running 2>&1) -join " "
    [Console]::OutputEncoding = $prevEnc
    if ($wslRunning -match "\S") {
        if (-not $DryRun) {
            $r1 = Invoke-WSLCommand "sudo apt clean -y" 60
            if ($null -eq $r1) { Write-ErrorLog "WSL apt" "apt clean timed out after 60s" }
            $r2 = Invoke-WSLCommand "sudo apt autoremove -y" 60
            if ($null -eq $r2) { Write-ErrorLog "WSL apt" "apt autoremove timed out after 60s" }
        }
        $status = if ($null -eq $r1 -or $null -eq $r2) { "WARN" } else { "OK" }
        Write-Done "WSL apt cleaned"; Add-Report "WSL apt Cleanup" $status "apt clean + autoremove"
    } else { Write-Skipped "WSL not running"; Add-Report "WSL apt Cleanup" "SKIPPED" "WSL not running" }
} else { Write-Skipped "WSL apt cleanup"; Add-Report "WSL apt Cleanup" "SKIPPED" "-" }

# ── Step 17: WSL + Docker Disk Compaction ───────────────────

Write-Header "STEP 16 — WSL + Docker Disk Compaction"

if ($Config_SkipWSLCompact) {
    Write-Skipped "Compaction disabled in config/flag"
    Add-Report "WSL vhdx Compact"    "SKIPPED" "disabled"
    Add-Report "Docker vhdx Compact" "SKIPPED" "disabled"
} elseif (-not $hasWSL -and -not $dockerVhdx) {
    Write-Skipped "No WSL or Docker found — skipping compaction"
    Add-Report "WSL vhdx Compact"    "SKIPPED" "not found"
    Add-Report "Docker vhdx Compact" "SKIPPED" "not found"
} elseif ($DryRun) {
    Write-DryRun "WSL vhdx compact ($beforeWSLVhdx GB)"
    Write-DryRun "Docker vhdx compact ($beforeDockerVhdx GB)"
    Add-Report "WSL vhdx Compact"    "DRY RUN" "$beforeWSLVhdx GB"
    Add-Report "Docker vhdx Compact" "DRY RUN" "$beforeDockerVhdx GB"
} elseif (Confirm-Step "WSL + Docker Disk Compaction (briefly stops WSL)") {
    Write-Step "Shutting down WSL"
    wsl --shutdown
    Start-Sleep -Seconds 3

    if ($wslVhdxList.Count -gt 0) {
        foreach ($distro in $wslVhdxList) {
            Compact-VhdxFile $distro.Path "WSL [$($distro.Distro)]" | Out-Null
        }
        Add-Report "WSL vhdx Compact" "OK" "$($wslVhdxList.Count) distro(s) compacted"
    } else {
        Write-Skipped "No WSL distros found in registry"; Add-Report "WSL vhdx Compact" "SKIPPED" "not found"
    }

    if (-not $Config_SkipDockerCompact -and $dockerVhdx) {
        Compact-VhdxFile $dockerVhdx.FullName "Docker" | Out-Null
        Add-Report "Docker vhdx Compact" "OK" "compacted"
    } elseif ($Config_SkipDockerCompact) {
        Write-Skipped "Docker compaction disabled in config"
        Add-Report "Docker vhdx Compact" "SKIPPED" "disabled"
    } else {
        Write-Skipped "Docker vhdx not found"; Add-Report "Docker vhdx Compact" "SKIPPED" "not found"
    }

    Write-Step "Restarting WSL"
    Start-Process wsl -WindowStyle Hidden
    Start-Sleep -Seconds 8
    Write-Done "WSL restarted — Docker containers will auto-start if configured"
} else {
    Write-Skipped "Compaction skipped"
    Add-Report "WSL vhdx Compact"    "SKIPPED" "-"
    Add-Report "Docker vhdx Compact" "SKIPPED" "-"
}

# ── Docker Health Check ──────────────────────────────────────

$dockerHealth = @()
if ($hasAnyDocker) {
    Write-Header "DOCKER CONTAINER HEALTH CHECK"
    Start-Sleep -Seconds 3
    try {
        $psOutput = if ($hasDockerNative) {
            docker ps --format "{{.Names}}|{{.Status}}|{{.Ports}}" 2>&1
        } else {
            # Fix: wsl output may be UTF-16 on PS 5.1
            $prevEnc = [Console]::OutputEncoding
            [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
            $out = wsl -e bash -c "docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}'" 2>&1
            [Console]::OutputEncoding = $prevEnc
            $out
        }

        if ($psOutput -and $psOutput -notmatch "error|Cannot|not found|daemon") {
            foreach ($line in $psOutput) {
                if ($line -match "\|") {
                    $parts  = $line -split "\|"
                    $name   = $parts[0].Trim()
                    $status = $parts[1].Trim()
                    $ports  = if ($parts[2]) { $parts[2].Trim() } else { "internal" }
                    $icon   = if ($status -match "^Up") { "[UP]  " } else { "[DOWN]" }
                    $color  = if ($status -match "^Up") { "Green" } else { "Red" }
                    Write-Host "  $icon $name — $status ($ports)" -ForegroundColor $color
                    $dockerHealth += @{ Name=$name; Status=$status; Ports=$ports }
                }
            }
            if ($dockerHealth.Count -eq 0) { Write-Info "No running containers found" }
        } else { Write-Info "Docker daemon not running or no containers found" }
    } catch { Write-Info "Could not reach Docker — check manually" }
}

# ── After State ──────────────────────────────────────────────

Write-Header "CAPTURING AFTER STATE"
Start-Sleep -Seconds 2

$afterFree      = Get-FreeGB
$afterUsed      = Get-UsedGB
$afterChrome    = Get-FolderSizeGB $chromeBase
$afterEdge      = Get-FolderSizeGB $edgeBase
$afterNpm       = Get-FolderSizeGB "$env:LOCALAPPDATA\npm-cache"
$afterTemp      = Get-FolderSizeGB "$env:TEMP"
$afterWinTemp   = Get-FolderSizeGB "C:\Windows\Temp"
$afterWinUpdate = Get-FolderSizeGB "C:\Windows\SoftwareDistribution\Download"
$afterProjects  = [math]::Round(($Config_ProjectsPath | Where-Object { Test-Path $_ } |
                   ForEach-Object { Get-FolderSizeGB $_ } |
                   Measure-Object -Sum).Sum, 2)
$newWSLVhdx     = if ($wslVhdx)    { $r = Get-Item $wslVhdx.Path -EA SilentlyContinue; if ($r) { [math]::Round($r.Length/1GB,2) } else { $beforeWSLVhdx } } else { 0 }
$newDockerVhdx  = if ($dockerVhdx) { $r = Get-Item $dockerVhdx.FullName -EA SilentlyContinue; if ($r) { [math]::Round($r.Length/1GB,2) } else { $beforeDockerVhdx } } else { 0 }
$totalFreed     = [math]::Round($afterFree - $beforeFree, 2)

$chromeProfilesAfter = @{}
if (Test-Path $chromeBase) {
    Get-ChildItem $chromeBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^Profile|^Default" } | ForEach-Object {
            $chromeProfilesAfter[$_.Name] = Get-FolderSizeGB $_.FullName
        }
}

# ── Top 10 Largest Files ─────────────────────────────────────

Write-Header "TOP 10 LARGEST FILES (C:\Users\$env:USERNAME)"
Write-Info "Scanning..."

# Exclude reparse points (symlinks/junctions) to prevent infinite loops
# Confirmed issue: Get-ChildItem -Recurse follows junctions causing C:\Users\All Users loops
# Also exclude known system files that are not actionable (pagefile, hiberfil, swapfile)
# -Depth 7 covers 99% of real user files without risk of multi-minute scans on deep structures
$systemFileNames = @("pagefile.sys", "hiberfil.sys", "swapfile.sys")
$top10 = Get-ChildItem "C:\Users\$env:USERNAME" -Recurse -Depth 7 -File -Force `
             -Attributes !ReparsePoint -ErrorAction SilentlyContinue |
         Where-Object { $systemFileNames -notcontains $_.Name } |
         Sort-Object Length -Descending | Select-Object -First 10 |
         ForEach-Object { [PSCustomObject]@{ File=$_.FullName; SizeGB=[math]::Round($_.Length/1GB,2) } }

$top10 | ForEach-Object { Write-Host "  $($_.SizeGB) GB  $($_.File)" -ForegroundColor White }

# ── Final Summary ────────────────────────────────────────────

$scriptTimer.Stop()
$elapsed = "{0:mm\:ss}" -f $scriptTimer.Elapsed

Write-Header "CLEANUP COMPLETE"
Write-Host ""
Write-Host "  Before : $beforeFree GB free  ($beforeUsed GB used)" -ForegroundColor White
Write-Host "  After  : $afterFree GB free  ($afterUsed GB used)"   -ForegroundColor White
Write-Host "  Freed  : $totalFreed GB" -ForegroundColor Green
Write-Host "  Time   : $elapsed (mm:ss)" -ForegroundColor Cyan
if ($errorLog.Count -gt 0) {
    Write-Host "`n  Warnings ($($errorLog.Count)):" -ForegroundColor DarkYellow
    $errorLog | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
}
Write-Host ""

# ── Save Reports ─────────────────────────────────────────────

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$txtPath   = "$env:USERPROFILE\Desktop\WinDiskCleanup-$timestamp.txt"
$htmlPath  = "$env:USERPROFILE\Desktop\WinDiskCleanup-$timestamp.html"

# TXT Report
$txt = @(
    "===== WINDISKSCLEANUP REPORT =====",
    "Date       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Mode       : $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })",
    "Duration   : $elapsed (mm:ss)",
    "",
    "--- BEFORE ---",
    "C: Free       : $beforeFree GB",
    "C: Used       : $beforeUsed GB",
    "Chrome        : $beforeChrome GB",
    "Edge          : $beforeEdge GB",
    "npm cache     : $beforeNpm GB",
    "Temp files    : $([math]::Round($beforeTemp+$beforeWinTemp,2)) GB",
    "Win Update    : $beforeWinUpdate GB",
    "Projects      : $beforeProjects GB",
    "WSL vhdx      : $beforeWSLVhdx GB",
    "Docker vhdx   : $beforeDockerVhdx GB",
    "",
    "--- AFTER ---",
    "C: Free       : $afterFree GB",
    "C: Used       : $afterUsed GB",
    "Chrome        : $afterChrome GB",
    "Edge          : $afterEdge GB",
    "npm cache     : $afterNpm GB",
    "Temp files    : $([math]::Round($afterTemp+$afterWinTemp,2)) GB",
    "Win Update    : $afterWinUpdate GB",
    "Projects      : $afterProjects GB",
    "WSL vhdx      : $newWSLVhdx GB",
    "Docker vhdx   : $newDockerVhdx GB",
    "",
    "TOTAL FREED   : $totalFreed GB",
    "",
    "--- CHROME PROFILE BREAKDOWN ---"
)
foreach ($key in ($chromeProfilesBefore.Keys | Sort-Object)) {
    $b = $chromeProfilesBefore[$key].Size
    $e = $chromeProfilesBefore[$key].Email
    $a = if ($chromeProfilesAfter[$key]) { $chromeProfilesAfter[$key] } else { $b }
    $txt += "$key ($e) : $b GB -> $a GB (saved $([math]::Round($b-$a,2)) GB)"
}
$txt += @("", "--- DOCKER CONTAINERS ---")
if ($dockerHealth.Count -gt 0) { $dockerHealth | ForEach-Object { $txt += "$($_.Name) : $($_.Status)" } }
else { $txt += "N/A" }
$txt += @("", "--- TOP 10 LARGEST FILES ---")
$top10 | ForEach-Object { $txt += "$($_.SizeGB) GB  $($_.File)" }
$txt += @("", "--- WARNINGS / ERRORS ---")
if ($errorLog.Count -gt 0) { $errorLog | ForEach-Object { $txt += $_ } }
else { $txt += "None" }
$txt += "================================="
$txt | Out-File -FilePath $txtPath -Encoding UTF8

# HTML Report
$profileRows = ""
foreach ($key in ($chromeProfilesBefore.Keys | Sort-Object)) {
    $b    = $chromeProfilesBefore[$key].Size
    $e    = $chromeProfilesBefore[$key].Email
    $a    = if ($chromeProfilesAfter[$key]) { $chromeProfilesAfter[$key] } else { $b }
    $save = [math]::Round($b - $a, 2)
    $profileRows += "<tr><td>$key</td><td>$e</td><td>${b} GB</td><td>${a} GB</td><td><b>${save} GB</b></td></tr>"
}
$dockerRows = if ($dockerHealth.Count -gt 0) {
    $dockerHealth | ForEach-Object {
        $c = if ($_.Status -match "^Up") { "#4CAF50" } else { "#f44336" }
        "<tr><td>$($_.Name)</td><td style='color:$c'>$($_.Status)</td><td>$($_.Ports)</td></tr>"
    }
} else { @("<tr><td colspan='3' style='color:#888'>No Docker containers found or Docker not installed</td></tr>") }

$html = @"
<!DOCTYPE html><html><head><meta charset="UTF-8">
<title>WinDiskCleanup Report — $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
<style>
body{font-family:Segoe UI,sans-serif;background:#1a1a2e;color:#eee;padding:30px}
h1{color:#00d4ff}h2{color:#aaa;border-bottom:1px solid #333;padding-bottom:6px}
.badge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:13px;margin-left:10px}
.live{background:#4CAF50;color:#fff}.dryrun{background:#9C27B0;color:#fff}
.cards{display:flex;gap:20px;flex-wrap:wrap;margin:20px 0}
.card{background:#16213e;border-radius:10px;padding:20px 30px;min-width:140px;text-align:center}
.card .val{font-size:2em;font-weight:bold;color:#00d4ff}.card .lbl{font-size:12px;color:#888;margin-top:4px}
.freed{color:#4CAF50!important}
table{width:100%;border-collapse:collapse;margin:16px 0}
th{background:#0f3460;color:#00d4ff;padding:10px;text-align:left}
td{padding:9px 10px;border-bottom:1px solid #222;font-size:14px}
tr:hover td{background:#1e2a4a}
.footer{margin-top:40px;color:#555;font-size:12px}
</style></head><body>
<h1>WinDiskCleanup Report <span class="badge $(if($DryRun){'dryrun'}else{'live'})">$(if($DryRun){'DRY RUN'}else{'LIVE'})</span></h1>
<p style="color:#888">$(Get-Date -Format 'dddd, MMMM dd yyyy — HH:mm:ss')</p>
<div class="cards">
  <div class="card"><div class="val">$beforeFree GB</div><div class="lbl">Free Before</div></div>
  <div class="card"><div class="val">$afterFree GB</div><div class="lbl">Free After</div></div>
  <div class="card"><div class="val freed">+$totalFreed GB</div><div class="lbl">Total Freed</div></div>
  <div class="card"><div class="val">$afterUsed GB</div><div class="lbl">Used After</div></div>
  <div class="card"><div class="val" style="font-size:1.4em">$elapsed</div><div class="lbl">Duration (mm:ss)</div></div>
</div>
<h2>Savings by Category</h2>
<table><tr><th>Category</th><th>Before</th><th>After</th><th>Saved</th></tr>
<tr><td>Chrome</td><td>$beforeChrome GB</td><td>$afterChrome GB</td><td><b>$([math]::Round($beforeChrome-$afterChrome,2)) GB</b></td></tr>
<tr><td>Edge</td><td>$beforeEdge GB</td><td>$afterEdge GB</td><td><b>$([math]::Round($beforeEdge-$afterEdge,2)) GB</b></td></tr>
<tr><td>npm cache</td><td>$beforeNpm GB</td><td>$afterNpm GB</td><td><b>$([math]::Round($beforeNpm-$afterNpm,2)) GB</b></td></tr>
<tr><td>Temp Files</td><td>$([math]::Round($beforeTemp+$beforeWinTemp,2)) GB</td><td>$([math]::Round($afterTemp+$afterWinTemp,2)) GB</td><td><b>$([math]::Round(($beforeTemp+$beforeWinTemp)-($afterTemp+$afterWinTemp),2)) GB</b></td></tr>
<tr><td>Windows Update</td><td>$beforeWinUpdate GB</td><td>$afterWinUpdate GB</td><td><b>$([math]::Round($beforeWinUpdate-$afterWinUpdate,2)) GB</b></td></tr>
<tr><td>Projects folder</td><td>$beforeProjects GB</td><td>$afterProjects GB</td><td><b>$([math]::Round($beforeProjects-$afterProjects,2)) GB</b></td></tr>
<tr><td>WSL vhdx</td><td>$beforeWSLVhdx GB</td><td>$newWSLVhdx GB</td><td><b>$([math]::Round($beforeWSLVhdx-$newWSLVhdx,2)) GB</b></td></tr>
<tr><td>Docker vhdx</td><td>$beforeDockerVhdx GB</td><td>$newDockerVhdx GB</td><td><b>$([math]::Round($beforeDockerVhdx-$newDockerVhdx,2)) GB</b></td></tr>
</table>
<h2>Actions Performed</h2>
<table><tr><th>Action</th><th>Status</th><th>Notes</th></tr>$($htmlRows -join '')</table>
<h2>Chrome Profile Breakdown</h2>
<table><tr><th>Profile</th><th>Email</th><th>Before</th><th>After</th><th>Saved</th></tr>$profileRows</table>
<h2>Docker Container Status</h2>
<table><tr><th>Container</th><th>Status</th><th>Ports</th></tr>$($dockerRows -join '')</table>
<h2>Top 10 Largest Files</h2>
<table><tr><th>Size</th><th>File</th></tr>$($top10|ForEach-Object{"<tr><td>$($_.SizeGB) GB</td><td>$($_.File)</td></tr>"})</table>
$(if ($errorLog.Count -gt 0) {
"<h2 style='color:#FF9800'>Warnings / Errors ($($errorLog.Count))</h2><table><tr><th>Log Entry</th></tr>" +
($errorLog | ForEach-Object { "<tr><td style='color:#FF9800;font-family:monospace'>$_</td></tr>" } | Out-String) +
"</table>"
})
<div class="footer">Generated by WinDiskCleanup v1.4.0 — github.com/AbdulWaseaDev/WinDiskCleanup</div>
</body></html>
"@

$html | Out-File -FilePath $htmlPath -Encoding UTF8

Write-Host "  TXT Report : $txtPath" -ForegroundColor Cyan
Write-Host "  HTML Report: $htmlPath" -ForegroundColor Cyan
if (-not $DryRun) { Start-Process $htmlPath }
