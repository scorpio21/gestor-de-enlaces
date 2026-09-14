# Design: Importar/exportar catálogo JSON, atajos de teclado y tests de link_checker

**Fecha:** 2026-09-14
**Issues:** #3 (Importar/exportar catálogo), #14 (Atajos de teclado), #31 (Tests de link_checker)
**Motor:** Godot 4.7.2 (GDScript), ejecución headless para tests (`--script res://tests/<archivo>.gd` con harness SceneTree `_check`).

## 1. Alcance y decisiones

| Decisión | Elección |
|---|---|
| Import: qué hacer con URLs ya presentes | Fusionar con dedup por `clave_unica`; las repetidas se omiten y se informa el recuento. |
| Formato de exportación | Solo JSON estándar (campos nombre, desc, url, img, cat). CSV se pospone. |
| Selección del archivo | Diálogos nativos (`FileDialog`) a cualquier ruta, filtro `*.json`. |
| Saneamiento al importar | Normalizar URL, ignorar entradas no válidas, conservar solo campos conocidos, omitir duplicados. |
| Atajos | Enfoque de acciones en `[input]` + dispatcher `_on_atajo` en main.gd. Esc usa `ui_cancel`. |
| #31 | Solo `link_checker.gd` (la cobertura de `gestor_imagenes` ya existe, 19 checks del ciclo anterior). Sin red. |

## 2. Arquitectura

- **Nuevo** `scripts/gestor_archivo.gd` (`extends RefCounted`, helpers estáticos) — patrón de `gestor_catalogo.gd`.
- **Nuevo** `tests/test_gestor_archivo.gd`.
- **main.gd**: items en el menú `%File`, dos `FileDialog` en `Main.tscn`, `_unhandled_input` + `_on_atajo`.
- **project.godot**: sección `[input]` con las acciones de atajo.
- **tests/test_link_checker_timeout.gd**: se amplía; `link_checker.gd` y `gestor_imagenes.gd` no cambian.

## 3. Issue #3 — Importar/Exportar catálogo JSON

### `scripts/gestor_archivo.gd`

```gdscript
extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const CAMPOS := ["nombre", "desc", "url", "img", "cat"]

static func exportar(ruta: String, entradas: Array) -> Dictionary
```

- `CAMPOS`: solos fields exportados/importados.
- `exportar(ruta, entradas)`:
  - Construye un array con sub-dicts de solo `CAMPOS` (coerción `String` de cada valor).
  - `JSON.stringify(sub, "\t")` y escribe con `FileAccess.open(ruta, FileAccess.WRITE)`.
  - Retorna `{"ok": true, "total": N}` o `{"ok": false, "error": "No se pudo escribir el archivo."}`.

- `importar(ruta, existentes: Array)`:
  - `FileAccess.open(ruta, READ)`; si falla o `JSON.parse_string` no es `TYPE_ARRAY` → `{"ok": false, "error": "El archivo no es un catálogo válido."}`.
  - Por cada elemento: solo `TYPE_DICTIONARY`; `url` = `normalizar_url(str(entrada.get("url","")))`; si vacía → omitida; `clave_unica` contra `existentes` y contra las ya aceptadas dentro del mismo archivo → omitida si colisiona.
  - Campo `cat`: `normalizar_categoria`.
  - Retorna `{"ok": true, "entradas": [...], "omitidas": N}`.

### `scenes/Main.tscn`

- Nodos `%DialogoImportar` (file_mode `OPEN_FILE`, filter `"*.json"`) y `%DialogoExportar` (file_mode `SAVE_FILE`, filter `"*.json"`).

### `scripts/main.gd`

- `_configurar_menus`: en `%File` añadir: `Importar…` (1), `Exportar…` (2) (Salir pasa a id 3; los ids existentes se renumeran).
- `_on_file_id`: 1→`%DialogoImportar.popup_centered()`; 2→`%DialogoExportar.popup_centered()`; 3→`get_tree().quit()`.
- `_on_importar_elegido(ruta)`:
  - `res := GestorArchivoScript.importar(ruta, _urls_existentes())`.
  - Si `error` → `progreso.text = error`.
  - Si `entradas` vacío → `progreso.text = "%d omitidos (ya existían o sin URL válida)." % omitidas`.
  - Si no: append de cada una a `_entradas`, `_guardar_datos()`, `_refrescar_vista()`, `_actualizar_status()`, `progreso.text = "%d importados, %d omitidos."`.
  - No toca `estado_store` (los importados quedan «sin comprobar»).
- `_on_exportar_elegido(ruta)`: `exportar(ruta, _entradas)` → `progreso.text = "Catálogo exportado (%d enlaces)."` o error.
- Const `GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")`.

## 4. Issue #14 — Atajos de teclado

### `project.godot` — sección `[input]`

- `atajo_buscar`: `KEY_CTRL + KEY_F`
- `atajo_agregar`: `KEY_CTRL + KEY_N`
- `atajo_comprobar`: `KEY_CTRL + KEY_R`
- Esc: se reutiliza la acción estándar `ui_cancel`.

### `scripts/main.gd`

- `_unhandled_input(event)`: para cada atajo `is_action_pressed` → `_on_atajo(nombre)`. Para `ui_cancel` (sin consumo previo por popups/menús) → `_on_atajo("ui_cancel")`.
- `_on_atajo(nombre)`:
  - `"atajo_buscar"` → `busqueda.grab_focus()`.
  - `"atajo_agregar"` → si `not ventana_agregar.visible`: `ventana_agregar.abrir()`; si está visible, `grab_focus()` de su `%Nombre` (trae frente).
  - `"atajo_comprobar"` → `_comprobar_visibles()`.
  - `"ui_cancel"` → si `ventana_agregar.visible` ocultarla; si no y `preferencias.visible` ocultarla.
- Los ConfirmationDialog/popups consumen `ui_cancel` solos (se cierran), así que no llegan al dispatcher: no hay doble cierre. `_unhandled_input` se prueba invocando `_on_atajo` directamente (headless no simula teclas de forma fiable).

## 5. Issue #31 — Tests de `link_checker.gd`

Ampliar `tests/test_link_checker_timeout.gd` (4 → ~20 checks), sin red, instancia nueva por caso:

- **`MARCAS_MUERTO`**: no vacía y todas las marcas no vacías.
- **`_parece_muerto`**: `(404, "")` → true; `(410, "<html>…")` → true; `(200, "")` → false; `(200, html_con_marca)` (minúsculas, como las entrega `_leer_respuesta`) → true; `(200, html_sin_marca)` → false.
- **`_parsear_url`**: `"https://example.com"` → `{host:"example.com", port:443, path:"/", tls:true}`; `"http://ej.com:8080/x"` → `{host:"ej.com", port:8080, path:"/x", tls:false}`; `"ftp://x"` → `{}`; `"sin-esquema.com"` → `{}`; `"https://[::1]/"` → host `"[::1]"`.
- **`_resolver_redirect`**: destino absoluto (`http://…`) intacto; relativo `/ruta` → `"https://host:puerto/ruta"` según la URL base. Documenta el contrato actual (los redirects relativos sin `/` no se expanden con barra — quirk conocido, no se corrige aquí).
- **`comprobar` con URL inválida, sin red**: `comprobar("")` y `comprobar("gopher://x")` emiten **sincrónicamente** `terminado(false, "URL inválida")` y dejan `_activo == false`. Cada caso usa `LinkChecker.new()` y conecta la señal antes de `comprobar`.

## 6. Errores

- Fallo de escritura/lectura → `progreso.text` con mensaje corto (patrón actual).
- Import con archivo corrupto/type equivocado → `"El archivo no es un catálogo válido."`.
- Import sin novedades → mensaje informativo, sin guardar (`_guardar_datos` no se llama si `entradas` está vacío).
- Atajos: no se interceptan si un diálogo/popup consume la tecla antes.

## 7. Pruebas y verificación

- `tests/test_gestor_archivo.gd` (~14 checks): roundtrip exportar→importar; campos conservados; dedup contra existentes; dedup interno del archivo; entradas inválidas omitidas + contador; archivo inexistente → error; export de catálogo vacío.
- `tests/test_main_barra.gd` (+4 checks): dispatcher `_on_atajo("buscar")` enfoca `%Busqueda`; `("agregar")` abre `VentanaAgregar`; `("comprobar")` llama el flujo de comprobación; `("ui_cancel")` oculta `VentanaAgregar`. (En el harness de la escena Main, como las inserciones del ciclo anterior.)
- `tests/test_link_checker_timeout.gd` (~20 checks) como en la sección 5.
- Batería final: 10 suites `TESTS OK` + `--check-only` sobre `scripts/gestor_archivo.gd` y `main.gd` + smoke `res://scenes/Main.tscn --quit-after 60`.
- TDD por tarea (RED→GREEN→commit), una tarea por issue, en un solo plan.

## 8. Fuera de alcance

- CSV (pospuesto, opcional en #3).
- Historial de estado al importar (los importados quedan «sin comprobar»).
- Ataques/validación de tipos profundos de `entradas` (coerción simple a `String`).
- Corrección del quirk de `_resolver_redirect` con relativos sin `/` (solo se documenta con test).
- Gestor de imágenes (ya cubierto).