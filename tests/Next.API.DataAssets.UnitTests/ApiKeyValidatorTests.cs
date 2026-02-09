using Next.API.DataAssets.Auth;
using System.Threading;
using Xunit;

namespace Next.API.DataAssets.UnitTests;

public class ApiKeyValidatorTests
{
    [Fact]
    public void Sha256_hash_is_lower_hex()
    {
        var hash = ApiKeyValidator.Sha256HexLower("test");
        Assert.Matches("^[0-9a-f]{64}$", hash);
    }
}
