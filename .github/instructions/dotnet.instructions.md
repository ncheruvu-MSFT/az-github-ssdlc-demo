---
applyTo: "**/*.cs"
---

# .NET 8 Coding Skill

When writing C# code in this project:

## Azure Functions (Isolated Worker)
- Use `[Function("Name")]` attribute (not `[FunctionName]`)
- Constructor injection with `ILogger<T>`, `IConfiguration`
- Return `IActionResult` or typed responses
- Use `async Task<T>` for all I/O operations
- Register services in `Program.cs` via `builder.Services`

## Container App (Minimal API)
- Use `app.MapGet/MapPost()` pattern (no controllers)
- Add health endpoint: `app.MapGet("/health", () => Results.Ok(new { status = "healthy" }))`
- Use `builder.Services.AddHttpClient()` for outbound HTTP
- Read config from `IConfiguration` (appsettings.json + env vars)

## Security
- Never log sensitive data (PII, tokens, connection strings)
- Validate all input at API boundaries using data annotations or FluentValidation
- Use `[FromQuery]`/`[FromBody]` with model binding (never raw string parsing)
- Use `DefaultAzureCredential` for Azure service auth (not connection strings)
- Handle exceptions with middleware — never expose stack traces

## Testing
- xUnit test classes: `{ClassName}Tests.cs`
- Use FluentAssertions: `result.Should().BeOfType<OkObjectResult>()`
- Use Moq for dependencies: `var mock = new Mock<ILogger<T>>()`
- Use `WebApplicationFactory<Program>` for integration tests
- Test naming: `MethodName_Scenario_ExpectedBehavior`
