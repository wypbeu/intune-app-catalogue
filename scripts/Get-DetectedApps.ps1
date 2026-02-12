<#
.SYNOPSIS
    Fetches detected (discovered) applications from the Intune Graph API.

.DESCRIPTION
    Queries the deviceManagement/detectedApps endpoint to retrieve all applications
    discovered across managed devices. Handles pagination automatically.

.PARAMETER Config
    Configuration hashtable containing tenantId, clientId, clientSecret, and graphBaseUrl.

.OUTPUTS
    Array of detected application objects with deviceCount and platform information.
#>

function Get-DetectedApps {
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

    $uri = "$($Config.graphBaseUrl)/deviceManagement/detectedApps?`$top=100"
    $allApps = @()

    Write-Host "Fetching detected apps from Graph API..." -ForegroundColor Cyan

    do {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $allApps += $response.value

        # Handle pagination
        $uri = $response.'@odata.nextLink'

        if ($uri) {
            Write-Verbose "Fetching next page... ($($allApps.Count) apps so far)"
        }
    } while ($uri)

    Write-Host "Retrieved $($allApps.Count) detected apps" -ForegroundColor Green

    # Normalize the output
    $allApps | ForEach-Object {
        [PSCustomObject]@{
            Id              = $_.id
            DisplayName     = $_.displayName
            Version         = $_.version
            Platform        = $_.platform
            DeviceCount     = $_.deviceCount
            Publisher       = $_.publisher
            Source           = "Detected"
            LastSyncDate    = (Get-Date -Format "yyyy-MM-dd")
        }
    }
}

function Get-GraphToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $body = @{
        grant_type    = "client_credentials"
        client_id     = $Config.clientId
        client_secret = $Config.clientSecret
        scope         = "https://graph.microsoft.com/.default"
    }

    $tokenResponse = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$($Config.tenantId)/oauth2/v2.0/token" `
        -Method Post `
        -Body $body `
        -ContentType "application/x-www-form-urlencoded"

    return $tokenResponse.access_token
}
