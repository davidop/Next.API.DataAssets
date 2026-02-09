using System.Security.Claims;

namespace Next.API.DataAssets.Observability;

public interface IAuditLogger
{
    Task LogDownloadAsync(ClaimsPrincipal user, string fileName, long sizeBytes, HttpContext http, CancellationToken ct);
}

public sealed class AuditLogger : IAuditLogger
{
    private readonly ILogger<AuditLogger> _logger;
    private readonly ICorrelationIdAccessor _cid;

    public AuditLogger(ILogger<AuditLogger> logger, ICorrelationIdAccessor cid)
    {
        _logger = logger;
        _cid = cid;
    }

    public Task LogDownloadAsync(ClaimsPrincipal user, string fileName, long sizeBytes, HttpContext http, CancellationToken ct)
    {
        var sub = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub") ?? "unknown";
        var authMethod = user.FindFirstValue("auth_method") ?? user.Identity?.AuthenticationType ?? "unknown";
        var ip = http.Connection.RemoteIpAddress?.ToString();

        _logger.LogInformation("asset_download cid={CorrelationId} user={User} auth={Auth} ip={Ip} file={File} bytes={Bytes}",
            _cid.Current, sub, authMethod, ip, fileName, sizeBytes);

        return Task.CompletedTask;
    }
}
