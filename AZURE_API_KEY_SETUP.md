# Configuración de API Key en Azure

## 🔑 API Key Generada

**API Key** (Envía esto a tus clientes):
```
AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH
```

**SHA-256 Hash** (Configura esto en Azure):
```
f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab
```

---

## ⚙️ Configurar en Azure App Service

### Método 1: Variables de Entorno (Recomendado)

1. Ve a **Azure Portal** → Tu App Service
2. En el menú lateral: **Configuration** → **Application settings**
3. Clic en **+ New application setting**
4. Agrega estas variables:

| Nombre | Valor |
|--------|-------|
| `Auth__ApiKeysOptions__Keys__0__KeyId` | `production-client-1` |
| `Auth__ApiKeysOptions__Keys__0__Owner` | `Production Client 1` |
| `Auth__ApiKeysOptions__Keys__0__KeyHash` | `f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab` |
| `Auth__ApiKeysOptions__Keys__0__Enabled` | `true` |

5. Clic en **Save**
6. Espera a que se reinicie la aplicación

---

### Método 2: Actualizar appsettings.Production.json

Actualiza el archivo `src/Next.API.DataAssets/appsettings.Production.json`:

```json
{
  "Auth": {
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
  }
}
```

Luego republica la aplicación en Azure.

---

## 🧪 Testear el Endpoint

### Opción 1: Usando el script de PowerShell

```powershell
.\Test-AzureEndpoint.ps1 -ApiKey "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH"
```

Con descarga:
```powershell
.\Test-AzureEndpoint.ps1 -ApiKey "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH" -Download
```

### Opción 2: Usando cURL

```bash
curl -X GET \
  "https://next-api-dataassets-net8.azurewebsites.net/resources/DataAsset?download=true" \
  -H "X-API-Key: AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH"
```

### Opción 3: Usando Postman

1. **Método**: `GET`
2. **URL**: `https://next-api-dataassets-net8.azurewebsites.net/resources/DataAsset?download=true`
3. **Headers**:
   - Key: `X-API-Key`
   - Value: `AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH`

---

## 📝 Agregar Múltiples Clientes

Para agregar más clientes, repite la configuración con índices incrementales:

### Variables de Entorno:
- `Auth__ApiKeysOptions__Keys__1__KeyId`
- `Auth__ApiKeysOptions__Keys__1__Owner`
- `Auth__ApiKeysOptions__Keys__1__KeyHash`
- `Auth__ApiKeysOptions__Keys__1__Enabled`

### O en appsettings.Production.json:

```json
{
  "Auth": {
    "ApiKeysOptions": {
      "Keys": [
        {
          "KeyId": "production-client-1",
          "Owner": "Production Client 1",
          "KeyHash": "f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab",
          "Enabled": true
        },
        {
          "KeyId": "production-client-2",
          "Owner": "Production Client 2",
          "KeyHash": "otra-hash-aqui",
          "Enabled": true
        }
      ]
    }
  }
}
```

---

## 🔒 Seguridad

- ✅ **NUNCA** compartas el hash SHA-256 con clientes
- ✅ **SOLO** comparte la API Key en texto plano con clientes
- ✅ Usa canales seguros para enviar API Keys (encrypted email, password manager, etc.)
- ✅ Rota las API Keys periódicamente
- ✅ Deshabilita API Keys comprometidas (`Enabled: false`)

---

## 🔍 Verificar Configuración Actual en Azure

Para ver qué configuración tiene Azure actualmente:

```powershell
# Instala Azure CLI si no lo tienes
# winget install Microsoft.AzureCLI

# Login
az login

# Ver configuración de la app
az webapp config appsettings list --name next-api-dataassets-net8 --resource-group <tu-resource-group>
```

O usa Azure Portal > App Service > Configuration > Application settings
