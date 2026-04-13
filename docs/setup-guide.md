# One-Time Setup Guide: OIDC + ADO + ACR

> **This guide covers the three one-time connections required before the SSDLC demo pipeline works end-to-end.**
> 
> Environment: Subscription `MCAPS-Hybrid-REQ-137206-2025-ncheruvu`, Tenant `16b3c013-d300-468d-ac64-7eda0820b6d3`

---

## Prerequisites

| Tool | Install | Verify |
|------|---------|--------|
| Azure CLI | `winget install Microsoft.AzureCLI` | `az version` |
| GitHub CLI | `winget install GitHub.cli` | `gh auth status` |
| Azure DevOps Extension | `az extension add --name azure-devops` | `az devops -h` |
| PowerShell 7+ | `winget install Microsoft.PowerShell` | `$PSVersionTable` |

```powershell
# Login to all three
az login                                              # Azure
gh auth login                                         # GitHub
az devops configure --defaults organization=https://dev.azure.com/ncheruvu0468 project=NagaDevops
```

---

## Part 1: OIDC Federation (GitHub → Azure)

**What**: Create an Azure AD App Registration with federated identity credentials so GitHub Actions can authenticate to Azure **without any stored secrets**.

**How it works**: GitHub Actions requests a short-lived OIDC token → Azure AD validates the token against the federated credential (matching repo + environment) → Azure issues an access token → workflow deploys resources.

### 1A. Create App Registration

```powershell
# Create the app
$app = az ad app create --display-name "github-ssdlc-demo-oidc" -o json | ConvertFrom-Json
$clientId = $app.appId
$objectId = $app.id
Write-Host "Client ID: $clientId"
Write-Host "Object ID: $objectId"

# Create service principal
az ad sp create --id $clientId -o none
```

**In Azure Portal** (alternative):
1. Go to **Microsoft Entra ID** → **App registrations** → **New registration**
2. Name: `github-ssdlc-demo-oidc`
3. Supported account types: **Single tenant**
4. Click **Register**
5. Copy the **Application (client) ID**

### 1B. Add Federated Identity Credentials

Each credential maps a specific GitHub Actions context to this app:

```powershell
$repo = "ncheruvu-MSFT/az-github-ssdlc-demo"

# For each GitHub environment (dev, staging, production)
foreach ($env in @("dev", "staging", "production")) {
    $body = @{
        name        = "github-$env"
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:${repo}:environment:${env}"
        description = "GitHub Actions OIDC for $env"
        audiences   = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    $body | az ad app federated-credential create --id $objectId --parameters "@-" -o none
    Write-Host "Created: github-$env"
}

# For main branch pushes (CD trigger)
@{
    name        = "github-branch-main"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:${repo}:ref:refs/heads/main"
    description = "GitHub Actions OIDC for main branch"
    audiences   = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress | az ad app federated-credential create --id $objectId --parameters "@-" -o none

# For pull requests (CI scans)
@{
    name        = "github-pull-request"
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = "repo:${repo}:pull_request"
    description = "GitHub Actions OIDC for PRs"
    audiences   = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress | az ad app federated-credential create --id $objectId --parameters "@-" -o none
```

**In Azure Portal** (alternative):
1. Open the App Registration → **Certificates & secrets** → **Federated credentials** → **Add credential**
2. Select **GitHub Actions deploying Azure resources**
3. Fill in: Organization = `ncheruvu-MSFT`, Repository = `az-github-ssdlc-demo`
4. Entity type = **Environment**, Value = `dev` → click **Add**
5. Repeat for `staging`, `production`, plus `Branch: main` and `Pull request`

### 1C. Assign RBAC Roles

```powershell
$subId = az account show --query id -o tsv

# Contributor — deploy resources
az role assignment create --assignee $clientId --role Contributor --scope "/subscriptions/$subId" -o none

# User Access Administrator — assign managed identity roles during Bicep deploy
az role assignment create --assignee $clientId --role "User Access Administrator" --scope "/subscriptions/$subId" -o none
```

**In Azure Portal**:
1. Go to **Subscriptions** → Select subscription → **Access control (IAM)** → **Add role assignment**
2. Role: **Contributor** → Members: Select `github-ssdlc-demo-oidc` → **Review + assign**
3. Repeat for **User Access Administrator**

### 1D. Set GitHub Repository Secrets

```powershell
$tenantId = az account show --query tenantId -o tsv
$subId = az account show --query id -o tsv

gh secret set AZURE_CLIENT_ID        --body $clientId  --repo ncheruvu-MSFT/az-github-ssdlc-demo
gh secret set AZURE_TENANT_ID        --body $tenantId  --repo ncheruvu-MSFT/az-github-ssdlc-demo
gh secret set AZURE_SUBSCRIPTION_ID  --body $subId     --repo ncheruvu-MSFT/az-github-ssdlc-demo
gh secret set ACR_NAME               --body "acrssdlcdemo" --repo ncheruvu-MSFT/az-github-ssdlc-demo
```

**In GitHub UI**:
1. Go to `https://github.com/ncheruvu-MSFT/az-github-ssdlc-demo/settings/secrets/actions`
2. Click **New repository secret** for each:
   - `AZURE_CLIENT_ID` = *(App Registration Client ID)*
   - `AZURE_TENANT_ID` = `16b3c013-d300-468d-ac64-7eda0820b6d3`
   - `AZURE_SUBSCRIPTION_ID` = `64e1939f-6460-4656-ad75-dcc277b155f1`
   - `ACR_NAME` = `acrssdlcdemo`

### 1E. Verify OIDC

```powershell
# List federated credentials
az ad app federated-credential list --id $objectId -o table

# List GitHub secrets
gh secret list --repo ncheruvu-MSFT/az-github-ssdlc-demo

# List role assignments
az role assignment list --assignee $clientId -o table
```

### Automated Option

All of Part 1 is scripted:
```powershell
.\scripts\setup-github-azure-oidc.ps1
```

---

## Part 2: ADO Boards ↔ GitHub Connection

**What**: Connect Azure DevOps Boards to the GitHub repo so `AB#<id>` references in commits and PRs create automatic bidirectional links.

### 2A. Install the Azure Boards App on GitHub

1. Go to: **https://github.com/marketplace/azure-boards**
2. Click **Set up a plan** → Select **Free**
3. Choose **Only select repositories** → Select `az-github-ssdlc-demo`
4. Click **Install & Authorize**
5. When prompted, sign in to Azure DevOps with: `ncheruvu@microsoft.com`
6. Select organization: `ncheruvu0468` → Project: `NagaDevops`
7. Click **Continue** → **Authorize**

### 2B. Connect from ADO Project Settings (Alternative)

1. Open: `https://dev.azure.com/ncheruvu0468/NagaDevops/_settings/boards-external-integration`
2. Click **New Connection** → **GitHub**
3. Authorize with GitHub
4. Select repository: `ncheruvu-MSFT/az-github-ssdlc-demo`
5. Click **Save**

### 2C. Verify AD# Links Work

```bash
# Create a test commit with AB# reference
git commit --allow-empty -m "chore: test ADO link AB#1"
git push origin main
```

Then check in ADO:
1. Open `https://dev.azure.com/ncheruvu0468/NagaDevops/_workitems/edit/1`
2. Scroll to **Development** section → should show the GitHub commit
3. Click the commit link → opens in GitHub

### 2D. How AB# Links Work

| Where You Write `AB#1` | What Happens |
|------------------------|-------------|
| Commit message | Commit appears in ADO work item's Development section |
| PR description | PR appears in ADO work item's Development section |
| PR title | Same as PR description |
| Branch name (with PR) | Branch appears when PR is created |

**Syntax**: `AB#<work-item-id>` — e.g., `AB#1`, `AB#7`, `AB#24`

---

## Part 3: Azure Container Registry (ACR)

**What**: Create a container registry where the CD pipeline pushes container images (C# Container App + Python API). The OIDC app gets push/pull access.

### 3A. Create Resource Group + ACR

```powershell
# Resource group for shared resources
az group create --name rg-ssdlcdemo-shared --location canadacentral

# Create ACR (Basic SKU for demo, Standard/Premium for prod)
az acr create `
    --name acrssdlcdemo `
    --resource-group rg-ssdlcdemo-shared `
    --sku Basic `
    --admin-enabled false `
    --tags Environment=shared Project=ssdlcdemo ManagedBy=AzCLI
```

**In Azure Portal**:
1. Search **Container registries** → **Create**
2. Resource group: `rg-ssdlcdemo-shared`
3. Registry name: `acrssdlcdemo`
4. Location: `Canada Central`
5. SKU: **Basic**
6. Admin user: **Disabled** (we use OIDC, not admin credentials)
7. Click **Review + create** → **Create**

### 3B. Grant OIDC App Access to ACR

```powershell
# Get the OIDC app client ID
$clientId = az ad app list --display-name github-ssdlc-demo-oidc --query "[0].appId" -o tsv

# Get ACR resource ID
$acrId = az acr show --name acrssdlcdemo --query id -o tsv

# AcrPush includes both push and pull
az role assignment create --assignee $clientId --role AcrPush --scope $acrId -o none
Write-Host "Granted AcrPush to OIDC app on ACR"
```

**In Azure Portal**:
1. Open `acrssdlcdemo` → **Access control (IAM)** → **Add role assignment**
2. Role: **AcrPush**
3. Members: Select `github-ssdlc-demo-oidc`
4. **Review + assign**

### 3C. Verify ACR

```powershell
# Check ACR exists and is accessible
az acr show --name acrssdlcdemo --query "{name:name,sku:sku.name,loginServer:loginServer}" -o table

# Check role assignment
az role assignment list --scope $acrId --query "[?principalName=='github-ssdlc-demo-oidc'].{role:roleDefinitionName}" -o table

# Test login (local verification)
az acr login --name acrssdlcdemo
```

### 3D. How CD Uses ACR

The CD pipeline (`cd.yml`) builds and pushes images tagged with the commit SHA:

```
acrssdlcdemo.azurecr.io/ssdlcdemo/containerapp:<commit-sha>
acrssdlcdemo.azurecr.io/ssdlcdemo/pythonapi:<commit-sha>
```

This ensures every deployed image is traceable to the exact source code commit.

---

## Verification Checklist

Run this after completing all three parts:

```powershell
Write-Host "═══ OIDC Federation ═══" -ForegroundColor Cyan
$clientId = az ad app list --display-name github-ssdlc-demo-oidc --query "[0].appId" -o tsv
$objectId = az ad app list --display-name github-ssdlc-demo-oidc --query "[0].id" -o tsv
$credCount = az ad app federated-credential list --id $objectId --query "length(@)" -o tsv
Write-Host "  App Registration: $clientId"
Write-Host "  Federated Credentials: $credCount (expect 5)"

Write-Host "`n═══ GitHub Secrets ═══" -ForegroundColor Cyan
gh secret list --repo ncheruvu-MSFT/az-github-ssdlc-demo

Write-Host "`n═══ Azure RBAC ═══" -ForegroundColor Cyan
az role assignment list --assignee $clientId --query "[].roleDefinitionName" -o tsv

Write-Host "`n═══ ACR ═══" -ForegroundColor Cyan
az acr show --name acrssdlcdemo --query "{name:name,loginServer:loginServer,sku:sku.name}" -o table

Write-Host "`n═══ ADO Connection ═══" -ForegroundColor Cyan
Write-Host "  Manual check: https://dev.azure.com/ncheruvu0468/NagaDevops/_settings/boards-external-integration"
Write-Host "  Look for GitHub connection to ncheruvu-MSFT/az-github-ssdlc-demo"

Write-Host "`n═══ GitHub Environments ═══" -ForegroundColor Cyan
gh api repos/ncheruvu-MSFT/az-github-ssdlc-demo/environments --jq ".environments[].name" 2>$null
```

**Expected Output:**

| Check | Expected |
|-------|----------|
| App Registration | Client ID displayed |
| Federated Credentials | 5 (dev, staging, production, main, PR) |
| GitHub Secrets | AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, ACR_NAME |
| RBAC Roles | Contributor, User Access Administrator |
| ACR | acrssdlcdemo (Basic), loginServer = acrssdlcdemo.azurecr.io |
| ADO Connection | GitHub repo visible in ADO project settings |
| GitHub Environments | dev, staging, production |

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                       GITHUB (Source of Truth)                    │
│                                                                  │
│  Repo: ncheruvu-MSFT/az-github-ssdlc-demo                       │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ Secrets      │  │ Environments │  │ GitHub Actions         │  │
│  │ CLIENT_ID    │  │ dev          │  │ CI: 8 parallel checks  │  │
│  │ TENANT_ID    │  │ staging      │  │ CD: progressive deploy │  │
│  │ SUB_ID       │  │ production   │  │ Auth: OIDC token       │  │
│  │ ACR_NAME     │  │ (gated)      │  │                        │  │
│  └──────┬───────┘  └──────────────┘  └───────────┬────────────┘  │
│         │                                         │               │
│         │         OIDC Token Exchange              │               │
└─────────┼─────────────────────────────────────────┼───────────────┘
          │                                         │
          ▼                                         ▼
┌─────────────────────┐               ┌─────────────────────────────┐
│ Microsoft Entra ID  │               │ AZURE SUBSCRIPTION          │
│                     │               │                             │
│ App: github-ssdlc-  │◄─────────────│ RBAC: Contributor +         │
│   demo-oidc         │  Validates    │   User Access Admin         │
│                     │  Token        │                             │
│ Federated Creds:    │               │ ┌─────────────────────────┐ │
│  - env:dev          │               │ │ rg-ssdlcdemo-shared     │ │
│  - env:staging      │               │ │  └─ acrssdlcdemo (ACR)  │ │
│  - env:production   │               │ │     AcrPush role        │ │
│  - ref:main         │               │ ├─────────────────────────┤ │
│  - pull_request     │               │ │ rg-ssdlcdemo-{env}      │ │
│                     │               │ │  ├─ Functions            │ │
│                     │               │ │  ├─ Container Apps       │ │
│                     │               │ │  ├─ Service Bus          │ │
│                     │               │ │  ├─ Key Vault            │ │
│                     │               │ │  └─ VNet + Monitoring    │ │
│                     │               │ └─────────────────────────┘ │
└─────────────────────┘               └─────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                   AZURE DEVOPS (Work Tracking)                    │
│                                                                  │
│  Org: ncheruvu0468 / Project: NagaDevops                         │
│  ┌──────────────────┐    AB# Links    ┌───────────────────────┐  │
│  │ Boards (Basic)   │◄──────────────►│ GitHub Repo            │  │
│  │ Epic → Issue     │  Bidirectional  │ Commits, PRs           │  │
│  │   → Task         │                 │ Branch activity        │  │
│  └──────────────────┘                 └───────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Quick Run (All-in-One Script)

For those who want to run everything at once:

```powershell
# From repo root
cd c:\Git\AZ\az-github-ssdlc-demo

# Part 1: OIDC + Secrets (automated)
.\scripts\setup-github-azure-oidc.ps1

# Part 2: ADO Boards → manual step in browser
Start-Process "https://github.com/marketplace/azure-boards"

# Part 3: ACR
az group create --name rg-ssdlcdemo-shared --location canadacentral
az acr create --name acrssdlcdemo --resource-group rg-ssdlcdemo-shared --sku Basic --admin-enabled false
$clientId = az ad app list --display-name github-ssdlc-demo-oidc --query "[0].appId" -o tsv
$acrId = az acr show --name acrssdlcdemo --query id -o tsv
az role assignment create --assignee $clientId --role AcrPush --scope $acrId -o none

Write-Host "`n✅ Setup complete. ADO Boards connection is the only manual step." -ForegroundColor Green
```

---

*Last updated: April 2026*
