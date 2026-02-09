namespace Next.API.DataAssets.Auth;

public sealed class AuthOptions
{
    public JwtOptions Jwt { get; set; } = new();
    public ApiKeysOptions ApiKeysOptions { get; set; } = new();
}

public sealed class JwtOptions
{
    public string? Issuer { get; set; } = "nextmobility";
    public string? Audience { get; set; } = "nextmobility.dataassets";
    public string? SigningKey { get; set; } = "CHANGE_ME_DEV_ONLY";
    public bool ValidateIssuer { get; set; } = false;
    public bool ValidateAudience { get; set; } = false;
    public int ClockSkewSeconds { get; set; } = 30;
}

public sealed class ApiKeysOptions
{
    public string HeaderName { get; set; } = ApiKeyDefaults.HeaderName;
    public List<ApiKeyRecord> Keys { get; set; } = new();
}

public sealed class ApiKeyRecord
{
    public string KeyId { get; set; } = "";
    public string Owner { get; set; } = "";
    /// <summary>SHA-256 hex hash (lowercase) of the raw API key.</summary>
    public string KeyHash { get; set; } = "";
    public bool Enabled { get; set; } = true;
}
