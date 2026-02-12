# Setup Guide

This guide walks through setting up the application catalogue pipeline from scratch.

## 1. Azure AD App Registration

1. Go to [Azure Portal](https://portal.azure.com) > **Azure Active Directory** > **App registrations** > **New registration**
2. Name: `Intune App Catalogue Pipeline`
3. Supported account types: **Single tenant**
4. No redirect URI needed
5. After creation, note the **Application (client) ID** and **Directory (tenant) ID**

### Client Secret

1. Go to **Certificates & secrets** > **New client secret**
2. Description: `App Catalogue Pipeline`
3. Expiry: 24 months (set a calendar reminder to rotate)
4. Copy the secret value immediately — it won't be shown again

### API Permissions

1. Go to **API permissions** > **Add a permission** > **Microsoft Graph** > **Application permissions**
2. Add these permissions:
   - `DeviceManagementApps.Read.All` — read managed and detected apps
   - `DeviceManagementManagedDevices.Read.All` — read device information
   - `Sites.ReadWrite.All` — read/write SharePoint lists (for the catalogue)
3. Click **Grant admin consent**

See `graph-permissions.md` for detailed permission explanations.

## 2. SharePoint Catalogue List

1. Create a new SharePoint site or use an existing one (e.g., "IT Operations")
2. Create a new list called **Application Catalogue**
3. Add columns matching `sharepoint/list-schema.json`:
   - Title (text, built-in) — Application name
   - Publisher (text)
   - Version (text)
   - Classification (choice: Managed, Orphaned, Unowned, MSIX Candidate, Retirement)
   - DeviceCount (number)
   - PackagingFormat (choice: Win32, MSIX, Store, MSI, WinGet, UWP, Unknown)
   - MSIXReadiness (number, 1-5)
   - ClassificationReason (multiline text)
   - Owner (person)
   - BusinessJustification (multiline text)
   - LifecycleStatus (choice: Active, Under Review, Deprecated, Retired)
   - LastSyncDate (date/time)
   - MatchedManagedApp (text)
   - Notes (multiline text)

4. Create the views defined in `list-schema.json` (Orphaned Apps, MSIX Candidates, etc.)
5. Note the **Site ID** — you can find it via Graph Explorer: `GET https://graph.microsoft.com/v1.0/sites/{hostname}:/{site-path}`

## 3. AI Service

Any model that supports structured JSON output via a chat completions API will work. The pipeline uses the OpenAI-compatible request format, which most providers support natively or via compatible endpoints.

### Option A: OpenAI

1. Create an account at [platform.openai.com](https://platform.openai.com)
2. Generate an API key
3. Use endpoint: `https://api.openai.com/v1/chat/completions`
4. Recommended model: `gpt-4o` (good balance of cost and quality for classification)

### Option B: Azure OpenAI

1. Create an Azure OpenAI resource in Azure Portal
2. Deploy a `gpt-4o` model
3. Use endpoint: `https://{resource-name}.openai.azure.com/openai/deployments/{deployment-name}/chat/completions?api-version=2024-02-01`
4. Use the Azure OpenAI API key

### Option C: Google Gemini

1. Get an API key from [Google AI Studio](https://aistudio.google.com/)
2. Use endpoint: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
3. Recommended model: `gemini-2.0-flash`
4. Gemini's OpenAI-compatible endpoint accepts the same request format — no script changes needed

### Option D: Local model (Ollama)

1. Install [Ollama](https://ollama.com) and pull a model (e.g., `ollama pull llama3`)
2. Use endpoint: `http://localhost:11434/v1/chat/completions`
3. No API key required — leave the field empty or set to `ollama`
4. Best for testing or air-gapped environments; classification quality depends on model size

### Option E: Anthropic Claude

Claude uses a different API format, so the HTTP call in `Invoke-AppClassification.ps1` needs adjusting (request body structure and auth header differ). The prompts and output schema are the same — only the transport layer changes. See [Anthropic's API docs](https://docs.anthropic.com/en/api/messages) for the message format.

## 4. Configuration

### PowerShell Path

```bash
cd scripts
cp config.example.json config.json
```

Edit `config.json` with your values:
- `tenantId`, `clientId`, `clientSecret` from Step 1
- `sharepoint.siteId` from Step 2
- `ai.apiKey` and `ai.endpoint` from Step 3

### Power Automate Path

See `power-automate/README.md` for flow import and variable configuration.

## 5. First Run

```powershell
cd scripts
.\Run-Pipeline.ps1
```

**What to expect on the first run:**
- The Graph API calls may take a few minutes for large estates (1000+ apps)
- AI classification will process in batches — expect 2-5 minutes depending on estate size
- The SharePoint list will be populated with all entries as "new"
- Review the classification results — the AI will misclassify some apps on the first pass

**Tuning after the first run:**
- Review apps classified as "orphaned" — some may be legitimate dependencies
- Check "MSIX candidates" — verify the readiness scores make sense
- Update the few-shot examples in `prompts/few-shot-examples.json` with corrections from your review
- Re-run to see improved classification accuracy

## 6. Scheduling

### PowerShell (Task Scheduler)

Create a scheduled task to run `Run-Pipeline.ps1` daily:

```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File C:\path\to\scripts\Run-Pipeline.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
Register-ScheduledTask -TaskName "App Catalogue Sync" -Action $action -Trigger $trigger -RunLevel Highest
```

### PowerShell (Azure Automation)

Upload the scripts as an Azure Automation runbook for a fully cloud-hosted solution.

### Power Automate

The flow includes a built-in daily recurrence trigger — no additional scheduling needed.
