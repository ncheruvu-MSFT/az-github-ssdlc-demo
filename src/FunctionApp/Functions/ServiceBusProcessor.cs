using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace HelloWorld.Functions;

/// <summary>
/// Service Bus triggered function — processes messages from the orders queue.
/// Demonstrates enterprise message-driven patterns.
/// </summary>
public class ServiceBusProcessor
{
    private readonly ILogger<ServiceBusProcessor> _logger;

    public ServiceBusProcessor(ILogger<ServiceBusProcessor> logger)
    {
        _logger = logger;
    }

    [Function("ProcessOrderMessage")]
    public void ProcessOrderMessage(
        [ServiceBusTrigger("orders", Connection = "ServiceBusConnection")] string message,
        FunctionContext context)
    {
        _logger.LogInformation("Processing order message: {Message}", message);
        // Enterprise pattern: idempotent processing, dead-letter on failure
    }

    [Function("ProcessNotification")]
    public void ProcessNotification(
        [ServiceBusTrigger("notifications", Connection = "ServiceBusConnection")] string message,
        FunctionContext context)
    {
        _logger.LogInformation("Processing notification: {Message}", message);
    }

    [Function("ProcessEvent")]
    public void ProcessEvent(
        [ServiceBusTrigger("events", "event-processing", Connection = "ServiceBusConnection")] string message,
        FunctionContext context)
    {
        _logger.LogInformation("Processing event: {Message}", message);
    }
}
