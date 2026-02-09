namespace Next.API.DataAssets.Assets;

public sealed class AssetOptions
{
    /// <summary>Root folder for assets (relative or absolute).</summary>
    public string RootPath { get; set; } = "assets";

    /// <summary>Private cache max-age in seconds.</summary>
    public int DefaultCacheSeconds { get; set; } = 300;
}
