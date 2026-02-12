<#
.SYNOPSIS
    Fetches managed applications from the Intune Graph API.

.DESCRIPTION
    Queries the deviceManagement/mobileApps endpoint to retrieve all applications
    that are intentionally deployed via Intune. Handles pagination and extracts
    packaging format metadata.

.PARAMETER Config
    Configuration hashtable containing tenantId, clientId, clientSecret, and graphBaseUrl.

.OUTPUTS
    Array of managed application objects with packaging format and assignment information.
#>

function Get-ManagedApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $token = Get-GraphToken -Config $Config
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $uri = "$($Config.graphBaseUrl)/deviceManagement/mobileApps?`$top=100"
    $allApps = @()

    Write-Host "Fetching managed apps from Graph API..." -ForegroundColor Cyan

    do {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $allApps += $response.value
        $uri = $response.'@odata.nextLink'

        if ($uri) {
            Write-Verbose "Fetching next page... ($($allApps.Count) apps so far)"
        }
    } while ($uri)

    Write-Host "Retrieved $($allApps.Count) managed apps" -ForegroundColor Green

    # Normalize and extract packaging format from @odata.type
    $allApps | ForEach-Object {
        $format = switch -Wildcard ($_.'@odata.type') {
            "*win32LobApp"          { "Win32" }
            "*windowsAppX"          { "MSIX" }
            "*windowsMobileMSI"     { "MSI" }
            "*microsoftStoreForBusinessApp" { "Store" }
            "*winGetApp"            { "WinGet" }
            "*windowsUniversalAppX" { "UWP" }
            default                 { "Other" }
        }

        [PSCustomObject]@{
            Id              = $_.id
            DisplayName     = $_.displayName
            Version         = $_.version ?? "N/A"
            Publisher       = $_.publisher
            PackagingFormat = $format
            ODataType       = $_.'@odata.type'
            CreatedDate     = $_.createdDateTime
            LastModified    = $_.lastModifiedDateTime
            Source          = "Managed"
            LastSyncDate    = (Get-Date -Format "yyyy-MM-dd")
        }
    }
}
