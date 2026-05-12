# ==============================================================================
# Entrypoint for GitHub Actions self-hosted runner (Windows container)
# Registers the runner, starts it, and deregisters on exit
# ==============================================================================
$ErrorActionPreference = "Stop"

$RunnerName   = if ($env:RUNNER_NAME)   { $env:RUNNER_NAME }   else { $env:COMPUTERNAME }
$RunnerWork   = if ($env:RUNNER_WORKDIR){ $env:RUNNER_WORKDIR } else { "C:\runner\_work" }
$RunnerLabels = if ($env:RUNNER_LABELS) { $env:RUNNER_LABELS } else { "self-hosted,aci,windows,custom" }
$RunnerGroup  = if ($env:RUNNER_GROUP)  { $env:RUNNER_GROUP }  else { "Default" }

# Validate required environment variables
if (-not $env:GITHUB_URL) {
    Write-Error "GITHUB_URL is required (e.g., https://github.com/org/repo)"
    exit 1
}
if (-not $env:RUNNER_TOKEN) {
    Write-Error "RUNNER_TOKEN is required (registration token from GitHub API)"
    exit 1
}

Write-Host "=== Configuring GitHub Actions Runner ==="
Write-Host "  Name:   $RunnerName"
Write-Host "  Labels: $RunnerLabels"
Write-Host "  URL:    $env:GITHUB_URL"
Write-Host "  Work:   $RunnerWork"

# Configure the runner
& .\config.cmd `
    --url $env:GITHUB_URL `
    --token $env:RUNNER_TOKEN `
    --name $RunnerName `
    --labels $RunnerLabels `
    --work $RunnerWork `
    --unattended `
    --replace

# Start the runner (blocks until terminated)
Write-Host "=== Starting runner ==="
& .\run.cmd

# Cleanup on exit
Write-Host "=== Removing runner registration ==="
& .\config.cmd remove --token $env:RUNNER_TOKEN
