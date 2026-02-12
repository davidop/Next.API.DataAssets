#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Provisions IIS site and application pool for Next.API.DataAssets on Windows Server 2019

.DESCRIPTION
    This script creates or updates:
    - Application Pool (No Managed Code, 64-bit, optimized for Windows Server 2019)
    - IIS Site or Application
    - NTFS permissions for the app pool identity
    - Creates necessary folders (logs, assets)
    
    Specifically optimized for Windows Server 2019 with enhanced security settings.

.PARAMETER SiteName
    Name of the IIS site (default: "DataAssets")

.PARAMETER AppPoolName
    Name of the application pool (default: "DataAssets")

.PARAMETER SitePath
    Physical path for the application (default: "C:\inetpub\dataassets")

.PARAMETER Port
    HTTP port for the site (default: 80)

.PARAMETER HostName
    Optional host name binding (leave empty for all hosts)

.PARAMETER UseDefaultWebSite
    Create as an application under "Default Web Site" instead of a new site

.PARAMETER AppPath
    Virtual path for the application when using -UseDefaultWebSite (default: "/dataassets")

.EXAMPLE
    .\Provision-Site.ps1
    Creates a new site on port 80 with default settings

.EXAMPLE
    .\Provision-Site.ps1 -Port 8080 -HostName "dataassets.company.com"
    Creates a new site with specific port and host name

.EXAMPLE
    .\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
    Creates an application under Default Web Site

.EXAMPLE
    .\Provision-Site.ps1 -SitePath "D:\WebApps\DataAssets"
    Creates site at custom physical location

.NOTES
    Requires Administrator privileges and IIS installed
    Optimized for Windows Server 2019
#>

[CmdletBinding()]
param(
    [string]$SiteName = "DataAssets",
    [string]$AppPoolName = "DataAssets",
    [string]$SitePath = "C:\inetpub\dataassets",
    [int]$Port = 80,
    [string]$HostName = "",
    [switch]$UseDefaultWebSite,
    [string]$AppPath = "/dataassets"
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

# Import IIS module
try {
    Import-Module WebAdministration -ErrorAction Stop
}
catch {
    Write-StepError "Failed to load WebAdministration module. Ensure IIS is installed."
    Write-Host ""
    Write-Host "  Run Install-Prereqs.ps1 first to install IIS features." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - Site Provisioning (Windows Server 2019)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Gray
if ($UseDefaultWebSite) {
    Write-Host "  Mode: Application under Default Web Site" -ForegroundColor White
    Write-Host "  App Path: $AppPath" -ForegroundColor White
}
else {
    Write-Host "  Mode: Standalone Site" -ForegroundColor White
    Write-Host "  Site Name: $SiteName" -ForegroundColor White
    Write-Host "  Port: $Port" -ForegroundColor White
    if ($HostName) {
        Write-Host "  Host Name: $HostName" -ForegroundColor White
    }
}
Write-Host "  App Pool: $AppPoolName" -ForegroundColor White
Write-Host "  Physical Path: $SitePath" -ForegroundColor White
Write-Host ""

# Step 1: Create or update Application Pool
Write-Step "Creating/updating Application Pool '$AppPoolName'..."
$appPool = Get-ChildItem IIS:\AppPools | Where-Object { $_.Name -eq $AppPoolName }

if ($null -eq $appPool) {
    Write-Host "  Creating new app pool..." -ForegroundColor Gray
    New-WebAppPool -Name $AppPoolName | Out-Null
    Write-Success "Application pool created"
}
else {
    Write-Success "Application pool already exists (will update settings)"
}

# Configure App Pool for ASP.NET Core on Windows Server 2019
Write-Host "  Configuring app pool settings..." -ForegroundColor Gray
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedRuntimeVersion" -Value ""  # No Managed Code
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "enable32BitAppOnWin64" -Value $false  # 64-bit only
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "startMode" -Value "AlwaysRunning"  # For better startup performance
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.idleTimeout" -Value "00:20:00"  # 20 minutes idle timeout

# Windows Server 2019 specific optimizations
try {
    # Enable rapid fail protection
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "failure.rapidFailProtection" -Value $true
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "failure.rapidFailProtectionInterval" -Value "00:05:00"
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "failure.rapidFailProtectionMaxCrashes" -Value 5
    
    # Configure recycling
    Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "recycling.periodicRestart.time" -Value "1.05:00:00"  # Every 29 hours (avoid peak times)
}
catch {
    Write-StepWarning "Could not set some advanced app pool settings: $_"
}

Write-Success "Application pool configured"
Write-Host "    Runtime: No Managed Code (ASP.NET Core)" -ForegroundColor Gray
Write-Host "    Platform: 64-bit" -ForegroundColor Gray
Write-Host "    Identity: ApplicationPoolIdentity" -ForegroundColor Gray
Write-Host "    Start Mode: AlwaysRunning" -ForegroundColor Gray

Write-Host ""

# Step 2: Create physical directory structure
Write-Step "Creating directory structure..."
if (-not (Test-Path $SitePath)) {
    New-Item -Path $SitePath -ItemType Directory -Force | Out-Null
    Write-Success "Created directory: $SitePath"
}
else {
    Write-Success "Directory already exists: $SitePath"
}

# Create subdirectories
$logsPath = Join-Path $SitePath "logs"
$assetsPath = Join-Path $SitePath "assets"

if (-not (Test-Path $logsPath)) {
    New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
    Write-Success "Created logs directory: $logsPath"
}
else {
    Write-Host "  Logs directory exists: $logsPath" -ForegroundColor DarkGray
}

if (-not (Test-Path $assetsPath)) {
    New-Item -Path $assetsPath -ItemType Directory -Force | Out-Null
    Write-Success "Created assets directory: $assetsPath"
}
else {
    Write-Host "  Assets directory exists: $assetsPath" -ForegroundColor DarkGray
}

Write-Host ""

# Step 3: Set NTFS permissions
Write-Step "Configuring NTFS permissions..."
$appPoolIdentity = "IIS AppPool\$AppPoolName"

try {
    # Site root: Read & Execute
    Write-Host "  Granting Read & Execute to: $SitePath" -ForegroundColor Gray
    $icaclsArgs = @(
        "`"$SitePath`"",
        "/grant",
        "`"${appPoolIdentity}:(OI)(CI)RX`""
    )
    & icacls $icaclsArgs[0] $icaclsArgs[1] $icaclsArgs[2] | Out-Null
    
    # Logs folder: Modify (Read, Write, Delete)
    Write-Host "  Granting Modify to: $logsPath" -ForegroundColor Gray
    $icaclsArgs = @(
        "`"$logsPath`"",
        "/grant",
        "`"${appPoolIdentity}:(OI)(CI)M`""
    )
    & icacls $icaclsArgs[0] $icaclsArgs[1] $icaclsArgs[2] | Out-Null
    
    Write-Success "NTFS permissions configured"
    Write-Host "    App Root: Read & Execute for $appPoolIdentity" -ForegroundColor Gray
    Write-Host "    Logs:     Modify for $appPoolIdentity" -ForegroundColor Gray
}
catch {
    Write-StepWarning "Could not set NTFS permissions automatically: $_"
    Write-Host ""
    Write-Host "  Please run manually:" -ForegroundColor Yellow
    Write-Host "    icacls `"$SitePath`" /grant `"${appPoolIdentity}:(OI)(CI)RX`"" -ForegroundColor White
    Write-Host "    icacls `"$logsPath`" /grant `"${appPoolIdentity}:(OI)(CI)M`"" -ForegroundColor White
    Write-Host ""
}

Write-Host ""

# Step 4: Create IIS Site or Application
if ($UseDefaultWebSite) {
    Write-Step "Creating application under 'Default Web Site'..."
    
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($null -eq $defaultSite) {
        Write-StepError "'Default Web Site' not found. Use without -UseDefaultWebSite to create a new site."
        exit 1
    }
    
    # Check if application already exists
    $existingApp = Get-WebApplication -Site "Default Web Site" -Name $AppPath.TrimStart('/') -ErrorAction SilentlyContinue
    if ($existingApp) {
        Write-Host "  Updating existing application..." -ForegroundColor Gray
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site\$($AppPath.TrimStart('/'))" -Name "applicationPool" -Value $AppPoolName
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site\$($AppPath.TrimStart('/'))" -Name "physicalPath" -Value $SitePath
        Write-Success "Application updated"
    }
    else {
        Write-Host "  Creating new application..." -ForegroundColor Gray
        New-WebApplication -Site "Default Web Site" -Name $AppPath.TrimStart('/') -PhysicalPath $SitePath -ApplicationPool $AppPoolName | Out-Null
        Write-Success "Application created"
    }
    
    Write-Host ""
    Write-Host "  Application URL: http://localhost$AppPath" -ForegroundColor Green
    Write-Host "  Test with: Invoke-WebRequest http://localhost${AppPath}/healthz" -ForegroundColor Cyan
}
else {
    Write-Step "Creating/updating IIS site '$SiteName'..."
    
    $existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    if ($existingSite) {
        Write-Host "  Updating existing site..." -ForegroundColor Gray
        Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name "applicationPool" -Value $AppPoolName
        Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name "physicalPath" -Value $SitePath
        
        # Update binding if needed
        $binding = Get-WebBinding -Name $SiteName -Protocol "http"
        if ($binding) {
            # Check if binding matches
            $currentPort = $binding.bindingInformation.Split(':')[1]
            $currentHostName = $binding.bindingInformation.Split(':')[2]
            
            if ($currentPort -ne $Port -or $currentHostName -ne $HostName) {
                Write-Host "  Updating binding..." -ForegroundColor Gray
                Remove-WebBinding -Name $SiteName -Protocol "http" -Confirm:$false
                
                if ($HostName) {
                    New-WebBinding -Name $SiteName -Protocol "http" -Port $Port -HostHeader $HostName | Out-Null
                }
                else {
                    New-WebBinding -Name $SiteName -Protocol "http" -Port $Port | Out-Null
                }
            }
        }
        
        Write-Success "Site updated"
    }
    else {
        Write-Host "  Creating new site..." -ForegroundColor Gray
        if ($HostName) {
            New-Website -Name $SiteName -Port $Port -HostHeader $HostName -PhysicalPath $SitePath -ApplicationPool $AppPoolName | Out-Null
        }
        else {
            New-Website -Name $SiteName -Port $Port -PhysicalPath $SitePath -ApplicationPool $AppPoolName | Out-Null
        }
        Write-Success "Site created"
    }
    
    Write-Host ""
    if ($HostName) {
        Write-Host "  Site URL: http://${HostName}:${Port}" -ForegroundColor Green
        Write-Host "  Test with: Invoke-WebRequest http://${HostName}:${Port}/healthz" -ForegroundColor Cyan
    }
    else {
        Write-Host "  Site URL: http://localhost:${Port}" -ForegroundColor Green
        Write-Host "  Test with: Invoke-WebRequest http://localhost:${Port}/healthz" -ForegroundColor Cyan
    }
}

Write-Host ""

# Step 5: Start the App Pool and Site
Write-Step "Starting application pool and site..."
try {
    # Start app pool if not running
    $appPoolState = (Get-WebAppPoolState -Name $AppPoolName).Value
    if ($appPoolState -ne "Started") {
        Start-WebAppPool -Name $AppPoolName
        Write-Success "Application pool started"
    }
    else {
        Write-Host "  Application pool already running" -ForegroundColor DarkGray
    }
    
    # Start site if not running (only for standalone sites)
    if (-not $UseDefaultWebSite) {
        $siteState = (Get-WebsiteState -Name $SiteName).Value
        if ($siteState -ne "Started") {
            Start-Website -Name $SiteName
            Write-Success "Site started"
        }
        else {
            Write-Host "  Site already running" -ForegroundColor DarkGray
        }
    }
}
catch {
    Write-StepWarning "Could not start app pool/site: $_"
    Write-Host "  You may need to start them manually after deploying the application" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Site Provisioning Complete!" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Deploy application files to: $SitePath" -ForegroundColor White
Write-Host "       - Run dotnet publish or use Publish-And-Zip.ps1" -ForegroundColor Gray
Write-Host "  2. Ensure web.config exists in: $SitePath" -ForegroundColor White
Write-Host "       - Copy from /deploy/web.config if needed" -ForegroundColor Gray
Write-Host "  3. Configure appsettings.Production.json" -ForegroundColor White
Write-Host "       - Set Auth:Jwt:SigningKey" -ForegroundColor Gray
Write-Host "       - Configure Auth:ApiKeysOptions" -ForegroundColor Gray
Write-Host "  4. Add your data assets to: $assetsPath" -ForegroundColor White
Write-Host "  5. Test deployment with: .\Smoke-Test.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Gray
Write-Host "  /docs/deploy/IIS-WindowsServer2019.md" -ForegroundColor White
Write-Host "  /docs/compatibility/WINDOWS_SERVER_2019.md" -ForegroundColor White
Write-Host ""

exit 0
