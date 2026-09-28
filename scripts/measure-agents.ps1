param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'AGENTSExample.md')
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "AGENTS file does not exist: $Path"
}

$content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($content)) {
    throw "AGENTS file is empty: $Path"
}
$lines = @($content -split "`r?`n")
$nonEmptyLines = @($lines | Where-Object { $_.Trim().Length -gt 0 })
$sections = @($lines | Where-Object { $_ -match '^##\s+' })
$bullets = @($lines | Where-Object { $_ -match '^\s*-\s+' })
$longLines = @($lines | Where-Object { $_.Length -gt 140 })

$charCount = $content.Length
$utf8Bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
$japaneseCharCount = ([regex]::Matches($content, '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}]')).Count
if ($charCount -gt 0) {
    $japaneseCharRatio = [Math]::Round(($japaneseCharCount / $charCount) * 100, 1)
} else {
    $japaneseCharRatio = 0
}
$lineCount = $nonEmptyLines.Count
$sectionCount = $sections.Count
$bulletCount = $bullets.Count
$longLineCount = $longLines.Count

$score = 100
$notes = New-Object System.Collections.Generic.List[string]

if ($lineCount -gt 120) {
    $score -= [Math]::Min(30, ($lineCount - 120))
    $notes.Add("Long file: more than 120 non-empty lines.")
} elseif ($lineCount -gt 80) {
    $score -= 10
    $notes.Add("Moderately long: more than 80 non-empty lines.")
}

if ($charCount -gt 12000) {
    $score -= 20
    $notes.Add("High character count: more than 12000 characters.")
} elseif ($charCount -gt 8000) {
    $score -= 10
    $notes.Add("Moderate character count: more than 8000 characters.")
}

if ($sectionCount -gt 10) {
    $score -= 10
    $notes.Add("Many sections: more than 10 second-level sections.")
}

if ($bulletCount -gt 60) {
    $score -= 15
    $notes.Add("Many bullets: more than 60 bullet items.")
} elseif ($bulletCount -gt 40) {
    $score -= 8
    $notes.Add("Moderately many bullets: more than 40 bullet items.")
}

if ($utf8Bytes -gt 32768) {
    $notes.Add("Exceeds the documented default 32 KiB combined instruction discovery budget; check project_doc_max_bytes and other loaded instructions.")
}

$coverageChecks = @(
    @{ Name = "Japanese response policy"; Pattern = "日本語|Japanese" },
    @{ Name = "Safety / destructive changes"; Pattern = "破壊的|destructive" },
    @{ Name = "Existing structure priority"; Pattern = "既存|existing" },
    @{ Name = "Small diff guidance"; Pattern = "diff|差分|小さ" },
    @{ Name = "Secrets / public repository"; Pattern = "secret|token|API key|public repository|機密" },
    @{ Name = "PowerShell / Windows"; Pattern = "PowerShell|Windows" },
    @{ Name = "Uncertainty handling"; Pattern = "不確実|推測|assumption" },
    @{ Name = "Authorization boundary"; Pattern = "authoriz|承認|確認" },
    @{ Name = "Proportionate validation"; Pattern = "validation|検証|テスト" }
)

$missingCoverage = New-Object System.Collections.Generic.List[string]

foreach ($check in $coverageChecks) {
    if ($content -notmatch $check.Pattern) {
        $score -= 5
        $missingCoverage.Add($check.Name)
    }
}

if ($score -lt 0) {
    $score = 0
}

if ($score -ge 85) {
    $status = "Good"
} elseif ($score -ge 70) {
    $status = "Needs Review"
} else {
    $status = "Needs revision"
}

Write-Host "## AGENTS Metrics"
Write-Host ""
Write-Host "- Path: $Path"
Write-Host "- Score: $score / 100"
Write-Host "- Status: $status"
Write-Host "- Non-empty lines: $lineCount"
Write-Host "- Characters: $charCount"
Write-Host "- UTF-8 bytes: $utf8Bytes"
Write-Host "- Measurement: text density proxy; no model token count or behavior evaluation"
Write-Host "- Japanese character ratio: $japaneseCharRatio%"
Write-Host "- Sections: $sectionCount"
Write-Host "- Bullet items: $bulletCount"
Write-Host "- Lines over 140 characters: $longLineCount"

if ($missingCoverage.Count -gt 0) {
    Write-Host "- Missing coverage: $($missingCoverage -join ', ')"
} else {
    Write-Host "- Missing coverage: none"
}

if ($notes.Count -gt 0) {
    Write-Host ""
    Write-Host "### Notes"
    foreach ($note in $notes) {
        Write-Host "- $note"
    }
}
