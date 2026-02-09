using Microsoft.Extensions.Options;

namespace Next.API.DataAssets.Auth;

public sealed class InMemoryApiKeyStore : IApiKeyStore
{
    private readonly IOptionsMonitor<ApiKeysOptions> _options;

    public InMemoryApiKeyStore(IOptionsMonitor<ApiKeysOptions> options) => _options = options;

    public Task<ApiKeyRecord?> FindByHashAsync(string sha256HexLower, CancellationToken ct)
    {
        var match = _options.CurrentValue.Keys
            .FirstOrDefault(k => k.Enabled && string.Equals(k.KeyHash, sha256HexLower, StringComparison.OrdinalIgnoreCase));

        return Task.FromResult(match);
    }
}
