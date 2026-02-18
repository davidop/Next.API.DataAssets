# Configuración de API Keys en IIS Windows Server

## 📋 Resumen

En IIS Windows Server tienes **3 opciones** para configurar la API Key (y cualquier configuración):

1. **Opción 1**: Archivo `appsettings.Production.json` (Recomendado para desarrollo/test)
2. **Opción 2**: Variables de entorno en `web.config` (Recomendado para producción)
3. **Opción 3**: Variables de entorno del sistema Windows (Alternativa)

---

## 🔑 Tu API Key Generada

**API Key** (Compartir con clientes):
```
AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH
```

**SHA-256 Hash** (Configurar en servidor):
```
f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab
```

---

## ⚙️ Opción 1: Archivo appsettings.Production.json (Más Simple)

### Paso 1: Editar appsettings.Production.json

Edita el archivo en tu servidor IIS en la ruta de la aplicación:
```
C:\inetpub\dataassets\appsettings.Production.json
```

Contenido completo con API Key configurada:

```json
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
          "KeyHash": "f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab",
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
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

### Paso 2: Reiniciar el Application Pool

```powershell
# PowerShell como Administrador
Import-Module WebAdministration
Restart-WebAppPool -Name "DataAssetsAppPool"

# O reinicia IIS completo
iisreset
```

### ✅ Ventajas:
- Simple y directo
- Fácil de editar con notepad
- No requiere reiniciar IIS (solo el App Pool)

### ❌ Desventajas:
- Secretos en texto plano en disco
- Menos seguro si múltiples personas tienen acceso al servidor
- Se puede sobrescribir al republicar

---

## 🔒 Opción 2: Variables de Entorno en web.config (Recomendado para Producción)

### Paso 1: Editar web.config

Edita el archivo en tu servidor IIS:
```
C:\inetpub\dataassets\web.config
```

Reemplaza la sección `<environmentVariables>` con esto:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified"/>
    </handlers>
    
    <aspNetCore processPath="dotnet" 
                arguments="Next.API.DataAssets.dll" 
                stdoutLogEnabled="false" 
                stdoutLogFile=".\logs\stdout" 
                hostingModel="outofprocess">
      
      <environmentVariables>
        <!-- Environment -->
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
        
        <!-- Assets Configuration -->
        <environmentVariable name="Assets__RootPath" value="assets" />
        <environmentVariable name="Assets__DefaultCacheSeconds" value="600" />
        
        <!-- Health Check -->
        <environmentVariable name="Health__AllowAnonymous" value="false" />
        
        <!-- JWT Configuration -->
        <environmentVariable name="Auth__Jwt__Issuer" value="your-company-name" />
        <environmentVariable name="Auth__Jwt__Audience" value="dataassets-api" />
        <environmentVariable name="Auth__Jwt__SigningKey" value="CHANGE-THIS-TO-A-SECURE-KEY-MINIMUM-32-CHARACTERS-LONG" />
        <environmentVariable name="Auth__Jwt__ValidateIssuer" value="true" />
        <environmentVariable name="Auth__Jwt__ValidateAudience" value="true" />
        <environmentVariable name="Auth__Jwt__ClockSkewSeconds" value="30" />
        
        <!-- API Key Configuration -->
        <environmentVariable name="Auth__ApiKeysOptions__HeaderName" value="X-API-Key" />
        
        <!-- API Key #1 -->
        <environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyId" value="production-client-1" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__0__Owner" value="Production Client 1" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyHash" value="f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__0__Enabled" value="true" />
        
        <!-- API Key #2 (Ejemplo múltiples clientes) -->
        <!--
        <environmentVariable name="Auth__ApiKeysOptions__Keys__1__KeyId" value="production-client-2" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__1__Owner" value="Production Client 2" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__1__KeyHash" value="otro-hash-aqui" />
        <environmentVariable name="Auth__ApiKeysOptions__Keys__1__Enabled" value="true" />
        -->
        
        <!-- Rate Limiting -->
        <environmentVariable name="RateLimiting__IpRateLimitOptions__EnableEndpointRateLimiting" value="true" />
        <environmentVariable name="RateLimiting__IpRateLimitOptions__HttpStatusCode" value="429" />
        <environmentVariable name="RateLimiting__IpRateLimitOptions__GeneralRules__0__Endpoint" value="*:/resources/*" />
        <environmentVariable name="RateLimiting__IpRateLimitOptions__GeneralRules__0__Period" value="1m" />
        <environmentVariable name="RateLimiting__IpRateLimitOptions__GeneralRules__0__Limit" value="60" />
      </environmentVariables>
      
    </aspNetCore>
  </system.webServer>
</configuration>
```

### Paso 2: Simplificar appsettings.Production.json (Opcional)

Ya no necesitas la configuración completa. Puedes dejar un archivo mínimo:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

### Paso 3: Reiniciar Application Pool

```powershell
Import-Module WebAdministration
Restart-WebAppPool -Name "DataAssetsAppPool"
```

### ✅ Ventajas:
- Más seguro (web.config puede tener permisos restrictivos)
- Las variables sobrescriben appsettings.json
- No se pierde al republicar (si el web.config está fuera del deploy)
- Cada site de IIS puede tener configuración diferente

### ❌ Desventajas:
- Más verboso
- Requiere editar XML

---

## 🖥️ Opción 3: Variables de Entorno del Sistema Windows

### Paso 1: Configurar Variables de Entorno

```powershell
# PowerShell como Administrador

# Configurar variables de entorno a nivel de MÁQUINA
[System.Environment]::SetEnvironmentVariable("Auth__ApiKeysOptions__Keys__0__KeyId", "production-client-1", "Machine")
[System.Environment]::SetEnvironmentVariable("Auth__ApiKeysOptions__Keys__0__Owner", "Production Client 1", "Machine")
[System.Environment]::SetEnvironmentVariable("Auth__ApiKeysOptions__Keys__0__KeyHash", "f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab", "Machine")
[System.Environment]::SetEnvironmentVariable("Auth__ApiKeysOptions__Keys__0__Enabled", "true", "Machine")

# Verificar
[System.Environment]::GetEnvironmentVariable("Auth__ApiKeysOptions__Keys__0__KeyHash", "Machine")
```

### Paso 2: Reiniciar IIS Completamente

```powershell
# Reinicia IIS para que tome las variables
iisreset
```

### ✅ Ventajas:
- Centralizado a nivel de servidor
- Muy seguro (solo administradores pueden ver/editar)
- Aplica a todos los sites/apps en el servidor

### ❌ Desventajas:
- Si tienes múltiples aplicaciones, todas compartirán la misma config
- Requiere privilegios de administrador
- Más difícil de documentar/auditar

---

## 🔐 Opción 4: Híbrida (Recomendado para Producción)

Combina las opciones anteriores:

1. **web.config**: Configuración específica del site (API Keys, paths, etc.)
2. **appsettings.Production.json**: Configuración base y defaults
3. **Variables de sistema**: Secretos Ultra-Sensibles (JWT signing keys)

### Ejemplo web.config (Solo API Keys):

```xml
<environmentVariables>
  <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
  
  <!-- API Keys en web.config -->
  <environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyId" value="production-client-1" />
  <environmentVariable name="Auth__ApiKeysOptions__Keys__0__Owner" value="Production Client 1" />
  <environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyHash" value="f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab" />
  <environmentVariable name="Auth__ApiKeysOptions__Keys__0__Enabled" value="true" />
</environmentVariables>
```

### Ejemplo appsettings.Production.json (Base):

```json
{
  "Assets": {
    "RootPath": "assets",
    "DefaultCacheSeconds": 600
  },
  "Health": {
    "AllowAnonymous": false
  },
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
}
```

### JWT Signing Key como variable de sistema:

```powershell
[System.Environment]::SetEnvironmentVariable("Auth__Jwt__SigningKey", "tu-super-secreto-key-256-bits", "Machine")
```

---

## 🧪 Testear la Configuración

### 1. Verificar que IIS está usando las variables

Habilita logging en web.config:

```xml
<aspNetCore ... stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout">
```

Reinicia el App Pool y revisa:
```
C:\inetpub\dataassets\logs\stdout_*.log
```

Busca en el log la configuración cargada.

### 2. Test desde el servidor local

```powershell
# Desde el servidor IIS
$headers = @{ "X-API-Key" = "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH" }
Invoke-WebRequest -Uri "http://localhost/resources/DataAsset" -Headers $headers -UseBasicParsing
```

### 3. Test remoto desde Postman

- **URL**: `http://tu-servidor-iis/resources/DataAsset?download=true`
- **Header**: `X-API-Key: AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH`

---

## 🔄 Agregar Múltiples API Keys

### En web.config:

```xml
<!-- Cliente 1 -->
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyId" value="client-1" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__Owner" value="Cliente 1" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyHash" value="hash1" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__Enabled" value="true" />

<!-- Cliente 2 -->
<environmentVariable name="Auth__ApiKeysOptions__Keys__1__KeyId" value="client-2" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__1__Owner" value="Cliente 2" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__1__KeyHash" value="hash2" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__1__Enabled" value="true" />

<!-- Cliente 3 -->
<environmentVariable name="Auth__ApiKeysOptions__Keys__2__KeyId" value="client-3" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__2__Owner" value="Cliente 3" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__2__KeyHash" value="hash3" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__2__Enabled" value="true" />
```

Los índices deben ser secuenciales: `__0__`, `__1__`, `__2__`, etc.

---

## 🛠️ Scripts de Ayuda

### Generar nueva API Key:

```powershell
.\Generate-ApiKey.ps1 -KeyId "cliente-abc" -Owner "Cliente ABC Corp"
```

### Verificar configuración actual:

```powershell
# Ver variables de entorno del App Pool
Import-Module WebAdministration
$appPool = Get-Item "IIS:\AppPools\DataAssetsAppPool"
$appPool.environmentVariables
```

---

## 📝 Checklist de Despliegue

- [ ] Decidir qué opción de configuración usar
- [ ] Configurar API Key(s) en el método elegido
- [ ] Configurar JWT signing key (si se usa JWT)
- [ ] Actualizar RootPath si los assets están en otra ubicación
- [ ] Configurar rate limiting según necesidad
- [ ] Reiniciar Application Pool o IIS
- [ ] Testear endpoint localmente en el servidor
- [ ] Testear endpoint remotamente desde Postman
- [ ] Documentar las API Keys generadas (guardar en password manager)
- [ ] Enviar API Keys a los clientes de forma segura
- [ ] Configurar backup del web.config

---

## 🔍 Troubleshooting

### Error 401 Unauthorized
```powershell
# Verificar que el hash está configurado correctamente
# En el servidor IIS, calcula el hash de tu API key:
$apiKey = "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($apiKey)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })

# Debe retornar: f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab
```

### Variables no se aplican
```powershell
# 1. Verifica sintaxis del web.config
# 2. Reinicia el App Pool específico
Restart-WebAppPool -Name "DataAssetsAppPool"

# 3. Si no funciona, reinicia IIS completo
iisreset

# 4. Verifica Event Viewer > Application logs
Get-WinEvent -LogName Application -MaxEvents 50 | Where-Object {$_.Source -like "*IIS*"}
```

### Configuración se pierde al republicar
- Guarda una copia del `web.config` fuera de la carpeta de publicación
- O excluye `web.config` de tu proceso de despliegue
- O usa variables de entorno del sistema (Opción 3)

---

## 🎯 Recomendación Final

**Para Producción** → Usa **Opción 2** (Variables en web.config)
- Fácil de mantener
- Seguro
- No se pierde al republicar si el web.config está fuera del deploy
- Cada site puede tener su propia configuración

**Para Desarrollo/Test** → Usa **Opción 1** (appsettings.Production.json)
- Más simple
- Más rápido de cambiar
