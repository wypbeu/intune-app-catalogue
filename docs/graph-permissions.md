# Graph API Permissions

The application catalogue pipeline requires an Azure AD app registration with the following Microsoft Graph application permissions.

## Required Permissions

| Permission | Type | Purpose |
|------------|------|---------|
| `DeviceManagementApps.Read.All` | Application | Read managed apps (`/deviceManagement/mobileApps`) and detected apps (`/deviceManagement/detectedApps`) |
| `DeviceManagementManagedDevices.Read.All` | Application | Read device details for enriching app-to-device relationships |
| `Sites.ReadWrite.All` | Application | Create and update items in the SharePoint catalogue list |

All permissions require **admin consent** — a Global Administrator or Application Administrator must grant consent after adding the permissions.

## Why Application Permissions (Not Delegated)?

The pipeline runs unattended on a schedule. Application permissions allow the pipeline to authenticate using client credentials (client ID + secret) without a signed-in user. Delegated permissions would require interactive sign-in, which isn't compatible with automated execution.

## Least Privilege Considerations

- `Sites.ReadWrite.All` is broader than ideal — it grants write access to all SharePoint sites, not just the catalogue site. Microsoft does not currently offer site-scoped application permissions through the standard consent flow. If your organisation uses [Sites.Selected](https://learn.microsoft.com/en-us/graph/permissions-reference#sitesselected), you can scope the permission to the specific catalogue site.

- `DeviceManagementApps.Read.All` is read-only — the pipeline never writes to Intune, only reads inventory data.

## Graph API Endpoints Used

| Endpoint | Method | Permission | Description |
|----------|--------|------------|-------------|
| `/deviceManagement/mobileApps` | GET | DeviceManagementApps.Read.All | Managed app inventory |
| `/deviceManagement/detectedApps` | GET | DeviceManagementApps.Read.All | Discovered app inventory |
| `/deviceManagement/detectedApps/{id}/managedDevices` | GET | DeviceManagementManagedDevices.Read.All | Devices with specific detected app |
| `/sites/{siteId}/lists/{listId}/items` | GET, POST, PATCH | Sites.ReadWrite.All | SharePoint catalogue CRUD |

## Token Endpoint

```
POST https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token

grant_type=client_credentials
client_id={clientId}
client_secret={clientSecret}
scope=https://graph.microsoft.com/.default
```

## Throttling

Graph API has throttling limits. The pipeline handles these by:
- Using `$top=100` for paginated requests (staying within recommended page sizes)
- Respecting `Retry-After` headers when throttled
- Processing in sequential pages rather than parallel requests

For large estates (5000+ apps), consider using [delta queries](https://learn.microsoft.com/en-us/graph/delta-query-overview) to fetch only changes since the last sync.
