# escape=`
# ==============================================================================
# Custom GitHub Actions Self-Hosted Runner — Windows Server 2022
# Pre-installed: .NET 8, Node 20, Azure CLI, Git, Docker CLI
# Security: non-admin ContainerUser
# ==============================================================================
FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';"]

# ── Metadata ─────────────────────────────────────────────────────
LABEL maintainer="ssdlc-demo" `
      description="Custom GitHub Actions runner for Windows" `
      os="windows-ltsc2022"

# ── Git ──────────────────────────────────────────────────────────
RUN $gitUrl = 'https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/MinGit-2.44.0-64-bit.zip'; `
    Invoke-WebRequest -Uri $gitUrl -OutFile git.zip; `
    Expand-Archive git.zip -DestinationPath C:\git; `
    Remove-Item git.zip; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\git\cmd', 'Machine')

# ── .NET 8 SDK ───────────────────────────────────────────────────
RUN Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile dotnet-install.ps1; `
    .\dotnet-install.ps1 -Channel 8.0 -InstallDir 'C:\dotnet'; `
    Remove-Item dotnet-install.ps1; `
    [Environment]::SetEnvironmentVariable('DOTNET_ROOT', 'C:\dotnet', 'Machine'); `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\dotnet', 'Machine')

# ── Node.js 20 LTS ──────────────────────────────────────────────
RUN $nodeUrl = 'https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip'; `
    Invoke-WebRequest -Uri $nodeUrl -OutFile node.zip; `
    Expand-Archive node.zip -DestinationPath C:\; `
    Rename-Item 'C:\node-v20.11.1-win-x64' 'C:\nodejs'; `
    Remove-Item node.zip; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\nodejs', 'Machine')

# ── Azure CLI ────────────────────────────────────────────────────
RUN $azUrl = 'https://aka.ms/installazurecliwindowsx64'; `
    Invoke-WebRequest -Uri $azUrl -OutFile az-cli.msi; `
    Start-Process msiexec.exe -ArgumentList '/i', 'az-cli.msi', '/quiet', '/norestart' -Wait; `
    Remove-Item az-cli.msi

# ── GitHub Actions Runner ────────────────────────────────────────
ARG RUNNER_VERSION=2.321.0

RUN $runnerUrl = \"https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip\"; `
    Invoke-WebRequest -Uri $runnerUrl -OutFile runner.zip; `
    New-Item -ItemType Directory -Path C:\runner -Force; `
    Expand-Archive runner.zip -DestinationPath C:\runner; `
    Remove-Item runner.zip

WORKDIR C:\runner

# ── Entrypoint ───────────────────────────────────────────────────
COPY entrypoint.ps1 C:\runner\entrypoint.ps1

# Security: use ContainerUser (non-admin)
USER ContainerUser

ENTRYPOINT ["powershell", "-File", "C:\\runner\\entrypoint.ps1"]
