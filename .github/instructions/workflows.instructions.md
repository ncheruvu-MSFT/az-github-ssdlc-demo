---
applyTo: ".github/workflows/*.yml"
---

# GitHub Actions Workflow Skill

When writing or modifying GitHub Actions workflows:

## Security
- Use `permissions` block with least privilege (never `permissions: write-all`)
- Pin action versions to full SHA or major version (`@v4` minimum)
- Use OIDC for Azure login (`id-token: write` permission)
- Never echo secrets or use `${{ secrets.* }}` in `run:` steps directly
- Use `environment:` for deployment jobs with protection rules

## CI Pipeline Pattern
- Trigger on `push` to main/develop + `pull_request` to main/develop
- Run tests, build, lint, security scans in parallel jobs
- Upload SARIF to GitHub Security tab (`security-events: write`)
- Post code coverage as PR comment (`pull-requests: write`)

## CD Pipeline Pattern
- Trigger on CI workflow success (`workflow_run`)
- Progressive deployment: dev → staging → (manual gate) → prod
- Tag container images with `${{ github.sha }}` (immutable)
- Run health checks after each deployment
- Use `concurrency` to prevent overlapping deployments

## Artifact Handling
- Use `actions/upload-artifact@v4` / `actions/download-artifact@v4`
- Never store secrets in artifacts
- Set retention period on artifacts
