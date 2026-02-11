#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Provisions IIS site and application pool for Next.API.DataAssets

.DESCRIPTION
    This script creates or updates:
    - Application Pool (No Managed Code, 64-bit)
    - IIS Site or Application
    - NTFS permissions for the app pool identity
    - Creates necessary folders (logs, assets)

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
    Creates a new site on port 80

.EXAMPLE
    .\Provision-Site.ps1 -Port 8080 -HostName "dataassets.company.com"
    Creates a new site with specific port and host name

.EXAMPLE
    .\Provision-Site.ps1 -UseDefaultWebSite -AppPath "/api/dataassets"
    Creates an application under Default Web Site

.NOTES
    Requires Administrator privileges and IIS installed
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
Import-Module WebAdministration -ErrorAction Stop

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
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - Site Provisioning" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create or update Application Pool
Write-Step "Creating/updating Application Pool '$AppPoolName'..."
$appPool = Get-ChildItem IIS:\AppPools | Where-Object { $_.Name -eq $AppPoolName }

if ($null -eq $appPool) {
    Write-Host "  Creating new app pool..."
    New-WebAppPool -Name $AppPoolName | Out-Null
    Write-Success "Application pool created"
}
else {
    Write-Success "Application pool already exists (will update settings)"
}

# Configure App Pool
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "enable32BitAppOnWin64" -Value $false
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name "startMode" -Value "AlwaysRunning"

Write-Success "Application pool configured (No Managed Code, 64-bit, ApplicationPoolIdentity)"

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
    Write-Success "Created logs directory"
}

if (-not (Test-Path $assetsPath)) {
    New-Item -Path $assetsPath -ItemType Directory -Force | Out-Null
    Write-Success "Created assets directory"
}

# Step 3: Set NTFS permissions
Write-Step "Configuring NTFS permissions..."
$appPoolIdentity = "IIS AppPool\$AppPoolName"

try {
    # Grant permissions to the app pool identity
    $acl = Get-Acl $SitePath
    $permission = $appPoolIdentity, "ReadAndExecute, Write", "ContainerInherit, ObjectInherit", "None", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $SitePath $acl
    
    Write-Success "NTFS permissions configured for '$appPoolIdentity'"
}
catch {
    Write-StepWarning "Failed to set NTFS permissions: $_"
    Write-Host "  You may need to set permissions manually for: $appPoolIdentity" -ForegroundColor Yellow
}

# Step 4: Create site or application
if ($UseDefaultWebSite) {
    Write-Step "Creating application under 'Default Web Site'..."
    
    # Check if Default Web Site exists
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($null -eq $defaultSite) {
        Write-StepError "Default Web Site not found. Use without -UseDefaultWebSite to create a standalone site."
        exit 1
    }
    
    # Check if application already exists
    $app = Get-WebApplication -Site "Default Web Site" -Name $AppPath.TrimStart('/') -ErrorAction SilentlyContinue
    
    if ($null -eq $app) {
        New-WebApplication -Site "Default Web Site" -Name $AppPath.TrimStart('/') -PhysicalPath $SitePath -ApplicationPool $AppPoolName | Out-Null
        Write-Success "Application created at: http://localhost$AppPath"
    }
    else {
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site\$($AppPath.TrimStart('/'))" -Name "physicalPath" -Value $SitePath
        Set-ItemProperty -Path "IIS:\Sites\Default Web Site\$($AppPath.TrimStart('/'))" -Name "applicationPool" -Value $AppPoolName
        Write-Success "Application updated at: http://localhost$AppPath"
    }
}
else {
    Write-Step "Creating/updating IIS site '$SiteName'..."
    
    # Check if site already exists
    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    
    if ($null -eq $site) {
        # Create new site
        if ($HostName) {
            New-Website -Name $SiteName -PhysicalPath $SitePath -ApplicationPool $AppPoolName -Port $Port -HostHeader $HostName | Out-Null
            Write-Success "Site created: http://${HostName}:${Port}/"
        }
        else {
            New-Website -Name $SiteName -PhysicalPath $SitePath -ApplicationPool $AppPoolName -Port $Port | Out-Null
            Write-Success "Site created: http://localhost:${Port}/"
        }
    }
    else {
        # Update existing site
        Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name "physicalPath" -Value $SitePath
        Set-ItemProperty -Path "IIS:\Sites\$SiteName" -Name "applicationPool" -Value $AppPoolName
        
        # Update binding if needed
        $binding = Get-WebBinding -Name $SiteName
        if ($binding) {
            if ($HostName) {
                Set-WebBinding -Name $SiteName -BindingInformation "*:${Port}:${HostName}" -PropertyName "BindingInformation" -Value "*:${Port}:${HostName}"
            }
            else {
                Set-WebBinding -Name $SiteName -BindingInformation "*:${Port}:" -PropertyName "BindingInformation" -Value "*:${Port}:"
            }
        }
        
        Write-Success "Site updated: $SiteName"
    }
}

# Step 5: Start the site/app pool
Write-Step "Starting application pool and site..."
Start-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
if (-not $UseDefaultWebSite) {
    Start-Website -Name $SiteName -ErrorAction SilentlyContinue
}

Write-Success "Application pool and site started"

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Site Provisioning Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  App Pool:    $AppPoolName" -ForegroundColor Gray
Write-Host "  Site Path:   $SitePath" -ForegroundColor Gray

if ($UseDefaultWebSite) {
    Write-Host "  URL:         http://localhost$AppPath" -ForegroundColor Gray
    Write-Host "  Health URL:  http://localhost$AppPath/healthz" -ForegroundColor Gray
}
else {
    if ($HostName) {
        Write-Host "  URL:         http://${HostName}:${Port}/" -ForegroundColor Gray
        Write-Host "  Health URL:  http://${HostName}:${Port}/healthz" -ForegroundColor Gray
    }
    else {
        Write-Host "  URL:         http://localhost:${Port}/" -ForegroundColor Gray
        Write-Host "  Health URL:  http://localhost:${Port}/healthz" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Green
Write-Host "1. Copy your published application files to: $SitePath" -ForegroundColor Green
Write-Host "2. Copy your data assets to: $assetsPath" -ForegroundColor Green
Write-Host "3. Configure appsettings.json or environment variables" -ForegroundColor Green
Write-Host "4. Test the deployment:" -ForegroundColor Green
if ($UseDefaultWebSite) {
    Write-Host "   Invoke-WebRequest http://localhost$AppPath/healthz" -ForegroundColor Green
}
else {
    if ($HostName) {
        Write-Host "   Invoke-WebRequest http://${HostName}:${Port}/healthz" -ForegroundColor Green
    }
    else {
        Write-Host "   Invoke-WebRequest http://localhost:${Port}/healthz" -ForegroundColor Green
    }
}

Write-Host ""
exit 0
