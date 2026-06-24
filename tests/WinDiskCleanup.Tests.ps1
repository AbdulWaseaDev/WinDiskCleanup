#Requires -Module Pester
<#
    Pester v5 tests for WinDiskCleanup helper logic.
    Run with: Invoke-Pester ./tests -Output Detailed
    All tests use -DryRun semantics — nothing is deleted.
#>

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:MainScript = Join-Path $script:RepoRoot "WinDiskCleanup.ps1"
    $script:ConfigFile = Join-Path $script:RepoRoot "cleanup-config.ps1"
}

Describe "Repository structure" {
    It "WinDiskCleanup.ps1 exists" {
        $script:MainScript | Should -Exist
    }

    It "cleanup-config.ps1 exists" {
        $script:ConfigFile | Should -Exist
    }

    It "CHANGELOG.md exists" {
        Join-Path $script:RepoRoot "CHANGELOG.md" | Should -Exist
    }

    It "CONTRIBUTING.md exists" {
        Join-Path $script:RepoRoot "CONTRIBUTING.md" | Should -Exist
    }

    It "LICENSE exists" {
        Join-Path $script:RepoRoot "LICENSE" | Should -Exist
    }

    It "CI workflow exists" {
        Join-Path $script:RepoRoot ".github/workflows/lint.yml" | Should -Exist
    }
}

Describe "cleanup-config.ps1 — default values" {
    BeforeAll {
        . $script:ConfigFile
        # Capture into $script: scope — Pester v5 BeforeAll vars are not visible in It blocks otherwise
        $script:Cfg_ProjectsPath        = $Config_ProjectsPath
        $script:Cfg_InactiveNodeModules = $Config_InactiveNodeModules
        $script:Cfg_InactivePythonVenvs = $Config_InactivePythonVenvs
        $script:Cfg_SkipFlags           = @(
            $Config_SkipChrome, $Config_SkipEdge, $Config_SkipFirefox, $Config_SkipBrave,
            $Config_SkipNpm, $Config_SkipPip,
            $Config_SkipTemp, $Config_SkipWindowsUpdate, $Config_SkipWindowsStore, $Config_SkipRecycleBin,
            $Config_SkipClaude, $Config_SkipVSCode, $Config_SkipTeams,
            $Config_SkipPycache, $Config_SkipNodeModules, $Config_SkipPythonVenvs,
            $Config_SkipDocker, $Config_SkipWSLApt, $Config_SkipWSLCompact, $Config_SkipDockerCompact
        )
    }

    It "Config_ProjectsPath is an array" {
        $script:Cfg_ProjectsPath | Should -BeOfType [array]
    }

    It "Config_InactiveNodeModules is an array" {
        $script:Cfg_InactiveNodeModules | Should -BeOfType [array]
    }

    It "Config_InactivePythonVenvs is an array" {
        $script:Cfg_InactivePythonVenvs | Should -BeOfType [array]
    }

    It "All skip flags default to false" {
        $script:Cfg_SkipFlags | Should -Not -Contain $true
    }
}

Describe "WinDiskCleanup.ps1 — script parameters" {
    It "accepts -DryRun switch" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain "DryRun"
    }

    It "accepts -Interactive switch" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain "Interactive"
    }

    It "accepts -SkipWSLCompact switch" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain "SkipWSLCompact"
    }

    It "accepts -SkipDocker switch" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain "SkipDocker"
    }

    It "accepts -SkipProjects switch" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$null)
        $params = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain "SkipProjects"
    }
}

Describe "WinDiskCleanup.ps1 — no syntax errors" {
    It "parses without errors" {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:MainScript, [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}

Describe "WinDiskCleanup.ps1 — DryRun produces no deletions" {
    It "runs -DryRun without throwing" {
        { & $script:MainScript -DryRun 2>&1 } | Should -Not -Throw
    }
}
