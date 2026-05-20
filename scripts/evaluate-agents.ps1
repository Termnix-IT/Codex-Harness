param(
    [Parameter(Mandatory = $false)]
    [string]$Path = "AGENTSExample.md",

    [Parameter(Mandatory = $false)]
    [string]$BeforePath,

    [Parameter(Mandatory = $false)]
    [string]$AfterPath
)

$ErrorActionPreference = "Stop"

function New-StringList {
    return New-Object System.Collections.Generic.List[string]
}

function Get-QualityGate {
    param([int]$Score)

    if ($Score -ge 90) {
        return "Excellent"
    }
    if ($Score -ge 80) {
        return "Good"
    }
    if ($Score -ge 70) {
        return "Warning"
    }
    return "Needs revision"
}

function Add-Unique {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Value
    )

    if ($Value -and -not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function Get-BulletItems {
    param([string[]]$Lines)

    $items = New-StringList
    foreach ($line in $Lines) {
        if ($line -match '^\s*-\s+(.+)$') {
            $items.Add($Matches[1].Trim())
        }
    }
    return @($items)
}

function Get-RuleHits {
    param(
        [string[]]$Items,
        [object[]]$Rules
    )

    $hits = @()
    foreach ($item in $Items) {
        foreach ($rule in $Rules) {
            if ($item -match $rule.Pattern) {
                $hits += [pscustomobject]@{
                    Name = $rule.Name
                    Text = $item
                    Recommendation = $rule.Recommendation
                }
            }
        }
    }
    return @($hits)
}

function Get-DuplicationGroups {
    param([string[]]$Items)

    $groups = @(
        @{
            Name = "small focused changes"
            Pattern = '(?i)\b(small|minimal|focused|narrow|broad|rewrite|diff)\b'
        },
        @{
            Name = "respect existing work"
            Pattern = '(?i)\b(existing|convention|structure|pattern|revert|user-owned)\b'
        },
        @{
            Name = "safety and secrets"
            Pattern = '(?i)\b(secret|token|password|private key|\.env|destructive|public repository)\b'
        },
        @{
            Name = "validation"
            Pattern = '(?i)\b(validate|validation|test|run|feasible|representative)\b'
        }
    )

    $results = @()
    foreach ($group in $groups) {
        $matches = @($Items | Where-Object { $_ -match $group.Pattern })
        if ($matches.Count -gt 2) {
            $results += [pscustomobject]@{
                Name = $group.Name
                Count = $matches.Count
                Items = $matches
            }
        }
    }

    return @($results)
}

function Get-ConflictRisks {
    param([string]$Content)

    $risks = @()
    $pairs = @(
        @{
            Name = "Detailed explanations vs concise responses"
            A = '(?i)\b(always|must)\b.*\b(detail|detailed|explain everything|comprehensive)\b'
            B = '(?i)\b(concise|brief|short|minimal response)\b'
        },
        @{
            Name = "Always ask vs make reasonable assumptions"
            A = '(?i)\b(always|must)\b.*\b(ask|confirm)\b'
            B = '(?i)\b(assume|reasonable assumption|choose the safest|minimal action)\b'
        },
        @{
            Name = "Never edit vs automatic fixes"
            A = '(?i)\b(never|do not)\b.*\b(edit|modify|change)\b'
            B = '(?i)\b(auto|automatic|automatically)\b.*\b(fix|update|rewrite|modify)\b'
        },
        @{
            Name = "Always run tests vs when feasible"
            A = '(?i)\b(always|must)\b.*\b(run tests|test)\b'
            B = '(?i)\b(when feasible|if feasible|cannot be run)\b'
        }
    )

    foreach ($pair in $pairs) {
        if (($Content -match $pair.A) -and ($Content -match $pair.B)) {
            $risks += $pair.Name
        }
    }

    return @($risks)
}

function Get-AgentsEvaluation {
    param([string]$TargetPath)

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        throw "AGENTS example file does not exist: $TargetPath"
    }

    $content = Get-Content -LiteralPath $TargetPath -Raw
    $lines = @($content -split "`r?`n")
    $nonEmptyLines = @($lines | Where-Object { $_.Trim().Length -gt 0 })
    $sections = @($lines | Where-Object { $_ -match '^##\s+' })
    $bullets = Get-BulletItems -Lines $lines
    $longLines = @($lines | Where-Object { $_.Length -gt 140 })

    $charCount = $content.Length
    $japaneseCharCount = ([regex]::Matches($content, '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}]')).Count
    if ($charCount -gt 0) {
        $japaneseCharRatio = [Math]::Round(($japaneseCharCount / $charCount) * 100, 1)
    } else {
        $japaneseCharRatio = 0
    }

    $actionWords = @($bullets | Where-Object { $_ -match '^(?i)(Do not|Do|Prefer|Before|After|When|Ask|State|Run|Use|Keep|Treat|Write|Switch|Add|Make|Explain|Separate)\b' })

    $vagueRules = @(
        @{ Name = "vague quality wording"; Pattern = '(?i)\b(make it better|be careful|improve quality|do it nicely|good quality|as appropriate|where possible|best effort)\b'; Recommendation = "Rewrite for clarity" }
    )
    $taskSpecificRules = @(
        @{ Name = "task-specific or artifact-specific wording"; Pattern = '(?i)\b(portfolio|network diagram|diagram\.svg|outputs/|screenshots/|release checklist|README maintenance|UI review|specific section structure)\b'; Recommendation = "Move to Skill or repo AGENTS.md" }
    )
    $skillRules = @(
        @{ Name = "workflow-like instruction"; Pattern = '(?i)\b(workflow|checklist|step-by-step|release|investigation|debugging flow|UI review|diagram generation|maintenance workflow)\b'; Recommendation = "Move to Skill" }
    )
    $repoRules = @(
        @{ Name = "repository-specific instruction"; Pattern = '(?i)\b(this repository|repo-specific|project structure|directory structure|templates/|skills/|benchmarks/|scripts/|outputs/|source candidate)\b'; Recommendation = "Move to repo AGENTS.md" }
    )

    $vagueHits = Get-RuleHits -Items $bullets -Rules $vagueRules
    $taskSpecificHits = Get-RuleHits -Items $bullets -Rules $taskSpecificRules
    $skillHits = Get-RuleHits -Items $bullets -Rules $skillRules
    $repoHits = Get-RuleHits -Items $bullets -Rules $repoRules
    $duplicationGroups = Get-DuplicationGroups -Items $bullets
    $conflictRisks = Get-ConflictRisks -Content $content

    $tokenEfficiency = 20
    if ($nonEmptyLines.Count -gt 120) {
        $tokenEfficiency -= [Math]::Min(8, [Math]::Ceiling(($nonEmptyLines.Count - 120) / 10))
    } elseif ($nonEmptyLines.Count -gt 80) {
        $tokenEfficiency -= 3
    }
    if ($charCount -gt 12000) {
        $tokenEfficiency -= 6
    } elseif ($charCount -gt 8000) {
        $tokenEfficiency -= 3
    }
    if ($longLines.Count -gt 0) {
        $tokenEfficiency -= [Math]::Min(4, $longLines.Count)
    }
    if ($japaneseCharRatio -gt 30) {
        $tokenEfficiency -= 4
    } elseif ($japaneseCharRatio -gt 10) {
        $tokenEfficiency -= 2
    }
    if ($duplicationGroups.Count -gt 0) {
        $tokenEfficiency -= [Math]::Min(3, $duplicationGroups.Count)
    }

    $clarity = 15
    $clarity -= [Math]::Min(5, $vagueHits.Count * 2)
    if ($longLines.Count -gt 0) {
        $clarity -= [Math]::Min(3, $longLines.Count)
    }

    $actionability = 15
    if ($bullets.Count -eq 0) {
        $actionability -= 8
    } else {
        $actionRatio = $actionWords.Count / $bullets.Count
        if ($actionRatio -lt 0.5) {
            $actionability -= 5
        } elseif ($actionRatio -lt 0.7) {
            $actionability -= 2
        }
    }
    $actionability -= [Math]::Min(3, $vagueHits.Count)

    $globalRelevance = 20
    $globalRelevance -= [Math]::Min(8, $taskSpecificHits.Count * 3)
    $globalRelevance -= [Math]::Min(6, $repoHits.Count * 2)
    if ($sections.Count -gt 10) {
        $globalRelevance -= 2
    }

    $duplication = 10 - [Math]::Min(6, $duplicationGroups.Count * 2)
    $conflictRisk = 10 - [Math]::Min(8, $conflictRisks.Count * 4)
    $separationFitness = 10
    $separationFitness -= [Math]::Min(5, $skillHits.Count * 2)
    $separationFitness -= [Math]::Min(4, $repoHits.Count)

    $scores = [ordered]@{
        "Token Efficiency" = [Math]::Max(0, $tokenEfficiency)
        "Clarity" = [Math]::Max(0, $clarity)
        "Actionability" = [Math]::Max(0, $actionability)
        "Global Relevance" = [Math]::Max(0, $globalRelevance)
        "Duplication" = [Math]::Max(0, $duplication)
        "Conflict Risk" = [Math]::Max(0, $conflictRisk)
        "Separation Fitness" = [Math]::Max(0, $separationFitness)
    }

    $overall = 0
    foreach ($value in $scores.Values) {
        $overall += $value
    }

    $warnings = New-StringList
    if ($nonEmptyLines.Count -gt 120) {
        $warnings.Add("Global AGENTS.md is longer than 120 non-empty lines.")
    }
    if ($bullets.Count -gt 60) {
        $warnings.Add("Global AGENTS.md has more than 60 bullet items.")
    }
    if ($vagueHits.Count -ge 3) {
        $warnings.Add("$($vagueHits.Count) rule(s) use vague wording.")
    } elseif ($vagueHits.Count -gt 0) {
        $warnings.Add("$($vagueHits.Count) vague wording candidate(s) found.")
    }
    if ($taskSpecificHits.Count -gt 0) {
        $warnings.Add("$($taskSpecificHits.Count) rule(s) may be too task-specific for global AGENTS.md.")
    }
    if ($skillHits.Count -gt 1) {
        $warnings.Add("$($skillHits.Count) rule(s) may be better as Skills.")
    }
    if ($repoHits.Count -gt 1) {
        $warnings.Add("$($repoHits.Count) rule(s) may be better in repo AGENTS.md.")
    }
    if ($conflictRisks.Count -gt 0) {
        $warnings.Add("$($conflictRisks.Count) conflict risk(s) found.")
    }
    if ($duplicationGroups.Count -gt 0) {
        $warnings.Add("$($duplicationGroups.Count) possible duplicate rule group(s) found.")
    }

    $keep = New-StringList
    $moveRepo = New-StringList
    $moveSkill = New-StringList
    $merge = New-StringList
    $rewrite = New-StringList
    $remove = New-StringList

    foreach ($item in $bullets) {
        if ($item -match '(?i)\b(language|Japanese|English|technical identifiers|secret|token|password|destructive|small|focused|diff|assumption|validation)\b') {
            Add-Unique -List $keep -Value $item
        }
    }
    foreach ($hit in $repoHits) {
        Add-Unique -List $moveRepo -Value $hit.Text
    }
    foreach ($hit in $skillHits) {
        Add-Unique -List $moveSkill -Value $hit.Text
    }
    foreach ($hit in $vagueHits) {
        Add-Unique -List $rewrite -Value $hit.Text
    }
    foreach ($group in $duplicationGroups) {
        Add-Unique -List $merge -Value "$($group.Name): $($group.Count) similar rule(s)"
    }
    if ($duplicationGroups.Count -gt 0) {
        Add-Unique -List $remove -Value "Duplicated background or repeated rule wording after merge review."
    }

    return [pscustomobject]@{
        Path = $TargetPath
        Overall = [int]$overall
        QualityGate = Get-QualityGate -Score $overall
        Scores = $scores
        Metrics = [pscustomobject]@{
            NonEmptyLines = $nonEmptyLines.Count
            Characters = $charCount
            JapaneseCharacterRatio = $japaneseCharRatio
            Sections = $sections.Count
            BulletItems = $bullets.Count
            LongLines = $longLines.Count
            ActionableBulletItems = $actionWords.Count
        }
        Warnings = @($warnings)
        VagueHits = @($vagueHits)
        TaskSpecificHits = @($taskSpecificHits)
        SkillHits = @($skillHits)
        RepoHits = @($repoHits)
        DuplicationGroups = @($duplicationGroups)
        ConflictRisks = @($conflictRisks)
        Classification = [pscustomobject]@{
            Keep = @($keep)
            MoveToRepoAgents = @($moveRepo)
            MoveToSkill = @($moveSkill)
            MergeWithSimilarRule = @($merge)
            RewriteForClarity = @($rewrite)
            Remove = @($remove)
        }
    }
}

function Write-ListSection {
    param(
        [string]$Title,
        [string[]]$Items,
        [int]$Limit = 8
    )

    Write-Host ""
    Write-Host "### $Title"
    if ($Items.Count -eq 0) {
        Write-Host "- none"
        return
    }

    foreach ($item in @($Items | Select-Object -First $Limit)) {
        Write-Host "- $item"
    }

    if ($Items.Count -gt $Limit) {
        Write-Host "- ... $($Items.Count - $Limit) more"
    }
}

function Write-Evaluation {
    param([object]$Evaluation)

    Write-Host "## AGENTS Example Harness Score"
    Write-Host ""
    Write-Host "- Path: $($Evaluation.Path)"
    Write-Host "- Overall: $($Evaluation.Overall) / 100"
    Write-Host "- Quality Gate: $($Evaluation.QualityGate)"
    Write-Host "- Non-empty lines: $($Evaluation.Metrics.NonEmptyLines)"
    Write-Host "- Characters: $($Evaluation.Metrics.Characters)"
    Write-Host "- Japanese character ratio: $($Evaluation.Metrics.JapaneseCharacterRatio)%"
    Write-Host "- Sections: $($Evaluation.Metrics.Sections)"
    Write-Host "- Bullet items: $($Evaluation.Metrics.BulletItems)"
    Write-Host "- Actionable bullet items: $($Evaluation.Metrics.ActionableBulletItems)"
    Write-Host "- Lines over 140 characters: $($Evaluation.Metrics.LongLines)"

    Write-Host ""
    Write-Host "### Breakdown"
    foreach ($key in $Evaluation.Scores.Keys) {
        $max = switch ($key) {
            "Token Efficiency" { 20 }
            "Clarity" { 15 }
            "Actionability" { 15 }
            "Global Relevance" { 20 }
            "Duplication" { 10 }
            "Conflict Risk" { 10 }
            "Separation Fitness" { 10 }
        }
        Write-Host "- ${key}: $($Evaluation.Scores[$key]) / $max"
    }

    Write-ListSection -Title "Warnings" -Items $Evaluation.Warnings

    $recommendations = New-StringList
    if ($Evaluation.TaskSpecificHits.Count -gt 0) {
        $recommendations.Add("Review task-specific rules and move them to repo AGENTS.md or a Skill.")
    }
    if ($Evaluation.SkillHits.Count -gt 0) {
        $recommendations.Add("Extract detailed workflows into dedicated Skills.")
    }
    if ($Evaluation.RepoHits.Count -gt 0) {
        $recommendations.Add("Move repository-specific directory and project rules to repo AGENTS.md.")
    }
    if ($Evaluation.DuplicationGroups.Count -gt 0) {
        $recommendations.Add("Merge similar rules so important instructions stay visible.")
    }
    if ($Evaluation.VagueHits.Count -gt 0) {
        $recommendations.Add("Rewrite vague quality wording into concrete Do / Do not / Prefer / When rules.")
    }
    if ($recommendations.Count -eq 0) {
        $recommendations.Add("No structural recommendation from rule-based checks.")
    }
    Write-ListSection -Title "Recommendations" -Items $recommendations

    Write-Host ""
    Write-Host "### Classification"
    Write-ListSection -Title "Keep in global AGENTS.md" -Items $Evaluation.Classification.Keep -Limit 6
    Write-ListSection -Title "Move to repo AGENTS.md" -Items $Evaluation.Classification.MoveToRepoAgents -Limit 6
    Write-ListSection -Title "Move to Skill" -Items $Evaluation.Classification.MoveToSkill -Limit 6
    Write-ListSection -Title "Merge with similar rule" -Items $Evaluation.Classification.MergeWithSimilarRule -Limit 6
    Write-ListSection -Title "Rewrite for clarity" -Items $Evaluation.Classification.RewriteForClarity -Limit 6
    Write-ListSection -Title "Remove" -Items $Evaluation.Classification.Remove -Limit 6
}

function Write-DiffEvaluation {
    param(
        [object]$Before,
        [object]$After
    )

    Write-Host "## AGENTS Example Diff Evaluation"
    Write-Host ""
    Write-Host "- Before: $($Before.Overall) / 100 ($($Before.QualityGate))"
    Write-Host "- After: $($After.Overall) / 100 ($($After.QualityGate))"
    Write-Host "- Score changed: $($After.Overall - $Before.Overall)"

    Write-Host ""
    Write-Host "### Breakdown Change"
    foreach ($key in $After.Scores.Keys) {
        $change = $After.Scores[$key] - $Before.Scores[$key]
        Write-Host "- ${key}: $change"
    }

    $reasons = New-StringList
    $lineDelta = $After.Metrics.NonEmptyLines - $Before.Metrics.NonEmptyLines
    $charDelta = $After.Metrics.Characters - $Before.Metrics.Characters
    $vagueDelta = $After.VagueHits.Count - $Before.VagueHits.Count
    $taskDelta = $After.TaskSpecificHits.Count - $Before.TaskSpecificHits.Count
    $skillDelta = $After.SkillHits.Count - $Before.SkillHits.Count
    $repoDelta = $After.RepoHits.Count - $Before.RepoHits.Count
    $conflictDelta = $After.ConflictRisks.Count - $Before.ConflictRisks.Count

    if ($lineDelta -ne 0) {
        $reasons.Add("Non-empty line count changed by $lineDelta.")
    }
    if ($charDelta -ne 0) {
        $reasons.Add("Character count changed by $charDelta.")
    }
    if ($vagueDelta -ne 0) {
        $reasons.Add("Vague wording candidates changed by $vagueDelta.")
    }
    if ($taskDelta -ne 0) {
        $reasons.Add("Task-specific rule candidates changed by $taskDelta.")
    }
    if ($skillDelta -ne 0) {
        $reasons.Add("Skill extraction candidates changed by $skillDelta.")
    }
    if ($repoDelta -ne 0) {
        $reasons.Add("Repo AGENTS.md candidates changed by $repoDelta.")
    }
    if ($conflictDelta -ne 0) {
        $reasons.Add("Conflict risks changed by $conflictDelta.")
    }
    if ($reasons.Count -eq 0) {
        $reasons.Add("No rule-based reason changed, but category weighting may have shifted.")
    }

    Write-ListSection -Title "Reasons" -Items $reasons
}

if ($BeforePath -or $AfterPath) {
    if (-not $BeforePath -or -not $AfterPath) {
        throw "Use both -BeforePath and -AfterPath for diff-based evaluation."
    }

    $beforeEvaluation = Get-AgentsEvaluation -TargetPath $BeforePath
    $afterEvaluation = Get-AgentsEvaluation -TargetPath $AfterPath
    Write-DiffEvaluation -Before $beforeEvaluation -After $afterEvaluation
} else {
    $evaluation = Get-AgentsEvaluation -TargetPath $Path
    Write-Evaluation -Evaluation $evaluation
}
