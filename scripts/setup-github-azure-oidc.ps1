#!/usr/bin/env pwsh
# =============================================================================
# GitHub → Azure OIDC Federation Setup
# Creates App Registration + Federated Credentials for GitHub Actions
# Prerequisites: az cli (logged in with Owner/Global Admin), gh cli
# =============================================================================
#Requires -Version 7.0
param(
    [string]$AppName = "github-ssdlc-demo-oidc",
    [string]$GitHubRepo = "ncheruvu-MSFT/az-github-ssdlc-demo"
)

$ErrorActionPreference = "Stop"

# ─── Load .env ──────────────────────────────────────────────────
$envFile = Join-Path $PSScriptRoot "../.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $Matches[1].Trim(); $val = $Matches[2].Trim()
            if ($key -eq 'GITHUB_REPO' -and -not $GitHubRepo) { $GitHubRepo = $val }
        }
    }
}

Write-Host "`n══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  GitHub → Azure OIDC Federation Setup" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# ─── Step 1: Verify Azure CLI auth ─────────────────────────────
Write-Host "▶ [1/6] Checking Azure authentication..." -ForegroundColor Yellow
$account = az account show -o json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "  ✗ Not logged in. Run: az login" -ForegroundColor Red; exit 1
}
$subId = $account.id
$tenantId = $account.tenantId
Write-Host "  ✓ Subscription: $($account.name) ($subId)" -ForegroundColor Green
Write-Host "  ✓ Tenant: $tenantId" -ForegroundColor Green

# ─── Step 2: Create Azure AD App Registration ──────────────────
Write-Host "`n▶ [2/6] Creating App Registration: $AppName..." -ForegroundColor Yellow

$existing = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
if ($existing) {
    Write-Host "  ℹ App already exists: $existing" -ForegroundColor DarkGray
    $clientId = $existing
} else {
    $app = az ad app create --display-name $AppName -o json 2>$null | ConvertFrom-Json
    $clientId = $app.appId
    Write-Host "  ✓ Created App: $clientId" -ForegroundColor Green
}

# Create Service Principal if it doesn't exist
$spExists = az ad sp show --id $clientId -o json 2>$null
if (-not $spExists) {
    az ad sp create --id $clientId -o none 2>$null
    Write-Host "  ✓ Created Service Principal" -ForegroundColor Green
} else {
    Write-Host "  ℹ Service Principal already exists" -ForegroundColor DarkGray
}

# ─── Step 3: Create Federated Identity Credentials ──────────────
Write-Host "`n▶ [3/6] Creating Federated Identity Credentials..." -ForegroundColor Yellow

$environments = @("dev", "staging", "production")
$objectId = az ad app show --id $clientId --query "id" -o tsv 2>$null

foreach ($env in $environments) {
    $credName = "github-$env"
    $existing = az ad app federated-credential list --id $objectId --query "[?name=='$credName'].name" -o tsv 2>$null
    if ($existing) {
        Write-Host "  ℹ Credential '$credName' already exists" -ForegroundColor DarkGray
        continue
    }

    $body = @{
        name        = $credName
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:${GitHubRepo}:environment:${env}"
        description = "GitHub Actions OIDC for $env environment"
        audiences   = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    $body | az ad app federated-credential create --id $objectId --parameters "@-" -o none 2>$null
    Write-Host "  ✓ Federated credential: $credName (environment:$env)" -ForegroundColor Green
}

# Also add credential for the main branch (for workflow_run triggers)
$branchCredName = "github-branch-main"
$existing = az ad app federated-credential list --id $objectId --query "[?name=='$branchCredName'].name" -o tsv 2>$null
if (-not $existing) {
    $body = @{
        name        = $branchCredName
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:${GitHubRepo}:ref:refs/heads/main"
        description = "GitHub Actions OIDC for main branch pushes"
        audiences   = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    $body | az ad app federated-credential create --id $objectId --parameters "@-" -o none 2>$null
    Write-Host "  ✓ Federated credential: $branchCredName (ref:main)" -ForegroundColor Green
} else {
    Write-Host "  ℹ Branch credential already exists" -ForegroundColor DarkGray
}

# Also add credential for pull requests
$prCredName = "github-pull-request"
$existing = az ad app federated-credential list --id $objectId --query "[?name=='$prCredName'].name" -o tsv 2>$null
if (-not $existing) {
    $body = @{
        name        = $prCredName
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = "repo:${GitHubRepo}:pull_request"
        description = "GitHub Actions OIDC for pull requests"
        audiences   = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    $body | az ad app federated-credential create --id $objectId --parameters "@-" -o none 2>$null
    Write-Host "  ✓ Federated credential: $prCredName (pull_request)" -ForegroundColor Green
} else {
    Write-Host "  ℹ PR credential already exists" -ForegroundColor DarkGray
}

# ─── Step 4: Assign RBAC roles on subscription ─────────────────
Write-Host "`n▶ [4/6] Assigning RBAC roles..." -ForegroundColor Yellow

$spObjectId = az ad sp show --id $clientId --query "id" -o tsv 2>$null

$roles = @("Contributor", "User Access Administrator")
foreach ($role in $roles) {
    $exists = az role assignment list --assignee $clientId --role $role --scope "/subscriptions/$subId" --query "length(@)" -o tsv 2>$null
    if ([int]$exists -gt 0) {
        Write-Host "  ℹ Role '$role' already assigned" -ForegroundColor DarkGray
    } else {
        az role assignment create --assignee $clientId --role $role --scope "/subscriptions/$subId" -o none 2>$null
        Write-Host "  ✓ Assigned: $role" -ForegroundColor Green
    }
}

# ─── Step 5: Set GitHub repo secrets ───────────────────────────
Write-Host "`n▶ [5/6] Setting GitHub repository secrets..." -ForegroundColor Yellow

gh secret set AZURE_CLIENT_ID --body $clientId --repo $GitHubRepo 2>$null
Write-Host "  ✓ AZURE_CLIENT_ID" -ForegroundColor Green

gh secret set AZURE_TENANT_ID --body $tenantId --repo $GitHubRepo 2>$null
Write-Host "  ✓ AZURE_TENANT_ID" -ForegroundColor Green

gh secret set AZURE_SUBSCRIPTION_ID --body $subId --repo $GitHubRepo 2>$null
Write-Host "  ✓ AZURE_SUBSCRIPTION_ID" -ForegroundColor Green

# ACR name (convention-based)
$acrName = "acrssdlcdemo"
gh secret set ACR_NAME --body $acrName --repo $GitHubRepo 2>$null
Write-Host "  ✓ ACR_NAME ($acrName)" -ForegroundColor Green

# ─── Step 6: Verify ────────────────────────────────────────────
Write-Host "`n▶ [6/6] Verification..." -ForegroundColor Yellow

$creds = az ad app federated-credential list --id $objectId -o json 2>$null | ConvertFrom-Json
Write-Host "  ✓ Federated credentials configured: $($creds.Count)" -ForegroundColor Green

$secrets = gh secret list --repo $GitHubRepo 2>$null
Write-Host "  ✓ GitHub secrets set:" -ForegroundColor Green
$secrets | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }

Write-Host @"

══════════════════════════════════════════════════════
  ✅ OIDC Federation Setup Complete
══════════════════════════════════════════════════════

  App Registration:    $AppName
  Client ID:           $clientId
  Tenant ID:           $tenantId
  Subscription ID:     $subId

  Federated Credentials (5):
    - github-dev          (environment:dev)
    - github-staging      (environment:staging)
    - github-production   (environment:production)
    - github-branch-main  (ref:refs/heads/main)
    - github-pull-request (pull_request)

  GitHub Secrets:
    AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, ACR_NAME

  Next Steps:
    1. Push code to main → CI runs → CD deploys to dev
    2. Create PR → OIDC auth validates → security scans run
    3. Merge → progressive deployment: dev → staging → (approve) → prod

══════════════════════════════════════════════════════
"@ -ForegroundColor Cyan
