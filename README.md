# Azure Enterprise SSDLC Demo

Enterprise-grade cloud deployment demonstrating **Azure Verified Module** patterns, **SSDLC best practices**, and **CI/CD from GitHub** with automated testing.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Private Repository                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ CodeQL   │  │ Trivy    │  │ Bandit   │  │ Checkov  │  │ Dep      │ │
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
    │       │   ├── Trivy container scan
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
| **Trivy** | Container scan | Docker images | `ci.yml` |
| **Checkov** | IaC scan | Bicep templates | `ci.yml` |
| **Safety** | SCA | Python dependencies | `ci.yml` |
| **dotnet audit** | SCA | .NET dependencies | `ci.yml` |
| **Dependency Review** | SCA | All PRs | `dependency-review.yml` |
| **Dependabot** | Auto-update | All ecosystems | `dependabot.yml` |

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
| **Security** | CodeQL, dotnet audit | Trivy, CodeQL | Bandit, Safety |
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
