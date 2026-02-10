# Guía de Despliegue

Esta guía detalla cómo desplegar la API Next.API.DataAssets en diferentes entornos.

## Tabla de Contenidos

- [Requisitos del Sistema](#requisitos-del-sistema)
- [Despliegue en IIS (Windows)](#despliegue-en-iis-windows)
- [Despliegue en Linux con Nginx](#despliegue-en-linux-con-nginx)
- [Configuración de Seguridad](#configuración-de-seguridad)
- [Monitorización y Logs](#monitorización-y-logs)

## Requisitos del Sistema

### Windows Server

| Componente | Requisito |
|------------|-----------|
| **Sistema Operativo** | Windows Server 2016+ (R2 o superior) |
| **.NET Runtime** | .NET 10.0 Runtime + ASP.NET Core Hosting Bundle |
| **IIS** | 10.0 o superior |
| **Memoria RAM** | Mínimo 2 GB disponible |
| **Disco** | 500 MB para la aplicación + espacio para assets |

**Nota**: Windows Server 2012/R2 NO es compatible con .NET 10. Ver README para opciones.

### Linux

| Componente | Requisito |
|------------|-----------|
| **Sistema Operativo** | Ubuntu 22.04+, Debian 11+, RHEL 8+, o similar |
| **.NET Runtime** | .NET 10.0 Runtime |
| **Reverse Proxy** | Nginx o Apache |
| **Systemd** | Para gestión del servicio |

## Despliegue en IIS (Windows)

### Paso 1: Instalar Prerequisitos

1. **Instalar ASP.NET Core Hosting Bundle**:
   ```powershell
   # Descargar desde: https://dotnet.microsoft.com/download/dotnet/10.0
   # Buscar "ASP.NET Core Runtime 10.x.x - Windows Hosting Bundle Installer"
   
   # Después de instalar, reiniciar IIS:
   net stop was /y
   net start w3svc
   ```

2. **Verificar instalación**:
   ```powershell
   dotnet --list-runtimes
   # Debe mostrar: Microsoft.AspNetCore.App 10.x.x
   ```

### Paso 2: Publicar la Aplicación

```powershell
# En tu máquina de desarrollo o build server:
cd path\to\Next.API.DataAssets
dotnet publish src\Next.API.DataAssets\Next.API.DataAssets.csproj `
  -c Release `
  -r win-x64 `
  --self-contained false `
  -o C:\publish\dataassets
```

### Paso 3: Copiar Archivos al Servidor

```powershell
# Copiar archivos publicados al servidor
Copy-Item -Path C:\publish\dataassets\* -Destination \\servidor\C$\inetpub\dataassets -Recurse

# Crear carpeta para assets si no existe
New-Item -Path C:\inetpub\dataassets\assets -ItemType Directory -Force

# Copiar tu archivo CSV
Copy-Item -Path C:\datos\DataAsset.csv -Destination C:\inetpub\dataassets\assets\
```

### Paso 4: Configurar IIS

#### Crear Application Pool

```powershell
Import-Module WebAdministration

# Crear Application Pool
New-WebAppPool -Name "DataAssetsPool"
Set-ItemProperty IIS:\AppPools\DataAssetsPool -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty IIS:\AppPools\DataAssetsPool -Name "enable32BitAppOnWin64" -Value $false
Set-ItemProperty IIS:\AppPools\DataAssetsPool -Name "processModel.identityType" -Value "ApplicationPoolIdentity"

# Configurar reciclaje
Set-ItemProperty IIS:\AppPools\DataAssetsPool -Name "recycling.periodicRestart.time" -Value "1.05:00:00"
```

#### Crear Sitio Web

```powershell
# Opción 1: Crear nuevo sitio
New-Website -Name "DataAssetsAPI" `
  -Port 80 `
  -PhysicalPath "C:\inetpub\dataassets" `
  -ApplicationPool "DataAssetsPool"

# Opción 2: Crear como aplicación bajo sitio existente
New-WebApplication -Name "dataassets" `
  -Site "Default Web Site" `
  -PhysicalPath "C:\inetpub\dataassets" `
  -ApplicationPool "DataAssetsPool"
```

### Paso 5: Configurar web.config

Asegúrate de que existe `web.config` en `C:\inetpub\dataassets\`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified"/>
    </handlers>
    <aspNetCore processPath="dotnet" 
                arguments="Next.API.DataAssets.dll" 
                stdoutLogEnabled="true" 
                stdoutLogFile=".\logs\stdout" 
                hostingModel="inprocess">
      <environmentVariables>
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
      </environmentVariables>
    </aspNetCore>
  </system.webServer>
</configuration>
```

### Paso 6: Configurar Permisos

```powershell
# Dar permisos al Application Pool Identity
$acl = Get-Acl "C:\inetpub\dataassets"
$permission = "IIS APPPOOL\DataAssetsPool","Read,ExecuteFile","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($accessRule)
Set-Acl "C:\inetpub\dataassets" $acl

# Crear carpeta de logs
New-Item -Path C:\inetpub\dataassets\logs -ItemType Directory -Force
```

### Paso 7: Configuración de Producción

Editar `C:\inetpub\dataassets\appsettings.json`:

```json
{
  "Assets": {
    "RootPath": "assets",
    "DefaultCacheSeconds": 600
  },
  "Auth": {
    "Jwt": {
      "Issuer": "tu-empresa",
      "Audience": "dataassets-api",
      "SigningKey": "CLAVE-SEGURA-DE-PRODUCCION-MINIMO-32-CARACTERES",
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ClockSkewSeconds": 30
    },
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "cliente-produccion-1",
          "Owner": "Cliente Principal",
          "KeyHash": "hash-sha256-de-la-api-key-real",
          "Enabled": true
        }
      ]
    }
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

### Paso 8: Verificar

```powershell
# Probar endpoint de health
Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing
# Debe devolver: {"status":"ok"}

# Probar con API Key
$headers = @{"X-API-Key" = "tu-api-key"}
Invoke-WebRequest -Uri "http://localhost/resources/DataAsset.csv" -Headers $headers
```

## Despliegue en Linux con Nginx

### Paso 1: Instalar .NET Runtime

```bash
# Ubuntu 22.04
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y aspnetcore-runtime-10.0

# Verificar
dotnet --list-runtimes
```

### Paso 2: Publicar y Copiar

```bash
# Publicar (en tu máquina de desarrollo)
dotnet publish src/Next.API.DataAssets/Next.API.DataAssets.csproj \
  -c Release \
  -r linux-x64 \
  --self-contained false \
  -o ./publish

# Copiar al servidor
scp -r ./publish/* usuario@servidor:/var/www/dataassets/

# En el servidor
sudo mkdir -p /var/www/dataassets/assets
sudo cp /ruta/a/DataAsset.csv /var/www/dataassets/assets/
sudo chown -R www-data:www-data /var/www/dataassets
sudo chmod -R 755 /var/www/dataassets
```

### Paso 3: Crear Servicio Systemd

Crear `/etc/systemd/system/dataassets.service`:

```ini
[Unit]
Description=Next API DataAssets
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/dataassets
ExecStart=/usr/bin/dotnet /var/www/dataassets/Next.API.DataAssets.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dataassets
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
```

Habilitar e iniciar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable dataassets
sudo systemctl start dataassets
sudo systemctl status dataassets
```

### Paso 4: Configurar Nginx

Crear `/etc/nginx/sites-available/dataassets`:

```nginx
server {
    listen 80;
    server_name api.tudominio.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Habilitar:

```bash
sudo ln -s /etc/nginx/sites-available/dataassets /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Paso 5: Configurar HTTPS con Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.tudominio.com
```

## Configuración de Seguridad

### 1. Generar API Keys Seguras

```bash
# Linux/macOS
API_KEY=$(openssl rand -hex 32)
echo "API Key: $API_KEY"
API_HASH=$(echo -n "$API_KEY" | openssl dgst -sha256 | awk '{print $2}')
echo "Hash para appsettings.json: $API_HASH"
```

```powershell
# PowerShell
$apiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
Write-Host "API Key: $apiKey"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($apiKey)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
$hashString = -join ($hash | ForEach-Object { $_.ToString("x2") })
Write-Host "Hash: $hashString"
```

### 2. Configurar JWT Signing Key

```bash
# Generar una clave segura de 256 bits (32 bytes)
openssl rand -base64 32
```

Usar esta clave en `appsettings.json` → `Auth:Jwt:SigningKey`

### 3. Firewall

**Windows**:
```powershell
# Permitir solo puerto 443 (HTTPS)
New-NetFirewallRule -DisplayName "DataAssets HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

**Linux**:
```bash
sudo ufw allow 443/tcp
sudo ufw enable
```

### 4. Rate Limiting

En producción, considera ajustar los límites en `appsettings.json`:

```json
"RateLimiting": {
  "IpRateLimitOptions": {
    "EnableEndpointRateLimiting": true,
    "GeneralRules": [
      {
        "Endpoint": "*:/resources/*",
        "Period": "1m",
        "Limit": 60
      }
    ]
  }
}
```

## Monitorización y Logs

### Windows IIS

Logs de aplicación:
```
C:\inetpub\dataassets\logs\stdout-*.log
```

Ver logs en tiempo real:
```powershell
Get-Content C:\inetpub\dataassets\logs\stdout-*.log -Wait -Tail 50
```

### Linux Systemd

```bash
# Ver logs
sudo journalctl -u dataassets -f

# Ver últimas 100 líneas
sudo journalctl -u dataassets -n 100

# Logs por fecha
sudo journalctl -u dataassets --since "2024-01-01" --until "2024-01-02"
```

### Verificación de Salud

Crear un script de monitorización:

```bash
#!/bin/bash
# health-check.sh

ENDPOINT="https://api.tudominio.com/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $ENDPOINT)

if [ $RESPONSE -eq 200 ]; then
    echo "OK: API is healthy"
    exit 0
else
    echo "ERROR: API returned $RESPONSE"
    exit 1
fi
```

Configurar en cron:
```bash
*/5 * * * * /usr/local/bin/health-check.sh
```

## Actualización de la Aplicación

### Windows

```powershell
# 1. Detener el sitio
Stop-Website -Name "DataAssetsAPI"

# 2. Hacer backup
Copy-Item -Path C:\inetpub\dataassets -Destination C:\backups\dataassets-$(Get-Date -Format 'yyyyMMdd-HHmmss') -Recurse

# 3. Publicar nueva versión
dotnet publish -c Release -o C:\publish\dataassets

# 4. Copiar nuevos archivos (excepto appsettings.json y assets)
Copy-Item -Path C:\publish\dataassets\* -Destination C:\inetpub\dataassets\ -Exclude appsettings.json,assets -Force

# 5. Reiniciar
Start-Website -Name "DataAssetsAPI"
```

### Linux

```bash
# 1. Detener servicio
sudo systemctl stop dataassets

# 2. Backup
sudo tar -czf /backups/dataassets-$(date +%Y%m%d-%H%M%S).tar.gz /var/www/dataassets

# 3. Actualizar archivos
sudo cp -r ./publish/* /var/www/dataassets/
# Preservar appsettings.json original

# 4. Reiniciar
sudo systemctl start dataassets
sudo systemctl status dataassets
```

## Troubleshooting

### Problema: API devuelve 502 Bad Gateway (Linux)

**Solución**:
```bash
# Verificar que la aplicación está corriendo
sudo systemctl status dataassets

# Ver logs
sudo journalctl -u dataassets -n 50

# Verificar que escucha en el puerto correcto
sudo netstat -tlnp | grep dotnet
```

### Problema: 500 Internal Server Error

**Solución**:
1. Habilitar logs detallados en `web.config`: `stdoutLogEnabled="true"`
2. Verificar permisos de la carpeta `assets`
3. Verificar que existe el archivo CSV

### Problema: 401 Unauthorized

**Solución**:
1. Verificar que el API Key hash es correcto
2. Verificar que el header `X-API-Key` se está enviando
3. Para JWT, verificar `SigningKey` y `ValidateIssuer/ValidateAudience`

## Soporte

Para más ayuda, consulta el [README.md](README.md) principal o contacta al equipo de desarrollo.
