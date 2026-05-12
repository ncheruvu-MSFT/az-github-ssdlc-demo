# Azure Enterprise SSDLC Demo

Enterprise-grade cloud deployment demonstrating **Azure Verified Module** patterns, **SSDLC best practices**, and **CI/CD from GitHub** with automated testing.

## Why This Exists

Most organizations bolt security onto their pipelines as an afterthought — a Trivy scan here, a manual pen-test there. The result is fragmented tooling, inconsistent enforcement, and security gates that developers learn to work around.

### What This Solves

This repository demonstrates a **unified, shift-left SSDLC** where security is embedded at every stage — from code authoring to production deployment — using a single platform (GitHub + Azure) instead of stitching together disconnected tools.

| | Traditional (Fragmented) | This Approach (Unified) |
|---|---|---|
| **Code scanning** | Separate SAST vendor | GitHub CodeQL (native) |
| **Container scanning** | Standalone Trivy/Snyk | Microsoft Defender for Containers |
| **Secret detection** | Pre-commit hooks only | GitHub Secret Scanning + push protection |
| **Dependency updates** | Manual CVE triage | Dependabot + Dependency Review (auto-PR) |
| **IaC validation** | Local linting | Checkov + Bicep lint in CI |
| **Identity** | Stored credentials | OIDC federation — zero secrets |
| **Malware scanning** | Third-party AV | GitHub Advanced Security malware detection |

> **Bottom line:** If your security toolchain requires a wiki page to explain which scanner runs where, you have a process problem — not a tooling problem. This repo shows how to collapse that complexity into a single, auditable pipeline.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Private Repository                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ CodeQL   │  │ Defender │  │ Bandit   │  │ Checkov  │  │ Dep      │ │
│  │ SAST     │  │ Container│  │ Python   │  │ IaC Scan │  │ Review   │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
│                          CI/CD Pipelines                                │
│         dev ──────────► staging ──────────► prod (manual gate)          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    OIDC (no stored credentials)
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                               │
│                                                                         │
│  ┌────────────────────── VNet (10.0.0.0/16) ──────────────────────┐    │
│  │                                                                  │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │    │
│  │  │ snet-functionapp│  │   snet-aca      │  │ snet-private   │  │    │
│  │  │  10.0.1.0/24    │  │  10.0.2.0/23    │  │ endpoints      │  │    │
│  │  │                 │  │                 │  │  10.0.4.0/24   │  │    │
│  │  │ ┌─────────────┐│  │ ┌─────────────┐ │  │                │  │    │
│  │  │ │ Azure       ││  │ │ ACA Env     │ │  │ ┌────────────┐ │  │    │
│  │  │ │ Functions   ││  │ │             │ │  │ │ Key Vault  │ │  │    │
│  │  │ │ (.NET 8)    ││  │ │ ┌─────────┐│ │  │ │ (RBAC)     │ │  │    │
│  │  │ │             ││  │ │ │ C# Hello ││ │  │ └────────────┘ │  │    │
│  │  │ │ • HelloWorld││  │ │ │ World    ││ │  │ ┌────────────┐ │  │    │
│  │  │ │ • Durable   ││  │ │ └─────────┘│ │  │ │ Service Bus│ │  │    │
│  │  │ │   Functions ││  │ │ ┌─────────┐│ │  │ │ (Premium)  │ │  │    │
│  │  │ │ • SB Trigger││  │ │ │ Python  ││ │  │ │ Queues +   │ │  │    │
│  │  │ └─────────────┘│  │ │ │ FastAPI ││ │  │ │ Topics     │ │  │    │
│  │  └─────────────────┘  │ │ └─────────┘│ │  │ └────────────┘ │  │    │
│  │                       │ └─────────────┘ │  └────────────────┘  │    │
│  │                       └─────────────────┘                      │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Monitoring & Observability                      │  │
│  │  Log Analytics ◄──── Application Insights ────► Alert Rules       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
az-github-ssdlc-demo/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # CI: build, test, security scan
│   │   ├── cd.yml                    # CD: deploy dev → staging → prod
│   │   ├── codeql.yml                # CodeQL SAST analysis
│   │   └── dependency-review.yml     # Dependency vulnerability review
│   ├── dependabot.yml                # Automated dependency updates
│   ├── CODEOWNERS                    # Required reviewers by path
│   ├── PULL_REQUEST_TEMPLATE.md      # SSDLC checklist for PRs
│   └── branch-protection.json        # Recommended branch rules
├── runners/
│   ├── ubuntu/                       # Custom Ubuntu runner image
│   │   ├── Dockerfile                # Ubuntu 22.04 + .NET 8, Python 3.12, Node 20
│   │   └── entrypoint.sh            # Auto-register/deregister runner
│   └── windows/                      # Custom Windows runner image
│       ├── Dockerfile                # Windows Server 2022 + .NET 8, Node 20
│       └── entrypoint.ps1           # Auto-register/deregister runner
├── src/
│   ├── FunctionApp/                  # C# Azure Functions (.NET 8 isolated)
│   │   ├── Functions/
│   │   │   ├── HelloWorldFunction.cs # HTTP hello world + health check
│   │   │   ├── OrderOrchestration.cs # Durable Functions workflow
│   │   │   └── ServiceBusProcessor.cs# Service Bus triggered functions
│   │   ├── Program.cs
│   │   ├── host.json
│   │   └── HelloWorld.Functions.csproj
│   ├── ContainerApp/                 # C# Minimal API on ACA
│   │   ├── Program.cs               # Hello world, health, info endpoints
│   │   ├── Dockerfile                # Multi-stage, non-root, Alpine
│   │   └── HelloWorld.ContainerApp.csproj
│   └── PythonApi/                    # Python FastAPI on ACA
│       ├── app/main.py              # Hello, health, info, echo endpoints
│       ├── Dockerfile                # Slim image, non-root, healthcheck
│       ├── requirements.txt
│       └── requirements-dev.txt
├── tests/
│   ├── FunctionApp.Tests/            # xUnit + FluentAssertions + Moq
│   ├── ContainerApp.Tests/           # Integration tests (WebApplicationFactory)
│   └── PythonApi.Tests/              # pytest + httpx + coverage
├── infra/
│   ├── main.bicep                    # Main orchestrator (subscription scope)
│   ├── main.dev.bicepparam           # Dev environment parameters
│   ├── main.staging.bicepparam       # Staging environment parameters
│   ├── main.prod.bicepparam          # Prod environment parameters
│   └── modules/
│       ├── networking.bicep          # VNet + NSG + subnets
│       ├── keyvault.bicep            # Key Vault + private endpoint + RBAC
│       ├── servicebus.bicep          # Service Bus + queues + topics
│       ├── monitoring.bicep          # Log Analytics + App Insights + alerts
│       ├── functionapp.bicep         # Function App + storage + diagnostics
│       └── containerapp.bicep        # ACA environment + C# + Python apps
├── SsdlcDemo.sln
├── SECURITY.md
└── .gitignore
```

---

## Enterprise Service Hub Architecture

### Service Bus Pattern (Queues + Topics)

| Pattern | Resource | Purpose |
|---------|----------|---------|
| **Point-to-point** | `orders` queue | Reliable order processing with dead-letter |
| **Point-to-point** | `notifications` queue | Notification delivery |
| **Pub/Sub** | `events` topic | Event distribution to multiple subscribers |
| **Audit** | `events/audit-log` subscription | Compliance and audit trail |
| **Processing** | `events/event-processing` subscription | Real-time event processing |

### Durable Functions Patterns

| Pattern | Implementation | Use Case |
|---------|---------------|----------|
| **Function Chaining** | `OrderOrchestration` | Sequential workflow steps |
| **Fan-out/Fan-in** | Extensible orchestrator | Parallel processing |
| **Human Interaction** | Status polling endpoint | Approval workflows |
| **Monitor** | Periodic status checks | Long-running processes |

### MS Options for Enterprise Service Hub

| Technology | Best For | This Demo |
|-----------|----------|-----------|
| **Azure Service Bus** | Enterprise messaging, transactions, ordering | ✅ Queues + Topics |
| **Azure Functions** | Event-driven compute, Service Bus triggers | ✅ Isolated .NET 8 |
| **Durable Functions** | Stateful workflows, orchestration | ✅ Order processing |
| **Azure Container Apps** | Microservices, APIs, background jobs | ✅ C# + Python apps |
| **Azure Event Grid** | Event routing, webhook delivery | Recommended add-on |
| **Azure API Management** | API gateway, rate limiting, policies | Recommended for prod |

---

## CI/CD Pipeline Flow

```
Developer
    │
    ├── Feature branch → PR to develop
    │       │
    │       ├── CI Pipeline (automatic)
    │       │   ├── .NET build + test + coverage
    │       │   ├── Python lint + test + coverage  
    │       │   ├── CodeQL SAST (C# + Python)
    │       │   ├── Bandit Python SAST
    │       │   ├── MS Defender container scan
    │       │   ├── Checkov IaC scan
    │       │   ├── Dependency review
    │       │   └── Bicep lint + validate
    │       │
    │       ├── CODEOWNERS review required
    │       └── Merge to develop
    │
    ├── PR: develop → main
    │       ├── All CI checks pass
    │       ├── 2 approvals required
    │       └── Merge to main
    │
    └── CD Pipeline (on main merge)
            ├── Build artifacts + container images
            ├── Deploy to DEV (automatic)
            │   └── Smoke tests
            ├── Deploy to STAGING (automatic)
            │   └── Integration tests
            └── Deploy to PROD (manual approval gate)
                └── Health checks
```

---

## SSDLC Best Practices Implemented

### Security Scanning (Shift-Left)

| Tool | Type | Target | Pipeline |
|------|------|--------|----------|
| **GitHub CodeQL** | SAST | C# & Python code | `codeql.yml` |
| **Bandit** | SAST | Python security | `ci.yml` |
| **MS Defender for Containers** | Container scan | Docker images | `ci.yml` |
| **Checkov** | IaC scan | Bicep templates | `ci.yml` |
| **Safety** | SCA | Python dependencies | `ci.yml` |
| **dotnet audit** | SCA | .NET dependencies | `ci.yml` |
| **Dependency Review** | SCA | All PRs | `dependency-review.yml` |
| **Dependabot** | Auto-update | All ecosystems | `dependabot.yml` |
| **GHAS Malware Scanning** | Malware detection | Commits & uploads | GitHub Advanced Security |
| **GHAS Vulnerability Scanning** | CVE detection | Code & dependencies | GitHub Advanced Security |

### Infrastructure Security

- **Private endpoints** for Key Vault and Service Bus (prod)
- **RBAC authorization** on Key Vault (no access policies)
- **Managed identities** on all compute (no stored credentials)
- **TLS 1.2 minimum** everywhere
- **NSG deny-all** with explicit allow rules
- **Soft delete + purge protection** on Key Vault
- **Azure AD auth only** on Service Bus (local auth disabled)
- **Zone redundancy** in production
- **Non-root containers** with minimal base images

### Code Quality

- **TreatWarningsAsErrors** in .NET projects
- **Ruff** linting for Python
- **Code coverage** thresholds (60% minimum)
- **PR template** with SSDLC checklist
- **CODEOWNERS** for mandatory review paths

---

## Testing Strategy

### Automated Test Types

| Level | C# Function App | C# Container App | Python API |
|-------|----------------|------------------|------------|
| **Unit** | xUnit + Moq + FluentAssertions | n/a | pytest |
| **Integration** | n/a | WebApplicationFactory | httpx AsyncClient |
| **Security** | CodeQL, dotnet audit | Defender, CodeQL | Bandit, Safety |
| **Infrastructure** | Bicep lint, Checkov | n/a | n/a |

### Tools to Explore for Automated Testing

| Tool | Purpose | Language |
|------|---------|----------|
| **xUnit** | Unit testing framework | C# |
| **Moq** | Mocking framework | C# |
| **FluentAssertions** | Readable assertions | C# |
| **WebApplicationFactory** | Integration testing | C# ASP.NET |
| **pytest** | Unit + integration testing | Python |
| **httpx** | Async HTTP testing | Python |
| **pytest-cov** | Code coverage | Python |
| **Playwright** | E2E/UI testing | Multi-language |
| **k6** | Load/performance testing | JavaScript |
| **Azure Load Testing** | Cloud-based load testing | Azure service |

---

## Custom GitHub Actions Runners

This repo includes two runner strategies for GitHub Actions — **GitHub-hosted larger runners** (managed by GitHub) and **self-hosted runners on Azure Container Instances** (managed by you). Both are production-ready with custom images built via ACR.

> **Architecture diagram:** Open [`docs/runner-architecture.drawio`](docs/runner-architecture.drawio) in [draw.io](https://app.diagrams.net) or the VS Code draw.io extension.

### Scenario Comparison

| | Scenario 1: GitHub Larger Hosted | Scenario 2: ACI Self-Hosted |
|---|---|---|
| **Runner location** | GitHub cloud infrastructure | Azure Container Instances |
| **Management** | Zero — GitHub manages everything | You manage image + ACI lifecycle |
| **Custom image** | No — GitHub's standard images | Yes — full control (Dockerfile) |
| **Network** | Optional VNET injection (Enterprise) | Runs inside your Azure VNET natively |
| **Scaling** | Automatic | Manual or scripted |
| **Cost model** | Per-minute billing (higher rate) | ACI billing (cheaper for long/heavy jobs) |
| **Best for** | Fast CI, zero-ops teams | Private network access, custom tools, compliance |

### Custom Runner Images

Both Ubuntu and Windows custom runner images are defined in `runners/` and built by the `runner-build-images.yml` workflow:

| Image | Base OS | Pre-installed Tools | Dockerfile |
|-------|---------|-------------------|------------|
| `github-runner-ubuntu` | Ubuntu 22.04 | .NET 8, Python 3.12, Node 20, Azure CLI, Docker CLI | [`runners/ubuntu/Dockerfile`](runners/ubuntu/Dockerfile) |
| `github-runner-windows` | Windows Server 2022 LTSC | .NET 8, Node 20, Azure CLI, Git | [`runners/windows/Dockerfile`](runners/windows/Dockerfile) |

Both images:
- Run as **non-root** users (`runner` / `ContainerUser`)
- Include the GitHub Actions runner agent (configurable version)
- Auto-register with GitHub on startup and deregister on shutdown
- Are tagged with `commit SHA` (immutable) + `latest`
- Are pushed to ACR (`acrssdlcdemo.azurecr.io`)

### Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Build Runner Images** | [`runner-build-images.yml`](.github/workflows/runner-build-images.yml) | Builds Ubuntu/Windows images via `az acr build`, pushes to ACR |
| **Runner Test — Larger Hosted** | [`runner-larger-hosted.yml`](.github/workflows/runner-larger-hosted.yml) | Tests GitHub-hosted runners (standard vs larger) with build time comparison |
| **Runner Test — ACI Self-Hosted** | [`runner-aci-selfhosted.yml`](.github/workflows/runner-aci-selfhosted.yml) | Tests self-hosted ACI runners with OIDC Azure connectivity |

### Setup Guide

#### Scenario 1: GitHub Larger Hosted Runners

1. Go to **Settings → Actions → Runners → New GitHub-hosted runner**
2. Choose OS (Linux/Windows), machine size (4/8/16/32/64 cores), and a label name
3. Trigger the workflow with that label:
   ```
   gh workflow run "Runner Test - GitHub Larger Hosted" -f runner_label=my-4core-runner
   ```

#### Scenario 2: ACI Self-Hosted Runners

```powershell
# 1. Build the custom image (triggers ACR build)
gh workflow run "Build Runner Images" -f build_ubuntu=true -f build_windows=false

# 2. Deploy runner to ACI (needs a GitHub PAT with repo + admin:org scope)
.\scripts\setup-aci-github-runner.ps1 `
    -GitHubOrg "ncheruvu-MSFT" `
    -GitHubRepo "az-github-ssdlc-demo" `
    -GitHubPAT $env:GITHUB_PAT `
    -ContainerImage "acrssdlcdemo.azurecr.io/github-runner-ubuntu:latest"

# 3. Verify runner is online
gh api repos/ncheruvu-MSFT/az-github-ssdlc-demo/actions/runners --jq '.runners[]'

# 4. Trigger the test workflow
gh workflow run "Runner Test - ACI Self-Hosted" -f run_on_selfhosted=true

# 5. Cleanup when done
az container delete -g rg-ssdlc-runners-dev -n aci-runner-01 --yes
```

### File Structure

```
runners/
├── ubuntu/
│   ├── Dockerfile          # Custom Ubuntu 22.04 runner image
│   └── entrypoint.sh       # Auto-register/deregister with GitHub
└── windows/
    ├── Dockerfile          # Custom Windows Server 2022 runner image
    └── entrypoint.ps1      # Auto-register/deregister with GitHub

scripts/
└── setup-aci-github-runner.ps1   # Deploy runner container to ACI

.github/workflows/
├── runner-build-images.yml       # Build & push runner images to ACR
├── runner-larger-hosted.yml      # Test larger hosted runners
└── runner-aci-selfhosted.yml     # Test ACI self-hosted runners
```

---

## Getting Started

### Prerequisites

- .NET 8 SDK
- Python 3.12+
- Azure CLI
- Docker Desktop
- Azure Functions Core Tools v4

### Local Development

```bash
# .NET Function App
cd src/FunctionApp
dotnet restore && dotnet run

# .NET Container App
cd src/ContainerApp
dotnet restore && dotnet run

# Python API
cd src/PythonApi
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000

# Run all tests
dotnet test SsdlcDemo.sln --collect:"XPlat Code Coverage"
cd tests/PythonApi.Tests && pytest --cov -v
```

### Deploy to Azure

```bash
# Login
az login

# Deploy dev environment
az deployment sub create \
  --location australiaeast \
  --template-file infra/main.bicep \
  --parameters infra/main.dev.bicepparam
```

### GitHub Repo Setup

1. **Enable GitHub Advanced Security** (secret scanning, code scanning)
2. **Create environments**: `dev`, `staging`, `production` (with approval on prod)
3. **Configure OIDC** for Azure: Create App Registration + Federated Credentials
4. **Set repository secrets**:
   - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - `AZURE_CLIENT_ID_PROD`, `AZURE_SUBSCRIPTION_ID_PROD`
   - `ACR_NAME`
5. **Apply branch protection** from `.github/branch-protection.json`
6. **Enable Dependabot** alerts and security updates
