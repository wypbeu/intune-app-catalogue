# Intune Application Catalogue — Self-Maintaining Pipeline

A self-maintaining application catalogue for Intune-managed estates. Pulls inventory from Microsoft Graph API, classifies applications with AI, and surfaces actionable outputs — orphaned software, unowned applications, MSIX migration candidates, and retirement flags.

**Companion blog post**: [Building a Self-Maintaining Application Catalogue with Graph API and AI](https://sbd.org.uk/blog/ai-app-catalogue)

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Intune Graph API                         │
│                                                              │
│   /deviceManagement/mobileApps    /deviceManagement/         │
│   (what you deploy)               detectedApps               │
│                                   (what's installed)         │
└──────────────┬───────────────────────────┬───────────────────┘
               │                           │
               ▼                           ▼
┌──────────────────────────────────────────────────────────────┐
│                  Power Automate / PowerShell                 │
│                                                              │
│   Scheduled sync  →  Normalize & deduplicate  →  AI classify │
└──────────────────────────────────┬───────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    SharePoint Catalogue                       │
│                                                              │
│   ┌─────────────┐ ┌───────────┐ ┌──────────┐ ┌───────────┐ │
│   │  Orphaned   │ │  Unowned  │ │   MSIX   │ │ Retirement│ │
│   │    apps     │ │   apps    │ │candidates│ │   flags   │ │
│   └─────────────┘ └───────────┘ └──────────┘ └───────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Two Implementation Paths

This repo provides both approaches:

- **Power Automate** (`power-automate/`) — for teams who prefer low-code, visual workflows within the Power Platform ecosystem. Import the flow template and configure your connections.

- **PowerShell** (`scripts/`) — for teams who prefer code, want CI/CD integration, or need more control over the pipeline. Run the scripts on a schedule via Task Scheduler, Azure Automation, or a pipeline.

Both paths use the same AI classification prompts (`prompts/`) and write to the same SharePoint catalogue schema (`sharepoint/`).

## Quick Start

### Prerequisites

- Microsoft 365 tenant with Intune
- Azure AD app registration with `DeviceManagementApps.Read.All` and `DeviceManagementManagedDevices.Read.All` permissions
- SharePoint site for the catalogue
- OpenAI API key or Azure OpenAI deployment (for AI classification)

### PowerShell Path

1. Copy `scripts/config.example.json` to `scripts/config.json` and fill in your tenant details
2. Run `scripts/Run-Pipeline.ps1` to execute the full pipeline
3. See `docs/setup-guide.md` for detailed instructions

### Power Automate Path

1. Import `power-automate/flow-definition.json` as a new flow
2. Configure the HTTP and SharePoint connections
3. See `power-automate/README.md` for detailed instructions

## Repository Structure

```
scripts/                    PowerShell implementation
  Get-DetectedApps.ps1      Fetch detected apps from Graph API
  Get-ManagedApps.ps1       Fetch managed apps from Graph API
  Invoke-AppClassification.ps1  Call AI API for classification
  Update-Catalogue.ps1      Write results to SharePoint list
  Run-Pipeline.ps1          Orchestrate all steps
  config.example.json       Sample configuration

power-automate/             Power Automate implementation
  flow-definition.json      Importable flow definition
  README.md                 Setup instructions

prompts/                    AI classification prompts
  system-prompt.md          System prompt for classification
  few-shot-examples.json    Structured output examples
  classification-schema.json  JSON Schema for AI output

sharepoint/                 Catalogue schema
  list-schema.json          SharePoint list column definitions

docs/                       Documentation
  setup-guide.md            Step-by-step setup guide
  graph-permissions.md      App registration & permissions
```

## Licence

MIT
