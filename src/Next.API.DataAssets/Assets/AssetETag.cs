using System.Security.Cryptography;
using System.Text;

namespace Next.API.DataAssets.Assets;

public static class AssetETag
{
    public static string Compute(long sizeBytes, DateTimeOffset lastModifiedUtc)
    {
        var input = $"{sizeBytes}:{lastModifiedUtc.ToUnixTimeSeconds()}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        // Weak ETag is fine for file downloads; use strong if you prefer by removing W/
        return "W/\"" + Convert.ToHexString(hash).ToLowerInvariant() + "\"";
    }
}
