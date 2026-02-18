# Guía Rápida - Testear API en Azure con Postman

## 🎯 Problema Actual
El endpoint `https://next-api-dataassets-net8.azurewebsites.net/resources/DataAsset` retorna **401 Unauthorized** porque requiere autenticación por API Key.

---

## ✅ Solución en 3 Pasos

### **PASO 1: Configurar API Key en Azure**

#### Opción A - Variables de Entorno (Recomendado - NO requiere republicar)

1. Ve a **Azure Portal** → https://portal.azure.com
2. Busca tu App Service: `next-api-dataassets-net8`
3. Menú lateral: **Configuration** → **Application settings**
4. Clic en **+ New application setting** y agrega estas 4 variables:

```
Nombre: Auth__ApiKeysOptions__Keys__0__KeyId
Valor: production-client-1

Nombre: Auth__ApiKeysOptions__Keys__0__Owner
Valor: Production Client 1

Nombre: Auth__ApiKeysOptions__Keys__0__KeyHash
Valor: f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab

Nombre: Auth__ApiKeysOptions__Keys__0__Enabled
Valor: true
```

5. Clic en **Save** (arriba)
6. Espera 30-60 segundos a que se reinicie la app

---

#### Opción B - Actualizar appsettings.Production.json (Requiere republicar)

Edita `src/Next.API.DataAssets/appsettings.Production.json` y reemplaza la sección de API Keys:

```json
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
```

Luego republica en Azure.

---

### **PASO 2: Testear con Postman**

1. Abre **Postman**
2. Crea una nueva request:
   - **Método**: `GET`
   - **URL**: `https://next-api-dataassets-net8.azurewebsites.net/resources/DataAsset?download=true`

3. Ve a la pestaña **Headers**
4. Agrega este header:
   ```
   Key: X-API-Key
   Value: AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH
   ```

5. Clic en **Send**

---

### **PASO 3: Verificar Respuesta Exitosa**

Deberías ver:
- ✅ **Status**: `200 OK`
- ✅ **Headers**:
  - `Content-Type`: `text/csv` (o similar)
  - `x-correlation-id`: Un ID único
  - `x-rate-limit-remaining`: Requests restantes
- ✅ **Body**: Contenido del archivo DataAsset.csv

---

## 🧪 Testear desde PowerShell (Alternativa)

Usa el script incluido:

```powershell
# Simple test
.\Test-AzureEndpoint.ps1 -ApiKey "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH"

# Con download
.\Test-AzureEndpoint.ps1 -ApiKey "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH" -Download

# Custom URL
.\Test-AzureEndpoint.ps1 -ApiKey "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH" -Url "https://next-api-dataassets-net8.azurewebsites.net/resources/OtroArchivo.csv" -Download
```

---

## 🔑 Tu API Key (Guarda esto)

**IMPORTANTE**: Esta es la clave que debes enviar a tus clientes:

```
AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH
```

**NO envíes el hash SHA-256**, ese solo va en la configuración de Azure.

---

## 🛠️ Generar Nuevas API Keys en el Futuro

```powershell
# Generar nueva key
.\Generate-ApiKey.ps1

# Con información del cliente
.\Generate-ApiKey.ps1 -KeyId "cliente-xyz" -Owner "Nombre del Cliente"

# Key más larga (48 caracteres)
.\Generate-ApiKey.ps1 -Length 48 -KeyId "cliente-vip" -Owner "Cliente VIP"
```

---

## ❓ Troubleshooting

### Error 401 Unauthorized
- ✅ Verifica que agregaste las variables de entorno en Azure
- ✅ Verifica que guardaste y esperaste el reinicio de la app
- ✅ Verifica que el header es exactamente `X-API-Key` (case-sensitive)
- ✅ Verifica que la API Key no tiene espacios extra

### Error 404 Not Found
- ✅ Verifica que el archivo existe en la carpeta `assets/`
- ✅ Verifica que el nombre del archivo es correcto (case-sensitive)

### Error 429 Too Many Requests
- ✅ Has excedido el rate limit (60 requests/minuto en producción)
- ✅ Espera un minuto e intenta de nuevo

---

## 📚 Archivos de Referencia

- `AZURE_API_KEY_SETUP.md` - Documentación completa de configuración
- `Test-AzureEndpoint.ps1` - Script para testear el endpoint
- `Generate-ApiKey.ps1` - Script para generar nuevas API Keys
- `docs/CONFIGURATION.md` - Toda la documentación de configuración

---

## 🎉 Endpoints Disponibles

| Endpoint | Descripción | Auth |
|----------|-------------|------|
| `GET /health` | Health check simple | No |
| `GET /healthz` | Health check detallado | No* |
| `GET /resources/{filename}` | Obtener recurso | Sí |
| `GET /resources/{filename}?download=true` | Descargar recurso | Sí |

*En producción `/healthz` requiere auth según tu configuración actual.
