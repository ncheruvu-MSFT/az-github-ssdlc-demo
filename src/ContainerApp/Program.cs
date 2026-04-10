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

app.Run();

namespace HelloWorld.ContainerApp
{
    public record HelloResponse(string Message, DateTimeOffset Timestamp, string Version);

    // Make Program accessible for integration tests
    public partial class Program;
}
