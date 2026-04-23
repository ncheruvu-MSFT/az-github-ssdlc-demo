using FluentAssertions;
using HelloWorld.Functions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace HelloWorld.Functions.Tests;

public class HelloWorldFunctionTests
{
    private readonly HelloWorldFunction _sut;
    private readonly Mock<ILogger<HelloWorldFunction>> _logger;

    public HelloWorldFunctionTests()
    {
        _logger = new Mock<ILogger<HelloWorldFunction>>();
        _sut = new HelloWorldFunction(_logger.Object);
    }

    [Fact]
    public void Run_WithoutName_ReturnsHelloWorld()
    {
        // Arrange
        var context = new DefaultHttpContext();
        var request = context.Request;

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.Run(request));

        // Assert
        result.StatusCode.Should().Be(200);

        var value = result.Value;
        Assert.NotNull(value);
        var messageProperty = value!.GetType().GetProperty("Message");
        Assert.NotNull(messageProperty);
        messageProperty!.GetValue(value).Should().Be("Hello, World!");
    }

    [Fact]
    public void Run_WithName_ReturnsPersonalizedGreeting()
    {
        // Arrange
        var context = new DefaultHttpContext();
        context.Request.QueryString = new QueryString("?name=Azure");

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        result.StatusCode.Should().Be(200);

        var value = result.Value;
        Assert.NotNull(value);
        var messageProperty = value!.GetType().GetProperty("Message");
        Assert.NotNull(messageProperty);
        messageProperty!.GetValue(value).Should().Be("Hello, Azure!");
    }

    [Fact]
    public void Run_WithEmptyName_ReturnsHelloWorld()
    {
        // Arrange
        var context = new DefaultHttpContext();
        context.Request.QueryString = new QueryString("?name=");

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        var value = result.Value;
        Assert.NotNull(value);
        var messageProperty = value!.GetType().GetProperty("Message");
        Assert.NotNull(messageProperty);
        messageProperty!.GetValue(value).Should().Be("Hello, World!");
    }

    [Fact]
    public void HealthCheck_ReturnsHealthy()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.HealthCheck(context.Request));

        // Assert
        result.StatusCode.Should().Be(200);

        var value = result.Value;
        Assert.NotNull(value);
        var statusProperty = value!.GetType().GetProperty("Status");
        Assert.NotNull(statusProperty);
        statusProperty!.GetValue(value).Should().Be("Healthy");
    }

    [Fact]
    public void Run_ResponseContainsTimestamp()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        var value = result.Value;
        Assert.NotNull(value);
        var timestampProperty = value!.GetType().GetProperty("Timestamp");
        Assert.NotNull(timestampProperty);
        var timestamp = (DateTimeOffset)timestampProperty!.GetValue(value)!;
        timestamp.Should().BeCloseTo(DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void Run_ResponseContainsVersion()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        var value = result.Value;
        Assert.NotNull(value);
        var versionProperty = value!.GetType().GetProperty("Version");
        Assert.NotNull(versionProperty);
        versionProperty!.GetValue(value).Should().Be("1.0.0");
    }
}
