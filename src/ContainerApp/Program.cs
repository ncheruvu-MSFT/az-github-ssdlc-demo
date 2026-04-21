using HelloWorld.ContainerApp;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddApplicationInsightsTelemetry();
builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");

app.MapGet("/", () => Results.Ok(new
{
    Service = "Hello World Container App",
    Status = "Running",
    Timestamp = DateTimeOffset.UtcNow
}))
.WithName("Root")
.WithOpenApi();

app.MapGet("/api/hello", (string? name) =>
{
    // Input validation: reject names exceeding max length (OWASP A03:2021)
    if (name is not null && name.Length > 100)
    {
        return Results.BadRequest(new { error = "Name parameter must not exceed 100 characters." });
    }

    var greeting = string.IsNullOrWhiteSpace(name) ? "World" : name;
    return Results.Ok(new HelloResponse($"Hello, {greeting}!", DateTimeOffset.UtcNow, "1.0.0"));
})
.WithName("Hello")
.WithOpenApi();

app.MapGet("/api/info", () => Results.Ok(new
{
    Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown",
    MachineName = Environment.MachineName,
    DotNetVersion = Environment.Version.ToString(),
    Timestamp = DateTimeOffset.UtcNow
}))
.WithName("Info")
.WithOpenApi();

app.MapGet("/api/time", () =>
{
    var now = DateTimeOffset.UtcNow;
    return Results.Ok(new
    {
        utc = now.UtcDateTime.ToString("O"),
        timestamp = now.ToUnixTimeSeconds(),
        timezone = "UTC"
    });
})
.WithName("Time")
.WithOpenApi();

app.Run();

namespace HelloWorld.ContainerApp
{
    public record HelloResponse(string Message, DateTimeOffset Timestamp, string Version);

    // Make Program accessible for integration tests
    public partial class Program;
}
