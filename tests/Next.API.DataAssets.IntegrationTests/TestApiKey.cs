using Next.API.DataAssets.Auth;

namespace Next.API.DataAssets.IntegrationTests;

public static class TestApiKey
{
    public const string Raw = "super-secret-test-key";
    public static string Hash => ApiKeyValidator.Sha256HexLower(Raw);
}
