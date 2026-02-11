#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs and configures IIS prerequisites for Next.API.DataAssets on Windows Server 2012 R2+

.DESCRIPTION
    This script:
    - Enables IIS and required features
    - Checks if ASP.NET Core Module (ANCM) is installed
    - Performs an IIS reset
    
    Note: This script does NOT install the .NET Hosting Bundle. You must download and install it manually:
    - For .NET 8: https://dotnet.microsoft.com/download/dotnet/8.0
    - For .NET 10: https://dotnet.microsoft.com/download/dotnet/10.0 (Windows Server 2016+ only)

.PARAMETER SkipIISReset
    Skip the IIS reset at the end

.EXAMPLE
    .\Install-Prereqs.ps1
    
.EXAMPLE
    .\Install-Prereqs.ps1 -SkipIISReset

.NOTES
    Requires Administrator privileges
    Compatible with Windows Server 2012 R2 and later
#>

[CmdletBinding()]
param(
    [switch]$SkipIISReset
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

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - IIS Prerequisites" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Enable IIS features
Write-Step "Enabling IIS and required features..."
try {
    # Core IIS features
    $features = @(
        'Web-Server',
        'Web-WebServer',
        'Web-Common-Http',
        'Web-Default-Doc',
        'Web-Dir-Browsing',
        'Web-Http-Errors',
        'Web-Static-Content',
        'Web-Health',
        'Web-Http-Logging',
        'Web-Performance',
        'Web-Stat-Compression',
        'Web-Dyn-Compression',
        'Web-Security',
        'Web-Filtering',
        'Web-App-Dev',
        'Web-ISAPI-Ext',
        'Web-ISAPI-Filter',
        'Web-Mgmt-Tools',
        'Web-Mgmt-Console'
    )

    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -ge 10 -or ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 3)) {
        # Windows Server 2012 R2 and later
        foreach ($feature in $features) {
            $installed = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
            if ($installed -and -not $installed.Installed) {
                Write-Host "  Installing $feature..."
                Install-WindowsFeature -Name $feature -ErrorAction Stop | Out-Null
            }
        }
    } else {
        # Older systems (if any)
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance -All -NoRestart -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools -All -NoRestart -ErrorAction Stop | Out-Null
    }
    
    Write-Success "IIS features enabled successfully"
}
catch {
    Write-Error "Failed to enable IIS features: $_"
    exit 1
}

# Step 2: Check for ASP.NET Core Module (ANCM)
Write-Step "Checking for ASP.NET Core Module (ANCM)..."
$ancmPath = "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
$ancmInprocPath = "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2_inprocess.dll"

if ((Test-Path $ancmPath) -or (Test-Path $ancmInprocPath)) {
    Write-Success "ASP.NET Core Module is installed"
    
    # Try to get version from registry
    try {
        $ancmVersion = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IIS Extensions\IIS AspNetCore Module V2" -Name Version -ErrorAction SilentlyContinue
        if ($ancmVersion) {
            Write-Host "  Version: $($ancmVersion.Version)" -ForegroundColor Gray
        }
    }
    catch {
        # Ignore if we can't get the version
    }
}
else {
    Write-Warning "ASP.NET Core Module (ANCM) is NOT installed"
    Write-Host ""
    Write-Host "  You must install the .NET Hosting Bundle:" -ForegroundColor Yellow
    Write-Host "  - For .NET 8 (Windows Server 2012 R2+): https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    Write-Host "  - For .NET 10 (Windows Server 2016+ only): https://dotnet.microsoft.com/download/dotnet/10.0" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  After installing the Hosting Bundle, run this script again." -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Check .NET Runtime installations
Write-Step "Checking installed .NET runtimes..."
$runtimes = dotnet --list-runtimes 2>$null
if ($LASTEXITCODE -eq 0 -and $runtimes) {
    Write-Host "  Installed runtimes:" -ForegroundColor Gray
    $runtimes | Where-Object { $_ -match 'Microsoft\.AspNetCore\.App' } | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Gray
    }
}
else {
    Write-Warning ".NET CLI not found or no runtimes detected"
}

# Step 4: IIS Reset
if (-not $SkipIISReset) {
    Write-Step "Performing IIS reset..."
    try {
        & iisreset /restart | Out-Null
        Write-Success "IIS reset completed successfully"
    }
    catch {
        Write-Warning "IIS reset failed: $_"
    }
}
else {
    Write-Warning "Skipping IIS reset (use 'iisreset' command manually if needed)"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Prerequisites Installation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ancmPath) -and -not (Test-Path $ancmInprocPath)) {
    Write-Host "NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Install the .NET Hosting Bundle for your target framework" -ForegroundColor Yellow
    Write-Host "2. Run 'iisreset' after installing the Hosting Bundle" -ForegroundColor Yellow
    Write-Host "3. Run Provision-Site.ps1 to create the IIS site" -ForegroundColor Yellow
}
else {
    Write-Host "NEXT STEPS:" -ForegroundColor Green
    Write-Host "1. Run Provision-Site.ps1 to create the IIS site and app pool" -ForegroundColor Green
    Write-Host "2. Deploy your application files to the site path" -ForegroundColor Green
    Write-Host "3. Test the deployment with: Invoke-WebRequest http://localhost/healthz" -ForegroundColor Green
}

Write-Host ""
exit 0
