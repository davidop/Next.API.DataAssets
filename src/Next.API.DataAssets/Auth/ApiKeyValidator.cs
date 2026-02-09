using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace Next.API.DataAssets.Auth;

public sealed class ApiKeyValidator : IApiKeyValidator
{
    private readonly IApiKeyStore _store;

    public ApiKeyValidator(IApiKeyStore store) => _store = store;

    public static string Sha256HexLower(string raw)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    public async Task<(bool ok, ClaimsPrincipal? principal, string? error)> ValidateAsync(string rawApiKey, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(rawApiKey))
            return (false, null, "missing_api_key");

        var hash = Sha256HexLower(rawApiKey.Trim());
        var rec = await _store.FindByHashAsync(hash, ct);

        if (rec is null)
            return (false, null, "invalid_api_key");

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, rec.KeyId),
            new(ClaimTypes.Name, rec.Owner),
            new("auth_method", "api_key")
        };

        var identity = new ClaimsIdentity(claims, ApiKeyDefaults.Scheme);
        return (true, new ClaimsPrincipal(identity), null);
    }
}
