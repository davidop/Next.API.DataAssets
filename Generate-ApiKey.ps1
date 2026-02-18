# Generador de API Keys con SHA-256 Hash
# Uso: .\Generate-ApiKey.ps1 [-Length 32] [-KeyId "client-1"] [-Owner "Client Name"]

param(
    [Parameter(Mandatory=$false)]
    [int]$Length = 32,
    
    [Parameter(Mandatory=$false)]
    [string]$KeyId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = ""
)

function Generate-SecureApiKey {
    param([int]$Length)
    
    # Genera caracteres aleatorios seguros (A-Z, a-z, 0-9)
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $apiKey = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    
    return $apiKey
}

function Get-Sha256Hash {
    param([string]$Text)
    
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $hashString = -join ($hash | ForEach-Object { $_.ToString("x2") })
    
    return $hashString
}

# Generar API Key
$apiKey = Generate-SecureApiKey -Length $Length
$hash = Get-Sha256Hash -Text $apiKey

# Output
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          API KEY GENERADA EXITOSAMENTE                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 API Key (Envía esto al cliente):" -ForegroundColor Cyan
Write-Host "   $apiKey" -ForegroundColor White

Write-Host "`n🔐 SHA-256 Hash (Configura esto en Azure/appsettings):" -ForegroundColor Cyan
Write-Host "   $hash" -ForegroundColor White

if ($KeyId -or $Owner) {
    Write-Host "`n📝 Configuración JSON para appsettings.Production.json:" -ForegroundColor Yellow
    
    $keyIdValue = if ($KeyId) { $KeyId } else { "client-$(Get-Random -Minimum 1000 -Maximum 9999)" }
    $ownerValue = if ($Owner) { $Owner } else { "Client Name" }
    
    $json = @"
{
  "KeyId": "$keyIdValue",
  "Owner": "$ownerValue",
  "KeyHash": "$hash",
  "Enabled": true
}
"@
    
    Write-Host $json -ForegroundColor Gray
}

Write-Host "`n⚙️  Variables de Entorno para Azure App Service:" -ForegroundColor Yellow
Write-Host "   (Reemplaza {INDEX} con 0, 1, 2... según el orden)" -ForegroundColor DarkGray

if ($KeyId) {
    Write-Host "`n   Auth__ApiKeysOptions__Keys__{INDEX}__KeyId" -ForegroundColor White
    Write-Host "   $KeyId" -ForegroundColor Gray
}
if ($Owner) {
    Write-Host "`n   Auth__ApiKeysOptions__Keys__{INDEX}__Owner" -ForegroundColor White
    Write-Host "   $Owner" -ForegroundColor Gray
}
Write-Host "`n   Auth__ApiKeysOptions__Keys__{INDEX}__KeyHash" -ForegroundColor White
Write-Host "   $hash" -ForegroundColor Gray
Write-Host "`n   Auth__ApiKeysOptions__Keys__{INDEX}__Enabled" -ForegroundColor White
Write-Host "   true" -ForegroundColor Gray

Write-Host "`n💾 Guardar en Clipboard?" -ForegroundColor Yellow
$save = Read-Host "   Copiar API Key al portapapeles? (Y/N)"
if ($save -eq "Y" -or $save -eq "y") {
    $apiKey | Set-Clipboard
    Write-Host "   ✓ API Key copiada al portapapeles!" -ForegroundColor Green
}

Write-Host "`n⚠️  IMPORTANTE: Guarda esta información de forma segura!" -ForegroundColor Red
Write-Host "   La API Key solo se muestra una vez.`n" -ForegroundColor Red
