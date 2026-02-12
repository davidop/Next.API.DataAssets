# Windows Server 2019 IIS Deployment Guide

Complete step-by-step guide for deploying **Next.API.DataAssets** on Windows Server 2019 with IIS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Automated Deployment (Recommended)](#automated-deployment-recommended)
- [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

---

## Prerequisites

### System Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **Operating System** | Windows Server 2019 (Build 17763+) | All editions supported |
| **OS Updates** | Latest cumulative updates | Critical for security and stability |
| **.NET Runtime** | .NET 8.0 or .NET 10.0 | LTS (.NET 8) recommended for production |
| **Hosting Bundle** | Matching .NET version | Includes ASP.NET Core Runtime + ANCM |
| **IIS** | Version 10.0 | Included in Windows Server 2019 |
| **RAM** | 4 GB minimum | 8 GB recommended for production |
| **Disk Space** | 2 GB minimum | More if you have large assets |

### Download Links

- **.NET 8 Hosting Bundle (Recommended)**: https://dotnet.microsoft.com/download/dotnet/8.0
  - Look for: "Hosting Bundle" under ASP.NET Core Runtime 8.0
  - Includes: ASP.NET Core 8.0 Runtime + .NET 8.0 Runtime + IIS Module (ANCM)
  - Support until: November 2026 (LTS)

- **.NET 10 Hosting Bundle**: https://dotnet.microsoft.com/download/dotnet/10.0
  - Look for: "Hosting Bundle" under ASP.NET Core Runtime 10.0
  - Includes: ASP.NET Core 10.0 Runtime + .NET 10.0 Runtime + IIS Module (ANCM)
  - Support until: May 2026 (STS)

---

## Automated Deployment (Recommended)

The repository includes PowerShell scripts to automate the deployment process.

### Step 1: Install Prerequisites

On your **Windows Server 2019** machine:

```powershell
# Open PowerShell as Administrator
# Navigate to deployment scripts
cd C:\path\to\Next.API.DataAssets\deploy\iis\WindowsServer2019

# Run prerequisites installer
.\Install-Prereqs.ps1
```

**What this does**:
- ✅ Verifies Windows Server 2019
- ✅ Enables IIS and required features
- ✅ Checks for ASP.NET Core Module (ANCM)
- ✅ Validates .NET runtime installations
- ✅ Performs IIS reset

**After the script completes**:

1. Download and install the .NET Hosting Bundle if not already installed
2. Restart PowerShell to refresh environment variables
3. Run `.\Install-Prereqs.ps1` again to verify

### Step 2: Download and Install .NET Hosting Bundle

If the script reports ANCM is not installed:

```powershell
# Download the Hosting Bundle installer from the link above
# Run the installer (requires Administrator)
# Example filename: dotnet-hosting-8.0.x-win.exe

# After installation, restart IIS
iisreset

# Verify installation
dotnet --list-runtimes
# Should show: Microsoft.AspNetCore.App 8.x.x (or 10.x.x)
```

### Step 3: Create IIS Site and App Pool

```powershell
# Still in PowerShell as Administrator
cd C:\path\to\Next.API.DataAssets\deploy\iis\WindowsServer2019

# Create site with default settings (port 80)
.\Provision-Site.ps1

# OR create site with custom settings
.\Provision-Site.ps1 -Port 8080 -HostName "dataassets.yourcompany.com"

# OR create as application under Default Web Site
.\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
```

**What this does**:
- ✅ Creates Application Pool (No Managed Code, 64-bit)
- ✅ Creates IIS Site or Application
- ✅ Creates directory structure (logs, assets)
- ✅ Configures NTFS permissions
- ✅ Starts the site

### Step 4: Publish and Deploy Application

On your **development machine** or **build server**:

```powershell
# Navigate to repository root
cd C:\path\to\Next.API.DataAssets

# Option A: Use the provided publish script (creates ZIP package)
cd deploy\iis
.\Publish-And-Zip.ps1 -Framework net8.0

# This creates: Next.API.DataAssets-net8.0-{timestamp}.zip
# Transfer this ZIP to your Windows Server 2019
```

On your **Windows Server 2019**:

```powershell
# Extract the ZIP to the site path
Expand-Archive -Path "Next.API.DataAssets-net8.0-*.zip" -DestinationPath "C:\inetpub\dataassets" -Force

# Verify files are present
dir C:\inetpub\dataassets
# Should see: Next.API.DataAssets.dll, web.config, appsettings.json, etc.
```

**Alternative: Manual publish**:

```powershell
# On development machine
dotnet publish src\Next.API.DataAssets\Next.API.DataAssets.csproj `
  -c Release `
  -f net8.0 `
  -r win-x64 `
  --self-contained false `
  -o C:\temp\publish

# Copy files to server
# Then copy web.config
Copy-Item deploy\web.config C:\temp\publish\
```

### Step 5: Configure Production Settings

```powershell
# On Windows Server 2019
cd C:\inetpub\dataassets

# Copy and edit the production configuration
Copy-Item appsettings.Production.json.example appsettings.Production.json
notepad appsettings.Production.json
```

**Required changes** in `appsettings.Production.json`:

```json
{
  "Auth": {
    "Jwt": {
      "SigningKey": "CHANGE-THIS-TO-A-SECURE-256-BIT-KEY-IN-PRODUCTION",
      "ValidateIssuer": true,
      "ValidateAudience": true
    },
    "ApiKeysOptions": {
      "Keys": [
        {
          "KeyId": "client-1",
          "Owner": "Production Client",
          "KeyHash": "GENERATE-SHA256-HASH-OF-YOUR-API-KEY",
          "Enabled": true
        }
      ]
    }
  }
}
```

**Generate API Key Hash**:

```powershell
# In PowerShell
$apiKey = "your-secret-api-key-here"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($apiKey)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })
# Use this hash in appsettings.Production.json
```

### Step 6: Add Data Assets

```powershell
# Copy your data files to the assets folder
Copy-Item "C:\your-data\DataAsset.csv" "C:\inetpub\dataassets\assets\"

# Verify
dir C:\inetpub\dataassets\assets
```

### Step 7: Verify Deployment

```powershell
# Run the smoke test script
cd C:\path\to\Next.API.DataAssets\deploy\iis\WindowsServer2019
.\Smoke-Test.ps1

# OR test with API key
.\Smoke-Test.ps1 -ApiKey "your-api-key-here"

# OR test different URL
.\Smoke-Test.ps1 -Url "http://dataassets.yourcompany.com"
```

If smoke test passes, your deployment is successful! 🎉

---

## Manual Deployment

If you prefer to deploy manually without scripts:

### 1. Enable IIS Features

```powershell
# Run as Administrator
Install-WindowsFeature -Name Web-Server, Web-WebServer, Web-Common-Http, `
  Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, `
  Web-Health, Web-Http-Logging, Web-Performance, Web-Stat-Compression, `
  Web-Dyn-Compression, Web-Security, Web-Filtering, Web-App-Dev, `
  Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Tools, Web-Mgmt-Console

iisreset
```

### 2. Install .NET Hosting Bundle

1. Download from https://dotnet.microsoft.com/download/dotnet/8.0
2. Run the installer
3. Restart IIS: `iisreset`
4. Verify: `dotnet --list-runtimes`

### 3. Create Application Pool

```powershell
Import-Module WebAdministration

# Create Application Pool
New-WebAppPool -Name "DataAssets"

# Configure for ASP.NET Core
Set-ItemProperty IIS:\AppPools\DataAssets -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty IIS:\AppPools\DataAssets -Name "enable32BitAppOnWin64" -Value $false
Set-ItemProperty IIS:\AppPools\DataAssets -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
Set-ItemProperty IIS:\AppPools\DataAssets -Name "startMode" -Value "AlwaysRunning"
```

### 4. Create Directory Structure

```powershell
New-Item -Path "C:\inetpub\dataassets" -ItemType Directory -Force
New-Item -Path "C:\inetpub\dataassets\logs" -ItemType Directory -Force
New-Item -Path "C:\inetpub\dataassets\assets" -ItemType Directory -Force
```

### 5. Set NTFS Permissions

```powershell
# Grant permissions to App Pool identity
$identity = "IIS AppPool\DataAssets"
icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)RX"
icacls "C:\inetpub\dataassets\logs" /grant "${identity}:(OI)(CI)M"
```

### 6. Create IIS Site

```powershell
# Create a new website
New-Website -Name "DataAssets" `
  -Port 80 `
  -PhysicalPath "C:\inetpub\dataassets" `
  -ApplicationPool "DataAssets"

# Start the site
Start-Website -Name "DataAssets"
```

### 7. Publish Application

```powershell
# On your development machine
dotnet publish src\Next.API.DataAssets\Next.API.DataAssets.csproj `
  -c Release `
  -f net8.0 `
  -r win-x64 `
  --self-contained false `
  -o C:\publish\dataassets

# Copy to server
# Then ensure web.config is present
Copy-Item deploy\web.config C:\publish\dataassets\
```

### 8. Deploy Files

Copy all published files to `C:\inetpub\dataassets` on the server.

---

## Configuration

### web.config

The `web.config` file configures ASP.NET Core Module (ANCM) in IIS:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" 
           modules="AspNetCoreModuleV2" resourceType="Unspecified"/>
    </handlers>
    <aspNetCore processPath="dotnet" 
                arguments="Next.API.DataAssets.dll" 
                stdoutLogEnabled="false" 
                stdoutLogFile=".\logs\stdout" 
                hostingModel="inprocess">
      <environmentVariables>
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
      </environmentVariables>
    </aspNetCore>
  </system.webServer>
</configuration>
```

**Key settings**:

- `hostingModel="inprocess"`: Runs in IIS process (best performance)
  - Change to `"outofprocess"` for process isolation
- `stdoutLogEnabled="false"`: Disable for production
  - Change to `"true"` for troubleshooting
- `ASPNETCORE_ENVIRONMENT`: Set to "Production"

### appsettings.Production.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "Assets": {
    "RootPath": "assets",
    "DefaultCacheSeconds": 300
  },
  "Auth": {
    "Jwt": {
      "Issuer": "yourcompany",
      "Audience": "yourcompany.dataassets",
      "SigningKey": "YOUR-SECURE-256-BIT-KEY-HERE",
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ClockSkewSeconds": 30
    },
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "prod-client-1",
          "Owner": "Production Client 1",
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
          "Limit": 120
        }
      ]
    }
  }
}
```

### Environment Variables (Alternative)

You can set configuration via environment variables in `web.config`:

```xml
<environmentVariables>
  <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
  <environmentVariable name="Auth__Jwt__SigningKey" value="YOUR-KEY" />
  <environmentVariable name="Auth__Jwt__ValidateIssuer" value="true" />
</environmentVariables>
```

---

## Verification

### Health Check

```powershell
# Basic health check
Invoke-WebRequest http://localhost/health

# Expected response: {"status":"ok"}

# Detailed health check
Invoke-WebRequest http://localhost/healthz

# Expected response:
# {
#   "status":"healthy",
#   "timestamp":"2026-02-12T17:00:00Z",
#   "version":"1.0.0",
#   "framework":"8.0.11",
#   "environment":"Production"
# }
```

### Test Authentication

```powershell
# Test with API Key
$apiKey = "your-api-key"
Invoke-WebRequest http://localhost/resources/DataAsset.csv -Headers @{"X-API-Key"=$apiKey}

# Should return the file or HTTP 404 if file doesn't exist
# Should NOT return HTTP 401 (authentication failed)
```

### Check Logs

```powershell
# Application logs (if configured)
Get-Content C:\inetpub\dataassets\logs\*.log -Tail 50

# IIS logs
Get-Content C:\inetpub\logs\LogFiles\W3SVC*\*.log -Tail 50

# Event Viewer - Application logs
Get-EventLog -LogName Application -Newest 20 | Where-Object { 
  $_.Source -like '*IIS*' -or $_.Source -like '*ASP.NET*' 
}
```

---

## Troubleshooting

### HTTP 500.30 - ASP.NET Core app failed to start

**Causes**:
- Wrong .NET runtime version
- Missing dependencies
- Configuration errors

**Solutions**:

1. Enable stdout logging in `web.config`:
   ```xml
   <aspNetCore ... stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" ...>
   ```

2. Restart IIS: `iisreset`

3. Check stdout log:
   ```powershell
   Get-Content C:\inetpub\dataassets\logs\stdout_*.log -Tail 100
   ```

4. Verify .NET runtime:
   ```powershell
   dotnet --list-runtimes
   # Should show Microsoft.AspNetCore.App 8.x.x or 10.x.x
   ```

### HTTP 502.5 - Process Failure

**Causes**:
- Application pool stopped
- Kestrel failed to start
- Port conflict

**Solutions**:

1. Check App Pool status:
   ```powershell
   Get-WebAppPoolState -Name "DataAssets"
   ```

2. Start App Pool if stopped:
   ```powershell
   Start-WebAppPool -Name "DataAssets"
   ```

3. Check Event Viewer:
   ```powershell
   Get-EventLog -LogName Application -Newest 50 | 
     Where-Object { $_.EntryType -eq 'Error' }
   ```

### HTTP 503 - Service Unavailable

**Causes**:
- Application pool stopped
- Site stopped
- Rapid fail protection triggered

**Solutions**:

1. Check and start site:
   ```powershell
   Get-Website -Name "DataAssets"
   Start-Website -Name "DataAssets"
   ```

2. Check rapid fail protection:
   ```powershell
   Get-ItemProperty IIS:\AppPools\DataAssets -Name failure.rapidFailProtection
   # Temporarily disable for testing:
   Set-ItemProperty IIS:\AppPools\DataAssets -Name failure.rapidFailProtection -Value $false
   ```

3. Reset App Pool:
   ```powershell
   Restart-WebAppPool -Name "DataAssets"
   ```

### HTTP 500.19 - Configuration Error

**Causes**:
- Invalid web.config
- ANCM not installed

**Solutions**:

1. Verify ANCM is installed:
   ```powershell
   Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
   ```

2. Reinstall Hosting Bundle if missing

3. Validate web.config syntax

### Permission Errors

**Symptoms**:
- Can't write logs
- Can't read configuration

**Solutions**:

```powershell
# Re-apply permissions
$identity = "IIS AppPool\DataAssets"
icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)RX" /T
icacls "C:\inetpub\dataassets\logs" /grant "${identity}:(OI)(CI)M" /T
```

### Common Commands

```powershell
# Restart IIS completely
iisreset

# Restart just your app pool
Restart-WebAppPool -Name "DataAssets"

# Check site status
Get-Website | Select-Object Name, State, PhysicalPath

# Check app pool status
Get-WebAppPoolState -Name "DataAssets"

# View IIS configuration
Get-WebConfiguration -Filter "system.webServer/aspNetCore" -PSPath "IIS:\Sites\DataAssets"
```

---

## Maintenance

### Updating the Application

```powershell
# 1. Stop the app pool
Stop-WebAppPool -Name "DataAssets"

# 2. Deploy new version
Copy-Item -Path C:\updates\* -Destination C:\inetpub\dataassets -Recurse -Force

# 3. Start the app pool
Start-WebAppPool -Name "DataAssets"

# 4. Verify
Invoke-WebRequest http://localhost/healthz
```

### Log Rotation

```powershell
# Clean old logs (older than 30 days)
Get-ChildItem -Path "C:\inetpub\dataassets\logs" -Filter "*.log" | 
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
  Remove-Item
```

### Monitoring

Set up monitoring for:
- `/healthz` endpoint (HTTP 200 expected)
- Application pool state
- Disk space in logs folder
- Event Viewer errors

Example monitoring script:

```powershell
# health-check.ps1
$response = Invoke-WebRequest http://localhost/healthz -UseBasicParsing
if ($response.StatusCode -ne 200) {
    # Send alert
    Write-Error "Health check failed!"
    exit 1
}
```

---

## Additional Resources

- **Compatibility Documentation**: `/docs/compatibility/WINDOWS_SERVER_2019.md`
- **Main README**: `/README.md`
- **ASP.NET Core on IIS**: https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/
- **.NET Downloads**: https://dotnet.microsoft.com/download

---

## Support

For issues specific to this deployment:
1. Check the [Troubleshooting](#troubleshooting) section above
2. Review `/docs/compatibility/WINDOWS_SERVER_2019.md` for known limitations
3. Check stdout logs and Event Viewer

For ASP.NET Core and IIS issues:
- Microsoft Docs: https://learn.microsoft.com/aspnet/core/
- GitHub Issues: https://github.com/dotnet/aspnetcore/issues

---

**Last Updated**: 2026-02-12  
**Tested On**: Windows Server 2019 (Build 17763), .NET 8.0.11, .NET 10.0.2
