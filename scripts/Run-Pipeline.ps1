<#
.SYNOPSIS
    Orchestrates the full application catalogue pipeline.

.DESCRIPTION
    Runs the complete pipeline: fetch detected apps, fetch managed apps,
    classify with AI, and update the SharePoint catalogue.

.PARAMETER ConfigPath
    Path to the configuration JSON file. Defaults to ./config.json.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.json")
)

# Import functions
. (Join-Path $PSScriptRoot "Get-DetectedApps.ps1")
. (Join-Path $PSScriptRoot "Get-ManagedApps.ps1")
. (Join-Path $PSScriptRoot "Invoke-AppClassification.ps1")
. (Join-Path $PSScriptRoot "Update-Catalogue.ps1")

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found at $ConfigPath. Copy config.example.json to config.json and fill in your settings."
    exit 1
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
Write-Host "=== Application Catalogue Pipeline ===" -ForegroundColor Cyan
Write-Host "Tenant: $($config.tenantId)" -ForegroundColor Gray
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Step 1: Fetch detected apps
    Write-Host "--- Step 1/4: Fetching detected apps ---" -ForegroundColor White
    $detectedApps = Get-DetectedApps -Config $config
    Write-Host ""

    # Step 2: Fetch managed apps
    Write-Host "--- Step 2/4: Fetching managed apps ---" -ForegroundColor White
    $managedApps = Get-ManagedApps -Config $config
    Write-Host ""

    # Step 3: AI classification
    Write-Host "--- Step 3/4: Running AI classification ---" -ForegroundColor White
    $classifications = Invoke-AppClassification `
        -DetectedApps $detectedApps `
        -ManagedApps $managedApps `
        -Config $config
    Write-Host ""

    # Step 4: Update SharePoint catalogue
    Write-Host "--- Step 4/4: Updating SharePoint catalogue ---" -ForegroundColor White
    Update-Catalogue -Classifications $classifications -Config $config
    Write-Host ""

    $stopwatch.Stop()
    Write-Host "=== Pipeline complete in $($stopwatch.Elapsed.TotalSeconds.ToString('F1'))s ===" -ForegroundColor Green
}
catch {
    $stopwatch.Stop()
    Write-Error "Pipeline failed after $($stopwatch.Elapsed.TotalSeconds.ToString('F1'))s: $_"
    exit 1
}
