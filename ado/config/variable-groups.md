# Variable Groups Documentation

> Reference for all ADO variable groups used by the SSDLC pipelines.

## Variable Group: `ssdlc-shared`

Non-secret shared variables used across all pipelines.

| Variable | Value | Description |
|----------|-------|-------------|
| `DEPLOY_REGION` | `australiaeast` | Azure deployment region |
| `DOTNET_VERSION` | `8.0.x` | .NET SDK version |
| `PYTHON_VERSION_GENERAL` | `3.12` | Python version for general apps |
| `PYTHON_VERSION_AI` | `3.11` | Python version for AI Agent |
| `TEAMS_WEBHOOK_URL` | *(optional)* | Teams incoming webhook URL |

## Variable Group: `ssdlc-dev`

Dev/Staging environment variables. **Link to Azure Key Vault recommended.**

| Variable | Secret? | Description |
|----------|---------|-------------|
| `ACR_NAME` | No | Azure Container Registry name (e.g., `acrssdlcdemo`) |
| `FOUNDRY_PROJECT_ENDPOINT` | Yes | Azure AI Foundry project endpoint |
| `FOUNDRY_MODEL_NAME` | No | Default model name (e.g., `gpt-4o`) |
| `APPINSIGHTS_CONNECTION_STRING` | Yes | Application Insights connection string |

## Variable Group: `ssdlc-prod`

Production environment variables. **Must be linked to Azure Key Vault.**

| Variable | Secret? | Description |
|----------|---------|-------------|
| `ACR_NAME` | No | Production ACR name |
| `FOUNDRY_PROJECT_ENDPOINT_PROD` | Yes | Production Foundry endpoint |
| `FOUNDRY_MODEL_NAME` | No | Production model name |
| `APPINSIGHTS_CONNECTION_STRING` | Yes | Production App Insights |

## Service Connections

| Connection Name | Type | Identity | Used By |
|----------------|------|----------|---------|
| `azure-dev` | Azure Resource Manager | Workload Identity Federation | CI, CD (dev/staging), AI pipelines |
| `azure-prod` | Azure Resource Manager | Workload Identity Federation | CD (production), AI prod verification |

### Setup: Workload Identity Federation

```
Project Settings → Service Connections → New → Azure Resource Manager
  → Workload Identity Federation (automatic or manual)
  → Subscription: <your-subscription>
  → Resource Group: (leave blank for subscription scope)
  → Service Connection Name: azure-dev
  → Grant access to all pipelines: ✓
```

> **No client secret is stored.** The service connection uses federated tokens
> (ADO equivalent of GitHub OIDC `id-token: write`).

## Environments

| Environment | Approvals | Checks | Used By |
|-------------|-----------|--------|---------|
| `dev` | None (auto) | — | CD, AI P1-P4 deploy |
| `staging` | 1 approver | Business hours | CD staging, AI red team |
| `production` | 2 approvers | Business hours + exclusive lock | CD prod, AI prod verify |

### Setup: Environment Approvals

```
Project Settings → Environments → (select env) → Approvals and checks
  → Add check → Approvals
    → Approvers: [team members]
    → Minimum approvals: 1 (staging) / 2 (production)
  → Add check → Business hours
    → Time zone: (your TZ)
    → Business hours: 9 AM - 5 PM, Mon-Fri
  → Add check → Exclusive lock (production only)
```

## Branch Policies

| Policy | Configuration |
|--------|--------------|
| Minimum reviewers | 1 approver, creator vote doesn't count |
| Build validation | CI pipeline must pass |
| Work item linking | Required |
| Comment resolution | All comments must be resolved |
| Merge strategy | Squash merge (clean history) |

### Setup

```
Project Settings → Repos → Policies → Branch Policies → main
  → Require minimum reviewers: 1
  → Check for linked work items: Required
  → Check for comment resolution: Required
  → Build validation: Add → CI pipeline → Required, Expire after 12 hours
  → Limit merge types: Squash merge only
```
