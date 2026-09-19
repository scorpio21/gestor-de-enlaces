# Diseño — #12 Ampliar detectores de enlace caído por host

Fecha: 2026-09-19

## Objetivo

El verificador HTTP de GestorAO (`scripts/link_checker.gd`) detecta enlaces muertos mediante un conjunto genérico de marcadores de texto (`MARCAS_MUERTO`) aplicados a cualquier host. La issue #12 pide ampliar la detección con marcadores **específicos por host** para los hosts más usados en catálogos de Argentum Online: MEGA, MediaFire, Google Drive, Google Sites, Dropbox y WeTransfer.

## Alcance

- Iteración de 6 hosts: `mega.nz`, `mediafire.com`, `drive.google.com`, `sites.google.com`, `dropbox.com`, `wetransfer.com`.
- Sin cambios en la UI ni en el flujo de escaneo existente. Sin regex complejas. Sin tocar persistencia.

## Arquitectura

Todo el cambio vive en `scripts/link_checker.gd` (194 líneas, sin cambios en la UI). Piezas:

### 1. Constante `MARCAS_POR_HOST: Dictionary`

```gdscript
const MARCAS_POR_HOST: Dictionary = {
	"mega.nz": PackedStringArray([
		"this file is no longer available",
		"file not available",
		"no longer available for download",
	]),
	"mediafire.com": PackedStringArray([
		"file cannot be found",
		"has been removed due to inactivity",
		"file has been deleted by the user",
	]),
	"drive.google.com": PackedStringArray([
		"the file you have selected does not exist",
		"the file was deleted",
		"the owner has removed this item",
		"has been removed by the owner",
	]),
	"sites.google.com": PackedStringArray([
		"the requested page could not be found",
	]),
	"dropbox.com": PackedStringArray([
		"file can't be found",
		"there's nothing here",
		"the file or folder has been deleted",
		"link has expired",
	]),
	"wetransfer.com": PackedStringArray([
		"this transfer has expired",
		"link has expired",
		"the transfer link you are looking for is no longer available",
	]),
}
```

Las marcas se escriben en minúsculas (como `MARCAS_MUERTO`); el HTML ya se normaliza con `to_lower()` antes de comparar (`link_checker.gd:113`).

### 2. Helper `_marcas_para_host(host: String) -> PackedStringArray`

Resuelve qué marcas aplican a un host:

- Recibe el host ya parseado (p.ej. `mega.nz`, `www.drive.google.com`).
- Itera `MARCAS_POR_HOST` y devuelve la lista del primer host cuya clave termina el host dado (`host.ends_with(clave)`) — el emparejado por **sufijo** cubre subdominios (`www.`, `drive.google.com`, etc.).
- Si el host coincide, devuelve **las específicas concatenadas con `MARCAS_MUERTO`** (unión: las genéricas se conservan para todo host, evitando regresión en casos como el mensaje de MEGA *"the link you have requested is not valid"*, que es genérico).
- Si ningún host coincide (o el host está vacío), **fallback a `MARCAS_MUERTO`** (las genéricas actuales sin añadidos).

### 3. Estado `_host_actual: String`

- Se asigna en `comprobar()` a partir de `_parsear_url(_url).host`.
- Se actualiza en cada redirección dentro de `_leer_respuesta()`: si el `Location` es una URL absoluta de otro host tras `_resolver_redirect`, re-asignar `_host_actual`; si es relativa, se conserva.
- Default `""`; vacío → fallback a genéricas.

### 4. Cambio en `_parece_muerto(codigo: int, html: String)`

- Mismo contrato de firmas actual (usa `_host_actual` de la instancia; los tests que llaman `_parece_muerto` sin comprobar siguen cubiertos con el default `""` → genéricas).
- Lógica: `_marcas_para_host(_host_actual)` devuelve la lista de marcas a aplicar (específicas + genéricas si el host es conocido; solo genéricas si no lo es). Si alguna marca está en el HTML → muerto.

> Detalle: las específicas **se suman** a las genéricas cuando el host es conocido (unión, una sola pasada sobre la lista combinada). Para hosts sin mapa, las genéricas siguen siendo el único criterio. Esto evita falsos positivos (las marcas específicas de un host no se aplican a otros) sin perder detección de mensajes genéricos de MEGA/Dropbox/etc.

## Flujo de datos

```text
comprobar(url) → _parsear_url(url) → _host_actual = host.parseado
  → _leer_respuesta() → _parece_muerto(código, fragmento)
      → _marcas_para_host(_host_actual)
          host conocido → específicas + MARCAS_MUERTO
          host desconocido → MARCAS_MUERTO
      → si alguna marca está en el HTML → muerto
```

## Manejo de errores / mantenibilidad

- `_host_actual` se resetea en `comprobar()` siempre (evita estado sucio entre comprobaciones).
- `_marcas_para_host` no lanza si el host está vacío o no está en el mapa → devuelve genéricas.
- Dict de solo lectura (constante); añadir un host nuevo = una línea en `MARCAS_POR_HOST` (+ tests), sin lógica adicional.

## Testing

Ampliar `tests/test_link_checker_timeout.gd` con checks sin red (deterministas):

1. `_marcas_para_host("mega.nz")` devuelve las 3 marcas de MEGA **y** `MARCAS_MUERTO` (unión; todo en minúsculas).
2. `_marcas_para_host("www.drive.google.com")` devuelve las marcas de `drive.google.com` + genéricas (sufijo cubre subdominio).
3. `_marcas_para_host("otro.host")` / `""` devuelve exactamente `MARCAS_MUERTO` (sin específicas).
4. `_parece_muerto` con host MEGA y HTML con marca específica (p.ej. `"this file is no longer available"`) → `true`.
5. `_parece_muerto` con host MEGA y HTML con una marca genérica (p.ej. `"page not found"`) → `true` (la unión conserva la detección genérica en hosts conocidos).
6. `_parece_muerto` con host MEGA y HTML que solo contiene una marca específica de OTRO host (p.ej. `"this transfer has expired"`, de WeTransfer) → `false` (las específicas de un host no se aplican a otro).

Settear `_host_actual` directamente en los tests (no requiere red).

## Entregables

- `scripts/link_checker.gd` — MARCAS_POR_HOST, `_host_actual`, `_marcas_para_host`, ajuste de `_parece_muerto`, reseteo/actualización de `_host_actual`.
- `tests/test_link_checker_timeout.gd` — nuevos checks.