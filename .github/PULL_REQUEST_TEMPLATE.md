## Description
<!-- Describe your changes in detail -->

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Infrastructure change (Bicep/IaC)
- [ ] Documentation update

## SSDLC Checklist
- [ ] Code follows security coding standards
- [ ] No secrets or credentials are hardcoded
- [ ] Input validation is implemented at system boundaries
- [ ] Error handling does not expose sensitive information
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated (if applicable)
- [ ] Security scanning passes (CodeQL, Bandit, Trivy)
- [ ] Dependency review passes (no vulnerable deps)
- [ ] Infrastructure changes reviewed for security
- [ ] RBAC/least privilege applied for new resources

## Testing
- [ ] All existing tests pass
- [ ] New tests written for this change
- [ ] Code coverage meets threshold (>60%)

## Deployment
- [ ] Changes are backwards compatible
- [ ] Deployment plan reviewed
- [ ] Rollback plan documented (for breaking changes)
