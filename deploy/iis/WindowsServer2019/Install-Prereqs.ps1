#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs and configures IIS prerequisites for Next.API.DataAssets on Windows Server 2019

.DESCRIPTION
    This script:
    - Verifies Windows Server 2019 (Build 17763 or later)
    - Enables IIS and required features
    - Checks if ASP.NET Core Module (ANCM) is installed
    - Validates .NET runtime installations
    - Performs an IIS reset
    
    Note: This script does NOT install the .NET Hosting Bundle. You must download and install it manually:
    - For .NET 8 (Recommended): https://dotnet.microsoft.com/download/dotnet/8.0
    - For .NET 10: https://dotnet.microsoft.com/download/dotnet/10.0

.PARAMETER SkipIISReset
    Skip the IIS reset at the end

.EXAMPLE
    .\Install-Prereqs.ps1
    
.EXAMPLE
    .\Install-Prereqs.ps1 -SkipIISReset

.NOTES
    Requires Administrator privileges
    Specifically designed for Windows Server 2019
    For other Windows versions, see /deploy/iis/Install-Prereqs.ps1
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

function Write-StepWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-StepError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-StepError "This script must be run as Administrator"
    Write-Host ""
    Write-Host "  Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - Windows Server 2019 Prerequisites" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Verify Windows Server 2019
Write-Step "Verifying Windows Server 2019..."
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = [System.Environment]::OSVersion.Version
$buildNumber = $osInfo.BuildNumber

Write-Host "  OS: $($osInfo.Caption)" -ForegroundColor Gray
Write-Host "  Version: $($osVersion)" -ForegroundColor Gray
Write-Host "  Build: $buildNumber" -ForegroundColor Gray

# Windows Server 2019 is build 17763
if ([int]$buildNumber -lt 17763) {
    Write-StepWarning "This script is designed for Windows Server 2019 (Build 17763+)"
    Write-Host "  Your build: $buildNumber" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne 'y') {
        Write-Host "Aborted by user." -ForegroundColor Yellow
        exit 0
    }
}
elseif ([int]$buildNumber -eq 17763) {
    Write-Success "Windows Server 2019 detected (Build 17763)"
}
else {
    Write-Success "Windows Server 2019 or later detected (Build $buildNumber)"
}

# Check for Windows Updates
Write-Step "Checking for pending Windows Updates..."
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    
    if ($searchResult.Updates.Count -gt 0) {
        Write-StepWarning "$($searchResult.Updates.Count) Windows Update(s) pending"
        Write-Host "  It is recommended to install all Windows Updates before deploying .NET applications." -ForegroundColor Yellow
    }
    else {
        Write-Success "No pending Windows Updates"
    }
}
catch {
    Write-StepWarning "Could not check for Windows Updates: $_"
}

Write-Host ""

# Step 1: Enable IIS features
Write-Step "Enabling IIS and required features..."
try {
    # Core IIS features required for ASP.NET Core hosting
    $features = @(
        'Web-Server',              # IIS Web Server
        'Web-WebServer',           # IIS Web Server
        'Web-Common-Http',         # Common HTTP Features
        'Web-Default-Doc',         # Default Document
        'Web-Dir-Browsing',        # Directory Browsing
        'Web-Http-Errors',         # HTTP Errors
        'Web-Static-Content',      # Static Content
        'Web-Health',              # Health and Diagnostics
        'Web-Http-Logging',        # HTTP Logging
        'Web-Performance',         # Performance Features
        'Web-Stat-Compression',    # Static Content Compression
        'Web-Dyn-Compression',     # Dynamic Content Compression
        'Web-Security',            # Security
        'Web-Filtering',           # Request Filtering
        'Web-App-Dev',             # Application Development
        'Web-ISAPI-Ext',           # ISAPI Extensions (required for ANCM)
        'Web-ISAPI-Filter',        # ISAPI Filters (required for ANCM)
        'Web-Mgmt-Tools',          # Management Tools
        'Web-Mgmt-Console'         # IIS Management Console
    )

    foreach ($feature in $features) {
        $installed = (Get-WindowsFeature -Name $feature).InstallState -eq 'Installed'
        if (-not $installed) {
            Write-Host "  Installing $feature..." -ForegroundColor Gray
            Install-WindowsFeature -Name $feature -ErrorAction Stop | Out-Null
        }
        else {
            Write-Host "  $feature already installed" -ForegroundColor DarkGray
        }
    }
    
    Write-Success "IIS features enabled successfully"
}
catch {
    Write-StepError "Failed to enable IIS features: $_"
    exit 1
}

Write-Host ""

# Step 2: Check for ASP.NET Core Module (ANCM)
Write-Step "Checking for ASP.NET Core Module (ANCM)..."
$ancmPath = "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
$ancmInprocPath = "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2_inprocess.dll"

if ((Test-Path $ancmPath) -or (Test-Path $ancmInprocPath)) {
    Write-Success "ASP.NET Core Module V2 is installed"
    
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
    
    # Check which modules are available
    if (Test-Path $ancmPath) {
        Write-Host "  OutOfProcess module: Found" -ForegroundColor Green
    }
    if (Test-Path $ancmInprocPath) {
        Write-Host "  InProcess module: Found" -ForegroundColor Green
    }
}
else {
    Write-StepWarning "ASP.NET Core Module (ANCM) is NOT installed"
    Write-Host ""
    Write-Host "  You must install the .NET Hosting Bundle to get ANCM:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  For .NET 8 (Recommended LTS):" -ForegroundColor Cyan
    Write-Host "    https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
    Write-Host "    Look for: 'Hosting Bundle' under ASP.NET Core Runtime" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  For .NET 10 (Standard Term Support):" -ForegroundColor Cyan
    Write-Host "    https://dotnet.microsoft.com/download/dotnet/10.0" -ForegroundColor White
    Write-Host "    Look for: 'Hosting Bundle' under ASP.NET Core Runtime" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  After installing the Hosting Bundle:" -ForegroundColor Yellow
    Write-Host "    1. Run: iisreset" -ForegroundColor White
    Write-Host "    2. Run this script again to verify" -ForegroundColor White
    Write-Host ""
}

Write-Host ""

# Step 3: Check .NET Runtime installations
Write-Step "Checking installed .NET runtimes..."

$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnetCmd) {
    Write-Host ""
    Write-Host "  Running: dotnet --list-runtimes" -ForegroundColor Gray
    Write-Host ""
    
    try {
        $runtimes = & dotnet --list-runtimes
        $runtimes | ForEach-Object {
            Write-Host "    $_" -ForegroundColor White
        }
        
        Write-Host ""
        
        # Check for ASP.NET Core runtime
        $aspnetCore = $runtimes | Where-Object { $_ -match 'Microsoft.AspNetCore.App' }
        if ($aspnetCore) {
            Write-Success "ASP.NET Core runtime found"
            
            # Check for recommended versions
            $hasNet8 = $aspnetCore | Where-Object { $_ -match 'Microsoft.AspNetCore.App 8\.' }
            $hasNet10 = $aspnetCore | Where-Object { $_ -match 'Microsoft.AspNetCore.App 10\.' }
            
            if ($hasNet8) {
                Write-Host "  .NET 8 (LTS): Available" -ForegroundColor Green
            }
            if ($hasNet10) {
                Write-Host "  .NET 10: Available" -ForegroundColor Green
            }
            
            if (-not $hasNet8 -and -not $hasNet10) {
                Write-StepWarning "Neither .NET 8 nor .NET 10 ASP.NET Core runtime found"
                Write-Host "  This application requires .NET 8 or .NET 10" -ForegroundColor Yellow
            }
        }
        else {
            Write-StepWarning "ASP.NET Core runtime not found"
            Write-Host "  Install the Hosting Bundle for .NET 8 or .NET 10" -ForegroundColor Yellow
        }
    }
    catch {
        Write-StepWarning "Could not execute 'dotnet --list-runtimes': $_"
    }
}
else {
    Write-StepWarning ".NET CLI (dotnet) not found in PATH"
    Write-Host ""
    Write-Host "  The .NET CLI is typically installed with the .NET Hosting Bundle." -ForegroundColor Yellow
    Write-Host "  If you have already installed it, you may need to:" -ForegroundColor Yellow
    Write-Host "    1. Close and reopen this PowerShell window" -ForegroundColor White
    Write-Host "    2. Or add the .NET install directory to your PATH" -ForegroundColor White
    Write-Host ""
}

Write-Host ""

# Step 4: Verify IIS is running
Write-Step "Verifying IIS service status..."
try {
    $w3svc = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
    if ($w3svc) {
        if ($w3svc.Status -eq 'Running') {
            Write-Success "IIS (W3SVC) is running"
        }
        else {
            Write-StepWarning "IIS (W3SVC) is not running. Starting..."
            Start-Service -Name W3SVC
            Write-Success "IIS started"
        }
    }
    else {
        Write-StepWarning "W3SVC service not found. IIS may not be installed correctly."
    }
}
catch {
    Write-StepWarning "Could not check IIS service: $_"
}

Write-Host ""

# Step 5: IIS Reset
if (-not $SkipIISReset) {
    Write-Step "Performing IIS reset..."
    try {
        & iisreset | Out-Null
        Write-Success "IIS reset completed"
    }
    catch {
        Write-StepWarning "IIS reset failed: $_"
    }
}
else {
    Write-StepWarning "IIS reset skipped (use without -SkipIISReset to reset IIS)"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Prerequisites Installation Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Summary and next steps
$ancmInstalled = (Test-Path $ancmPath) -or (Test-Path $ancmInprocPath)
$dotnetFound = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)

if ($ancmInstalled -and $dotnetFound) {
    Write-Success "System is ready for Next.API.DataAssets deployment!"
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Cyan
    Write-Host "    1. Run .\Provision-Site.ps1 to create IIS site and app pool" -ForegroundColor White
    Write-Host "    2. Deploy your application files" -ForegroundColor White
    Write-Host "    3. Configure appsettings.Production.json" -ForegroundColor White
    Write-Host "    4. Run .\Smoke-Test.ps1 to verify deployment" -ForegroundColor White
    Write-Host ""
}
else {
    Write-StepWarning "Additional steps required before deployment:"
    Write-Host ""
    if (-not $ancmInstalled) {
        Write-Host "  [ ] Install .NET Hosting Bundle (.NET 8 or .NET 10)" -ForegroundColor Yellow
        Write-Host "      https://dotnet.microsoft.com/download/dotnet" -ForegroundColor Gray
    }
    if (-not $dotnetFound) {
        Write-Host "  [ ] Ensure .NET CLI is in PATH (restart PowerShell)" -ForegroundColor Yellow
    }
    Write-Host "  [ ] Run this script again to verify" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "For detailed deployment instructions, see:" -ForegroundColor Gray
Write-Host "  /docs/deploy/IIS-WindowsServer2019.md" -ForegroundColor White
Write-Host ""

exit 0
