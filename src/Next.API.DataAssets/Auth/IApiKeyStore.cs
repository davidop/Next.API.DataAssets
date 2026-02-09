namespace Next.API.DataAssets.Auth;

public interface IApiKeyStore
{
    Task<ApiKeyRecord?> FindByHashAsync(string sha256HexLower, CancellationToken ct);
}
