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

- **SAST**: CodeQL analysis on every PR
- **SCA**: Dependency review blocking vulnerable packages
- **Container Scanning**: Trivy vulnerability scanning
- **IaC Scanning**: Checkov for Bicep templates
- **Secret Scanning**: GitHub secret scanning enabled
- **Branch Protection**: Required reviews, status checks, signed commits
- **OIDC Authentication**: No long-lived credentials in CI/CD
- **Least Privilege**: Minimal permissions in workflows
