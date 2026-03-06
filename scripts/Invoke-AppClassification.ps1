<#
.SYNOPSIS
    Classifies applications using AI by comparing detected vs managed app inventories.

.DESCRIPTION
    Takes normalized detected and managed app datasets, sends them to an AI model
    (OpenAI or Azure OpenAI) for classification, and returns structured results.

    Classification categories:
    - Managed: detected app matches a managed deployment
    - Orphaned: installed across estate but not managed via Intune
    - Unowned: in Intune but no owner assigned
    - MSIX Candidate: Win32 package suitable for MSIX conversion
    - Retirement: EOL, superseded, or zero/near-zero usage

.PARAMETER DetectedApps
    Array of detected application objects from Get-DetectedApps.

.PARAMETER ManagedApps
    Array of managed application objects from Get-ManagedApps.

.PARAMETER Config
    Configuration hashtable containing AI provider settings.
#>

function Invoke-AppClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DetectedApps,

        [Parameter(Mandatory)]
        [array]$ManagedApps,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Load the system prompt and few-shot examples
    $promptsDir = Join-Path $PSScriptRoot ".." "prompts"
    $systemPrompt = Get-Content (Join-Path $promptsDir "system-prompt.md") -Raw
    $fewShotExamples = Get-Content (Join-Path $promptsDir "few-shot-examples.json") -Raw | ConvertFrom-Json
    $schema = Get-Content (Join-Path $promptsDir "classification-schema.json") -Raw

    $batchSize = $Config.options.batchSize
    $allResults = @()

    # Process in batches to stay within token limits
    $batches = [System.Collections.ArrayList]@()
    for ($i = 0; $i -lt $DetectedApps.Count; $i += $batchSize) {
        $batch = $DetectedApps[$i..([Math]::Min($i + $batchSize - 1, $DetectedApps.Count - 1))]
        [void]$batches.Add($batch)
    }

    Write-Host "Classifying $($DetectedApps.Count) apps in $($batches.Count) batches..." -ForegroundColor Cyan

    $batchNum = 0
    foreach ($batch in $batches) {
        $batchNum++
        Write-Host "  Processing batch $batchNum of $($batches.Count)..." -ForegroundColor Gray

        # Build the user message with the batch data
        $userMessage = @"
## Managed Apps (reference: what we intentionally deploy)
``````json
$($ManagedApps | Select-Object DisplayName, Version, Publisher, PackagingFormat | ConvertTo-Json -Depth 3)
``````

## Detected Apps (this batch: classify each one)
``````json
$($batch | Select-Object DisplayName, Version, Publisher, DeviceCount | ConvertTo-Json -Depth 3)
``````

Classify each detected app. Return JSON matching the provided schema.
"@

        # Build the API request
        $messages = @(
            @{ role = "system"; content = $systemPrompt }
        )

        # Add few-shot examples
        foreach ($example in $fewShotExamples) {
            $messages += @{ role = "user"; content = $example.input }
            $messages += @{ role = "assistant"; content = ($example.output | ConvertTo-Json -Depth 5) }
        }

        # Add the actual request
        $messages += @{ role = "user"; content = $userMessage }

        $body = @{
            model       = $Config.ai.model
            messages    = $messages
            temperature = 0.1
            response_format = @{
                type = "json_schema"
                json_schema = @{
                    name   = "app_classification"
                    schema = ($schema | ConvertFrom-Json)
                }
            }
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Authorization" = "Bearer $($Config.ai.apiKey)"
            "Content-Type"  = "application/json"
        }

        $retries = 0
        $maxRetries = $Config.options.maxRetries

        while ($retries -le $maxRetries) {
            try {
                $response = Invoke-RestMethod `
                    -Uri $Config.ai.endpoint `
                    -Method Post `
                    -Headers $headers `
                    -Body $body

                $content = $response.choices[0].message.content | ConvertFrom-Json
                $allResults += $content.classifications
                break
            }
            catch {
                $retries++
                if ($retries -gt $maxRetries) {
                    Write-Warning "Failed to classify batch $batchNum after $maxRetries retries: $_"
                    break
                }
                Write-Warning "Retry $retries/$maxRetries for batch $batchNum..."
                Start-Sleep -Seconds (2 * $retries)
            }
        }
    }

    Write-Host "Classification complete: $($allResults.Count) apps classified" -ForegroundColor Green

    # Summary
    $summary = $allResults | Group-Object -Property classification | Sort-Object Count -Descending
    foreach ($group in $summary) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Yellow
    }

    return $allResults
}
