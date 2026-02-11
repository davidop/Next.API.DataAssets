using System.Net;
using System.Text.Json;
using Xunit;

namespace Next.API.DataAssets.IntegrationTests;

public class HealthEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;

    public HealthEndpointTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_returns_200_with_simple_status()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/health");
        
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content);
        
        Assert.True(json.RootElement.TryGetProperty("status", out var status));
        Assert.Equal("ok", status.GetString());
    }

    [Fact]
    public async Task Healthz_returns_200_with_detailed_status()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/healthz");
        
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(content);
        
        // Check required fields
        Assert.True(json.RootElement.TryGetProperty("status", out var status));
        Assert.Equal("healthy", status.GetString());
        
        Assert.True(json.RootElement.TryGetProperty("version", out _));
        Assert.True(json.RootElement.TryGetProperty("framework", out _));
        Assert.True(json.RootElement.TryGetProperty("timestamp", out _));
        Assert.True(json.RootElement.TryGetProperty("environment", out _));
    }

    [Fact]
    public async Task Healthz_allows_anonymous_in_development()
    {
        // In test environment (Development), healthz should be accessible without auth
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/healthz");
        
        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
