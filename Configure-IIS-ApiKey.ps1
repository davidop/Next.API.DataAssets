# Configure-IIS-ApiKey.ps1
# Script para configurar la API Key en IIS rápidamente
# Uso: .\Configure-IIS-ApiKey.ps1 -AppPoolName "DataAssetsAppPool" -SitePath "C:\inetpub\dataassets"

param(
    [Parameter(Mandatory=$true)]
    [string]$AppPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$SitePath,
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKeyRaw = "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKeyHash = "f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyId = "production-client-1",
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = "Production Client 1"
)

# Verificar que se ejecuta como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERROR: Este script requiere privilegios de Administrador" -ForegroundColor Red
    Write-Host "   Inicia PowerShell como Administrador e intenta de nuevo." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     CONFIGURACIÓN DE API KEY EN IIS                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Verificar que el módulo WebAdministration está disponible
if (-not (Get-Module -ListAvailable -Name WebAdministration)) {
    Write-Host "`n❌ ERROR: Módulo WebAdministration no disponible" -ForegroundColor Red
    Write-Host "   IIS no está instalado o no está configurado correctamente." -ForegroundColor Yellow
    exit 1
}

Import-Module WebAdministration -ErrorAction Stop

# Verificar que el Application Pool existe
Write-Host "`n🔍 Verificando Application Pool: $AppPoolName" -ForegroundColor Cyan
if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
    Write-Host "   ❌ ERROR: El Application Pool '$AppPoolName' no existe" -ForegroundColor Red
    Write-Host "   Application Pools disponibles:" -ForegroundColor Yellow
    Get-ChildItem IIS:\AppPools | Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
    exit 1
}
Write-Host "   ✓ Application Pool encontrado" -ForegroundColor Green

# Verificar que el sitio existe
Write-Host "`n🔍 Verificando Site Path: $SitePath" -ForegroundColor Cyan
if (-not (Test-Path $SitePath)) {
    Write-Host "   ❌ ERROR: La ruta '$SitePath' no existe" -ForegroundColor Red
    exit 1
}
Write-Host "   ✓ Site path encontrado" -ForegroundColor Green

# Buscar web.config
$webConfigPath = Join-Path $SitePath "web.config"
Write-Host "`n🔍 Verificando web.config: $webConfigPath" -ForegroundColor Cyan
if (-not (Test-Path $webConfigPath)) {
    Write-Host "   ❌ ERROR: web.config no encontrado" -ForegroundColor Red
    Write-Host "   Crea el archivo web.config primero." -ForegroundColor Yellow
    exit 1
}
Write-Host "   ✓ web.config encontrado" -ForegroundColor Green

# Hacer backup del web.config
$backupPath = "$webConfigPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "`n💾 Creando backup: $backupPath" -ForegroundColor Cyan
Copy-Item $webConfigPath $backupPath -Force
Write-Host "   ✓ Backup creado" -ForegroundColor Green

# Leer web.config
Write-Host "`n📝 Actualizando web.config..." -ForegroundColor Cyan
[xml]$webConfig = Get-Content $webConfigPath

# Buscar o crear el nodo aspNetCore
$aspNetCore = $webConfig.configuration.'system.webServer'.aspNetCore
if (-not $aspNetCore) {
    Write-Host "   ❌ ERROR: No se encontró el nodo aspNetCore en web.config" -ForegroundColor Red
    exit 1
}

# Buscar o crear environmentVariables
$envVars = $aspNetCore.environmentVariables
if (-not $envVars) {
    $envVars = $webConfig.CreateElement("environmentVariables")
    $aspNetCore.AppendChild($envVars) | Out-Null
}

# Función para añadir o actualizar una variable de entorno
function Set-EnvironmentVariable {
    param(
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$EnvVarsNode,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Value
    )
    
    # Buscar si ya existe
    $existing = $EnvVarsNode.environmentVariable | Where-Object { $_.name -eq $Name }
    
    if ($existing) {
        # Actualizar existente
        $existing.value = $Value
        Write-Host "      ↻ $Name" -ForegroundColor Yellow
    } else {
        # Crear nuevo
        $newVar = $webConfig.CreateElement("environmentVariable")
        $newVar.SetAttribute("name", $Name)
        $newVar.SetAttribute("value", $Value)
        $EnvVarsNode.AppendChild($newVar) | Out-Null
        Write-Host "      + $Name" -ForegroundColor Green
    }
}

# Configurar API Key
Write-Host "   Configurando API Key variables..." -ForegroundColor White

Set-EnvironmentVariable -EnvVarsNode $envVars -Name "Auth__ApiKeysOptions__HeaderName" -Value "X-API-Key"
Set-EnvironmentVariable -EnvVarsNode $envVars -Name "Auth__ApiKeysOptions__Keys__0__KeyId" -Value $KeyId
Set-EnvironmentVariable -EnvVarsNode $envVars -Name "Auth__ApiKeysOptions__Keys__0__Owner" -Value $Owner
Set-EnvironmentVariable -EnvVarsNode $envVars -Name "Auth__ApiKeysOptions__Keys__0__KeyHash" -Value $ApiKeyHash
Set-EnvironmentVariable -EnvVarsNode $envVars -Name "Auth__ApiKeysOptions__Keys__0__Enabled" -Value "true"

# Configurar ASPNETCORE_ENVIRONMENT si no existe
$envVarEnv = $envVars.environmentVariable | Where-Object { $_.name -eq "ASPNETCORE_ENVIRONMENT" }
if (-not $envVarEnv) {
    Set-EnvironmentVariable -EnvVarsNode $envVars -Name "ASPNETCORE_ENVIRONMENT" -Value "Production"
}

# Guardar web.config
Write-Host "`n💾 Guardando web.config..." -ForegroundColor Cyan
$webConfig.Save($webConfigPath)
Write-Host "   ✓ web.config actualizado" -ForegroundColor Green

# Reiniciar Application Pool
Write-Host "`n🔄 Reiniciando Application Pool: $AppPoolName" -ForegroundColor Cyan
try {
    Restart-WebAppPool -Name $AppPoolName -ErrorAction Stop
    Write-Host "   ✓ Application Pool reiniciado" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  No se pudo reiniciar el App Pool automáticamente" -ForegroundColor Yellow
    Write-Host "   Reinícialo manualmente: Restart-WebAppPool -Name '$AppPoolName'" -ForegroundColor Gray
}

# Resumen
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              ✓ CONFIGURACIÓN COMPLETADA                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 Resumen de configuración:" -ForegroundColor Cyan
Write-Host "   Application Pool: $AppPoolName" -ForegroundColor White
Write-Host "   Site Path: $SitePath" -ForegroundColor White
Write-Host "   Key ID: $KeyId" -ForegroundColor White
Write-Host "   Owner: $Owner" -ForegroundColor White
Write-Host "   Header: X-API-Key" -ForegroundColor White

Write-Host "`n🔑 API Key para compartir con el cliente:" -ForegroundColor Yellow
Write-Host "   $ApiKeyRaw" -ForegroundColor Cyan

Write-Host "`n🧪 Testear la configuración:" -ForegroundColor Yellow
Write-Host "   # Desde el servidor local" -ForegroundColor Gray
Write-Host '   $headers = @{ "X-API-Key" = "' -NoNewline -ForegroundColor Gray
Write-Host $ApiKeyRaw -NoNewline -ForegroundColor Cyan
Write-Host '" }' -ForegroundColor Gray
Write-Host '   Invoke-WebRequest -Uri "http://localhost/resources/DataAsset" -Headers $headers -UseBasicParsing' -ForegroundColor Gray

Write-Host "`n   # Desde Postman o cliente externo" -ForegroundColor Gray
Write-Host "   URL: http://tu-servidor/resources/DataAsset?download=true" -ForegroundColor Gray
Write-Host "   Header: X-API-Key: $ApiKeyRaw" -ForegroundColor Gray

Write-Host "`n💾 Backup del web.config anterior guardado en:" -ForegroundColor Yellow
Write-Host "   $backupPath" -ForegroundColor Gray

Write-Host "`n✅ Todo listo! La API debe estar disponible ahora.`n" -ForegroundColor Green
