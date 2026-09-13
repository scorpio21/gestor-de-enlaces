# Spec: Normalización de URLs y arreglos de la ventana Agregar enlace (#25, #32, #33)

**Fecha:** 2026-09-14
**Issues:**
- scorpio21/gestor-de-enlaces#25 — [Datos] Normalización de URLs para evitar duplicados semánticos
- scorpio21/gestor-de-enlaces#32 — [UI] El botón Guardar de la ventana Agregar enlace queda fuera de vista (ventana no cabe)
- scorpio21/gestor-de-enlaces#33 — [UI] No se aceptan imágenes .jpg en la ventana Agregar enlace

## Objetivo

Normalizar las URLs al guardarlas y usar una **forma canónica** como clave de unicidad y de estado, de modo que variantes semánticas de la misma URL (`http`/`https`, `/` final redundante, mayúsculas, fragmento, puerto por defecto) no generen duplicados ni estados huérfanos. Además, arreglar dos bugs de la ventana de agregar enlaces: el botón Guardar cortado por el tamaño de la ventana y la aceptación real de imágenes `.jpg`.

## Contexto (estado actual)

- Datos: arrays JSON planos de entradas `{"nombre","desc","url","img","cat"}` (`main._cargar_datos`/`_guardar_datos`). `DATA_RES = res://data/data.json` (56 entradas commiteadas), `DATA_USER = user://enlaces.json`. `_guardar_datos()` escribe **ambos** archivos en cada guardado (así entró la clave `cat` en el #5).
- Unicidad actual: comparación **exacta de string** tras `strip_edges()`. `gestor_catalogo.separar(urls, existentes)` (gestor_catalogo.gd:16) construye `vistos[url.strip_edges()]`; `main._url_existe` / `_cambios_url_validos` delegnan en `separar`. Un enlace `https://x.com` se da de alta sin problema aunque exista `http://x.com`.
- Estados: `estado_store.gd` (diccionario genérico) con `guardar_estado`, `marcar_borrado`, `borrar_estado`, `renombrar`; las claves de `estados.json` **son las URLs tal cual** se comprobaron (`main._on_item_terminado`/`_persistir_recompra` usan `item.url`; `_mostrar_lista` busca `_estados.get(url_item)`; `gestor_contadores.gd:12` idem). `borrados.json` guarda strings de URLs borradas; `_cargar_datos` filtra `_borrados.has(url)`.
- Escritura de entradas: `_on_enlace_guardado` (alta individual), `_on_lote_guardado` (varias), `_on_enlace_editado` y `_cambios_url_validos` (edición). La validación de esquema (`begins_with("http://")`/`"https://"` **con mayúsculas sensibles**) está en `agregar_enlace.gd:150` y `main.gd:239`; un `HTTP://...` se rechaza hoy.
- `link_checker.gd`: parsa la URL para conectar por host/puerto/path (independiente de la normalización; un fragmento nunca viaja en HTTP y el checker ya lo ignora al no incluirlo en `path`).
- Ventana agregar enlace (`AgregarEnlace.tscn`): `Window` `size = Vector2i(540, 520)`, `unresizable = true`. Contenido de `%Columna` (VBox, incluye `%VistaPrevia` 120px y las filas de `%EtiquetaCategoria`/`%Categoria` añadidas en el #5): altura estimada ≈ 650px → **desborda** y la fila `%Botones` (Cancelar/Guardar) queda fuera de la vista.
- Imágenes: `gestor_imagenes.copiar()` (gestor_imagenes.gd:4) siempre `save_png` hacia `res://Assets/png/img_<ts>.png`, redimensionando >800px. `FileDialog` (`DialogoImagen`) con filtros `"*.png", "*.jpg ; *.jpeg", "*.webp"`. `Image.load_from_file` decodifica png/jpg/webp (verificado empíricamente con jpg). `_on_imagen_picked` ignora en silencio una decodificación fallida (muestra el placeholder y sigue).
- `limpiar_huerfanas` solo recorre `res://Assets/png` para `img_*.png`; `main._borrar_captura_si_huerfana` solo borra rutas `res://Assets/png/`.

## Enfoque

Dos funciones estáticas en `gestor_catalogo.gd` (patrón ya usado por `dominio`/`separar`/`normalizar_categoria`): `normalizar_url()` para la forma **guardada** (conserva el esquema que escribió el usuario) y `clave_unica()` para la **clave de unicidad/estado** (sin esquema, para que `http` y `https` colisionen). Todas las rutas de escritura (entradas y estados/borrados) y de búsqueda (estados, contadores) pasan a usar esas formas; `link_checker` no cambia. En el mismo ciclo se arregla la ventana (#32, tamaño) y las imágenes (#33, jpg/formatos con carpeta propia y errores visibles).

## Alcance

Dentro:

- `gestor_catalogo.gd`: `static func normalizar_url(url: String) -> String` y `static func clave_unica(url: String) -> String`; `separar()` pasa a comparar con `clave_unica` y devolver formas canónicas.
- Puntos de escritura/lectura de URLs en `main.gd` (alta, lote, edición, estados, borrados, lista, contadores).
- Migración en memoria al cargar (`_cargar_datos`): normalización de URLs de entradas y re-aje de claves de `_estados`/`_borrados`.
- #32: ventana `resizable = true` con tamaño inicial mayor.
- #33: filtros del diálogo, error visible al decodificar, `gestor_imagenes.copiar()` conservando formato por extensión (jpg → carpeta propia), limpieza de huérfanas en ambas carpetas.
- Pruebas unitarias/integradas por suite y regresión de batería completa.

Fuera de alcance:

- Unificar `www.`/dominio desnudo (decidido: no, queda para otro ciclo).
- `link_checker._parsear_url` ni el comportamiento HTTP (redirects, etc.).
- Cambiar el formato de `estados.json`/`borrados.json` ni de `enlaces.json` (mismo esquema, claves canónicas).
- Reescritura manual de `data/data.json`; se sincroniza solo con `_guardar_datos()` como hoy.
- Migrar imágenes existentes de `Assets/png` a otras carpetas; solo afecta a copias nuevas.
- **No se tocan** `data/data.json.bak` ni `data/data2.json`.

## Comportamiento detallado

### `gestor_catalogo.gd` — funciones de normalización

**`static func normalizar_url(url: String) -> String`** (forma de guardado, idempotente):
1. `strip_edges()`.
2. Esquema a minúsculas (`HTTP://` → `http://`); solo se reconocen `http://`/`https://` (el resto se devuelve sin tocar).
3. Host en minúsculas. **El path nunca se pasa a minúsculas** (sensible a mayúsculas).
4. Elimina el fragmento (`#...`).
5. Quita el slash final redundante de la raíz (`http://host/` → `http://host`); los slashes de subruta (`host/a/`) se conservan.
6. Elimina el puerto por defecto del esquema (`:80` en http, `:443` en https).

**`static func clave_unica(url: String) -> String`** (clave de unicidad/estado): mismo proceso pero **elimina el esquema completo** (host en minúsculas, sin fragmento, sin slash de raíz, puerto conservado si no es el por defecto, path intacto). Hace que `http://x.com/a` y `https://x.com/a` colisionen.

Ejemplos esperados:

| Entrada | `normalizar_url` | `clave_unica` |
|---|---|---|
| `HTTP://Ejemplo.com/a#sec` | `http://ejemplo.com/a` | `ejemplo.com/a` |
| `http://x.com/` | `http://x.com` | `x.com` |
| `https://X.com` | `https://x.com` | `x.com` |
| `http://x.com:80/p?q=1` | `http://x.com/p?q=1` | `x.com/p?q=1` |
| `https://x.com:8080/A/B/` | `https://x.com:8080/A/B/` | `x.com:8080/A/B/` |
| `ftp://x.com` | `ftp://x.com` | (sin uso) |

### `gestor_catalogo.gd` — `separar()`

Compara por `clave_unica` (internamente) y devuelve en `nuevas`/`repetidas` las formas **canónicas** (`normalizar_url`) de las URLs válidas.

### `main.gd` — puntos de escritura y búsqueda

- **`_cargar_datos()`**: tras cargar `_entradas`/`_estados`/`_borrados`, nueva migración `_normalizar_urls()`:
  - `entrada["url"] = GestorCatalogoScript.normalizar_url(entrada.url)` para cada entrada Dictionary.
  - `_estados` re-ajeado a `clave_unica(key)`: si dos claves colisionan, gana la **última** en el orden del JSON.
  - `_borrados` re-ajeado a `clave_unica(key)` con duplicados eliminados.
  - El filtro de borradas pasa a `not _borrados.has(clave_unica(entrada.url))`.
  - Llamada junto a `_normalizar_categorias()` al final de `_cargar_datos`.
- **`_on_enlace_guardado`**: `var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))` se usa como `datos["url"]` y en `_url_existe`. Si colisiona, el mensaje `"Ya existe: %s"` muestra la URL canónica de la entrada existente.
- **`_on_lote_guardado`**: cada línea se `normalizar_url` **antes** de validar `http(s)` y de `separar`; las entradas nuevas guardan la URL canónica (`"url": u_canonica`). Así `HTTP://X.com/` pasa la validación.
- **`_on_enlace_editado` / `_cambios_url_validos`**: `url_nueva = normalizar_url(...)`; la colisión compara `clave_unica`; `renombrar(url_original, url_nueva)` recibe formas canónicas.
- **Estados**: `_on_item_terminado` y `_persistir_recompra` hacen `guardar_estado(clave_unica(item.url), ...)` y `_estados[clave_unica(item.url)] = ...`. `_mostrar_lista` busca `_estados.get(clave_unica(url_item), {})`. `gestor_contadores.gd:12` pasa a buscar `_estados.get(GestorCatalogoScript.clave_unica(url), {})`, añadiendo el preload `const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")`.
- **Borrado**: `_confirmar_borrado` usa `marcar_borrado(clave_unica(item.url))`, `borrar_estado(clave_unica(item.url))`, `_estados.erase(clave_unica(item.url))`.
- `estado_store.gd` no cambia: es un diccionario por clave; `main` decide qué clave pasa.
- `_borrar_captura_si_huerfana`: acepta rutas `res://Assets/png/` **y** `res://Assets/jpg/` (extensión `.jpg`).

### Ventana Agregar enlace (#32)

`AgregarEnlace.tscn`: `unresizable = true` → `resizable = true`; `size = Vector2i(540, 680)`. El contenido cabe en individual y en "varias".

### Imágenes (#33)

- `AgregarEnlace.tscn` (`DialogoImagen.filters`): un único filtro bien formado: `PackedStringArray("*.png ; *.jpg ; *.jpeg ; *.webp")`.
- `agregar_enlace.gd` `_on_imagen_picked`: si `Image.load_from_file(ruta)` devuelve `null`/vacío → `error_label.text = "No se pudo cargar la imagen."` y **no** se fija `_imagen_ruta` (hoy falla en silencio).
- `gestor_imagenes.copiar()` — según la extensión del origen (minúsculas):
  - `.png` → `res://Assets/png/img_<ts>.png` (`save_png`, igual que hoy).
  - `.jpg` / `.jpeg` → `res://Assets/jpg/img_<ts>.jpg` (redimensiona >800px como hoy; `save_jpg(..., 0.9)`).
  - `.webp` → reconvertido a png → `res://Assets/png/img_<ts>.png`.
  - otra extensión → `{"ok": false, "error": "Formato no soportado."}`.
  - La redimensión (`ANCHO_MAX = 800`) se aplica a todos los formatos antes de guardar.
- `gestor_imagenes.limpiar_huerfanas`: recorre `res://Assets/png` (`img_*.png`) **y** `res://Assets/jpg` (`img_*.jpg`).

## Errores y casos borde

| Caso | Resultado |
|---|---|
| `HTTP://X.com/` en alta o lote | Se guarda como `http://x.com`; pasa la validación de esquema (antes rechazada). |
| Alta `https://x.com/a` existiendo `http://x.com/a` | Bloqueada con "Ya existe" (misma `clave_unica`). Solo difieren a nivel visual (esquema). |
| Alta `http://x.com:80/a` existiendo `http://x.com/a` | Duplicado (puerto por defecto eliminado). |
| Altas `ftp://`, `mailto:` | `normalizar_url` las devuelve sin tocar; la validación de alta/lote las rechaza (sin cambio). |
| Fragmento `#...` | Eliminado en guardado y en clave. |
| `%Cargar estados` con claves viejas que colisionan a la misma canónica | Gana la última en orden del JSON; no se pierden estados. |
| `borrados.json` con duplicados/duplicados tras re-aje | Lista re-ajeada + deduplicada en memoria; se persiste en la siguiente escritura. |
| Dos entradas con clave única igual pero URLs distintas (una http y otra https) | Imposible convivir: precipitar se bloquea en alta/edición. La migración no elimina entradas (no existen hoy). |
| Jpg elegido en "varias" | No aplica: el modo varias no usa imágenes. |
| Jpg no decodificable | Error visible en `error_label`; el guardado continúa sin imagen (no marca `_imagen_ruta`). |
| Extensión desconocida (gif/bmp... aunque el diálogo no las liste) | `copiar` → `ok:false` "Formato no soportado."; `_on_guardar` muestra el error y no cierra. |
| Webp elegido | Reconversión a png en `Assets/png`. |
| Entrada con imagen jpg que se borra o cambia | `_borrar_captura_si_huerfana` borra el archivo de `Assets/jpg` si queda huérfano. |
| `limpiar_huerfanas` con jpg sueltos no referidos | Los elimina de `Assets/jpg`. |
| Ventana en monitores pequeños / tema con fuentes grandes | `resizable = true`; los botones siempre visibles al poder redimensionar. |

## Pruebas

### `tests/test_gestor_catalogo.gd` (21 → ~31 checks) — normalización

- `normalizar_url("HTTP://Ejemplo.com/a#sec")` → `"http://ejemplo.com/a"`.
- `normalizar_url("http://x.com/")` → `"http://x.com"`.
- `normalizar_url("http://x.com:80/p?q=1")` → `"http://x.com/p?q=1"`.
- `normalizar_url("https://x.com:443/A/B/")` → `"https://x.com/A/B/"` (subruta conserva `/` y mayúsculas; puerto por defecto eliminado).
- `normalizar_url("https://x.com:8080/A/B/")` → sin cambios (puerto no estándar conservado).
- `normalizar_url("ftp://x.com")` → `"ftp://x.com"` (no-toque); `normalizar_url("")` → `""`.
- Idempotencia: `normalizar_url(normalizar_url(s)) == normalizar_url(s)`.
- `clave_unica("http://X.com/a") == clave_unica("https://x.com/a")`.
- `clave_unica("http://x.com/") == clave_unica("https://x.com")`.
- `clave_unica("http://x.com/a/") == "x.com/a/"` (subruta conservada) y `!= "x.com/a"`.
- `clave_unica("http://x.com:80/a") == clave_unica("http://x.com/a")`; `clave_unica("http://x.com:8080/a") != clave_unica("http://x.com/a")`.
- `separar(["https://x.com/"], ["http://x.com"])` → `repetidas` (misma clave).

### `tests/test_main_barra.gd` (59 → ~66 checks) — dedup semántico y estados

1. Alta `https://Ejemplo.com/` existiendo `http://ejemplo.com` → "Ya existe" y sin duplicar (`_persistir = false`).
2. Lote `["HTTP://x.com/", "https://x.com"]` con catálogo que ya tiene `http://x.com` → 1 añadida + 1 repetida + 0 inválidas; la entrada nueva queda con URL `http://x.com`.
3. Lote `["HTTP://X.com/"]` sobre catálogo vacío → se añade con URL canónica `http://x.com`.
4. Edición de `http://x.com/a` a `https://x.com/a` → bloqueada si existe otra entrada con esa clave.
5. Tras comprobar (`_on_item_terminado` simulado), `_estados` tiene clave `clave_unica(item.url)` y `_mostrar_lista` aplica el estado.
6. `_cargar_datos` con `_estados` sembrado con claves viejas (`http://x.com/` y `https://x.com`) → colapsa a una sola clave.
7. `gestor_contadores` cuenta correctamente con `_estados` keyed por `clave_unica`.

### `tests/test_gestor_imagenes.gd` (13 → ~20 checks) — formatos y carpetas

1. `copiar` png → destino en `Assets/png`, extensión `.png` (regresión).
2. `copiar` jpg (cargado/guardado en el test) → destino en `Assets/jpg`, extensión `.jpg`, decodificable.
3. `copiar` jpeg → idem (`Assets/jpg`, `.jpg`).
4. `copiar` webp → destino en `Assets/png`, `.png` (reconversión).
5. `copiar` con imagen grande >800px → redimensionada (mismo comportamiento para jpg y png).
6. `copiar` extensión desconocida → `ok:false` con "Formato no soportado.".
7. `limpiar_huerfanas` con un `img_*.jpg` no referido → lo elima; con referido → no.
8. borrado/renombrado no se alteran.

### Regresión

Batería completa (10 suites + las modificadas) con `TESTS OK`. Verificación manual: ventana de agregar (botón Guardar visible, #32) y selección real de un `.JPG` del sistema (#33). `data/data.json.bak` y `data/data2.json` intactos.

## Notas

- `clave_unica` no incluye `www.`-normalización (decisión de alcance): `www.x.com` y `x.com` siguen siendo enlaces distintos.
- La clave sale del parseo de `normalizar_url` sin esquema; el puerto por defecto se omite en ambos para que coincidan al servir el mismo recurso.
- Los archivos de estado antiguos siguen siendo válidos: el re-aje al cargar actualiza las claves en memoria y se persiste con la siguiente escritura.
- `EstadoStore` se queda como utilidad genérica por clave; la política de claves vive en `main` (y `gestor_contadores` vía `clave_unica`).
- `AgregarEnlace.tscn` pasa a ser resizable; la altura 680 cubre ambos modos con el tema actual.