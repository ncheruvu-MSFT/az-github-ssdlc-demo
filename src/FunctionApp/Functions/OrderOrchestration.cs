using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask;
using Microsoft.DurableTask.Client;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace HelloWorld.Functions;

/// <summary>
/// Durable Functions orchestration — enterprise workflow pattern
/// demonstrating fan-out/fan-in and chaining.
/// </summary>
public class OrderOrchestration
{
    private readonly ILogger<OrderOrchestration> _logger;

    public OrderOrchestration(ILogger<OrderOrchestration> logger)
    {
        _logger = logger;
    }

    // ── HTTP Starter ──────────────────────────────────────────────
    [Function("StartOrderProcessing")]
    public async Task<IActionResult> HttpStart(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "orders/process")] HttpRequest req,
        [DurableClient] DurableTaskClient client)
    {
        var orderId = Guid.NewGuid().ToString("N")[..8];
        var instanceId = await client.ScheduleNewOrchestrationInstanceAsync(
            nameof(ProcessOrderOrchestrator), orderId);

        _logger.LogInformation("Started orchestration {InstanceId} for order {OrderId}", instanceId, orderId);

        return new AcceptedResult("", new
        {
            InstanceId = instanceId,
            OrderId = orderId,
            StatusQueryUrl = $"/api/orders/status/{instanceId}"
        });
    }

    // ── Orchestrator ──────────────────────────────────────────────
    [Function(nameof(ProcessOrderOrchestrator))]
    public async Task<OrderResult> ProcessOrderOrchestrator(
        [OrchestrationTrigger] TaskOrchestrationContext context)
    {
        var orderId = context.GetInput<string>() ?? "unknown";
        var logger = context.CreateReplaySafeLogger<OrderOrchestration>();

        // Step 1: Validate
        logger.LogInformation("Validating order {OrderId}", orderId);
        var isValid = await context.CallActivityAsync<bool>(nameof(ValidateOrder), orderId);
        if (!isValid)
        {
            return new OrderResult(orderId, "Rejected", "Validation failed");
        }

        // Step 2: Process payment
        logger.LogInformation("Processing payment for {OrderId}", orderId);
        var paymentResult = await context.CallActivityAsync<string>(nameof(ProcessPayment), orderId);

        // Step 3: Send notification
        logger.LogInformation("Sending notification for {OrderId}", orderId);
        await context.CallActivityAsync(nameof(SendNotification), orderId);

        return new OrderResult(orderId, "Completed", paymentResult);
    }

    // ── Activity Functions ────────────────────────────────────────
    [Function(nameof(ValidateOrder))]
    public bool ValidateOrder([ActivityTrigger] string orderId, FunctionContext context)
    {
        var logger = context.GetLogger(nameof(ValidateOrder));
        logger.LogInformation("Validating order {OrderId}", orderId);
        return !string.IsNullOrEmpty(orderId);
    }

    [Function(nameof(ProcessPayment))]
    public string ProcessPayment([ActivityTrigger] string orderId, FunctionContext context)
    {
        var logger = context.GetLogger(nameof(ProcessPayment));
        logger.LogInformation("Processing payment for order {OrderId}", orderId);
        return $"Payment-{Guid.NewGuid().ToString("N")[..8]}";
    }

    [Function(nameof(SendNotification))]
    public void SendNotification([ActivityTrigger] string orderId, FunctionContext context)
    {
        var logger = context.GetLogger(nameof(SendNotification));
        logger.LogInformation("Notification sent for order {OrderId}", orderId);
    }

    // ── Status endpoint ───────────────────────────────────────────
    [Function("GetOrderStatus")]
    public async Task<IActionResult> GetOrderStatus(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "orders/status/{instanceId}")] HttpRequest req,
        [DurableClient] DurableTaskClient client,
        string instanceId)
    {
        var metadata = await client.GetInstanceAsync(instanceId);
        if (metadata is null)
        {
            return new NotFoundObjectResult(new { Error = "Instance not found" });
        }

        return new OkObjectResult(new
        {
            metadata.InstanceId,
            Status = metadata.RuntimeStatus.ToString(),
            CreatedAt = metadata.CreatedAt,
            LastUpdatedAt = metadata.LastUpdatedAt
        });
    }
}

public record OrderResult(string OrderId, string Status, string Details);
