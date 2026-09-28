$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$profilePath = Join-Path $repoRoot 'benchmarks/model-profile.json'
. (Join-Path $PSScriptRoot 'harness-profile.ps1')
$profileText = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
$template = $profileText | ConvertFrom-Json
$anchorDate = [datetime]::ParseExact($template.reviewed_on, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempParent ('codex-harness-tests-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
$script:checks = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Failed: $Message" }
    $script:checks++
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    $didThrow = $false
    try { $null = & $Action } catch { $didThrow = $true }
    Assert-True -Condition $didThrow -Message $Message
}

function Write-Fixture {
    param([string]$Name, [string]$Content)
    $fixturePath = Join-Path $tempRoot $Name
    [System.IO.File]::WriteAllText($fixturePath, $Content, (New-Object System.Text.UTF8Encoding($false)))
    return $fixturePath
}

function New-ProfileFixture {
    param([string]$Name, [scriptblock]$Change)
    $fixtureProfile = $profileText | ConvertFrom-Json
    & $Change $fixtureProfile
    return Write-Fixture -Name $Name -Content ($fixtureProfile | ConvertTo-Json -Depth 10)
}

function Invoke-Evaluation {
    param([string]$TargetPath, [string]$ModelProfilePath)
    $json = & (Join-Path $PSScriptRoot 'evaluate-agents.ps1') -Path $TargetPath -ProfilePath $ModelProfilePath -AsJson
    return ($json | ConvertFrom-Json)
}

function Invoke-ChildScript {
    param([string]$ScriptName, [string[]]$Arguments)
    $powerShellExe = (Get-Process -Id $PID).Path
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $powerShellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $ScriptName) @Arguments 2>&1 | ForEach-Object { [string]$_ })
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") }
    } finally {
        $ErrorActionPreference = $savedPreference
    }
}

try {
    $profile = Get-HarnessProfile -ProfilePath $profilePath -Today $anchorDate
    Assert-True ($profile.TargetModel -eq 'gpt-6-sol') 'The checked-in target remains GPT-6 Sol.'
    Assert-True $profile.IsCurrent 'Profile is current on the review date.'
    $beforeDeadline = Get-HarnessProfile -ProfilePath $profilePath -Today $anchorDate.AddDays($template.review_interval_days - 1)
    Assert-True $beforeDeadline.IsCurrent 'Profile is current before the deadline.'
    $atDeadline = Get-HarnessProfile -ProfilePath $profilePath -Today $anchorDate.AddDays($template.review_interval_days)
    Assert-True (-not $atDeadline.IsCurrent) 'Profile review becomes due at the deadline.'
    Assert-Throws { Get-HarnessProfile -ProfilePath $profilePath -Today $anchorDate.AddDays(-1) } 'Future review dates are rejected.'

    $badInterval = New-ProfileFixture 'bad-interval.json' { param($p) $p.review_interval_days = 0 }
    Assert-Throws { Get-HarnessProfile -ProfilePath $badInterval -Today $anchorDate } 'Zero review intervals are rejected.'
    $fractionalInterval = New-ProfileFixture 'fractional-interval.json' { param($p) $p.review_interval_days = 1.5 }
    Assert-Throws { Get-HarnessProfile -ProfilePath $fractionalInterval -Today $anchorDate } 'Fractional review intervals are rejected.'
    $badDate = New-ProfileFixture 'bad-date.json' { param($p) $p.reviewed_on = '2026-02-30' }
    Assert-Throws { Get-HarnessProfile -ProfilePath $badDate } 'Invalid calendar dates are rejected.'
    $badSchema = New-ProfileFixture 'bad-schema.json' { param($p) $p.schema_version = 2 }
    Assert-Throws { Get-HarnessProfile -ProfilePath $badSchema -Today $anchorDate } 'Unsupported profile schemas are rejected.'
    $badSource = New-ProfileFixture 'bad-source.json' { param($p) $p.sources[0].url = 'https://example.com/api/docs/models/gpt-6-sol' }
    Assert-Throws { Get-HarnessProfile -ProfilePath $badSource -Today $anchorDate } 'Non-official sources are rejected.'
    $repeatedSources = New-ProfileFixture 'repeated-sources.json' { param($p) $p.sources = @($p.sources[0], $p.sources[0]) }
    Assert-Throws { Get-HarnessProfile -ProfilePath $repeatedSources -Today $anchorDate } 'Repeating the model page is not a guidance review.'
    $wrongModel = New-ProfileFixture 'wrong-model.json' { param($p) $p.target_model = 'gpt-6-luna' }
    Assert-Throws { Get-HarnessProfile -ProfilePath $wrongModel -Today $anchorDate } 'The model page must match the target model.'
    $brokenJson = Write-Fixture 'broken.json' '{ broken'
    Assert-Throws { Get-HarnessProfile -ProfilePath $brokenJson } 'Malformed JSON is rejected.'
    Assert-Throws { Get-HarnessProfile -ProfilePath (Join-Path $tempRoot 'missing.json') } 'Missing profiles are rejected.'

    # Evaluation fixtures use today's review date so regression tests remain usable when the real review is due.
    $freshPath = New-ProfileFixture 'fresh.json' { param($p) $p.reviewed_on = (Get-Date).ToString('yyyy-MM-dd') }
    $scopedPath = Write-Fixture 'scoped.txt' @'
# Fixture
- Use a task-specific branch.
- Push automatically only to an existing remote after confirming no deployment, publication, or release.
- Ask before pushing to shared branches unless already authorized.
- Run validation appropriate to the change.
'@
    $scoped = Invoke-Evaluation $scopedPath $freshPath
    Assert-True ($scoped.SkillHits.Count -eq 0) 'Release authorization wording does not imply a Skill workflow.'
    Assert-True ($scoped.AutonomyRisks.Count -eq 0) 'Scoped approval and testing rules are not unconditional restrictions.'
    Assert-True ($scoped.Scores.'Autonomy Calibration' -eq 10) 'Scoped rules retain the autonomy score.'
    Assert-True ($scoped.Profile.TargetModel -eq 'gpt-6-sol') 'JSON reports include the actual target profile.'
    Assert-True ($scoped.RubricVersion -eq '2026-09-gpt6-ja') 'JSON reports identify their rubric.'
    $qualifiedPath = Write-Fixture 'qualified.txt' "- Always ask before force pushing.`n- Always run affected tests.`n- Always delegate when independent work would save time."
    $qualified = Invoke-Evaluation $qualifiedPath $freshPath
    Assert-True ($qualified.AutonomyRisks.Count -eq 0) 'Explicit operation boundaries and conditional rules are not blanket restrictions.'
    $emptyPath = Write-Fixture 'empty.txt' ''
    Assert-Throws { Invoke-Evaluation $emptyPath $freshPath } 'Empty instructions cannot receive a high evaluation score.'
    $whitespacePath = Write-Fixture 'whitespace.txt' " `n `n"
    Assert-Throws { & (Join-Path $PSScriptRoot 'measure-agents.ps1') -Path $whitespacePath } 'Whitespace-only instructions are rejected by metrics.'

    $distinctPath = Write-Fixture 'distinct.txt' "- Keep existing patterns.`n- Keep existing staged changes.`n- Keep existing validation setup."
    $distinct = Invoke-Evaluation $distinctPath $freshPath
    Assert-True ($distinct.DuplicationGroups.Count -eq 0) 'Shared vocabulary does not count as duplicated instructions.'
    $duplicatePath = Write-Fixture 'duplicate.txt' "- Keep existing changes.`n-  Keep   existing changes."
    $duplicate = Invoke-Evaluation $duplicatePath $freshPath
    Assert-True ($duplicate.DuplicationGroups.Count -eq 1) 'Normalized duplicate instructions are detected.'
    Assert-True ($duplicate.DuplicationGroups[0].Count -eq 2) 'Duplicate occurrences are counted correctly.'
    Assert-True ($duplicate.Scores.Duplication -lt $distinct.Scores.Duplication) 'Actual duplication reduces the score.'

    $unconditionalPath = Write-Fixture 'unconditional.txt' @'
- Always ask before every edit.
- Before changing files, inspect the README and all existing structure.
- Always run all tests.
- Always delegate work to sub-agents.
- Do not stage, commit, or push unless the user explicitly asks.
'@
    $unconditional = Invoke-Evaluation $unconditionalPath $freshPath
    Assert-True ($unconditional.AutonomyRisks.Count -eq 5) 'Unconditional approvals, context, tests, delegation, and Git restrictions are detected.'
    Assert-True ($unconditional.Scores.'Autonomy Calibration' -eq 0) 'Unconditional restrictions reduce autonomy calibration.'

    $japanesePath = Write-Fixture 'japanese.txt' '- 日本語で回答する。'
    $japanese = Invoke-Evaluation $japanesePath $freshPath
    Assert-True ($japanese.Metrics.JapaneseCharacterRatio -gt 30) 'Japanese character ratio remains visible.'
    Assert-True ($japanese.Scores.'Context Economy' -eq 15) 'Language ratio alone does not reduce context economy.'
    Assert-True ($japanese.Metrics.ActionableBulletItems -eq 1) 'Japanese action wording is recognized.'
    $japaneseUnconditionalPath = Write-Fixture 'japanese-unconditional.txt' @'
- 毎回の編集前にユーザーに確認する。
- 編集前にREADMEと構成全体を読む。
- 常に全テストを実行する。
- 必ずサブエージェントに委譲する。
- ユーザーから明示的に依頼されない限り、stage、commit、pushを行わない。
'@
    $japaneseUnconditional = Invoke-Evaluation $japaneseUnconditionalPath $freshPath
    Assert-True ($japaneseUnconditional.AutonomyRisks.Count -eq 5) 'Japanese unconditional workflow restrictions are detected.'
    $japaneseScopedPath = Write-Fixture 'japanese-scoped.txt' @'
- 必ず破壊的な操作の前にユーザーに確認する。
- 常に関連するテストを実行する。
- 独立した作業に分けられる場合にサブエージェントを使用する。
- 承認済みの範囲は再確認しない。
- 公開やリリースを発生させないことを確認できた場合にpushする。
'@
    $japaneseScoped = Invoke-Evaluation $japaneseScopedPath $freshPath
    Assert-True ($japaneseScoped.AutonomyRisks.Count -eq 0 -and $japaneseScoped.SkillHits.Count -eq 0) 'Japanese scoped approvals, tests, delegation, and release boundaries are not blanket restrictions or workflows.'
    $japaneseClassificationsPath = Write-Fixture 'japanese-classifications.txt' "- いい感じに品質を上げる。`n- このリポジトリでは専用のコマンドを実行する。`n- デバッグの手順書を毎回作成する。"
    $japaneseClassifications = Invoke-Evaluation $japaneseClassificationsPath $freshPath
    Assert-True ($japaneseClassifications.VagueHits.Count -eq 1) 'Japanese vague wording is detected.'
    Assert-True ($japaneseClassifications.RepoHits.Count -eq 1) 'Japanese repository-specific rules are detected.'
    Assert-True ($japaneseClassifications.SkillHits.Count -eq 1) 'Japanese procedural instructions are detected.'
    $japaneseConflictPath = Write-Fixture 'japanese-conflict.txt' "- 常にユーザーに確認する。`n- 不足情報には仮定を置いて進める。"
    $japaneseConflict = Invoke-Evaluation $japaneseConflictPath $freshPath
    Assert-True ($japaneseConflict.ConflictRisks.Count -eq 1) 'Japanese conflicting guidance is flagged for review.'
    $japaneseDuplicatePath = Write-Fixture 'japanese-duplicate.txt' "- 既存の変更を保持する。`n-  既存の変更を保持する"
    $japaneseDuplicate = Invoke-Evaluation $japaneseDuplicatePath $freshPath
    Assert-True ($japaneseDuplicate.DuplicationGroups.Count -eq 1) 'Japanese duplicates normalize their final punctuation.'
    $candidate = Invoke-Evaluation (Join-Path $repoRoot 'AGENTSExample.md') $freshPath
    Assert-True ($candidate.Classification.Keep.Count -gt 0 -and $candidate.Metrics.ActionableBulletItems -ge 40) 'The Japanese candidate retains actionable wording and global classifications.'
    Assert-True ($candidate.AutonomyRisks.Count -eq 0 -and $candidate.RepoHits.Count -eq 0) 'Translation does not turn scoped candidate guidance into unconditional or repo-specific rules.'
    $longPath = Write-Fixture 'long-line.txt' ('- Keep the authorization boundary explicit. ' + ('Additional context about approved operations. ' * 4))
    $long = Invoke-Evaluation $longPath $freshPath
    Assert-True ($long.Metrics.LongLines -eq 1) 'Long lines remain visible.'
    Assert-True ($long.Scores.Clarity -eq 15 -and $long.Scores.'Context Economy' -eq 15) 'Line length alone does not reduce the score.'

    $stalePath = New-ProfileFixture 'stale.json' { param($p) $p.reviewed_on = (Get-Date).AddDays(-$p.review_interval_days).ToString('yyyy-MM-dd') }
    $stale = Invoke-Evaluation $scopedPath $stalePath
    Assert-True ($stale.QualityGate -eq 'Review due') 'A due review remains visible regardless of the score.'
    $staleRun = Invoke-ChildScript 'validate-harness.ps1' @('-Path', $scopedPath, '-ProfilePath', $stalePath, '-SkipScriptRuns')
    Assert-True ($staleRun.ExitCode -ne 0 -and $staleRun.Text -match 'Fail: Official guidance freshness') 'SkipScriptRuns cannot bypass freshness checks.'
    $invalidRun = Invoke-ChildScript 'validate-harness.ps1' @('-Path', $scopedPath, '-ProfilePath', $badSchema, '-SkipScriptRuns')
    Assert-True ($invalidRun.ExitCode -ne 0 -and $invalidRun.Text -match 'Fail: Model profile validity') 'Invalid profiles fail validation.'
    $failedChildRun = Invoke-ChildScript 'validate-harness.ps1' @('-Path', $scopedPath, '-ProfilePath', $badSchema)
    Assert-True ($failedChildRun.ExitCode -ne 0 -and $failedChildRun.Text -match 'Fail: Harness score floor') 'A failed evaluator cannot pass by emitting other output.'
    $missingRun = Invoke-ChildScript 'validate-harness.ps1' @('-Path', (Join-Path $tempRoot 'missing.txt'), '-ProfilePath', $freshPath, '-SkipScriptRuns')
    Assert-True ($missingRun.ExitCode -ne 0) 'Missing instruction targets fail validation.'
    $metricsRun = Invoke-ChildScript 'measure-agents.ps1' @('-Path', $japanesePath)
    Assert-True ($metricsRun.ExitCode -eq 0 -and $metricsRun.Text -notmatch 'High Japanese|Too short|Few sections') 'Metrics do not penalize language, short files, or few headings.'

    $diffJson = & (Join-Path $PSScriptRoot 'evaluate-agents.ps1') -BeforePath $unconditionalPath -AfterPath $scopedPath -ProfilePath $freshPath -AsJson
    $diff = $diffJson | ConvertFrom-Json
    Assert-True ($diff.Before.RubricVersion -eq $diff.After.RubricVersion -and $diff.ScoreChange -gt 0) 'Diff evaluation uses one rubric and reports the improvement.'
    Assert-Throws { & (Join-Path $PSScriptRoot 'evaluate-agents.ps1') -BeforePath $scopedPath -ProfilePath $freshPath -AsJson } 'Diff evaluation requires both paths.'

    # Test script location independence without depending on the caller's working directory.
    Push-Location $tempRoot
    try {
        $outsideRun = Invoke-ChildScript 'validate-harness.ps1' @('-Path', (Join-Path $repoRoot 'AGENTSExample.md'), '-ProfilePath', $freshPath)
        Assert-True ($outsideRun.ExitCode -eq 0) 'Harness validation resolves its files when called outside the repository.'
    } finally {
        Pop-Location
    }
    Write-Host "Harness regression checks passed: $script:checks"
} finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    if ([System.IO.Path]::GetDirectoryName($resolvedTempRoot) -ne $tempParent -or
        [System.IO.Path]::GetFileName($resolvedTempRoot) -notmatch '^codex-harness-tests-[a-f0-9]{32}$') {
        throw 'Refusing to remove an unexpected test directory.'
    }
    Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
}
