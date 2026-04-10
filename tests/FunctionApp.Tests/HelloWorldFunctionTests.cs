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
        var result = _sut.Run(request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        result!.StatusCode.Should().Be(200);

        var value = result.Value;
        value.Should().NotBeNull();
        var messageProperty = value!.GetType().GetProperty("Message");
        messageProperty.Should().NotBeNull();
        messageProperty!.GetValue(value).Should().Be("Hello, World!");
    }

    [Fact]
    public void Run_WithName_ReturnsPersonalizedGreeting()
    {
        // Arrange
        var context = new DefaultHttpContext();
        context.Request.QueryString = new QueryString("?name=Azure");

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        result!.StatusCode.Should().Be(200);

        var value = result.Value;
        var messageProperty = value!.GetType().GetProperty("Message");
        messageProperty!.GetValue(value).Should().Be("Hello, Azure!");
    }

    [Fact]
    public void Run_WithEmptyName_ReturnsHelloWorld()
    {
        // Arrange
        var context = new DefaultHttpContext();
        context.Request.QueryString = new QueryString("?name=");

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        var value = result!.Value;
        var messageProperty = value!.GetType().GetProperty("Message");
        messageProperty!.GetValue(value).Should().Be("Hello, World!");
    }

    [Fact]
    public void HealthCheck_ReturnsHealthy()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = _sut.HealthCheck(context.Request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        result!.StatusCode.Should().Be(200);

        var value = result.Value;
        var statusProperty = value!.GetType().GetProperty("Status");
        statusProperty!.GetValue(value).Should().Be("Healthy");
    }

    [Fact]
    public void Run_ResponseContainsTimestamp()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        var value = result!.Value;
        var timestampProperty = value!.GetType().GetProperty("Timestamp");
        timestampProperty.Should().NotBeNull();
        var timestamp = (DateTimeOffset)timestampProperty!.GetValue(value)!;
        timestamp.Should().BeCloseTo(DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void Run_ResponseContainsVersion()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        var value = result!.Value;
        var versionProperty = value!.GetType().GetProperty("Version");
        versionProperty!.GetValue(value).Should().Be("1.0.0");
    }
}
