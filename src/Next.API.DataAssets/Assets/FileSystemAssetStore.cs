using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;

namespace Next.API.DataAssets.Assets;

public sealed class FileSystemAssetStore : IAssetStore
{
    private readonly IFileProvider _provider;
    private readonly string _rootPath;
    private readonly FileExtensionContentTypeProvider _contentTypes = new();

    public FileSystemAssetStore(IFileProvider provider, string rootPath)
    {
        _provider = provider;
        _rootPath = rootPath;
    }

    public Task<Stream?> OpenReadAsync(string safeFileName, CancellationToken ct)
    {
        var info = _provider.GetFileInfo(safeFileName);
        if (!info.Exists || info.IsDirectory) return Task.FromResult<Stream?>(null);
        // Note: PhysicalFileProvider returns a stream without needing async; this is fine for file I/O here.
        return Task.FromResult<Stream?>(info.CreateReadStream());
    }

    public Task<AssetMetadata?> GetMetadataAsync(string safeFileName, CancellationToken ct)
    {
        var info = _provider.GetFileInfo(safeFileName);
        if (!info.Exists || info.IsDirectory) return Task.FromResult<AssetMetadata?>(null);

        var contentType = _contentTypes.TryGetContentType(info.Name, out var ctOut)
            ? ctOut
            : "application/octet-stream";

        var last = info.LastModified.ToUniversalTime();
        var etag = AssetETag.Compute(info.Length, last);

        return Task.FromResult<AssetMetadata?>(new AssetMetadata(
            FileName: info.Name,
            ContentType: contentType,
            SizeBytes: info.Length,
            LastModifiedUtc: last,
            ETag: etag
        ));
    }
}
