using AspNetCoreRateLimit;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using Next.API.DataAssets.Assets;
using Next.API.DataAssets.Auth;
using Next.API.DataAssets.Observability;
using Next.API.DataAssets.Security;
using System.Text;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

// -------------------- Configuration --------------------
builder.Services.Configure<AssetOptions>(builder.Configuration.GetSection("Assets"));
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection("Auth"));
builder.Services.Configure<ApiKeyOptions>(builder.Configuration.GetSection("Auth:ApiKeysOptions"));

// -------------------- Logging / Correlation --------------------
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<ICorrelationIdAccessor, CorrelationIdAccessor>();
builder.Services.AddSingleton<IAuditLogger, AuditLogger>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(opt =>
{
    opt.SwaggerDoc("v1", new() { Title = "Next.API.DataAssets", Version = "v1" });

    // JWT Bearer
    opt.AddSecurityDefinition("Bearer", new()
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "JWT Bearer token. Example: Authorization: Bearer {token}"
    });

    // API Key
    opt.AddSecurityDefinition("ApiKey", new()
    {
        Name = ApiKeyDefaults.HeaderName,
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = $"API Key header. Example: {ApiKeyDefaults.HeaderName}: {{key}}"
    });

    // Document BOTH schemes (OR logic is enforced at runtime via policy scheme)
    opt.AddSecurityRequirement(new()
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        },
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "ApiKey"
                }
            },
            Array.Empty<string>()
        }
    });
});

// -------------------- Rate limiting (basic) --------------------
builder.Services.AddOptions();
builder.Services.AddMemoryCache();
builder.Services.Configure<IpRateLimitOptions>(builder.Configuration.GetSection("RateLimiting:IpRateLimitOptions"));
builder.Services.Configure<IpRateLimitPolicies>(builder.Configuration.GetSection("RateLimiting:IpRateLimitPolicies"));
builder.Services.AddInMemoryRateLimiting();
builder.Services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();

// -------------------- Assets --------------------
builder.Services.AddSingleton<IAssetStore>(sp =>
{
    var opts = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<AssetOptions>>().Value;

    // RootPath supports relative paths; we normalize to an absolute path.
    var rootPath = Path.IsPathRooted(opts.RootPath)
        ? opts.RootPath
        : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, opts.RootPath));

    var provider = new PhysicalFileProvider(rootPath);
    return new FileSystemAssetStore(provider, rootPath);
});

// -------------------- Authentication (JWT OR API Key) --------------------
builder.Services.AddSingleton<IApiKeyStore, InMemoryApiKeyStore>();
builder.Services.AddSingleton<IApiKeyValidator, ApiKeyValidator>();

builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = DualAuthDefaults.Scheme;
})
.AddPolicyScheme(DualAuthDefaults.Scheme, DualAuthDefaults.DisplayName, options =>
{
    options.ForwardDefaultSelector = ctx =>
    {
        // If the API key header exists, validate via ApiKey; otherwise fallback to JWT bearer.
        if (ctx.Request.Headers.ContainsKey(ApiKeyDefaults.HeaderName))
            return ApiKeyDefaults.Scheme;

        return JwtBearerDefaults.AuthenticationScheme;
    };
})
.AddScheme<ApiKeyAuthenticationOptions, ApiKeyAuthenticationHandler>(ApiKeyDefaults.Scheme, _ => { })
.AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
{
    var auth = builder.Configuration.GetSection("Auth:Jwt").Get<JwtOptions>() ?? new JwtOptions();

    // Symmetric signing key (HMAC). Ready to evolve to Authority-based validation if desired.
    var keyBytes = Encoding.UTF8.GetBytes(auth.SigningKey ?? "CHANGE_ME_DEV_ONLY");
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = auth.ValidateIssuer,
        ValidIssuer = auth.Issuer,
        ValidateAudience = auth.ValidateAudience,
        ValidAudience = auth.Audience,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(keyBytes),
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromSeconds(auth.ClockSkewSeconds)
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// -------------------- Middleware --------------------
app.UseMiddleware<CorrelationIdMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseIpRateLimiting();

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
   .WithTags("Health")
   .AllowAnonymous();

app.MapGet("/resources/{filename}", async (
        string filename,
        bool? download,
        HttpContext http,
        IAssetStore store,
        IAuditLogger audit,
        Microsoft.Extensions.Options.IOptions<AssetOptions> assetOptions) =>
    {
        // AuthN/AuthZ: enforced via RequireAuthorization()
        // Input validation
        if (!AssetPathSanitizer.TrySanitizeFileName(filename, out var safeName, out var reason))
            return Results.BadRequest(new { error = "invalid_filename", detail = reason });

        var meta = await store.GetMetadataAsync(safeName, http.RequestAborted);
        if (meta is null)
            return Results.NotFound(new { error = "not_found" });

        // Conditional GET (ETag)
        if (http.Request.Headers.TryGetValue("If-None-Match", out var inm) && inm.ToString() == meta.ETag)
        {
            http.Response.Headers.ETag = meta.ETag;
            return Results.StatusCode(StatusCodes.Status304NotModified);
        }

        var stream = await store.OpenReadAsync(safeName, http.RequestAborted);
        if (stream is null)
            return Results.NotFound(new { error = "not_found" });

        // Cache control
        var cacheSeconds = Math.Max(0, assetOptions.Value.DefaultCacheSeconds);
        http.Response.Headers.CacheControl = $"private, max-age={cacheSeconds}";
        http.Response.Headers.ETag = meta.ETag;
        http.Response.Headers.LastModified = meta.LastModifiedUtc.ToString("R");

        // Security: prevent MIME sniffing
        http.Response.Headers["X-Content-Type-Options"] = "nosniff";

        // Content disposition
        var asAttachment = (download ?? false);
        var fileDownloadName = safeName;
        var contentDisposition = asAttachment ? "attachment" : "inline";
        http.Response.Headers.ContentDisposition = $"{contentDisposition}; filename=\"{fileDownloadName}\"";

        // Audit
        await audit.LogDownloadAsync(http.User, safeName, meta.SizeBytes, http, http.RequestAborted);

        return Results.File(stream, meta.ContentType, fileDownloadName: null, enableRangeProcessing: true);
    })
    .WithTags("Resources")
    .RequireAuthorization();

app.MapControllers();

app.Run();

// Required for WebApplicationFactory in integration tests
public partial class Program { }
