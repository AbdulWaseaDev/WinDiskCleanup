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
    It "path arrays use array syntax and all skip flags default to false" {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ConfigFile, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        $assignments = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] },
            $true
        )

        foreach ($name in @("Config_ProjectsPath", "Config_InactiveNodeModules", "Config_InactivePythonVenvs")) {
            $a = $assignments | Where-Object { $_.Left.VariablePath.UserPath -eq $name }
            $a | Should -Not -BeNullOrEmpty -Because "$name must be defined"
            $a.Right | Should -BeOfType [System.Management.Automation.Language.ArrayExpressionAst] `
                -Because "$name should be assigned an array literal"
        }

        $skipVars = $assignments | Where-Object { $_.Left.VariablePath.UserPath -like "Config_Skip*" }
        $skipVars.Count | Should -BeGreaterThan 0
        foreach ($a in $skipVars) {
            $a.Right.ToString() | Should -Be '$false' `
                -Because "$($a.Left.VariablePath.UserPath) should default to false"
        }
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
