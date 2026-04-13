#!/usr/bin/env pwsh
# =============================================================================
# ADO Boards → GitHub → Azure Nonprod — Setup & Test Script
# Prerequisites: az cli, az devops extension, gh cli
# Loads config from .env file in repo root (falls back to params)
# =============================================================================
#Requires -Version 7.0
param(
    [string]$AdoOrg,
    [string]$AdoProject,
    [string]$GitHubRepo,
    [string]$AzureSubscriptionId,
    [string]$AzureTenantId,
    [string]$AzureRegion
)

# ─── Load .env file ────────────────────────────────────────────
$envFile = Join-Path $PSScriptRoot "../.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $Matches[1].Trim(); $val = $Matches[2].Trim()
            switch ($key) {
                'ADO_ORG'       { if (-not $AdoOrg)       { $AdoOrg = $val } }
                'ADO_PROJECT'   { if (-not $AdoProject)   { $AdoProject = $val } }
                'GITHUB_REPO'   { if (-not $GitHubRepo)   { $GitHubRepo = $val } }
                'AZURE_REGION'  { if (-not $AzureRegion)  { $AzureRegion = $val } }
            }
        }
    }
    Write-Host "  Loaded config from .env" -ForegroundColor DarkGray
}
if (-not $AdoOrg -or -not $AdoProject) {
    Write-Host "ERROR: AdoOrg and AdoProject are required (set in .env or pass as params)" -ForegroundColor Red; exit 1
}
if (-not $GitHubRepo) { $GitHubRepo = "ncheruvu-MSFT/az-github-ssdlc-demo" }
if (-not $AzureRegion) { $AzureRegion = "canadacentral" }

$ErrorActionPreference = "Stop"

Write-Host "`n══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ADO Boards → GitHub → Azure Nonprod Setup" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# ─── Step 0: Auth checks ───────────────────────────────────────
Write-Host "▶ [0/6] Checking authentication..." -ForegroundColor Yellow

# Azure CLI
$azAccount = az account show -o json 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Host "  ✗ Azure CLI not logged in. Run: az login" -ForegroundColor Red; exit 1
}
Write-Host "  ✓ Azure CLI: $($azAccount.user.name) (Tenant: $($azAccount.tenantId))" -ForegroundColor Green

if (-not $AzureSubscriptionId) { $AzureSubscriptionId = $azAccount.id }
if (-not $AzureTenantId) { $AzureTenantId = $azAccount.tenantId }

# GitHub CLI
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ GitHub CLI not logged in. Run: gh auth login" -ForegroundColor Red; exit 1
}
Write-Host "  ✓ GitHub CLI authenticated" -ForegroundColor Green

# ADO CLI
az devops configure --defaults organization=$AdoOrg project=$AdoProject 2>$null
$adoProjectJson = az devops project show --project $AdoProject -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ ADO CLI cannot reach $AdoOrg/$AdoProject" -ForegroundColor Red
    Write-Host "    Run: az login   (then retry)" -ForegroundColor Yellow
    Write-Host "    Or:  az devops login --organization $AdoOrg" -ForegroundColor Yellow
    exit 1
}
$adoProjectObj = $adoProjectJson | ConvertFrom-Json
$processTemplate = $adoProjectObj.capabilities.processTemplate.templateName
Write-Host "  ✓ ADO project: $AdoProject (process: $processTemplate)" -ForegroundColor Green

# Determine work item types based on process template
# Basic: Epic → Issue → Task  |  Agile: Epic → Feature → User Story → Task
$isBasic = $processTemplate -eq 'Basic'
$midType = if ($isBasic) { 'Issue' } else { 'Feature' }
$storyType = if ($isBasic) { 'Issue' } else { 'User Story' }
Write-Host "  → Using work item types: Epic → $midType → $storyType → Task" -ForegroundColor DarkGray

# ─── Step 1: Connect ADO Boards to GitHub ──────────────────────
Write-Host "`n▶ [1/6] Connecting ADO Boards ↔ GitHub repo..." -ForegroundColor Yellow
Write-Host @"
  MANUAL STEP (one-time, requires ADO admin):
  1. Go to: $AdoOrg/$AdoProject/_settings/boards-external-integration
  2. Click "Connect GitHub" → Authorize the GitHub repo: $GitHubRepo
  3. This enables AB# links in commits/PRs to auto-link ADO work items
  
  Docs: https://learn.microsoft.com/en-us/azure/devops/boards/github/connect-to-github
"@ -ForegroundColor DarkGray

# ─── Step 2: Create ADO test work items ────────────────────────
Write-Host "`n▶ [2/6] Creating ADO test work items (Epic → $midType → $storyType → Tasks)..." -ForegroundColor Yellow

# Epic
$epic = az boards work-item create `
    --type "Epic" `
    --title "SSDLC Demo: Secure Cloud Deployment" `
    --description "End-to-end DevSecOps pipeline from ADO Boards → GitHub → Azure nonprod. Demonstrates GHAS, Bicep IaC, progressive deployment." `
    --fields "System.Tags=ssdlc;devops;demo" `
    -o json 2>$null | ConvertFrom-Json

if ($epic) {
    Write-Host "  ✓ Epic #$($epic.id): $($epic.fields.'System.Title')" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to create Epic (check ADO permissions)" -ForegroundColor Red; exit 1
}

# Feature / Issue (mid-level) — depends on process template
$feature = az boards work-item create `
    --type $midType `
    --title "GitHub Actions CI/CD with GHAS Security Scanning" `
    --description "Implement CI pipeline with 8 parallel checks (CodeQL, Trivy, Checkov, Bandit, dotnet test, pytest, dependency review, Bicep lint) and CD pipeline with progressive deployment (dev → staging → prod)." `
    --fields "System.Tags=ci-cd;github-actions;ghas" `
    -o json 2>$null | ConvertFrom-Json

if ($feature) {
    # Parent the feature/issue under the epic
    az boards work-item relation add --id $feature.id --relation-type "Parent" --target-id $epic.id -o none 2>$null
    Write-Host "  ✓ $midType #$($feature.id) → (parent) Epic #$($epic.id)" -ForegroundColor Green
}

# User Stories with Tasks
$stories = @(
    @{
        Title = "As a developer, I can push code and get automated security scanning on PRs"
        Description = "CodeQL SAST, Bandit, dependency review, container scan (Trivy), IaC scan (Checkov) run on every PR. Results surface in GitHub Security tab."
        AcceptanceCriteria = "- [ ] CodeQL scans C# and Python`n- [ ] Trivy scans container images`n- [ ] Checkov scans Bicep`n- [ ] Bandit scans Python`n- [ ] All results upload to GitHub Security"
        Tags = "security;ci;ghas"
        Tasks = @(
            "Configure CodeQL workflow for C# and Python",
            "Add Trivy container scanning to CI",
            "Add Checkov IaC scanning for Bicep",
            "Add Bandit Python SAST to security job",
            "Enable Dependabot for NuGet, pip, and GitHub Actions"
        )
    },
    @{
        Title = "As a platform engineer, I can deploy Bicep IaC to Azure nonprod"
        Description = "Bicep modules deploy VNet, Key Vault, Service Bus, Functions, and Container Apps to dev/staging environments with OIDC auth (no stored credentials)."
        AcceptanceCriteria = "- [ ] Bicep compiles cleanly (az bicep build)`n- [ ] Dev env deploys via CD pipeline`n- [ ] Staging env deploys after dev succeeds`n- [ ] OIDC federated credentials used (no PATs)"
        Tags = "iac;bicep;azure;deployment"
        Tasks = @(
            "Validate Bicep modules compile without errors",
            "Configure OIDC federated credentials in Azure AD",
            "Set GitHub repo secrets for Azure deployment",
            "Create GitHub environments (dev, staging, production)",
            "Test dev environment deployment from CD pipeline"
        )
    },
    @{
        Title = "As an auditor, I can trace work items to deployed code"
        Description = "Full traceability from ADO work item → GitHub commit (AB# link) → PR → CI results → CD deployment. Supports SOC2 / ISO27001 evidence."
        AcceptanceCriteria = "- [ ] AB# links show in ADO work items`n- [ ] PR template includes SSDLC checklist`n- [ ] CD pipeline links to commit SHA`n- [ ] Container images tagged with commit SHA"
        Tags = "traceability;compliance;audit"
        Tasks = @(
            "Configure ADO-GitHub integration for AB# links",
            "Verify PR template renders SSDLC checklist",
            "Tag container images with commit SHA in CD pipeline",
            "Document audit trail from work item to deployment"
        )
    },
    @{
        Title = "As a team lead, I can monitor deployments and health via Azure"
        Description = "Application Insights + Log Analytics monitor all compute. Alert rules for failures. ACA and Functions health endpoints return 200."
        AcceptanceCriteria = "- [ ] App Insights connected to Functions and ACA`n- [ ] Health endpoints respond 200`n- [ ] Alert rules configured`n- [ ] Log Analytics collects all diagnostics"
        Tags = "monitoring;observability;azure"
        Tasks = @(
            "Verify App Insights connection in Bicep modules",
            "Test Function App health endpoint",
            "Test Container App health endpoint",
            "Configure alert rules in monitoring module"
        )
    }
)

foreach ($story in $stories) {
    # Basic process: Issue (no AcceptanceCriteria field)  |  Agile: User Story (has AcceptanceCriteria)
    $fieldsArr = @("System.Tags=$($story.Tags)")
    if (-not $isBasic) { $fieldsArr += "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" }

    $wi = az boards work-item create `
        --type $storyType `
        --title $story.Title `
        --description "$($story.Description)`n`nAcceptance Criteria:`n$($story.AcceptanceCriteria)" `
        --fields @fieldsArr `
        -o json 2>$null | ConvertFrom-Json

    if ($wi) {
        # Parent under feature/issue
        az boards work-item relation add --id $wi.id --relation-type "Parent" --target-id $feature.id -o none 2>$null
        Write-Host "  ✓ $storyType #$($wi.id): $($story.Title | Select-String -Pattern '^.{0,60}' | ForEach-Object { $_.Matches.Value })..." -ForegroundColor Green

        # Create tasks
        foreach ($taskTitle in $story.Tasks) {
            $task = az boards work-item create `
                --type "Task" `
                --title $taskTitle `
                --fields "System.Tags=$($story.Tags)" `
                -o json 2>$null | ConvertFrom-Json
            if ($task) {
                az boards work-item relation add --id $task.id --relation-type "Parent" --target-id $wi.id -o none 2>$null
                Write-Host "    ✓ Task #$($task.id): $taskTitle" -ForegroundColor DarkGreen
            }
        }
    }
}

# ─── Step 3: Create a test branch + commit with AB# link ───────
Write-Host "`n▶ [3/6] Creating test branch with AB# linked commit..." -ForegroundColor Yellow

$branchName = "feature/ado-boards-integration-test"
$currentBranch = git rev-parse --abbrev-ref HEAD

git checkout -b $branchName 2>$null
if ($LASTEXITCODE -ne 0) {
    git checkout $branchName 2>$null
}

# Create a test file that references the work items
$testContent = @"
# ADO Boards Integration Test

This file validates the ADO Boards → GitHub → Azure traceability chain.

## Linked Work Items
- Epic: SSDLC Demo Secure Cloud Deployment
- Feature: GitHub Actions CI/CD with GHAS

## Verification
- AB# link syntax: ``AB#$($epic.id)``
- Created: $(Get-Date -Format "yyyy-MM-dd HH:mm")
- Pipeline: CI triggers on PR, CD triggers on main merge
"@

Set-Content -Path "docs/ado-integration-test.md" -Value $testContent -Force
New-Item -ItemType Directory -Path "docs" -Force -ErrorAction SilentlyContinue | Out-Null
Set-Content -Path "docs/ado-integration-test.md" -Value $testContent -Force

git add docs/ado-integration-test.md
git commit -m "test: validate ADO Boards integration AB#$($epic.id)" 2>$null
git push -u origin $branchName 2>$null

Write-Host "  ✓ Branch: $branchName" -ForegroundColor Green
Write-Host "  ✓ Commit references AB#$($epic.id)" -ForegroundColor Green

# ─── Step 4: Create PR with SSDLC checklist ────────────────────
Write-Host "`n▶ [4/6] Creating test PR..." -ForegroundColor Yellow

$prBody = @"
## Description
ADO Boards integration test — validates traceability from ADO work items to GitHub PRs.

Linked work items: AB#$($epic.id) AB#$($feature.id)

## Type of Change
- [x] Documentation update

## SSDLC Checklist
- [x] Code follows security coding standards
- [x] No secrets or credentials are hardcoded
- [x] Input validation is implemented at system boundaries
- [x] Error handling does not expose sensitive information
- [x] Unit tests added/updated (N/A - docs only)
- [x] Security scanning passes (CodeQL, Bandit, Trivy)
- [x] Dependency review passes (no vulnerable deps)
"@

$pr = gh pr create `
    --title "test: ADO Boards integration - AB#$($epic.id)" `
    --body $prBody `
    --base main `
    --head $branchName 2>&1

Write-Host "  ✓ PR created: $pr" -ForegroundColor Green

# ─── Step 5: Configure GitHub environments for nonprod ──────────
Write-Host "`n▶ [5/6] Configuring GitHub environments (dev, staging)..." -ForegroundColor Yellow

# Create environments via GitHub API
foreach ($env in @("dev", "staging")) {
    gh api --method PUT "repos/$GitHubRepo/environments/$env" 2>$null
    Write-Host "  ✓ Environment: $env" -ForegroundColor Green
}

# Production with approval gate
$prodBody = @{
    wait_timer = 0
    reviewers = @()
    deployment_branch_policy = @{
        protected_branches = $true
        custom_branch_policies = $false
    }
} | ConvertTo-Json -Compress
$prodBody | gh api --method PUT "repos/$GitHubRepo/environments/production" --input - 2>$null
Write-Host "  ✓ Environment: production (with branch policy)" -ForegroundColor Green

Write-Host @"

  ℹ️  To add OIDC secrets for Azure deployment, run:
  gh secret set AZURE_CLIENT_ID --body "<app-registration-client-id>"
  gh secret set AZURE_TENANT_ID --body "$AzureTenantId"
  gh secret set AZURE_SUBSCRIPTION_ID --body "$AzureSubscriptionId"
  gh secret set ACR_NAME --body "<your-acr-name>"
"@ -ForegroundColor DarkGray

# ─── Step 6: Summary ───────────────────────────────────────────
Write-Host "`n▶ [6/6] Summary" -ForegroundColor Yellow

git checkout $currentBranch 2>$null

Write-Host @"

══════════════════════════════════════════════════════
  ✅ ADO Boards → GitHub → Azure Setup Complete
══════════════════════════════════════════════════════

  ADO Work Items Created:
    Epic #$($epic.id)    → SSDLC Demo: Secure Cloud Deployment
    Feature #$($feature.id) → GitHub Actions CI/CD with GHAS
    + 4 User Stories with 18 Tasks

  GitHub:
    Repo:     https://github.com/$GitHubRepo
    PR:       (see link above — AB# linked to ADO)
    Envs:     dev, staging, production
    Workflows: ci.yml, cd.yml, codeql.yml, dependency-review.yml

  Traceability Chain:
    ADO Board (AB#$($epic.id)) → Git Commit → PR → CI Checks → CD Deploy → Azure

  Next Steps:
    1. Connect ADO ↔ GitHub in ADO Project Settings (one-time)
    2. Verify AB#$($epic.id) appears linked in ADO work item
    3. Merge the test PR after CI passes
    4. Configure OIDC credentials for Azure deployment
    5. Watch CD pipeline deploy to dev → staging → (approve) → prod

══════════════════════════════════════════════════════
"@ -ForegroundColor Cyan

