using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System;
#pragma warning disable CS0618

namespace Next.API.DataAssets.Auth;

public sealed class ApiKeyAuthenticationHandler : AuthenticationHandler<ApiKeyAuthenticationOptions>
{
    private readonly IApiKeyValidator _validator;
    private readonly IOptionsMonitor<ApiKeysOptions> _keysOptions;

    public ApiKeyAuthenticationHandler(
        IOptionsMonitor<ApiKeyAuthenticationOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        ISystemClock clock,
        IApiKeyValidator validator,
        IOptionsMonitor<ApiKeysOptions> keysOptions)
        : base(options, logger, encoder, clock)
    {
        _validator = validator;
        _keysOptions = keysOptions;
    }
#pragma warning restore CS0618

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var headerName = _keysOptions.CurrentValue.HeaderName ?? ApiKeyDefaults.HeaderName;

        if (!Request.Headers.TryGetValue(headerName, out var values))
            return AuthenticateResult.NoResult();

        var raw = values.ToString();
        var (ok, principal, error) = await _validator.ValidateAsync(raw, Context.RequestAborted);

        if (!ok || principal is null)
            return AuthenticateResult.Fail(error ?? "invalid_api_key");

        return AuthenticateResult.Success(new AuthenticationTicket(principal, ApiKeyDefaults.Scheme));
    }
}
