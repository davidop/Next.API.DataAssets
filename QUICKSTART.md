# Quick Start Guide

Esta guía te ayudará a ejecutar la API en menos de 5 minutos para desarrollo/pruebas.

## Requisitos Previos

- .NET 10 SDK instalado ([Descargar](https://dotnet.microsoft.com/download/dotnet/10.0))
- Git

## Paso 1: Clonar y Restaurar

```bash
git clone <url-del-repo>
cd Next.API.DataAssets
dotnet restore
```

## Paso 2: Ejecutar

```bash
cd src/Next.API.DataAssets
dotnet run
```

La API estará disponible en:
- HTTP: `http://localhost:5000`
- HTTPS: `https://localhost:5001`

## Paso 3: Probar

### Endpoint de Health (sin autenticación)

```bash
curl http://localhost:5000/health
# Respuesta: {"status":"ok"}
```

### Descargar CSV con API Key

```bash
# La API Key por defecto en desarrollo es: super-secret-test-key
curl -H "X-API-Key: super-secret-test-key" \
  http://localhost:5000/resources/DataAsset.csv

# Respuesta:
# id,name,value
# 1,example,42
```

### Forzar descarga

```bash
curl -H "X-API-Key: super-secret-test-key" \
  "http://localhost:5000/resources/DataAsset.csv?download=true" \
  --output downloaded.csv
```

### Usar JWT en lugar de API Key

Primero, genera un JWT con la clave de desarrollo:

```bash
# Usa cualquier generador JWT con:
# Algoritmo: HS256
# SigningKey: CHANGE_ME_DEV_ONLY
# Issuer: nextmobility (opcional en dev)
# Audience: nextmobility.dataassets (opcional en dev)
```

Ejemplo con un token de prueba:
```bash
JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -H "Authorization: Bearer $JWT" \
  http://localhost:5000/resources/DataAsset.csv
```

## Paso 4: Ver Swagger UI (solo en Development)

Abre en tu navegador:
```
https://localhost:5001/swagger
```

Aquí puedes:
- Ver todos los endpoints disponibles
- Probar la API interactivamente
- Ver los modelos de request/response

## Actualizar el Archivo CSV

Simplemente sobrescribe el archivo:

```bash
echo "id,producto,precio
1,Widget A,19.99
2,Widget B,29.99" > src/Next.API.DataAssets/assets/DataAsset.csv
```

La API detectará automáticamente el cambio y actualizará el ETag.

## Ejecutar Tests

```bash
# Todos los tests
dotnet test

# Solo integration tests
dotnet test tests/Next.API.DataAssets.IntegrationTests

# Solo unit tests
dotnet test tests/Next.API.DataAssets.UnitTests
```

## Configuración Rápida

### Cambiar el puerto

Edita `src/Next.API.DataAssets/Properties/launchSettings.json` o usa:

```bash
dotnet run --urls "http://localhost:8080;https://localhost:8443"
```

### Añadir más API Keys

Edita `src/Next.API.DataAssets/appsettings.json`:

```json
{
  "Auth": {
    "ApiKeysOptions": {
      "Keys": [
        {
          "KeyId": "mi-nueva-key",
          "Owner": "Mi Cliente",
          "KeyHash": "hash-sha256-de-tu-key",
          "Enabled": true
        }
      ]
    }
  }
}
```

Para generar el hash:

```bash
# Linux/macOS
echo -n "mi-api-key-secreta" | sha256sum | awk '{print $1}'

# PowerShell
$key = "mi-api-key-secreta"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })
```

### Deshabilitar Rate Limiting (para desarrollo)

En `appsettings.json`, cambia el límite a un valor alto:

```json
{
  "RateLimiting": {
    "IpRateLimitOptions": {
      "GeneralRules": [
        {
          "Endpoint": "*:/resources/*",
          "Period": "1m",
          "Limit": 10000
        }
      ]
    }
  }
}
```

## Troubleshooting

### Error: "Address already in use"

Otro proceso está usando el puerto. Cambia el puerto o detén el proceso:

```bash
# Ver qué proceso usa el puerto 5000
lsof -i :5000  # Linux/macOS
netstat -ano | findstr :5000  # Windows
```

### Error: "Unable to find package Microsoft.AspNetCore.OpenApi"

Ejecuta:
```bash
dotnet restore --force
dotnet build
```

### La API devuelve 401 Unauthorized

Verifica que estás enviando la API Key o JWT:
- Header `X-API-Key: super-secret-test-key` (para API Key)
- Header `Authorization: Bearer <token>` (para JWT)

### El archivo CSV no se encuentra (404)

Verifica que existe:
```bash
ls -la src/Next.API.DataAssets/assets/DataAsset.csv
```

Si no existe, créalo:
```bash
mkdir -p src/Next.API.DataAssets/assets
echo "id,name,value
1,test,123" > src/Next.API.DataAssets/assets/DataAsset.csv
```

## Próximos Pasos

- Lee el [README.md](README.md) completo para entender todas las features
- Consulta [DEPLOYMENT.md](DEPLOYMENT.md) para desplegar en producción
- Explora los tests en `tests/` para ver ejemplos de uso

## Recursos Útiles

- [Documentación oficial de .NET](https://docs.microsoft.com/dotnet/)
- [ASP.NET Core API Documentation](https://docs.microsoft.com/aspnet/core/)
- [JWT.io](https://jwt.io/) - Para crear y validar JWTs

---

**¿Problemas?** Abre un issue en el repositorio o contacta al equipo de desarrollo.
