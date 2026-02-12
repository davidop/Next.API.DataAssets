# Configuration Reference

This document describes all configuration keys used by **Next.API.DataAssets**.

## Configuration Files

- **appsettings.json**: Default settings (development/testing)
- **appsettings.Production.json**: Production-specific settings (overrides defaults)
- **Environment Variables**: Can override any setting (use double underscore `__` for nested keys)
- **web.config**: IIS-specific environment variables

## Configuration Keys

### Assets Configuration

Controls where and how asset files are served.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Assets:RootPath` | string | `"assets"` | Path to assets folder (relative or absolute) |
| `Assets:DefaultCacheSeconds` | int | `300` | Cache-Control max-age in seconds |

**Examples**:
```json
{
  "Assets": {
    "RootPath": "assets",           // Relative to app root
    "DefaultCacheSeconds": 600      // 10 minutes cache
  }
}
```

```json
{
  "Assets": {
    "RootPath": "D:\\Data\\Assets", // Absolute path on Windows
    "DefaultCacheSeconds": 3600     // 1 hour cache
  }
}
```

**Environment Variable**:
```
Assets__RootPath=D:\Data\Assets
Assets__DefaultCacheSeconds=600
```

---

### Health Check Configuration

Controls health endpoint behavior.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Health:AllowAnonymous` | bool | `true` | Allow anonymous access to `/healthz` endpoint |

**Examples**:
```json
{
  "Health": {
    "AllowAnonymous": true    // /healthz accessible without auth
  }
}
```

```json
{
  "Health": {
    "AllowAnonymous": false   // /healthz requires authentication
  }
}
```

**Notes**:
- `/health` endpoint is always anonymous (simple status check)
- `/healthz` returns detailed info (version, framework, timestamp)
- In production, consider setting to `false` to restrict detailed info

---

### Authentication - JWT Configuration

JWT Bearer token authentication settings.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Auth:Jwt:Issuer` | string | Required | Token issuer identifier |
| `Auth:Jwt:Audience` | string | Required | Token audience identifier |
| `Auth:Jwt:SigningKey` | string | Required | Secret key for token validation (min 32 chars) |
| `Auth:Jwt:ValidateIssuer` | bool | `false` | Validate token issuer claim |
| `Auth:Jwt:ValidateAudience` | bool | `false` | Validate token audience claim |
| `Auth:Jwt:ClockSkewSeconds` | int | `30` | Allowed clock skew for token expiration |

**Production Example**:
```json
{
  "Auth": {
    "Jwt": {
      "Issuer": "yourcompany",
      "Audience": "yourcompany.dataassets",
      "SigningKey": "your-secure-256-bit-signing-key-here-minimum-32-characters",
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ClockSkewSeconds": 30
    }
  }
}
```

**Development Example**:
```json
{
  "Auth": {
    "Jwt": {
      "Issuer": "dev",
      "Audience": "dev.dataassets",
      "SigningKey": "dev-key-not-for-production-use",
      "ValidateIssuer": false,
      "ValidateAudience": false,
      "ClockSkewSeconds": 300
    }
  }
}
```

**Security Notes**:
- ⚠️ **ALWAYS change `SigningKey` in production**
- ✅ Set `ValidateIssuer` and `ValidateAudience` to `true` in production
- ✅ Use a cryptographically secure random key (min 256 bits / 32 bytes)
- ✅ Store signing key in Azure Key Vault or similar secret management

**Environment Variables** (recommended for secrets):
```
Auth__Jwt__SigningKey=your-secure-key
```

---

### Authentication - API Key Configuration

API Key authentication settings (X-API-Key header).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Auth:ApiKeysOptions:HeaderName` | string | `"X-API-Key"` | HTTP header name for API key |
| `Auth:ApiKeysOptions:Keys` | array | `[]` | Array of API key definitions |

**API Key Object**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `KeyId` | string | Yes | Unique identifier for this key |
| `Owner` | string | Yes | Human-readable owner/client name |
| `KeyHash` | string | Yes | SHA-256 hash of the API key (lowercase hex) |
| `Enabled` | bool | Yes | Whether this key is active |

**Example**:
```json
{
  "Auth": {
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "client-1",
          "Owner": "Production Client 1",
          "KeyHash": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
          "Enabled": true
        },
        {
          "KeyId": "client-2",
          "Owner": "Production Client 2",
          "KeyHash": "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4",
          "Enabled": true
        },
        {
          "KeyId": "legacy-client",
          "Owner": "Legacy Client (Deprecated)",
          "KeyHash": "...",
          "Enabled": false
        }
      ]
    }
  }
}
```

**Generating API Key Hash**:

PowerShell:
```powershell
$apiKey = "my-secret-api-key"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($apiKey)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })
```

Linux/macOS:
```bash
echo -n "my-secret-api-key" | sha256sum
```

**Security Notes**:
- ✅ API keys are stored as SHA-256 hashes (never plaintext)
- ✅ Distribute actual API keys securely to clients
- ✅ Use different keys per client for audit trail
- ✅ Disable compromised keys by setting `Enabled: false`
- ⚠️ Rotate API keys periodically

---

### Rate Limiting Configuration

IP-based rate limiting to prevent abuse.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `RateLimiting:IpRateLimitOptions:EnableEndpointRateLimiting` | bool | `true` | Enable per-endpoint rate limits |
| `RateLimiting:IpRateLimitOptions:StackBlockedRequests` | bool | `false` | Count blocked requests toward limit |
| `RateLimiting:IpRateLimitOptions:RealIpHeader` | string | `"X-Real-IP"` | Header containing real client IP (if behind proxy) |
| `RateLimiting:IpRateLimitOptions:ClientIdHeader` | string | `"X-ClientId"` | Optional client identifier header |
| `RateLimiting:IpRateLimitOptions:HttpStatusCode` | int | `429` | HTTP status code for rate limit exceeded |
| `RateLimiting:IpRateLimitOptions:GeneralRules` | array | `[]` | Array of rate limit rules |

**Rate Limit Rule Object**:
| Field | Type | Description |
|-------|------|-------------|
| `Endpoint` | string | Endpoint pattern (e.g., `"*:/resources/*"`) |
| `Period` | string | Time period (`"1s"`, `"1m"`, `"1h"`, `"1d"`) |
| `Limit` | int | Maximum requests in period |

**Examples**:

Conservative (60 req/min):
```json
{
  "RateLimiting": {
    "IpRateLimitOptions": {
      "EnableEndpointRateLimiting": true,
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 60
        }
      ]
    }
  }
}
```

Permissive (120 req/min):
```json
{
  "RateLimiting": {
    "IpRateLimitOptions": {
      "EnableEndpointRateLimiting": true,
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 120
        }
      ]
    }
  }
}
```

Multi-tier:
```json
{
  "RateLimiting": {
    "IpRateLimitOptions": {
      "EnableEndpointRateLimiting": true,
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1s",
          "Limit": 10
        },
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 120
        },
        {
          "Endpoint": "*:/resources/*",
          "Period": "1h",
          "Limit": 5000
        }
      ]
    }
  }
}
```

**Notes**:
- Rate limiting is per-IP address
- If behind a load balancer/proxy, configure `RealIpHeader`
- Use `X-Forwarded-For`, `X-Real-IP`, or custom header
- In-memory storage (resets on app restart)

---

### Logging Configuration

Standard ASP.NET Core logging configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Logging:LogLevel:Default` | string | `"Information"` | Default log level |
| `Logging:LogLevel:Microsoft.AspNetCore` | string | `"Warning"` | ASP.NET Core framework logs |

**Log Levels**: `Trace`, `Debug`, `Information`, `Warning`, `Error`, `Critical`, `None`

**Examples**:

Production (minimal logging):
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

Development (verbose):
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  }
}
```

Troubleshooting (very verbose):
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Trace",
      "Microsoft.AspNetCore": "Debug"
    }
  }
}
```

---

### Other Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `AllowedHosts` | string | `"*"` | Comma-separated list of allowed hosts |

**Example**:
```json
{
  "AllowedHosts": "dataassets.yourcompany.com,api.yourcompany.com"
}
```

---

## Environment Variable Mapping

ASP.NET Core uses double underscore (`__`) to represent nested configuration:

| Configuration Key | Environment Variable |
|-------------------|---------------------|
| `Assets:RootPath` | `Assets__RootPath` |
| `Auth:Jwt:SigningKey` | `Auth__Jwt__SigningKey` |
| `Auth:ApiKeysOptions:HeaderName` | `Auth__ApiKeysOptions__HeaderName` |
| `RateLimiting:IpRateLimitOptions:GeneralRules:0:Limit` | `RateLimiting__IpRateLimitOptions__GeneralRules__0__Limit` |

**In web.config** (IIS):
```xml
<environmentVariables>
  <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
  <environmentVariable name="Auth__Jwt__SigningKey" value="your-key" />
  <environmentVariable name="Assets__RootPath" value="D:\Data\Assets" />
</environmentVariables>
```

**In IIS App Pool Settings**:
1. Open IIS Manager
2. Select Application Pool
3. Advanced Settings → Environment Variables
4. Add variables

---

## Configuration Priority

Configuration sources are read in this order (later sources override earlier):

1. `appsettings.json`
2. `appsettings.{Environment}.json` (e.g., `appsettings.Production.json`)
3. Environment variables
4. Command-line arguments

**Example**: If you have:
- `appsettings.json`: `"Assets:RootPath": "assets"`
- `appsettings.Production.json`: `"Assets:RootPath": "D:\\Data\\Assets"`
- Environment variable: `Assets__RootPath=E:\Production\Assets`

The final value will be: `E:\Production\Assets`

---

## Security Best Practices

### Secrets Management

❌ **DON'T**:
- Commit production secrets to source control
- Use default/example values in production
- Share API keys in plaintext

✅ **DO**:
- Use environment variables for secrets
- Use Azure Key Vault, AWS Secrets Manager, or similar
- Rotate secrets periodically
- Use different secrets per environment

### Production Checklist

- [ ] Change `Auth:Jwt:SigningKey` to a secure random value
- [ ] Set `Auth:Jwt:ValidateIssuer` to `true`
- [ ] Set `Auth:Jwt:ValidateAudience` to `true`
- [ ] Generate and configure real API key hashes
- [ ] Configure appropriate rate limits
- [ ] Set `Logging:LogLevel:Default` to `Information` or higher
- [ ] Configure `AllowedHosts` to specific domains
- [ ] Store secrets in secure vault (not appsettings.json)
- [ ] Review and adjust cache timeouts
- [ ] Consider setting `Health:AllowAnonymous` to `false`

---

## Windows Server Specific Configuration

### IIS web.config

See `/deploy/web.config` for the complete IIS configuration file.

Key settings:
- `hostingModel`: `"inprocess"` or `"outofprocess"`
- `stdoutLogEnabled`: Set to `"true"` for troubleshooting
- Environment variables for production settings

### Windows Service (Kestrel)

If running as Windows Service instead of IIS, configure via:
- `appsettings.Production.json`
- Environment variables in service configuration
- Windows registry (advanced)

---

## Additional Resources

- **ASP.NET Core Configuration**: https://learn.microsoft.com/aspnet/core/fundamentals/configuration/
- **Environment Variables**: https://learn.microsoft.com/aspnet/core/fundamentals/configuration/#environment-variables
- **Azure Key Vault**: https://learn.microsoft.com/azure/key-vault/

---

**Last Updated**: 2026-02-12
