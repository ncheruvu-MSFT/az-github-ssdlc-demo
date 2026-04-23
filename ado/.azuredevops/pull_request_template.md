## Description
<!-- Describe what this PR does -->

## Related Work Items
<!-- Link ADO work items: AB#12345 -->
- AB#

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Infrastructure change (Bicep/IaC)
- [ ] Documentation update

## SSDLC Security Checklist
> **All items must be checked before merge**

### Code Security
- [ ] Code follows project security standards
- [ ] No hardcoded secrets, connection strings, or API keys
- [ ] Input validation at all system boundaries
- [ ] Error handling does not leak PII or sensitive data
- [ ] Async/await used for I/O operations (no `.Result` or `.Wait()`)

### Testing
- [ ] Unit tests added/updated (minimum 60% coverage)
- [ ] Integration tests added (if applicable)
- [ ] All existing tests pass
- [ ] Both happy path and error cases tested

### Security Scanning
- [ ] GHAzDO CodeQL SAST passes (check Advanced Security tab)
- [ ] Dependency scanning passes (no high/critical CVEs)
- [ ] Secret scanning passes (no leaked secrets)
- [ ] Container scanning passes (if applicable)
- [ ] IaC scanning passes (Checkov, if applicable)
- [ ] MSDO pipeline passes

### Infrastructure (if applicable)
- [ ] Follows Azure Verified Module (AVM) naming patterns
- [ ] Private endpoints configured for staging/prod
- [ ] Diagnostic settings on every resource
- [ ] Tags applied: Environment, Project, ManagedBy, SecurityLevel
- [ ] RBAC over access policies (Key Vault, Storage, Service Bus)

### AI/Agent (if applicable)
- [ ] Prompt evaluation metrics within threshold
- [ ] Content safety validation passes
- [ ] Red team testing completed
- [ ] Gate logic passes (quality/safety/compliance/tool)

### Deployment
- [ ] Changes are backwards compatible
- [ ] Deployment plan reviewed
- [ ] Rollback plan identified (for breaking changes)
- [ ] Health checks configured

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

## GitHub Copilot Review
<!-- Copilot PR summary will appear here automatically -->
