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
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        result.StatusCode.Should().Be(200);

        var value = result.Value;
        Assert.NotNull(value);

        var versionProp = value!.GetType().GetProperty("Version");
        Assert.NotNull(versionProp);
        versionProp!.GetValue(value).Should().NotBeNull();

        var commitShaProp = value.GetType().GetProperty("CommitSha");
        Assert.NotNull(commitShaProp);

        var buildDateProp = value.GetType().GetProperty("BuildDate");
        Assert.NotNull(buildDateProp);

        var timestampProp = value.GetType().GetProperty("Timestamp");
        Assert.NotNull(timestampProp);
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
            var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

            // Assert
            var value = result.Value;
            Assert.NotNull(value);
            var commitShaProp = value!.GetType().GetProperty("CommitSha");
            Assert.NotNull(commitShaProp);
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
        var result = Assert.IsType<OkObjectResult>(_sut.Run(context.Request));

        // Assert
        var value = result.Value;
        Assert.NotNull(value);
        var commitShaProp = value!.GetType().GetProperty("CommitSha");
        Assert.NotNull(commitShaProp);
        commitShaProp!.GetValue(value).Should().Be("local");
    }
}
