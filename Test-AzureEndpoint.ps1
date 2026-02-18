# Script para testear el endpoint de Azure con API Key
# Uso: .\Test-AzureEndpoint.ps1 -ApiKey "tu-api-key"

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$Url = "https://next-api-dataassets-net8.azurewebsites.net/resources/DataAsset",
    
    [Parameter(Mandatory=$false)]
    [switch]$Download
)

if ($Download) {
    $Url = "$Url`?download=true"
}

Write-Host "`n=== TESTING AZURE ENDPOINT ===" -ForegroundColor Green
Write-Host "URL: $Url" -ForegroundColor Cyan
Write-Host "API Key: $($ApiKey.Substring(0, 4))****$($ApiKey.Substring($ApiKey.Length - 4))" -ForegroundColor Cyan
Write-Host ""

try {
    $headers = @{
        "X-API-Key" = $ApiKey
        "Accept" = "*/*"
    }
    
    $response = Invoke-WebRequest -Uri $Url -Headers $headers -Method GET -UseBasicParsing
    
    Write-Host "✓ SUCCESS!" -ForegroundColor Green
    Write-Host "`nStatus Code: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
    Write-Host "Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor White
    Write-Host "Content-Length: $($response.Headers['Content-Length']) bytes" -ForegroundColor White
    Write-Host "Correlation-Id: $($response.Headers['x-correlation-id'])" -ForegroundColor White
    Write-Host "Rate Limit Remaining: $($response.Headers['x-rate-limit-remaining'])" -ForegroundColor White
    
    if ($response.Content.Length -lt 500) {
        Write-Host "`nContent Preview:" -ForegroundColor Yellow
        Write-Host $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
    } else {
        Write-Host "`nContent Size: $($response.Content.Length) bytes (too large to display)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ ERROR!" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "`nPossible reasons:" -ForegroundColor Yellow
        Write-Host "1. API Key is incorrect" -ForegroundColor White
        Write-Host "2. API Key hash is not configured in Azure" -ForegroundColor White
        Write-Host "3. API Key is disabled (Enabled: false)" -ForegroundColor White
    }
    
    Write-Host "`nFull Error:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Gray
}

Write-Host "`n========================`n" -ForegroundColor Green
