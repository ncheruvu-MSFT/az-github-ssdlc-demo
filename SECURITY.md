# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** create a public GitHub issue.
2. Email security concerns to your security team.
3. Include a description of the vulnerability and steps to reproduce.
4. We aim to acknowledge reports within 48 hours and provide a fix timeline within 5 business days.

## Security Measures

This project implements the following SSDLC practices:

- **SAST**: CodeQL analysis on every PR (C# + Python)
- **SCA**: Dependency review blocking vulnerable packages
- **Container Scanning**: Microsoft Defender for Containers (image vulnerability + malware)
- **IaC Scanning**: Checkov for Bicep templates
- **Secret Scanning**: GitHub secret scanning with push protection enabled
- **Image Signing**: Notation (Notary v2) signs container images in CD pipeline
- **Branch Protection**: Required reviews, status checks, signed commits
- **OIDC Authentication**: No long-lived credentials in CI/CD (federated identity)
- **Least Privilege**: Minimal permissions in workflows
- **Staging Gate**: Go/no-go release readiness report before production
- **ADO Traceability**: Work items linked to commits, PRs, and deployments via AB# references
