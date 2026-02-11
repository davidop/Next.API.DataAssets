# Deployment Guide: Windows Server 2012 R2 with IIS

This guide provides detailed instructions for deploying **Next.API.DataAssets** on **Windows Server 2012 R2** using IIS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

---

## Prerequisites

### 1. Windows Server Requirements

- **Windows Server 2012 R2** with latest updates
  - **IMPORTANT**: Windows Server 2012 R2 reached end of support. Extended Security Updates (ESU) recommended for production use.
  - For .NET 10, you need **Windows Server 2016 or later**

### 2. .NET Runtime

This application uses **.NET 8 (LTS)** for compatibility with Windows Server 2012 R2.

**Download .NET 8 Hosting Bundle:**
- URL: https://dotnet.microsoft.com/download/dotnet/8.0
- Select: **Hosting Bundle** (includes ASP.NET Core Runtime + IIS Module)
- Minimum version: .NET 8.0.0

> **Note**: The Hosting Bundle includes:
> - ASP.NET Core Runtime
> - .NET Runtime
> - ASP.NET Core Module (ANCM) for IIS

### 3. IIS (Internet Information Services)

Required IIS roles and features:
- Web Server (IIS)
- Web Server → Common HTTP Features:
  - Default Document
  - Directory Browsing
  - HTTP Errors
  - Static Content
- Web Server → Health and Diagnostics:
  - HTTP Logging
- Web Server → Performance:
  - Static Content Compression
  - Dynamic Content Compression
- Web Server → Security:
  - Request Filtering
- Web Server → Application Development:
  - ISAPI Extensions
  - ISAPI Filters
- Management Tools:
  - IIS Management Console

---

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Windows Server 2012 R2 | Windows Server 2016+ |
| **RAM** | 2 GB | 4 GB+ |
| **CPU** | 2 cores | 4+ cores |
| **Disk Space** | 1 GB | 5 GB+ (depending on assets) |
| **.NET Runtime** | .NET 8.0 | .NET 8.0 (latest patch) |

---

## Installation Steps

### Option A: Using PowerShell Scripts (Recommended)

The repository includes automated PowerShell scripts in `deploy/iis/`:

#### Step 1: Install Prerequisites

```powershell
# Run as Administrator
cd deploy\iis
.\Install-Prereqs.ps1
```

This script:
- ✅ Enables IIS and required features
- ✅ Checks for ASP.NET Core Module (ANCM)
- ✅ Performs IIS reset

**After the script completes:**
1. Download and install the **.NET 8 Hosting Bundle**
2. Run `iisreset` to load the new module

#### Step 2: Create IIS Site and App Pool

```powershell
# Run as Administrator
.\Provision-Site.ps1
```

**Options:**

```powershell
# Default: Creates site on port 80
.\Provision-Site.ps1

# Custom port and hostname
.\Provision-Site.ps1 -Port 8080 -HostName "dataassets.company.com"

# Create as application under Default Web Site
.\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"

# Custom site path
.\Provision-Site.ps1 -SitePath "D:\WebApps\DataAssets"
```

This script creates:
- ✅ Application Pool (No Managed Code, 64-bit)
- ✅ IIS Site or Application
- ✅ Directory structure (logs, assets)
- ✅ NTFS permissions for App Pool identity

#### Step 3: Publish and Package Application

```powershell
# From the repository root
cd deploy\iis
.\Publish-And-Zip.ps1
```

This creates a deployment ZIP file: `Next.API.DataAssets-net8.0-{timestamp}.zip`

**Options:**

```powershell
# Publish net8.0 (default)
.\Publish-And-Zip.ps1

# Publish net10.0 (Windows Server 2016+ only)
.\Publish-And-Zip.ps1 -Framework net10.0

# Include sample assets
.\Publish-And-Zip.ps1 -IncludeAssets
```

#### Step 4: Deploy Files

1. Transfer the ZIP file to the server
2. Extract to your site path (default: `C:\inetpub\dataassets`)
3. Ensure `web.config` is in the root

---

### Option B: Manual Installation

<details>
<summary>Click to expand manual installation steps</summary>

#### Step 1: Enable IIS Features

Open PowerShell as Administrator and run:

```powershell
# Install IIS with required features
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Common-Http
Install-WindowsFeature -Name Web-Default-Doc
Install-WindowsFeature -Name Web-Dir-Browsing
Install-WindowsFeature -Name Web-Http-Errors
Install-WindowsFeature -Name Web-Static-Content
Install-WindowsFeature -Name Web-Health
Install-WindowsFeature -Name Web-Http-Logging
Install-WindowsFeature -Name Web-Performance
Install-WindowsFeature -Name Web-Stat-Compression
Install-WindowsFeature -Name Web-Dyn-Compression
Install-WindowsFeature -Name Web-Security
Install-WindowsFeature -Name Web-Filtering
Install-WindowsFeature -Name Web-App-Dev
Install-WindowsFeature -Name Web-ISAPI-Ext
Install-WindowsFeature -Name Web-ISAPI-Filter
Install-WindowsFeature -Name Web-Mgmt-Console
```

#### Step 2: Install .NET 8 Hosting Bundle

1. Download from: https://dotnet.microsoft.com/download/dotnet/8.0
2. Run the installer: `dotnet-hosting-8.x.x-win.exe`
3. Restart IIS: `iisreset`

Verify installation:
```powershell
dotnet --list-runtimes
# Should show: Microsoft.AspNetCore.App 8.x.x
```

#### Step 3: Create Application Pool

Open IIS Manager or use PowerShell:

```powershell
Import-Module WebAdministration

# Create App Pool
New-WebAppPool -Name "DataAssets"
Set-ItemProperty IIS:\AppPools\DataAssets -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty IIS:\AppPools\DataAssets -Name "enable32BitAppOnWin64" -Value $false
```

**Critical Settings:**
- **.NET CLR Version**: `No Managed Code`
- **Enable 32-Bit Applications**: `False`
- **Identity**: `ApplicationPoolIdentity` (default)

#### Step 4: Create IIS Site

```powershell
# Create site directory
New-Item -Path "C:\inetpub\dataassets" -ItemType Directory -Force
New-Item -Path "C:\inetpub\dataassets\logs" -ItemType Directory -Force
New-Item -Path "C:\inetpub\dataassets\assets" -ItemType Directory -Force

# Create IIS Site
New-Website -Name "DataAssets" `
            -PhysicalPath "C:\inetpub\dataassets" `
            -ApplicationPool "DataAssets" `
            -Port 80
```

#### Step 5: Set NTFS Permissions

```powershell
$path = "C:\inetpub\dataassets"
$identity = "IIS AppPool\DataAssets"

# Grant permissions
$acl = Get-Acl $path
$permission = $identity, "ReadAndExecute, Write", "ContainerInherit, ObjectInherit", "None", "Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($accessRule)
Set-Acl $path $acl
```

#### Step 6: Publish Application

From your development machine:

```powershell
dotnet publish src/Next.API.DataAssets/Next.API.DataAssets.csproj `
    -c Release `
    -f net8.0 `
    -r win-x64 `
    --self-contained false `
    -o ./publish
```

Copy all files from `./publish` to `C:\inetpub\dataassets` on the server.

#### Step 7: Deploy web.config

Copy `deploy/web.config` to `C:\inetpub\dataassets\web.config`.

</details>

---

## Configuration

### 1. Application Settings

The application is configured via `appsettings.json` and `appsettings.Production.json`.

**Example `appsettings.Production.json`:**

```json
{
  "Assets": {
    "RootPath": "assets",
    "DefaultCacheSeconds": 600
  },
  "Health": {
    "AllowAnonymous": false
  },
  "Auth": {
    "Jwt": {
      "Issuer": "your-company-name",
      "Audience": "dataassets-api",
      "SigningKey": "YOUR-SECURE-KEY-MINIMUM-32-CHARACTERS",
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ClockSkewSeconds": 30
    },
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "client-1",
          "Owner": "Client Name",
          "KeyHash": "sha256-hash-here",
          "Enabled": true
        }
      ]
    }
  },
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
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

### 2. Environment Variables (Alternative)

You can override settings using environment variables in `web.config`:

```xml
<aspNetCore ...>
  <environmentVariables>
    <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
    <environmentVariable name="Assets__RootPath" value="D:\Data\Assets" />
    <environmentVariable name="Auth__Jwt__SigningKey" value="YOUR-SECURE-KEY" />
  </environmentVariables>
</aspNetCore>
```

> **Note**: Use double underscores `__` to represent nested configuration levels.

### 3. Generate API Key Hashes

API Keys are stored as SHA-256 hashes for security:

```powershell
$key = "your-secret-api-key"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })
```

Copy the output hash to `appsettings.json` → `Auth:ApiKeysOptions:Keys[].KeyHash`.

### 4. Data Assets

Place your data files (CSV, JSON, etc.) in the `assets` folder:

```
C:\inetpub\dataassets\
  ├── assets\
  │   ├── DataAsset.csv
  │   └── AnotherFile.json
  ├── logs\
  ├── web.config
  ├── appsettings.json
  └── Next.API.DataAssets.dll
```

Files are accessed via: `GET /resources/{filename}`

---

## Verification

### 1. Health Check

Test that the application is running:

```powershell
Invoke-WebRequest http://localhost/healthz
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-02-11T22:00:00Z",
  "version": "1.0.0",
  "framework": "8.0.11",
  "environment": "Production"
}
```

### 2. Test with Authentication

**Using API Key:**
```powershell
$apiKey = "your-api-key"
Invoke-WebRequest http://localhost/resources/DataAsset.csv -Headers @{"X-API-Key"=$apiKey}
```

**Using JWT Bearer Token:**
```powershell
$token = "your-jwt-token"
Invoke-WebRequest http://localhost/resources/DataAsset.csv -Headers @{"Authorization"="Bearer $token"}
```

---

## Troubleshooting

### Error 500.30 - ASP.NET Core app failed to start

**Causes:**
- .NET Hosting Bundle not installed
- Wrong .NET runtime version
- Missing or corrupt DLL files

**Solutions:**
1. Verify .NET runtime:
   ```powershell
   dotnet --list-runtimes
   # Should show: Microsoft.AspNetCore.App 8.x.x
   ```

2. Enable detailed logging in `web.config`:
   ```xml
   <aspNetCore ... stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" ...>
   ```

3. Check logs in `C:\inetpub\dataassets\logs\stdout-*.log`

4. Check Event Viewer → Windows Logs → Application

### Error 502.5 - Process Failure

**Causes:**
- Incorrect `web.config` settings
- App Pool identity lacks permissions
- Application crash on startup

**Solutions:**
1. Verify `web.config` settings:
   - `processPath="dotnet"`
   - `arguments="Next.API.DataAssets.dll"`
   - `hostingModel="OutOfProcess"`

2. Check App Pool permissions:
   ```powershell
   $identity = "IIS AppPool\DataAssets"
   icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)RX"
   icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)W" /T
   ```

3. Enable stdout logging and check logs

### Error 401 - Unauthorized

**Causes:**
- Invalid or missing authentication credentials
- Incorrect API Key hash
- JWT validation failure

**Solutions:**
1. Verify API Key hash matches:
   ```powershell
   # Generate hash from your key
   $key = "your-api-key"
   $bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
   $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
   -join ($hash | ForEach-Object { $_.ToString("x2") })
   ```

2. For JWT: Verify `SigningKey` matches between issuer and API

3. Check logs for specific auth failures

### Error 404 - Not Found

**Causes:**
- File doesn't exist in assets folder
- Incorrect URL

**Solutions:**
1. Verify file exists: `C:\inetpub\dataassets\assets\{filename}`
2. Check URL: `http://localhost/resources/{filename}`
3. File names are case-sensitive

### Application won't start

**Solutions:**
1. Check App Pool is running:
   ```powershell
   Get-WebAppPoolState -Name "DataAssets"
   Start-WebAppPool -Name "DataAssets"
   ```

2. Restart IIS:
   ```powershell
   iisreset
   ```

3. Check for port conflicts:
   ```powershell
   netstat -ano | findstr :80
   ```

---

## Maintenance

### Updating the Application

1. **Stop the App Pool:**
   ```powershell
   Stop-WebAppPool -Name "DataAssets"
   ```

2. **Backup current deployment:**
   ```powershell
   Copy-Item "C:\inetpub\dataassets" "C:\Backups\dataassets-backup-$(Get-Date -Format 'yyyyMMdd')" -Recurse
   ```

3. **Deploy new version:**
   - Copy new files to `C:\inetpub\dataassets`
   - Preserve `appsettings.Production.json` and `assets` folder

4. **Start the App Pool:**
   ```powershell
   Start-WebAppPool -Name "DataAssets"
   ```

### Updating Data Assets

Simply replace files in the `assets` folder:

```powershell
Copy-Item "\\network\share\DataAsset.csv" "C:\inetpub\dataassets\assets\DataAsset.csv" -Force
```

No restart required - changes take effect immediately.

### Log Management

Enable log rotation or clean old logs periodically:

```powershell
# Delete logs older than 30 days
$logPath = "C:\inetpub\dataassets\logs"
Get-ChildItem -Path $logPath -Recurse -Filter "*.log" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item -Force
```

### Monitoring

Monitor application health:

```powershell
# Schedule this in Task Scheduler
$response = Invoke-WebRequest http://localhost/healthz
if ($response.StatusCode -ne 200) {
    # Send alert
    Write-Host "Application health check failed!"
}
```

---

## Security Best Practices

1. **Use HTTPS in production**
   - Configure SSL certificate in IIS
   - Redirect HTTP to HTTPS

2. **Secure configuration**
   - Use strong `SigningKey` (32+ characters)
   - Store API Keys as SHA-256 hashes only
   - Enable `ValidateIssuer` and `ValidateAudience` for JWT

3. **Restrict health endpoint**
   - Set `Health:AllowAnonymous` to `false` in production
   - Or limit access via firewall rules

4. **File permissions**
   - App Pool identity should have minimal permissions
   - Read/Execute on application files
   - Write only on logs folder

5. **Keep software updated**
   - Apply Windows updates regularly
   - Update .NET runtime to latest patch version
   - Monitor for security advisories

---

## Additional Resources

- **Repository**: https://github.com/davidop/Next.API.DataAssets
- **Main README**: [README.md](README.md)
- **General Deployment Guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **.NET 8 Documentation**: https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/
- **IIS Hosting**: https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/

---

## Support

For issues, questions, or contributions, please open an issue on the GitHub repository.
