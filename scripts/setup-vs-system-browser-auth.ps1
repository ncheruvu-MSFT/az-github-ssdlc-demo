#!/usr/bin/env pwsh
# =============================================================================
# Set Visual Studio sign-in to "System web browser" via registry
# Discovers all VS installations via vswhere, computes the instance-specific
# SHA-256 hash (of devenv.exe path), and sets IdentityAuthenticationType.
#
# SCCM / SYSTEM context support:
#   When running as SYSTEM (e.g., SCCM task sequence), HKCU points to the
#   SYSTEM account's hive — not the logged-in user. This script detects that
#   scenario and writes to every real user profile via HKU:\<SID>, plus the
#   Default User profile (so new users get the setting on first logon).
# =============================================================================
#Requires -Version 5.1
param(
    [ValidateSet("SystemWebBrowser", "WindowsBroker", "EmbeddedBrowser")]
    [string]$AuthType = "SystemWebBrowser"
)

$ErrorActionPreference = 'Stop'

# --- Value mapping for the dropdown in Tools > Options > Environment > Accounts ---
$authValues = @{
    EmbeddedBrowser    = 0  # Embedded web browser (legacy)
    SystemWebBrowser   = 3  # System web browser
    WindowsBroker      = 2  # Windows authentication broker (WAM)
}
$targetValue = $authValues[$AuthType]

# --- Locate vswhere ---
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswherePath)) {
    Write-Error "vswhere.exe not found at '$vswherePath'. Ensure Visual Studio Installer is present."
}

# --- Discover all VS installations and compute hashes ---
$instances = & $vswherePath -all -format json | ConvertFrom-Json
if (-not $instances -or $instances.Count -eq 0) {
    Write-Error "No Visual Studio installations found via vswhere."
}

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$valueNames = @()

foreach ($instance in $instances) {
    $devenvPath = Join-Path $instance.installationPath "Common7\IDE\devenv.exe"
    if (-not (Test-Path $devenvPath)) {
        Write-Warning "Skipping '$($instance.displayName)' - devenv.exe not found at '$devenvPath'"
        continue
    }
    $hashBytes  = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($devenvPath))
    $hashString = -join ($hashBytes | ForEach-Object { '{0:X2}' -f $_ })
    $valueNames += [PSCustomObject]@{
        DisplayName = $instance.displayName
        DevenvPath  = $devenvPath
        ValueName   = "IdentityAuthenticationType.$hashString"
    }
}
$sha256.Dispose()

if ($valueNames.Count -eq 0) {
    Write-Error "No valid VS installations with devenv.exe found."
}

# --- Helper: write the registry value under a given root path ---
function Set-VSAuthType {
    param(
        [string]$RootPath,   # e.g. "HKCU:\Software\Microsoft\VSCommon" or "Registry::HKU\S-1-5-...\Software\Microsoft\VSCommon"
        [string]$Label       # display label for logging
    )
    $regPath = $RootPath
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    foreach ($entry in $valueNames) {
        Set-ItemProperty -Path $regPath -Name $entry.ValueName -Value $targetValue -Type DWord
        $actual = (Get-ItemProperty -Path $regPath -Name $entry.ValueName).$($entry.ValueName)
        if ($actual -eq $targetValue) {
            Write-Host "[OK] $Label | $($entry.DisplayName) => $AuthType ($targetValue)" -ForegroundColor Green
        } else {
            Write-Warning "FAIL $Label | $($entry.ValueName): expected $targetValue, got $actual"
        }
    }
}

# --- Detect if running as SYSTEM ---
$isSystem = ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')

if (-not $isSystem) {
    # --- Normal user context: write to HKCU ---
    Write-Host "Running as current user — writing to HKCU" -ForegroundColor Cyan
    Set-VSAuthType -RootPath "HKCU:\Software\Microsoft\VSCommon" -Label $env:USERNAME
} else {
    # --- SYSTEM context (SCCM/Intune/GPO): write to all user profiles via HKU ---
    Write-Host "Running as SYSTEM — targeting all user profiles via HKU" -ForegroundColor Yellow

    # Mount HKU if not already available as PSDrive
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }

    # 1) Currently loaded hives (logged-in users + cached profiles)
    $loadedSIDs = Get-ChildItem "HKU:\" |
        Where-Object { $_.PSChildName -match '^S-1-5-21-\d+-\d+-\d+-\d+$' } |  # real user SIDs, skip _Classes
        Select-Object -ExpandProperty PSChildName

    foreach ($sid in $loadedSIDs) {
        try {
            $username = ([System.Security.Principal.SecurityIdentifier]$sid).Translate(
                [System.Security.Principal.NTAccount]).Value
        } catch {
            $username = $sid
        }
        $hkuPath = "HKU:\$sid\Software\Microsoft\VSCommon"
        Set-VSAuthType -RootPath $hkuPath -Label $username
    }

    # 2) Offline hives (users not currently logged in)
    $profileList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
        Where-Object { $_.PSChildName -match '^S-1-5-21-' }

    foreach ($profile in $profileList) {
        $sid = $profile.PSChildName
        if ($sid -in $loadedSIDs) { continue }  # already handled above

        $profilePath = (Get-ItemProperty $profile.PSPath).ProfileImagePath
        $ntuser = Join-Path $profilePath "NTUSER.DAT"
        if (-not (Test-Path $ntuser)) {
            Write-Warning "Skipping $sid — NTUSER.DAT not found at '$ntuser'"
            continue
        }

        try {
            $username = ([System.Security.Principal.SecurityIdentifier]$sid).Translate(
                [System.Security.Principal.NTAccount]).Value
        } catch {
            $username = $sid
        }

        # Load the offline hive under a temp key
        $tempKey = "HKU_TEMP_$($sid.Replace('-','_'))"
        $loadResult = & reg.exe load "HKU\$tempKey" $ntuser 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not load hive for $username ($ntuser): $loadResult"
            continue
        }

        try {
            $hkuPath = "Registry::HKEY_USERS\$tempKey\Software\Microsoft\VSCommon"
            Set-VSAuthType -RootPath $hkuPath -Label "$username (offline)"
        } finally {
            # Flush and unload — must release PSDrive handles first
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            & reg.exe unload "HKU\$tempKey" 2>&1 | Out-Null
        }
    }

    # 3) Default User profile (applies to users who log in for the first time)
    $defaultNtuser = Join-Path $env:SystemDrive "Users\Default\NTUSER.DAT"
    if (Test-Path $defaultNtuser) {
        $tempKey = "HKU_TEMP_DEFAULT"
        $loadResult = & reg.exe load "HKU\$tempKey" $defaultNtuser 2>&1
        if ($LASTEXITCODE -eq 0) {
            try {
                Set-VSAuthType -RootPath "Registry::HKEY_USERS\$tempKey\Software\Microsoft\VSCommon" -Label "Default User (new logons)"
            } finally {
                [gc]::Collect()
                [gc]::WaitForPendingFinalizers()
                & reg.exe unload "HKU\$tempKey" 2>&1 | Out-Null
            }
        } else {
            Write-Warning "Could not load Default User hive: $loadResult"
        }
    }
}

Write-Host "`nDone. Restart Visual Studio for the change to take effect." -ForegroundColor Cyan
