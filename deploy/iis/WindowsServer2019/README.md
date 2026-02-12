# Windows Server 2019 Deployment Scripts

This folder contains PowerShell scripts specifically designed and tested for **Windows Server 2019** deployment of Next.API.DataAssets.

## 📋 Prerequisites

- Windows Server 2019 (Build 17763 or later)
- Administrator privileges
- PowerShell 5.1 or later

## 🚀 Quick Start

### 1. Install Prerequisites

```powershell
# Run as Administrator
cd deploy\iis\WindowsServer2019
.\Install-Prereqs.ps1
```

This script will:
- ✅ Verify Windows Server 2019
- ✅ Enable IIS and required features
- ✅ Check for ASP.NET Core Module (ANCM)
- ✅ Validate .NET runtime installations

**Important**: After running this script, install the .NET Hosting Bundle:
- [.NET 8 Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/8.0) (Recommended - LTS)
- [.NET 10 Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/10.0) (Standard Term Support)

Then run `.\Install-Prereqs.ps1` again to verify.

### 2. Provision IIS Site

```powershell
# Default: Creates site on port 80
.\Provision-Site.ps1

# OR with custom settings
.\Provision-Site.ps1 -Port 8080 -HostName "dataassets.yourcompany.com"

# OR as application under Default Web Site
.\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
```

This script will:
- ✅ Create Application Pool (No Managed Code, 64-bit)
- ✅ Create IIS Site or Application
- ✅ Set up directory structure (logs, assets)
- ✅ Configure NTFS permissions

### 3. Deploy Application

From your **development machine** or **build server**:

```powershell
# Option A: Use the included publish script
cd deploy\iis
.\Publish-And-Zip.ps1 -Framework net8.0

# This creates: Next.API.DataAssets-net8.0-{timestamp}.zip
# Transfer to Windows Server 2019
```

On **Windows Server 2019**:

```powershell
# Extract to site path
Expand-Archive -Path "Next.API.DataAssets-net8.0-*.zip" `
               -DestinationPath "C:\inetpub\dataassets" -Force
```

### 4. Verify Deployment

```powershell
# Run smoke test
.\Smoke-Test.ps1

# OR test with API key
.\Smoke-Test.ps1 -ApiKey "your-api-key-here"

# OR test custom URL
.\Smoke-Test.ps1 -Url "http://dataassets.yourcompany.com"
```

## 📜 Scripts Overview

### Install-Prereqs.ps1

**Purpose**: Install and verify IIS prerequisites

**Parameters**:
- `-SkipIISReset`: Skip IIS reset at the end (optional)

**What it does**:
- Verifies Windows Server 2019
- Checks for pending Windows Updates
- Enables IIS and required features
- Checks for ASP.NET Core Module (ANCM)
- Validates .NET runtime installations
- Performs IIS reset

**Example**:
```powershell
.\Install-Prereqs.ps1
.\Install-Prereqs.ps1 -SkipIISReset
```

---

### Provision-Site.ps1

**Purpose**: Create or update IIS site and application pool

**Parameters**:
- `-SiteName`: Name of the IIS site (default: "DataAssets")
- `-AppPoolName`: Name of the application pool (default: "DataAssets")
- `-SitePath`: Physical path for the application (default: "C:\inetpub\dataassets")
- `-Port`: HTTP port for the site (default: 80)
- `-HostName`: Optional host name binding
- `-UseDefaultWebSite`: Create as application under Default Web Site
- `-AppPath`: Virtual path when using -UseDefaultWebSite (default: "/dataassets")

**What it does**:
- Creates or updates Application Pool with ASP.NET Core settings
- Creates or updates IIS Site or Application
- Sets up directory structure (logs, assets)
- Configures NTFS permissions for App Pool identity
- Starts the site and app pool

**Examples**:
```powershell
# Default settings
.\Provision-Site.ps1

# Custom port and hostname
.\Provision-Site.ps1 -Port 8080 -HostName "dataassets.company.com"

# Custom path
.\Provision-Site.ps1 -SitePath "D:\WebApps\DataAssets"

# Application under Default Web Site
.\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
```

---

### Smoke-Test.ps1

**Purpose**: Verify deployment is working

**Parameters**:
- `-Url`: Base URL of the deployed application (default: "http://localhost")
- `-ApiKey`: Optional API key to test authenticated endpoints
- `-SkipAuthTest`: Skip testing authenticated endpoints

**What it does**:
- Tests `/health` endpoint (basic health check)
- Tests `/healthz` endpoint (detailed health check)
- Optionally tests authenticated `/resources/*` endpoint
- Provides detailed diagnostics on failure

**Examples**:
```powershell
# Basic test
.\Smoke-Test.ps1

# Test specific URL
.\Smoke-Test.ps1 -Url "http://dataassets.company.com"

# Test with authentication
.\Smoke-Test.ps1 -ApiKey "your-api-key-here"

# Test on custom port
.\Smoke-Test.ps1 -Url "http://localhost:8080" -ApiKey "test-key"
```

---

## 📚 Complete Deployment Workflow

### On Windows Server 2019

1. **Install prerequisites**
   ```powershell
   cd deploy\iis\WindowsServer2019
   .\Install-Prereqs.ps1
   ```

2. **Install .NET Hosting Bundle**
   - Download from https://dotnet.microsoft.com/download/dotnet/8.0
   - Run the installer
   - Run `iisreset`
   - Verify: `.\Install-Prereqs.ps1`

3. **Provision IIS site**
   ```powershell
   .\Provision-Site.ps1
   ```

4. **Deploy application files**
   - Extract deployment ZIP to C:\inetpub\dataassets
   - OR copy publish folder contents

5. **Configure settings**
   ```powershell
   cd C:\inetpub\dataassets
   Copy-Item appsettings.Production.json.example appsettings.Production.json
   notepad appsettings.Production.json
   ```

6. **Add data assets**
   ```powershell
   Copy-Item "C:\your-data\*.csv" "C:\inetpub\dataassets\assets\"
   ```

7. **Verify deployment**
   ```powershell
   cd deploy\iis\WindowsServer2019
   .\Smoke-Test.ps1
   ```

## 🔧 Troubleshooting

### Script requires Administrator

All scripts require Administrator privileges.

**Solution**: Right-click PowerShell and select "Run as Administrator"

### Execution Policy Error

**Error**: "cannot be loaded because running scripts is disabled"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### IIS Features Installation Failed

**Solution**:
1. Run Windows Update
2. Restart server
3. Run `.\Install-Prereqs.ps1` again

### ANCM Not Found

**Solution**:
1. Download .NET Hosting Bundle
2. Install it
3. Run `iisreset`
4. Run `.\Install-Prereqs.ps1` to verify

### Smoke Test Fails

**Check**:
1. IIS is running: `Get-Service W3SVC`
2. App Pool is started: `Get-WebAppPoolState -Name "DataAssets"`
3. Site is started: `Get-Website -Name "DataAssets"`
4. Logs: `C:\inetpub\dataassets\logs\stdout_*.log`
5. Event Viewer: Application logs

**Common fixes**:
```powershell
# Restart IIS
iisreset

# Restart just the app pool
Restart-WebAppPool -Name "DataAssets"

# Enable stdout logging in web.config
# Set stdoutLogEnabled="true"

# Check permissions
$identity = "IIS AppPool\DataAssets"
icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)RX"
icacls "C:\inetpub\dataassets\logs" /grant "${identity}:(OI)(CI)M"
```

## 📖 Additional Documentation

- **Deployment Guide**: [/docs/deploy/IIS-WindowsServer2019.md](../../../docs/deploy/IIS-WindowsServer2019.md)
- **Compatibility Analysis**: [/docs/compatibility/WINDOWS_SERVER_2019.md](../../../docs/compatibility/WINDOWS_SERVER_2019.md)
- **Configuration Reference**: [/docs/CONFIGURATION.md](../../../docs/CONFIGURATION.md)
- **Main README**: [/README.md](../../../README.md)

## 🆚 Differences from Generic IIS Scripts

These scripts are specifically optimized for Windows Server 2019:

| Feature | Generic Scripts | Windows Server 2019 Scripts |
|---------|----------------|----------------------------|
| OS Verification | Generic Windows | Checks for Build 17763+ |
| Windows Updates Check | No | Yes |
| Optimized Settings | Basic | Windows Server 2019 specific |
| Documentation | General | Server 2019 specific |
| Error Messages | Generic | Server 2019 context |

## ⚠️ Important Notes

### Windows Server 2019 vs Other Versions

- ✅ **Windows Server 2019**: Use these scripts
- ✅ **Windows Server 2016/2022**: These scripts work, but generic scripts (`/deploy/iis/`) are also fine
- ⚠️ **Windows Server 2012 R2**: Use generic scripts (`/deploy/iis/`), .NET 8 only

### .NET Version Selection

- **For production**: Use .NET 8 (LTS - supported until November 2026)
- **For latest features**: Use .NET 10 (STS - supported until May 2026)
- Both are fully compatible with Windows Server 2019

### Hosting Model Selection

- **InProcess** (Recommended for Windows Server 2019):
  - Best performance (~30% faster)
  - Runs inside IIS process
  - Edit `web.config`: `hostingModel="inprocess"`

- **OutOfProcess** (Maximum compatibility):
  - Better isolation
  - Easier debugging
  - Default in `deploy/web.config`

## 🔒 Security Notes

1. **Always review scripts before running as Administrator**
2. Scripts are idempotent - safe to run multiple times
3. Existing sites/app pools are updated, not replaced
4. Backup your configuration before running updates
5. Use strong API keys and rotate regularly
6. Configure `appsettings.Production.json` securely

## 📞 Support

For issues specific to Windows Server 2019 deployment:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review [/docs/deploy/IIS-WindowsServer2019.md](../../../docs/deploy/IIS-WindowsServer2019.md)
3. Check [/docs/compatibility/WINDOWS_SERVER_2019.md](../../../docs/compatibility/WINDOWS_SERVER_2019.md)

For general ASP.NET Core and IIS issues:
- Microsoft Docs: https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/

---

**Last Updated**: 2026-02-12  
**Tested On**: Windows Server 2019 (Build 17763), .NET 8.0.11, .NET 10.0.2
