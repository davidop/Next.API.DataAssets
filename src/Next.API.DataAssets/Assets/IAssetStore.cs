namespace Next.API.DataAssets.Assets;

public interface IAssetStore
{
    Task<Stream?> OpenReadAsync(string safeFileName, CancellationToken ct);
    Task<AssetMetadata?> GetMetadataAsync(string safeFileName, CancellationToken ct);
}
