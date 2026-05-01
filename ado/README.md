# Azure DevOps — SSDLC Reference Implementation

> Enterprise Secure Software Development Lifecycle (SSDLC) running in **Azure DevOps Pipelines**
> sourced from the **same GitHub repository** (`ncheruvu-MSFT/az-github-ssdlc-demo`).
> No repo mirroring — ADO pipelines pull directly from GitHub via a service connection.
> GitHub handles: source code, PRs, Dependabot, GitHub Actions workflows.
> ADO handles: pipeline orchestration, environments, approvals, boards, artifacts.

## Pipeline Status Badges

<!-- Replace YOUR_ORG and YOUR_PROJECT with actual values -->
<!-- Badges auto-generated from: Project Settings → Pipelines → (pipeline) → ⋯ → Status badge -->

| Pipeline | Status | Description |
|----------|--------|-------------|
| CI | [![CI](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/build/status/SSDLC%2FCI?branchName=main)](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_build/latest?definitionId=1&branchName=main) | Build, test, lint, coverage |
| CD | [![CD](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/build/status/SSDLC%2FCD?branchName=main)](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_build/latest?definitionId=2&branchName=main) | Deploy: dev → staging → prod |
| Security | [![Security](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/build/status/SSDLC%2FSecurity?branchName=main)](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_build/latest?definitionId=3&branchName=main) | MSDO + GHAzDO (SAST/SCA/Secrets) |
| Supply Chain | [![Supply Chain](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/build/status/SSDLC%2FSupply-Chain-Security?branchName=main)](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_build/latest?definitionId=4&branchName=main) | Container patching + SBOM |
| Staging Gate | [![Staging Gate](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_apis/build/status/SSDLC%2FStaging-Gate?branchName=main)](https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_build/latest?definitionId=5&branchName=main) | Release readiness Go/No-Go |

## Reports & Analytics

### Built-in Pipeline Reports (No Setup Required)

ADO provides rich analytics out of the box when pipelines publish test results and coverage:

| Report | Location | What It Shows |
|--------|----------|---------------|
| **Pipeline pass rate** | Pipelines → Analytics | % successful runs over time |
| **Pipeline duration** | Pipelines → Analytics | Build time trends, P50/P80/P95 |
| **Test pass rate** | Pipelines → Analytics → Tests | Test success trends per pipeline |
| **Test duration** | Pipelines → Analytics → Tests | Slow test identification |
| **Code coverage** | Pipelines → (run) → Code Coverage | Line/branch coverage per build |
| **Flaky tests** | Test Plans → Runs → Analytics | Auto-detected unreliable tests |

### Security Reports (GHAzDO — GitHub Advanced Security for ADO)

| Report | Location | What It Shows |
|--------|----------|---------------|
| **Dependency alerts** | Repos → Advanced Security | CVEs in NuGet/pip/npm packages |
| **Code scanning** | Repos → Advanced Security | CodeQL SAST findings |
| **Secret scanning** | Repos → Advanced Security | Leaked secrets/tokens |
| **Alert trends** | Repos → Advanced Security → Overview | Open/closed alerts over time |

### Custom Reports in This Repo

| Artifact | Pipeline | Description |
|----------|----------|-------------|
| `staging-gate-report.md` | Staging-Gate | Go/No-Go readiness with pipeline status + work items |
| `container-scan-results/` | CI | Trivy SARIF reports per container image |
| `iac-scan-results/` | CI | Checkov SARIF for Bicep infrastructure |
| `sbom-*.spdx.json` | Supply-Chain-Security | SPDX SBOM per container image |

### How to Demo ADO Reports

```bash
# 1. Trigger CI pipeline
az pipelines run --name CI --branch main

# 2. After CI completes, check test analytics
#    → Pipelines → CI → Analytics tab → Test pass rate

# 3. Trigger Security pipeline
az pipelines run --name Security --branch main

# 4. Check GHAzDO alerts (if enabled)
#    → Repos → Advanced Security → Alerts

# 5. Run Staging Gate for release readiness report
az pipelines run --name Staging-Gate --branch main
#    → Download artifact "staging-gate-report" for Go/No-Go markdown

# 6. View deployment history
#    → Environments → dev/staging/production → Deployment history
```

## Quick Start — New ADO Project Setup

### 1. Create the ADO Project

```bash
# Install/login Azure DevOps CLI extension
az extension add --name azure-devops
az devops configure --defaults organization=https://dev.azure.com/YOUR_ORG

# Create project with Git + Agile
az devops project create \
  --name "ssdlc-demo" \
  --description "Enterprise SSDLC reference — ADO Pipelines + GitHub Copilot" \
  --process Agile \
  --source-control git \
  --visibility private

az devops configure --defaults project=ssdlc-demo
```

### 2. Create GitHub Service Connection

ADO pipelines will use the **same GitHub repo** (`ncheruvu-MSFT/az-github-ssdlc-demo`) as source — no separate ADO repo needed.

```bash
# Create GitHub service connection (PAT or GitHub App)
# Option A: Personal Access Token
az devops service-endpoint github create \
  --github-url https://github.com/ncheruvu-MSFT/az-github-ssdlc-demo \
  --name "github-ssdlc-demo" \
  --org https://dev.azure.com/YOUR_ORG \
  --project ssdlc-demo

# Option B: GitHub App (recommended for orgs)
# Install the Azure Pipelines GitHub App:
# https://github.com/apps/azure-pipelines → Install → Select repo
```

### 3. Create Azure Service Connections (Workload Identity Federation)

```bash
# Dev/Staging service connection — Workload Identity Federation (OIDC, no secrets)
az devops service-endpoint create --service-endpoint-configuration ado/config/service-connection-dev.json

# Production service connection (separate identity)
az devops service-endpoint create --service-endpoint-configuration ado/config/service-connection-prod.json
```

> **Workload Identity Federation** is the ADO equivalent of GitHub OIDC.
> No client secrets stored — the pipeline authenticates via federated token exchange.

### 4. Create Variable Groups

```bash
# Shared variables (non-secret)
az pipelines variable-group create \
  --name "ssdlc-shared" \
  --variables \
    DEPLOY_REGION=australiaeast \
    DOTNET_VERSION=8.0.x \
    PYTHON_VERSION_GENERAL=3.12 \
    PYTHON_VERSION_AI=3.11

# Dev environment secrets (linked to Key Vault recommended)
az pipelines variable-group create \
  --name "ssdlc-dev" \
  --variables \
    ACR_NAME=youracr \
    FOUNDRY_PROJECT_ENDPOINT=https://your-project.api.azureml.ms \
    FOUNDRY_MODEL_NAME=gpt-4o \
    APPINSIGHTS_CONNECTION_STRING=InstrumentationKey=xxx
```

### 5. Create Environments with Approvals

```bash
# Dev — no approval
az devops invoke --area distributedtask --resource environments \
  --route-parameters project=ssdlc-demo \
  --http-method POST --in-file ado/config/env-dev.json

# Staging — requires 1 approval
# Production — requires 2 approvals + business hours check
```

> Configure approvals in **Project Settings → Environments → Approvals and checks**

### 6. Create Pipelines (from GitHub repo)

All pipelines point to the **same GitHub repository** — no mirroring required.

```bash
# GitHub repo reference (uses the service connection from step 2)
GH_REPO="ncheruvu-MSFT/az-github-ssdlc-demo"
GH_SC="github-ssdlc-demo"  # GitHub service connection name

# CI Pipeline
az pipelines create --name "CI" \
  --yml-path ado/pipelines/ci.yml \
  --repository "$GH_REPO" \
  --repository-type github \
  --service-connection "$GH_SC" \
  --branch main

# CD Pipeline
az pipelines create --name "CD" \
  --yml-path ado/pipelines/cd.yml \
  --repository "$GH_REPO" \
  --repository-type github \
  --service-connection "$GH_SC" \
  --branch main

# Security Pipeline
az pipelines create --name "Security Scan" \
  --yml-path ado/pipelines/security.yml \
  --repository "$GH_REPO" \
  --repository-type github \
  --service-connection "$GH_SC" \
  --branch main

# Supply Chain Security (Dependabot + Copacetic)
az pipelines create --name "Supply Chain Security" \
  --yml-path ado/pipelines/supply-chain-security.yml \
  --repository "$GH_REPO" \
  --repository-type github \
  --service-connection "$GH_SC" \
  --branch main

# AI Pipelines (P1-P4)
az pipelines create --name "AI-P1-DevOps-Model" --yml-path ado/pipelines/ai-p1-devops-model.yml --repository "$GH_REPO" --repository-type github --service-connection "$GH_SC" --branch main
az pipelines create --name "AI-P2-Agent-Ops"    --yml-path ado/pipelines/ai-agent-ops.yml      --repository "$GH_REPO" --repository-type github --service-connection "$GH_SC" --branch main
az pipelines create --name "AI-P3-FoundryIQ"    --yml-path ado/pipelines/ai-p3-foundryiq.yml   --repository "$GH_REPO" --repository-type github --service-connection "$GH_SC" --branch main
az pipelines create --name "AI-P4-MCP-Tools"    --yml-path ado/pipelines/ai-p4-mcp-tools.yml   --repository "$GH_REPO" --repository-type github --service-connection "$GH_SC" --branch main

# Staging Gate
az pipelines create --name "Staging Gate" \
  --yml-path ado/pipelines/staging-gate.yml \
  --repository "$GH_REPO" \
  --repository-type github \
  --service-connection "$GH_SC" \
  --branch main
```

### 7. Configure Branch Policies

Since the repo lives on GitHub, branch protection is managed in **GitHub Settings → Branches**.
ADO build status checks are reported back to GitHub PRs via the GitHub service connection.

```bash
# ADO build validation is auto-configured when using --repository-type github.
# The pipeline status is posted back as a GitHub commit status / check run.
#
# On the GitHub side, configure branch protection:
# Settings → Branches → main → Require status checks:
#   - "CI" (ADO pipeline)
#   - "Security Scan" (ADO pipeline)
#
# ADO-side: you can also add a build validation policy for the GitHub repo:
az repos policy build create --branch main \
  --build-definition-id <CI_PIPELINE_ID> \
  --blocking true \
  --enabled true \
  --queue-on-source-update-only true \
  --valid-duration 720 \
  --repository-id <GITHUB_REPO_EXTERNAL_ID>
```

### 8. Enable GitHub Advanced Security for Azure DevOps (GHAzDO)

1. **Project Settings → Repos → Advanced Security** → Enable
2. This provides: CodeQL scanning, Dependency scanning, Secret scanning
3. Results appear in **Repos → Advanced Security** tab (same UX as GitHub)

### 9. Install GitHub Copilot for Azure DevOps

1. Go to **Organization Settings → Extensions → Browse marketplace**
2. Search "GitHub Copilot" → Install
3. Assign licenses to team members
4. Copilot works in:
   - **VS Code** (with Azure Repos extension)
   - **Visual Studio** (with ADO connected)
   - **ADO Pull Request summaries** (auto-generated)
   - **ADO Work Item suggestions** (AI-assisted)

---

## GitHub → ADO Feature Mapping

| GitHub Feature | ADO Equivalent | Notes |
|---|---|---|
| GitHub Actions | **Azure Pipelines** | YAML-based, multi-stage |
| OIDC (`id-token: write`) | **Workload Identity Federation** (Service Connection) | No stored secrets |
| CodeQL SAST | **GHAzDO CodeQL** or MSDO `MicrosoftSecurityDevOps@1` | Same engine |
| Dependabot SCA | **GHAzDO Dependency Scanning** | Automatic alerts |
| Secret Scanning | **GHAzDO Secret Scanning** | Push protection supported |
| GitHub Security tab | **ADO Advanced Security tab** | Same SARIF-based |
| Branch Protection | **Branch Policies** | Approvals, build gates, linked work items |
| Environments + Gates | **ADO Environments** + Approvals & Checks | Business hours, exclusive lock |
| `actions/checkout@v4` | `checkout: self` (built-in) | Automatic |
| `actions/upload-artifact` | `PublishPipelineArtifact@1` | Pipeline artifacts |
| GitHub Issues | **ADO Work Items** (User Stories, Bugs, Tasks) | Boards, Sprints |
| PR Template | **`.azuredevops/pull_request_template.md`** | Same markdown |
| Dependabot auto-merge | **ADO auto-complete** + policy-based merge | Via branch policies |
| `workflow_run` trigger | **Pipeline resources** (`pipelines:` trigger) | Cross-pipeline triggers |
| `concurrency` groups | **Exclusive lock** on Environment | Deployment serialization |
| GitHub Copilot (native) | **GitHub Copilot for ADO** (extension) | PR summaries, code suggestions |
| Copilot Coding Agent | **Copilot in VS Code + ADO Repos** | Branch → PR flow |
| Notation signing | Same CLI in script task | Identical process |
| GitHub Container Registry | **Azure Container Registry** | Already used |
| `dorny/test-reporter` | `PublishTestResults@2` | Built-in ADO task |
| Code coverage PR comment | `PublishCodeCoverageResults@2` | Built-in ADO task |

---

## Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────┐
│         Azure DevOps Pipelines (GitHub repo source)          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  CI Pipeline ──► Security Pipeline ──► CD Pipeline           │
│  (Build+Test)    (MSDO/GHAzDO)        (Dev→Stg→Prod)        │
│                                                              │
│  Supply Chain Security:                                      │
│  Trivy Scan ─► Copa Patch ─► Push to ACR ─► Sign (Notation) │
│                                                              │
│  AI Pipelines:                                               │
│  P1 DevOps Model ─► Prompt Eval ─► Content Safety ─► Gate   │
│  P2 Agent Ops    ─► Agent Eval  ─► Red Team       ─► Gate   │
│  P3 FoundryIQ    ─► Policy Val  ─► Model Eval     ─► Gate   │
│  P4 MCP Tools    ─► Schema Val  ─► Tool Eval      ─► Gate   │
│                                                              │
│  Staging Gate ─► Release Readiness Report ─► Go/No-Go       │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  Source: github.com/ncheruvu-MSFT/az-github-ssdlc-demo      │
│  Environments: dev (auto) → staging (1 approval) → prod (2) │
│  Service Connections: Workload Identity Federation (OIDC)    │
│  Variable Groups: ssdlc-shared, ssdlc-dev, ssdlc-prod       │
│  GitHub Copilot: PR summaries, code suggestions, reviews     │
└──────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
ado/
├── README.md                          # This file
├── pipelines/
│   ├── ci.yml                         # CI: build, test, lint, coverage
│   ├── cd.yml                         # CD: dev → staging → prod
│   ├── security.yml                   # MSDO + GHAzDO scanning
│   ├── supply-chain-security.yml      # Dependabot + Copacetic container patching
│   ├── staging-gate.yml               # Release readiness gate
│   ├── ssdlc-report.yml               # Consolidated compliance report
│   ├── ai-agent-ops.yml               # P2: Agent Model pipeline
│   ├── ai-p1-devops-model.yml         # P1: DevOps Model pipeline
│   ├── ai-p3-foundryiq.yml            # P3: FoundryIQ pipeline
│   ├── ai-p4-mcp-tools.yml            # P4: MCP Tools pipeline
│   └── templates/                     # Reusable pipeline templates
│       ├── dotnet-build.yml           # .NET build + test template
│       ├── python-build.yml           # Python build + test template
│       ├── azure-deploy.yml           # Azure deployment template
│       ├── container-build.yml        # Container build + sign template
│       └── health-check.yml           # Post-deploy health check
├── config/
│   ├── branch-policies.json           # Branch policy configuration
│   └── variable-groups.md             # Variable group documentation
└── .azuredevops/
    └── pull_request_template.md       # PR template with SSDLC checklist
```
