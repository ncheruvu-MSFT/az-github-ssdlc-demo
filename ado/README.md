# Azure DevOps — SSDLC Reference Implementation

> Enterprise Secure Software Development Lifecycle (SSDLC) running entirely in **Azure DevOps Pipelines** with **GitHub Copilot** as an AI coding assistant add-on.

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

### 2. Push This Repo

```bash
# Add ADO remote
git remote add ado https://dev.azure.com/YOUR_ORG/ssdlc-demo/_git/ssdlc-demo
git push ado main
git push ado develop
```

### 3. Create Service Connections (Workload Identity Federation)

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

### 6. Create Pipelines

```bash
# CI Pipeline
az pipelines create --name "CI" \
  --yml-path ado/pipelines/ci.yml \
  --repository ssdlc-demo \
  --repository-type tfsgit \
  --branch main

# CD Pipeline
az pipelines create --name "CD" \
  --yml-path ado/pipelines/cd.yml \
  --repository ssdlc-demo \
  --repository-type tfsgit \
  --branch main

# Security Pipeline
az pipelines create --name "Security Scan" \
  --yml-path ado/pipelines/security.yml \
  --repository ssdlc-demo \
  --repository-type tfsgit \
  --branch main

# AI Pipelines (P1-P4)
az pipelines create --name "AI-P1-DevOps-Model" --yml-path ado/pipelines/ai-p1-devops-model.yml --repository ssdlc-demo --repository-type tfsgit --branch main
az pipelines create --name "AI-P2-Agent-Ops"    --yml-path ado/pipelines/ai-agent-ops.yml      --repository ssdlc-demo --repository-type tfsgit --branch main
az pipelines create --name "AI-P3-FoundryIQ"    --yml-path ado/pipelines/ai-p3-foundryiq.yml   --repository ssdlc-demo --repository-type tfsgit --branch main
az pipelines create --name "AI-P4-MCP-Tools"    --yml-path ado/pipelines/ai-p4-mcp-tools.yml   --repository ssdlc-demo --repository-type tfsgit --branch main

# Staging Gate
az pipelines create --name "Staging Gate" \
  --yml-path ado/pipelines/staging-gate.yml \
  --repository ssdlc-demo \
  --repository-type tfsgit \
  --branch main
```

### 7. Configure Branch Policies

```bash
# Require PR for main branch
az repos policy create --branch main \
  --blocking true \
  --enabled true \
  --policy-type approverCount \
  --settings '{"minimumApproverCount": 1, "creatorVoteCounts": false}'

# Require CI build to pass
az repos policy build create --branch main \
  --build-definition-id <CI_PIPELINE_ID> \
  --blocking true \
  --enabled true \
  --queue-on-source-update-only true \
  --valid-duration 720
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
│                    Azure DevOps Pipelines                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  CI Pipeline ──► Security Pipeline ──► CD Pipeline           │
│  (Build+Test)    (MSDO/GHAzDO)        (Dev→Stg→Prod)        │
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
│   ├── staging-gate.yml               # Release readiness gate
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
