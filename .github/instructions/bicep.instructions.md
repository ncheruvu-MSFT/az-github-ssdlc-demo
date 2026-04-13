---
applyTo: "**/*.bicep"
---

# Bicep Infrastructure Skill

When writing or modifying Bicep templates in this project:

## Naming Convention
- Resource groups: `rg-{project}-{env}`
- Key Vault: `kv-{project}-{env}`
- Functions: `func-{project}-{env}`
- Container Apps: `ca-{name}-{project}-{env}`
- Service Bus: `sb-{project}-{env}`
- Log Analytics: `log-{project}-{env}`
- App Insights: `appi-{project}-{env}`

## Required Patterns
- Every resource MUST have `tags` parameter applied
- Every resource MUST have diagnostic settings sending to Log Analytics
- Use `@description()` decorator on all parameters
- Use `@allowed()` for environment parameter: dev, staging, prod
- Use `@secure()` for any secret parameters
- Prefer `existing` keyword to reference deployed resources
- Use managed identity over connection strings
- Enable soft-delete and purge protection on Key Vault
- Disable local auth on Service Bus (Azure AD only)
- Set `minimumTlsVersion: 'TLS1_2'` on all applicable resources

## Security Requirements
- No public endpoints in prod (use private endpoints)
- NSG with deny-all default on subnets
- RBAC authorization mode on Key Vault (not access policies)
- Zone redundancy enabled for prod SKUs
