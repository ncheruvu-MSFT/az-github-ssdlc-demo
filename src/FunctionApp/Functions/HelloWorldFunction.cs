using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace HelloWorld.Functions;

/// <summary>
/// HTTP-triggered Azure Function — Hello World endpoint.
/// </summary>
public class HelloWorldFunction
{
    private readonly ILogger<HelloWorldFunction> _logger;

    public HelloWorldFunction(ILogger<HelloWorldFunction> logger)
    {
        _logger = logger;
    }

    [Function("HelloWorld")]
    public IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "hello")] HttpRequest req)
    {
        _logger.LogInformation("HelloWorld function processed a request.");

        var name = req.Query["name"].ToString();
        if (string.IsNullOrWhiteSpace(name))
        {
            name = "World";
        }

        return new OkObjectResult(new
        {
            Message = $"Hello, {name}!",
            Timestamp = DateTimeOffset.UtcNow,
            Version = "1.0.0"
        });
    }

    [Function("HealthCheck")]
    public IActionResult HealthCheck(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req)
    {
        return new OkObjectResult(new { Status = "Healthy", Timestamp = DateTimeOffset.UtcNow });
    }
}
