# End-to-End SSDLC Demo Runbook

> **Audience**: Developers, architects, security leads  
> **Duration**: 45–60 minutes  
> **Prerequisites**: Azure subscription, GitHub account, VS Code with Copilot

---

## Demo Overview

This runbook walks through the complete Secure SDLC flow — from work item to production deployment — showing how GitHub Advanced Security, Copilot, and Azure work together.

```
ADO Epic → Backlog → Feature Assignment
    ↓
Copilot codes the feature (with architecture skills)
    ↓
Push → PR → 8 automated security scans
    ↓
Merge → CD deploys: dev → staging → (approve) → prod
    ↓
Full traceability: work item → commit → deploy
```

---

## Part 0: One-Time Setup (Before Demo Day)

### 0.1 Connect GitHub to Azure (OIDC Federation)

This creates an App Registration with federated identity credentials — **zero stored secrets**.

```powershell
# Run from repo root
.\scripts\setup-github-azure-oidc.ps1
```

**What it creates:**
| Resource | Purpose |
|----------|---------|
| Azure AD App Registration | `github-ssdlc-demo-oidc` |
| 5 Federated Credentials | dev, staging, production environments + main branch + PR |
| RBAC Roles | Contributor + User Access Administrator on subscription |
| GitHub Secrets | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME` |

**Verify:**
```powershell
# Check secrets were set
gh secret list --repo ncheruvu-MSFT/az-github-ssdlc-demo

# Check federated credentials
az ad app list --display-name github-ssdlc-demo-oidc --query "[0].appId" -o tsv
```

### 0.2 Connect ADO Boards to GitHub

1. Go to **ADO Project Settings** → **Boards** → **GitHub Connections**  
   `https://dev.azure.com/ncheruvu0468/NagaDevops/_settings/boards-external-integration`
2. Click **Connect GitHub** → Authorize `ncheruvu-MSFT/az-github-ssdlc-demo`
3. This enables `AB#` links: commits/PRs auto-link to ADO work items

### 0.3 Create Azure Container Registry

```powershell
az group create -n rg-ssdlcdemo-shared -l canadacentral
az acr create -n acrssdlcdemo -g rg-ssdlcdemo-shared --sku Basic --admin-enabled false
# Grant the OIDC app push/pull access
$clientId = az ad app list --display-name github-ssdlc-demo-oidc --query "[0].appId" -o tsv
$acrId = az acr show -n acrssdlcdemo --query id -o tsv
az role assignment create --assignee $clientId --role AcrPush --scope $acrId
```

### 0.4 Verify Copilot Instructions Are Loaded

Open VS Code in the repo. Copilot reads:
- `.github/copilot-instructions.md` — project-wide architecture standards
- `.github/instructions/*.instructions.md` — file-type-specific skills (Bicep, .NET, Python, workflows)

These ensure Copilot generates code that follows security patterns, naming conventions, and testing standards automatically.

---

## Part 1: Work Management — Epic to Task (5 min)

### Show the ADO Board

Open: `https://dev.azure.com/ncheruvu0468/NagaDevops/_boards/board/t/NagaDevops%20Team/Issues`

**Hierarchy already created:**
```
Epic #1: SSDLC Demo: Secure Cloud Deployment
└── Issue #2: GitHub Actions CI/CD with GHAS
    ├── Issue #3: Security scanning (Tasks: CodeQL, Trivy, Checkov, Bandit, Dependabot)
    ├── Issue #10: IaC deployment (Tasks: Bicep validate, OIDC, secrets, envs, deploy)
    ├── Issue #19: Traceability (Tasks: ADO-GH integration, PR template, SHA tags, audit)
    └── Issue #24: Monitoring (Tasks: App Insights, health endpoints, alert rules)
```

### Demo talking points:
- "Each Epic breaks into Issues (Basic template) or Features/User Stories (Agile template)"
- "Every Task maps to a concrete pull request"
- "AB# links in commits create automatic traceability"

---

## Part 2: Code a Feature with Copilot + Architecture Skills (15 min)

### 2.1 Pick a Work Item

Choose Issue #3 Task: **"Add Bandit Python SAST to security job"** (Task #7)

### 2.2 Create a Feature Branch

```bash
git checkout -b feature/add-bandit-scan
```

### 2.3 Ask Copilot to Implement

Open the CI workflow file and ask Copilot:

> **Prompt**: "Add a Bandit SAST scanning job for Python code to this CI workflow. Upload results as SARIF to GitHub Security tab. Follow the workflow instruction patterns."

**What to show the audience:**
1. Copilot reads `.github/instructions/workflows.instructions.md` automatically
2. It generates a job with correct `permissions`, pinned action versions, SARIF upload
3. It follows the parallel job pattern matching existing CI structure

### 2.4 Ask Copilot to Add a New API Endpoint

Open `src/PythonApi/app/main.py` and ask:

> **Prompt**: "Add a POST /orders endpoint that accepts an order with items and quantities, validates input, and returns a confirmation. Follow the project's Python patterns."

**What to show:**
1. Copilot reads `.github/instructions/python.instructions.md`
2. It creates Pydantic models for request/response validation
3. It uses `async def`, type hints, proper error handling
4. It does NOT hardcode anything or expose sensitive data in errors

### 2.5 Ask Copilot to Write Tests

> **Prompt**: "Write pytest tests for the new /orders endpoint. Cover happy path, validation errors, and empty items. Follow the project testing patterns."

**What to show:**
1. Uses `httpx.AsyncClient` (not `requests`)
2. Uses `@pytest.mark.asyncio`
3. Tests both success and error cases
4. Names follow `test_{endpoint}_{scenario}` convention

### 2.6 Ask Copilot to Add .NET Function

Open `src/FunctionApp/Functions/` and ask:

> **Prompt**: "Create a new HTTP-triggered Azure Function called OrderValidation that validates incoming order JSON and returns OK or BadRequest. Follow the .NET isolated worker patterns."

**What to show:**
1. Uses `[Function("OrderValidation")]` (not `[FunctionName]`)
2. Constructor injection with `ILogger<T>`
3. Input validation with model binding
4. Async/await pattern
5. No sensitive data in error responses

---

## Part 3: Push, PR & Security Scanning (10 min)

### 3.1 Commit with AB# Link

```bash
git add -A
git commit -m "feat: add order validation and Bandit scanning AB#7"
git push -u origin feature/add-bandit-scan
```

### 3.2 Create PR

```bash
gh pr create \
  --title "feat: add order validation and Bandit scan - AB#7" \
  --body "## Description
Implements order validation endpoint and Bandit SAST scanning.

Linked: AB#7 AB#3

## SSDLC Checklist
- [x] No secrets or credentials hardcoded
- [x] Input validation at system boundaries
- [x] Error handling doesn't expose sensitive info
- [x] Security scanning passes
- [x] Tests added with >60% coverage"
```

### 3.3 Show CI Pipeline Running

Navigate to **Actions** tab → show 8 parallel jobs:

| Job | What it does |
|-----|-------------|
| .NET Build + Test | Compiles, runs 17+ xUnit tests |
| Python Lint + Test | Ruff lint, pytest with coverage |
| CodeQL | SAST scan for C# and Python |
| Container Scan | Docker image vulnerability scan |
| IaC Scan (Checkov) | Bicep template security scan |
| Bandit Scan | Python-specific SAST |
| Dependency Review | Block PRs with vulnerable deps |
| Bicep Validate | Template compilation check |

### 3.4 Show GitHub Security Tab

Navigate to **Security** → **Code scanning alerts**:
- CodeQL findings with severity levels
- Bandit findings (if any)
- Remediation guidance
- Dependabot alerts for dependencies

### 3.5 Show Branch Protection

- PR requires all checks to pass
- PR requires CODEOWNERS review
- Stale reviews are dismissed

---

## Part 4: CD Pipeline — Deploy to Azure (10 min)

### 4.1 Merge the PR

After CI passes and reviews are approved:
```bash
gh pr merge --squash
```

### 4.2 Show CD Pipeline

The CD triggers automatically on main merge:

```
Build Artifacts
    ├── Publish .NET Function App
    ├── Build C# Container → ACR (tagged with SHA)
    └── Build Python API → ACR (tagged with SHA)
         ↓
Deploy to DEV (auto)
    ├── Bicep: infra/main.dev.bicepparam
    ├── Deploy Function App
    ├── Update Container App images
    └── Smoke test health endpoints
         ↓
Deploy to STAGING (auto)
    ├── Bicep: infra/main.staging.bicepparam
    └── Same deployment steps
         ↓
⏸ Manual Approval Gate
         ↓
Deploy to PRODUCTION (gated)
    ├── Bicep: infra/main.prod.bicepparam
    └── Full deployment with health verification
```

### 4.3 Key Points to Highlight

- **OIDC Auth**: No stored credentials — GitHub exchanges a token with Azure AD
- **Immutable Images**: Container tagged with `${{ github.sha }}` (exact code traceability)
- **Environment Gates**: Production requires manual approval
- **Same Bicep Templates**: All environments use identical IaC, different params

---

## Part 5: Infrastructure & Security Deep Dive (10 min)

### 5.1 Show Bicep Module Structure

```
infra/
├── main.bicep          ← Subscription-scope orchestrator
├── main.dev.bicepparam ← Dev: Basic SKUs, no private endpoints
├── main.prod.bicepparam← Prod: Premium SKUs, private endpoints, zone redundancy
└── modules/
    ├── networking.bicep   VNet 10.0.0.0/16 with 3 subnets + NSG
    ├── keyvault.bicep     RBAC auth, soft-delete, purge protection, PE
    ├── servicebus.bicep   Premium, Azure AD only, PE, dead-letter
    ├── monitoring.bicep   Log Analytics + App Insights + Alerts
    ├── functionapp.bicep  .NET 8 isolated, VNet integration, Managed Identity
    └── containerapp.bicep ACA env, non-root, health probes, auto-scale
```

### 5.2 Security Hardening Checklist

Show how Checkov validates these in CI:

| Control | Implementation |
|---------|---------------|
| Zero secrets | Managed Identity + Key Vault references |
| Network isolation | VNet + private endpoints + NSG deny-all |
| Encryption | TLS 1.2+, encryption at rest |
| Identity | Azure AD auth only, RBAC (no access policies) |
| Containers | Non-root USER, Alpine base, no capabilities |
| Monitoring | Diagnostics on every resource → Log Analytics |

---

## Part 6: Traceability — End-to-End Audit Trail (5 min)

### Show the complete chain:

1. **ADO Board**: Epic #1 → Issue #3 → Task #7  
2. **GitHub Commit**: `feat: add order validation AB#7` → auto-linked in ADO  
3. **Pull Request**: PR #N with SSDLC checklist + CI results  
4. **CI Results**: 8 security scans passed, coverage >60%  
5. **CD Deployment**: Container image `acr.../ssdlcdemo:abc123` (SHA = commit)  
6. **Azure Portal**: Running container with same image tag traceable to exact commit

> "From work item to production in a single auditable chain — no manual steps, no stored credentials, every change scanned by 8 security tools."

---

## Quick Reference Commands

```powershell
# ─── One-Time Setup ──────────────────────────────────
.\scripts\setup-github-azure-oidc.ps1     # OIDC federation
.\scripts\setup-ado-boards.ps1            # ADO work items

# ─── Feature Development ─────────────────────────────
git checkout -b feature/my-feature
# ... use Copilot to code (skills auto-load) ...
git commit -m "feat: description AB#<work-item-id>"
git push -u origin feature/my-feature
gh pr create --title "feat: description - AB#<id>"

# ─── Verify ──────────────────────────────────────────
gh run list --limit 5                      # CI/CD status
gh pr checks                               # PR check status
az deployment sub list -o table            # Azure deployments
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| OIDC login fails in CD | Check federated credential subjects match exactly (`repo:owner/name:environment:env`) |
| AB# links don't show in ADO | Connect GitHub repo in ADO Project Settings → Boards → GitHub Connections |
| Copilot ignores instructions | Ensure `.github/copilot-instructions.md` exists and VS Code has Copilot 1.200+ |
| Bicep deploy fails | Run `az bicep build -f infra/main.bicep` locally first |
| ACR push denied | Verify AcrPush role assigned to OIDC app on ACR resource |
| Container App not updating | Check image tag matches — CD uses `${{ github.sha }}` |

---

*Last updated: April 2026*
