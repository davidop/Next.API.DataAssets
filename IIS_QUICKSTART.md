# 🚀 Configuración Rápida de API Key en IIS

## ✅ Archivos Disponibles

- **[IIS_APPSETTINGS_GUIDE.md](IIS_APPSETTINGS_GUIDE.md)** - Guía completa (todas las opciones)
- **[deploy/web.config](deploy/web.config)** - Template con comentarios
- **[deploy/web.config.example](deploy/web.config.example)** - Ejemplo ya configurado
- **[Configure-IIS-ApiKey.ps1](Configure-IIS-ApiKey.ps1)** - Script de configuración automática

---

## ⚡ Configuración Rápida (3 opciones)

### 🎯 Opción 1: Script Automático (Más Rápido)

```powershell
# En tu servidor IIS, como Administrador:
.\Configure-IIS-ApiKey.ps1 -AppPoolName "DataAssetsAppPool" -SitePath "C:\inetpub\dataassets"
```

✅ **Se hace automáticamente**:
- Configura las variables de entorno en web.config
- Hace backup del web.config anterior
- Reinicia el Application Pool
- Muestra instrucciones de testing

---

### 📄 Opción 2: Copiar web.config.example

```powershell
# En tu servidor IIS:
cd C:\inetpub\dataassets
cp deploy\web.config.example web.config

# Reiniciar App Pool
Import-Module WebAdministration
Restart-WebAppPool -Name "DataAssetsAppPool"
```

✅ **Ventaja**: Ya tiene la API Key configurada (solo copiar y listo)

---

### ✏️ Opción 3: Editar web.config Manualmente

Edita `C:\inetpub\dataassets\web.config` y agrega en la sección `<environmentVariables>`:

```xml
<environmentVariable name="Auth__ApiKeysOptions__HeaderName" value="X-API-Key" />

<environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyId" value="production-client-1" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__Owner" value="Production Client 1" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__KeyHash" value="f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab" />
<environmentVariable name="Auth__ApiKeysOptions__Keys__0__Enabled" value="true" />
```

Reinicia el App Pool:
```powershell
Restart-WebAppPool -Name "DataAssetsAppPool"
```

---

## 🔑 API Key Generada

**Para compartir con clientes**:
```
AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH
```

**Hash SHA-256** (ya configurado en los ejemplos):
```
f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab
```

---

## 🧪 Testing

### Desde el servidor IIS (local):

```powershell
$headers = @{ "X-API-Key" = "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH" }
Invoke-WebRequest -Uri "http://localhost/resources/DataAsset" -Headers $headers -UseBasicParsing
```

### Desde Postman (remoto):

- **Method**: `GET`
- **URL**: `http://tu-servidor-iis/resources/DataAsset?download=true`
- **Header**: 
  - Key: `X-API-Key`
  - Value: `AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH`

---

## 📚 Documentación Completa

| Archivo | Descripción |
|---------|-------------|
| [IIS_APPSETTINGS_GUIDE.md](IIS_APPSETTINGS_GUIDE.md) | Guía completa con 4 opciones de configuración |
| [POSTMAN_QUICKSTART.md](POSTMAN_QUICKSTART.md) | Guía de testing con Postman |
| [AZURE_API_KEY_SETUP.md](AZURE_API_KEY_SETUP.md) | Configuración para Azure App Service |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Referencia completa de configuración |
| [docs/deploy/IIS-WindowsServer2019.md](docs/deploy/IIS-WindowsServer2019.md) | Despliegue completo en IIS |

---

## 🛠️ Scripts Útiles

| Script | Descripción |
|--------|-------------|
| [Generate-ApiKey.ps1](Generate-ApiKey.ps1) | Genera nuevas API Keys |
| [Configure-IIS-ApiKey.ps1](Configure-IIS-ApiKey.ps1) | Configura API Key en IIS automáticamente |
| [Test-AzureEndpoint.ps1](Test-AzureEndpoint.ps1) | Testea endpoints de Azure |

---

## ➕ Agregar Múltiples Clientes

Para agregar más clientes, usa índices incrementales (`__0__`, `__1__`, `__2__`):

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
```

Genera nuevas keys con:
```powershell
.\Generate-ApiKey.ps1 -KeyId "client-2" -Owner "Cliente 2"
```

---

## ❓ Troubleshooting

### ❌ Error 401 Unauthorized

```powershell
# Verifica que el hash es correcto
$apiKey = "AGdJ4tivFc0Ljzh3ebMQ5gXZkDnfulSH"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($apiKey)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
-join ($hash | ForEach-Object { $_.ToString("x2") })

# Debe retornar: f34270a335b52d33de7c3b04da14f2fb1ffee7e1c10247984287ebe4e9e364ab
```

### ❌ Configuración no se aplica

```powershell
# Reiniciar App Pool específico
Restart-WebAppPool -Name "DataAssetsAppPool"

# O reiniciar IIS completo
iisreset

# Ver logs del App Pool
Get-Content "C:\inetpub\dataassets\logs\stdout_*.log" -Tail 50
```

---

## 🎯 Recomendación

**Para IIS en Producción**: Usa **variables de entorno en web.config** (Opción 2 o 3)

✅ **Ventajas**:
- Seguro
- No se pierde al republicar
- Cada site puede tener su propia configuración
- Fácil de mantener

---

## 🔒 Seguridad

- ✅ Comparte solo la API Key (texto plano) con clientes
- ❌ NUNCA compartas el hash SHA-256
- ✅ Genera una API Key diferente por cliente
- ✅ Deshabilita keys comprometidas (`Enabled: false`)
- ✅ Rota las keys periódicamente
