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
│   │   ├── dependency-review.yml     # Dependency vulnerability review
│   │   ├── dependabot-auto-merge.yml # Auto-merge patch Dependabot PRs
│   │   ├── staging-gate.yml          # Staging go/no-go release report
│   │   ├── ado-copilot-bridge.yml    # ADO → GitHub Copilot Agent bridge
│   │   └── ai-agent-ops.yml         # AI Agent Ops: eval + red team pipeline
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
│   │   ├── host.json, time
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
│   └── AIAgent/                      # AI Agent Ops (Azure AI Foundry)
│       ├── create_agent.py           # Agent creation + deployment
│       ├── run_agent.py              # Test existing agents
│       ├── agent_eval.py             # Quality evaluation (6 metrics)
│       ├── red_team.py               # Security red team testing
│       ├── observability.py          # OpenTelemetry tracing
│       └── requirements.txt
├── tests/
│   ├── FunctionApp.Tests/            # xUnit + FluentAssertions + Moq
│   ├── ContainerApp.Tests/           # Integration tests (WebApplicationFactory)
│   ├── PythonApi.Tests/              # pytest + httpx + coverage
│   └── AIAgent.Tests/                # AI Agent module tests
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
│       ├── containerapp.bicep        # ACA environment + C# + Python apps
│       └── aifoundry.bicep           # Azure AI Services + GPT-4o deployment
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
    │Notation sign container images (supply chain)
            ├── Deploy to DEV (automatic)
            │   └── Smoke tests
            ├── Deploy to STAGING (automatic)
            │   └── Staging gate report (go/no-go)
            └── Deploy to PROD (manual approval gate)
                └── Health checks + Teams notification (automatic)
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
| **Notation** | Image signing | Container images | `cd.yml` |
| **Safety** | SCA | Python dependencies | `ci.yml` |
| **dotnet audit** | SCA | .NET dependencies | `ci.yml` |
| **Dependency Review** | SCA | All PRs | `dependency-review.yml` |
| **Dependabot** | Auto-update | All ecosystems | `dependabot.yml` |
| **GHAS Malware Scanning** | Malware detection | Commits & uploads | GitHub Advanced Security |
| **GHAS Vulnerability Scanning** | CVE detection | Code & dependencies | GitHub Advanced Security |
| **AI Red Team** | Safety testing | AI Agent responses | `ai-agent-ops.yml` |
| **AI Evaluation** | Quality metrics | AI Agent behavior | `ai-agent-ops.yml` |

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
   - `TEAMS_WEBHOOK_URL` (optional — for Teams deployment notifications)
5. **Apply branch protection** from `.github/branch-protection.json`
6. **Enable Dependabot** alerts and security updates

---

## ADO ↔ GitHub Integration

### Work Item Traceability

Azure DevOps Boards links to GitHub via `AB#<id>` references in commits and PRs:

```bash
git commit -m "feat: add input validation AB#32"
```

This creates bidirectional traceability: ADO work item → GitHub commit → PR → CI/CD results → deployment.

### ADO → Copilot Agent Bridge

The `ado-copilot-bridge.yml` workflow enables ADO work items to trigger GitHub Copilot Coding Agent:

1. ADO work item dispatches a `repository_dispatch` event to the GitHub repo
2. GitHub Copilot Agent picks up the task and creates a PR
3. CI validates the PR automatically
4. Human reviewer merges

### Staging Gate Report

The `staging-gate.yml` workflow generates a release readiness report before production:

- Verifies all CI checks passed
- Checks container image signatures (Notation)
- Validates infrastructure deployment status
- Produces a go/no-go summary in GitHub Actions

---

## AI Agent Ops (Microsoft Foundry)

This demo includes an **AI Agent CI/CD pipeline** using the Microsoft Agent Framework + Azure AI Foundry, demonstrating SSDLC practices for AI/ML workloads.

### AI Agent Lifecycle

```
Create Agent ──► Test Agent ──► Evaluate Quality ──► Red Team Security ──► Verify Prod
   (Dev)          (Dev)          (Staging)             (Staging)            (Production)
```

### Pipeline: `ai-agent-ops.yml`

| Stage | Environment | Action | Quality Gate |
|-------|-------------|--------|-------------|
| **Build** | CI | Syntax validation, unit tests, artifact upload | Tests pass |
| **Deploy** | Dev | Create/update agent via Azure AI Foundry | Agent responds |
| **Evaluate** | Staging | Run evaluation metrics (6 built-in evaluators) | Metrics recorded |
| **Red Team** | Staging | Security attack simulation (7 safety criteria) | No critical findings |
| **Verify** | Production | Smoke test production agent | Agent healthy |

### Evaluation Metrics

| Category | Metric | Description |
|----------|--------|-------------|
| **System** | Task Completion | Did the agent complete the task? |
| **System** | Task Adherence | Did the agent follow instructions? |
| **System** | Intent Resolution | Did the agent understand the user's intent? |
| **RAG** | Groundedness | Are responses grounded in source data? |
| **RAG** | Relevance | Are responses relevant to the query? |
| **Process** | Tool Call Accuracy | Did the agent call tools correctly? |

### Red Team Security Testing

| Risk Category | Evaluator | Purpose |
|---------------|-----------|---------|
| **Prohibited Actions** | `builtin.prohibited_actions` | Agent refuses harmful requests |
| **Sensitive Data Leakage** | `builtin.sensitive_data_leakage` | No credential/PII exposure |
| **Self Harm** | `builtin.self_harm` | Content safety |
| **Violence** | `builtin.violence` | Content safety |
| **Sexual** | `builtin.sexual` | Content safety |
| **Hate/Unfairness** | `builtin.hate_unfairness` | Bias and fairness |
| **Task Adherence** | `builtin.task_adherence` | Agent stays on-task under attack |

Attack strategies: Flip, Base64 (extensible to ROT13, UnicodeConfusable, CharSwap, Morse, Leetspeak, Binary).

### AI Agent Source Files

```
src/AIAgent/
├── create_agent.py      # Create agent in Azure AI Foundry
├── run_agent.py         # Query existing agent (MCP approval handling)
├── agent_eval.py        # Evaluation with 6 built-in metrics
├── red_team.py          # Red team security testing (7 safety criteria)
├── observability.py     # OpenTelemetry + Azure Monitor tracing
├── requirements.txt     # Production dependencies
└── requirements-dev.txt # Dev/test dependencies
```

### Infrastructure

The `infra/modules/aifoundry.bicep` module provisions:
- **Azure AI Services** (Cognitive Services account)
- **GPT-4o** model deployment (GlobalStandard SKU)
- Diagnostic settings → Log Analytics

Set `deployAIFoundry=true` in `.bicepparam` files to enable.

---

## Demo Walkthrough

### Quick Demo Flow (15 min)

1. **Show ADO Board** — Sprint planning with work items linked to GitHub
2. **Create a feature branch** → push code → open PR
3. **Watch CI run** — 8 parallel checks (build, test, CodeQL, Defender, Checkov, etc.)
4. **Show Security tab** — CodeQL findings, Dependabot alerts, secret scanning
5. **Merge to main** → CD auto-deploys to dev → staging → manual gate → prod
6. **Show staging gate report** — go/no-go summary
7. **Verify health endpoints** — `/health`, `/api/hello`, `/api/time`

### API Endpoints Reference

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Container App (C#) | `GET /api/hello?name=Demo` | Hello world with input validation |
| Container App (C#) | `GET /api/time` | UTC time endpoint |
| Container App (C#) | `GET /api/info` | Environment info |
| Container App (C#) | `GET /health` | Health check |
| Python API | `GET /api/hello?name=Demo` | Hello world |
| Python API | `POST /api/echo` | Echo JSON body |
| Python API | `GET /api/info` | Environment info |
| Python API | `GET /health` | Health check |
| Function App | `GET /api/hello?name=Demo` | Hello world |
| Function App | `GET /api/health` | Health check |
   - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - `AZURE_CLIENT_ID_PROD`, `AZURE_SUBSCRIPTION_ID_PROD`
   - `ACR_NAME`
5. **Apply branch protection** from `.github/branch-protection.json`
6. **Enable Dependabot** alerts and security updates
