<#
.SYNOPSIS
    Sets up a GitHub Actions self-hosted runner on Azure Container Instances (ACI).
    
.DESCRIPTION
    Creates an ACI container group running the GitHub Actions runner agent.
    Uses your existing OIDC SP for Azure authentication.
    Since subscription has zero VM quotas, ACI is used instead of VMSS.

.PARAMETER GitHubOrg
    GitHub organization name

.PARAMETER GitHubRepo
    GitHub repository name

.PARAMETER GitHubPAT
    GitHub Personal Access Token with 'repo' and 'admin:org' scopes
    (needed to register runners). Store in Key Vault for production use.

.PARAMETER ResourceGroupName
    Azure resource group to deploy ACI into

.PARAMETER Location
    Azure region (default: canadacentral)

.PARAMETER RunnerName
    Name for the runner instance

.PARAMETER ContainerCpu
    CPU cores for the container (default: 2)

.PARAMETER ContainerMemoryGb
    Memory in GB for the container (default: 4)

.EXAMPLE
    ./setup-aci-github-runner.ps1 `
        -GitHubOrg "myorg" `
        -GitHubRepo "az-github-ssdlc-demo" `
        -GitHubPAT $env:GITHUB_PAT `
        -ResourceGroupName "rg-ssdlc-runners" `
        -Location "canadacentral"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepo,

    [Parameter(Mandatory = $true)]
    [string]$GitHubPAT,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-ssdlc-runners-dev",

    [Parameter(Mandatory = $false)]
    [string]$Location = "canadacentral",

    [Parameter(Mandatory = $false)]
    [string]$RunnerName = "aci-runner-01",

    [Parameter(Mandatory = $false)]
    [int]$ContainerCpu = 2,

    [Parameter(Mandatory = $false)]
    [int]$ContainerMemoryGb = 4,

    [Parameter(Mandatory = $false)]
    [string]$ContainerImage = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== GitHub Actions Self-Hosted Runner on ACI ===" -ForegroundColor Cyan

# ── Step 1: Get runner registration token ────────────────────────
Write-Host "`n[1/5] Getting runner registration token..." -ForegroundColor Yellow

$tokenResponse = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$GitHubOrg/$GitHubRepo/actions/runners/registration-token" `
    -Method Post `
    -Headers @{
        Authorization = "Bearer $GitHubPAT"
        Accept        = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

$registrationToken = $tokenResponse.token
Write-Host "  Registration token obtained (expires in 1 hour)" -ForegroundColor Green

# ── Step 2: Ensure resource group exists ─────────────────────────
Write-Host "`n[2/5] Ensuring resource group '$ResourceGroupName' exists..." -ForegroundColor Yellow

$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
if (-not $rgExists) {
    az group create --name $ResourceGroupName --location $Location --tags Environment=dev Project=ssdlc-demo ManagedBy=script | Out-Null
    Write-Host "  Created resource group" -ForegroundColor Green
} else {
    Write-Host "  Resource group already exists" -ForegroundColor Green
}

# ── Step 3: Create ACI container group ───────────────────────────
Write-Host "`n[3/5] Deploying ACI container group '$RunnerName'..." -ForegroundColor Yellow

# Using the official GitHub runner image from ghcr.io
# For production, use custom image from ACR (built by runner-build-images.yml)
if ($ContainerImage) {
    $containerImageToUse = $ContainerImage
    Write-Host "  Using custom image: $containerImageToUse" -ForegroundColor Cyan
} else {
    $containerImageToUse = "ghcr.io/actions/actions-runner:latest"
    Write-Host "  Using default image: $containerImageToUse" -ForegroundColor Cyan
}
$repoUrl = "https://github.com/$GitHubOrg/$GitHubRepo"

# Check if container already exists and delete it
$existing = az container show --resource-group $ResourceGroupName --name $RunnerName 2>$null
if ($existing) {
    Write-Host "  Deleting existing container..." -ForegroundColor DarkYellow
    az container delete --resource-group $ResourceGroupName --name $RunnerName --yes | Out-Null
}

# Deploy ACI with runner configuration
az container create `
    --resource-group $ResourceGroupName `
    --name $RunnerName `
    --image $containerImageToUse `
    --cpu $ContainerCpu `
    --memory $ContainerMemoryGb `
    --os-type Linux `
    --restart-policy Never `
    --environment-variables `
        RUNNER_NAME=$RunnerName `
        RUNNER_WORKDIR="/home/runner/_work" `
        GITHUB_URL=$repoUrl `
        RUNNER_TOKEN=$registrationToken `
        RUNNER_LABELS="self-hosted,aci,linux" `
        RUNNER_GROUP="Default" `
    --command-line "/bin/bash -c './config.sh --url $repoUrl --token $registrationToken --name $RunnerName --labels self-hosted,aci,linux --unattended --replace && ./run.sh'" `
    --tags Environment=dev Project=ssdlc-demo ManagedBy=script SecurityLevel=standard `
    --location $Location | Out-Null

Write-Host "  ACI container deployed successfully" -ForegroundColor Green

# ── Step 4: Verify runner is online ──────────────────────────────
Write-Host "`n[4/5] Waiting for runner to register..." -ForegroundColor Yellow

$maxAttempts = 12
$attempt = 0
$runnerOnline = $false

while ($attempt -lt $maxAttempts -and -not $runnerOnline) {
    Start-Sleep -Seconds 10
    $attempt++

    $runners = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$GitHubOrg/$GitHubRepo/actions/runners" `
        -Headers @{
            Authorization = "Bearer $GitHubPAT"
            Accept        = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

    $ourRunner = $runners.runners | Where-Object { $_.name -eq $RunnerName }
    if ($ourRunner -and $ourRunner.status -eq "online") {
        $runnerOnline = $true
        Write-Host "  Runner '$RunnerName' is ONLINE (ID: $($ourRunner.id))" -ForegroundColor Green
    } else {
        Write-Host "  Attempt $attempt/$maxAttempts - waiting..." -ForegroundColor DarkGray
    }
}

if (-not $runnerOnline) {
    Write-Host "  WARNING: Runner not online yet. Check ACI logs:" -ForegroundColor Red
    Write-Host "  az container logs --resource-group $ResourceGroupName --name $RunnerName" -ForegroundColor DarkYellow
}

# ── Step 5: Show summary ─────────────────────────────────────────
Write-Host "`n[5/5] Summary" -ForegroundColor Yellow
Write-Host "  ┌──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  │ Runner Name:    $RunnerName" -ForegroundColor White
Write-Host "  │ Labels:         self-hosted, aci, linux" -ForegroundColor White
Write-Host "  │ Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  │ Container CPU:  $ContainerCpu cores" -ForegroundColor White
Write-Host "  │ Container RAM:  ${ContainerMemoryGb} GB" -ForegroundColor White
Write-Host "  │ Location:       $Location" -ForegroundColor White
Write-Host "  │ Image:          $containerImageToUse" -ForegroundColor White
Write-Host "  └──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Use in workflows with: runs-on: [self-hosted, aci, linux]" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor DarkGray
Write-Host "    az container logs -g $ResourceGroupName -n $RunnerName" -ForegroundColor DarkGray
Write-Host "    az container show -g $ResourceGroupName -n $RunnerName --query 'instanceView.state'" -ForegroundColor DarkGray
Write-Host "    az container delete -g $ResourceGroupName -n $RunnerName --yes  # Cleanup" -ForegroundColor DarkGray
