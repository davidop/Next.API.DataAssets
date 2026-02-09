using System.Net;
using Xunit;

namespace Next.API.DataAssets.IntegrationTests;

public class ResourcesEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;

    public ResourcesEndpointTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Get_without_auth_returns_401()
    {
        var client = _factory.CreateClient();
        var res = await client.GetAsync("/resources/DataAsset.csv");
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task Get_with_api_key_returns_200()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", TestApiKey.Raw);

        var res = await client.GetAsync("/resources/DataAsset.csv");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        Assert.True(res.Content.Headers.ContentType?.MediaType?.Contains("text") ?? true);
    }

    [Fact]
    public async Task Get_with_jwt_returns_200()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", TestJwt.CreateToken());

        var res = await client.GetAsync("/resources/DataAsset.csv");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [Fact]
    public async Task Get_nonexistent_returns_404()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", TestApiKey.Raw);

        var res = await client.GetAsync("/resources/Nope.csv");
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    [Fact]
    public async Task Path_traversal_returns_400()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", TestApiKey.Raw);

        var res = await client.GetAsync("/resources/../secret.txt");
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }
}
