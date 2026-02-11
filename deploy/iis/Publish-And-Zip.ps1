<#
.SYNOPSIS
    Publishes Next.API.DataAssets for IIS deployment and creates a ZIP package

.DESCRIPTION
    This script:
    - Publishes the application for net8.0 (Windows Server 2012 R2 compatible)
    - Framework-dependent deployment (requires .NET runtime on target server)
    - Includes web.config and example appsettings
    - Creates a ZIP file ready for deployment

.PARAMETER Configuration
    Build configuration (default: Release)

.PARAMETER Framework
    Target framework (default: net8.0)

.PARAMETER OutputPath
    Output directory for publish (default: ./publish)

.PARAMETER ZipPath
    Path for the output ZIP file (default: ./Next.API.DataAssets-{framework}-{date}.zip)

.PARAMETER IncludeAssets
    Include sample assets folder in the deployment

.EXAMPLE
    .\Publish-And-Zip.ps1
    Publishes net8.0 release build

.EXAMPLE
    .\Publish-And-Zip.ps1 -Framework net10.0
    Publishes net10.0 release build

.EXAMPLE
    .\Publish-And-Zip.ps1 -IncludeAssets
    Publishes with sample assets folder

.NOTES
    Run this from the repository root or adjust paths accordingly
#>

[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [ValidateSet("net8.0", "net10.0")]
    [string]$Framework = "net8.0",
    [string]$OutputPath = "",
    [string]$ZipPath = "",
    [switch]$IncludeAssets
)

$ErrorActionPreference = 'Stop'

# Color output functions
function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-StepWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-StepError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - Publish & Zip" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine repository root
$scriptPath = $PSScriptRoot
$repoRoot = Split-Path (Split-Path $scriptPath -Parent) -Parent

# Set default paths if not specified
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot "publish"
}

if (-not $ZipPath) {
    $dateStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ZipPath = Join-Path $repoRoot "Next.API.DataAssets-${Framework}-${dateStamp}.zip"
}

# Project path
$projectPath = Join-Path $repoRoot "src\Next.API.DataAssets\Next.API.DataAssets.csproj"

if (-not (Test-Path $projectPath)) {
    Write-StepError "Project file not found: $projectPath"
    Write-Host "  Make sure to run this script from the deploy/iis folder or adjust paths" -ForegroundColor Red
    exit 1
}

# Step 1: Clean previous publish
Write-Step "Cleaning previous publish output..."
if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Recurse -Force
    Write-Success "Cleaned: $OutputPath"
}

# Step 2: Publish the application
Write-Step "Publishing application..."
Write-Host "  Project:      $projectPath" -ForegroundColor Gray
Write-Host "  Framework:    $Framework" -ForegroundColor Gray
Write-Host "  Configuration: $Configuration" -ForegroundColor Gray
Write-Host "  Output:       $OutputPath" -ForegroundColor Gray
Write-Host ""

try {
    $publishArgs = @(
        "publish",
        $projectPath,
        "-c", $Configuration,
        "-f", $Framework,
        "-r", "win-x64",
        "--self-contained", "false",
        "-o", $OutputPath,
        "/p:PublishReadyToRun=false"
    )
    
    & dotnet @publishArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-StepError "Publish failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Success "Application published successfully"
}
catch {
    Write-StepError "Publish failed: $_"
    exit 1
}

# Step 3: Copy web.config
Write-Step "Copying web.config..."
$webConfigSource = Join-Path $repoRoot "deploy\web.config"
$webConfigDest = Join-Path $OutputPath "web.config"

if (Test-Path $webConfigSource) {
    Copy-Item -Path $webConfigSource -Destination $webConfigDest -Force
    Write-Success "web.config copied"
}
else {
    Write-StepWarning "web.config not found at: $webConfigSource"
}

# Step 4: Create example production appsettings
Write-Step "Creating example appsettings files..."
$appsettingsProductionExample = @"
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
      "SigningKey": "CHANGE-THIS-TO-A-SECURE-KEY-MINIMUM-32-CHARACTERS-LONG",
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ClockSkewSeconds": 30
    },
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "production-client-1",
          "Owner": "Production Client 1",
          "KeyHash": "replace-with-sha256-hash-of-your-api-key",
          "Enabled": true
        }
      ]
    }
  },
  "RateLimiting": {
    "IpRateLimitOptions": {
      "EnableEndpointRateLimiting": true,
      "StackBlockedRequests": false,
      "RealIpHeader": "X-Real-IP",
      "ClientIdHeader": "X-ClientId",
      "HttpStatusCode": 429,
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 60
        }
      ]
    },
    "IpRateLimitPolicies": {
      "IpRules": []
    }
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.AspNetCore.Hosting.Diagnostics": "Information"
    }
  },
  "AllowedHosts": "*"
}
"@

$appsettingsExamplePath = Join-Path $OutputPath "appsettings.Production.json.example"
$appsettingsProductionExample | Out-File -FilePath $appsettingsExamplePath -Encoding UTF8 -Force
Write-Success "Created: appsettings.Production.json.example"

# Step 5: Create README for deployment
Write-Step "Creating deployment README..."
$readmeContent = @"
# Next.API.DataAssets - IIS Deployment Package

This package contains a framework-dependent deployment of Next.API.DataAssets for $Framework.

## Prerequisites on Target Server

1. **Windows Server 2012 R2 or later** (for net8.0)
   - Windows Server 2016 or later (for net10.0)

2. **.NET Hosting Bundle**
   - For net8.0: Download from https://dotnet.microsoft.com/download/dotnet/8.0
   - For net10.0: Download from https://dotnet.microsoft.com/download/dotnet/10.0
   - Includes ASP.NET Core Runtime + IIS Module (ANCM)

3. **IIS with required features**
   - Use the Install-Prereqs.ps1 script (included in source repository)

## Deployment Steps

1. **Install Prerequisites**
   - Run Install-Prereqs.ps1 (from source repo deploy/iis/)
   - Install .NET Hosting Bundle
   - Run 'iisreset'

2. **Create IIS Site**
   - Run Provision-Site.ps1 (from source repo deploy/iis/)
   - Or manually create site with Application Pool (No Managed Code)

3. **Deploy Files**
   - Copy all files from this package to your IIS site path (e.g., C:\inetpub\dataassets)
   - Ensure web.config is in the root

4. **Configure Application**
   - Rename appsettings.Production.json.example to appsettings.Production.json
   - Edit appsettings.Production.json or use web.config environment variables
   - IMPORTANT: Change Auth:Jwt:SigningKey to a secure value
   - Configure your API Keys (use SHA-256 hashes)

5. **Add Data Assets**
   - Create 'assets' folder in the deployment directory
   - Copy your CSV or other data files to the assets folder

6. **Test Deployment**
   ```powershell
   Invoke-WebRequest http://localhost/healthz
   ```
   Should return JSON with status "healthy"

## Configuration via Environment Variables

You can override appsettings.json values using environment variables in web.config:

```xml
<environmentVariable name="Assets__RootPath" value="C:\Data\Assets" />
<environmentVariable name="Auth__Jwt__SigningKey" value="your-production-key" />
```

## Generate API Key Hash

```powershell
`$key = "your-api-key-secret"
`$bytes = [System.Text.Encoding]::UTF8.GetBytes(`$key)
`$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash(`$bytes)
-join (`$hash | ForEach-Object { `$_.ToString("x2") })
```

## Troubleshooting

### 500.30 - ASP.NET Core app failed to start
- Check if .NET Hosting Bundle is installed
- Run 'dotnet --list-runtimes' to verify runtime
- Check logs in .\logs\stdout-*.log

### 502.5 - Process Failure
- Check Application Pool identity has permissions
- Verify web.config processPath and arguments
- Check Event Viewer > Application logs

### Enable Detailed Logging
In web.config, set:
```xml
<aspNetCore ... stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" ...>
```

## Support

For issues and documentation:
- Repository: https://github.com/davidop/Next.API.DataAssets
- Deployment Guide: DEPLOYMENT-WindowsServer2012R2.md

"@

$readmePath = Join-Path $OutputPath "DEPLOYMENT-README.txt"
$readmeContent | Out-File -FilePath $readmePath -Encoding UTF8 -Force
Write-Success "Created: DEPLOYMENT-README.txt"

# Step 6: Include sample assets if requested
if ($IncludeAssets) {
    Write-Step "Including sample assets..."
    $sourceAssetsPath = Join-Path $repoRoot "src\Next.API.DataAssets\assets"
    $destAssetsPath = Join-Path $OutputPath "assets"
    
    if (Test-Path $sourceAssetsPath) {
        if (-not (Test-Path $destAssetsPath)) {
            New-Item -Path $destAssetsPath -ItemType Directory | Out-Null
        }
        Copy-Item -Path "$sourceAssetsPath\*" -Destination $destAssetsPath -Recurse -Force
        Write-Success "Sample assets included"
    }
    else {
        Write-StepWarning "Source assets folder not found: $sourceAssetsPath"
    }
}

# Step 7: Create ZIP package
Write-Step "Creating ZIP package..."
try {
    if (Test-Path $ZipPath) {
        Remove-Item -Path $ZipPath -Force
    }
    
    Compress-Archive -Path "$OutputPath\*" -DestinationPath $ZipPath -CompressionLevel Optimal
    
    $zipSize = (Get-Item $ZipPath).Length / 1MB
    Write-Success "ZIP package created: $ZipPath"
    Write-Host "  Size: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Gray
}
catch {
    Write-StepError "Failed to create ZIP: $_"
    exit 1
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Publish Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Published to:  $OutputPath" -ForegroundColor Green
Write-Host "ZIP package:   $ZipPath" -ForegroundColor Green
Write-Host "Framework:     $Framework" -ForegroundColor Gray
Write-Host ""
Write-Host "DEPLOYMENT:" -ForegroundColor Cyan
Write-Host "1. Transfer $ZipPath to your Windows Server" -ForegroundColor Gray
Write-Host "2. Extract to your IIS site path (e.g., C:\inetpub\dataassets)" -ForegroundColor Gray
Write-Host "3. Configure appsettings.Production.json" -ForegroundColor Gray
Write-Host "4. Test with: http://your-server/healthz" -ForegroundColor Gray
Write-Host ""

exit 0
