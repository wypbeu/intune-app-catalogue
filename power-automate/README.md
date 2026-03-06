# Power Automate Implementation

This directory contains a Power Automate flow that implements the application catalogue pipeline as a low-code solution.

## Prerequisites

- Power Automate Premium licence (required for HTTP connector to Graph API)
- Microsoft Entra ID app registration with Graph API permissions (see `docs/graph-permissions.md`)
- SharePoint site with the catalogue list created (see `sharepoint/list-schema.json`)
- AI provider API key (OpenAI, Azure OpenAI, Gemini, or any OpenAI-compatible endpoint)

## Importing the Flow

1. Go to [Power Automate](https://make.powerautomate.com)
2. Navigate to **My flows** > **Import** > **Import Package**
3. Upload `flow-definition.json`
4. Configure the connections:
   - **HTTP** connector: used for Graph API and AI API calls
   - **SharePoint** connector: used for reading/writing the catalogue list
   - **Teams** connector (optional): used for sending the weekly digest

## Flow Structure

The flow runs on a daily schedule (configurable) and executes these steps:

1. **Scheduled Trigger**: runs at 06:00 UTC daily
2. **Authenticate to Graph API**: using client credentials from app registration
3. **Fetch Managed Apps**: GET `/deviceManagement/mobileApps` with pagination
4. **Fetch Detected Apps**: GET `/deviceManagement/detectedApps` with pagination
5. **Normalize Data**: deduplicate, standardise names, merge datasets
6. **AI Classification**: POST to OpenAI/Azure OpenAI with the system prompt and app data
7. **Update SharePoint List**: delta sync: create new entries, update existing, flag removals
8. **Send Digest** (optional): Teams message summarising new orphans, candidates, and changes

## Configuration

After importing, update these flow variables:

| Variable | Description |
|----------|-------------|
| `TenantId` | Your Entra ID tenant ID |
| `ClientId` | App registration client ID |
| `ClientSecret` | App registration client secret (store in a Key Vault for production) |
| `SharePointSiteUrl` | URL of the SharePoint site hosting the catalogue |
| `CatalogueListName` | Name of the SharePoint list |
| `AIEndpoint` | OpenAI or Azure OpenAI chat completions endpoint |
| `AIApiKey` | API key for the AI service |

## Customisation

- **Schedule**: Edit the recurrence trigger to change frequency
- **AI Prompt**: The system prompt is embedded in the HTTP action body. For easier editing, move it to a SharePoint document library and read it dynamically
- **Notification**: Replace the Teams connector with email, Slack, or any other notification service
