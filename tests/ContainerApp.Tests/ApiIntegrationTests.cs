using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace HelloWorld.ContainerApp.Tests;

public class ApiIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Root_ReturnsOkWithServiceInfo()
    {
        // Act
        var response = await _client.GetAsync("/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<Dictionary<string, object>>();
        content.Should().ContainKey("service");
        content!["service"].ToString().Should().Contain("Hello World");
    }

    [Fact]
    public async Task Hello_WithoutName_ReturnsHelloWorld()
    {
        // Act
        var response = await _client.GetAsync("/api/hello");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<HelloResponse>();
        content.Should().NotBeNull();
        content!.Message.Should().Be("Hello, World!");
        content.Version.Should().Be("1.0.0");
    }

    [Fact]
    public async Task Hello_WithName_ReturnsPersonalizedGreeting()
    {
        // Act
        var response = await _client.GetAsync("/api/hello?name=Enterprise");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<HelloResponse>();
        content!.Message.Should().Be("Hello, Enterprise!");
    }

    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        // Act
        var response = await _client.GetAsync("/health");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task HealthReady_ReturnsOk()
    {
        // Act
        var response = await _client.GetAsync("/health/ready");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Info_ReturnsEnvironmentInfo()
    {
        // Act
        var response = await _client.GetAsync("/api/info");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<Dictionary<string, object>>();
        content.Should().ContainKey("dotNetVersion");
        content.Should().ContainKey("machineName");
    }

    [Fact]
    public async Task Hello_ResponseHasCorrectContentType()
    {
        // Act
        var response = await _client.GetAsync("/api/hello");

        // Assert
        response.Content.Headers.ContentType!.MediaType.Should().Be("application/json");
    }

    [Fact]
    public async Task Hello_WithExcessivelyLongName_ReturnsBadRequest()
    {
        // Arrange — name longer than 100 characters
        var longName = new string('A', 101);

        // Act
        var response = await _client.GetAsync($"/api/hello?name={longName}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var content = await response.Content.ReadFromJsonAsync<Dictionary<string, object>>();
        content.Should().ContainKey("error");
    }

    [Fact]
    public async Task Hello_WithMaxLengthName_ReturnsOk()
    {
        // Arrange — exactly 100 characters should pass
        var maxName = new string('B', 100);

        // Act
        var response = await _client.GetAsync($"/api/hello?name={maxName}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadFromJsonAsync<HelloResponse>();
        content!.Message.Should().Contain(maxName);
    }

    [Fact]
    public async Task Hello_WithEmptyName_ReturnsHelloWorld()
    {
        // Act
        var response = await _client.GetAsync("/api/hello?name=");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadFromJsonAsync<HelloResponse>();
        content!.Message.Should().Be("Hello, World!");
    }
}
