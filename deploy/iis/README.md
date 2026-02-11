# IIS Deployment Scripts

This folder contains PowerShell scripts to automate deployment of **Next.API.DataAssets** to IIS on Windows Server.

## Scripts Overview

### 1. Install-Prereqs.ps1

Installs and configures IIS prerequisites.

**What it does:**
- ✅ Enables IIS and required features
- ✅ Checks if ASP.NET Core Module (ANCM) is installed
- ✅ Performs IIS reset

**Usage:**
```powershell
# Run as Administrator
.\Install-Prereqs.ps1

# Skip IIS reset
.\Install-Prereqs.ps1 -SkipIISReset
```

**Note:** You must still manually download and install the .NET Hosting Bundle after running this script.

---

### 2. Provision-Site.ps1

Creates or updates IIS site and application pool.

**What it does:**
- ✅ Creates Application Pool (No Managed Code, 64-bit)
- ✅ Creates IIS Site or Application
- ✅ Sets up directory structure (logs, assets)
- ✅ Configures NTFS permissions

**Usage:**
```powershell
# Run as Administrator

# Default: Create site on port 80
.\Provision-Site.ps1

# Custom port and hostname
.\Provision-Site.ps1 -Port 8080 -HostName "dataassets.company.com"

# Custom site path
.\Provision-Site.ps1 -SitePath "D:\WebApps\DataAssets"

# Create as application under Default Web Site
.\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
```

**Parameters:**
- `-SiteName`: Name of the IIS site (default: "DataAssets")
- `-AppPoolName`: Name of the application pool (default: "DataAssets")
- `-SitePath`: Physical path for the application (default: "C:\inetpub\dataassets")
- `-Port`: HTTP port (default: 80)
- `-HostName`: Optional host name binding
- `-UseDefaultWebSite`: Create as app under "Default Web Site"
- `-AppPath`: Virtual path when using -UseDefaultWebSite

---

### 3. Publish-And-Zip.ps1

Publishes the application and creates a deployment ZIP package.

**What it does:**
- ✅ Publishes application for specified framework
- ✅ Copies web.config
- ✅ Creates example appsettings.Production.json
- ✅ Generates deployment README
- ✅ Creates ZIP package ready for deployment

**Usage:**
```powershell
# From repository root or this folder

# Publish net8.0 (default - for Windows Server 2012 R2+)
.\Publish-And-Zip.ps1

# Publish net10.0 (for Windows Server 2016+)
.\Publish-And-Zip.ps1 -Framework net10.0

# Include sample assets
.\Publish-And-Zip.ps1 -IncludeAssets

# Custom output path
.\Publish-And-Zip.ps1 -OutputPath "C:\Deploy\Output"
```

**Parameters:**
- `-Configuration`: Build configuration (default: Release)
- `-Framework`: Target framework - "net8.0" or "net10.0" (default: net8.0)
- `-OutputPath`: Output directory for publish
- `-ZipPath`: Path for output ZIP file
- `-IncludeAssets`: Include sample assets folder

**Output:**
- Creates `publish/` folder with application files
- Creates `Next.API.DataAssets-{framework}-{timestamp}.zip` package

---

## Complete Deployment Workflow

### On Your Development Machine

1. **Publish and package the application:**
   ```powershell
   cd deploy\iis
   .\Publish-And-Zip.ps1 -Framework net8.0
   ```

2. **Transfer the ZIP file to your Windows Server**

### On the Windows Server

3. **Install prerequisites:**
   ```powershell
   # Run as Administrator
   cd deploy\iis
   .\Install-Prereqs.ps1
   ```

4. **Install .NET Hosting Bundle:**
   - Download from https://dotnet.microsoft.com/download/dotnet/8.0
   - Run the installer
   - Run `iisreset`

5. **Create IIS site:**
   ```powershell
   .\Provision-Site.ps1
   ```

6. **Deploy application:**
   - Extract the ZIP to your site path (e.g., C:\inetpub\dataassets)
   - Configure `appsettings.Production.json`
   - Add your data assets to the `assets` folder

7. **Test:**
   ```powershell
   Invoke-WebRequest http://localhost/healthz
   ```

---

## Troubleshooting

### Script requires Administrator
All scripts require Administrator privileges. Right-click PowerShell and select "Run as Administrator".

### Execution Policy Error
If you get "cannot be loaded because running scripts is disabled", run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### IIS Features Installation Failed
Try running Windows Update first, then run the script again.

### ANCM Not Found
The script checks for ANCM but doesn't install it. You must:
1. Download the .NET Hosting Bundle
2. Install it
3. Run `iisreset`

### Permissions Issues
The script tries to set NTFS permissions but may fail in some scenarios. Manually grant permissions:
```powershell
$identity = "IIS AppPool\DataAssets"
icacls "C:\inetpub\dataassets" /grant "${identity}:(OI)(CI)RX"
icacls "C:\inetpub\dataassets\logs" /grant "${identity}:(OI)(CI)M"
```

---

## Additional Resources

- **Detailed Deployment Guide:** [DEPLOYMENT-WindowsServer2012R2.md](../../DEPLOYMENT-WindowsServer2012R2.md)
- **Main README:** [README.md](../../README.md)
- **Repository:** https://github.com/davidop/Next.API.DataAssets

---

## Script Compatibility

- **Windows Server 2012 R2**: ✅ All scripts supported (use net8.0)
- **Windows Server 2016+**: ✅ All scripts supported (use net8.0 or net10.0)
- **Windows 10/11**: ✅ Scripts work with IIS enabled

---

## Security Notes

1. Always review scripts before running them as Administrator
2. The scripts are idempotent - safe to run multiple times
3. Existing sites/app pools are updated, not replaced
4. Backup your configuration before running updates
