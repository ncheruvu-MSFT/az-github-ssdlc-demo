using FluentAssertions;
using HelloWorld.Functions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace HelloWorld.Functions.Tests;

public class OrderOrchestrationTests
{
    private readonly OrderOrchestration _sut;
    private readonly Mock<ILogger<OrderOrchestration>> _logger;

    public OrderOrchestrationTests()
    {
        _logger = new Mock<ILogger<OrderOrchestration>>();
        _sut = new OrderOrchestration(_logger.Object);
    }

    [Fact]
    public void ValidateOrder_WithValidOrderId_ReturnsTrue()
    {
        // Arrange
        var mockContext = new Mock<FunctionContext>();
        var mockLogger = new Mock<ILogger>();
        var serviceProvider = new Mock<IServiceProvider>();
        var loggerFactory = new Mock<ILoggerFactory>();
        loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(mockLogger.Object);
        serviceProvider.Setup(s => s.GetService(typeof(ILoggerFactory))).Returns(loggerFactory.Object);
        mockContext.Setup(c => c.InstanceServices).Returns(serviceProvider.Object);

        // Act
        var result = _sut.ValidateOrder("order123", mockContext.Object);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void ValidateOrder_WithEmptyOrderId_ReturnsFalse()
    {
        // Arrange
        var mockContext = new Mock<FunctionContext>();
        var mockLogger = new Mock<ILogger>();
        var serviceProvider = new Mock<IServiceProvider>();
        var loggerFactory = new Mock<ILoggerFactory>();
        loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(mockLogger.Object);
        serviceProvider.Setup(s => s.GetService(typeof(ILoggerFactory))).Returns(loggerFactory.Object);
        mockContext.Setup(c => c.InstanceServices).Returns(serviceProvider.Object);

        // Act
        var result = _sut.ValidateOrder("", mockContext.Object);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void ProcessPayment_ReturnsPaymentId()
    {
        // Arrange
        var mockContext = new Mock<FunctionContext>();
        var mockLogger = new Mock<ILogger>();
        var serviceProvider = new Mock<IServiceProvider>();
        var loggerFactory = new Mock<ILoggerFactory>();
        loggerFactory.Setup(f => f.CreateLogger(It.IsAny<string>())).Returns(mockLogger.Object);
        serviceProvider.Setup(s => s.GetService(typeof(ILoggerFactory))).Returns(loggerFactory.Object);
        mockContext.Setup(c => c.InstanceServices).Returns(serviceProvider.Object);

        // Act
        var result = _sut.ProcessPayment("order123", mockContext.Object);

        // Assert
        result.Should().StartWith("Payment-");
        result.Should().HaveLength(16); // "Payment-" + 8 chars
    }

    [Fact]
    public void OrderResult_Record_CreatesCorrectly()
    {
        // Act
        var result = new OrderResult("order1", "Completed", "Payment OK");

        // Assert
        result.OrderId.Should().Be("order1");
        result.Status.Should().Be("Completed");
        result.Details.Should().Be("Payment OK");
    }
}
