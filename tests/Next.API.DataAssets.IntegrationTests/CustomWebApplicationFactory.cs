using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;

namespace Next.API.DataAssets.IntegrationTests;

public sealed class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");

        builder.ConfigureAppConfiguration((context, config) =>
        {
            var overrides = new Dictionary<string, string?>
            {
                ["Assets:RootPath"] = "assets",
                ["Auth:Jwt:SigningKey"] = TestJwt.SigningKey,
                ["Auth:Jwt:ValidateIssuer"] = "false",
                ["Auth:Jwt:ValidateAudience"] = "false",
                ["Auth:ApiKeysOptions:HeaderName"] = "X-API-Key",
                ["Auth:ApiKeysOptions:Keys:0:KeyId"] = "test-key-1",
                ["Auth:ApiKeysOptions:Keys:0:Owner"] = "Integration Tests",
                ["Auth:ApiKeysOptions:Keys:0:KeyHash"] = TestApiKey.Hash,
                ["Auth:ApiKeysOptions:Keys:0:Enabled"] = "true",
                // Disable rate-limiting in tests (optional): keep defaults small.
                ["RateLimiting:IpRateLimitOptions:GeneralRules:0:Limit"] = "10000"
            };

            config.AddInMemoryCollection(overrides);
        });
    }
}
