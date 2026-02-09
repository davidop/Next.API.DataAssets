using System.Security.Claims;

namespace Next.API.DataAssets.Auth;

public interface IApiKeyValidator
{
    Task<(bool ok, ClaimsPrincipal? principal, string? error)> ValidateAsync(string rawApiKey, CancellationToken ct);
}
