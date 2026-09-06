# Spec — Catálogo: añadir y editar enlaces (#1, #2, #4)

Fecha: 2026-09-06. Sub-bloque A del bloque "Catálogo" (#1–#6) del proyecto GestorAO.
Cubre: **#1 Editar enlaces existentes**, **#2 Añadir varios a la vez (pegar URLs)**, **#4 Detección de URLs duplicadas**.
Fuera de alcance (sub-bloques posteriores): #5 etiquetas, #6 orden manual, #3 importar/exportar, #21 limpieza de capturas, #25 normalización de URLs.

## Contexto

La identidad de un enlace en el catálogo es su **URL**: es la clave del estado de comprobación (`estado_store`, `user://estados.json`), de los borrados, de la detección de duplicados al fusionar `data.json` + `user://enlaces.json`, y de los estados en memoria (`main._estados`). Los datos de un enlace son `{nombre, desc, url, img}` dentro de `_entradas: Array`.

El diálogo `AgregarEnlace` (Window) captura nombre/descripción/URL/imagen y emite `guardado(datos)`; `main._on_enlace_guardado` añade a `_entradas` y guarda. La fila (`ListItem`) es un `Button` que abre la URL con clic izquierdo y hoy muestra botones visibles (`BtnRecomprobar`, `BtnEliminar`, `BtnCopiar` + feedback con temporizador).

## Decisiones de diseño

1. **Duplicado = URL exacta** tras `strip_edges()` (mayúsculas y barra final importan). Los duplicados **se ignoran y se reportan al final**, tanto contra el catálogo actual como dentro del propio lote.
2. **Editar reutiliza `AgregarEnlace`** precargado. La **URL se puede editar solo si no colisiona** con otra entrada existente (excluyendo la propia). Si la URL cambia, se remapea el estado y el historial de borrado (memoria + disco).
3. **El disparador de edición y acciones es un menú contextual** con clic derecho en la fila: **Editar… / Volver a comprobar / Copiar URL / Eliminar**. Se **eliminan los botones visibles** de la fila. El clic izquierdo sigue abriendo la URL.
4. **Modo "Varias URLs"** dentro del diálogo: caja multilínea, una URL por línea; cada enlace se crea con `nombre = dominio(url)`, `desc = ""`, `img = ""`. Líneas vacías se ignoran; líneas no-http(s) se saltan y se reportan junto a las repetidas.
5. El feedback de copiar pasa al label de progreso de `main` ("URL copiada: <url>"); desaparece el feedback temporal del botón.

## Arquitectura

### `scripts/gestor_catalogo.gd` (nuevo, helpers puros)

Sigue el patrón de `gestor_imagenes.gd` / `gestor_contadores.gd`: sin estado, funciones estáticas recuperables desde preload.

- `static func dominio(url: String) -> String`
  Host sin esquema ni ruta; quita `www.` inicial. Ej.: `https://www.ejemplo.com/ao` → `ejemplo.com`.
- `static func duplicadas(urls: Array, existentes: Array) -> Array`
  Devuelve las URLs de `urls` que ya están en `existentes`, **o que se repiten dentro de `urls`**, comparando el `strip_edges()` exacto. Sin normalizar mayúsculas/barra.

### Diálogo `AgregarEnlace` multi-modo

Selector de modo arriba: **"Individual" | "Varias"**.

- **Individual** (comportamiento actual): campos nombre/descripción/URL/imagen y validaciones vigentes (nombre y URL no vacíos, URL http(s)). Emite `guardado(datos)`.
- **Varias**: se oculta el formulario (nombre/desc/imagen) y se muestra un `TextEdit` multilínea (`placeholder`: "Una URL por línea…"). Al guardar se emite `lote_guardado(urls: Array)` con las línea no vacías crudas; `main` construye las entradas (`nombre = gestor_catalogo.dominio(url)`, `desc = ""`, `img = ""`), filtra duplicadas/inválidas y reporta.
- **Editar** (abierto desde el menú contextual): mismo formulario individual **precargado** (nombre/desc/URL/imagen), título "Editar enlace", botón "Guardar cambios". Emite `editado(datos: Dictionary, url_original: String)`.

Señales del diálogo: `guardado(datos)`, `lote_guardado(urls)`, `editado(datos, url_original)`.
La validación permanece en el diálogo (formato URL, campos obligatorios); las reglas de catálogo (duplicados, dominio) viven en `main`/helpers.

### `ListItem` menú contextual

- El clic izquierdo abre la URL (sin cambios).
- Clic derecho (`gui_input` / `MOUSE_BUTTON_RIGHT`) abre `%MenuContexto` (`PopupMenu`) en la posición del ratón con:
  - `Editar…` → señal nueva **`editar_pedido`**
  - `Volver a comprobar` → `recomprobar_pedido` (existente)
  - `Copiar URL` → `copiar_pedido` (existente)
  - `Eliminar` → `eliminar_pedido` (existente)
- Se eliminan de `ListItem.tscn`: `Acciones` (`BtnRecomprobar`, `BtnEliminar`), `BtnCopiar`, `TemporizadorCopiar`. Se añade `%MenuContexto`.
- La opción del menú se conecta a la señal en `_ready`; cada ítem emite su señal con los mismos argumentos que antes.

### `main.gd` flujos

- **`_on_enlace_guardado(datos)`**: si `datos.url` está en `_entradas` → no guarda y `progreso.text = "Ya existe: <url>"`. Si no, alta como hoy.
- **`_on_lote_guardado(urls)`**:
  1. Normaliza líneas (`strip_edges`), descarta vacías.
  2. Separa inválidas (no http(s)) y duplicadas con `gestor_catalogo.duplicadas(urls, _entradas)` (las duplicadas internas del lote se detectan en el mismo helper).
  3. Construye entradas `{nombre: dominio, desc: "", url, img: ""}` para las válidas nuevas.
  4. Añade, guarda, refresca.
  5. `progreso.text` = `"Se añadieron X enlaces."` y, si `Y > 0`, `" Y repetidas ignoradas."`; si hay `Z` inválidas se añade `" Z inválidas ignoradas."` (cada parte solo si > 0).
- **`_on_editar_pedido(item)`**: busca en `_entradas` la entrada con `url == item.url`, precarga `ventana_agregar` en modo Editar con `url_original`.
- **`_on_enlace_editado(datos, url_original)`**:
  1. Localiza la entrada por `url_original`.
  2. Colisión: si `datos.url != url_original` y `gestor_catalogo.duplicadas([datos.url], _entradas)` no está vacío → no guarda, `progreso.text = "Ya existe: <url>"` y **reabre** el diálogo de edición con los mismos datos para corregir.
  3. Si cambió la URL: `_estado_store.renombrar(url_original, datos.url)`, y en memoria se mueve la clave de `_estados` y se reemplaza la URL en `_borrados`.
  4. Sustituye los campos de la entrada (nombre/desc/url/img). Imagen: flujo actual vía `gestor_imagenes.copiar(_imagen_ruta)`.
  5. `_guardar_datos()`, `_refrescar_vista()`, `_actualizar_status()`.

### `estado_store.gd`

Nuevo método `renombrar(url_antigua: String, url_nueva: String) -> bool`: lee los datos persistidos, mueve la clave de `estados` si existe, reemplaza `url_antigua` por `url_nueva` en `borrados`, reescribe el archivo. Devuelve `false` solo si falla la escritura.

## Flujos de datos

- **Alta individual**: usuario → diálogo → `guardado(datos)` → `main` (duplicado? no → añade+guarda | sí → mensaje).
- **Lote**: usuario pega líneas → `lote_guardado(urls)` → `main` filtra (inválidas, duplicadas) → añade válidas → reporta conteo.
- **Editar**: clic derecho → `editar_pedido` → precarga → `editado(datos, url_original)` → `main` (colisión excluyendo self → reabre | valida → remapea estado/borrado si cambia URL → reemplaza campos → guarda).

## Errores y casos límite

- Colisión en edición con una URL existente (excluyendo la propia): no guardar + reabrir.
- Duplicados en lote intra-lote y contra catálogo: ignorar + reportar en un único mensaje final.
- `renombrar` sin clave previa en `estados` o sin URL en `borrados`: no-op salvo escritura (no es error).
- Cambio de imagen en edición: si el usuario elige imagen nueva, se copia como en alta; si la quita, `img = ""`.
- Batería de regresión: los checks del lote (#15/#16/#18) que pulsaban botones visibles se migran a las opciones del menú; `test_estado_store` gana casos de `renombrar`; `test_main_barra` no se ve afectado (sigue instanciando `Main.tscn`).

## Testing

- **`tests/test_gestor_catalogo.gd`** (nuevo): `dominio()` — esquema, `www.`, ruta, puerto, dominio desnudo; `duplicadas()` — colisión exacta, trim, diferenciación de mayúsculas, repetidas internas del lote, lista vacía, sin duplicados.
- **`tests/test_agregar_enlace.gd`** (nuevo): modo Varias (línea vacía ignorada, inválida contada, emisión de `lote_guardado` con líneas crudas), modo Editar (precarga campos + `editado` con `url_original`), validación individual intacta.
- **`tests/test_estado_store.gd`** (+): `renombrar` mueve clave, reemplaza en borrados, no-op sin clave, persiste a disco.
- **`tests/test_list_item.gd`** (migración): clic derecho abre `%MenuContexto`; cada ítem emite su señal (`editar_pedido`, `recomprobar_pedido`, `copiar_pedido`, `eliminar_pedido`). Se eliminan/ajustan los checks que pulsaban `%BtnCopiar`/`%BtnRecomprobar`/`%BtnEliminar` y el del feedback del botón.
- **`tests/test_main_barra.gd`** (o suite de integración): alta individual duplicada → no añade + mensaje; lote con válidas/duplicadas/inválidas → añade las válidas y reporta conteos; edición con cambio de URL → remapeo confirmado en `_estados`/`_borrados` (memoria) y `estado_store` (disco); colisión en edición excluyendo self.
- Batería completa de suites al final; harness SceneTree, salida `TESTS OK` / `quit(0)`.

## Normas del repo

Textos de UI en español; sin comentarios en código; sin `class_name` (preload); `.tscn` a columna 0; harness SceneTree para tests; no crear archivos fuera de lo listado; sidecars `.uid` versionados si el editor los genera.