param(
    [Parameter(Mandatory = $false)]
    [string]$Path = "AGENTSExample.md",

    [Parameter(Mandatory = $false)]
    [int]$MinimumMetricsScore = 70,

    [Parameter(Mandatory = $false)]
    [int]$MinimumHarnessScore = 70,

    [Parameter(Mandatory = $false)]
    [switch]$SkipScriptRuns
)

$ErrorActionPreference = "Stop"

function New-StringList {
    return New-Object System.Collections.Generic.List[string]
}

function Add-CheckResult {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [string]$Name,
        [bool]$Passed,
        [string]$Message
    )

    $Results.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Message = $Message
    })
}

function Get-ScoreFromOutput {
    param(
        [string[]]$Output,
        [string]$Pattern
    )

    foreach ($line in $Output) {
        if ($line -match $Pattern) {
            return [int]$Matches[1]
        }
    }

    return $null
}

function Invoke-ValidationScript {
    param(
        [string]$ScriptPath,
        [string]$TargetPath
    )

    $powerShellExe = (Get-Process -Id $PID).Path
    return & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -Path $TargetPath 2>&1
}

$results = New-Object System.Collections.Generic.List[object]

$requiredFiles = @(
    "README.md",
    "AGENTS.md",
    "AGENTSExample.md",
    "benchmarks/AGENTS.checklist.md",
    "benchmarks/HARNESS.checklist.md",
    "scripts/evaluate-agents.ps1",
    "scripts/measure-agents.ps1",
    "scripts/validate-harness.ps1"
)

foreach ($file in $requiredFiles) {
    $exists = Test-Path -LiteralPath $file -PathType Leaf
    Add-CheckResult -Results $results -Name "Required file: $file" -Passed $exists -Message $(if ($exists) { "found" } else { "missing" })
}

$readmeContent = ""
if (Test-Path -LiteralPath "README.md" -PathType Leaf) {
    $readmeContent = Get-Content -LiteralPath "README.md" -Raw
}

$readmeChecks = @(
    @{ Name = "README explains floor-check purpose"; Pattern = "最低限|floor|warning light|警告" },
    @{ Name = "README documents validate-harness.ps1"; Pattern = "validate-harness\.ps1" },
    @{ Name = "README documents HARNESS checklist"; Pattern = "HARNESS\.checklist\.md" },
    @{ Name = "README keeps manual review expectation"; Pattern = "手動|manual" }
)

foreach ($check in $readmeChecks) {
    $passed = $readmeContent -match $check.Pattern
    Add-CheckResult -Results $results -Name $check.Name -Passed $passed -Message $(if ($passed) { "covered" } else { "not covered" })
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-CheckResult -Results $results -Name "Target AGENTS file exists" -Passed $false -Message "missing: $Path"
} elseif (-not $SkipScriptRuns) {
    $measureOutput = Invoke-ValidationScript -ScriptPath ".\scripts\measure-agents.ps1" -TargetPath $Path
    $metricsScore = Get-ScoreFromOutput -Output $measureOutput -Pattern '^- Score:\s+(\d+)\s+/'
    $metricsPassed = $null -ne $metricsScore -and $metricsScore -ge $MinimumMetricsScore
    Add-CheckResult -Results $results -Name "Metrics score floor" -Passed $metricsPassed -Message "score: $metricsScore / 100, floor: $MinimumMetricsScore"

    $evaluationOutput = Invoke-ValidationScript -ScriptPath ".\scripts\evaluate-agents.ps1" -TargetPath $Path
    $harnessScore = Get-ScoreFromOutput -Output $evaluationOutput -Pattern '^- Overall:\s+(\d+)\s+/'
    $harnessPassed = $null -ne $harnessScore -and $harnessScore -ge $MinimumHarnessScore
    Add-CheckResult -Results $results -Name "Harness score floor" -Passed $harnessPassed -Message "score: $harnessScore / 100, floor: $MinimumHarnessScore"
} else {
    Add-CheckResult -Results $results -Name "Script score checks" -Passed $true -Message "skipped by -SkipScriptRuns"
}

$failures = @($results | Where-Object { -not $_.Passed })

Write-Host "## Harness Validation"
Write-Host ""
Write-Host "- Target: $Path"
Write-Host "- Failed checks: $($failures.Count)"
Write-Host "- Total checks: $($results.Count)"
Write-Host ""
Write-Host "### Checks"

foreach ($result in $results) {
    $status = if ($result.Passed) { "Pass" } else { "Fail" }
    Write-Host "- ${status}: $($result.Name) - $($result.Message)"
}

if ($failures.Count -gt 0) {
    exit 1
}
