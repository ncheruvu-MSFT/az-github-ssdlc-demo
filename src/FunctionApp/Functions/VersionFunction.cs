using System.Reflection;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace HelloWorld.Functions;

/// <summary>
/// HTTP-triggered Azure Function — returns build metadata for deployment verification.
/// </summary>
public class VersionFunction
{
    private readonly ILogger<VersionFunction> _logger;

    public VersionFunction(ILogger<VersionFunction> logger)
    {
        _logger = logger;
    }

    [Function("Version")]
    public IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "version")] HttpRequest req)
    {
        _logger.LogInformation("Version endpoint requested.");

        var assembly = Assembly.GetExecutingAssembly();
        var version = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? assembly.GetName().Version?.ToString()
            ?? "unknown";
        var commitSha = Environment.GetEnvironmentVariable("COMMIT_SHA") ?? "local";
        var buildDate = Environment.GetEnvironmentVariable("BUILD_DATE") ?? DateTimeOffset.UtcNow.ToString("o");

        return new OkObjectResult(new
        {
            Version = version,
            CommitSha = commitSha,
            BuildDate = buildDate,
            Timestamp = DateTimeOffset.UtcNow
        });
    }
}
