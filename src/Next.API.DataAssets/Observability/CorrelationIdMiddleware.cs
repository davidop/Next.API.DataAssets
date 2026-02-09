namespace Next.API.DataAssets.Observability;

public sealed class CorrelationIdMiddleware
{
    public const string HeaderName = "X-Correlation-Id";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next) => _next = next;

    public async Task Invoke(HttpContext context, ICorrelationIdAccessor accessor)
    {
        var cid = context.Request.Headers.TryGetValue(HeaderName, out var v) && !string.IsNullOrWhiteSpace(v)
            ? v.ToString()
            : Guid.NewGuid().ToString("N");

        accessor.Set(cid);

        context.Response.Headers[HeaderName] = cid;
        await _next(context);
    }
}

public interface ICorrelationIdAccessor
{
    string? Current { get; }
    void Set(string correlationId);
}

public sealed class CorrelationIdAccessor : ICorrelationIdAccessor
{
    private string? _current;
    public string? Current => _current;
    public void Set(string correlationId) => _current = correlationId;
}
