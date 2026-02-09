# Next.API.DataAssets

API de entrega de ficheros (data assets) protegida por **JWT** o **API Key** (OR), lista para hospedar en **Windows IIS**.

## Endpoint
- `GET /resources/{filename}`
  - Ejemplo: `/resources/DataAsset.csv`
  - `?download=true` fuerza `Content-Disposition: attachment`

## Autenticación
- **API Key**: header `X-API-Key: <key>`
- **JWT**: header `Authorization: Bearer <token>`

Si se envía `X-API-Key`, se valida por API Key; si no, se intenta JWT.

## Almacenamiento de ficheros
- Por defecto, carpeta `assets/` (configurable en `appsettings.json`).
- Se bloquean intentos de path traversal (`..`, `/`, `\`).

## IIS (Windows)
- Publicar la app con el **ASP.NET Core Hosting Bundle** instalado en el servidor.
- Incluye un `deploy/web.config` de referencia para IIS.

## Tests
- Unit tests: `tests/Next.API.DataAssets.UnitTests`
- Integration tests: `tests/Next.API.DataAssets.IntegrationTests` (WebApplicationFactory)

> Nota: este repo targetea `net8.0` como baseline estable. Cambiar a `net10.0` cuando el SDK esté disponible en vuestro build agent.

