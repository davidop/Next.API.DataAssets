namespace Next.API.DataAssets.Assets;

public sealed record AssetMetadata(
    string FileName,
    string ContentType,
    long SizeBytes,
    DateTimeOffset LastModifiedUtc,
    string ETag
);
