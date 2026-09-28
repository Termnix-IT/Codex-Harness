function Get-HarnessProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath,
        [datetime]$Today = (Get-Date).Date
    )

    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
        throw "Model profile does not exist: $ProfilePath"
    }
    $profile = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($profile.schema_version -ne 1) {
        throw "Unsupported model profile schema_version."
    }
    if ($profile.target_model -notmatch '^gpt-[a-z0-9.-]+$') {
        throw "Model profile requires an explicit target_model identifier."
    }
    if ($profile.reasoning_effort -notin @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra')) {
        throw "Invalid reasoning_effort in model profile."
    }
    if (($profile.review_interval_days -isnot [int] -and $profile.review_interval_days -isnot [long]) -or
        $profile.review_interval_days -lt 1 -or $profile.review_interval_days -gt [int]::MaxValue) {
        throw "review_interval_days must be a positive integer."
    }
    $reviewDate = [datetime]::MinValue
    $validDate = [datetime]::TryParseExact(
        [string]$profile.reviewed_on, 'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$reviewDate
    )
    if (-not $validDate -or $reviewDate.Date -gt $Today.Date) {
        throw "reviewed_on must be a valid date that is not in the future."
    }
    $sources = @($profile.sources)
    if ($sources.Count -lt 2) {
        throw "Model profile requires model and instruction guidance sources."
    }
    $hasModelSource = $false
    foreach ($source in $sources) {
        $sourceUri = $null
        if (-not [uri]::TryCreate([string]$source.url, [System.UriKind]::Absolute, [ref]$sourceUri) -or
            $sourceUri.Scheme -ne 'https' -or
            $sourceUri.Host -notin @('developers.openai.com', 'platform.openai.com', 'learn.chatgpt.com') -or
            [string]::IsNullOrWhiteSpace([string]$source.name) -or
            [string]::IsNullOrWhiteSpace([string]$source.scope)) {
            throw "Sources must identify official HTTPS documentation and its scope."
        }
        if ($sourceUri.AbsolutePath.TrimEnd('/') -eq "/api/docs/models/$($profile.target_model)") {
            $hasModelSource = $true
        }
    }
    if (@($sources.url | Select-Object -Unique).Count -lt 2) {
        throw "Model profile requires distinct model and guidance sources."
    }
    if (-not $hasModelSource) {
        throw "Model profile requires an official model page for target_model."
    }
    $ageDays = [int]($Today.Date - $reviewDate.Date).TotalDays
    return [pscustomobject]@{
        TargetModel = $profile.target_model
        ReasoningEffort = $profile.reasoning_effort
        ReviewedOn = $profile.reviewed_on
        ReviewIntervalDays = $profile.review_interval_days
        AgeDays = $ageDays
        IsCurrent = $ageDays -lt $profile.review_interval_days
        Sources = $sources
    }
}

function Write-HarnessProfile {
    param([object]$Profile)

    $reviewStatus = if ($Profile.IsCurrent) { 'Current' } else { 'Review due' }
    Write-Host "- Target model: $($Profile.TargetModel)"
    Write-Host "- Behavior evaluation effort: $($Profile.ReasoningEffort)"
    Write-Host "- Official guidance reviewed: $($Profile.ReviewedOn) ($reviewStatus; age: $($Profile.AgeDays) days)"
    Write-Host "- Evaluation mode: static heuristics; model behavior not executed"
}
