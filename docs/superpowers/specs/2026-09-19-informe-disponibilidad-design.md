# Diseño — #11 Exportar informe de disponibilidad (CSV/HTML)

Fecha: 2026-09-19

## Objetivo

Permitir exportar un informe de disponibilidad del catálogo completo en archivo CSV (para Excel) o HTML legible, elegible por extensión desde un único FileDialog de guardar, accesible desde el menú Archivo. Refleja el estado actual de cada enlace (válido/caído/sin comprobar) usando los datos ya cargados en memoria.

## Decisiones de diseño

1. **Todos los enlaces del catálogo**, comprobados o no. Sin estado → "Sin comprobar".
2. **CSV y HTML**, ambos desde un solo FileDialog de guardar; el formato se deduce de la extensión del nombre elegido (`.html` → HTML, resto → CSV; sin extensión → `.csv` por defecto). Sin diálogo intermedio de formato.
3. **Nuevo `scripts/informe_store.gd`** (RefCounted, funciones estáticas), separado de `gestor_archivo.gd` (que solo habla el formato interno JSON del catálogo) y de `main.gd` (que queda para orquestación). Patrón store/UI del repo, testeable sin UI.
4. **3 estados de texto** en el informe: `Válido`, `Caído`, `Sin comprobar`. Las URLs inválidas (malformadas, no http/https) cuentan como `Caído`.

## Alcance

- Generación del informe desde la vista/estado en memoria (`_entradas` + `_estados`).
- Ítem "Informe de disponibilidad…" en el menú Archivo.
- Nuevo `%DialogoInforme` (FileDialog guardar) en `Main.tscn`.
- **Sin cambios** en el formato de catálogo, en el escaneo, en preferencias ni en el empaquetado.

## Arquitectura

### 1. Nuevo `scripts/informe_store.gd` (RefCounted, estáticas)

**API:**

```gdscript
class_name InformeStore
extends RefCounted

# filas: Array[Dictionary] con {nombre, url, estado, fecha, mensaje}
static func exportar_csv(ruta: String, filas: Array) -> Dictionary
static func exportar_html(ruta: String, filas: Array) -> Dictionary
```

Ambas devuelven `{"ok": true, "total": int}` o `{"ok": false, "error": String}` (mismo contrato que `gestor_archivo.exportar`).

**CSV:**
- Separador `;` (Excel es español usa `;`).
- Cabecera: `Nombre;URL;Estado;Fecha;Mensaje`.
- Escape: valores que contengan `;`, `"`, `\n` o `\r` se envuelven en comillas dobles; las `"` internas se doblan (`""`). El resto sin comillas.
- `estado` en texto: `Válido`, `Caído`, `Sin comprobar`.
- `fecha`: `0` → campo vacío; si no, `AAAA-MM-DD HH:MM` (hora en HH:MM).
- Final de línea `\n` (RFC 4180 no exige CRLF; se usa `\n`).

**HTML:**
- Documento autocontenido: `<!DOCTYPE html>`, `<meta charset="utf-8">`, `<title>Informe de disponibilidad</title>`.
- CSS inline en `<style>`: tabla simple (bordes, cabecera gris), fila verde para `Válido`, roja para `Caído`, gris para `Sin comprobar`.
- Escape de `<`, `>`, `&`, `"` en todos los campos.
- Cabecera de columnas: Nombre, URL, Estado, Fecha, Mensaje. Fecha vacía si `fecha == 0`.

**Escritura:** `FileAccess.open(ruta, FileAccess.WRITE)`, devuelve `{"ok": false, "error": "No se pudo escribir el archivo."}` si falla.

### 2. Integración en `scripts/main.gd`

- `const InformeStoreScript := preload("res://scripts/informe_store.gd")`
- `_configurar_menus()` (línea ~108): tras "Exportar…" añadir `menu_file.add_item("Informe de disponibilidad…", 5)`.
- `_on_file_id(id)` (línea ~127): caso `5` → `%DialogoInforme.popup_centered()`.
- Conexión en `_ready()`: `%DialogoInforme.file_selected.connect(_on_informe_elegido)`.
- `_on_informe_elegido(ruta: String)`:
  1. `var formato := _formato_informe(ruta)`.
  2. Construir `filas: Array` recorriendo `_entradas` como dicts; para cada una, `clave = GestorCatalogoScript.clave_unica(url)`, buscar `_estados.get(clave, {})`.
     - `estado` texto: `_estados` sin entrada → `"Sin comprobar"`; si la hay → `"Válido"` si `valido == true` else `"Caído"`.
     - `fecha` y `mensaje` del estado (o vacíos).
  3. `var res := InformeStoreScript.exportar_csv(ruta, filas)` o `exportar_html` según formato.
  4. Éxito → `progreso.text = "Informe %s guardado (%d enlaces)." % [formato.to_upper(), total]`; error → `progreso.text = error`.
- `_formato_informe(ruta: String) -> String`: si `ruta.to_lower().ends_with(".html")` → `"html"`; si `ruta.to_lower().ends_with(".csv")` → `"csv"`; si no → `"csv"` (y si falta extensión se añade `.csv` al llamar al store).

> Detalle de robustez: si el usuario elige un nombre sin extensión en el FileDialog, se fuerza `.csv` para que el fichero se abra bien en Excel.

### 3. `scenes/Main.tscn` — nuevo `%DialogoInforme`

```text
[node name="DialogoInforme" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Guardar informe de disponibilidad"
file_mode = 4
filters = PackedStringArray("*.csv ; Archivo CSV (*.csv)", "*.html ; Archivo HTML (*.html)")
```

Se añade tras `%DialogoExportar` (~línea 212).

## Flujo de datos

```text
Menú Archivo → Informe de disponibilidad…
  → %DialogoInforme.popup_centered()
  → usuario escribe informe.csv / informe.html
  → _on_informe_elegido(ruta)
      → _formato_informe(ruta) → csv|html
      → filas = _entradas ∪ {estado, fecha, mensaje} desde _estados (por clave_unica)
      → exportar_csv/html(ruta, filas)
      → "Informe CSV guardado (N enlaces)." / error
```

## Manejo de errores / mantenibilidad

- Escritura con `FileAccess` devuelve error legible en `%Progreso`; nunca crashea si el path no es escribible.
- `informe_store.gd` no conoce UI ni main; solo recibe `ruta` y `filas` y devuelve un Dictionary. Mantiene la separación store/UI.
- Estados derivados solo desde `_estados` en memoria (no lee `user://estados.json`), consistente con lo que muestra la lista.

## Testing

**Nuevo `tests/test_informe_store.gd`** (SceneTree, base `user://__test_informe__/`):

1. CSV: cabecera correcta `Nombre;URL;Estado;Fecha;Mensaje`.
2. CSV: fila válida y fila caída con estado correcto.
3. CSV: fila con `fecha == 0` → campo Fecha vacío.
4. CSV: escape de `;` y `"` en un campo (mensaje con `Hola; "mundo"`).
5. HTML: contiene `<!DOCTYPE html>`, `<table>`, y texto escapado `&lt;script&gt;` para un mensaje malicioso.
6. HTML: fila caída tiene la clase/color rojo.
7. `exportar_csv` a un path inválido → `{"ok": false}`.
8. Al terminar se limpia `user://__test_informe__`.

> Basado en el patrón de `tests/test_gestor_archivo.gd` (escritura a fichero temporal `user://__test_*__` y limpieza async-safe con `await process_frame`).

**Integración en `tests/test_main_barra.gd`**:

- El menú Archivo contiene el ítem "Informe de disponibilidad…" (verbosidad: inspeccionar `%File` tras `_configurar_menus`, o emitir el id).
- `main.has_node("%DialogoInforme")` es true.
- `_formato_informe("x.html") == "html"`, `_formato_informe("x.csv") == "csv"`, `_formato_informe("x") == "csv"`.

## Entregables

- `scripts/informe_store.gd` — nuevo store (exportar_csv/exportar_html).
- `tests/test_informe_store.gd` — suite nueva.
- `scripts/main.gd` — ítem de menú, `%DialogoInforme` wiring, `_on_informe_elegido`, `_formato_informe`.
- `scenes/Main.tscn` — `%DialogoInforme`.
- `tests/test_main_barra.gd` — checks de integración.