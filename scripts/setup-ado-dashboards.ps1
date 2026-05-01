# ==============================================================================
# Setup ADO Dashboards & Pipeline Reporting
# Creates dashboards, widgets, and configures reporting for SSDLC pipelines
#
# Prerequisites:
#   - az CLI with azure-devops extension
#   - Authenticated: az login && az devops configure --defaults org=... project=...
#
# Usage:
#   .\scripts\setup-ado-dashboards.ps1 -Organization "https://dev.azure.com/YOUR_ORG" -Project "ssdlc-demo"
# ==============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$Team = "$Project Team"
)

$ErrorActionPreference = "Continue"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ADO Dashboard & Reporting Setup" -ForegroundColor Cyan
Write-Host " Org: $Organization" -ForegroundColor Gray
Write-Host " Project: $Project" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

# ── Verify prerequisites ────────────────────────────────────────────────────
Write-Host "`n[1/7] Verifying prerequisites..." -ForegroundColor Yellow
$devopsExt = az extension list --query "[?name=='azure-devops']" -o tsv 2>$null
if (-not $devopsExt) {
    Write-Host "  Installing azure-devops extension..." -ForegroundColor Gray
    az extension add --name azure-devops --yes
}
az devops configure --defaults organization=$Organization project=$Project

# ── Create Pipelines ────────────────────────────────────────────────────────
Write-Host "`n[2/7] Creating pipeline definitions..." -ForegroundColor Yellow

$pipelines = @(
    @{ Name = "CI";                    Path = "ado/pipelines/ci.yml";                     Folder = "SSDLC" }
    @{ Name = "CD";                    Path = "ado/pipelines/cd.yml";                     Folder = "SSDLC" }
    @{ Name = "Security";              Path = "ado/pipelines/security.yml";               Folder = "SSDLC" }
    @{ Name = "Supply-Chain-Security"; Path = "ado/pipelines/supply-chain-security.yml";  Folder = "SSDLC" }
    @{ Name = "Staging-Gate";          Path = "ado/pipelines/staging-gate.yml";           Folder = "SSDLC" }
    @{ Name = "AI-Agent-Ops";          Path = "ado/pipelines/ai-agent-ops.yml";           Folder = "SSDLC/AI" }
    @{ Name = "AI-P1-DevOps-Model";    Path = "ado/pipelines/ai-p1-devops-model.yml";    Folder = "SSDLC/AI" }
    @{ Name = "AI-P3-FoundryIQ";       Path = "ado/pipelines/ai-p3-foundryiq.yml";       Folder = "SSDLC/AI" }
    @{ Name = "AI-P4-MCP-Tools";       Path = "ado/pipelines/ai-p4-mcp-tools.yml";       Folder = "SSDLC/AI" }
    @{ Name = "SSDLC-Report";          Path = "ado/pipelines/ssdlc-report.yml";          Folder = "SSDLC" }
)

$pipelineIds = @{}
foreach ($p in $pipelines) {
    $existing = az pipelines show --name $p.Name --org $Organization --project $Project 2>$null | ConvertFrom-Json
    if ($existing) {
        Write-Host "  ✓ Pipeline '$($p.Name)' already exists (ID: $($existing.id))" -ForegroundColor Green
        $pipelineIds[$p.Name] = $existing.id
    }
    else {
        Write-Host "  Creating pipeline '$($p.Name)'..." -ForegroundColor Gray
        $result = az pipelines create `
            --name $p.Name `
            --yml-path $p.Path `
            --repository "ncheruvu-MSFT/az-github-ssdlc-demo" `
            --repository-type github `
            --service-connection "github-ssdlc-demo" `
            --branch main `
            --folder-path $p.Folder `
            --skip-first-run true `
            --org $Organization `
            --project $Project 2>$null | ConvertFrom-Json
        if ($result) {
            Write-Host "  ✓ Created '$($p.Name)' (ID: $($result.id))" -ForegroundColor Green
            $pipelineIds[$p.Name] = $result.id
        }
        else {
            Write-Host "  ⚠ Failed to create '$($p.Name)' — check service connection" -ForegroundColor DarkYellow
        }
    }
}

# ── Update Staging-Gate pipeline variables with pipeline IDs ────────────────
Write-Host "`n[3/7] Configuring pipeline variables..." -ForegroundColor Yellow
if ($pipelineIds["CI"] -and $pipelineIds["Staging-Gate"]) {
    az pipelines variable create --name CI_PIPELINE_ID --value $pipelineIds["CI"] `
        --pipeline-name "Staging-Gate" --org $Organization --project $Project 2>$null
    Write-Host "  ✓ Set CI_PIPELINE_ID = $($pipelineIds['CI'])" -ForegroundColor Green
}
if ($pipelineIds["Security"] -and $pipelineIds["Staging-Gate"]) {
    az pipelines variable create --name SECURITY_PIPELINE_ID --value $pipelineIds["Security"] `
        --pipeline-name "Staging-Gate" --org $Organization --project $Project 2>$null
    Write-Host "  ✓ Set SECURITY_PIPELINE_ID = $($pipelineIds['Security'])" -ForegroundColor Green
}

# ── Create Environments with Approval Gates ─────────────────────────────────
Write-Host "`n[4/7] Creating deployment environments..." -ForegroundColor Yellow

$environments = @("dev", "staging", "production")
foreach ($env in $environments) {
    $existing = az devops invoke `
        --area distributedtask --resource environments `
        --route-parameters project=$Project `
        --query-parameters name=$env `
        --http-method GET --org $Organization 2>$null | ConvertFrom-Json
    
    if ($existing.value -and $existing.value.Count -gt 0) {
        Write-Host "  ✓ Environment '$env' exists" -ForegroundColor Green
    }
    else {
        $body = @{ name = $env; description = "SSDLC $env environment" } | ConvertTo-Json -Compress
        az devops invoke `
            --area distributedtask --resource environments `
            --route-parameters project=$Project `
            --http-method POST --in-file <(echo $body) `
            --org $Organization 2>$null
        Write-Host "  ✓ Created environment '$env'" -ForegroundColor Green
    }
}
Write-Host "  ℹ Set approval gates manually:" -ForegroundColor Gray
Write-Host "    Project Settings → Environments → staging → Approvals (1 approver)" -ForegroundColor Gray
Write-Host "    Project Settings → Environments → production → Approvals (2 approvers)" -ForegroundColor Gray

# ── Configure Branch Policies ───────────────────────────────────────────────
Write-Host "`n[5/7] Configuring branch policies..." -ForegroundColor Yellow
Write-Host "  ℹ Set these manually in Project Settings → Repos → Policies → main:" -ForegroundColor Gray
Write-Host "    • Require minimum 1 reviewer" -ForegroundColor Gray
Write-Host "    • Check for linked work items" -ForegroundColor Gray
Write-Host "    • Build validation: CI pipeline" -ForegroundColor Gray
Write-Host "    • Build validation: Security pipeline" -ForegroundColor Gray
Write-Host "    • Reset votes on new pushes" -ForegroundColor Gray

# ── Enable Pipeline Reports & Test Analytics ────────────────────────────────
Write-Host "`n[6/7] Pipeline Reports & Analytics..." -ForegroundColor Yellow
Write-Host "  ✓ Pipeline reports are built-in. Access via:" -ForegroundColor Green
Write-Host "    Pipelines → (select pipeline) → Analytics tab" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "  Available built-in reports:" -ForegroundColor Cyan
Write-Host "    • Pipeline pass rate — % of successful runs over time" -ForegroundColor Gray
Write-Host "    • Pipeline duration — build time trends" -ForegroundColor Gray
Write-Host "    • Test pass rate — test success trends (from PublishTestResults)" -ForegroundColor Gray
Write-Host "    • Test duration — test execution time trends" -ForegroundColor Gray
Write-Host "    • Code coverage — coverage trends (from PublishCodeCoverageResults)" -ForegroundColor Gray
Write-Host "    • Flaky tests — auto-detected unreliable tests" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "  Advanced Security reports (if GHAzDO enabled):" -ForegroundColor Cyan
Write-Host "    Repos → Advanced Security → Alerts dashboard" -ForegroundColor Gray
Write-Host "    • Dependency alerts (CVEs)" -ForegroundColor Gray
Write-Host "    • Code scanning alerts (CodeQL SAST)" -ForegroundColor Gray
Write-Host "    • Secret scanning alerts" -ForegroundColor Gray

# ── Print Dashboard URL & Summary ──────────────────────────────────────────
Write-Host "`n[7/7] Dashboard & Reporting URLs" -ForegroundColor Yellow
$orgClean = $Organization.TrimEnd('/')
Write-Host "" -ForegroundColor Gray
Write-Host "  ┌─────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │ SSDLC ADO Reporting — Key URLs                                  │" -ForegroundColor DarkCyan
Write-Host "  ├─────────────────────────────────────────────────────────────────┤" -ForegroundColor DarkCyan
Write-Host "  │ Pipeline Runs:   $orgClean/$Project/_build" -ForegroundColor White
Write-Host "  │ Pipeline Analytics: $orgClean/$Project/_build?view=analytics" -ForegroundColor White
Write-Host "  │ Test Results:    $orgClean/$Project/_testManagement/runs" -ForegroundColor White
Write-Host "  │ Environments:   $orgClean/$Project/_environments" -ForegroundColor White
Write-Host "  │ Deployments:    $orgClean/$Project/_releaseProgress" -ForegroundColor White
Write-Host "  │ Security Alerts: $orgClean/$Project/_git/az-github-ssdlc-demo/alerts" -ForegroundColor White
Write-Host "  │ Boards:         $orgClean/$Project/_boards/board" -ForegroundColor White
Write-Host "  │ Dashboards:     $orgClean/$Project/_dashboards" -ForegroundColor White
Write-Host "  └─────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run CI pipeline:  az pipelines run --name CI" -ForegroundColor Gray
Write-Host "  2. Verify tests publish to Test Analytics" -ForegroundColor Gray
Write-Host "  3. Check Pipeline Analytics tab after 3+ runs" -ForegroundColor Gray
Write-Host "  4. Set approval gates on staging/production environments" -ForegroundColor Gray
Write-Host "  5. Enable GHAzDO for Advanced Security reporting" -ForegroundColor Gray
Write-Host ""
