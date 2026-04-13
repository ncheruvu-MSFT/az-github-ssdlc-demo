---
applyTo: "**/*.py"
---

# Python FastAPI Skill

When writing Python code in this project:

## FastAPI Patterns
- Use Pydantic `BaseModel` for all request/response schemas
- Type hints on every function signature
- Use `async def` for I/O-bound endpoints
- Use `httpx.AsyncClient` (not `requests`) for HTTP calls
- Health endpoint: `@app.get("/health")` returning `{"status": "healthy"}`
- Dependency injection via FastAPI `Depends()`

## Configuration
- Read all config from environment variables via `os.getenv()`
- Never hardcode connection strings, keys, or URLs
- Use `azure.identity.DefaultAzureCredential` for Azure auth
- Use `pydantic_settings.BaseSettings` for typed config

## Security
- Input validation via Pydantic models (automatic)
- Never log sensitive data — redact tokens, keys, PII
- Use `HTTPException` with appropriate status codes (never 500 with details)
- Set CORS origins explicitly (never `allow_origins=["*"]` in prod)

## Testing
- pytest with httpx `AsyncClient` for endpoint tests
- Fixtures in `conftest.py`
- Test naming: `test_{endpoint}_{scenario}`
- Use `@pytest.mark.asyncio` for async tests
- Coverage threshold: 60% minimum
