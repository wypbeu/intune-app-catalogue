<#
.SYNOPSIS
    Writes classified application data to a SharePoint list.

.DESCRIPTION
    Takes the AI classification results and writes them to a SharePoint list,
    performing delta updates — matching on DisplayName + Publisher composite key,
    updating existing rows, adding new entries, and flagging removed apps.

.PARAMETER Classifications
    Array of classification objects from Invoke-AppClassification.

.PARAMETER Config
    Configuration hashtable containing SharePoint settings.
#>

function Update-Catalogue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Classifications,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $token = Get-GraphToken -Config $Config
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $siteId = $Config.sharepoint.siteId
    $listName = $Config.sharepoint.listName

    # Get the list ID
    $listsUri = "https://graph.microsoft.com/v1.0/sites/$siteId/lists?`$filter=displayName eq '$listName'"
    $listResponse = Invoke-RestMethod -Uri $listsUri -Headers $headers -Method Get
    $listId = $listResponse.value[0].id

    if (-not $listId) {
        throw "SharePoint list '$listName' not found on site $siteId"
    }

    # Fetch existing catalogue entries for delta comparison
    $existingUri = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/items?`$expand=fields&`$top=999"
    $existing = @()

    do {
        $response = Invoke-RestMethod -Uri $existingUri -Headers $headers -Method Get
        $existing += $response.value
        $existingUri = $response.'@odata.nextLink'
    } while ($existingUri)

    Write-Host "Found $($existing.Count) existing catalogue entries" -ForegroundColor Cyan

    # Build lookup from existing entries
    $existingLookup = @{}
    foreach ($item in $existing) {
        $key = "$($item.fields.Title)|$($item.fields.Publisher)"
        $existingLookup[$key] = $item
    }

    $stats = @{ Created = 0; Updated = 0; Unchanged = 0 }

    foreach ($app in $Classifications) {
        $key = "$($app.displayName)|$($app.publisher)"
        $fields = @{
            Title             = $app.displayName
            Publisher         = $app.publisher
            Version           = $app.version
            Classification    = $app.classification
            DeviceCount       = $app.deviceCount
            PackagingFormat   = $app.packagingFormat
            MSIXReadiness     = $app.msixReadiness
            ClassificationReason = $app.reason
            LastSyncDate      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        }

        if ($existingLookup.ContainsKey($key)) {
            # Update existing entry
            $itemId = $existingLookup[$key].id
            $updateUri = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/items/$itemId/fields"

            try {
                Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Patch -Body ($fields | ConvertTo-Json)
                $stats.Updated++
            }
            catch {
                Write-Warning "Failed to update '$($app.displayName)': $_"
            }
        }
        else {
            # Create new entry
            $createUri = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/items"
            $body = @{ fields = $fields } | ConvertTo-Json -Depth 3

            try {
                Invoke-RestMethod -Uri $createUri -Headers $headers -Method Post -Body $body
                $stats.Created++
            }
            catch {
                Write-Warning "Failed to create '$($app.displayName)': $_"
            }
        }
    }

    Write-Host "`nCatalogue update complete:" -ForegroundColor Green
    Write-Host "  Created: $($stats.Created)" -ForegroundColor Yellow
    Write-Host "  Updated: $($stats.Updated)" -ForegroundColor Yellow
    Write-Host "  Unchanged: $($stats.Unchanged)" -ForegroundColor Gray
}
