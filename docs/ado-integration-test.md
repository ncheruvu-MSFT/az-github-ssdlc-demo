# ADO Boards Integration Test

This file validates the ADO Boards → GitHub → Azure traceability chain.

## Linked Work Items
- Epic #1: SSDLC Demo Secure Cloud Deployment
- Issue #2: GitHub Actions CI/CD with GHAS

## Verification
- AB# link syntax: `AB#1`
- Pipeline: CI triggers on PR, CD triggers on main merge

## Work Item Hierarchy

```
Epic #1: SSDLC Demo: Secure Cloud Deployment
└─ Issue #2: GitHub Actions CI/CD with GHAS Security Scanning
   ├─ Issue #3: Security scanning (5 tasks: CodeQL, Trivy, Checkov, Bandit, Dependabot)
   ├─ Issue #10: IaC deployment (5 tasks: Bicep validate, OIDC, secrets, envs, test deploy)
   ├─ Issue #19: Traceability (4 tasks: ADO-GH integration, PR template, SHA tags, audit docs)
   └─ Issue #24: Monitoring (4 tasks: App Insights, Func health, ACA health, alert rules)
```
