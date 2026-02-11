# Next.API.DataAssets

API de entrega de ficheros (data assets) protegida por **JWT** o **API Key** (OR), lista para hospedar en **Windows IIS**.

## ⚠️ Compatibilidad con Windows Server

**IMPORTANTE**: Este proyecto utiliza **.NET 10** que requiere **Windows Server 2016 o superior**.

### Requisitos del sistema

| .NET Version | Windows Server Mínimo | Notas |
|--------------|----------------------|-------|
| .NET 10.0 | Windows Server 2016+ | Versión actual del proyecto |



## Funcionalidad

### Endpoint principal

**GET /resources/{filename}**

Ejemplo: `GET /resources/DataAsset.csv`

- **Autenticación requerida**: JWT Bearer o API Key
- **Query parameter**: `?download=true` fuerza descarga (`Content-Disposition: attachment`)
- **Sin parámetro**: visualización inline (`Content-Disposition: inline`)
- **Content-Type**: Automático según extensión (ej: `text/csv; charset=utf-8` para CSV)
- **Soporte ETag**: Responde con `304 Not Modified` si el cliente envía `If-None-Match` con ETag válido
- **Cache-Control**: Configurable en `appsettings.json`
- **Seguridad**: 
  - Bloquea path traversal (`..`, `/`, `\`)
  - Header `X-Content-Type-Options: nosniff`
  - Validación estricta de nombres de archivo

### Autenticación (OR)

El endpoint acepta **cualquiera** de estos métodos:

#### 1. API Key
```bash
curl -H "X-API-Key: tu-clave-secreta" \
  https://tu-servidor/resources/DataAsset.csv
```

#### 2. JWT Bearer Token
```bash
curl -H "Authorization: Bearer eyJhbGc..." \
  https://tu-servidor/resources/DataAsset.csv
```

**Nota**: Si envías `X-API-Key`, se valida por API Key. Si no, se intenta JWT.

## Configuración

### appsettings.json

```json
{
  "Assets": {
    "RootPath": "assets",              // Ruta relativa o absoluta
    "DefaultCacheSeconds": 300         // Cache-Control max-age
  },
  "Auth": {
    "Jwt": {
      "Issuer": "nextmobility",
      "Audience": "nextmobility.dataassets",
      "SigningKey": "CHANGE_ME_IN_PRODUCTION",  // ⚠️ Cambiar en producción
      "ValidateIssuer": false,                   // true en producción
      "ValidateAudience": false,                 // true en producción
      "ClockSkewSeconds": 30
    },
    "ApiKeysOptions": {
      "HeaderName": "X-API-Key",
      "Keys": [
        {
          "KeyId": "cliente-1",
          "Owner": "Nombre del cliente",
          "KeyHash": "sha256-hash-of-key",   // ⚠️ SHA-256 hex (lowercase)
          "Enabled": true
        }
      ]
    }
  },
  "RateLimiting": {
    "IpRateLimitOptions": {
      "EnableEndpointRateLimiting": true,
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 120                       // Máximo 120 peticiones/minuto
        }
      ]
    }
  }
}
```

### Generar API Key Hash

Las API Keys se almacenan como hash SHA-256. Para generar:

```bash
# En Linux/macOS
echo -n "tu-api-key-secreta" | sha256sum

# En PowerShell
$key = "tu-api-key-secreta"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })
```

## Almacenamiento de ficheros

- **Ubicación**: Por defecto, carpeta `assets/` (relativa al ejecutable)
- **Configurable**: Edita `Assets:RootPath` en `appsettings.json`
- **Rutas absolutas**: También soportadas (ej: `C:\Data\Assets`)
- **Seguridad**: Bloquea path traversal y nombres de archivo inválidos

### Actualizar el CSV

Simplemente sobrescribe el archivo en la carpeta `assets/`:
```bash
cp nuevo-archivo.csv /ruta/a/assets/DataAsset.csv
```

El ETag se recalcula automáticamente basándose en la fecha de modificación y tamaño.

## Despliegue en IIS (Windows)

### Prerrequisitos

1. **ASP.NET Core Hosting Bundle** para tu versión de .NET:
   - [.NET 10 Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/10.0) (requiere Windows Server 2016+)

2. **IIS** con módulo de reescritura de URL (opcional pero recomendado)

### Pasos de despliegue

1. **Publicar la aplicación**:
```bash
dotnet publish src/Next.API.DataAssets/Next.API.DataAssets.csproj \
  -c Release \
  -o C:\inetpub\dataassets
```

2. **Copiar assets**:
```bash
# Crear carpeta de assets
mkdir C:\inetpub\dataassets\assets

# Copiar tu CSV
copy tu-archivo.csv C:\inetpub\dataassets\assets\DataAsset.csv
```

3. **Configurar IIS**:
   - Crear Application Pool (.NET CLR Version: **No Managed Code**)
   - Crear sitio web o aplicación apuntando a `C:\inetpub\dataassets`
   - Copiar `deploy/web.config` a la carpeta de publicación (si no existe)

4. **Configurar producción**:
   - Editar `appsettings.json` o usar variables de entorno
   - Cambiar `Auth:Jwt:SigningKey` a valor seguro
   - Habilitar `ValidateIssuer` y `ValidateAudience`
   - Configurar API Keys reales

5. **Verificar**:
```bash
curl http://localhost/health
# Debe devolver: {"status":"ok"}
```

### web.config

El archivo `deploy/web.config` configura el módulo ASP.NET Core en IIS:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" 
           modules="AspNetCoreModuleV2" resourceType="Unspecified"/>
    </handlers>
    <aspNetCore processPath="dotnet" 
                arguments="Next.API.DataAssets.dll" 
                stdoutLogEnabled="false" 
                stdoutLogFile=".\logs\stdout" 
                hostingModel="inprocess">
      <environmentVariables>
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
      </environmentVariables>
    </aspNetCore>
  </system.webServer>
</configuration>
```

## Tests

### Unit Tests
```bash
dotnet test tests/Next.API.DataAssets.UnitTests
```

### Integration Tests
```bash
dotnet test tests/Next.API.DataAssets.IntegrationTests
```

Las pruebas de integración usan `WebApplicationFactory` para levantar la API en memoria.

## Desarrollo Local

1. **Clonar y restaurar**:
```bash
git clone <repo-url>
cd Next.API.DataAssets
dotnet restore
```

2. **Ejecutar**:
```bash
dotnet run --project src/Next.API.DataAssets
```

3. **Swagger UI**: Navega a `https://localhost:5001/swagger` (solo en Development)

4. **Probar con curl**:
```bash
# Sin autenticación (debe fallar con 401)
curl http://localhost:5000/resources/DataAsset.csv

# Con API Key
curl -H "X-API-Key: dev-key" \
  http://localhost:5000/resources/DataAsset.csv

# Forzar descarga
curl -H "X-API-Key: dev-key" \
  "http://localhost:5000/resources/DataAsset.csv?download=true"
```

## Rate Limiting

Por defecto: **120 peticiones por minuto** por IP para endpoints `/resources/*`.

Configurable en `appsettings.json` → `RateLimiting:IpRateLimitOptions:GeneralRules`.

## Seguridad

- ✅ Autenticación obligatoria (JWT o API Key)
- ✅ Validación estricta de nombres de archivo
- ✅ Protección contra path traversal
- ✅ Rate limiting por IP
- ✅ Headers de seguridad (`X-Content-Type-Options: nosniff`)
- ✅ Hashes SHA-256 para API Keys (no se almacenan en texto plano)
- ✅ HTTPS recomendado en producción

## Estructura del Proyecto

```
Next.API.DataAssets/
├── src/Next.API.DataAssets/
│   ├── Assets/               # Lógica de gestión de assets
│   ├── Auth/                 # Autenticación (JWT + API Key)
│   ├── Security/             # Sanitización de paths
│   ├── Observability/        # Logging y correlación
│   ├── Program.cs            # Punto de entrada
│   └── appsettings.json
├── tests/
│   ├── Next.API.DataAssets.UnitTests/
│   └── Next.API.DataAssets.IntegrationTests/
├── deploy/
│   └── web.config            # Configuración para IIS
└── README.md
```



## Licencia

[Especifica la licencia de tu proyecto]

## Soporte

Para preguntas o problemas, contacta [información de contacto].

