# Captura/imagen de enlaces al agregar — Diseño

> **Fecha:** 2026-09-05
> **Decisión:** Permitir adjuntar una captura/imagen cuando se agrega un enlace, mostrarla como miniatura en la lista y usar un placeholder cuando no haya imagen.

## Objetivo

Al agregar un enlace (escenario AO), poder elegir un archivo de imagen local (captura/gráfico del juego) que se copia a la carpeta `res://Assets/png/` del proyecto y se muestra como miniatura en la fila del enlace. Si el enlace no tiene imagen (o el archivo no existe), la fila muestra la imagen `res://Assets/png/no-disponible.png` como marcador.

## Alcance

**Incluye**
- Nueva clave `img` (String) en cada entrada de enlace (vacía = sin imagen).
- Diálogo **Agregar enlace**: botón "Elegir imagen…", FileDialog, vista previa (~120px) y botón "Quitar imagen".
- Copiado del archivo elegido a `res://Assets/png/` con nombre saneado `img_<unix_ts>.<ext>`.
- Miniatura `TextureRect` (~56×56, `KEEP_ASPECT_CENTERED`, expandida) al inicio de cada fila de la lista.
- Placeholder `res://Assets/png/no-disponible.png` cuando `img` está vacío o el archivo no se puede cargar.
- Al confirmar el borrado de un enlace, eliminar también su archivo de imagen si apunta a `res://Assets/png/`.
- Asset `no-disponible.png` versionado en el repo.
- Tests headless: extender `tests/test_list_item.gd` con miniatura visible/placeholder.

**Excluye**
- Edición posterior del enlace (cambiar/poner imagen después de guardar). Solo se asocia al agregar.
- Descargar imágenes por URL o scraping automático.
- Redimensionar/recomprimir la imagen al copiarla (se escala en pantalla; se guarda el original).
- Anchova/`data/data.json.bak`, `data2.json`, `servidores.json` sin tocar.

## Contexto actual

- `scripts/agregar_enlace.gd` (Window) con campos Nombre, Descripción (1 línea), URL; emite `guardado(datos)` con `{nombre, desc, url}`.
- `scripts/main.gd::_on_enlace_guardado()` hace `_entradas.append(datos)` y `_guardar_datos()` escribe `_entradas` en `user://enlaces.json` y `data/data.json`.
- `scenes/ListItem.tscn`: fila `Button` con `Indicador`, `Textos` (NombreLabel, DescripcionLabel), `EstadoLabel`, `Acciones`. `scripts/list_item.gd::setup(nombre, desc, url)` y vars `url/estado/valido/mensaje`.
- `_confirmar_borrado()` en `main.gd` marca borrado en `user://borrados.json`, elimina de `_entradas` en memoria y hace `item.queue_free()`. `data/data.json` no se escribe en el flujo de borrado.
- Los enlaces sin `img` (todos los actuales) deben seguir funcionando sin cambios visuales reales (mostrarán el placeholder tras este cambio).

## Almacenamiento y formato de datos

- Carpeta destino: `res://Assets/png/`. Se crea automáticamente (`DirAccess.make_dir_recursive_absolute`) al guardar si no existe. Al ser `res://`, solo se puede escribir ejecutando desde el proyecto (editor/dev), que es el uso de este gestor (no exportado).
- Clave `img`: valor `res://Assets/png/img_<unix_ts>.png`. El origen puede ser png/jpg/jpeg/webp; siempre se guarda como `.png`. Si no hay imagen, `""` y la clave `img` se guarda vacía.
- `Assets/png/` se versiona en git: las capturas elegidas por el usuario quedan trackeadas automáticamente (nueva capeta dentro del repo) y son compartibles al clonar.
- Las entradas existentes sin clave `img` se tratan como `img == ""`.

## Placeholder no-disponible.png

- Existe como asset en `res://Assets/png/no-disponible.png` (se genera y commitea en la implementación).
- Regla de visualización: si `img` está vacío O `ResourceLoader.file_exists(img)`/carga falla → la miniatura muestra `no-disponible.png`. Si la imagen se carga bien → muestra la imagen.
- La lista siempre muestra la `TextureRect` (visible), con placeholder o imagen real. Así el usuario sabe que la miniatura existe pero no hay captura.

## Diálogo Agregar enlace

- Se añade tras el campo URL (antes del label de error):
  - Botón "Elegir imagen…" → FileDialog (`access = FILE_OPEN`, filtros: `*.png`, `*.jpg;*.jpeg`, `*.webp`).
  - `TextureRect` de vista previa (~120×120, `KEEP_ASPECT_CENTERED`, expandida) que muestra la imagen elegida o `no-disponible.png` si aún no se elige.
  - Botón "Quitar imagen" que limpia la selección (vuelve al placeholder).
- Estado interno: `_imagen_ruta` (String, ruta (source file o `""`)). `abrir()` lo resetea a `""` y la vista previa al placeholder.
- Al guardar:
  1. Validaciones actuales (nombre, url) sin cambios.
  2. Si `_imagen_ruta` está vacía → `img = ""`.
  3. Si hay imagen → cargar con `Image.load_from_file` desde la ruta elegida y `save_png` a `res://Assets/png/img_<unix_ts>.png`. Si cargar/convertir falla → `error_label.text = "No se pudo copiar la imagen."` y no se emite `guardado`.
- `img` se incluye en el diccionario emitido: `{nombre, desc, url, img}`.

## Lista (ListItem.tscn / list_item.gd)

- Nueva `TextureRect` `Imagen` (unique_name_in_owner) al inicio de la fila (hijo de `Fila`, antes de `Indicador`):
  - `custom_minimum_size = Vector2(56, 56)`, `expand_mode = 1` (EXPAND_IGNORE_SIZE), `stretch_mode = 5` (KEEP_ASPECT_CENTERED), `texture_filter = 1` (LINEAR) opcional, `mouse_filter = 2`.
  - Placeholder por defecto en la escena: `texture = ExtResource(no-disponible)`.
- `setup(nombre, desc, enlace, imagen := "")`: si `imagen` no está vacía y `ResourceLoader.file_exists(imagen)` carga `load(imagen)` y asigna textura; si no, deja el placeholder de la escena.
- `main.gd::_mostrar_lista()` pasa `str(entrada.get("img", ""))` como cuarto argumento a `setup`.
- Entradas sin `img`: placeholder (regla de visualización).
- `_pressed()` (abrir URL) no cambia: la miniatura con `mouse_filter = IGNORE` no intercepta el clic.

## Flujo de borrado

- En `_confirmar_borrado()`, tras `item.queue_free()`:
  - Si el item tenía imagen (leer `img` de la entrada eliminada) y `img.begins_with("res://Assets/png/")` → `DirAccess.remove_absolute(ProjectSettings.globalize_path(img))`, sin errores visibles si falla (best-effort).
- No se escribe `data/data.json` en el borrado (sin cambios respecto al plan anterior).

## Casos borde

- Archivo de origen png/jpg/jpeg/webp o con extensión en mayúsculas (`JPG`) → siempre se guarda como `img_<unix_ts>.png` (sin depender de la extensión original).
- Imagen elegida ya dentro de `Assets/png/` → se copia igual a un nombre nuevo (sin colisiones).
- `img` señala un archivo que no existe (borrado a mano o clon sin las imágenes) → placeholder.
- Copiar falla (ruta no legible, formato corrupto) → error en el diálogo y no se agrega el enlace.
- `Assets/png/no-disponible.png` es un asset del repo, no se borra jamás (el guard de borrado lo excluye si alguna entrada lo referenciara).

## Verificación

1. **Tests headless** — extender `tests/test_list_item.gd` (harness SceneTree existente, patrón fijado: `quit(0)`+`return`, salida limpia, `TESTS OK`):
   - Item con `img` a un PNG temporal generado en `user://` → `TextureRect` visible con textura != placeholder.
   - Item con `img == ""` → `TextureRect` muestra el placeholder (textura == no-disponible).
   - Item con `img` inexistente → placeholder.
2. **Smoke tests**: `--script res://scripts/main.gd --check-only`, `res://scenes/Main.tscn --quit-after 60` y `res://scenes/AgregarEnlace.tscn --quit-after 60` sin `Parse Error|SCRIPT ERROR|ERROR`.
3. **Manual (opcional)**: agregar enlace con imagen, ver miniatura y placeholder, borrar enlace y comprobar que el archivo de `Assets/png/` desaparece.

## Criterios de aceptación

1. El diálogo Agregar enlace permite elegir un archivo de imagen local, previsualizarlo y quitarlo.
2. Al guardar, la imagen se copia a `res://Assets/png/img_<unix_ts>.png` y la entrada guarda `img`; si no hay imagen, `img = ""`.
3. La fila del enlace muestra la miniatura (56px, centrada, sin distorsión).
4. Si no hay imagen o el archivo no existe, la fila muestra `no-disponible.png`.
5. Al eliminar la entrada, se borra su archivo de `Assets/png/` (solo si el `img` apunta ahí).
6. `data/data.json` no se modifica en el flujo de borrado; el flujo de agregar lo actualiza como hasta ahora, ahora con la clave `img`.
7. Tests extendidos pasan y smoke tests de escenas sin errores.
8. Las entradas existentes sin `img` siguen funcionando (placeholder).