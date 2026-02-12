#Requires -Version 5.1
<#
.SYNOPSIS
    Smoke test for Next.API.DataAssets deployment on Windows Server 2019

.DESCRIPTION
    This script performs basic health checks on a deployed Next.API.DataAssets instance:
    - Tests /health endpoint (anonymous)
    - Tests /healthz endpoint (anonymous or authenticated based on config)
    - Optionally tests authenticated /resources endpoint
    - Provides detailed diagnostics on failure

.PARAMETER Url
    Base URL of the deployed application (default: http://localhost)

.PARAMETER ApiKey
    Optional API key to test authenticated endpoints

.PARAMETER SkipAuthTest
    Skip testing authenticated endpoints

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\Smoke-Test.ps1
    Basic health check on http://localhost

.EXAMPLE
    .\Smoke-Test.ps1 -Url "http://dataassets.company.com"
    Health check on specific URL

.EXAMPLE
    .\Smoke-Test.ps1 -ApiKey "your-api-key-here"
    Full test including authenticated endpoints

.EXAMPLE
    .\Smoke-Test.ps1 -Url "http://localhost:8080" -ApiKey "test-key"
    Full test on custom port with authentication

.NOTES
    Does not require Administrator privileges
    Requires PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [string]$Url = "http://localhost",
    [string]$ApiKey = "",
    [switch]$SkipAuthTest
)

$ErrorActionPreference = 'Continue'

# Color output functions
function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "       $Message" -ForegroundColor Gray
}

# Normalize URL (remove trailing slash)
$Url = $Url.TrimEnd('/')

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Next.API.DataAssets - Smoke Test (Windows Server 2019)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target URL: $Url" -ForegroundColor White
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testsWarning = 0

# Test 1: Basic /health endpoint
Write-TestHeader "Test 1: Basic Health Check (/health)"
try {
    $response = Invoke-WebRequest -Uri "$Url/health" -Method GET -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Write-TestSuccess "Endpoint returned HTTP 200"
        $testsPassed++
        
        # Parse JSON response
        try {
            $healthData = $response.Content | ConvertFrom-Json
            if ($healthData.status -eq "ok") {
                Write-TestSuccess "Health status is 'ok'"
                Write-TestInfo "Response: $($response.Content)"
            }
            else {
                Write-TestWarning "Unexpected status: $($healthData.status)"
                $testsWarning++
            }
        }
        catch {
            Write-TestWarning "Could not parse JSON response"
            $testsWarning++
        }
    }
    else {
        Write-TestFailure "Expected HTTP 200, got HTTP $($response.StatusCode)"
        $testsFailed++
    }
}
catch {
    Write-TestFailure "Failed to reach /health endpoint"
    Write-TestInfo "Error: $($_.Exception.Message)"
    $testsFailed++
    
    # Provide diagnostics
    Write-Host ""
    Write-Host "Troubleshooting suggestions:" -ForegroundColor Yellow
    Write-Host "  1. Check if IIS site is running:" -ForegroundColor White
    Write-Host "     Get-Website | Where-Object { `$_.State -eq 'Started' }" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Check if application pool is running:" -ForegroundColor White
    Write-Host "     Get-WebAppPoolState -Name 'DataAssets'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Check IIS logs:" -ForegroundColor White
    Write-Host "     C:\inetpub\logs\LogFiles\W3SVC*\*.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Check application logs:" -ForegroundColor White
    Write-Host "     C:\inetpub\dataassets\logs\*.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. Check Event Viewer (Application logs):" -ForegroundColor White
    Write-Host "     Get-EventLog -LogName Application -Newest 20 | Where-Object { `$_.Source -like '*IIS*' -or `$_.Source -like '*ASP.NET*' }" -ForegroundColor Gray
    Write-Host ""
}

# Test 2: Enhanced /healthz endpoint
Write-TestHeader "Test 2: Detailed Health Check (/healthz)"
try {
    $response = Invoke-WebRequest -Uri "$Url/healthz" -Method GET -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        Write-TestSuccess "Endpoint returned HTTP 200"
        $testsPassed++
        
        # Parse JSON response
        try {
            $healthzData = $response.Content | ConvertFrom-Json
            
            if ($healthzData.status) {
                Write-TestSuccess "Status: $($healthzData.status)"
            }
            
            if ($healthzData.version) {
                Write-TestInfo "Version: $($healthzData.version)"
            }
            
            if ($healthzData.framework) {
                Write-TestInfo "Framework: $($healthzData.framework)"
            }
            
            if ($healthzData.environment) {
                Write-TestInfo "Environment: $($healthzData.environment)"
                
                if ($healthzData.environment -ne "Production") {
                    Write-TestWarning "Environment is not 'Production' - is this expected?"
                    $testsWarning++
                }
            }
            
            if ($healthzData.timestamp) {
                Write-TestInfo "Server Time: $($healthzData.timestamp)"
            }
        }
        catch {
            Write-TestWarning "Could not parse JSON response"
            Write-TestInfo "Response: $($response.Content)"
            $testsWarning++
        }
    }
    else {
        Write-TestFailure "Expected HTTP 200, got HTTP $($response.StatusCode)"
        $testsFailed++
    }
}
catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 401) {
        Write-TestWarning "Endpoint requires authentication (HTTP 401)"
        Write-TestInfo "This is OK if Health:AllowAnonymous is set to false"
        $testsWarning++
    }
    else {
        Write-TestFailure "Failed to reach /healthz endpoint"
        Write-TestInfo "Error: $($_.Exception.Message)"
        $testsFailed++
    }
}

# Test 3: Authenticated endpoint (if API key provided)
if (-not $SkipAuthTest -and $ApiKey) {
    Write-TestHeader "Test 3: Authenticated Endpoint (/resources/*)"
    
    # Try to call a resources endpoint (will likely fail if file doesn't exist, but tests auth)
    try {
        $headers = @{
            "X-API-Key" = $ApiKey
        }
        
        # Test with a sample file name (expect 404 if file doesn't exist, but should not be 401)
        $response = Invoke-WebRequest -Uri "$Url/resources/test.csv" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            Write-TestSuccess "Authentication successful - file found"
            Write-TestInfo "File served successfully"
            $testsPassed++
        }
        else {
            Write-TestWarning "Unexpected status code: $($response.StatusCode)"
            $testsWarning++
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
            Write-TestSuccess "Authentication successful (file not found is expected)"
            Write-TestInfo "HTTP 404 indicates auth worked but file doesn't exist"
            $testsPassed++
        }
        elseif ($_.Exception.Response.StatusCode.Value__ -eq 401) {
            Write-TestFailure "Authentication failed (HTTP 401)"
            Write-TestInfo "API Key may be incorrect or not configured in appsettings.json"
            $testsFailed++
        }
        elseif ($_.Exception.Response.StatusCode.Value__ -eq 429) {
            Write-TestWarning "Rate limit exceeded (HTTP 429)"
            Write-TestInfo "Too many requests - this may be expected"
            $testsWarning++
        }
        else {
            Write-TestFailure "Unexpected error"
            Write-TestInfo "Error: $($_.Exception.Message)"
            $testsFailed++
        }
    }
}
elseif (-not $SkipAuthTest -and -not $ApiKey) {
    Write-TestHeader "Test 3: Authenticated Endpoint (SKIPPED)"
    Write-TestInfo "Provide -ApiKey parameter to test authenticated endpoints"
}
else {
    Write-TestHeader "Test 3: Authenticated Endpoint (SKIPPED)"
    Write-TestInfo "Skipped via -SkipAuthTest parameter"
}

# Test 4: Check for common IIS/ASP.NET Core errors
Write-TestHeader "Test 4: Error Page Detection"
try {
    # Try to request root (/) and check for error pages
    $response = Invoke-WebRequest -Uri "$Url/" -Method GET -UseBasicParsing -ErrorAction Stop
    
    # Check for common error markers in response
    $content = $response.Content
    
    if ($content -match "500\.30|500\.31|500\.32|500\.33|502\.5|503") {
        Write-TestFailure "Detected ASP.NET Core error page"
        Write-TestInfo "Response contains error code: $($Matches[0])"
        $testsFailed++
        
        Write-Host ""
        Write-Host "Common ASP.NET Core error codes:" -ForegroundColor Yellow
        Write-Host "  500.30: Failed to start" -ForegroundColor White
        Write-Host "  500.31: Failed to load assembly" -ForegroundColor White
        Write-Host "  502.5:  Process failure" -ForegroundColor White
        Write-Host "  503:    App offline or pool stopped" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-TestSuccess "No obvious error pages detected"
        $testsPassed++
    }
}
catch {
    # It's OK if / returns 404 or redirects
    if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
        Write-TestSuccess "Root endpoint not found (expected for API-only app)"
        $testsPassed++
    }
    else {
        Write-TestInfo "Could not check root endpoint (may be expected)"
    }
}

# Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Passed:  $testsPassed" -ForegroundColor Green
Write-Host "Failed:  $testsFailed" -ForegroundColor Red
Write-Host "Warning: $testsWarning" -ForegroundColor Yellow
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "Overall Result: SUCCESS ✓" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Next.API.DataAssets deployment appears to be working correctly!" -ForegroundColor Green
    
    if ($testsWarning -gt 0) {
        Write-Host ""
        Write-Host "Note: There are $testsWarning warning(s). Review them above." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Add your data assets to the assets folder" -ForegroundColor White
    Write-Host "  2. Configure authentication (JWT or API Keys)" -ForegroundColor White
    Write-Host "  3. Test with actual API calls" -ForegroundColor White
    Write-Host "  4. Set up monitoring and logging" -ForegroundColor White
    Write-Host ""
    
    exit 0
}
else {
    Write-Host "Overall Result: FAILURE ✗" -ForegroundColor Red
    Write-Host ""
    Write-Host "Deployment has issues that need to be resolved." -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting resources:" -ForegroundColor Yellow
    Write-Host "  - Deployment guide: /docs/deploy/IIS-WindowsServer2019.md" -ForegroundColor White
    Write-Host "  - Compatibility info: /docs/compatibility/WINDOWS_SERVER_2019.md" -ForegroundColor White
    Write-Host "  - ASP.NET Core on IIS: https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/" -ForegroundColor White
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  1. Check stdout logs: C:\inetpub\dataassets\logs\stdout_*.log" -ForegroundColor White
    Write-Host "  2. Enable stdout logging in web.config (stdoutLogEnabled=`"true`")" -ForegroundColor White
    Write-Host "  3. Check Event Viewer > Windows Logs > Application" -ForegroundColor White
    Write-Host "  4. Verify .NET Hosting Bundle is installed: dotnet --list-runtimes" -ForegroundColor White
    Write-Host "  5. Restart IIS: iisreset" -ForegroundColor White
    Write-Host ""
    
    exit 1
}
