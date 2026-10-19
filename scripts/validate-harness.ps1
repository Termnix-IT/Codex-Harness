param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'AGENTSExample.md'),

    [string]$ProfilePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'benchmarks/model-profile.json'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]$MinimumMetricsScore = 70,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]$MinimumHarnessScore = 70,

    [Parameter(Mandatory = $false)]
    [switch]$SkipScriptRuns
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'harness-profile.ps1')

function New-StringList {
    return New-Object System.Collections.Generic.List[string]
}

function Add-CheckResult {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [string]$Name,
        [bool]$Passed,
        [string]$Message,
        [switch]$Warning
    )

    $Results.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Message = $Message
        IsWarning = [bool]$Warning
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

function Add-ScoreCheck {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [string]$Name,
        [object]$Run,
        [string]$Pattern,
        [int]$Threshold
    )

    $score = Get-ScoreFromOutput -Output $Run.Output -Pattern $Pattern
    $valid = $Run.ExitCode -eq 0 -and $null -ne $score -and $score -ge 0 -and $score -le 100
    $warning = $valid -and $score -lt $Threshold
    $message = if ($valid) {
        "score: $score / 100, warning threshold: $Threshold"
    } else {
        "evaluation failed or score missing/invalid (exit code: $($Run.ExitCode), score: $score)"
    }
    Add-CheckResult -Results $Results -Name $Name -Passed $valid -Warning:$warning -Message $message
}

function Invoke-ValidationScript {
    param(
        [string]$ScriptPath,
        [string]$TargetPath,
        [string]$ModelProfilePath
    )

    $powerShellExe = (Get-Process -Id $PID).Path
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-Path', $TargetPath)
    if ($ModelProfilePath) { $arguments += @('-ProfilePath', $ModelProfilePath) }
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $powerShellExe @arguments 2>&1 | ForEach-Object { [string]$_ })
        return [pscustomobject]@{ Output = $output; ExitCode = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $savedPreference
    }
}

$results = New-Object System.Collections.Generic.List[object]

$requiredFiles = @(
    "README.md",
    "AGENTS.md",
    "AGENTSExample.md",
    "benchmarks/AGENTS.checklist.md",
    "benchmarks/HARNESS.checklist.md",
    "benchmarks/model-profile.json",
    "scripts/evaluate-agents.ps1",
    "scripts/harness-profile.ps1",
    "scripts/measure-agents.ps1",
    "scripts/validate-harness.ps1",
    "scripts/test-harness.ps1"
)

foreach ($file in $requiredFiles) {
    $exists = Test-Path -LiteralPath (Join-Path $repoRoot $file) -PathType Leaf
    Add-CheckResult -Results $results -Name "Required file: $file" -Passed $exists -Message $(if ($exists) { "found" } else { "missing" })
}

$readmeContent = ""
if (Test-Path -LiteralPath (Join-Path $repoRoot 'README.md') -PathType Leaf) {
    $readmeContent = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw -Encoding UTF8
}

$readmeChecks = @(
    @{ Name = "README explains validation purpose"; Pattern = "最低限|warning light|警告" },
    @{ Name = "README documents validate-harness.ps1"; Pattern = "validate-harness\.ps1" },
    @{ Name = "README documents HARNESS checklist"; Pattern = "HARNESS\.checklist\.md" },
    @{ Name = "README keeps manual review expectation"; Pattern = "手動|manual" },
    @{ Name = "README documents model profile"; Pattern = "model-profile\.json" },
    @{ Name = "README distinguishes static and behavior evaluation"; Pattern = "行動評価" }
)

foreach ($check in $readmeChecks) {
    $passed = $readmeContent -match $check.Pattern
    Add-CheckResult -Results $results -Name $check.Name -Passed $passed -Message $(if ($passed) { "covered" } else { "not covered" })
}

try {
    $profile = Get-HarnessProfile -ProfilePath $ProfilePath
    Add-CheckResult -Results $results -Name 'Official guidance freshness' -Passed $profile.IsCurrent -Message "$($profile.TargetModel), reviewed: $($profile.ReviewedOn), age: $($profile.AgeDays) days, interval: $($profile.ReviewIntervalDays) days"
} catch {
    Add-CheckResult -Results $results -Name 'Model profile validity' -Passed $false -Message $_.Exception.Message
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-CheckResult -Results $results -Name "Target AGENTS file exists" -Passed $false -Message "missing: $Path"
} elseif (-not $SkipScriptRuns) {
    $measureRun = Invoke-ValidationScript -ScriptPath (Join-Path $PSScriptRoot 'measure-agents.ps1') -TargetPath $Path
    Add-ScoreCheck -Results $results -Name 'Metrics score check' -Run $measureRun -Pattern '^- Score:\s+(\d+)\s+/' -Threshold $MinimumMetricsScore

    $evaluationRun = Invoke-ValidationScript -ScriptPath (Join-Path $PSScriptRoot 'evaluate-agents.ps1') -TargetPath $Path -ModelProfilePath $ProfilePath
    Add-ScoreCheck -Results $results -Name 'Harness score check' -Run $evaluationRun -Pattern '^- Overall:\s+(\d+)\s+/' -Threshold $MinimumHarnessScore
} else {
    Add-CheckResult -Results $results -Name "Script score checks" -Passed $true -Message "skipped by -SkipScriptRuns"
}

$failures = @($results | Where-Object { -not $_.Passed })
$warnings = @($results | Where-Object { $_.IsWarning })

Write-Host "## Harness Validation"
Write-Host ""
Write-Host "- Target: $Path"
Write-Host "- Failed checks: $($failures.Count)"
Write-Host "- Warnings: $($warnings.Count)"
Write-Host "- Total checks: $($results.Count)"
Write-Host ""
Write-Host "### Checks"

foreach ($result in $results) {
    $status = if (-not $result.Passed) { "Fail" } elseif ($result.IsWarning) { "Warning" } else { "Pass" }
    Write-Host "- ${status}: $($result.Name) - $($result.Message)"
}

if ($failures.Count -gt 0) {
    exit 1
}
