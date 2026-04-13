# Project Copilot Instructions — az-github-ssdlc-demo

## Architecture Standards

This is an enterprise SSDLC reference implementation. All code MUST follow these patterns:

### .NET 8 (Isolated Worker)
- Use **isolated worker model** for Azure Functions (not in-process)
- Use **Minimal API** pattern for Container Apps (no controllers)
- Dependency injection via `builder.Services`
- Configuration via `IConfiguration` (never hardcode connection strings)
- Use `ILogger<T>` for structured logging
- Async/await everywhere — never `.Result` or `.Wait()`

### Python (FastAPI)
- Use **FastAPI** with Pydantic models for request/response validation
- Type hints on all function signatures
- Use `async def` for I/O-bound endpoints
- Use `httpx.AsyncClient` for HTTP calls (not `requests`)
- Configuration via environment variables (never hardcode)

### Security (MANDATORY)
- **Zero hardcoded secrets** — use Managed Identity + Key Vault references
- **Input validation at system boundaries** — validate all external input
- **No sensitive data in logs** — redact PII, tokens, connection strings
- **RBAC over access policies** — Key Vault, Service Bus, Storage all use RBAC
- **TLS 1.2 minimum** on all services
- **Non-root containers** — Dockerfiles must use non-root USER
- Follow **OWASP Top 10** mitigations

### Infrastructure as Code (Bicep)
- Follow **Azure Verified Module (AVM)** naming patterns
- Use **subscription-scope** deployments with resource group creation
- Environment parameterization via `.bicepparam` files
- Private endpoints for PaaS services in staging/prod
- Diagnostic settings on every resource (Log Analytics + App Insights)
- Tags: Environment, Project, ManagedBy, SecurityLevel

### Testing
- **xUnit** + **FluentAssertions** + **Moq** for .NET tests
- **pytest** + **httpx** for Python tests
- Minimum **60% code coverage** threshold
- Use `WebApplicationFactory<T>` for integration tests
- Test both happy path and error cases

### CI/CD Patterns
- GitHub Actions with **OIDC** authentication (no stored credentials)
- Container images tagged with **commit SHA** (immutable)
- Progressive deployment: dev → staging → (manual gate) → prod
- Health check verification after each environment deployment

### Git Conventions
- Branch naming: `feature/`, `fix/`, `chore/`
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)
- Reference ADO work items via `AB#<id>` in commits and PR descriptions
- PR template with SSDLC security checklist
