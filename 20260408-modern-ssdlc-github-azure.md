# Modern Secure SDLC with GitHub Advanced Security & Azure

**Building a Production-Grade DevSecOps Pipeline from Code to Cloud**

---

## Introduction

The modern software development lifecycle (SDLC) demands security at every stage — not bolted on at the end, but woven into the development workflow from the first line of code. This post walks through a **complete Secure SDLC (SSDLC)** implementation using **GitHub Advanced Security**, **GitHub Actions CI/CD**, and **Azure** as the cloud platform, with work tracking via **Azure DevOps Boards** or **GitHub Issues**.

The companion repository [az-github-ssdlc-demo](https://github.com/ncheruvu-MSFT/az-github-ssdlc-demo) demonstrates every pattern discussed here with working code, pipelines, and infrastructure-as-code.

![Architecture Diagram](../diagrams/20260408-modern-ssdlc-github-architecture.drawio)

---

## Architecture Overview

The architecture spans six key areas:

| Layer | Components | Purpose |
|-------|-----------|---------|
| **Work Management** | ADO Boards / GitHub Issues | Sprint planning, backlog, task tracking |
| **GitHub Platform** | Repos, PRs, Branch Protection | Source control with enforced quality gates |
| **GitHub Advanced Security** | CodeQL, Secret Scanning, Dependabot | Shift-left security scanning |
| **CI/CD Pipeline** | GitHub Actions (CI + CD) | Automated build, test, scan, deploy |
| **Azure Platform** | Functions, Container Apps, Service Bus | Cloud compute and messaging |
| **Infrastructure as Code** | Bicep (Azure Verified Modules) | Repeatable, auditable deployments |

---

## 1. Work Management & Planning

### Choosing Your Board: ADO vs GitHub

Both options integrate seamlessly with GitHub repositories:

**Azure DevOps Boards**
- Epics → Features → User Stories → Tasks hierarchy
- Sprint planning with velocity tracking and burndown charts
- Kanban boards with WIP limits and cumulative flow
- **AB# links** connect ADO work items to GitHub commits and PRs

**GitHub Issues & Projects**
- Lightweight issue tracking with labels and milestones
- GitHub Projects (v2) with custom fields, views, and automations
- Native integration — issues auto-close on PR merge
- Roadmap and timeline views built in

**Integration Pattern:** Use `AB#1234` in commit messages or PR descriptions to link GitHub activity back to ADO work items. This creates full traceability from requirement → code → deployment.

```
git commit -m "feat: add Service Bus processor AB#1234"
```

---

## 2. GitHub Platform & Branch Protection

### Repository Governance

The repository enforces security through configuration-as-code:

**Branch Protection Rules**
- Require 2 approvals for merges to `main`
- Require all status checks (CI, CodeQL, dependency review) to pass
- Require signed commits
- Dismiss stale reviews on new pushes
- Restrict who can push to `main`

**CODEOWNERS** assigns mandatory reviewers based on file paths:

```
# .github/CODEOWNERS
*.bicep    @infra-team
*.cs       @dotnet-team
*.py       @python-team
/infra/    @security-team @infra-team
```

**PR Template** includes an SSDLC checklist that developers must verify:

- [ ] No secrets or credentials hardcoded
- [ ] Input validation at system boundaries
- [ ] Error handling doesn't expose sensitive info
- [ ] Security scanning passes (CodeQL, Bandit, Defender)
- [ ] Code coverage meets threshold (>60%)

---

## 3. GitHub Advanced Security (GHAS)

GHAS provides six pillars of automated security scanning:

### CodeQL — Static Application Security Testing (SAST)

CodeQL analyzes C# and Python source code on every PR, detecting:
- SQL injection, XSS, path traversal
- Insecure deserialization
- Hardcoded credentials
- Improper error handling

```yaml
# .github/workflows/codeql.yml
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: csharp, python
    queries: security-and-quality
```

### Secret Scanning with Push Protection

Prevents secrets from ever reaching the repository:
- Scans for 200+ secret patterns (API keys, tokens, certificates)
- **Push protection** blocks commits containing detected secrets *before* they're pushed
- Custom patterns for organization-specific secrets

### Dependabot

Automated dependency management across all ecosystems:

```yaml
# .github/dependabot.yml
updates:
  - package-ecosystem: "nuget"
    directory: "/src/FunctionApp"
    schedule: { interval: "weekly" }
  - package-ecosystem: "pip"
    directory: "/src/PythonApi"
    schedule: { interval: "weekly" }
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
```

### Dependency Review

Blocks PRs that introduce packages with known vulnerabilities. Runs on every PR via `actions/dependency-review-action`.

### Security Alerts Dashboard

All findings surface in the repository's **Security** tab with:
- Severity classification (Critical / High / Medium / Low)
- Remediation guidance
- Auto-fix suggestions for Dependabot alerts
- Dismissal audit trail

### Malware Scanning

GHAS scans artifacts and dependencies for known malware patterns:
- Detects malicious packages in npm, PyPI, and NuGet ecosystems
- Flags typosquatting and dependency confusion attacks
- Alerts on compromised upstream packages before they reach production

### Vulnerability Scanning

Beyond CodeQL SAST, GHAS provides comprehensive vulnerability detection:
- Automated security advisories for known CVEs across all dependency ecosystems
- Copilot Autofix suggests remediation code for detected vulnerabilities
- Integration with GitHub Security Advisories database for real-time threat intelligence

---

## 4. CI/CD Pipeline — GitHub Actions

### CI Pipeline (on every PR)

The CI pipeline runs **eight parallel checks**:

| Job | Tool | Purpose |
|-----|------|---------|
| .NET Build + Test | `dotnet test` + xUnit | Compile, unit tests, coverage |
| Python Lint + Test | Ruff + pytest | Lint, unit tests, coverage |
| Security Scan | CodeQL + Bandit | SAST for C# and Python |
| Container Scan | Microsoft Defender for Containers | Docker image vulnerability & malware scan |
| IaC Scan | Checkov | Bicep template security scan |
| Code Coverage | irongut/CodeCoverageSummary | Enforce ≥60% threshold |
| Bicep Validate | `az bicep build` | Template syntax and lint |
| Dependency Review | dependency-review-action | Block vulnerable packages |

```yaml
# Key CI features
permissions:
  contents: read
  security-events: write    # Upload SARIF results
  pull-requests: write      # Post coverage comments
```

### CD Pipeline (on main merge)

The CD pipeline deploys through three environments with progressive gates:

```
Build Artifacts → Sign Images (Notation) → DEV (auto) → STAGING (auto) → Staging Gate → ⏸ Manual Gate → PROD (gated) → Health Checks → Teams Notification
```

**Key design decisions:**

1. **OIDC Authentication** — No stored credentials. GitHub Actions exchanges a short-lived token with Azure AD using federated identity credentials.

```yaml
- name: Azure Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ env.AZURE_TENANT_ID }}
    subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

2. **Immutable Artifacts** — Container images are tagged with the commit SHA, ensuring exact traceability from deployment to source.

3. **Notation Image Signing** — All container images are signed using Notary v2 (Notation) as part of the CD pipeline, providing supply chain integrity verification before deployment.

4. **Environment Protection Rules** — Production requires manual approval from designated reviewers. Staging and dev deploy automatically.

5. **Staging Gate Report** — An automated go/no-go release readiness report is generated after staging deployment, verifying CI status, image signatures, and infrastructure health.

6. **Smoke Tests** — Each deployment is verified with health check endpoints before proceeding.

7. **Teams Notifications** — Deployment status is sent to a Microsoft Teams channel via incoming webhook.

---

## 5. Azure Platform Architecture

### Compute Services

| Service | Workload | Details |
|---------|----------|---------|
| **Azure Functions** (.NET 8 Isolated) | Event-driven compute | HelloWorld HTTP, Durable Orchestration, Service Bus Trigger |
| **Azure Container Apps** (C# Minimal API) | Containerized microservices | Multi-stage Dockerfile, non-root, Alpine |
| **Azure Container Apps** (Python FastAPI) | REST API | Slim image, healthcheck, async |

### Enterprise Messaging

**Azure Service Bus (Premium)** provides reliable messaging:

| Pattern | Resource | Purpose |
|---------|----------|---------|
| Point-to-point | `orders` queue | Reliable order processing with dead-letter |
| Point-to-point | `notifications` queue | Notification delivery |
| Pub/Sub | `events` topic | Event distribution to multiple subscribers |
| Audit | `events/audit-log` | Compliance and audit trail |

### Durable Functions Patterns

The demo includes **function chaining** via `OrderOrchestration`:

```
ValidateOrder → ProcessPayment → UpdateInventory → SendConfirmation
```

Each step is independently retriable, with automatic state management and a status polling endpoint for external systems.

### Networking & Security

All resources deploy into a **VNet (10.0.0.0/16)** with subnet segmentation:

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-functionapp` | 10.0.1.0/24 | Azure Functions VNet integration |
| `snet-aca` | 10.0.2.0/23 | Container Apps Environment |
| `snet-privateendpoints` | 10.0.4.0/24 | Private Endpoints (KV, Service Bus) |

**Infrastructure Security Hardening:**

- **Private Endpoints** for Key Vault and Service Bus (no public access in prod)
- **RBAC Authorization** on Key Vault (no legacy access policies)
- **Managed Identities** on all compute resources (zero stored credentials)
- **TLS 1.2 minimum** enforced on all services
- **NSG deny-all default** with explicit allow rules
- **Soft delete + purge protection** on Key Vault
- **Azure AD auth only** on Service Bus (local auth disabled)
- **Zone redundancy** in production
- **Non-root containers** with minimal Alpine base images

### Monitoring & Observability

| Service | Purpose |
|---------|---------|
| Application Insights | Distributed tracing, performance metrics |
| Log Analytics Workspace | Centralized log aggregation |
| Alert Rules + Action Groups | Proactive failure notification |
| Managed Identity | Secure service-to-service auth |

---

## 6. Infrastructure as Code — Bicep

All infrastructure is defined as **Bicep templates** following Azure Verified Module patterns:

```
infra/
├── main.bicep                  # Orchestrator (subscription scope)
├── main.dev.bicepparam         # Dev overrides
├── main.staging.bicepparam     # Staging overrides
├── main.prod.bicepparam        # Prod overrides
└── modules/
    ├── networking.bicep        # VNet + NSG + Subnets
    ├── keyvault.bicep          # Key Vault + PE + RBAC
    ├── servicebus.bicep        # Service Bus + Queues + Topics
    ├── monitoring.bicep        # Log Analytics + App Insights
    ├── functionapp.bicep       # Functions + Storage + Diagnostics
    └── containerapp.bicep      # ACA Environment + Apps
```

**Environment parameterization** ensures the same templates deploy across dev/staging/prod with appropriate sizing, redundancy, and security levels.

**IaC Security Scanning** with Checkov catches misconfigurations before deployment:
- Missing encryption at rest
- Overly permissive network rules
- Missing diagnostic settings
- Public endpoints in production

---

## 7. The Complete Flow — End to End

Here's the complete developer workflow from idea to production:

```
 1. Pick up work item (ADO Board / GitHub Issue)
 2. Create feature branch from develop
 3. Write code + tests in VS Code with Copilot
 4. Pre-commit hooks run local linting
 5. Push → Create PR (linked to work item via AB#)
 6. ┌──── Automated CI ─────────────────────────────┐
    │  Build → Test → Coverage → Security Scan      │
    │  CodeQL · Bandit · Defender · Checkov · Dep Rev  │
    └───────────────────────────────────────────────┘
 7. ┌──── GitHuSign (Notation) → DEV → STAGING      │
    │  Staging Gate Report → ⏸ Gate → PROD          │
    │  OIDC auth · Immutable images · Health checks  │
    │  Teams notification on deployment               │
    └───────────────────────────────────────────────┘
11. Telemetry flows to Application Insights
12. Work item auto-transitions to "Done"
```

### ADO → GitHub Copilot Agent Bridge

For AI-assisted development, ADO work items can trigger GitHub Copilot Coding Agent:

1. ADO work item dispatches a `repository_dispatch` event via the `ado-copilot-bridge.yml` workflow
2. Copilot Agent picks up the task description and creates a feature branch + PR
3. CI validates the PR automatically (all 8 checks)staging gate report and manual gate protecting production.

4. **Supply chain integrity** — Notation (Notary v2) signs all container images; signatures are verified before deployment to each environment.

5. **Full traceability** — From work item → commit → PR → CI results → deployment. Every change is auditable. ADO Boards links bidirectionally with GitHub.

6. **Infrastructure parity** — The same Bicep templates deploy every environment, with parameterized differences for scale and security posture.

7. **Defense in depth** — Network segmentation, private endpoints, non-root containers, NSG deny-all, and 10+ security scanners.

8. **AI-assisted development** — ADO work items can trigger GitHub Copilot Coding Agent for automated PR creation
11. Telemetry flows to Application Insights
12. Work item auto-transitions to "Done"
```

---, Notation image signing
- **Pipeline**: GitHub Actions (CI + CD) with OIDC, environment gates, staging gate report, Teams notifications, and ADO Copilot bridge
## Key Takeaways

1. **Security is not a phase** — it's integrated into every stage via GitHub Advanced Security and shift-left scanning tools.

2. **Zero stored credentials** — OIDC for CI/CD, Managed Identities for services, RBAC for authorization. No secrets in pipelines or code.

3. **Progressive deployment** — Automatic promotion through dev and staging, with a manual gate protecting production.

4. **Full traceability** — From work item → commit → PR → CI results → deployment. Every change is auditable.

5. **Infrastructure parity** — The same Bicep templates deploy every environment, with parameterized differences for scale and security posture.

6. **Defense in depth** — Network segmentation, private endpoints, non-root containers, NSG deny-all, and seven different security scanners.

---

## Repository Reference

The complete working implementation is available at:
- **Repository**: [az-github-ssdlc-demo](https://github.com/ncheruvu-MSFT/az-github-ssdlc-demo)
- **Technologies**: .NET 8, Python 3.12, Azure Functions, Container Apps, Service Bus, Bicep
- **Security Tools**: CodeQL, Bandit, Microsoft Defender for Containers, Checkov, Safety, dotnet audit, Dependabot, GHAS Malware Scanning
- **Pipeline**: GitHub Actions (CI + CD) with OIDC and environment gates

---

*Published April 2026 | Tags: #DevSecOps #GitHub #SSDLC #Azure #GitHubAdvancedSecurity #CICD #InfrastructureAsCode*
