using FluentAssertions;
using HelloWorld.Functions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace HelloWorld.Functions.Tests;

public class VersionFunctionTests
{
    private readonly VersionFunction _sut;
    private readonly Mock<ILogger<VersionFunction>> _logger;

    public VersionFunctionTests()
    {
        _logger = new Mock<ILogger<VersionFunction>>();
        _sut = new VersionFunction(_logger.Object);
    }

    [Fact]
    public void Run_ReturnsOkWithVersionInfo()
    {
        // Arrange
        var context = new DefaultHttpContext();

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        result!.StatusCode.Should().Be(200);

        var value = result.Value;
        value.Should().NotBeNull();

        var versionProp = value!.GetType().GetProperty("Version");
        versionProp.Should().NotBeNull();
        versionProp!.GetValue(value).Should().NotBeNull();

        var commitShaProp = value.GetType().GetProperty("CommitSha");
        commitShaProp.Should().NotBeNull();

        var buildDateProp = value.GetType().GetProperty("BuildDate");
        buildDateProp.Should().NotBeNull();

        var timestampProp = value.GetType().GetProperty("Timestamp");
        timestampProp.Should().NotBeNull();
    }

    [Fact]
    public void Run_WhenCommitShaEnvSet_ReturnsIt()
    {
        // Arrange
        var context = new DefaultHttpContext();
        Environment.SetEnvironmentVariable("COMMIT_SHA", "abc123def");

        try
        {
            // Act
            var result = _sut.Run(context.Request) as OkObjectResult;

            // Assert
            result.Should().NotBeNull();
            var value = result!.Value;
            var commitShaProp = value!.GetType().GetProperty("CommitSha");
            commitShaProp!.GetValue(value).Should().Be("abc123def");
        }
        finally
        {
            Environment.SetEnvironmentVariable("COMMIT_SHA", null);
        }
    }

    [Fact]
    public void Run_WhenNoCommitShaEnv_ReturnsLocal()
    {
        // Arrange
        var context = new DefaultHttpContext();
        Environment.SetEnvironmentVariable("COMMIT_SHA", null);

        // Act
        var result = _sut.Run(context.Request) as OkObjectResult;

        // Assert
        result.Should().NotBeNull();
        var value = result!.Value;
        var commitShaProp = value!.GetType().GetProperty("CommitSha");
        commitShaProp!.GetValue(value).Should().Be("local");
    }
}
